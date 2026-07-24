---
Date: 2026-07-25
Status: Accepted
Triggers:
  - a TV/idle screen gets stuck or stale and can't be refreshed without power-cycling the TV
  - deciding whether a new idle/non-interactive screen should auto-refresh
  - building a remote-control or remote-reload mechanism for the Stage
Topics: tv, closed-screen, resilience, google-tv-app
---

# ADR 012 -- Self-Refreshing Idle TV Screens

## Context

The Google TV app running EZ-AZ has no way to manually refresh the page --
there's no browser chrome, no reload button. When `public/closed.html` gets
stuck showing stale state (e.g. a countdown that stopped updating correctly),
the only fix was powering the whole TV off and back on.

A `nextOpening()` boundary bug in `public/opening-hours.js` was the immediate
trigger (fixed same day), but the underlying problem -- no way to recover a
stuck screen short of a full power-cycle -- exists independently of that bug
and will recur with any future bug or transient glitch on an idle screen.

## Decision

Idle, non-interactive screens self-heal with a periodic full page reload
instead of relying on a remote-control/remote-reload mechanism.

Applied first to `public/closed.html`:

```js
setInterval(function () { window.location.reload(); }, 2 * 60 * 1000);
```

Scope rule: this only applies to idle/non-interactive screens (the closed
screen today; the shelf or other waiting screens could adopt it later if the
same problem shows up there). It must never be applied to a screen mid-game
-- a forced reload would kill an active game session. If a game-adjacent
screen ever needs this kind of resilience, the game's own state/session
handling needs to be addressed first, not a blanket reload timer.

If this pattern is needed on another idle screen, replicate the same
`setInterval(reload, 2 * 60 * 1000)` line on that screen directly. Don't
build a generic remote-reload/broadcast mechanism for this -- the ActionCable
plumbing exists for phone-to-TV control, but a periodic self-reload is
simpler and sufficient for idle screens, and the two problems (idle-screen
staleness vs. deliberate remote control) shouldn't be solved by the same
mechanism.

## Consequences

- The closed screen recovers on its own from staleness or transient bugs
  within 2 minutes, without anyone touching the TV.
- No new infrastructure: no ActionCable channel, no remote command surface,
  no admin UI.
- Any future idle screen with the same "TV app can't be refreshed manually"
  problem has a one-line fix to copy, rather than needing a design
  discussion each time.
- This is explicitly not a remote-reload-on-demand capability -- if that's
  ever wanted (e.g. "force this specific TV to reload right now"), it's a
  separate decision built on the existing TV-remote ActionCable channel, not
  an extension of this timer.
