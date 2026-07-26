---
Date: 2026-07-26
Status: Accepted
Related: ADR 011, ADR 014
Triggers:
  - building a new EZ-AZ game
  - changing a title screen, leaderboard, pause overlay or store banner
  - deciding whether something belongs in a game or in the shell
  - migrating an existing game onto the shared wrapper (BL-016)
  - adding an option to ArcadeShell
Topics: design-system, shell, games, arcade-shell, tooling
---

# ADR 015 -- The Wrapper Around a Game Is Shared Code, Not a Snippet

## Context

ADR 011 extracted the visual primitives that wrap a game into
`public/ez-az-shell.css`. It stopped short of the behaviour: `docs/design-system.md`
documented `renderLb`, `saveScore`, the leaderboard fetch and the pause handling
as **snippets to paste into each game**.

Thirteen games each pasted their own copy, and they drifted. By 2026-07-26:

- Ten of thirteen games did not link the shared stylesheet at all, so each
  carried its own store-banner CSS.
- Every game had its own leaderboard fetch, render, submit and "did I make the
  board" check. They disagreed. Magnet Lab offered name entry for any score
  above zero rather than checking the board.
- Each had its own HTML escaping, its own localStorage key and shape.
- The shelf kept its own table of which games rank ascending. It listed two of
  the four, so hacker-pro's times rendered as `"N pts"`.

Writing a new game therefore meant re-implementing the controls and the
navigation before writing any of the game. That is the wrong ratio.

## Decision

**The shell is shared code. A new game writes the game and nothing else.**

Three pieces, each with one job:

| File | Owns |
|---|---|
| `public/ez-az-shell.css` | How the wrapper looks -- tokens, `.ezaz-` components |
| `public/arcade-shell.js` | How the wrapper behaves -- the `ArcadeShell` runtime |
| `docs/game-template.html` | Where a new game starts |

`ArcadeShell` covers the store banner, the leaderboard (fetch, render, submit,
qualify), score formatting, and the Escape pause overlay. It sits alongside
`arcade-cable.js` (ActionCable) and `arcade-tv.js` (phone-to-TV input), which
cover multiplayer; the wrapper applies to single-player games too.

A new game copies the template, fills in three marked sections -- styles, loop,
input -- and calls `gameOver()`. That is the entire contract.

### Corollaries

**If a wrapper piece is missing, add it to the shell.** Late Shift needed a
board padded out to ten rows; the shelf modal did the same thing independently,
so it became `renderLeaderboard`'s `fill` option rather than a per-game quirk.

**Clients never keep their own copy of the ranking direction.** `/api/scores`
returns `sort`, and `ArcadeShell` reads it. A local table is what broke
hacker-pro.

**The shell is served `no-cache`.** Game HTML is already uncached, so caching
its runtime for an hour lets a deployed game call a newer option than the
browser holds -- and the option is silently ignored rather than erroring. See
`StaticCacheHeaders::ALWAYS_FRESH`.

**Gameplay stays with the game.** A canvas-drawn pause, an in-game HUD clock,
the game's own board heading -- these are not wrapper concerns. `title: null`
exists so a game can keep its own heading.

### Enforcement

- `ShellAdoptionTest` -- a new game must use the shell. Games predating it are
  listed in `PRE_SHELL_GAMES`, which may shrink and never grow. It covers
  folder games as well as single files.
- `e2e/title-leaderboard.spec.js` -- asserts the rendered markup, per game,
  for both pre-shell and migrated rendering.
- Both the Rails and Playwright suites gate the deploy.

## Consequences

- A new game starts from a template with the wrapper already working, which
  was the goal.
- Fixing the wrapper once fixes it everywhere -- but only for migrated games,
  so the value grows as BL-016 proceeds.
- Migrating an existing game changes the markup its tests assert on. Three
  separate specs broke migrating Bloom alone. That is why the e2e suite now
  runs in CI.
- Existing games are migrated one at a time with a browser check, not in a
  sweep. They are large self-contained files whose gameplay cannot be
  automatically playtested, so a bad edit costs a working game.
- `ArcadeShell` itself has no automated unit coverage -- it is plain browser
  JS and this project has no JS unit harness. It is exercised only indirectly
  through the Playwright specs. Worth revisiting if it grows much further.
- This does not settle BL-001, which is about whether the arcade and broadcast
  registers should look the same. This ADR shares the *skeleton*; each game
  keeps its own skin.
