'use strict';

/**
 * Simulator web UI — single source of truth is `state.config`, an in-memory
 * object matching lib/config-schema.js's shape. The Form view and Raw JSON
 * view both read/write it, so switching tabs never loses edits.
 */

const state = {
  config: null,
  running: false,
  pickingWaypointFor: null, // helmet index currently capturing map clicks as waypoints, or null
};

let map, markersByHelmet = {};

// ─── Bootstrap ──────────────────────────────────────────────────────────────

async function init() {
  const res = await fetch('/api/config/default');
  state.config = await res.json();
  document.getElementById('backendUrl').value = state.config.backendUrl;
  document.getElementById('intervalMs').value = state.config.intervalMs;

  initMap();
  renderForm();
  refreshConfigList();
  wireTopbar();
  wireConfigIO();
  wireViewToggle();
  connectWebSocket();
  refreshRunStatus();
}

function initMap() {
  map = L.map('map').setView([13.7563, 100.5018], 16);
  L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; OpenStreetMap &copy; CARTO',
    maxZoom: 19,
  }).addTo(map);

  map.on('click', (e) => {
    if (state.pickingWaypointFor === null) return;
    const helmet = state.config.helmets[state.pickingWaypointFor];
    if (!helmet || helmet.movement.type !== 'waypoints') return;
    helmet.movement.points = helmet.movement.points || [];
    helmet.movement.points.push({ lat: round5(e.latlng.lat), lng: round5(e.latlng.lng) });
    renderForm();
  });
}

function round5(n) { return Math.round(n * 1e5) / 1e5; }

// ─── Top bar ────────────────────────────────────────────────────────────────

function wireTopbar() {
  document.getElementById('backendUrl').addEventListener('change', (e) => {
    state.config.backendUrl = e.target.value;
  });
  document.getElementById('intervalMs').addEventListener('change', (e) => {
    state.config.intervalMs = Number(e.target.value) || state.config.intervalMs;
  });
  document.getElementById('btnStart').addEventListener('click', startRun);
  document.getElementById('btnStop').addEventListener('click', stopRun);
}

async function startRun() {
  syncFromActiveView();
  const res = await fetch('/api/run/start', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(state.config),
  });
  const body = await res.json();
  if (!res.ok) {
    showConfigError((body.errors || [body.error]).join('; '));
    return;
  }
  showConfigError('');
}

async function stopRun() {
  await fetch('/api/run/stop', { method: 'POST' });
}

function setRunning(running) {
  state.running = running;
  document.getElementById('btnStart').disabled = running;
  document.getElementById('btnStop').disabled = !running;
  const el = document.getElementById('runState');
  el.textContent = running ? 'Running' : 'Idle';
  el.className = 'run-state' + (running ? ' running' : '');
}

async function refreshRunStatus() {
  const res = await fetch('/api/run/status');
  const body = await res.json();
  setRunning(body.running);
  body.snapshot.forEach(applyTick);
}

// ─── View toggle (Form / Raw JSON) ─────────────────────────────────────────

function wireViewToggle() {
  document.getElementById('btnFormView').addEventListener('click', () => switchView('form'));
  document.getElementById('btnJsonView').addEventListener('click', () => switchView('json'));
  document.getElementById('btnApplyJson').addEventListener('click', applyJsonView);
}

function switchView(view) {
  syncFromActiveView();
  document.getElementById('btnFormView').classList.toggle('active', view === 'form');
  document.getElementById('btnJsonView').classList.toggle('active', view === 'json');
  document.getElementById('formView').classList.toggle('hidden', view !== 'form');
  document.getElementById('jsonView').classList.toggle('hidden', view !== 'json');
  if (view === 'form') renderForm();
  else document.getElementById('jsonEditor').value = JSON.stringify(state.config, null, 2);
}

/** If the JSON view is currently active, nothing to sync — the form view
 * already writes straight into state.config on every field change. This
 * exists so Start/Save/tab-switch always sees the latest edits regardless
 * of which view is open. */
