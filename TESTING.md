# TESTING.md — Broguypal-Addons working fork

## Current Development Status — 2026-11-07 — Failsafe cast interruption correction

- **Repository / branch:** `rerorriM-Mirrorer/Broguypal-Addons` / `development/action-readiness-20261106`. Existing `main` is not modified or promoted.
- **Version / source checkpoint:** Failsafe `1.1.1-dev`; executable fix committed as `ff809582f2a7fd06cb366f73c8797710aed9bfd9`. Source was re-fetched and checked after publication. Earlier working-fork experiments in Failsafe, CastStill and TrueTargetLock remain otherwise unchanged.
- **Change:** For category-8 action events, recognize `param=24931` as start and `param=28787` as interruption. Ignore unknown category-8 variants; do not let interruption clear the pending action as though it succeeded. Completion category 4 and action-message `0x029` ID 16 clear casting as before, with consistent `casting_since` reset. No changes to the default or persisted settings (`ready`, 4-second max wait, attack ON, notify ON).
- **Test artifact:** `tests/test_failsafe_cast_events.lua` added as a mocked, offline Lua 5.1 regression suite. The suite covers cast start blocking, interruption release without success misclassification, unknown category-8 events, category-4 completion, original fixed mode, and defaults. **It has been committed but not executed** in this environment.
- **Verification actually performed:** A post-publication source read and nine exact source-structure/invariant checks passed, including category/param branch ordering, clearing both casting variables, backup ID 16 path, unchanged defaults, and one action event registration. Regression test source was checked for the five intended scenarios. This is **static verification**, not a Lua runtime test or game acceptance.
- **Pending:** Run `lua tests/test_failsafe_cast_events.lua` with Lua 5.1; then use FFXI to interrupt Cure with movement, immediately request a JA/spell, confirm one permitted retry and no misleading timeout, and verify ordinary successful casts and fixed-mode regression. Capture action `0x028` category/param and `0x029` message IDs; update `docs/PACKETS.md`. Retain the branch in test status until live verification.
- **Delivery:** GitHub branch source and docs only; no ZIP produced. Source checkpoint above is not the final documentation commit; the branch's latest head must be confirmed at delivery.

---


## Code review and static checks — 2026-11-06

- **Changes on development branch only:** TrueTargetLock v1.3.0 adds session-only `faceaway` and target-bound timed `turnaway`; Failsafe v1.1.0-dev adds idempotent `/attack on` tracking and a bounded readiness-aware mode; CastStill v1.3.0-dev adds optional `firststop` mode and configurable hold times. Each has updated README documentation plus help/status/restart/unload commands.
- **Docs:** Adopted `AGENTS.md`, canonical-shared `WORKFLOW.md` with fork notes, this cumulative `TESTING.md`, and `docs/PACKETS.md` for implementation assumptions and requested captures.
- **Verification performed:** Pulled each published Lua file back from GitHub and checked balanced quote/comment, delimiter, and control-block structure with an independent JS lexical checker. All three reported no structural errors. Confirmed exactly one instance of each Failsafe event registration after repairing an erroneous duplicated section. Confirmed separate settings/commands and reviewed the original source paths. A final GitHub fetch of all three sources confirmed all required new command/state symbols, and no duplicate event registrations.
- **Verification not performed:** No full Lua 5.1 parsing or native Windower API smoke test, controller input test, packet capture, or live FFXI verification. Do not install all three simultaneously for initial testing; start one addon at a time.
- **Additional target-safety review:** CastStill now saves the original selected <t> target for held text commands, discards changed or unavailable targets rather than falling back to packet replay, and Failsafe recognizes uppercase <T> target tokens for target-change cancellation.
- **Safety/behavior caveats:** Failsafe's readiness mode is heuristic; no single definitive server unlock signal was found. It gives up after one additional attempt (ready mode) or two additional attempts (fixed mode). CastStill firststop mode cancels an unfulfilled pending action after timeout. TrueTargetLock's explicit away commands override normal engaged/locked requirements; do not rely on this alone to avoid gaze mechanics.
- **Release:** Working branch `development/action-readiness-20261106`; `main` has not been intentionally edited. No testing ZIP generated in this batch; users may inspect source in the branch.
- **Outstanding workflow adoption:** The code retains upstream chat formatting for now; a comprehensive BattleStations-style colored command formatting pass would be a separate cosmetic change after behavior is proven. The shared docs remain the canonical standard.
- **Next live tests:** Check attack timing and unchanged-target guards, firststop on multiple clients, TrueTargetLock's true-away and timed return, CastStill + GearSwap, and Failsafe/CastStill interaction. Record detailed packet data before tuning global recovery heuristics.

---

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

## 2026-11-07 — Failsafe correction batch

- **User request:** Fix the shared casting flag treating category-8 spell interruption as cast start. Changes intentionally limited to Failsafe plus its test and development records.
- **Commits:** Failsafe executable `ff809582f2a7fd06cb366f73c8797710aed9bfd9`; test `7b842981f8319a3a87072d1270443543213ee876`; see GitHub branch history for README/packet/testing documentation.
- **Result:** Source invariants passed. Offline regression script exists but wasn't run; Windower/FFXI behavior remains untested. No default-setting changes.

## Previous tests and results

- No prior testing records available in this fork at adoption. Upstream README claims are not treated as user-confirmed local tests.

## Delivery register

| Date | Batch | Commit | Verification | Live FFXI |
| --- | --- | --- | --- | --- |
| 2026-11-06 | Workflow adoption, three addon experiments, and packet notes | See branch commit history; latest remote commit recorded at delivery | Structural checks only | Not performed |

## User observations and requests

- 2026-11-06: A observed that spell, weaponskill, and job-ability lockouts share a readiness concept; considers using Failsafe rejection packets/messages for GripRumble's reject buzzer; wants safe attack handling and readiness-aware retries, stronger movement hold, and turn-away/face-away controls.

## Corrections and retention

Keep this cumulative record; add dated corrections without removing historical observations.
