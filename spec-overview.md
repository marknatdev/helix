# HELIX Spec Overview

Two dependency-ordered specs, produced from a single interview session that pivoted scope mid-way: what started as a request for a data-flow simulator surfaced a real security gap (arbitrary helmet self-claiming) that has to be fixed first.

## Specs

1. **[spec-device-pairing-system.md](spec-device-pairing-system.md)** — *Shipped.* Closed the helmet self-claim vulnerability with a two-tier Receiver + Helmet credential/pairing model. [Preview](https://claude.ai/code/artifact/fe87ef22-1b7c-475c-8a69-54cddbc8bcbe)
2. **[spec-data-flow-simulator.md](spec-data-flow-simulator.md)** — *Draft for review.* A standalone local dev/testing tool (`simulator/`, its own Node/Express + web UI app) that simulates helmet telemetry through the real `/lora-uplink` path using receiver credentials from spec 1, superseding the prior-art `simulator/` design (Python stdlib server + Leaflet map UI) deleted in commit `f9492d2`. [Preview](https://claude.ai/code/artifact/1c6ddc98-85e2-46d8-976d-f08ef1a52eae)

## Dependency order

```
[1. Device Pairing System] ---> [2. Data-Flow Simulator]
```

Spec 1 shipped (webhook migration + per-receiver auth, plus the claim flow) this session, which is what makes spec 2 buildable — the simulator authenticates using exactly the receiver-credential scheme spec 1 introduced.