function syncFromActiveView() {
  const jsonVisible = !document.getElementById('jsonView').classList.contains('hidden');
  if (jsonVisible) {
    try {
      state.config = JSON.parse(document.getElementById('jsonEditor').value);
      showConfigError('');
    } catch (e) {
      showConfigError('Raw JSON is invalid: ' + e.message);
    }
  }
}

async function applyJsonView() {
  let parsed;
  try {
    parsed = JSON.parse(document.getElementById('jsonEditor').value);
  } catch (e) {
    showConfigError('Invalid JSON: ' + e.message);
    return;
  }
  const res = await fetch('/api/config/validate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(parsed),
  });
  const { valid, errors } = await res.json();
  if (!valid) {
    showConfigError(errors.join('; '));
    return;
  }
  state.config = parsed;
  document.getElementById('backendUrl').value = state.config.backendUrl || '';
  document.getElementById('intervalMs').value = state.config.intervalMs || '';
  showConfigError('');
  switchView('form');
}

function showConfigError(msg) {
  document.getElementById('configError').textContent = msg;
}

// ─── Config save/load ───────────────────────────────────────────────────────

function wireConfigIO() {
  document.getElementById('btnSave').addEventListener('click', saveConfig);
  document.getElementById('btnLoad').addEventListener('click', loadConfig);
}

