# CastStill — working fork 1.3.0-dev

A Windower 4 addon for Final Fantasy XI that stops your spells, items, and
ranged attacks from getting interrupted right after you stop moving.

## What it does

In FFXI there's a short delay between when you stop moving and when the server
realizes you've stopped. If you cast during that gap, the server thinks you're
still moving and interrupts your spell.

CastStill fixes this. If you cast too soon after moving, it quietly holds the
spell for a fraction of a second until the server knows you're standing still,
then casts it. No more "moved and interrupted" spam when you were clearly
standing still.

It works on magic, ninjutsu, songs, trusts, items, and ranged attacks.

In the default recent mode, an action requested during continuous running can still be interrupted when the short hold expires. Optional firststop mode instead waits for a stationary opening or cancels at its configured timeout.

## How it works

CastStill watches the position updates your client sends to the server. When
you act too soon after moving, it holds the outgoing action packet and re-sends
it once your client has reported the same position twice or after a short timeout,
whichever comes first in the original recent mode. That mode defaults to a 0.35-second maximum hold; the optional firststop mode has a separate longer maximum.

In the original recent mode, the upstream behavior remains unchanged. The working fork also provides configurable holds and firststop mode (see above).

## Experimental movement modes (working fork)

The upstream **recent** mode is unchanged by default: actions are held for up to 0.35 seconds if you have just moved and the position is unsettled.

A new **firststop** mode holds movement-interruptible actions while you are moving, waiting for the first observed stationary opening (unchanged outgoing `0x015` position, matching current client position, and a brief 0.20-second settle interval). It observes local position updates as well, not solely the last outgoing packet.

Commands:

```text
//caststill restart
//caststill unload
//caststill mode firststop
//caststill hold 5
//caststill mode recent
//caststill hold 0.8
//caststill status
//caststill help
```

`hold` sets the current mode's maximum hold (0.1 to 15 seconds). Defaults are 0.35 seconds in recent mode and 5 seconds in firststop mode. **When firststop times out while still moving, CastStill cancels the pending action rather than sending an action that would likely fail.** In recent mode a timeout replays the action, as upstream does.

Only spells/ninjutsu/songs/Trust calls, items, and ranged attacks are gated. Weapon skills and standard job abilities are intentionally untouched: these don't have the same movement-interruption behavior. The addon still holds at most one pending action. GearSwap detection and ordering logic remain in place.

This is an experiment, not a confirmed guarantee of server readiness. Test the timing and target-change behavior on each client before depending on it.

## Does it work with GearSwap?

Yes.

Windower calls addon event handlers in load order, so whichever addon loads
first sees your actions first, and CastStill has to see them before GearSwap
does. GearSwap is usually already running by the time CastStill starts, so
CastStill reloads it once to put it back in line. If you load CastStill from
your `init.txt`, that reload happens at the character select screen, before the
game is drawing chat, so you won't see it.

Where you will notice: reloading CastStill mid-session reloads GearSwap with it,
which resets any modes you may have set.

All your gear swaps (precast, midcast, aftercast) work exactly like they always
have.

## License

CastStill is free to use and share under the BSD 3-Clause License.

Copyright © 2026 Broguypal

## Working-fork changelog

- **2026-11-06 / v1.3.0-dev:** Added optional first-stop hold during movement and independently configurable timeout per mode. Preserves upstream recent-mode defaults. Static code review only; live FFXI behavior pending.
