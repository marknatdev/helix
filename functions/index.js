/**
 * functions/index.js
 * ────────────────────────────────────────────────────────────────────────────
 * HELIX Receiver telemetry ingestion + admin API.
 *
 * Standalone Express server — NOT a Firebase Cloud Function (smhelmet-67 is on
 * the free Spark plan; Cloud Functions Gen2 requires Blaze). Deployed to
 * Render (see render.yaml at repo root) and runnable locally the same way:
 *   node index.js
 *
 * Firebase Admin credentials come from, in order: GOOGLE_APPLICATION_CREDENTIALS_JSON
 * (the service-account key as a JSON string — how Render's env vars carry it,
 * since a key file can't be committed), GOOGLE_APPLICATION_CREDENTIALS (a file
 * path, for local dev), or the local committed key file as a last-resort default.
 *
 * ChirpStack config:
 *   POST  <deploy-url>/chirpstack-webhook
 *   Header: X-Webhook-Token: <WEBHOOK_SECRET>
 *
 * Receiver telemetry (per-device credential, see spec-device-pairing-system.md D5):
 *   POST  <deploy-url>/lora-uplink
 *   Headers: X-Receiver-Id: <receiverId>, X-Receiver-Credential: <raw credential>
 * ────────────────────────────────────────────────────────────────────────────
 */

require("dotenv").config();
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const path = require("path");
const crypto = require("crypto");

// ─── Firebase Admin init ──────────────────────────────────────────────────────
function loadCredential() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON) {
    return admin.credential.cert(JSON.parse(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON));
  }
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
    || path.join(__dirname, "smhelmet-67-firebase-adminsdk-fbsvc-5cfc7ee572.json");
  return admin.credential.cert(require(serviceAccountPath));
}
admin.initializeApp({ credential: loadCredential() });
const db = admin.firestore();

const app = express();
// Restrict CORS to localhost, 127.0.0.1, and the deployed firebase hosting domains.
const ALLOWED_ORIGINS = [/localhost/, /127\.0\.0\.1/, /smhelmet-67\.web\.app/, /smhelmet-67\.firebaseapp\.com/];
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || ALLOWED_ORIGINS.some((re) => re.test(origin))) {
      cb(null, true);
    } else {
      cb(new Error("CORS blocked"));
    }
  },
}));
app.use(express.json({ limit: "1mb" }));

// ─── Shared-secret auth (set via CHIRPSTACK_WEBHOOK_SECRET in .env) ──────────
// IMPORTANT: If no secret is configured the endpoint rejects ALL requests.
const WEBHOOK_SECRET = process.env.CHIRPSTACK_WEBHOOK_SECRET || "";

// Alert deduplication cooldown (ms). Prevents spamming the same alert type for
// the same helmet within this window.
const ALERT_COOLDOWN_MS = 5 * 60 * 1000; // 5 minutes

// ─── Per-receiver credential auth (D5, D15) ──────────────────────────────────
// Replaces the old shared X-Webhook-Token for device telemetry. Verifier
// hashes are cached in-memory per function instance to avoid a Firestore read
// on every uplink; a revoke on THIS instance evicts immediately, but Cloud
// Functions runs multiple concurrent instances with no cross-instance push
// invalidation, so the cache also carries a short TTL as the real bound on
// how long a revoked/rotated credential can still work elsewhere — not
// instant across the fleet, but bounded and documented rather than assumed.
const RECEIVER_CACHE_TTL_MS = 30 * 1000; // 30 seconds
const receiverCache = new Map(); // receiverId -> { state, verifier, expiresAt }

async function getReceiverAuthRecord(receiverId) {
  const cached = receiverCache.get(receiverId);
  if (cached && cached.expiresAt > Date.now()) return cached;

  const [receiverSnap, credSnap] = await Promise.all([
    db.collection("receivers").doc(receiverId).get(),
    db.collection("receivers").doc(receiverId).collection("private").doc("credential").get(),
  ]);
  if (!receiverSnap.exists || !credSnap.exists) return null;

  const record = {
    state: receiverSnap.data().state,
    verifier: credSnap.data().credentialVerifier,
    expiresAt: Date.now() + RECEIVER_CACHE_TTL_MS,
  };
  receiverCache.set(receiverId, record);
  return record;
}

