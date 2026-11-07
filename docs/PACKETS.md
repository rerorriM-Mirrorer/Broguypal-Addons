# Packet investigations — Failsafe and CastStill

Status: **Source-reviewed, not captured in-game**. These entries are implementation expectations and known library structure, not packet captures from the user's clients.

## Failsafe: server refusal and action readiness

- **Scenario:** Press a spell/JA/WS or `/attack` too soon after another action.
- **Incoming `0x029` action message:** Code reads actor from offset `0x05`, target from `0x09`, action message from `0x19` masked by `0x7FFF`. Previously hardcoded candidate rejection IDs: `17, 87, 90`; additional IDs are discovered from `resources.action_messages` English strings. A public message-ID list also identifies `94` for “You must wait longer to perform that action.” Which IDs occur in each live scenario is **unverified**.
- **Incoming `0x028` action:** Windower's action event supplies actor, category and parameter. The working fork infers spell start/finish from categories `8/4`, ranged from `12/2`, WS from `7/3`, and JA from `6/13/14/15`.
- **Category-8 cast transition clarification (2026-11-07):** Existing Windower addon source interprets category 8 + `param=24931` as cast beginning, and `param=28787` as interruption. The new Failsafe code sets `casting=true` only for 24931, clears casting for 28787, and does not mark interruption as success. Completed spell category 4 and `0x029` message 16 also clear casting. **Evidence:** source patterns in Ivaar's AutoGEO and GearSwap-related code; **confidence:** strong as established addon conventions, still unverified against this user's live client packets. Unknown category-8 parameters are ignored.
- **Live check required:** Capture a normal Cure cast start, movement interruption, successful finish, and a JA used immediately after interruption. Confirm the reported `0x028` params and whether the additional `0x029` message 16 appears.
- **Outgoing `0x01A` action:** The game's engage request is category `2`; the working fork currently observes user-facing `/attack` text rather than injecting this packet.
- **Follow-up observation needed:** Log server rejection versus actual permissible next action after a cast, JA, WS and early engage. Distinguish “could send” from “server accepted.” Confirm whether action messages arrive as both chat and `0x029` for each case.

## CastStill: movement and gated action

- **Scenario:** Begin casting while still moving, or immediately after releasing movement.
- **Outgoing `0x015` movement:** Code reads X and Y as 32-bit floats at offsets `5` and `13` in Windower's Lua pack offsets. Compares successive reports plus client mob position; *identical client-sent positions are a heuristic, not a server acknowledgment*.
- **Outgoing `0x01A`:** Code gates categories `3` (cast) and `16` (ranged); outgoing item `0x037` is also gated.
- **Test:** Walk or run continuously and request Cure; release the stick after a variable delay; check report-to-stop and stop-to-start intervals, whether GearSwap runs precast once, and whether the action fires only after a stable stop. Repeat with another client under high latency and while changing targets.
- **Known limits:** No verified server “stationary” signal, and a timeout is a safety policy rather than proof of readiness. Preserving no-synthetic-actions semantics may require future design review if the new first-stop mode loses a queued action.

## Requested data

For each relevant test, capture: user input and time, current target ID, outbound `0x015/0x01A/0x037`, incoming `0x028/0x029`, observed cast status, and whether the action truly executed. When possible, compare two test cases (moving and stopped) for the same action.

No actual packet capture has yet been recorded for this batch.
