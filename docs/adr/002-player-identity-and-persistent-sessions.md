# ADR 002 — Player Identity and Persistent Sessions

**Status:** Proposed  
**Date:** April 2026

---

## Context

ADR 001 established the TV Zone as a reactive phone controller. It works well for one session in one room. But it has a short memory.

Every time the TV page loads, a new token is generated. Every time a phone opens the Zone page, a new `phoneId` is rolled. If a phone disconnects — battery died, kid accidentally navigated away, or the game crashed — the server has no idea who that phone was. The slot is gone. You're starting fresh.

This matters now for two reasons:

**Reconnect.** During play, disconnections happen. A player should be able to tap back to the Zone page and land in their slot automatically, not lose their place.

**Remote play.** EZ-AZ was built for the same room. But kids move. The two cousins who used to sit on the same couch now live in different cities. The architecture shouldn't assume physical proximity. A room code you can text to someone should work just as well as a QR code you scan from across the room.

The DB already has `Room`, `RoomMembership`, and `Player` — built for Family Trivia. But party games (Space Dodge, D-pad games) bypass all of it. Player-to-slot assignment lives in a Ruby hash that evaporates on server restart. There's no DB record of who was in a game.

The fix is to extend the existing infrastructure, not build something new beside it.

---

## Decision

### Player identity is a device claim, not an account

We're not doing email addresses or passwords. The friction is wrong for kids, and the games don't need it.

A `Player` is a name claimed from a device:

1. First visit: the Zone page prompts "What's your name?" (one-time, takes 3 seconds)
2. A `Player` record is created with that username
3. A `device_token` (32-char random hex) is returned and stored in `localStorage` forever
4. Every subsequent visit: the `device_token` identifies the player automatically — no prompt

To play on a different device, a player enters a **4-digit PIN** (optional, set on first claim, changeable). PIN + username = cross-device login. No PIN = single-device only.

The `Player` model gets:
- `username` (already exists)
- `device_token` — long random hex, indexed, used to auto-authenticate
- `pin_digest` — bcrypt of a 4-digit PIN, optional

There is no session cookie, no server-side session for players. The `device_token` in `localStorage` is the credential. It's sent with every ActionCable subscription as a param.

### TV sessions are DB-backed Rooms

When the TV page loads, it creates a `Room` record instead of just generating a token. That room:

- Has a `tv_token` (8-char, secure, used for ActionCable auth and QR code) — new field on `Room`
- Has a `code` (4-char, human-readable, used for remote join by typing)
- Has a `game_slug` (set when a game launches, cleared when returning to shelf)
- Expires after 4 hours (extended from the current 2-hour TTL)
- Is `active` while the TV tab is open, `finished` when the TV navigates away

