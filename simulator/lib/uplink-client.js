'use strict';

/**
 * POST /lora-uplink client — builds the exact request shape the real
 * receiver firmware sends (see spec-data-flow-simulator.md, "Protocol
 * Fidelity" field reference) and reports back enough detail for the live
 * log/status views: whether the request itself succeeded, the HTTP status,
 * the parsed JSON body (which tells the caller if this uplink was
 * `throttled`), and round-trip time.
 *
 * Uses Node's built-in fetch (Node 22) — no extra HTTP dependency.
 */

async function sendUplink({ backendUrl, receiver, helmetId, lat, lng, alt, speed, heading, battery, rssi, snr, satellites }) {
  const url = `${backendUrl.replace(/\/+$/, '')}/lora-uplink`;
  const body = {
    helmetId,
    lat,
    lng,
    alt,
    speed,
    heading,
    battery,
    rssi,
    snr,
    satellites,
  };

  const sentAt = Date.now();
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Receiver-Id': receiver.receiverId,
        'X-Receiver-Credential': receiver.credential,
      },
      body: JSON.stringify(body),
    });

    const durationMs = Date.now() - sentAt;
    let parsed = null;
    let parseError = null;
    const text = await res.text();
    try {
      parsed = text ? JSON.parse(text) : null;
    } catch (e) {
      parseError = `Response was not valid JSON: ${text.slice(0, 200)}`;
    }

    return {
      ok: res.ok,
      status: res.status,
      body: parsed,
      parseError,
      error: null,
      durationMs,
      sentAt,
      request: body,
    };
  } catch (err) {
    return {
      ok: false,
      status: null,
      body: null,
      parseError: null,
      error: err.message || String(err),
      durationMs: Date.now() - sentAt,
      sentAt,
      request: body,
    };
  }
}

module.exports = { sendUplink };
