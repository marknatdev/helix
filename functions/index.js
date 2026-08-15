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

// ─── Known-helmet cache ───────────────────────────────────────────────────────
// /lora-uplink used to `.set(doc, {merge:true})` on whatever helmetId the
// request body contained, which silently creates a new Firestore doc (and
// consumes a write) for any string — a leaked/rogue receiver credential
// could spam-create arbitrary garbage helmets, and nothing tied the
// telemetry to a helmet that was ever actually provisioned. Helmets must
// now already exist (via /admin/helmets/provision, or the admin dev tool)
// before they'll accept telemetry. Existence is cached in-memory with a TTL
// to avoid a Firestore read on every uplink; a helmet that's provisioned
// mid-cache-window just waits out the TTL before its first uplink lands.
const KNOWN_HELMET_TTL_MS = 5 * 60 * 1000; // 5 minutes
const knownHelmets = new Map(); // helmetId -> expiresAt

async function helmetExists(helmetId) {
  const expiresAt = knownHelmets.get(helmetId);
  if (expiresAt && expiresAt > Date.now()) return true;

  const snap = await db.collection("helmets").doc(helmetId).get();
  if (!snap.exists) return false;
  knownHelmets.set(helmetId, Date.now() + KNOWN_HELMET_TTL_MS);
  return true;
}

// ─── Telemetry write throttling ────────────────────────────────────────────────
// The receiver posts every ~10s; writing every uplink straight to Firestore
// burns through Spark's free daily write quota fast (2 helmets alone is
// already ~85% of the 20k/day quota at that cadence — see the D17 rollout
// review). Routine position/telemetry writes are throttled to once per
// TELEMETRY_MIN_WRITE_INTERVAL_MS per helmet; a status change or an
// alert-worthy reading (low battery / weak signal) always writes
// immediately regardless of the throttle, so safety responsiveness isn't
// affected — only the cadence of routine "still here, still fine" updates.
const TELEMETRY_MIN_WRITE_INTERVAL_MS = Number(process.env.TELEMETRY_MIN_WRITE_INTERVAL_MS) || 30 * 1000;
const lastTelemetryWrite = new Map(); // helmetId -> { at, status }

function shouldWriteTelemetry(helmetId, status, alertWorthy) {
  const prior = lastTelemetryWrite.get(helmetId);
  if (!prior) return true;
  if (prior.status !== status) return true;
  if (alertWorthy) return true;
  return Date.now() - prior.at >= TELEMETRY_MIN_WRITE_INTERVAL_MS;
}

// ─── Zone geofence containment ─────────────────────────────────────────────
// Zones are created/assigned by any signed-in owner (of the helmet being
// assigned) via the /zones routes below — never written directly by clients
// (firestore.rules locks the collection to server-only writes, matching the
// helmets/alerts pattern). Each zone doc carries its own `assignedHelmetIds`
// array (for the array-contains lookup below) and a `containment` map of
// helmetId -> last-known inside/outside bool, so a containment *transition*
// can be detected on the next uplink without a second collection.
const ZONE_CACHE_TTL_MS = 30 * 1000; // matches RECEIVER_CACHE_TTL_MS/claim cache
const zoneAssignmentsCache = new Map(); // helmetId -> { at, zones: [{id, ...data}] }

async function getZoneAssignments(helmetId) {
  const cached = zoneAssignmentsCache.get(helmetId);
  if (cached && Date.now() - cached.at < ZONE_CACHE_TTL_MS) return cached.zones;

  const snap = await db.collection("zones")
    .where("assignedHelmetIds", "array-contains", helmetId)
    .get();
  const zones = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  zoneAssignmentsCache.set(helmetId, { at: Date.now(), zones });
  return zones;
}

