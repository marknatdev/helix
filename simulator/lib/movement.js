'use strict';

/**
 * Telemetry generators — produce lat/lng/heading/speed/battery/signal for
 * one simulated helmet, one tick at a time.
 *
 * The random-walk model is a direct port of firmware/sender/sender.ino's
 * stepFakeGps() (±15°/tick heading jitter, constant speed, equirectangular
 * lat/lng step) so simulated movement matches what real hardware produces
 * when it has no GPS fix. See spec-data-flow-simulator.md, "Movement &
 * Telemetry Models".
 */

const METERS_PER_DEGREE_LAT = 111111;
const MIN_COS_LAT = 0.01; // sender.ino clamps the same way near the poles

function toRad(deg) { return (deg * Math.PI) / 180; }

/**
 * Random-walk generator. `movement` is a normalized config from
 * config-schema.js's withDefaults(): { startLat, startLng, startHeading,
 * speed, headingJitterDeg }.
 */
function createRandomWalk(movement) {
  let lat = movement.startLat;
  let lng = movement.startLng;
  let heading = movement.startHeading;
  const jitter = movement.headingJitterDeg;
  const speed = movement.speed;

  return function tick(intervalMs) {
    const intervalS = intervalMs / 1000;
    heading += (Math.random() * 2 - 1) * jitter;
    if (heading < 0) heading += 360;
    if (heading > 360) heading -= 360;

    const dist = speed * intervalS; // meters
    const rad = toRad(heading);
    lat += (dist * Math.cos(rad)) / METERS_PER_DEGREE_LAT;
    let cosLat = Math.cos(toRad(lat));
    if (cosLat < MIN_COS_LAT) cosLat = MIN_COS_LAT;
    lng += (dist * Math.sin(rad)) / (METERS_PER_DEGREE_LAT * cosLat);

    return { lat, lng, heading, speed };
  };
}

/**
 * Waypoint-interpolation generator. `movement` is normalized:
 * { points: [{lat,lng}, ...], speed, loop }. Walks the polyline at a
 * constant speed; stops at the final point unless `loop` is set, in which
 * case it wraps back to the first point.
 */
function createWaypointWalk(movement) {
  const points = movement.points;
  const speed = movement.speed;
  const loop = movement.loop;
  let segIndex = 0;
  let segProgressM = 0; // meters walked into the current segment
  let finished = false;

  function segmentLengthM(a, b) {
    // Equirectangular approximation, consistent with the random-walk model
    // above — fine at the sub-kilometer scale this tool operates at.
    const cosLat = Math.max(Math.cos(toRad((a.lat + b.lat) / 2)), MIN_COS_LAT);
    const dLatM = (b.lat - a.lat) * METERS_PER_DEGREE_LAT;
    const dLngM = (b.lng - a.lng) * METERS_PER_DEGREE_LAT * cosLat;
    return Math.hypot(dLatM, dLngM);
  }

  function headingOf(a, b) {
    const cosLat = Math.max(Math.cos(toRad((a.lat + b.lat) / 2)), MIN_COS_LAT);
    const dLatM = (b.lat - a.lat) * METERS_PER_DEGREE_LAT;
    const dLngM = (b.lng - a.lng) * METERS_PER_DEGREE_LAT * cosLat;
    let h = (Math.atan2(dLngM, dLatM) * 180) / Math.PI;
    if (h < 0) h += 360;
    return h;
  }

  return function tick(intervalMs) {
    if (finished) {
      const last = points[points.length - 1];
      return { lat: last.lat, lng: last.lng, heading: 0, speed: 0 };
    }

    const intervalS = intervalMs / 1000;
    let remainingM = speed * intervalS;
    let a = points[segIndex];
    let b = points[segIndex + 1];
    let segLenM = segmentLengthM(a, b);

    while (remainingM > 0) {
      const left = segLenM - segProgressM;
      if (remainingM < left) {
        segProgressM += remainingM;
        remainingM = 0;
      } else {
        remainingM -= left;
        segIndex += 1;
        segProgressM = 0;
        if (segIndex >= points.length - 1) {
          if (loop) {
            segIndex = 0;
          } else {
            finished = true;
            const last = points[points.length - 1];
            return { lat: last.lat, lng: last.lng, heading: 0, speed: 0 };
          }
        }
        a = points[segIndex];
        b = points[segIndex + 1];
        segLenM = segmentLengthM(a, b);
      }
    }

    const frac = segLenM === 0 ? 0 : segProgressM / segLenM;
    const lat = a.lat + (b.lat - a.lat) * frac;
    const lng = a.lng + (b.lng - a.lng) * frac;
    const heading = headingOf(a, b);
    return { lat, lng, heading, speed };
  };
}

function createMovementGenerator(movement) {
  return movement.type === 'waypoints' ? createWaypointWalk(movement) : createRandomWalk(movement);
}

/**
 * Battery drifts linearly by `driftPerTick` percent each tick, clamped to
 * [0, 100]. driftPerTick is typically <= 0 (or 0 for a constant reading).
 */
function createBatteryGenerator(battery) {
  let pct = battery.start;
  return function tick() {
    pct = Math.max(0, Math.min(100, pct + battery.driftPerTick));
    return Math.round(pct * 10) / 10;
  };
}

/**
 * RSSI wobbles around a baseline by +/- jitter dBm each tick — models the
 * kind of signal-strength noise real hardware sees from multipath/distance
 * changes, without any directional drift.
 */
function createSignalGenerator(signal) {
  return function tick() {
    const rssi = signal.rssiStart + (Math.random() * 2 - 1) * signal.jitter;
    return Math.round(rssi * 10) / 10;
  };
}

module.exports = {
  createMovementGenerator,
  createBatteryGenerator,
  createSignalGenerator,
};
