# HELIX Spec Overview

Two dependency-ordered specs, produced from a single interview session that pivoted scope mid-way: what started as a request for a data-flow simulator surfaced a real security gap (arbitrary helmet self-claiming) that has to be fixed first.

## Specs

1. **[spec-device-pairing-system.md](spec-device-pairing-system.md)** — *Draft for review.* Closes the helmet self-claim vulnerability with a two-tier Receiver + Helmet credential/pairing model. [Preview](https://claude.ai/code/artifact/fe87ef22-1b7c-475c-8a69-54cddbc8bcbe)
2. **spec-data-flow-simulator.md** — *Not yet interviewed.* A standalone local dev/testing tool ("split of the main app") that simulates helmet telemetry/alerts through the `/lora-uplink` webhook path, matching the prior-art `simulator/` design (Python stdlib server + Leaflet map UI) deleted in commit `f9492d2`. Depends on spec 1 shipping — the simulator needs a provisioned Receiver credential to authenticate as, once the webhook auth migration (spec 1, step 4) lands.

## Dependency order

```
[1. Device Pairing System] ---> [2. Data-Flow Simulator]
```

Spec 1 must ship (through at least step 4 of its own implementation order — webhook migration + per-receiver auth) before spec 2 can be meaningfully interviewed, since the simulator's injection path and credential model are direct consequences of spec 1's decisions.
