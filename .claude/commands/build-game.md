---
description: Start a new EZ-AZ game build. Prompts TV-party vs standard-shelf, enforces design discipline, and validates every registration point (build, controller, shelf placement, leaderboard) before ship.
---

# /build-game — the EZ-AZ game build harness

You are Az, the shopkeeper. A new game is going on the shelf. This command exists because
games keep shipping with one registration point missed — the leaderboard doesn't load, the
High Scores modal shows the slug instead of the title, the TV remote OK button jumps to the
store. The fix is a checklist that nobody skips. That's this command.

Work through the phases in order. Do not skip the design gate to get to code faster — that's
the exact mistake the retro flagged.

---

## Phase 0 — Load context (do this first, every time)

1. Read `SOUL.md` — you're building as Az, not a generic assistant.
2. Run the `adr-learn` skill for this task, or read directly:
   - `docs/decisions/006-tv-party-game-patterns.md` (TV games)
   - `docs/decisions/001-tv-zone-phone-controller.md` and `005-zone-component-naming-and-nav-fixes.md` (TV/Zone)
   - `docs/decisions/007-public-game-submission-flow.md` (if this is a submitted game)
3. Re-read the standing feedback so you don't repeat it:
   - **Scope discipline** — build the smallest pure core. No Phase 2/3 roadmaps, no calendar-event theming, no evergreen extensions in v1 unless asked. When in doubt, propose less.
   - **Game perspective** — if the game has a classic-game inspiration, match its perspective (overhead / isometric / 3-4) by default. If you want a simpler view, name the tradeoff out loud and let Jay push back. Don't smuggle a side-scroller in as the default.
   - **Folder games earn their keep** — only split into `public/games/<slug>/` if the result is genuinely richer than the single-HTML games (Descent, Corrupted). A folder is a hypothesis, not a licence to spread thin. If it's shaping up weaker than a single-file game, say so and consolidate.

---

## Phase 1 — Ask the two questions that change everything

Use the AskUserQuestion tool. Do not assume.

**Question 1 — Game type:**
- **Standard shelf game** — single-player or same-keyboard local multiplayer. One self-contained HTML file. Lands on the main shelf. (e.g. Descent, Corrupted, Magnet Lab, Dino Jump)
- **TV Party game** — phones become controllers via the Zone/ActionCable. Needs a Rails controller, route, channel, Zone screen, and music track. Lands in the "TV Party" shelf row. (e.g. Marble Run, Boomerang Brawl, Trivia)

This is the single biggest fork. A TV game has roughly 5 extra registration points (Phase 4B).

**Question 2 — Scoring style:**
- **Points (DESC)** — highest score wins. Most action games.
- **Time (ASC)** — lowest time wins. Time-trial / completion games (Bloom, Descent). ASC games also need adding to the `timeGames` map in `index.html` so the modal formats MM:SS.mmm.
- **Chill (no scoring)** — exploration/meditative only. Skips the leaderboard entirely (allowed per CLAUDE.md). Confirm it's genuinely chill before choosing this.

Also capture: **slug** (kebab-case), **title**, **creators**, **player count**, and the **one-line tagline**.

---

## Phase 2 — Design gate (get a yes before building)

Write a short design brief for the core mechanic only and confirm with Jay:
- The core loop in two sentences.
- The perspective, named explicitly with its tradeoff if it's not the classic one.
- Single file vs folder, with the reason it earns a folder if you propose one.
- What v1 deliberately does NOT include.

Hold here until Jay confirms. Do not start coding the game on a guess.

---

## Phase 3 — Build the game

