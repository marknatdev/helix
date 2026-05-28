/**
 * functions/index.js
 * ────────────────────────────────────────────────────────────────────────────
 * Standalone Express server that receives ChirpStack HTTP integration webhooks
 * (uplink events), decodes CayenneLPP telemetry, and writes to Firestore.
 *
 * Run locally:  node index.js
 * ChirpStack config:
 *   POST  http://host.docker.internal:3000/chirpstack-webhook
 *   Header: X-Webhook-Token: <WEBHOOK_SECRET>
 * ────────────────────────────────────────────────────────────────────────────
 */

require("dotenv").config();
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");
const path = require("path");

// ─── Firebase Admin init with service account key ────────────────────────────
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
  || path.join(__dirname, "smhelmet-67-firebase-adminsdk-fbsvc-5cfc7ee572.json");
admin.initializeApp({
  credential: admin.credential.cert(require(serviceAccountPath)),
});
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
  // 1) Validate shared secret — ALWAYS required
  if (!WEBHOOK_SECRET) {
    console.error("[AUTH] WEBHOOK_SECRET is not configured. Rejecting request.");
    return res.status(500).json({ error: "Server misconfigured: no webhook secret" });
  }
  const token = req.headers["x-webhook-token"] || "";
  if (token !== WEBHOOK_SECRET) {
    console.warn("[AUTH] Invalid webhook token");
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
  // 1) Validate shared secret
  if (!WEBHOOK_SECRET) {
    console.error("[AUTH] WEBHOOK_SECRET is not configured. Rejecting request.");
    return res.status(500).json({ error: "Server misconfigured: no webhook secret" });
  }
  const token = req.headers["x-webhook-token"] || "";
  if (token !== WEBHOOK_SECRET) {
    console.warn("[AUTH] Invalid webhook token");
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

// Health-check
app.get("/health", (_req, res) => res.json({ status: "ok" }));

// ─── Start server ───────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`[HELIX] Webhook server running on http://localhost:${PORT}`);
  console.log(`[HELIX] LoRa P2P endpoint:   POST http://localhost:${PORT}/lora-uplink`);
  console.log(`[HELIX] ChirpStack endpoint: POST http://localhost:${PORT}/chirpstack-webhook`);
});
