# TESTING.md — Broguypal-Addons working fork

## Current development status — 2026-11-06

- **Repository:** `rerorriM-Mirrorer/Broguypal-Addons`.
- **Working branch:** `development/action-readiness-20261106` (branched from `main`). The default branch is intentionally unchanged.
- **Baseline:** Broguypal's Failsafe v1.0.4, CastStill v1.2.2, and TrueTargetLock v1.2 matched the public upstream code at the beginning of this work.
- **Requested:** Explain shared action lockouts for XIVCrossbar; consider state-aware Failsafe including `/attack`; consider movement-to-first-stop and configurable hold for CastStill; implement an explicit face-away / turn-away mode for TrueTargetLock.
- **Current confidence:** Static source review only. No in-game FFXI testing performed. Do not treat source inspection as proof of packet timing or server acceptance.

## Current testing checklist — pending live validation

1. Load each addon separately; check `help` and `status` and that existing saved options merge.
2. Check TrueTargetLock default face-target behavior while engaged/target-locked. Use explicit face-away against a stationary target, then a moving target, confirm the heading moves about 180° away. Verify timed turn-away expires and resumes normal facing, target changes cancel it, and zone/logout clears temporary mode.
3. Failsafe: use an attack command shortly after an action to provoke a rejection, confirm it never toggles an already-engaged character off, respects a changed target, and never retries beyond bounded time/attempts. Check spell/WS/JA regression and GearSwap interactions.
4. CastStill: test brief movement stops with a spell; then continuous movement with a pending cast, verify first real stop and max-hold behavior, and check GearSwap reordering and target switching.
5. Check multiple Windower clients independently. Log chat messages, action/message packet IDs, and any false positives. Do not test experimental behavior on valuable limited-use actions.

## Previous tests and results

- No prior testing records available in this fork at adoption. Upstream README claims are not treated as user-confirmed local tests.

## Delivery register

| Date | Batch | Commit | Verification | Live FFXI |
| --- | --- | --- | --- | --- |
| 2026-11-06 | Workflow adoption & experimental design | To be filled on publication | Source review | Not performed |

## User observations and requests

- 2026-11-06: A observed that spell, weaponskill, and job-ability lockouts share a readiness concept; considers using Failsafe rejection packets/messages for GripRumble's reject buzzer; wants safe attack handling and readiness-aware retries, stronger movement hold, and turn-away/face-away controls.

## Corrections and retention

Keep this cumulative record; add dated corrections without removing historical observations.