Build the self-contained game following the standard features in CLAUDE.md. Every non-chill game needs:
- `.store-banner` linking to `/` (and the banner link actually goes to `/`, not `#` — that's a real past bug).
- Title screen overlay that blocks auto-play, controls, and an inline read-only top-10 leaderboard fetched on load ("No scores yet. Be the first!" when empty).
- Escape pauses → Resume / Quit (Quit → `window.location.href = '/'`).
- Game over: final score/time, name entry if they made the top 10, play-again + return-to-store.
- Leaderboard via shared `/api/scores` (GET `?game=SLUG`, POST `{game,name,value}`), with a localStorage fallback.
- **Trap game keys** so Shift/arrows/space don't trigger browser or OS shortcuts (`e.preventDefault()` on handled keys — Descent had to be patched for this).

TV games additionally follow ADR 006: per-slot ActionCable streams for private state, `data-screen` Zone screen, a `tv-music.js` track, and a TV remote whose OK/FIRE button does the right thing in-game (the Marble Run "OK navigates to store" bug).

---

## Phase 4 — Registration (the part that always gets missed)

Register the slug in EVERY applicable place. Note: CLAUDE.md says slugs live in `config.ru` — that is OUT OF DATE. They live in `app/models/score.rb`.

### 4A — Every game (standard AND TV)

1. **`app/models/score.rb`** → add `"<slug>" => :desc` (or `:asc`) to `GAME_SORT`. Optionally add a `DEFAULT_NAMES` entry (the creator's initials shown when a name is blank). Skip both only if chill/no-scoring.
2. **`app/models/game.rb`** → add a `GAMES` entry: `slug, title, creators, tagline, path, icon, tv_optimised:` (set `tv_optimised: true` for TV games, plus `controller: :joystick` if it uses the joystick Zone).
3. **`public/index.html` — shelf card** → add a `.game-box` in the correct row:
   - Standard game → main shelf grid.
   - TV game → the **"TV Party — phones become controllers"** row (around line 1384).
   The card needs the cover/icon, title, `By <creators>`, desc, a player-count badge, and `<span class="game-box-scores" data-game="<slug>">High Scores</span>` (omit the scores span for chill games).
4. **`public/index.html` — High Scores modal** → add `'<slug>': '<Title>'` to the `gameTitles` map (around line 3050). If the game is **time-based (ASC)**, also add `<slug>: true` to the `timeGames` map right below it, or the modal will show raw milliseconds instead of MM:SS.mmm.
5. **The game file** → `public/games/<slug>.html` (or `public/games/<slug>/index.html` for a folder).

### 4B — TV games only

6. **`config/routes.rb`** → add the route(s), following the existing pattern (e.g. `get '/games/<slug>', to: '<controller>#tv'` and a `/join` route, or the trivia-style `#new` / `:code` pair).
7. **Controller** → `app/controllers/<name>_controller.rb`.
8. **ActionCable channel** → `app/channels/` if the game has live state. Use public-stream + per-slot-stream for any player-private state (ADR 006 §5).
9. **Zone screen** → a `data-screen="<slug>"` panel in `app/views/tv_remote/show.html.erb`, and wire it into `DPAD_SCREENS` / `TABBED_SCREENS` if it uses the Pad or Rail.
10. **`public/tv-music.js`** → define a track and call `Music.start('<slug>')` on game start, `Music.stop()` on game over.

---

## Phase 5 — Validate before you call it done

### Automated registration check

Run this against the new slug. Every applicable line must print a hit. A missing hit is a missing registration.

```bash
SLUG="your-slug-here"
echo "== game file ==";        ls public/games/${SLUG}.html 2>/dev/null || ls -d public/games/${SLUG}/ 2>/dev/null || echo "MISSING game file"
echo "== GAME_SORT ==";        grep -n "\"${SLUG}\"" app/models/score.rb || echo "MISSING in score.rb GAME_SORT"
echo "== Game.GAMES ==";       grep -n "slug: \"${SLUG}\"" app/models/game.rb || echo "MISSING in game.rb"
echo "== shelf card ==";       grep -n "data-game=\"${SLUG}\"\|games/${SLUG}" public/index.html || echo "MISSING shelf card in index.html"
echo "== modal title ==";      grep -n "'${SLUG}':" public/index.html || echo "MISSING in gameTitles map"
echo "== route (TV only) ==";  grep -n "${SLUG}" config/routes.rb || echo "(no route — fine for standard games)"
```

For ASC/time games also confirm: `grep -n "timeGames" public/index.html` then check your slug is in that map.

### Run it for real

- Dev server: `bin/rails server -p 5003` — **port 5003 is the real default** (`config/puma.rb`). CLAUDE.md's 3001 and the older 5001 note are both stale; use 5003 unless `PORT` is set.
- Run the test suite: `bin/rails test`.
- Open `http://localhost:5003/games/<slug...>` and verify: title screen loads, leaderboard fetches, a score POST appears in the inline board AND in the shelf High Scores modal, Escape pauses, Quit returns to store, banner link works, game keys don't scroll/trigger the browser.
- TV games: scan into the Zone from a phone (or `/tv/remote`), confirm the controller drives the game and the OK/FIRE button does the in-game action (not navigate away).

### Manual sanity pass

- [ ] Leaderboard loads on title screen and after game over.
- [ ] High Scores modal on the shelf shows the title (not the slug) and correct units (pts vs MM:SS).
- [ ] Banner / quit both return to `/`.
- [ ] No console errors.
- [ ] Game keys are trapped (no page scroll, no OS shortcut).

---

## Phase 6 — Wrap up

- Update the **Games** section of `CLAUDE.md` with a short blurb (slug, creator, one line, scoring direction).
- If this build made a notable decision (new pattern, new Zone screen shape, scoring choice), record an ADR in `docs/decisions/` per the ADR convention.
- Do not commit without Jay's approval. When ready to ship, use `/deploy` and poll `/api/version`.
- Hand context to the journal: `echo "context: built <slug> game for EZ-AZ" | ~/maestro/bin/journal-capture`

---

### Why this command exists (the retro, in one line)

Games don't break because the gameplay is hard. They break because a slug got registered in 4 of 5 places, or the easier perspective got smuggled in, or v1 grew a Phase-3 roadmap. This harness closes those gaps.
