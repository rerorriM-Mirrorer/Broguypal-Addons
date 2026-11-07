# Failsafe — working fork 1.1.1-dev

Failsafe is a Windower addon for Final Fantasy XI that can hold and retry rejected spells, weaponskills, items, job abilities, ranged attacks, and attack-on commands.

## State-aware experiment

The working fork defaults to `mode ready`. After a server rejection, it waits for observable readiness: a completed cast, spell/ability recast at zero (where available), sufficient TP for weaponskills, and disengaged status for `/attack`. It sends **at most one additional attempt** in this mode and abandons pending work after the timeout (default 4 seconds). This is a best-effort heuristic, **not proof that the server's animation/global recovery is complete**.

`mode fixed` keeps the original 0.65-second schedule, allowing up to two additional attempts.

The addon recognizes `/attack` and `/a`, and safely resends only `/attack on`. It does not retry `/attack off` or re-send a toggle, and cancels pending engagement once you're engaged or the original target changes. A `<t>`-targeted pending action also cancels if the target changes.

Commands:

```text
//failsafe mode ready
//failsafe mode fixed
//failsafe attack on
//failsafe attack off
//failsafe maxwait 4
//failsafe notify on
//failsafe notify off
//failsafe status
//failsafe help
//failsafe restart
//failsafe unload
```

The `maxwait` range is 1–15 seconds. Changing settings cancels pending work. All automatic attempts remain experimental until observed in-game.

# What is it?

Ever press a spell, weaponskill, job ability, or item a split second too early and the 
game refuses it? Failsafe presses it again for you.

## How it behaves

1. You use an ability (spell, job ability, weaponskill, or item).
2. It doesn't go off.
3. The working-fork readiness mode waits for an observable opening and makes one extra attempt; fixed mode retains two retries.

## Commands

Use the command examples above; notification is enabled by default.

## Install

* Put `Failsafe.lua` in `Windower/addons/Failsafe/`
* Run `//lua load failsafe`
* Add it to your init script to load it automatically

## License

Failsafe is free to use and share under the BSD 3-Clause License.

Copyright © 2026 Broguypal
## Working-fork changelog

- **2026-11-07 / 1.1.1-dev:** Corrected category-8 casting-state detection: param 24931 marks cast start; 28787 marks an interrupted spell and clears casting rather than marking it active. Unknown variants are ignored, and interruption events no longer count as action successes. The existing 0x029 message-16 fallback remains. Defaults and saved settings are unchanged. In-game acceptance pending.

- **2026-11-06 / 1.1.0-dev:** Experimental bounded readiness mode; idempotent attack-on tracking; commands for mode, attack tracking, max wait, notify, and status. Source-level checks only, in-game testing outstanding.
