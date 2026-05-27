# HELIX GPS Map Simulator

A modern, web-based interactive GPS map simulator that models a smart helmet node. Pick coordinates visually by clicking on the map, adjust sensors/signals, and stream live telemetry straight to your local webhook server (`/lora-uplink` endpoint).

```
[Web Map Simulator]  ──HTTP POST (CORS)──▶  [Local Express Webhook]  ──▶  [Firestore]  ──▶  [Flutter App]
```

## Features

- **Interactive Leaflet Map** — visually click or drag the helmet marker anywhere in the world to instantly update telemetry.
- **CartoDB Dark Matter** tiles for a high-tech command center visual design.
- **10 Thai City Presets** (Bangkok, Chiang Mai, Phuket, Pattaya, etc.) to quickly teleport.
- **3 Simulation Modes**:
  - **Manual** — update coordinates by clicking or dragging.
  - **Auto-Walk** — automatically walk continuously in the direction of the `heading` slider.
  - **Route** — double-click any point on the map to set a Destination waypoint. The simulator will automatically compute the path and animate the helmet node step-by-step along the route.
- **Sensor Controls** — customize battery, satellites, RSSI, and SNR on the fly.
- **Signal Jitter** — auto-jitter toggles to add realistic fluctuations to RSSI and SNR.
- **Transmission Panel** — configure sending interval, toggle live transmission, or trigger manual immediate uplinks.
- **Real-Time Logs** — inspect every network payload and HTTP response code in the scrolling console.

## Setup & Running

No complex Python packages or dependencies are required. The simulator runs on standard libraries.

1. **Start the local webhook server** first:
   ```powershell
   cd d:\helix\functions
   node index.js
   ```

2. **Start the Web Simulator**:
   ```powershell
   cd d:\helix\simulator
   python main.py
   ```
   *This starts a local lightweight HTTP server on port `8080` and automatically opens your default browser to `http://localhost:8080`.*

## Usage

1. **Configure Webhook** — default is `http://localhost:3000/lora-uplink` with token `smarthelmet`.
2. **Select Location** — click anywhere on the dark map or click a Thai preset to place the helmet.
3. **Double Click to Route** — double-click anywhere on the map to drop a red target marker and animate the helmet towards it.
4. **Tune Sliders** — customize battery, speed, heading, interval, etc.
5. Click **▶ Start Telemetry** to start the continuous updates.

## Files

| File | Purpose |
|---|---|
| `main.py` | Starts local Python HTTP server and opens browser |
| `index.html` | Front-end Leaflet map UI, simulation engine, and API client |
