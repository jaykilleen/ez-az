---
Date: 2026-06-07
Status: Accepted
Related: ADR 006, ADR 007
Triggers:
  - building a new EZ-AZ game (use /build-game)
  - finishing or stalling on a build and wanting to learn from it (use /build-retro)
  - deciding where a "Claude keeps getting X wrong" lesson should live
  - registering a new game slug across score.rb, game.rb, index.html
  - wondering why feedback memories exist or how they get written
Topics: process, build-process, retro, knowledge-management, feedback-memories, games
---

# ADR 008 -- Build → Retro → Memory Loop for EZ-AZ Games

## Context

Adding a game to EZ-AZ touches up to six disconnected registration points: the game file in
`public/games/`, `GAME_SORT` (+ `DEFAULT_NAMES`) in `app/models/score.rb`, the `GAMES` array in
`app/models/game.rb`, the shelf card in `public/index.html`, the `gameTitles`/`timeGames` maps in
the same file, and — for TV games — a route, controller, ActionCable channel, Zone screen, and
`tv-music.js` track. The git history is full of "fix leaderboard", "fix TV remote nav", and
"fix EZ-AZ logo link" commits: each one is a registration point that was missed because nothing
enforced the full list.

A second, slower failure ran in parallel. The same design mistakes kept recurring — scope creep
(Spotlight grew Phase 2/3 features before v1 shipped), the easier perspective getting smuggled in
(Letterbox shipped as a side-scroller instead of Paperboy's 3/4 overhead), and hollow folder games
(Letterbox v1 split into files without earning the split). Jay had been hand-writing these lessons
into feedback memories (`feedback_scope_discipline.md`, `feedback_game_perspective.md`,
`feedback_folder_games.md`) after each one bit. The lessons existed, but nothing guaranteed a build
read them before starting, and nothing guaranteed a finished build wrote new ones.

The loop was open: knowledge was being captured by hand, inconsistently, and not reliably consumed.

Compounding both: the documentation had drifted. `CLAUDE.md` claimed game slugs lived in
`config.ru` (they live in `score.rb`) and that the dev server ran on port 3001 (it is 5003, set in
`config/puma.rb`); a memory said 5001. Fresh sessions were being misled by their own source of truth.

## Decision

Two slash commands form a closed loop, with the project's **feedback memories as the durable
learning layer** between them.

### `/build-game` — the build harness (consume)

`.claude/commands/build-game.md`. A six-phase harness run at the start of every new game:

1. **Phase 0** loads SOUL, the relevant ADRs, and re-reads the three standing feedback memories
   (scope discipline, perspective, folder-earns-keep) so prior lessons bind before any code.
2. **Phase 1** asks two forking questions via AskUserQuestion — TV-party vs standard-shelf, and
   scoring style (points DESC / time ASC / chill) — plus slug, title, creators, tagline.
3. **Phase 2** is a design gate: confirm a core-only brief before building.
4. **Phase 3** builds against the standard game-feature checklist.
5. **Phase 4** registers the slug in every applicable place (the six points above), split into
   "every game" and "TV games only".
6. **Phase 5** validates with a copy-paste bash check that greps the slug across all registration
   points and flags any MISSING, then runs the app on the correct port (5003).
7. **Phase 6** wraps up: CLAUDE.md blurb, ADR if warranted, journal handoff.

### `/build-retro` — the retrospective (produce)

`.claude/commands/build-retro.md`. Run after a build ships or stalls:

1. Gather evidence from the git log (fix/revert commits **are** the retro), not from memory.
2. Produce an honest three-column review — what worked / what didn't / what was a slog — with an
   explicit rule against self-flattering summaries, and the load-bearing question for each problem:
   "what would have to be true next time for this not to happen?"
3. Route each learning to where the next build reads it (see table below).
4. Close out to the journal.

### Feedback memories are the connective tissue

The routing table is the heart of the decision:

| Kind of learning | Destination |
|---|---|
| A correction Jay made / "Claude keeps doing X" | a `feedback_<slug>.md` memory + `MEMORY.md` pointer |
| A weak/missing build step | a checklist item in `/build-game` |
| A wrong or stale codebase fact | a fix to `CLAUDE.md` (and the relevant memory) |
| A real architectural decision | an ADR via `/adr` |
| Ongoing-work context, not a rule | a project memory + `MEMORY.md` pointer |

`/build-game` Phase 0 reads the feedback memories that `/build-retro` writes. That is the loop.

### Source-of-truth corrections

As part of establishing the loop, the known drift was fixed: `CLAUDE.md` now points slug
registration at `app/models/score.rb` (not `config.ru`) and names port 5003 (not 3001); the
`dev_server` memory and `MEMORY.md` pointer were corrected from 5001 to 5003.

## Consequences

- Missed registration points become catchable before ship: the Phase 5 grep is a mechanical gate,
  not a hope that the author remembered all six places.
- Recurring design mistakes get a systematic capture-and-replay path instead of relying on Jay to
  hand-write a memory and on the next session to happen to read it.
- The feedback memories gain a defined producer (`/build-retro`) and consumer (`/build-game`), so the
  directory stops being an ad-hoc scratchpad and becomes a maintained learning layer.
- There is now a standing expectation that a finished build runs a retro. Skipping it leaves the
  loop open — the cost is silent (the same mistake recurs later), so the discipline has to be held.
- `/build-retro` is deliberately honest-by-design. If it degrades into tidy summaries that change
  nothing, it has failed its own stated standard and the loop is decorative.
- The commands are EZ-AZ-specific (they encode this repo's six registration points and game
  conventions). The *pattern* — a consume command and a produce command bracketing a shared memory
  layer — is portable to other projects if it proves out here.
- CLAUDE.md and the dev-server memory now match reality, so fresh sessions stop being misled by
  stale facts. Future drift of this kind is itself a `/build-retro` finding routed to CLAUDE.md.
