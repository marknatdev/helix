# Helmet Pairing System

**Status:** Draft for review
**Date:** 2026-08-14
**Preview:** https://claude.ai/code/artifact/fe87ef22-1b7c-475c-8a69-54cddbc8bcbe
**Blocks:** `spec-data-flow-simulator.md` (not yet interviewed — depends on this shipping first)

## Problem

`lib/services/user_service.dart`'s `registerHelmet(helmetId)` performs `FieldValue.arrayUnion([id])` on the caller's own `users/{uid}` document with zero verification that the ID is real, unclaimed, or physically theirs. `firestore.rules` then grants **full read/write** on `helmets/{helmetId}` to whoever has that ID in their own `helmetIds` array — meaning any signed-in user can claim, read, and overwrite (GPS, battery, SOS status) any helmet by simply typing or guessing its ID.

This was surfaced while scoping a separate "simulate data flow through the app" request: before building a tool that fakes telemetry realistically, the underlying question of "who's allowed to claim a real helmet" needed a real answer first. The data-flow simulator becomes a dependent spec once this one ships.

## Approach

A two-tier credential model:

1. **Receiver gateways** (device-level trust) — admin-provisioned, credentialed hardware that relays telemetry.
2. **Helmets** (ownership-level trust) — pairing-code-verified claiming by the worker who physically has the device.

## Credential Model

> **Correction from the interview process:** the initial framing assumed an existing `docs/architecture/decisions.md` (ADR-005) and `receiver-protocol.md` could be adapted. Neither file exists in the working tree, on any branch, or in git history — `docs/` itself was removed during an earlier "restore old version" revert this session. The design below is written from first principles (see D7).

- **Receiver credential:** a high-entropy random token, issued exactly once at provisioning time and shown to the admin exactly once. The server stores only an HMAC-SHA256 hash (the *verifier*) plus a `credentialVersion` integer — never the raw value.
- **Helmet pairing code:** a separate high-entropy (10+ alphanumeric character) code, generated at helmet setup time, printed as a QR label. The server stores only its hash; the raw code lives on the physical label.
- Both are versioned and rotatable: rotating either invalidates the previous value immediately (fail closed, no grace period).

## Receiver Provisioning

- Admin-only in-app Flutter screen: "Provision new receiver" → server generates credential + verifier, displays the raw credential once for the installer to copy into `firmware/receiver/config.h` before flashing.
- Enforced by the new `users/{uid}.role` field (see Admin Role & Access Control) — never by client-side UI gating alone.
- Revocation/rotation is admin-triggered, fails closed immediately, no grace period.

## Helmet Claim Flow

1. Worker submits the helmet's pairing code (scanned QR or manual entry) to a Claim Cloud Function.
2. The function runs a **single Firestore transaction**: verify the code hash matches the target helmet, confirm it is not already claimed, mark it `claimed: true` / `claimedByUid` / `claimedAt`, and invalidate the code.
3. A second worker attempting to claim the same helmet after step 2 gets an explicit "already claimed" error — no silent overwrite, no race.
4. Repeated failed claim attempts from a given account trip a per-uid rate limit / lockout, so the high-entropy code isn't the only defense against brute-forcing.

## Admin Role & Access Control

Today's app has no role concept for the flat `helmets`/`alerts` schema — though `firestore.rules` does contain an orphaned `sites/{siteId}` block with its own `role in ['supervisor','safety','admin']` check, left over from a prior, unused architecture attempt. That block is deleted as part of this change to avoid two competing definitions of "role" in the same rules file (see D8).

- `users/{uid}.role` (`admin` | `user`) is added, but the existing rule's client-writable-fields allowlist (currently `hasOnly(['helmetIds'])`) is **never** extended to include it.
- `role` is settable only by an admin-invoked Cloud Function using the Admin SDK, which itself checks the caller's own existing role before granting.
- A one-time bootstrap Cloud Function, gated by an env-var setup secret and permanently disabled after first successful use, creates the very first admin — there is otherwise no in-app path to create one.
- During the re-claim rollout window (below), the admin role retains blanket alert-acknowledge rights regardless of a helmet's claim state, so active SOS/battery alerts on not-yet-reclaimed helmets are never stuck unacknowledgeable.