function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/** Compute containment for every zone this helmet is assigned to. Returns
 * whether any zone changed containment state (used to bypass the telemetry
 * write throttle, same as a low-battery/weak-signal reading) plus the list
 * of transitions to alert on and persist. Deliberately read-only — does NOT
 * mutate the cached zone objects. The caller only commits transitions to
 * Firestore after `shouldWriteTelemetry` clears and the write actually
 * succeeds; mutating the cache here would mark a transition "seen" even if
 * the uplink is throttled or the commit fails, permanently losing it for
 * the rest of this cache entry's TTL. */
async function checkGeofences(helmetId, lat, lng) {
  const zones = await getZoneAssignments(helmetId);
  const transitions = [];
  for (const zone of zones) {
    if (typeof zone.centerLat !== "number" || typeof zone.centerLng !== "number" ||
        typeof zone.radiusM !== "number") continue;
    const nowContained = haversineMeters(lat, lng, zone.centerLat, zone.centerLng) <= zone.radiusM;
    const priorContained = (zone.containment || {})[helmetId];
    if (priorContained === undefined) {
      // First reading since assignment — record state, don't alert (we don't
      // know which direction the helmet crossed the boundary, if at all).
      transitions.push({ zoneId: zone.id, zoneName: zone.name, nowContained, silent: true });
    } else if (priorContained !== nowContained) {
      transitions.push({ zoneId: zone.id, zoneName: zone.name, nowContained, silent: false });
    }
  }
  return { alertWorthy: transitions.some((t) => !t.silent), transitions };
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

/** Create an alert for a helmet unless an unresolved one of the same kind
 * already exists within the cooldown window. */
async function maybeAlert(batch, helmetId, kind, message, now) {
  const cutoff = new Date(Date.now() - ALERT_COOLDOWN_MS);
  const existing = await db.collection("alerts")
    .where("helmetId", "==", helmetId)
    .where("kind", "==", kind)
    .where("resolved", "==", false)
    .where("ts", ">=", cutoff)
    .limit(1)
    .get();
  if (!existing.empty) return false; // skip duplicate
  const alertRef = db.collection("alerts").doc();
  batch.set(alertRef, {
    helmetId,
    worker: "",
    kind,
    message,
    ts: now,
    resolved: false,
  });
  return true;
}

// ─── LoRa uplink endpoint (from receiver board) ──────────────────────────────
// The receiver POSTs a flat JSON object; this is the only ingestion path.

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

  // 2) Reject telemetry for helmets that were never provisioned — closes
  // off arbitrary-doc creation from a rogue/leaked receiver credential.
  if (!(await helmetExists(helmetId))) {
    console.warn(`[AUTH] lora-uplink rejected: unknown helmetId=${helmetId} (receiver=${auth.receiverId})`);
    return res.status(404).json({ error: "Unknown helmetId" });
  }

  // 3) Extract fields (receiver already parsed the binary struct)
  const rssi = typeof body.rssi === "number" ? body.rssi : -120;
  const snr  = typeof body.snr  === "number" ? body.snr  : 0;
  const signal = rssiToPercent(rssi);
  const battery = typeof body.battery === "number" ? body.battery : -1;
  const lat = typeof body.lat === "number" ? body.lat : 0;
  const lng = typeof body.lng === "number" ? body.lng : 0;

  let status = "active";
  if (body.speed === 0) {
    status = "idle";
  }

  // Geofence containment must be checked before the throttle decision below —
  // a zone-boundary crossing has to bypass the throttle the same way a
  // low-battery/weak-signal reading does, or transitions up to
  // TELEMETRY_MIN_WRITE_INTERVAL_MS old could go unwritten.
  const geo = await checkGeofences(helmetId, lat, lng);

  const alertWorthy = (battery >= 0 && battery < 20) || signal < 30 || geo.alertWorthy;
  if (!shouldWriteTelemetry(helmetId, status, alertWorthy)) {
    return res.status(200).json({ ok: true, helmetId, throttled: true });
  }
  lastTelemetryWrite.set(helmetId, { at: Date.now(), status });

  const now = admin.firestore.FieldValue.serverTimestamp();

  const doc = {
    helmetId,
    lat,
    lng,
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
    // 4) Upsert helmet doc
    await db.collection("helmets").doc(helmetId).set(doc, { merge: true });

    // 5) Generate alerts if needed
    const alertsBatch = db.batch();
    let alertCount = 0;

    if (battery >= 0 && battery < 20) {
      if (await maybeAlert(alertsBatch, helmetId, "battery", `Battery critically low: ${battery}%`, now)) alertCount++;
    }
    if (signal < 30) {
      if (await maybeAlert(alertsBatch, helmetId, "offline", `Weak LoRa signal: ${signal}% (RSSI ${rssi} dBm)`, now)) alertCount++;
    }
    for (const t of geo.transitions) {
      alertsBatch.set(db.collection("zones").doc(t.zoneId), {
        containment: { [helmetId]: t.nowContained },
        updatedAt: now,
      }, { merge: true });
      if (!t.silent) {
        const msg = t.nowContained
          ? `Entered zone "${t.zoneName}"`
          : `Exited zone "${t.zoneName}"`;
        // NOTE: maybeAlert dedupes by (helmetId, kind, resolved:false,
        // ts>=cooldown) only — it doesn't know about zoneId. A helmet
        // crossing two zone boundaries in the same uplink will only get one
        // "geofence" alert recorded; the second maybeAlert call below
        // returns false as a (spurious) duplicate. Acceptable for a
        // single-zone-per-helmet v1; revisit (add zoneId to the dedupe
        // query, which needs a new composite index) if overlapping zone
        // assignments become common.
        if (await maybeAlert(alertsBatch, helmetId, "geofence", msg, now)) alertCount++;
      }
    }

    if (alertCount > 0 || geo.transitions.length > 0) await alertsBatch.commit();
    // Cache held the pre-transition containment map; drop it so the next
    // uplink re-reads the just-committed state from Firestore instead of
    // re-detecting the same transition as "still pending".
    if (geo.transitions.length > 0) zoneAssignmentsCache.delete(helmetId);

    console.log(`[P2P] ${helmetId}  lat=${doc.lat} lng=${doc.lng} bat=${battery}% sig=${signal}% rssi=${rssi}`);
    return res.status(200).json({ ok: true, helmetId, alertCount });
  } catch (err) {
    console.error("[ERR] Firestore write failed:", err);
    return res.status(500).json({ error: "Internal error" });
  }
});