async function saveConfig() {
  syncFromActiveView();
  let name = document.getElementById('configName').value.trim();
  if (!name) { showConfigError('Enter a config name to save.'); return; }
  if (!name.endsWith('.json')) name += '.json';
  const res = await fetch(`/api/configs/${encodeURIComponent(name)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(state.config),
  });
  const body = await res.json();
  if (!res.ok) {
    showConfigError((body.errors || [body.error]).join('; '));
    return;
  }
  showConfigError('');
  refreshConfigList();
}

async function refreshConfigList() {
  const res = await fetch('/api/configs');
  const files = await res.json();
  const select = document.getElementById('configList');
  select.innerHTML = '<option value="">Load saved…</option>' +
    files.map((f) => `<option value="${f}">${f}</option>`).join('');
}

async function loadConfig() {
  const name = document.getElementById('configList').value;
  if (!name) return;
  const res = await fetch(`/api/configs/${encodeURIComponent(name)}`);
  if (!res.ok) { showConfigError('Could not load config'); return; }
  state.config = await res.json();
  document.getElementById('backendUrl').value = state.config.backendUrl || '';
  document.getElementById('intervalMs').value = state.config.intervalMs || '';
  document.getElementById('configName').value = name;
  renderForm();
}

// ─── Form view rendering ────────────────────────────────────────────────────

function renderForm() {
  renderReceivers();
  renderHelmets();
  document.getElementById('btnAddReceiver').onclick = addReceiver;
  document.getElementById('btnAddHelmet').onclick = addHelmet;
}

function addReceiver() {
  state.config.receivers.push({ id: `r${state.config.receivers.length + 1}`, receiverId: '', credential: '', label: '' });
  renderForm();
}

function removeReceiver(i) {
  state.config.receivers.splice(i, 1);
  renderForm();
}

function renderReceivers() {
  const list = document.getElementById('receiverList');
  list.innerHTML = '';
  state.config.receivers.forEach((r, i) => {
    const card = document.createElement('div');
    card.className = 'entry-card';
    card.innerHTML = `
      <div class="entry-card-header"><strong>Receiver ${i + 1}</strong><button class="remove-btn">Remove</button></div>
      <div class="field-row">
        <div class="field"><label>Local id (referenced by helmets)</label><input data-f="id" value="${esc(r.id)}"></div>
        <div class="field"><label>Label</label><input data-f="label" value="${esc(r.label || '')}"></div>
      </div>
      <div class="field-row">
        <div class="field"><label>receiverId</label><input data-f="receiverId" value="${esc(r.receiverId)}"></div>
        <div class="field"><label>credential</label><input data-f="credential" value="${esc(r.credential)}"></div>
      </div>`;
    card.querySelector('.remove-btn').onclick = () => removeReceiver(i);
    card.querySelectorAll('input').forEach((input) => {
      input.addEventListener('change', (e) => { r[e.target.dataset.f] = e.target.value; });
    });
    list.appendChild(card);
  });
}

function addHelmet() {
  state.config.helmets.push({
    helmetId: `HLX-SIM-${String(state.config.helmets.length + 1).padStart(3, '0')}`,
    receiverRef: state.config.receivers[0]?.id || '',
    movement: { type: 'randomWalk', startLat: 13.7563, startLng: 100.5018, startHeading: 0, speed: 1.5, headingJitterDeg: 15 },
    battery: { start: 90, driftPerTick: 0 },
    signal: { rssiStart: -70, jitter: 3 },
    altitude: 0,
    satellites: 8,
  });
  renderForm();
}

function removeHelmet(i) {
  state.config.helmets.splice(i, 1);
  if (state.pickingWaypointFor === i) state.pickingWaypointFor = null;
  renderForm();
}

function renderHelmets() {
  const list = document.getElementById('helmetList');
  list.innerHTML = '';
  const receiverOptions = state.config.receivers
    .map((r) => `<option value="${esc(r.id)}">${esc(r.label || r.id)}</option>`).join('');

  state.config.helmets.forEach((h, i) => {
    const card = document.createElement('div');
    card.className = 'entry-card';
    const isWaypoints = h.movement.type === 'waypoints';
    card.innerHTML = `
      <div class="entry-card-header"><strong>${esc(h.helmetId) || 'Helmet ' + (i + 1)}</strong><button class="remove-btn">Remove</button></div>
      <div class="field-row">
        <div class="field"><label>helmetId</label><input data-f="helmetId" value="${esc(h.helmetId)}"></div>
        <div class="field"><label>Receiver</label>
          <select data-f="receiverRef">${receiverOptions}</select>
        </div>
      </div>
      <div class="field-row">
        <div class="field"><label>Movement</label>
          <select data-f="movementType">
            <option value="randomWalk" ${!isWaypoints ? 'selected' : ''}>Random walk</option>
            <option value="waypoints" ${isWaypoints ? 'selected' : ''}>Waypoint route</option>
          </select>
        </div>
        <div class="field"><label>Speed (m/s)</label><input data-f="speed" type="number" step="0.1" value="${h.movement.speed}"></div>
      </div>
      <div class="movement-fields"></div>
      <div class="field-row">
        <div class="field"><label>Battery start %</label><input data-f="batteryStart" type="number" min="0" max="100" value="${h.battery.start}"></div>
        <div class="field"><label>Battery drift/tick</label><input data-f="batteryDrift" type="number" step="0.01" value="${h.battery.driftPerTick}"></div>
      </div>
      <div class="field-row">
        <div class="field"><label>RSSI baseline (dBm)</label><input data-f="rssiStart" type="number" value="${h.signal.rssiStart}"></div>
        <div class="field"><label>RSSI jitter</label><input data-f="rssiJitter" type="number" min="0" value="${h.signal.jitter}"></div>
      </div>`;

    const movementFieldsEl = card.querySelector('.movement-fields');
    renderMovementFields(movementFieldsEl, h, i);

    card.querySelector('.remove-btn').onclick = () => removeHelmet(i);
    card.querySelector('[data-f="helmetId"]').addEventListener('change', (e) => { h.helmetId = e.target.value; });
    card.querySelector('[data-f="receiverRef"]').addEventListener('change', (e) => { h.receiverRef = e.target.value; });
    card.querySelector('[data-f="speed"]').addEventListener('change', (e) => { h.movement.speed = Number(e.target.value); });
    card.querySelector('[data-f="movementType"]').addEventListener('change', (e) => {
      h.movement = e.target.value === 'waypoints'
        ? { type: 'waypoints', points: [], speed: h.movement.speed, loop: false }
        : { type: 'randomWalk', startLat: 13.7563, startLng: 100.5018, startHeading: 0, speed: h.movement.speed, headingJitterDeg: 15 };
      renderForm();
    });
    card.querySelector('[data-f="batteryStart"]').addEventListener('change', (e) => { h.battery.start = Number(e.target.value); });
    card.querySelector('[data-f="batteryDrift"]').addEventListener('change', (e) => { h.battery.driftPerTick = Number(e.target.value); });
    card.querySelector('[data-f="rssiStart"]').addEventListener('change', (e) => { h.signal.rssiStart = Number(e.target.value); });
    card.querySelector('[data-f="rssiJitter"]').addEventListener('change', (e) => { h.signal.jitter = Number(e.target.value); });

    list.appendChild(card);
  });
}

function renderMovementFields(el, h, helmetIndex) {
  if (h.movement.type === 'randomWalk') {
    el.innerHTML = `
      <div class="field-row">
        <div class="field"><label>Start lat</label><input data-mf="startLat" type="number" step="0.00001" value="${h.movement.startLat}"></div>
        <div class="field"><label>Start lng</label><input data-mf="startLng" type="number" step="0.00001" value="${h.movement.startLng}"></div>
      </div>
      <div class="field-row">
        <div class="field"><label>Start heading (deg)</label><input data-mf="startHeading" type="number" value="${h.movement.startHeading}"></div>
        <div class="field"><label>Heading jitter (deg/tick)</label><input data-mf="headingJitterDeg" type="number" min="0" value="${h.movement.headingJitterDeg}"></div>
      </div>`;
    el.querySelector('[data-mf="startLat"]').addEventListener('change', (e) => { h.movement.startLat = Number(e.target.value); });
    el.querySelector('[data-mf="startLng"]').addEventListener('change', (e) => { h.movement.startLng = Number(e.target.value); });
    el.querySelector('[data-mf="startHeading"]').addEventListener('change', (e) => { h.movement.startHeading = Number(e.target.value); });
    el.querySelector('[data-mf="headingJitterDeg"]').addEventListener('change', (e) => { h.movement.headingJitterDeg = Number(e.target.value); });
  } else {
    const picking = state.pickingWaypointFor === helmetIndex;
    const points = h.movement.points || [];
    el.innerHTML = `
      <div class="field-row single">
        <button class="btn small pick-btn" type="button">${picking ? 'Click map to add… (click again to stop)' : 'Pick on map'}</button>
      </div>
      <div class="waypoint-list">
        ${points.map((p, j) => `
          <div class="waypoint-row" data-idx="${j}">
            <span>#${j + 1}</span>
            <input data-wf="lat" type="number" step="0.00001" value="${p.lat}">
            <input data-wf="lng" type="number" step="0.00001" value="${p.lng}">
            <button class="remove-btn" data-remove="${j}">×</button>
          </div>`).join('')}
      </div>
      <label class="field" style="flex-direction:row; align-items:center; gap:6px;">
        <input type="checkbox" data-mf="loop" ${h.movement.loop ? 'checked' : ''} style="width:auto;"> Loop back to first point
      </label>`;
    el.querySelector('.pick-btn').addEventListener('click', () => {
      state.pickingWaypointFor = picking ? null : helmetIndex;
      renderForm();
    });
    el.querySelectorAll('.waypoint-row').forEach((row) => {
      const j = Number(row.dataset.idx);
      row.querySelector('[data-wf="lat"]').addEventListener('change', (e) => { points[j].lat = Number(e.target.value); });
      row.querySelector('[data-wf="lng"]').addEventListener('change', (e) => { points[j].lng = Number(e.target.value); });
      row.querySelector('[data-remove]').addEventListener('click', () => { points.splice(j, 1); renderForm(); });
    });
    el.querySelector('[data-mf="loop"]').addEventListener('change', (e) => { h.movement.loop = e.target.checked; });
  }
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

// ─── WebSocket live view ────────────────────────────────────────────────────

function connectWebSocket() {
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  const ws = new WebSocket(`${proto}://${location.host}/ws`);
  ws.addEventListener('message', (event) => {
    const msg = JSON.parse(event.data);
    if (msg.type === 'status') {
      setRunning(msg.running);
      msg.snapshot.forEach(applyTick);
    } else if (msg.type === 'tick') {
      applyTick(msg);
    } else if (msg.type === 'run-started') {
      setRunning(true);
    } else if (msg.type === 'run-stopped') {
      setRunning(false);
    }
  });
  ws.addEventListener('close', () => setTimeout(connectWebSocket, 1500));
}

function applyTick(payload) {
  updateStatusRow(payload);
  updateMapMarker(payload);
  appendLog(payload);
}

function resultSummary(result) {
  if (result.error) return { text: `error: ${result.error}`, cls: 'status-err' };
  if (!result.ok) return { text: `HTTP ${result.status}`, cls: 'status-err' };
  if (result.body && result.body.throttled) return { text: '200 (throttled)', cls: 'status-throttled' };
  return { text: `200${result.body && result.body.alertCount ? ` (${result.body.alertCount} alert${result.body.alertCount === 1 ? '' : 's'})` : ''}`, cls: 'status-ok' };
}

function updateStatusRow(payload) {
  const tbody = document.querySelector('#statusTable tbody');
  let row = tbody.querySelector(`tr[data-helmet="${cssEscape(payload.helmetId)}"]`);
  if (!row) {
    row = document.createElement('tr');
    row.dataset.helmet = payload.helmetId;
    row.innerHTML = '<td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>';
    tbody.appendChild(row);
  }
  const req = payload.request || {};
  const derivedStatus = req.speed === 0 ? 'idle' : 'active';
  const summary = resultSummary(payload.result);
  const cells = row.children;
  cells[0].textContent = payload.helmetId;
  cells[1].textContent = payload.receiverLabel || '—';
  cells[2].textContent = derivedStatus;
  cells[3].textContent = req.lat !== undefined ? req.lat.toFixed(5) : '—';
  cells[4].textContent = req.lng !== undefined ? req.lng.toFixed(5) : '—';
  cells[5].textContent = req.battery !== undefined ? `${req.battery}%` : '—';
  cells[6].textContent = req.rssi !== undefined ? `${req.rssi} dBm` : '—';
  cells[7].textContent = summary.text;
  cells[7].className = summary.cls;
}

function cssEscape(s) { return String(s).replace(/["\\]/g, '\\$&'); }

function updateMapMarker(payload) {
  const req = payload.request;
  if (!req || req.lat === undefined) return;
  let marker = markersByHelmet[payload.helmetId];
  if (!marker) {
    marker = L.circleMarker([req.lat, req.lng], { radius: 7, color: '#ffb547', fillColor: '#ffb547', fillOpacity: 0.8 })
      .bindTooltip(payload.helmetId, { permanent: false });
    marker.addTo(map);
    markersByHelmet[payload.helmetId] = marker;
  } else {
    marker.setLatLng([req.lat, req.lng]);
  }
}

const MAX_LOG_LINES = 200;
function appendLog(payload) {
  const log = document.getElementById('log');
  const line = document.createElement('div');
  const summary = resultSummary(payload.result);
  line.className = 'log-line' + (summary.cls === 'status-err' ? ' err' : '');
  const ts = new Date(payload.result.sentAt || Date.now()).toLocaleTimeString();
  const reqStr = payload.request ? JSON.stringify(payload.request) : '(no request built)';
  const resStr = payload.result.error
    ? `ERROR: ${payload.result.error}`
    : JSON.stringify(payload.result.body);
  line.innerHTML = `<span class="ts">${ts}</span><strong>${esc(payload.helmetId)}</strong> → ${esc(reqStr)} ⇐ ${esc(resStr)} (${payload.result.durationMs}ms)`;
  log.prepend(line);
  while (log.children.length > MAX_LOG_LINES) log.removeChild(log.lastChild);
}

init();