## Webhook & Deployment Changes

Today, `functions/index.js` is started with `node index.js` on whatever machine happens to be running it, using a locally-stored Admin SDK service-account key (`firebase.json` has no `functions` block — it isn't actually deployed). Every request to `/lora-uplink` and `/chirpstack-webhook` is authenticated with one shared `X-Webhook-Token` for the entire server.

- Migrate to deployed Firebase Cloud Functions (Gen2) — removes the "someone has to keep a laptop process alive" dependency and matches how hosting and rules are already actually deployed.
- Both webhook routes add `X-Receiver-Id` and a per-receiver credential header; the function hashes the credential and compares it against that specific receiver's stored verifier, rejecting on mismatch or revoked state.
- Verifier hashes are cached in-memory in the function instance, actively invalidated the moment a credential is revoked or rotated — avoiding a Firestore read on every single uplink while still honoring immediate revocation.

## Retiring the Old Claim Path

`UserService.registerHelmet()`/`unregisterHelmet()` and `RegisterHelmetDialog` are removed entirely. `helmetIds` mutation moves fully server-side, written only by the new Claim Cloud Function (via Admin SDK) — the `users/{uid}` rule's client-writable allowlist drops `helmetIds` the same way it must never gain `role`. Shipping the old and new paths side by side, even temporarily, would leave the original vulnerability reachable.

## Migration: Rolling Out to a Live App

- **Scope:** every `helmetIds` entry created under the old self-registration model is invalidated. Nothing is grandfathered.
- **Timing:** a scheduled, announced maintenance window with advance in-app notice — not a silent flip.
- **Safety net during the window:** the admin alert-acknowledge override stays active so SOS/battery alerts on not-yet-reclaimed helmets remain actionable.
- **Prerequisite:** every physical helmet needs a pairing-code label generated and attached before the cutover, or workers have no way to re-claim it.

## Security Considerations

- `role` must never appear in any client-writable Firestore rule allowlist (D6) — the single most consequential guard in this spec, since violating it re-opens self-escalation.
- Pairing codes and receiver credentials are stored only as hashes server-side; raw values exist only at issuance time (displayed once) and on the physical label.
- Rate limiting / lockout on the claim endpoint (D12) is required alongside high entropy — entropy alone doesn't stop enumeration.
- Revocation fails closed with no grace period for both tiers (D4).
- The Admin SDK service-account key remains the highest-privilege credential in this system (it bypasses all rules); migrating the webhook to deployed Cloud Functions (D10) removes the "manually run process on a laptop" exposure but the key itself still needs standard secret-management hygiene outside this spec's scope.

## Open Assumption

Who creates the initial `helmets/{id}` document and generates its pairing code — before a worker can claim anything — was not directly asked during the interview. This spec assumes it mirrors the Receiver provisioning pattern: an admin action (likely on the same admin screen) that creates the helmet record and prints its QR label before the physical unit ships to a site. **Confirm before implementation.**

## Decisions Log

| ID | Topic | Decision | Rationale | Source | Date |
|---|---|---|---|---|---|
| D1 | Pairing subject scope | Two-tier: Receivers (device credential) + Helmets (ownership claim) | Receiver credentials alone don't stop arbitrary helmet self-claiming; helmet claiming alone leaves ingestion unauthenticated per-device | Interview | 2026-08-14 |
| D2 | Helmet claim proof | High-entropy (10+ char) pairing code via QR label, verified server-side | Closes "type any ID string" while matching real hardware-shipping workflow | Interview | 2026-08-14 |
| D3 | Receiver provisioning interface | Admin-only in-app Flutter screen; raw credential shown once | Self-service for site admins, matches real deployment workflow | Interview | 2026-08-14 |
| D4 | Revocation scope | Both helmet unclaim and receiver credential revoke/rotate, fails closed | Covers "worker leaves" and "gateway compromised" scenarios | Interview | 2026-08-14 |
| D5 | Webhook auth model | Replace shared X-Webhook-Token with per-receiver credential headers | Without this, provisioned credentials wouldn't be the real gatekeeper | Interview | 2026-08-14 |
| D6 | Admin role enforcement | Add users/{uid}.role, but never in any client-writable rule allowlist | Existing rule allows client writes to allowlisted fields; role must never join it or self-escalation is one rule tweak away | Red Team | 2026-08-14 |
| D7 | Credential design basis | Design fresh (HMAC-signed, versioned, hash-only storage) instead of "adapting ADR-005" | ADR-005/receiver-protocol.md do not exist anywhere in the repo or its history | Red Team | 2026-08-14 |
| D8 | Orphaned rules cleanup | Delete the dead sites/{siteId} + isSupervisor role block from firestore.rules | Prior architecture attempt left dead code with conflicting "role" semantics next to the new field | Red Team | 2026-08-14 |
| D9 | Old self-claim path | Delete UserService.registerHelmet and RegisterHelmetDialog entirely | Leaving it reachable keeps the original vulnerability open after the new flow ships | Red Team | 2026-08-14 |
| D10 | Webhook deployment model | Migrate functions/index.js to deployed Cloud Functions (Gen2) | The fail-closed revocation guarantee only holds while a human keeps a local process with a live admin key running | Red Team | 2026-08-14 |
| D11 | Claim operation atomicity | Single Firestore transaction: verify code → mark claimed → invalidate code | Prevents a crash/race leaving a helmet claimed-but-code-valid or code-invalidated-but-claim-failed | Red Team | 2026-08-14 |
| D12 | Pairing code rate limiting | Per-uid attempt rate limit with lockout, in addition to high entropy | A high-entropy code alone doesn't stop brute-force enumeration against known/sequential helmet IDs | Red Team | 2026-08-14 |
| D13 | Re-claim rollout | Wipe all existing claims; scheduled/announced maintenance window, not silent | Strongest security guarantee, without silently breaking live dashboards for field workers | Interview + Red Team | 2026-08-14 |
| D14 | Alert acknowledgement during transition | Admin role retains blanket alert-ack rights regardless of claim state during rollout | Prevents active SOS/battery alerts from becoming unacknowledgeable mid-transition | Red Team | 2026-08-14 |
| D15 | Receiver credential lookup performance | Cache verifier hashes in-memory, invalidated on revoke/rotate | Avoids a Firestore read on every uplink while still honoring immediate revocation | Red Team | 2026-08-14 |
| D16 | First-admin bootstrap | One-time bootstrap Cloud Function gated by an env-var secret, disabled after first use | Once role is locked to admin-only writes, some out-of-band mechanism must create the first admin | Red Team | 2026-08-14 |

## Dependency Graph & Implementation Order

```
[role field + rules cleanup]
        |
        +--> [admin bootstrap + alert-ack override] --> [receiver provisioning]
        |                                                       |
        |                                                       v
        +---------------------------------------------> [webhook migration + per-receiver auth]
                                                                |
                                                                v
                                                        [helmet claim flow]
                                                                |
                                                                v
                                                    [delete old self-claim path]
                                                                |
                                                                v
                                                     [live rollout — scheduled window]
```

1. **Role field + orphaned rules cleanup** — Add `users/{uid}.role` (never client-writable); delete the dead `sites/{siteId}` rules block. No dependencies — do this first.
2. **Admin bootstrap + alert-ack override** — One-time bootstrap function for the first admin; extend alert rules so admins can always acknowledge regardless of claim state.
3. **Receiver provisioning** — Data model, provisioning Cloud Function, admin screen. Depends on admin gating existing.
4. **Webhook migration + per-receiver auth** — Deploy `functions/index.js` as real Cloud Functions; replace shared token with per-receiver credential checks + in-memory verifier cache.
5. **Helmet claim flow** — Pairing-code data model, atomic claim transaction, rate limiting. Depends on the deployed function infra above.
6. **Delete the old self-claim path** — Remove `registerHelmet`/`RegisterHelmetDialog` once the new claim flow is live and tested — don't ship both at once.
7. **Live rollout** — Scheduled maintenance window, advance notice, wipe existing claims, require re-claim for everyone. Last step, once everything above is proven.
