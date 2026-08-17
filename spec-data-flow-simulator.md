# Smart Helmet Simulator (Data-Flow Simulator)

**Status:** Draft for review
**Preview:** https://claude.ai/code/artifact/1c6ddc98-85e2-46d8-976d-f08ef1a52eae
**Captured at commit:** `9a7c48e` (branch `feature/validation-fixes`)
**Supersedes:** `simulator/` (Python stdlib server + static Leaflet page), deleted in commit `f9492d2`. See [Prior Art](#prior-art) below.

## Overview

A standalone local web app that impersonates a real HELIX LoRa receiver — generating configurable telemetry for one or more virtual helmets and POSTing it through the exact same `POST /lora-uplink` path the real firmware uses, with a live web UI to build the run configuration and watch it happen in real time.

This is spec 2 of the two-spec sequence recorded in `spec-overview.md`: spec 1 (device pairing system — receiver credentials, per-receiver auth, helmet provisioning/claim flow) has since shipped, which is what makes this spec buildable — the simulator authenticates using exactly the receiver-credential scheme spec 1 introduced.

## Goals

- Let a developer manually test or demo dashboard behavior (fleet view, alerts, zones) by driving real backend traffic, without ESP32 hardware.
- Exercise the *actual* ingestion pipeline: receiver auth, the telemetry write-throttle, battery/signal alerts, and geofence containment transitions — not a shortcut that bypasses them (unlike the existing `dev_config_page.dart` "simulate walk" toggle, which writes straight to Firestore).
- Support configuring every part of a simulated helmet's behavior: identity, movement, cadence, receiver mapping.

## Non-Goals

- Not a CI/automated test fixture and not a load-testing tool — this is a manual QA/demo tool.
- Not a faithful simulation of the LoRa radio layer — there is no radio to simulate in software; the tool models the HTTP boundary a real receiver produces.
- No SOS simulation — the real `/lora-uplink` protocol has no field that ever sets an `"sos"` status (see [Scope Boundaries](#cadence-runtime--scope-boundaries)).
- No automated data cleanup/teardown of simulated Firestore documents.
- No admin-credential handling of any kind inside the tool (see [Security & Environment](#security--environment)).
- No named "trigger alert" presets — alert conditions (low battery, weak signal, geofence crossing) are reached by configuring values/routes, not by a dedicated button.

## Prior Art

An earlier, simpler simulator existed at `simulator/` (Python `http.server` serving a single static `index.html` with an embedded Leaflet map) and was deleted in commit `f9492d2`. It supported:

- A single simulated helmet, position set by click/drag on a Leaflet map (CartoDB Dark Matter tiles).
- Manual / Auto-Walk (heading-driven) / Route (double-click waypoint) modes.
- Sliders for battery, satellites, RSSI, SNR, with optional jitter.
- POSTed directly from browser JS (`fetch`, CORS) to a local webhook, authenticated with a single shared `X-Webhook-Token` — the shared-token scheme that predated spec 1's per-receiver credential system.

This spec's design is a direct evolution of that tool: same core interaction ideas (Leaflet map, manual/route/auto-walk-style movement, sensor sliders, live log), but re-architected as a proper client/server app (Express + WebSocket instead of a static page hitting the webhook directly from the browser), extended to multiple helmets with configurable receiver mapping, and updated to the current per-receiver credential auth scheme. See [Decisions Log](#decisions-log), D17.

## How It Works

```
Config ──▶ Simulator (virtual receiver) ──POST /lora-uplink──▶ helix-webhook (Render) ──▶ Firestore ──▶ Real Dashboard
                    │
                    └──WebSocket──▶ Simulator Web UI (live view)
```

Config drives one or more virtual helmets, each posting real telemetry to the real backend — the same write path a physical receiver would use. The simulator generates telemetry (random-walk or scripted routes) for any number of configured virtual helmets, signs each request with a real, pre-provisioned receiver credential, and POSTs to the live `/lora-uplink` endpoint at the same ~10s cadence real hardware uses. A local web UI shows what's happening in real time and lets you build/edit the run configuration.

## Protocol Fidelity — What "Same Method" Means

The unsimulatable hop is the LoRa radio; every hop from HTTP onward is identical to real hardware:

```
REAL:      Sender --LoRa radio--> Receiver (adds RSSI/SNR) --HTTPS--> POST /lora-uplink
SIMULATOR: Virtual helmet+receiver (telemetry + synthetic RSSI/SNR) --HTTPS (identical)--> POST /lora-uplink
```

Each virtual helmet generates the same fields the real sender produces (`lat, lng, alt, speed, heading, battery, satellites`), plus synthetic `rssi`/`snr` the way a real receiver would report them. The request carries real `X-Receiver-Id`/`X-Receiver-Credential` headers. This means the simulator inherits the real backend's behavior for free: the 30s write-throttle, the alert-worthy bypass, battery/signal alert generation, and geofence containment checks all run exactly as they would for real hardware.

### Request field reference (from `functions/index.js`'s `/lora-uplink` handler)

| field | type | notes |
|---|---|---|
| `helmetId` | string | required; must already exist via `/admin/helmets/provision` (claim status irrelevant to ingestion) |
| `lat`, `lng` | number | default `0` if omitted |
| `alt` | number | default `0` |
| `speed` | number | default `0`; `speed === 0` ⇒ derived `status = "idle"`, else `"active"` |
| `heading` | number | default `0` |
| `battery` | number | default `-1` ("unknown", suppresses battery alert); real range 0–100 |
| `rssi` | number | default `-120` (dBm); drives `signal = rssiToPercent(rssi)`, clamped to [-120,-30] |
| `snr` | number | default `0` |
| `satellites` | number | default `0` |

Headers: `X-Receiver-Id: <receiverId>`, `X-Receiver-Credential: <raw credential>` — verified via SHA-256 against the receiver's stored verifier hash (see spec-device-pairing-system.md).

## Fleet Configuration & Receiver Mapping

Every part is configurable: any number of virtual helmets, each independently mapped to a receiver credential — shared or one-per-helmet, in any mix.

The run config defines a list of **receivers** (each a pre-provisioned `{receiverId, credential, label}`) and a list of **helmets**, where each helmet entry references one receiver by id. This supports every real-world topology: several helmets under one site gateway (shared receiver), one helmet per gateway (per-helmet receiver), or any mix.

| Config field | Type | Notes |
|---|---|---|
| `receivers[]` | array | `{id, receiverId, credential, label}` — pasted from a real `/admin/receivers/provision` call |
| `helmets[]` | array | `{helmetId, receiverRef, movementModel, batteryModel, ...}` |
| `backendUrl` | string | Defaults to the real deployed backend (`https://helix-webhook.onrender.com`); overridable if a non-prod deploy ever exists |
| `intervalMs` | number | Global default cadence; overridable per helmet |

## Movement & Telemetry Models

Each helmet independently picks one of:

**Random walk** — same shape as `firmware/sender/sender.ino`'s `stepFakeGps()`: a start position, constant step speed, and per-tick heading jitter. Config exposes the knobs (start lat/lng, speed, jitter range) rather than reinventing the model. Battery and signal drift slowly downward by default (configurable rate), so a long-running simulation can organically cross the low-battery/weak-signal alert thresholds if left running.

**Waypoint route** — a list of `{lat, lng}` points; the simulator interpolates position between them over time at the configured speed. Deterministic and reproducible — useful for deliberately walking a helmet in and out of a zone boundary to test geofence alerts, since there's no named "trigger geofence" preset (see Non-Goals) — you build the route to cross the boundary yourself.

## Cadence, Runtime & Scope Boundaries

- **Cadence**: default 10,000ms per helmet, overridable globally or per-helmet — matches the real firmware's `TX_INTERVAL_S = 10`.
- **Runtime**: starts on demand from the web UI, runs continuously (like real hardware) until stopped — no fixed duration/tick-count mode.
- **Alert triggering**: manual config only. To see a battery alert, configure a helmet's battery to start <20% or drift there. No "trigger SOS/battery/geofence" buttons.
- **SOS status — explicit gap**: `/lora-uplink` only ever derives `active`/`idle` from `speed === 0`; there is no field in the real protocol that sets `"sos"`. The simulator stays protocol-faithful and does not add one. If SOS testing is needed later, that's a firmware/backend protocol gap to solve separately, not a simulator feature.

## App Architecture

A new, fully standalone `simulator/` folder in this repo — Node/Express backend, plain HTML/JS frontend, WebSocket for live updates, zero Firebase SDK dependency.

```
simulator/
  package.json          # own deps: express, ws, node-fetch (or native fetch)
  server.js              # Express app + WebSocket server + simulation runner
  public/
    index.html            # single-page UI: config builder + live view
    app.js                # form builder, JSON editor toggle, map (Leaflet + OSM tiles), WS client
    style.css
  configs/                # saved run configs (gitignored, user-created)
  README.md
```

Runs with `node server.js` from the `simulator/` folder — no build step. The Express server both serves the static UI and runs the simulation loop (one timer per virtual helmet), POSTing to the real backend and streaming results to connected browser clients over WebSocket.

## Web UI

One page: a config builder (form + raw JSON, both available) and a live view (status table, map, and raw request/response log) once a run starts.

- **Config builder** — form-based add/edit for helmets and receivers (movement model knobs, waypoint list via click-to-place on a map), with a toggle to drop into a raw JSON textarea for bulk/advanced edits. Configs can be saved to and loaded from the `configs/` folder.
- **Live status table** — one row per helmet: current lat/lng, battery, signal, derived status, last uplink result (200 / throttled / error), and which receiver/account it's sending under.
- **Live map** — Leaflet + OpenStreetMap tiles (no build step, consistent with the real app's `flutter_map` and the deleted prior-art simulator's own choice of Leaflet), showing virtual helmets moving in real time.
- **Raw request/response log** — scrollable log of every `POST /lora-uplink` sent and the exact response body/status received, for protocol-level debugging.

## Security & Environment

The simulator holds no admin credentials and has no Firebase SDK access — it only ever knows pre-provisioned receiver credentials, the same trust boundary a real receiver has.

> Original direction considered letting the simulator provision its own receivers/helmets via an admin login. Rejected: there's no staging Firebase project in this system, so a local dev tool holding a production admin token — and provisioning fake helmets straight into the real dashboard real workers use — was an unacceptable risk for a manual QA tool.

Instead: receivers and helmets are provisioned ahead of time through the existing real admin flow (the admin UI, or a one-off script), and their `receiverId`/credential/`helmetId` are pasted into the simulator's config. The simulator itself is a pure `/lora-uplink` HTTP client — it never touches Firebase Auth, Admin SDK, or any endpoint other than `/lora-uplink`. This makes its risk profile identical to plugging in one extra physical receiver: bounded by whatever that one receiver credential can already do.

**Consequence worth stating plainly**: because there's no staging environment, simulated helmets write real documents to production Firestore (`helmets/*`, `alerts/*`, and `zones/*.containment` if zone-assigned) and will appear in the real dashboard exactly like a real worker's helmet. Use a clearly-named test helmet ID (e.g. `HLX-SIM-001`) and clean it up manually when done.

## Cleanup

Manual only — the simulator has no Firebase access to clean up after itself. When a simulation run ends, the operator is responsible for deleting or unclaiming the test helmet(s) and any generated alerts, the same way they'd tear down after testing with a spare physical receiver.

## Decisions Log

| ID | Topic | Decision | Rationale | Source | Date |
|---|---|---|---|---|---|
| D1 | Purpose | Manual QA / demo tool | Shapes scope: no CI hooks, no load-test volume requirements | Interview | 2026-08-15 |
| D2 | Protocol fidelity | Real `/lora-uplink` path, receiver-authenticated | "Same method as real helmet" means exercising the actual ingestion pipeline, not a shortcut | Interview | 2026-08-15 |
| D3 | Simulated layer | Virtual receiver (sender-like telemetry + synthetic RSSI/SNR) | No LoRa radio to simulate in software; the HTTP boundary is where fidelity matters | Interview | 2026-08-15 |
| D4 | Fleet scope | Configurable N helmets | User wants every part configurable, not a fixed single-helmet tool | Interview | 2026-08-15 |
| D5 | Receiver mapping | Configurable either way (shared or per-helmet) | Matches real multi-site/multi-gateway topologies | Interview | 2026-08-15 |
| D6 | Movement model | Both random-walk and waypoint routes, selectable per helmet | Random-walk mirrors real firmware's fake-GPS mode; waypoints give deterministic scenario reproduction | Interview | 2026-08-15 |
| D7 | Cadence & runtime | Configurable interval (default ~10s), runs until stopped | Matches real hardware's always-on behavior; manual QA doesn't need auto-stop | Interview | 2026-08-15 |
| D8 | Scenario coverage | Manual config only, no named alert-trigger presets | Simpler scope, consistent with manual QA tool sizing | Interview | 2026-08-15 |
| D9 | SOS support | Left out entirely | Real `/lora-uplink` protocol has no field that ever sets SOS status — adding one would break protocol fidelity (D2) | Interview | 2026-08-15 |
| D10 | App structure | New standalone folder `simulator/` in this repo | Stays versioned with the backend it targets; not embedded in Flutter app or functions/ | Interview | 2026-08-15 |
| D11 | App interface | Own local web UI (not just CLI) | User explicitly asked to split this into its own app with a UI | Interview | 2026-08-15 |
| D12 | UI live view | Status table + live map + raw request/response log + receiver/account display | User selected all offered options plus added account visibility | Interview | 2026-08-15 |
| D13 | UI config building | Both form builder and raw JSON editor | Consistent with "configure every part" direction | Interview | 2026-08-15 |
| D14 | Credentials setup | No admin auth in the tool; paste pre-provisioned values | Reversed after pushback: no staging Firebase project exists, so a local tool holding prod admin credentials + provisioning fake helmets into the real dashboard was an unacceptable risk | Interview | 2026-08-15 |
| D15 | Cleanup | Manual only, no automated teardown | Consistent with the tool having no Firebase access at all | Interview | 2026-08-15 |
| D16 | Tech stack | Node/Express + plain HTML/JS + WebSocket | Matches existing functions/ stack; no build step for a quick-to-run dev tool | Interview | 2026-08-15 |
| D17 | File naming & lineage | Named `spec-data-flow-simulator.md`, documented as superseding the deleted `simulator/` (commit `f9492d2`) | `spec-overview.md` from an earlier session already reserved this name and dependency slot; this spec is that planned spec 2, now that spec 1 (device pairing) has shipped | Interview | 2026-08-15 |

## Dependency Graph & Implementation Order

```
[Config schema] ──▶ [Movement generators] ──▶ [/lora-uplink HTTP client] ──▶ [Express server + sim runner] ──▶ [WebSocket event stream] ──▶ [Web UI]
      │                                                                              │
      └──────────────────────────────────────────────────────────────────────────────┘
```

1. **Config schema** — Define the JSON shape for `receivers[]`, `helmets[]`, movement models, cadence. Everything downstream reads this.
2. **Movement generators** — Random-walk (port of `stepFakeGps()`) and waypoint interpolation, pure functions producing lat/lng/speed/heading/battery/signal per tick.
3. **`/lora-uplink` HTTP client** — Builds the request body + receiver auth headers, POSTs, returns the parsed response/status for logging.
4. **Express server + simulation runner** — Loads a config, spins up one timer per helmet calling the generator + HTTP client, serves the static UI.
5. **WebSocket event stream** — Broadcasts each tick's request/response/status to connected browsers.
6. **Web UI** — Config builder (form + JSON toggle) and live view (status table, Leaflet map, raw log) consuming the WebSocket stream.
