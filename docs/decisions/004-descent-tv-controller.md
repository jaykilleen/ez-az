# ADR 004 — Descent: TV Controller Support

**Status:** Accepted  
**Date:** April 2026

---

## Context

Descent was built as a single-player game for local play (phone/tablet touch via `controls.js`, or keyboard). The EZ-AZ TV setup uses a phone as a D-pad controller — the TV runs the game, the phone sends navigate events via ActionCable (`TvRemoteChannel`).

Descent was `tv_optimised: false` (hidden from the TV shelf) because there was no bridge between the D-pad navigate events and the game's keyboard-based input system.

## How the TV controller pipeline works

1. The TV page (`/tv`) stores the room token and ActionCable path in `sessionStorage`
2. When the user selects a game, the TV browser navigates to the game URL — the TV page's ActionCable subscription is gone
3. The phone controller still holds its `TvRemoteChannel` subscription and sends navigate events (press/release per D-pad button)
4. A game that wants to receive these events must subscribe to `TvRemoteChannel` itself using the token from `sessionStorage`

## Decision

Add a `<script type="module">` at the bottom of `descent.html` that:

- Reads `tvRemoteToken` and `tvAcPath` from `sessionStorage` (set by the TV page on load)
- If not present, exits silently — the game runs normally for local play
- Connects to `TvRemoteChannel` and calls `set_state({ state: 'game', game_title: 'Descent' })` so the phone shows the D-pad and FIRE button
- Maps navigate `press`/`release` events to `keydown`/`keyup` events dispatched on the document, feeding directly into Descent's existing `keys` object
- Handles menu states (title, charSelect) by calling game functions directly (`showCharSelect`, `selectChar`, `startGame`) since those screens don't use the `keys` loop

## Button mapping

| D-pad | Descent action |
|-------|---------------|
| Arrows | Move |
| FIRE (action) | Sprint (Shift) |
| BACK | Pause / Resume (Escape) |
| OK (select) on title | Open character select |
| Left/Right on char select | Cycle characters |
| OK (select) on char select | Start descent |
| OK (select) on end screen | Play again (reload) |

## Why press/release matters

Descent uses a held-key model — the game loop reads `keys['ArrowLeft']` etc. every frame. Dispatching only `keydown` (as the TV shelf page does for shelf navigation) would cause the character to move forever after one tap. The game receives both `press` and `release` navigate events, dispatching the matching `keydown`/`keyup`.

## Files changed

- `public/games/descent.html` — TV remote script block added
- `app/models/game.rb` — `tv_optimised: true`
