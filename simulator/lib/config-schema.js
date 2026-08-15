'use strict';

/**
 * Config schema, defaults, and validation for the simulator.
 * See spec-data-flow-simulator.md, "Fleet Configuration & Receiver Mapping"
 * and "Movement & Telemetry Models" for the field reference this mirrors.
 *
 * Shape:
 * {
 *   backendUrl: string,
 *   intervalMs: number,
 *   receivers: [{ id, receiverId, credential, label }],
 *   helmets: [{
 *     helmetId, receiverRef, intervalMs?,
 *     movement: randomWalkConfig | waypointsConfig,
 *     battery: { start, driftPerTick },
 *     signal: { rssiStart, jitter },
 *     altitude?, satellites?
 *   }]
 * }
 */

const DEFAULT_BACKEND_URL = 'https://helix-webhook.onrender.com';
const DEFAULT_INTERVAL_MS = 10000;

function emptyConfig() {
  return {
    backendUrl: DEFAULT_BACKEND_URL,
    intervalMs: DEFAULT_INTERVAL_MS,
    receivers: [],
    helmets: [],
  };
}

/**
 * Validate a raw config object. Returns { valid, errors } — collects every
 * problem found rather than failing on the first, since this backs the web
 * UI's raw-JSON-editor validation (a user fixing one typo at a time from a
 * fail-fast error is a bad editing loop).
 */
function validateConfig(raw) {
  const errors = [];
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    return { valid: false, errors: ['Config must be a JSON object'] };
  }

  if (raw.backendUrl !== undefined && typeof raw.backendUrl !== 'string') {
    errors.push('backendUrl must be a string');
  }
  if (raw.intervalMs !== undefined && !isPositiveNumber(raw.intervalMs)) {
    errors.push('intervalMs must be a positive number');
  }

  const receivers = Array.isArray(raw.receivers) ? raw.receivers : [];
  if (raw.receivers !== undefined && !Array.isArray(raw.receivers)) {
    errors.push('receivers must be an array');
  }
  const receiverIds = new Set();
  receivers.forEach((r, i) => {
    const p = `receivers[${i}]`;
    if (!r || typeof r !== 'object') {
      errors.push(`${p} must be an object`);
      return;
    }
    if (!isNonEmptyString(r.id)) errors.push(`${p}.id is required (local reference id)`);
    else if (receiverIds.has(r.id)) errors.push(`${p}.id "${r.id}" is duplicated`);
    else receiverIds.add(r.id);
    if (!isNonEmptyString(r.receiverId)) errors.push(`${p}.receiverId is required (from /admin/receivers/provision)`);
    if (!isNonEmptyString(r.credential)) errors.push(`${p}.credential is required (raw credential from /admin/receivers/provision)`);
  });

  const helmets = Array.isArray(raw.helmets) ? raw.helmets : [];
  if (raw.helmets !== undefined && !Array.isArray(raw.helmets)) {
    errors.push('helmets must be an array');
  }
  const helmetIds = new Set();
  helmets.forEach((h, i) => {
    const p = `helmets[${i}]`;
    if (!h || typeof h !== 'object') {
      errors.push(`${p} must be an object`);
      return;
    }
    if (!isNonEmptyString(h.helmetId)) errors.push(`${p}.helmetId is required`);
    else if (helmetIds.has(h.helmetId)) errors.push(`${p}.helmetId "${h.helmetId}" is duplicated`);
    else helmetIds.add(h.helmetId);

    if (!isNonEmptyString(h.receiverRef)) errors.push(`${p}.receiverRef is required`);
    else if (!receiverIds.has(h.receiverRef)) errors.push(`${p}.receiverRef "${h.receiverRef}" does not match any receivers[].id`);

    if (h.intervalMs !== undefined && !isPositiveNumber(h.intervalMs)) {
      errors.push(`${p}.intervalMs must be a positive number if set`);
    }

    validateMovement(h.movement, p, errors);

    if (h.battery !== undefined) {
      if (!h.battery || typeof h.battery !== 'object') {
        errors.push(`${p}.battery must be an object if set`);
      } else {
        if (h.battery.start !== undefined && !isNumberInRange(h.battery.start, 0, 100)) {
          errors.push(`${p}.battery.start must be 0-100`);
        }
        if (h.battery.driftPerTick !== undefined && typeof h.battery.driftPerTick !== 'number') {
          errors.push(`${p}.battery.driftPerTick must be a number`);
        }
      }
    }

    if (h.signal !== undefined) {
      if (!h.signal || typeof h.signal !== 'object') {
        errors.push(`${p}.signal must be an object if set`);
      } else {
        if (h.signal.rssiStart !== undefined && typeof h.signal.rssiStart !== 'number') {
          errors.push(`${p}.signal.rssiStart must be a number (dBm)`);
        }
        if (h.signal.jitter !== undefined && !isPositiveOrZeroNumber(h.signal.jitter)) {
          errors.push(`${p}.signal.jitter must be >= 0`);
        }
      }
    }
  });

  return { valid: errors.length === 0, errors };
}

