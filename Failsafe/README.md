# Failsafe — working fork 1.1.0-dev

Failsafe is a Windower addon for Final Fantasy XI that can hold and retry rejected spells, weaponskills, items, job abilities, ranged attacks, and attack-on commands.

# What is it?

Ever press a spell, weaponskill, job ability, or item a split second too early and the 
game refuses it? Failsafe presses it again for you.

## How it behaves

1. You use an ability (spell, job ability, weaponskill, or item).
2. It doesn't go off.
3. Failsafe retries it, up to 2 additional attempts total.

## Commands

* `//failsafe notify` turns the retry message on or off. It's on by default.

## Install

* Put `Failsafe.lua` in `Windower/addons/Failsafe/`
* Run `//lua load failsafe`
* Add it to your init script to load it automatically

## License

Failsafe is free to use and share under the BSD 3-Clause License.

Copyright © 2026 Broguypal
## Working-fork changelog

- **2026-11-06 / 1.1.0-dev:** Experimental bounded readiness mode; idempotent attack-on tracking; commands for mode, attack tracking, max wait, notify, and status. Source-level checks only, in-game testing outstanding.
