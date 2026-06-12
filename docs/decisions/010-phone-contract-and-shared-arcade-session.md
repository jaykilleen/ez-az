# ADR 010 — The Phone Contract and the Shared Arcade Session

**Status:** Accepted
**Date:** 12 June 2026

---

## Context

Jay and the boys tried to play the two newest TV party games — Snake Pit Royale and Golden
Goal — from the couch and could not. Four things failed in real play:

1. The new games did not use the standard Zone controller; each was a bespoke implementation.
2. No phone was "host", so nobody could start the game — start only worked from a button on
   the TV itself, which needs a keyboard or mouse plugged into the telly.
3. Once in, players had no way to exit from their phone.
4. Quitting wedged the session, so the only way back to the TV party home screen was to
   restart the entire TV.

A pipeline audit (run on Fable 5) traced every failure to the same root: these games are
"arcade join page" games (a dedicated `/<slug>/join` page + a game-specific ActionCable
channel) that copied each other without ever satisfying the invariants the Zone gives the
server-rendered party games for free. Golden Goal's channel was a near line-for-line copy of
Snake Pit's, so both carried the identical defects, including a `location.reload()` rematch
that minted a new join code and orphaned every connected phone, and an in-memory `SESSIONS`
hash that leaked one entry per match forever.

CLAUDE.md had recorded the divergence ("dedicated join page, not the unified Zone") as if it
were an accepted pattern. It was not a decision; it was an unreviewed shortcut.

---

## Decisions

### 1. The Phone Contract — ten clauses every phone-controlled TV game must satisfy

Codified in `/build-game` Phase 4C. A TV party game is not done until all ten hold, whether it
uses the Zone or a bespoke join page:

1. No keyboard, no mouse — every interactive TV state is reachable from a phone.
2. The TV listens to the remote (TvRemoteChannel), announces via `set_state`, maps `navigate`
   onto its own UI, and handles `tv_home` → `/tv`.
3. Start cannot depend on a single absent device — host election or a phone start control.
4. The phone always has a reachable EXIT; the channel exposes `leave` valid in every phase.
5. A hung or quit game recovers without restarting anything — quit broadcasts a terminal
   event and resets the session.
6. Rematch keeps the party together — reuse the join code, never regenerate it.
7. Sessions die — in-memory stores get a TTL/sweep and cleanup on TV unsubscribe.
8. One-scan join (QR), per ADR 009.
9. The recovery contract is honoured — `ezaz_active_tv_game` + the `/tv` resume map.
10. Divergence from the Zone needs an ADR that states, clause by clause, how it is met.

`/build-game` Phase 5 now also has a "couch test" run with hands off the keyboard, plus an
automated grep gate (the `location.reload()` check, the TV-only-start check, the no-TTL-session
check) so these defects are loud at build time, not discovered on the couch.

### 2. A shared `ArcadeSession` concern owns session lifecycle

Rather than fix two copies, the common shape was extracted to
`app/channels/concerns/arcade_session.rb`. It owns the `SESSIONS` store (with `created_at` and a
4-hour sweep), slot assignment, host election (first joiner is host; promotion on host drop),
`join` / `leave` (valid in **every** phase) / `start_game` (`tv? || host?`) / `game_ended` /
`abort` (terminal reset to lobby). Game-specific state stays in the game channel via two hooks:
`arcade_after_subscribe` (extra streams) and `arcade_player_disconnected(slot)` (bot-fill the
avatar). A game adopts it with `include ArcadeSession` + `arcade_prefix "<name>"`.

### 3. Shared phone and TV clients

`public/arcade-cable.js` gives the phone a cable client, a universal EXIT (`attachExit` → `leave`
then `/`), and a host-aware START (`hostStart`). `public/arcade-tv.js` gives the TV the remote
subscription (`connectRemote` → TvRemoteChannel + `set_state` + `navigate`/`tv_home` handling), a
focus-button model (`setButtons`), a code helper that accepts `?code=` (`sessionCode`), and the
resume-contract writers (`saveActiveGame`/`clearActiveGame`).

### 4. Both games rebuilt on the shared spine

Snake Pit Royale and Golden Goal were refactored onto the concern and the two clients. Golden
Goal's secret-pick mechanic (the TV-private `golden_goal:#{code}:tv` stream from ADR 009 §2)
layered on through `arcade_after_subscribe` with zero changes to the shared code.

---

## Compliance — clause by clause (clause 10)

Both games keep their bespoke join pages, so this ADR is their required waiver.

| Clause | Snake Pit Royale | Golden Goal |
|--------|------------------|-------------|
| 1 No keyboard/mouse | Pass — every screen's buttons registered via `ArcadeTV.setButtons` | Pass — title/pause/game-over/SAVE registered |
| 2 TV listens to remote | Pass — `connectRemote`, `set_state`, `tv_home` → `/tv` | Pass — same |
| 3 Host/phone start | Pass — first joiner host, phone START, drop-promotion | Pass — same |
| 4 Phone EXIT + `leave` | Pass — EXIT on every screen, `leave` any phase | Pass — same |
| 5 Recover without restart | Pass — QUIT → `abort` → `session_reset` | Pass — same |
| 6 Rematch keeps party | Pass — reuse code, no reload | Pass — `location.reload()` removed |
| 7 Sessions die | Pass — TTL sweep + empty-session destroy | Pass — same |
| 8 One-scan join | Pass — QR (ADR 009) | Pass — QR (ADR 009) |
| 9 Resume contract | Pass — `ezaz_active_tv_game` + `/tv` map | Pass — same |

Verified by 56 new channel tests (26 Snake Pit, 30 Golden Goal) and headless browser runs.
The on-hardware couch test — real phones scanning in, the Zone pad feel, `tv_home` from a
device — still needs a physical pass.

---

## Consequences

- New TV party games adopt the spine with `include ArcadeSession` + the two client scripts;
  the Phone Contract is the bar they must clear, enforced by `/build-game`.
- Marble Run and Dino Jump carry the same pre-fix disease (no host, no phone exit, wedge on
  quit). They are the next two to drop onto this spine; they were deliberately left out of this
  pass to get the two worst offenders right first.
- CLAUDE.md's "dedicated join page, not the unified Zone" framing is corrected: a bespoke join
  page is allowed, but only if it satisfies the Phone Contract and cites an ADR.
- The TV-private-stream pattern (ADR 006 §5, ADR 009 §2) composes cleanly with the shared
  session via `arcade_after_subscribe`.
