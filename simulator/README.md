# HELIX Helmet Simulator

A standalone local web app that impersonates a real HELIX LoRa receiver — generating configurable telemetry for one or more virtual helmets and POSTing it through the real `POST /lora-uplink` path, exactly like the real receiver firmware does. See [`../spec-data-flow-simulator.md`](../spec-data-flow-simulator.md) for the full design and decisions.

```
[Web UI] ──WebSocket──▶ [Express server + sim runner] ──POST /lora-uplink──▶ [helix-webhook] ──▶ [Firestore] ──▶ [Real dashboard]
```

## Important: this writes to real production data

There is no staging environment for HELIX. Simulated helmets write real documents to production Firestore (`helmets/*`, `alerts/*`, `zones/*.containment`) and appear in the real dashboard exactly like a real worker's helmet. Use a clearly-named test helmet ID (e.g. `HLX-SIM-001`) and clean it up manually when done — this tool has no admin access and does not delete anything itself.

## Setup

1. **Provision a receiver and a helmet through the real admin flow first** — this tool has no admin login of its own (by design, see the spec's "Security & Environment" section):
   - `POST /admin/receivers/provision` (as an admin) → gives you `{receiverId, credential}`. **The credential is returned once — save it.**
   - `POST /admin/helmets/provision` (as an admin) → gives you a `helmetId` and pairing code. The helmet does not need to be *claimed* by a user for telemetry ingestion to work — only provisioned.
2. Install dependencies:
   ```bash
   cd simulator
   npm install
   ```
3. Run:
   ```bash
   npm start
   ```
   Opens on `http://localhost:8090`.

## Using the UI

1. In the **Configuration** panel, add a **Receiver** with the `receiverId`/`credential` from step 1 above.
2. Add a **Helmet**, set its `helmetId` to the one you provisioned, pick the receiver you just added, and choose a movement model:
   - **Random walk** — mirrors the real firmware's fake-GPS mode (start position, speed, heading jitter).
   - **Waypoint route** — click "Pick on map" then click points on the live map, or type lat/lng directly.
3. Click **Start**. The Live View shows a status table, the helmets moving on the map, and a raw request/response log of every `/lora-uplink` call.
4. Click **Stop** to end the run. Nothing is cleaned up automatically — see above.

Configs can be saved/loaded by name (stored as JSON files in `configs/`, gitignored). The **Raw JSON** tab lets you edit the whole config as text — useful for bulk edits or scripting up a fleet.

## Known scope boundaries (see the spec for rationale)

- No SOS simulation — the real `/lora-uplink` protocol has no field that ever sets an SOS status.
- No named "trigger alert" presets — reach battery/signal/geofence alert thresholds by configuring values or routes yourself.
- No admin auth, no Firebase SDK — this is a pure `/lora-uplink` HTTP client, same trust boundary as one extra physical receiver.
