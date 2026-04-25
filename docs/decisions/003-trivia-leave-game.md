# ADR 003 — Trivia: Leave Game from Waiting Screen

**Status:** Accepted  
**Date:** April 2026

---

## Context

Once a player joined a Family Trivia room from their phone controller, they had no way to leave. The waiting screen (joined, host hasn't started yet) had no back button and no tab menu — the tab menu only appears during the active buzzer screen. The player was stuck: couldn't return to D-pad mode, couldn't undo joining the game.

## Decision

Add a `leave_room` action to `TvRemoteChannel`. When called:

1. The membership record is destroyed.
2. `RoomChannel.member_left` is broadcast so the TV and other players see the updated room.
3. A `left` message is transmitted back to the phone.

On the phone, a "Leave Game" button sits at the bottom of the waiting screen. Tapping it calls `leave_room`, and on receiving `left` the client clears its slot state, unsubscribes from `TriviaChannel` and `RoomChannel`, and returns to the lobby screen.

## Why

The waiting screen is the only place a player can reconsider before the game starts. Once the game begins, the tab menu's Options tab already has an exit path. The gap was specifically the pre-game waiting state.

Destroying the membership rather than soft-disconnecting keeps the room clean — the slot is freed for another player. The existing `RoomChannel.member_left` broadcast was already built for exactly this event.

## Files changed

- `app/channels/tv_remote_channel.rb` — `leave_room` action added
- `app/views/tv_remote/show.html.erb` — "Leave Game" button, `handleLeft` handler, message dispatch wired
