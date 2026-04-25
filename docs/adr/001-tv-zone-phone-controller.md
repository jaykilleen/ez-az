# ADR 001 — TV Zone: Single-Scan Reactive Phone Controller

**Status:** Accepted  
**Date:** April 2026

---

## Context

EZ-AZ runs on a TV. People sit across a room from it. The interface has to work from a couch, which means no keyboard, no mouse, and often no app install. We needed a way for phones to become controllers without friction — no separate URL to type, no per-game setup, no page navigation on the phone.

The breakthrough moment: what if one QR scan was the only thing you ever needed to do? Scan it when you walk in the door, and your phone just... follows the TV.

The complications this creates:
- Phones connect at different times. A phone that scans late needs to know what's already happening.
- Different games need completely different phone UIs. Trivia needs a buzzer. A shelf needs a D-pad. A lobby needs a join form.
- The phone and TV are on the same ActionCable server but must stay in sync without page reloads.

---

## Decision

### One token, one subscription, everything flows from that

The TV generates a short token (8 uppercase alphanumeric characters) at page load. That token is:
- Encoded in the QR code displayed on screen
- Stored in `sessionStorage` before any page navigation, so trivia/game pages inherit it
- Used as the stream key: `tv_remote:{token}`

The phone subscribes to `TvRemoteChannel` with that token. That subscription lasts for the whole session regardless of what game the TV navigates to.

### TV broadcasts its own state — phones react

The TV calls `set_state` on `TvRemoteChannel` whenever the screen changes:

```
shelf  → phones show D-pad
lobby  → phones show join form (or D-pad if already joined)
game   → phones show game-specific UI (buzzer, waiting, etc.)
```

This is the core insight: **the phone doesn't navigate, the TV tells it what to be.** The phone is a reactive shell, not a separate application.

### In-memory state cache for late subscribers

`TvRemoteChannel` keeps a `STATES` hash (Mutex-protected) with the last `set_state` payload per token. When a phone subscribes — even ten minutes after the TV launched — it immediately receives the current state and lands on the right screen.

```ruby
STATES       = {}
STATES_MUTEX = Mutex.new

def subscribed
  STATES_MUTEX.synchronize { transmit(STATES[clean_token]) if STATES[clean_token] }
end
```

### In-game join is a channel action, not a page load

For party games like Family Trivia, phones join the game room directly via `TvRemoteChannel#join_room`. No browser navigation. The channel creates the membership, broadcasts to `RoomChannel`, and transmits the player's slot/colour back to the phone. The phone then subscribes to the game-specific channel (e.g. `TriviaChannel`) in JavaScript.

### The phone Zone is a stateless reactive shell

`tv_remote/show.html.erb` renders all possible screens upfront and shows/hides them based on what the TV broadcasts. There is no server-rendered state on the phone — it's entirely driven by ActionCable events. This means the page never needs to reload.

Screens (as of April 2026):
- `shelf` — D-pad + browse hint
- `lobby` — join form (name input, join button) or D-pad if already joined
- `waiting` — player list, host note, D-pad still visible
- `buzzer` — game UI (reading / answering / locked / result)
- `watching` — D-pad only, for non-joined observers
- `disconnected` — reconnect guidance

---

## Consequences

### Every TV-optimised game must call `set_state`

When a game launches, it must announce itself:

```javascript
tvRemoteSub.perform('set_state', { state: 'game', room_code: code, game_title: 'My Game' });
```

When it exits, the TV should navigate back to `/tv` which triggers `set_state({ state: 'shelf' })` automatically on connect.

### `ALLOWED_STATES` must be extended for new game types

Currently: `['shelf', 'lobby', 'game']`. If a new game introduces a fundamentally different phone state (e.g. a drawing game where phones are canvases), `ALLOWED_STATES` in `TvRemoteChannel` should be extended and a new screen added to the Zone.

### The phone game UI is pluggable by convention, not by framework

There's no formal plugin system. The convention is:
1. When the TV calls `set_state({ state: 'game' })`, the phone Zone switches to the `buzzer` screen
2. The `TriviaChannel` (or equivalent) drives what's shown within that screen via ActionCable events
3. The game-specific channel must be subscribed to from within the Zone JS after joining

Future games should follow this same pattern: get into the game screen via TV state, then drive sub-states via their own channel.

### D-pad is always available as the fallback

Even while waiting for a game to start, or watching a game as a non-player, the D-pad remains accessible. The `DPAD_SCREENS` set in the Zone controls this. By default: `shelf`, `lobby`, `waiting`, `watching`. Game-only screens (`buzzer`) intentionally hide the D-pad because the phone UI replaces it.

---

## What we're landing on

This isn't just a feature. It's a product philosophy: **EZ-AZ is a place you go with your family, not just a website you load.** The TV is the campfire. The phones are the instruments. One scan and everyone's playing.

The engine should treat this as infrastructure, not an add-on. Any game tagged `tv_optimised: true` should get Zone support for free.

---

## Future directions

- Pluggable phone screens: games declare their phone UI in a manifest, the Zone loads it
- Multi-game Zone: the token persists across games, so phones don't need to rescan between sessions
- Spectator mode: non-joined phones see a read-only game summary
- Theme picker: lobby screen lets the TV host configure the game before it starts
- NAPLAN packs: curriculum-aligned question sets selectable from the lobby
