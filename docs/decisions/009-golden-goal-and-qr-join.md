# ADR 009 — Golden Goal Penalty Shootout, and QR-Code Join for Static-File TV Games

**Status:** Accepted
**Date:** 12 June 2026

---

## Context

Two things landed together in this round:

1. **Golden Goal** — a new World Cup penalty-shootout TV party game by Az, built as the first
   proper test of the Fable 5 model. The brief came from Jay's first World Cup memory: being 9
   and watching Roberto Baggio miss his penalty as Brazil beat Italy in USA '94. Glory or
   heartbreak on one kick.
2. A gap surfaced while building it: the static-file real-time TV games (Snake Pit Royale,
   Dino Jump, and Golden Goal itself) showed players a **text join link**, not a scannable QR
   code. That breaks the core party promise of ADR 001 — one scan and you're in. Typing a URL
   on a phone from across the room is exactly the friction we set out to remove.

---

## Decisions

### 1. Golden Goal is built in three phases; only Phase 1 shipped

- **Phase 1 (shipped):** the core shootout. Striker and keeper each pick secretly on their
  phone (horizontal aim L/C/R + height HIGH/LOW = six target zones), lock with FIRE, then the
  TV reveals from the classic behind-the-striker camera. Exact-zone match = save. Players
  rotate through both roles; most goals-plus-saves wins. Az bots fill empty slots so a solo
  player gets a full match. Points-based, DESC leaderboard, slug `golden-goal`.
- **Phase 2 (future):** team selection, where each pick is a real World Cup final that went to
  a shootout — USA '94 (Brazil v Italy), Germany 2006 (Italy v France), Qatar 2022 (Argentina
  v France). Pick a side, wear the kit, the TV names the moment.
- **Phase 3 (future):** intensity layer — power-ups, ball curve, keeper feints, run-up timing
  bar, power meter.

The phased split keeps Phase 1 the smallest fun core (scope discipline) and leaves clean seams
for team/kit data and shot physics later.

### 2. Picks stay secret via a TV-private ActionCable stream

Snake Pit broadcasts every input on the public stream — fine for snakes, but it would leak a
penalty pick to the other phone. Golden Goal follows ADR 006 §5 instead: the TV subscribes to
both `golden_goal:#{code}` (public) and `golden_goal:#{code}:tv` (TV-only). A phone's locked
pick relays only on the TV-private stream, so no other phone ever sees it. The public stream
carries lobby, round setup, reveal results, scoreboard and game over.

### 3. A shared `/qr` endpoint gives static-file games scannable joins

Server-rendered TV views (trivia, treasure, boomerang, spotlight, hacker) already build their
QR with the `rqrcode` gem into `@qr_code_svg`. The static-file games served straight from
`public/games/*.html` can't run rqrcode inline. Rather than vendor a client-side QR library, we
added a small `QrController` at `GET /qr?url=...` that returns an `image/svg+xml` QR using the
same `rqrcode` styling. Static games embed `<img src="/qr?url=<encoded join url>">` in the
lobby and keep the short CODE as a fallback.

Security: `/qr` only encodes **same-origin (or relative) URLs** and caps URL length, so it can't
be abused as an open QR generator for arbitrary links.

This was wired into Snake Pit Royale, Dino Jump and Golden Goal, and the `/build-game` template
was updated to make a scannable QR mandatory for every future TV party game.

---

## Consequences

- New static-file TV games get QR joining by copying the `<img id="joinQr">` + `/qr?url=` pattern
  documented in `/build-game`. No per-game server view required.
- The TV-private-stream pattern is now used by two games (Treasure Hunt, Golden Goal); it is the
  canonical way to deliver any player-private state in a real-time TV game.
- Phase 2 of Golden Goal will need real-final/kit data and a lobby team-picker; Phase 3 will need
  shot physics. Both slot into seams left in the Phase 1 build.
- Built and validated by Fable 5: all 383 tests pass, a full phone-to-TV match was driven through
  a browser. Sound, music and real touch input were verified by code review only, not on hardware.
