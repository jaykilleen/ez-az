---
Date: 2026-11-01
Status: Accepted
Triggers:
  - building a multiplayer game where every player's phone is their own screen
  - adding server-side bots to a phone-as-display game
  - channel action data arriving empty despite the client sending it
Topics: games, actioncable, bots, phone-controller, arcade-session
---

# ADR 021 -- Mammoth Games: Phone-as-Display Architecture and Server-Side Bot AI

## Context

Mammoth Games is a real-time multiplayer tag game (up to 4 players + up to 3 bots) in
which **each player's phone is their own display**, not a controller for a shared TV.
Every player sees their own view of the arena -- their position, who is IT, nearby
players, the minimap, power-up spots -- all rendered on Canvas on the phone itself.

This is architecturally different from every prior EZ-AZ multiplayer game:

- TV party games (Snake Pit Royale, Golden Goal, Spotlight) use a shared TV Stage
  as the canonical display; phones are controllers.
- Phone-as-display means there is no TV host, no `TvRemoteChannel`, no Zone. The
  phone is simultaneously the controller and the screen.

The game needed bots to keep a solo player entertained. Because position and tag
logic run server-side (so all clients agree), bots had to run server-side too.

A five-round debugging session (four deploys, one browser debugger session) exposed
a non-obvious ActionCable behaviour that silently dropped all incoming data from the
`start_game` action.

---

## Decisions

### 1. Phone-as-display on the ArcadeSession spine

Mammoth Games uses `include ArcadeSession` with `arcade_prefix "mammoth_games"`.
ArcadeSession's slot assignment, host election, TTL sweep, and `join`/`leave` actions
are all reused unchanged. The key difference from a TV party game:

- There is no TV subscriber; the first phone subscriber triggers
  `arcade_after_subscribe` which creates the session.
- `host?` is `phone? && !@slot.nil? && s && s[:host_slot] == @slot`
  (no `tv?` branch needed).
- The game broadcasts positions to all subscribers; each phone filters and renders
  only what it needs locally.
- `ArcadeTV.setButtons`, `connectRemote`, and the Zone are not used.

The Phone Contract (ADR 010) still applies. Compliance:

| Clause | Mammoth Games |
|--------|--------------|
| 1 No keyboard/mouse | Pass -- every action is touch on the phone |
| 2 TV listens to remote | N/A -- no TV Stage |
| 3 Host/phone start | Pass -- first joiner is host; start button shown only to host |
| 4 Phone EXIT + `leave` | Pass -- EXIT on lobby, game, and game-over screens |
| 5 Recover without restart | Pass -- QUIT broadcasts `game_over` and resets session to lobby |
| 6 Rematch keeps party | Pass -- reuse join code, no reload |
| 7 Sessions die | Pass -- 4-hour TTL sweep from ArcadeSession |
| 8 One-scan join | Pass -- QR code on join page (ADR 009) |
| 9 Resume contract | N/A -- phone-only, no TV resume map needed |

No TV Stage means clauses 2 and 9 do not apply. This is the first game on the spine
without a TV Stage; no ADR amendment is needed because clause 10 requires only that
the game states how each clause is met, which is above.

### 2. Server-side position authority and bot AI

All positions are server-authoritative:

- Phones report `move(x, y)` on every animation frame.
- The server clamps `x`/`y` to arena bounds and broadcasts `positions` to all
  subscribers.
- Each phone renders the received positions, not its own locally-predicted ones.

Bots (`BOT_SLOT_BASE = 1000`, slots 1000+) are ticked server-side inside
`sessions_mu.synchronize` as part of each `move` action (`tick_bots`). This
piggybacks bot movement onto the 60 fps player-report cadence with no extra thread
or timer.

Bot AI is simple: IT-bots chase the nearest runner; runner-bots flee the nearest
chaser. Heading recalculates every 0.8-1.2 s with a small random jitter to avoid
locking in a straight line.

`PLAYER_SPD = 240.0` must be defined as a Ruby constant in the channel class --
not only in JavaScript -- because `tick_bots` references it. A missing constant
raises `NameError` inside `sessions_mu.synchronize` and silently aborts the `move`
action without any position broadcast.

### 3. Bots and arena passed in `start_game`, not via pre-calls

An earlier design used two separate pre-calls (`set_bots(count:)` and
`set_arena(arena:)`) before `start_game`. This was abandoned: `start_game` now
receives `{ bots:, arena: }` directly, with the pre-call values as a fallback
(`s[:pending_bots]`, `s[:pending_arena]`). This makes the start atomic and keeps the
channel stateless between lobby and game start.

The host's start button reads the selected bot count and arena directly from the DOM
and sends them in the `start_game` message. `ArcadeCable.hostStart` was not used
because it sends `start_game` with an empty payload.

### 4. ActionCable channel actions that receive data must use required parameters

**The single most dangerous gotcha discovered during this build.**

ActionCable's `dispatch_action` (Rails 8) checks `method(action).arity == 1` before
deciding whether to pass the incoming data hash to the action method. If arity is
not exactly 1, the method is called with no arguments.

`def start_game(data = {})` has arity `-1` (optional parameter). ActionCable calls
it with no arguments; `data` is always `{}` regardless of what the client sent. No
exception is raised. The failure is completely silent.

Rule: **any channel action that reads from its `data` argument must declare it as a
required parameter** (`def start_game(data)`). Actions that ignore their data should
use `def foo(_data = {})` or omit the parameter entirely.

This bit `start_game`, `set_bots`, and `set_arena` in the same channel. All three
were fixed to required parameters before the game worked correctly.

---

## Consequences

- Phone-as-display is now an established pattern. The next game using it should
  follow the same spine: `include ArcadeSession`, no TV Stage, `arcade_after_subscribe`
  creates the session, positions broadcast to all.
- Any future channel action that receives data must use a required parameter. This
  is a project-wide rule, not just for Mammoth Games.
- Bot AI runs on the `move` cadence. If a game has very low move frequency (e.g.
  a turn-based game), bots would need their own timer rather than piggybacking.
- The pre-call pattern (`set_bots`, `set_arena` as separate messages) was viable
  once the arity bug was fixed, but was still replaced with inline-in-start-game for
  simplicity. It remains available if a future game needs pre-start host config that
  is too complex to embed in `start_game`.

## Related

- ADR 009 -- QR-Code Join (one-scan join used here)
- ADR 010 -- The Phone Contract and the Shared Arcade Session (spine this game runs on)