function validateMovement(movement, p, errors) {
  if (!movement || typeof movement !== 'object') {
    errors.push(`${p}.movement is required`);
    return;
  }
  if (movement.type === 'randomWalk') {
    if (!isNumber(movement.startLat) || !isNumber(movement.startLng)) {
      errors.push(`${p}.movement.startLat/startLng are required for randomWalk`);
    }
    if (movement.speed !== undefined && !isPositiveOrZeroNumber(movement.speed)) {
      errors.push(`${p}.movement.speed must be >= 0`);
    }
    if (movement.headingJitterDeg !== undefined && !isPositiveOrZeroNumber(movement.headingJitterDeg)) {
      errors.push(`${p}.movement.headingJitterDeg must be >= 0`);
    }
  } else if (movement.type === 'waypoints') {
    if (!Array.isArray(movement.points) || movement.points.length < 2) {
      errors.push(`${p}.movement.points must be an array of at least 2 {lat,lng} points`);
    } else {
      movement.points.forEach((pt, j) => {
        if (!pt || !isNumber(pt.lat) || !isNumber(pt.lng)) {
          errors.push(`${p}.movement.points[${j}] must be {lat, lng} numbers`);
        }
      });
    }
    if (movement.speed !== undefined && !isPositiveOrZeroNumber(movement.speed)) {
      errors.push(`${p}.movement.speed must be >= 0`);
    }
  } else {
    errors.push(`${p}.movement.type must be "randomWalk" or "waypoints"`);
  }
}

/**
 * Fill in defaults for a config already confirmed valid by validateConfig.
 * Never call on an unvalidated config — this does not re-check invariants
 * like receiverRef resolution.
 */
function withDefaults(raw) {
  const cfg = {
    backendUrl: raw.backendUrl || DEFAULT_BACKEND_URL,
    intervalMs: raw.intervalMs || DEFAULT_INTERVAL_MS,
    receivers: (raw.receivers || []).map((r) => ({ ...r })),
    helmets: (raw.helmets || []).map((h) => ({
      helmetId: h.helmetId,
      receiverRef: h.receiverRef,
      intervalMs: h.intervalMs || null,
      movement: withMovementDefaults(h.movement),
      battery: { start: 90, driftPerTick: 0, ...(h.battery || {}) },
      signal: { rssiStart: -70, jitter: 3, ...(h.signal || {}) },
      altitude: typeof h.altitude === 'number' ? h.altitude : 0,
      satellites: typeof h.satellites === 'number' ? h.satellites : 8,
    })),
  };
  return cfg;
}

function withMovementDefaults(movement) {
  if (movement.type === 'randomWalk') {
    return {
      type: 'randomWalk',
      startLat: movement.startLat,
      startLng: movement.startLng,
      startHeading: movement.startHeading || 0,
      speed: movement.speed !== undefined ? movement.speed : 1.5,
      headingJitterDeg: movement.headingJitterDeg !== undefined ? movement.headingJitterDeg : 15,
    };
  }
  return {
    type: 'waypoints',
    points: movement.points.map((p) => ({ lat: p.lat, lng: p.lng })),
    speed: movement.speed !== undefined ? movement.speed : 1.5,
    loop: movement.loop === true,
  };
}

function isNumber(v) { return typeof v === 'number' && Number.isFinite(v); }
function isPositiveNumber(v) { return isNumber(v) && v > 0; }
function isPositiveOrZeroNumber(v) { return isNumber(v) && v >= 0; }
function isNumberInRange(v, min, max) { return isNumber(v) && v >= min && v <= max; }
function isNonEmptyString(v) { return typeof v === 'string' && v.trim().length > 0; }

module.exports = {
  DEFAULT_BACKEND_URL,
  DEFAULT_INTERVAL_MS,
  emptyConfig,
  validateConfig,
  withDefaults,
};
