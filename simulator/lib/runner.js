'use strict';

const { EventEmitter } = require('events');
const { createMovementGenerator, createBatteryGenerator, createSignalGenerator } = require('./movement');
const { sendUplink } = require('./uplink-client');

/**
 * Runs a simulation: one timer per configured helmet, each tick generating
 * telemetry and POSTing it to the real backend. Emits events the WebSocket
 * layer (server.js) broadcasts to connected browsers — this module has no
 * knowledge of WebSocket/HTTP serving, only of running the simulation.
 *
 * Events:
 *   'tick'    ({ helmetId, receiverLabel, request, result })  — after every uplink attempt
 *   'started' ()
 *   'stopped' ()
 */
class SimulationRunner extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.timers = new Map(); // helmetId -> intervalId
    this.latest = new Map(); // helmetId -> last tick payload, for late-joining WS clients
    this.running = false;
  }

  start() {
    if (this.running) return;
    this.running = true;

    const receiversById = new Map(this.config.receivers.map((r) => [r.id, r]));

    for (const helmet of this.config.helmets) {
      const receiver = receiversById.get(helmet.receiverRef);
      if (!receiver) {
        // Should not happen if config passed validateConfig, but fail loud
        // rather than silently skip a helmet if it does.
        this.emit('tick', {
          helmetId: helmet.helmetId,
          receiverLabel: null,
          request: null,
          result: { ok: false, status: null, body: null, error: `No receiver found for receiverRef "${helmet.receiverRef}"`, durationMs: 0, sentAt: Date.now() },
        });
        continue;
      }

      const moveTick = createMovementGenerator(helmet.movement);
      const batteryTick = createBatteryGenerator(helmet.battery);
      const signalTick = createSignalGenerator(helmet.signal);
      const intervalMs = helmet.intervalMs || this.config.intervalMs;

      const fireTick = async () => {
        const { lat, lng, heading, speed } = moveTick(intervalMs);
        const battery = batteryTick();
        const rssi = signalTick();

        const result = await sendUplink({
          backendUrl: this.config.backendUrl,
          receiver,
          helmetId: helmet.helmetId,
          lat,
          lng,
          alt: helmet.altitude,
          speed,
          heading,
          battery,
          rssi,
          snr: 0,
          satellites: helmet.satellites,
        });

        const payload = { helmetId: helmet.helmetId, receiverLabel: receiver.label || receiver.receiverId, request: result.request, result };
        this.latest.set(helmet.helmetId, payload);
        this.emit('tick', payload);
      };

      // Fire immediately so the UI shows data right away, then on interval.
      fireTick();
      this.timers.set(helmet.helmetId, setInterval(fireTick, intervalMs));
    }

    this.emit('started');
  }

  stop() {
    if (!this.running) return;
    for (const id of this.timers.values()) clearInterval(id);
    this.timers.clear();
    this.running = false;
    this.emit('stopped');
  }

  isRunning() {
    return this.running;
  }

  /** Snapshot of the most recent tick per helmet, for clients that connect mid-run. */
  snapshot() {
    return Array.from(this.latest.values());
  }
}

module.exports = { SimulationRunner };