/** Verify X-Receiver-Id / X-Receiver-Credential headers against Firestore. */
async function verifyReceiver(req) {
  const receiverId = req.headers["x-receiver-id"] || "";
  const credential = req.headers["x-receiver-credential"] || "";
  if (!receiverId || !credential) {
    return { ok: false, reason: "Missing receiver credentials" };
  }

  const record = await getReceiverAuthRecord(receiverId);
  if (!record) return { ok: false, reason: "Unknown receiver" };
  if (record.state !== "active") return { ok: false, reason: "Receiver revoked" };

  const providedHash = crypto.createHash("sha256").update(credential).digest();
  const storedHash = Buffer.from(record.verifier, "hex");
  // SHA-256 digests are always 32 bytes, so this length check doesn't leak
  // anything credential-dependent — it only guards timingSafeEqual, which
  // throws (rather than compares) on mismatched buffer lengths.
  if (providedHash.length !== storedHash.length || !crypto.timingSafeEqual(providedHash, storedHash)) {
    return { ok: false, reason: "Invalid credential" };
  }
  return { ok: true, receiverId };
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Convert RSSI (dBm, typically -30 to -120) into a 0-100 signal quality % */
function rssiToPercent(rssi) {
  const clamped = Math.max(-120, Math.min(-30, rssi));
  return Math.round(((clamped + 120) / 90) * 100);
}

/** Map battery voltage (3.2–4.2 V) to 0-100 % */
function voltageToPct(v) {
  if (v >= 4.2) return 100;
  if (v <= 3.2) return 0;
  return Math.round(((v - 3.2) / 1.0) * 100);
}

/** Extract decoded CayenneLPP fields from ChirpStack `object` map. */
function parseLpp(obj) {
  const out = {};
  if (!obj) return out;

  // ChirpStack CayenneLPP decoder puts fields like:
  //   gps_1: { latitude, longitude, altitude }
  //   analogOutput_2: <value>   (speed)
  //   analogOutput_3: <value>   (heading)
  //   analogOutput_4: <value>   (battery %)
  //   digitalInput_5: <value>   (sats)
  //   analogOutput_6: <value>   (heart rate bpm)

  if (obj.gps_1) {
    out.lat = obj.gps_1.latitude;
    out.lng = obj.gps_1.longitude;
    out.alt = obj.gps_1.altitude;
  }
  if (obj.analogOutput_2 !== undefined) out.speed = obj.analogOutput_2;
  if (obj.analogOutput_3 !== undefined) out.heading = obj.analogOutput_3;
  if (obj.analogOutput_4 !== undefined) out.battery = obj.analogOutput_4;
  if (obj.digitalInput_5 !== undefined) out.satellites = obj.digitalInput_5;

  return out;
}

// ─── Webhook endpoint ────────────────────────────────────────────────────────

app.post("/chirpstack-webhook", async (req, res) => {
  // 1) Validate per-receiver credential (D5) — replaces the old shared token.
  const auth = await verifyReceiver(req);
  if (!auth.ok) {
    console.warn(`[AUTH] chirpstack-webhook rejected: ${auth.reason}`);
    return res.status(403).json({ error: "Forbidden" });
  }

  const body = req.body;

  // Validate body is a non-null object
  if (!body || typeof body !== "object") {
    return res.status(400).json({ error: "Invalid request body" });
  }

  // ChirpStack v4 wraps uplink data in `data` for the "up" event
  const data = body.data || body;

  const deviceName = (data.deviceInfo && data.deviceInfo.deviceName) || "";
  const devEui = (data.deviceInfo && data.deviceInfo.devEui) || "";

  if (!devEui) {
    return res.status(400).json({ error: "Missing devEui" });
  }

  // Use deviceName as the helmet ID (e.g., "HLX-0142"), fallback to devEui
  const helmetId = deviceName || devEui;

  // 2) Decode payload
  const decoded = parseLpp(data.object || {});

  // Validate critical numeric fields to prevent garbage writes
  if (decoded.lat !== undefined && typeof decoded.lat !== "number") {
    return res.status(400).json({ error: "Invalid lat: must be a number" });
  }
  if (decoded.lng !== undefined && typeof decoded.lng !== "number") {
    return res.status(400).json({ error: "Invalid lng: must be a number" });
  }

  // 3) Extract best RSSI from rxInfo array
  let bestRssi = -120;
  let bestSnr = 0;
  if (Array.isArray(data.rxInfo)) {
    for (const rx of data.rxInfo) {
      const rssi = typeof rx.rssi === "number" ? rx.rssi : -120;
      if (rssi > bestRssi) {
        bestRssi = rssi;
        bestSnr = typeof rx.snr === "number" ? rx.snr
                : typeof rx.loRaSNR === "number" ? rx.loRaSNR : 0;
      }
    }
  }

  // 4) Build Firestore document
  const now = admin.firestore.FieldValue.serverTimestamp();
  const signal = rssiToPercent(bestRssi);
  const battery = decoded.battery !== undefined ? decoded.battery : -1;

  let status = "active";
  if (decoded.speed === 0) {
    status = "idle";
  }

  const doc = {
    helmetId,
    devEui,
    lat: decoded.lat !== undefined ? decoded.lat : 0,
    lng: decoded.lng !== undefined ? decoded.lng : 0,
    alt: decoded.alt !== undefined ? decoded.alt : 0,
    speed: decoded.speed !== undefined ? decoded.speed : 0,
    heading: decoded.heading !== undefined ? decoded.heading : 0,
    battery,
    signal,
    rssi: bestRssi,
    snr: bestSnr,
    satellites: decoded.satellites || 0,
    status,
    lastSeen: now,
    updatedAt: now,
  };

  try {
    // 5) Upsert helmet doc
    await db.collection("helmets").doc(helmetId).set(doc, { merge: true });

    // 6) Generate alerts if needed
    const alertsBatch = db.batch();
    let alertCount = 0;

    // Helper: only create an alert if no unresolved alert of the same kind
    // exists for this helmet within the cooldown window.
    async function maybeAlert(kind, message) {
      const cutoff = new Date(Date.now() - ALERT_COOLDOWN_MS);
      const existing = await db.collection("alerts")
        .where("helmetId", "==", helmetId)
        .where("kind", "==", kind)
        .where("resolved", "==", false)
        .where("ts", ">=", cutoff)
        .limit(1)
        .get();
      if (!existing.empty) return; // skip duplicate
      const alertRef = db.collection("alerts").doc();
      alertsBatch.set(alertRef, {
        helmetId,
        worker: "",
        kind,
        message,
        ts: now,
        resolved: false,
      });
      alertCount++;
    }

    if (battery >= 0 && battery < 20) {
      await maybeAlert("battery", `Battery critically low: ${battery}%`);
    }
    if (signal < 30) {
      await maybeAlert("offline", `Weak LoRa signal: ${signal}% (RSSI ${bestRssi} dBm)`);
    }

    if (alertCount > 0) await alertsBatch.commit();

    console.log(`[OK] ${helmetId}  lat=${doc.lat} lng=${doc.lng} bat=${battery}% sig=${signal}%`);
    return res.status(200).json({ ok: true, helmetId, alertCount });
  } catch (err) {
    console.error("[ERR] Firestore write failed:", err);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── LoRa P2P uplink endpoint (from receiver board) ──────────────────────────
// Simpler format than ChirpStack — the receiver POSTs a flat JSON object.

app.post("/lora-uplink", async (req, res) => {
  // 1) Validate per-receiver credential (D5) — replaces the old shared token.
  const auth = await verifyReceiver(req);
  if (!auth.ok) {
    console.warn(`[AUTH] lora-uplink rejected: ${auth.reason}`);
    return res.status(403).json({ error: "Forbidden" });
  }

  const body = req.body;
  const helmetId = body.helmetId;

  if (!helmetId) {
    return res.status(400).json({ error: "Missing helmetId" });
  }

  // 2) Extract fields (receiver already parsed the binary struct)
  const rssi = typeof body.rssi === "number" ? body.rssi : -120;
  const snr  = typeof body.snr  === "number" ? body.snr  : 0;
  const signal = rssiToPercent(rssi);
  const battery = typeof body.battery === "number" ? body.battery : -1;

  let status = "active";
  if (body.speed === 0) {
    status = "idle";
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

  const doc = {
    helmetId,
    lat: typeof body.lat === "number" ? body.lat : 0,
    lng: typeof body.lng === "number" ? body.lng : 0,
    alt: typeof body.alt === "number" ? body.alt : 0,
    speed: typeof body.speed === "number" ? body.speed : 0,
    heading: typeof body.heading === "number" ? body.heading : 0,
    battery,
    signal,
    rssi,
    snr,
    satellites: typeof body.satellites === "number" ? body.satellites : 0,
    status,
    lastSeen: now,
    updatedAt: now,
  };

  try {
    // 3) Upsert helmet doc
    await db.collection("helmets").doc(helmetId).set(doc, { merge: true });

    // 4) Generate alerts if needed
    const alertsBatch = db.batch();
    let alertCount = 0;

    async function maybeAlert(kind, message) {
      const cutoff = new Date(Date.now() - ALERT_COOLDOWN_MS);
      const existing = await db.collection("alerts")
        .where("helmetId", "==", helmetId)
        .where("kind", "==", kind)
        .where("resolved", "==", false)
        .where("ts", ">=", cutoff)
        .limit(1)
        .get();
      if (!existing.empty) return;
      const alertRef = db.collection("alerts").doc();
      alertsBatch.set(alertRef, {
        helmetId,
        worker: "",
        kind,
        message,
        ts: now,
        resolved: false,
      });
      alertCount++;
    }

    if (battery >= 0 && battery < 20) {
      await maybeAlert("battery", `Battery critically low: ${battery}%`);
    }
    if (signal < 30) {
      await maybeAlert("offline", `Weak LoRa signal: ${signal}% (RSSI ${rssi} dBm)`);
    }

    if (alertCount > 0) await alertsBatch.commit();

    console.log(`[P2P] ${helmetId}  lat=${doc.lat} lng=${doc.lng} bat=${battery}% sig=${signal}% rssi=${rssi}`);
    return res.status(200).json({ ok: true, helmetId, alertCount });
  } catch (err) {
    console.error("[ERR] Firestore write failed:", err);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Dev config endpoint (secret config page) ───────────────────────────────
// Updates helmet fields (location, status, battery, etc.) directly.

app.post("/dev-config", async (req, res) => {
  const token = req.headers["x-webhook-token"] || "";
  if (!WEBHOOK_SECRET || token !== WEBHOOK_SECRET) {
    return res.status(403).json({ error: "Forbidden" });
  }

  const { helmetId, lat, lng, status, battery, speed, heading, worker, keepAlive } = req.body;
  if (!helmetId) return res.status(400).json({ error: "Missing helmetId" });

  const now = admin.firestore.FieldValue.serverTimestamp();
  const update = { updatedAt: now };

  if (lat !== undefined) update.lat = lat;
  if (lng !== undefined) update.lng = lng;
  if (status !== undefined) update.status = status;
  if (battery !== undefined) update.battery = battery;
  if (speed !== undefined) update.speed = speed;
  if (heading !== undefined) update.heading = heading;
  if (worker !== undefined) update.worker = worker;
  if (keepAlive) update.lastSeen = now;

  try {
    await db.collection("helmets").doc(helmetId).set(update, { merge: true });
    console.log(`[DEV] Updated ${helmetId}:`, JSON.stringify(req.body));
    return res.json({ ok: true, helmetId });
  } catch (err) {
    console.error("[DEV] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Admin-authenticated routes ──────────────────────────────────────────────
// Unlike the device webhooks above (shared static secret), these routes are
// called by the Flutter app on behalf of a signed-in user and are authorized
// with a Firebase Auth ID token + the caller's Firestore `users/{uid}.role`.

async function requireAdmin(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!idToken) {
    return res.status(401).json({ error: "Missing ID token" });
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    const userSnap = await db.collection("users").doc(decoded.uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      console.warn(`[AUTH] uid=${decoded.uid} attempted admin route without admin role`);
      return res.status(403).json({ error: "Admin role required" });
    }
    req.uid = decoded.uid;
    next();
  } catch (err) {
    console.error("[AUTH] ID token verification failed:", err.message);
    return res.status(401).json({ error: "Invalid ID token" });
  }
}

// Same as requireAdmin but for any signed-in user — used by helmet claim/
// unclaim, which any worker may call for their own account, not just admins.
async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  if (!idToken) {
    return res.status(401).json({ error: "Missing ID token" });
  }
  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    req.uid = decoded.uid;
    next();
  } catch (err) {
    console.error("[AUTH] ID token verification failed:", err.message);
    return res.status(401).json({ error: "Invalid ID token" });
  }
}

// ─── Receiver provisioning (D3, D7) ──────────────────────────────────────────
// Generates a high-entropy raw credential, returned exactly once. Only its
// SHA-256 verifier hash is stored, in a server-only `private` subcollection
// (Firestore rules can't field-filter a single document, so the sensitive
// fields live in a doc no client rule ever grants read/write to).

app.post("/admin/receivers/provision", requireAdmin, async (req, res) => {
  const { hardwareId, label } = req.body || {};
  if (!hardwareId || typeof hardwareId !== "string") {
    return res.status(400).json({ error: "Missing hardwareId" });
  }

  try {
    const rawCredential = crypto.randomBytes(24).toString("base64url");
    const credentialVerifier = crypto.createHash("sha256").update(rawCredential).digest("hex");
    const now = admin.firestore.FieldValue.serverTimestamp();

    const receiverRef = db.collection("receivers").doc();
    await receiverRef.set({
      hardwareId,
      label: label || hardwareId,
      state: "active",
      lastSeen: null,
      provisionedAt: now,
      provisionedBy: req.uid,
    });
    await receiverRef.collection("private").doc("credential").set({
      credentialVerifier,
      credentialVersion: 1,
    });

    console.log(`[PROVISION] Receiver ${receiverRef.id} (hardwareId=${hardwareId}) provisioned by ${req.uid}`);
    // The raw credential is returned exactly once and never stored.
    return res.status(200).json({
      ok: true,
      receiverId: receiverRef.id,
      credential: rawCredential,
      credentialVersion: 1,
    });
  } catch (err) {
    console.error("[PROVISION] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// Revoke fails closed (D4): rejected on this instance immediately (cache
// evicted below), everywhere else within RECEIVER_CACHE_TTL_MS (D15).
app.post("/admin/receivers/:receiverId/revoke", requireAdmin, async (req, res) => {
  const { receiverId } = req.params;
  try {
    const receiverRef = db.collection("receivers").doc(receiverId);
    const snap = await receiverRef.get();
    if (!snap.exists) {
      return res.status(404).json({ error: "Receiver not found" });
    }
    await receiverRef.update({
      state: "revoked",
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      revokedBy: req.uid,
    });
    await receiverRef.collection("private").doc("credential").update({
      credentialVersion: admin.firestore.FieldValue.increment(1),
    });
    receiverCache.delete(receiverId);
    console.log(`[REVOKE] Receiver ${receiverId} revoked by ${req.uid}`);
    return res.status(200).json({ ok: true, receiverId, state: "revoked" });
  } catch (err) {
    console.error("[REVOKE] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Helmet pairing-code provisioning (D1, D2) ───────────────────────────────
// Mirrors receiver provisioning: an admin creates the helmet record and gets
// back a raw pairing code, shown exactly once, to print as a QR label before
// the helmet ships to a site. Only the code's SHA-256 hash is stored, in the
// same server-only `private` subcollection pattern used for receivers.
app.post("/admin/helmets/provision", requireAdmin, async (req, res) => {
  const { helmetId, label } = req.body || {};
  if (!helmetId || typeof helmetId !== "string") {
    return res.status(400).json({ error: "Missing helmetId" });
  }

  try {
    const helmetRef = db.collection("helmets").doc(helmetId);
    const existing = await helmetRef.get();
    if (existing.exists && existing.data().claimed) {
      return res.status(409).json({ error: "Helmet already claimed" });
    }

    const rawCode = crypto.randomBytes(9).toString("base64url"); // 12 chars, QR-friendly
    const pairingCodeHash = crypto.createHash("sha256").update(rawCode).digest("hex");
    const now = admin.firestore.FieldValue.serverTimestamp();

    await helmetRef.set({
      label: label || helmetId,
      claimed: false,
      claimedByUid: null,
      claimedAt: null,
      provisionedAt: now,
      provisionedBy: req.uid,
    }, { merge: true });
    await helmetRef.collection("private").doc("pairing").set({ pairingCodeHash });

    console.log(`[HELMET-PROVISION] ${helmetId} provisioned by ${req.uid}`);
    return res.status(200).json({ ok: true, helmetId, pairingCode: rawCode });
  } catch (err) {
    console.error("[HELMET-PROVISION] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Claim rate limiting (D12) ────────────────────────────────────────────────
// Same in-memory-per-instance caveat as the receiver credential cache (D15):
// bounded per function instance, not a perfect cross-instance guarantee in a
// serverless deployment — but it's a real, documented bound, not nothing.
const CLAIM_MAX_ATTEMPTS = 5;
const CLAIM_LOCKOUT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const claimAttempts = new Map(); // uid -> { count, windowStart }

function isClaimRateLimited(uid) {
  const entry = claimAttempts.get(uid);
  if (!entry) return false;
  if (Date.now() - entry.windowStart > CLAIM_LOCKOUT_WINDOW_MS) {
    claimAttempts.delete(uid);
    return false;
  }
  return entry.count >= CLAIM_MAX_ATTEMPTS;
}

function recordClaimFailure(uid) {
  const entry = claimAttempts.get(uid);
  if (!entry || Date.now() - entry.windowStart > CLAIM_LOCKOUT_WINDOW_MS) {
    claimAttempts.set(uid, { count: 1, windowStart: Date.now() });
  } else {
    entry.count++;
  }
}

// ─── Helmet claim (D1, D2, D11, D12) ─────────────────────────────────────────
// Single Firestore transaction: verify the pairing code, confirm the helmet
// isn't already claimed, mark it claimed, and delete the pairing doc so the
// code can never be reused. A second concurrent claimant loses the race and
// gets an explicit "already claimed" error, not a silent overwrite.
app.post("/helmets/:helmetId/claim", requireAuth, async (req, res) => {
  const { helmetId } = req.params;
  const { pairingCode } = req.body || {};
  if (!pairingCode || typeof pairingCode !== "string") {
    return res.status(400).json({ error: "Missing pairingCode" });
  }
  if (isClaimRateLimited(req.uid)) {
    console.warn(`[CLAIM] uid=${req.uid} rate-limited`);
    return res.status(429).json({ error: "Too many failed attempts. Try again later." });
  }

  try {
    const helmetRef = db.collection("helmets").doc(helmetId);
    const pairingRef = helmetRef.collection("private").doc("pairing");
    const userRef = db.collection("users").doc(req.uid);

    const result = await db.runTransaction(async (tx) => {
      const [helmetSnap, pairingSnap] = await Promise.all([tx.get(helmetRef), tx.get(pairingRef)]);

      if (!helmetSnap.exists || !pairingSnap.exists) return { outcome: "not_found" };
      if (helmetSnap.data().claimed) return { outcome: "already_claimed" };

      const providedHash = crypto.createHash("sha256").update(pairingCode).digest();
      const storedHash = Buffer.from(pairingSnap.data().pairingCodeHash, "hex");
      if (providedHash.length !== storedHash.length || !crypto.timingSafeEqual(providedHash, storedHash)) {
        return { outcome: "invalid_code" };
      }

      const now = admin.firestore.FieldValue.serverTimestamp();
      tx.update(helmetRef, { claimed: true, claimedByUid: req.uid, claimedAt: now });
      tx.delete(pairingRef); // invalidate the code — cannot be reused
      tx.set(userRef, { helmetIds: admin.firestore.FieldValue.arrayUnion(helmetId) }, { merge: true });
      return { outcome: "claimed" };
    });

    if (result.outcome === "claimed") {
      claimAttempts.delete(req.uid);
      console.log(`[CLAIM] ${helmetId} claimed by ${req.uid}`);
      return res.status(200).json({ ok: true, helmetId });
    }

    recordClaimFailure(req.uid);
    if (result.outcome === "already_claimed") {
      return res.status(409).json({ error: "Helmet already claimed" });
    }
    if (result.outcome === "not_found") {
      return res.status(404).json({ error: "Helmet not found or not provisioned" });
    }
    return res.status(403).json({ error: "Invalid pairing code" });
  } catch (err) {
    console.error("[CLAIM] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Helmet unclaim (D4) ──────────────────────────────────────────────────────
// Clears the server-side claim record (not just the client's helmetIds array),
// so the helmet becomes genuinely available again — an admin must re-provision
// a fresh pairing code before anyone can claim it, since the old code was
// deleted at claim time.
app.post("/helmets/:helmetId/unclaim", requireAuth, async (req, res) => {
  const { helmetId } = req.params;
  try {
    const helmetRef = db.collection("helmets").doc(helmetId);
    const userRef = db.collection("users").doc(req.uid);

    const result = await db.runTransaction(async (tx) => {
      const helmetSnap = await tx.get(helmetRef);
      if (!helmetSnap.exists) return { outcome: "not_found" };
      if (helmetSnap.data().claimedByUid !== req.uid) return { outcome: "not_owner" };

      tx.update(helmetRef, { claimed: false, claimedByUid: null, claimedAt: null });
      tx.set(userRef, { helmetIds: admin.firestore.FieldValue.arrayRemove(helmetId) }, { merge: true });
      return { outcome: "unclaimed" };
    });

    if (result.outcome === "unclaimed") {
      console.log(`[UNCLAIM] ${helmetId} released by ${req.uid}`);
      return res.status(200).json({ ok: true, helmetId });
    }
    if (result.outcome === "not_owner") {
      return res.status(403).json({ error: "You do not own this helmet" });
    }
    return res.status(404).json({ error: "Helmet not found" });
  } catch (err) {
    console.error("[UNCLAIM] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Admin bootstrap (one-time use) ──────────────────────────────────────────
// Creates the very first admin account (see spec-device-pairing-system.md, D16).
// `role` is intentionally never client-writable (firestore.rules), so some
// out-of-band mechanism has to grant the first admin — this is it. Gated by
// ADMIN_BOOTSTRAP_SECRET (set in .env, NOT the same secret as the webhook) and
// permanently disabled after first successful use via the system/bootstrap
// marker doc, checked and set inside one transaction so a second concurrent
// call can't also succeed.
const BOOTSTRAP_SECRET = process.env.ADMIN_BOOTSTRAP_SECRET || "";

app.post("/admin/bootstrap", async (req, res) => {
  if (!BOOTSTRAP_SECRET) {
    console.error("[BOOTSTRAP] ADMIN_BOOTSTRAP_SECRET is not configured. Rejecting request.");
    return res.status(500).json({ error: "Server misconfigured: no bootstrap secret" });
  }
  const token = req.headers["x-bootstrap-secret"] || "";
  if (token !== BOOTSTRAP_SECRET) {
    console.warn("[BOOTSTRAP] Invalid bootstrap secret");
    return res.status(403).json({ error: "Forbidden" });
  }

  const { uid, email } = req.body || {};
  if (!uid && !email) {
    return res.status(400).json({ error: "Provide uid or email" });
  }

  try {
    let targetUid = uid;
    if (!targetUid) {
      const userRecord = await admin.auth().getUserByEmail(email);
      targetUid = userRecord.uid;
    }

    const bootstrapRef = db.collection("system").doc("bootstrap");
    const userRef = db.collection("users").doc(targetUid);

    const result = await db.runTransaction(async (tx) => {
      const bootstrapSnap = await tx.get(bootstrapRef);
      if (bootstrapSnap.exists && bootstrapSnap.data().used) {
        return { alreadyUsed: true };
      }
      tx.set(userRef, { role: "admin" }, { merge: true });
      tx.set(bootstrapRef, {
        used: true,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        usedByUid: targetUid,
      });
      return { alreadyUsed: false };
    });

    if (result.alreadyUsed) {
      console.warn("[BOOTSTRAP] Rejected: already used");
      return res.status(410).json({ error: "Bootstrap already used" });
    }

    console.log(`[BOOTSTRAP] Granted admin role to uid=${targetUid}`);
    return res.status(200).json({ ok: true, uid: targetUid });
  } catch (err) {
    console.error("[BOOTSTRAP] Error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// Health-check
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// ─── Start server ───────────────────────────────────────────────────────────
// Render sets PORT itself; local dev falls back to 3000.
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`[HELIX] Server running on port ${PORT}`);
  console.log(`[HELIX] LoRa P2P endpoint:   POST /lora-uplink`);
  console.log(`[HELIX] ChirpStack endpoint: POST /chirpstack-webhook`);
});
