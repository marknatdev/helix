'use strict';

/**
 * HELIX Helmet Simulator — standalone local app.
 * Serves the config-builder/live-view web UI, runs the simulation (one
 * timer per virtual helmet POSTing to the real /lora-uplink endpoint), and
 * streams live results to connected browsers over WebSocket.
 *
 * See spec-data-flow-simulator.md for the full design. No Firebase SDK or
 * admin auth dependency by design (D14) — this is a pure /lora-uplink HTTP
 * client, same trust boundary as a real receiver.
 */

const path = require('path');
const fs = require('fs/promises');
const express = require('express');
const { WebSocketServer } = require('ws');

const { emptyConfig, validateConfig, withDefaults } = require('./lib/config-schema');
const { SimulationRunner } = require('./lib/runner');

const PORT = process.env.PORT || 8090;
const CONFIGS_DIR = path.join(__dirname, 'configs');

const app = express();
app.use(express.json({ limit: '2mb' }));
app.use(express.static(path.join(__dirname, 'public')));

let runner = null; // single active SimulationRunner, or null

// ─── Config helpers ───────────────────────────────────────────────────────

/** Prevent path traversal via a config name coming from the browser. */
function safeConfigPath(name) {
  const base = path.basename(String(name || ''));
  if (!base || base !== name || !/^[\w.\-]+\.json$/.test(base)) return null;
  return path.join(CONFIGS_DIR, base);
}

app.get('/api/config/default', (_req, res) => {
  res.json(emptyConfig());
});

app.post('/api/config/validate', (req, res) => {
  const { valid, errors } = validateConfig(req.body);
  res.json({ valid, errors });
});

app.get('/api/configs', async (_req, res) => {
  try {
    const files = await fs.readdir(CONFIGS_DIR);
    res.json(files.filter((f) => f.endsWith('.json')));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/configs/:name', async (req, res) => {
  const p = safeConfigPath(req.params.name);
  if (!p) return res.status(400).json({ error: 'Invalid config name' });
  try {
    const text = await fs.readFile(p, 'utf8');
    res.json(JSON.parse(text));
  } catch (err) {
    res.status(404).json({ error: `Could not read config: ${err.message}` });
  }
});

app.post('/api/configs/:name', async (req, res) => {
  const p = safeConfigPath(req.params.name);
  if (!p) return res.status(400).json({ error: 'Invalid config name' });
  const { valid, errors } = validateConfig(req.body);
  if (!valid) return res.status(400).json({ error: 'Config is invalid', errors });
  try {
    await fs.mkdir(CONFIGS_DIR, { recursive: true });
    await fs.writeFile(p, JSON.stringify(req.body, null, 2), 'utf8');
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── Run control ──────────────────────────────────────────────────────────

app.post('/api/run/start', (req, res) => {
  if (runner && runner.isRunning()) {
    return res.status(409).json({ error: 'A simulation is already running. Stop it first.' });
  }
  const { valid, errors } = validateConfig(req.body);
  if (!valid) return res.status(400).json({ error: 'Config is invalid', errors });

  const config = withDefaults(req.body);
  runner = new SimulationRunner(config);
  wireRunnerToWebSocket(runner);
  runner.start();
  res.json({ ok: true });
});

app.post('/api/run/stop', (_req, res) => {
  if (runner) runner.stop();
  res.json({ ok: true });
});

app.get('/api/run/status', (_req, res) => {
  res.json({
    running: !!runner && runner.isRunning(),
    snapshot: runner ? runner.snapshot() : [],
  });
});

// ─── HTTP + WebSocket server ────────────────────────────────────────────────

const server = app.listen(PORT, () => {
  console.log(`[SIM] HELIX Helmet Simulator running on http://localhost:${PORT}`);
});

const wss = new WebSocketServer({ server, path: '/ws' });
const wsClients = new Set();

wss.on('connection', (ws) => {
  wsClients.add(ws);
  ws.on('close', () => wsClients.delete(ws));

  // Bring a newly-connected client up to date immediately.
  ws.send(JSON.stringify({
    type: 'status',
    running: !!runner && runner.isRunning(),
    snapshot: runner ? runner.snapshot() : [],
  }));
});

function broadcast(message) {
  const text = JSON.stringify(message);
  for (const ws of wsClients) {
    if (ws.readyState === ws.OPEN) ws.send(text);
  }
}

/** Subscribe a runner's events to the WebSocket broadcast. Only one runner
 * is ever active at a time (see /api/run/start's 409 guard above), so
 * listeners are not explicitly removed between runs — the old runner is
 * simply discarded (stopped, no more ticks, garbage collected). */
function wireRunnerToWebSocket(r) {
  r.on('tick', (payload) => broadcast({ type: 'tick', ...payload }));
  r.on('started', () => broadcast({ type: 'run-started' }));
  r.on('stopped', () => broadcast({ type: 'run-stopped' }));
}