// ─── Dev config endpoint (admin dev tool) ────────────────────────────────────
// Updates helmet fields (location, status, battery, etc.) directly. Gated by
// the same requireAdmin role check as every other privileged route below —
// no separate shared-secret trust model for this one dev tool.

app.post("/dev-config", requireAdmin, async (req, res) => {
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

// ─── Claim rate limiting (D10, D12) ──────────────────────────────────────────
// Backed by a `rateLimits` Firestore collection so an attempt count survives
// a Render restart/cold-start instead of living only in a Map that a
// redeploy wipes. An in-memory cache sits in front and is synced to
// Firestore only on a failed attempt or a cache miss — not on every claim
// check — so this stays cheap relative to the Spark plan's write quota.
const CLAIM_MAX_ATTEMPTS = 5;
const CLAIM_LOCKOUT_WINDOW_MS = 15 * 60 * 1000; // 15 minutes
const CLAIM_CACHE_TTL_MS = 30 * 1000; // 30 seconds
const claimAttemptsCache = new Map(); // uid -> { count, windowStart, expiresAt }

function isExpiredWindow(entry) {
  return !entry || Date.now() - entry.windowStart > CLAIM_LOCKOUT_WINDOW_MS;
}

async function getClaimAttemptRecord(uid) {
  const cached = claimAttemptsCache.get(uid);
  if (cached && cached.expiresAt > Date.now()) return cached;

  const snap = await db.collection("rateLimits").doc(uid).get();
  const record = snap.exists
    ? { count: snap.data().count, windowStart: snap.data().windowStart.toMillis(), expiresAt: Date.now() + CLAIM_CACHE_TTL_MS }
    : null;
  if (record) claimAttemptsCache.set(uid, record);
  return record;
}

async function isClaimRateLimited(uid) {
  const entry = await getClaimAttemptRecord(uid);
  if (isExpiredWindow(entry)) return false;
  return entry.count >= CLAIM_MAX_ATTEMPTS;
}

async function recordClaimFailure(uid) {
  const entry = await getClaimAttemptRecord(uid);
  const next = isExpiredWindow(entry)
    ? { count: 1, windowStart: Date.now() }
    : { count: entry.count + 1, windowStart: entry.windowStart };

  claimAttemptsCache.set(uid, { ...next, expiresAt: Date.now() + CLAIM_CACHE_TTL_MS });
  await db.collection("rateLimits").doc(uid).set({
    count: next.count,
    windowStart: new Date(next.windowStart),
  });
}

async function clearClaimAttempts(uid) {
  claimAttemptsCache.delete(uid);
  await db.collection("rateLimits").doc(uid).delete();
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
  if (await isClaimRateLimited(req.uid)) {
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
      await clearClaimAttempts(req.uid);
      console.log(`[CLAIM] ${helmetId} claimed by ${req.uid}`);
      return res.status(200).json({ ok: true, helmetId });
    }

    await recordClaimFailure(req.uid);
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

// ─── Zones (geofence containment) ────────────────────────────────────────────
// Any signed-in user may create a zone and assign/unassign it to helmets they
// own — firestore.rules locks the `zones` collection to server-only writes
// (read: isAuthed(), same as `alerts`), so every mutation goes through here
// with Admin SDK rather than a client-writable rule, even though the
// permission model itself ("any owner") is permissive.

app.post("/zones", requireAuth, async (req, res) => {
  const { name, kind, centerLat, centerLng, radiusM } = req.body || {};
  if (!name || typeof name !== "string") {
    return res.status(400).json({ error: "Missing name" });
  }
  if (typeof centerLat !== "number" || typeof centerLng !== "number") {
    return res.status(400).json({ error: "Missing centerLat/centerLng" });
  }
  if (typeof radiusM !== "number" || radiusM <= 0) {
    return res.status(400).json({ error: "radiusM must be a positive number" });
  }
  try {
    const now = admin.firestore.FieldValue.serverTimestamp();
    const zoneRef = db.collection("zones").doc();
    await zoneRef.set({
      name,
      kind: typeof kind === "string" && kind ? kind : "operational",
      centerLat,
      centerLng,
      radiusM,
      assignedHelmetIds: [],
      containment: {},
      createdBy: req.uid,
      createdAt: now,
      updatedAt: now,
    });
    return res.status(200).json({ ok: true, zoneId: zoneRef.id });
  } catch (err) {
    console.error("[ZONES] create error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

app.patch("/zones/:zoneId", requireAuth, async (req, res) => {
  const { zoneId } = req.params;
  const { name, kind, centerLat, centerLng, radiusM } = req.body || {};
  try {
    const zoneRef = db.collection("zones").doc(zoneId);
    const zoneSnap = await zoneRef.get();
    if (!zoneSnap.exists) return res.status(404).json({ error: "Zone not found" });
    if (zoneSnap.data().createdBy !== req.uid) {
      const userSnap = await db.collection("users").doc(req.uid).get();
      if (!userSnap.exists || userSnap.data().role !== "admin") {
        return res.status(403).json({ error: "Only the zone's creator or an admin may edit it" });
      }
    }
    const patch = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    if (typeof name === "string" && name) patch.name = name;
    if (typeof kind === "string" && kind) patch.kind = kind;
    if (typeof centerLat === "number") patch.centerLat = centerLat;
    if (typeof centerLng === "number") patch.centerLng = centerLng;
    if (typeof radiusM === "number" && radiusM > 0) patch.radiusM = radiusM;
    await zoneRef.update(patch);
    return res.status(200).json({ ok: true, zoneId });
  } catch (err) {
    console.error("[ZONES] update error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

app.post("/zones/:zoneId/delete", requireAuth, async (req, res) => {
  const { zoneId } = req.params;
  try {
    const zoneRef = db.collection("zones").doc(zoneId);
    const zoneSnap = await zoneRef.get();
    if (!zoneSnap.exists) return res.status(404).json({ error: "Zone not found" });
    if (zoneSnap.data().createdBy !== req.uid) {
      const userSnap = await db.collection("users").doc(req.uid).get();
      if (!userSnap.exists || userSnap.data().role !== "admin") {
        return res.status(403).json({ error: "Only the zone's creator or an admin may delete it" });
      }
    }
    await zoneRef.delete();
    return res.status(200).json({ ok: true, zoneId });
  } catch (err) {
    console.error("[ZONES] delete error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

// A caller may only assign/unassign helmets they themselves have claimed —
// mirrors the ownership check in /helmets/:helmetId/unclaim above.
async function assertOwnsHelmet(req, res, helmetId) {
  const helmetSnap = await db.collection("helmets").doc(helmetId).get();
  if (!helmetSnap.exists) {
    res.status(404).json({ error: "Helmet not found" });
    return false;
  }
  if (helmetSnap.data().claimedByUid !== req.uid) {
    res.status(403).json({ error: "You do not own this helmet" });
    return false;
  }
  return true;
}

app.post("/zones/:zoneId/assign", requireAuth, async (req, res) => {
  const { zoneId } = req.params;
  const { helmetId } = req.body || {};
  if (!helmetId || typeof helmetId !== "string") {
    return res.status(400).json({ error: "Missing helmetId" });
  }
  try {
    if (!(await assertOwnsHelmet(req, res, helmetId))) return;
    const zoneRef = db.collection("zones").doc(zoneId);
    const zoneSnap = await zoneRef.get();
    if (!zoneSnap.exists) return res.status(404).json({ error: "Zone not found" });
    await zoneRef.update({
      assignedHelmetIds: admin.firestore.FieldValue.arrayUnion(helmetId),
      // Clear any stale containment reading from a prior assignment — without
      // this, a re-assign after unassign would compare the next uplink
      // against old state instead of treating it as a first reading.
      [`containment.${helmetId}`]: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    zoneAssignmentsCache.delete(helmetId); // force a fresh read on next uplink
    return res.status(200).json({ ok: true, zoneId, helmetId });
  } catch (err) {
    console.error("[ZONES] assign error:", err.message);
    return res.status(500).json({ error: "Internal error" });
  }
});

app.post("/zones/:zoneId/unassign", requireAuth, async (req, res) => {
  const { zoneId } = req.params;
  const { helmetId } = req.body || {};
  if (!helmetId || typeof helmetId !== "string") {
    return res.status(400).json({ error: "Missing helmetId" });
  }
  try {
    if (!(await assertOwnsHelmet(req, res, helmetId))) return;
    const zoneRef = db.collection("zones").doc(zoneId);
    const zoneSnap = await zoneRef.get();
    if (!zoneSnap.exists) return res.status(404).json({ error: "Zone not found" });
    await zoneRef.update({
      assignedHelmetIds: admin.firestore.FieldValue.arrayRemove(helmetId),
      [`containment.${helmetId}`]: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    zoneAssignmentsCache.delete(helmetId);
    return res.status(200).json({ ok: true, zoneId, helmetId });
  } catch (err) {
    console.error("[ZONES] unassign error:", err.message);
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
  console.log(`[HELIX] LoRa uplink endpoint: POST /lora-uplink`);
});