The in-memory `STATES` hash in `TvRemoteChannel` stays for late-joiner state delivery (it's fast and appropriate for that), but the source of truth for "who is in this room" moves to `RoomMembership`.

### Slot assignment is DB-backed

When a phone connects to a room (by QR scan or by code entry), a `RoomMembership` is created:

- `room_id` — which room
- `player_id` — which player (optional — anonymous play still works)
- `slot` — 1 or 2 for D-pad games, 1–4 for Trivia
- `device_token` — copied from the player, or generated for anonymous sessions
- `session_id` — already exists, used for reconnect

For D-pad games, slot 1 = P1 (Arrow keys), slot 2 = P2 (WASD). These map to the existing `tv-engine.js` key maps. The server now assigns these instead of `tv-engine.js` doing first-come-first-served in-memory.

### Reconnect is automatic

When a phone opens the Zone page and has a `device_token` in `localStorage`:

1. `TvRemoteChannel#subscribed` receives the `device_token` as a param
2. Server looks for an active `RoomMembership` matching `device_token` + this room's `tv_token`
3. If found: transmits a `rejoined` event with the player's slot, name, and colour — phone is back in the game
4. If not found: normal join flow

The phone never shows "you were disconnected." It just comes back.

### Remote join uses the room code

The Zone page (`/scan`) gains a second entry point: a code input field. Below the "Open Camera" button, a small "Have a code?" link reveals a 4-char input. Type the code, tap Join, done.

The QR code path and the code-entry path converge at the same `TvRemoteChannel` subscription. From the server's perspective they're identical — just a `tv_token` lookup from a `Room` by either field.

```
QR code  →  extracts tv_token  →  subscribes to TvRemoteChannel
Code entry  →  looks up Room by code  →  gets tv_token  →  same subscription
```

The last-used room is stored in `localStorage` (both the `tv_token` and the `code`). If a phone already has a room in `localStorage`, the scan page shows "Rejoin [code]?" as the primary action — scanning or entering a new code is secondary.

---

## Consequences

### Room is no longer Trivia-only

The `Room` model was originally shaped around Trivia (host creates, players join, questions flow). Party D-pad sessions will now also create rooms. The `game_slug` field handles this — `nil` means "on the shelf", a slug means a specific game is running.

`Room` needs `tv_token` added via migration. Trivia rooms don't use `tv_token` (they're joined by code from the lobby, not QR scan), so it's nullable.

### Anonymous play still works, just without reconnect

If a phone joins without a name, it gets a temporary `RoomMembership` with no `player_id` and a short-lived `device_token`. This is identical to current behaviour. They just can't reconnect if they drop out.

The Zone page should nudge (not force) players to claim a name: "Add your name to save your slot."

### `tv-engine.js` slot assignment changes

Currently `tv-engine.js` assigns P1/P2 by first-input order entirely in JavaScript on the TV. With DB-backed slots, the server assigns slots at join time. `tv-engine.js` reads the slot from the `joined` broadcast instead of tracking order itself.

The `playerMap` logic in `tv-engine.js` simplifies: map `phone_id → slot` from server assignment, not from arrival order.

### The TV page is no longer stateless

Currently `/tv` is a simple Rails render. Now it needs to create a `Room` on load. That's a side effect in a controller action, which is fine — it's what the controller is for. On reload, the old room expires and a new one is created. If the TV navigates to a game and back, the existing room is reused (looked up by `tv_token` from `sessionStorage`).

### PIN is optional and not enforced

Cross-device login is a convenience, not a security requirement. If a player hasn't set a PIN and tries to log in on a new device, they get a new anonymous session. Their history doesn't follow them, but they can still play. We don't block anything.

---

## What we're landing on

A player is a name on a device. A game session is a room in the database. A phone that disconnects can find its way back because the server remembers it.

None of this is accounts and authentication in the traditional sense. There's no email to verify, no password to forget, no account to get locked out of. It's the minimum identity needed to keep your seat at the table when something goes wrong — which in a family living room, it will.

The same infrastructure that lets a kid reconnect after their phone dies is the same infrastructure that lets two kids in different cities play together. The room code works either way.

---

## What we're building first

1. **`device_token` on `Player`** — new field, generated on claim, returned to phone once and stored in `localStorage`
2. **`tv_token` on `Room`** — new field, created when TV page loads, used for ActionCable auth
3. **`device_token` on `RoomMembership`** — tracks which device holds each slot
4. **Name claim flow on Zone page** — one-time "What's your name?" prompt before joining
5. **Reconnect in `TvRemoteChannel#subscribed`** — check `device_token` param, restore slot if found
6. **Code entry on `/scan`** — "Have a code?" fallback alongside the camera

PIN and cross-device login are phase 2.

---

## Future directions

- PIN-based cross-device login (4 digits, optional, player-set)
- Player profiles: avatar, colour preference, game history
- Friends list: "Invite [name] to this room" generates a one-tap link
- Spectator mode: join a room without taking a slot, watch via ActionCable state broadcasts
- Persistent leaderboard identity: scores are attached to a `Player`, not just a name string
