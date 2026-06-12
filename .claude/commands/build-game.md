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

**The TV lobby MUST show a scannable QR code, not just a text link.** Phones join by scanning — typing a URL on a phone from across the room is the friction the whole party model exists to kill (ADR 001). Server-rendered TV views (trivia, treasure, boomerang) build the QR with the `rqrcode` gem into `@qr_code_svg`. The static-file real-time games (Snake Pit, Dino Jump, Golden Goal) can't run rqrcode inline, so they embed the shared `/qr` endpoint:

```html
<img id="joinQr" alt="Scan to join" style="width:180px;height:180px;background:#fff;border-radius:10px;padding:8px;" />
```
```javascript
var fullUrl = window.location.origin + '/<slug>/join?code=' + gameCode;
document.getElementById('joinQr').src = '/qr?url=' + encodeURIComponent(fullUrl);
```

Keep the short join CODE as a fallback, but the QR is the primary join path. `/qr` only encodes same-origin URLs.

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
9. **Zone screen** → a `data-screen="<slug>"` panel in `app/views/tv_remote/show.html.erb`, and wire it into `DPAD_SCREENS` / `TABBED_SCREENS` if it uses the Pad or Rail. If you build a bespoke join page instead of the Zone (the Snake Pit / Dino Jump / Golden Goal "arcade join" pattern), you do NOT get to skip the Phone Contract below — you must re-implement every clause of it by hand, and cite an ADR that lists how each clause is met. A bespoke page with no ADR is a bug, not a pattern.
10. **`public/tv-music.js`** → define a track and call `Music.start('<slug>')` on game start, `Music.stop()` on game over.

---

## Phase 4C — The Phone Contract (TV games — non-negotiable)

This phase exists because Snake Pit Royale and Golden Goal both shipped as TV party games that
could not actually be played from the couch: no host so nobody could start, no exit on the phone,
and a quit that wedged the TV until it was restarted. Every clause below is a real failure that
reached real kids. A TV party game is not done until ALL of these hold — whether it uses the Zone
or a bespoke join page.

1. **No keyboard, no mouse.** Every interactive state of the TV page — title/start, pause, game
   over, rematch — must be reachable using only connected phones. A physical keyboard or mouse at
   the TV is a debugging convenience, never a requirement to play.
2. **The TV listens to the remote.** Every `tv_optimised` page subscribes to its control channel,
   announces itself (`set_state` for Zone games), translates directional/select input into its own
   actions, and handles a **home** command by navigating to `/tv`. A phone pressing Home must
   recover the TV from inside the game.
3. **Start can't depend on one absent device.** Starting a match must work either from the Zone Pad
   reaching the TV, or from an explicit start control on a phone. Elect a host (first joiner is
   simplest) with a fallback if that phone drops. Never gate start solely on a button that only a
   keyboard/mouse at the TV can press.
4. **The phone always has a reachable EXIT.** Every phone screen state (join, lobby, playing, game
   over) shows an exit control that frees the player's slot server-side and returns the phone to a
   home state. The channel exposes a `leave` action valid in **every** phase, not just lobby.
5. **A hung or quit game recovers without restarting anything.** When the TV quits or aborts, it
   broadcasts a terminal event, resets the session to lobby (or destroys it), and releases the
   phones to a known screen. No session phase may become permanently unreachable.
6. **Rematch keeps the party together.** Play-again reuses the same code/room and returns joined
   phones to the lobby with their slots. Never regenerate the join code on rematch — that orphans
   every connected phone (the Snake Pit `location.reload()` bug).
7. **Sessions die.** Any in-memory session store has a TTL or is cleaned up when the TV
   unsubscribes. No unbounded module-level hash that leaks a session per match forever.
8. **One-scan join.** The TV lobby shows a scannable QR (Phase 3), not just a typed code.
9. **The recovery contract is honoured.** The TV page writes `ezaz_active_tv_game` on load, clears
   it on game over, and is registered in the `/tv` resume map (ADR 006 §7).
10. **Divergence needs an ADR.** Any game bypassing the Zone must cite an ADR that states, clause by
    clause, how it meets 1–9. CLAUDE.md prose describing a divergence as "the pattern" is not a
    decision record and does not waive this phase.

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
echo "== Phone Contract (TV only) ==";
echo "-- Zone screen OR bespoke-join ADR that names the Phone Contract --"; grep -n "data-screen=\"${SLUG}\"" app/views/tv_remote/show.html.erb || grep -l "Phone Contract" $(grep -rl "${SLUG}" docs/decisions/ 2>/dev/null) 2>/dev/null || echo "MISSING: no Zone screen AND no ADR containing a 'Phone Contract' clause table — not waived (clause 10)"
echo "-- TV listens to remote (clause 2) --";  grep -n "TvRemoteChannel" public/games/${SLUG}.html app/views/${SLUG//-/_}/*.erb 2>/dev/null || echo "WARN: TV page may not handle the remote / tv_home"
echo "-- TV buttons are phone-reachable (clause 1) --"; if grep -q "onclick=" public/games/${SLUG}.html 2>/dev/null && ! grep -q "TvRemoteChannel" public/games/${SLUG}.html 2>/dev/null; then echo "WARN: TV page has onclick buttons but no remote subscription — keyboard/mouse only"; else echo "ok"; fi
echo "-- start not TV-only (clause 3) --"; grep -n 'role == "tv"' app/channels/${SLUG//-/_}_channel.rb 2>/dev/null | grep -i start && echo "WARN: start_game gated to TV role — check for a host/phone start path"
echo "-- phone leave action (clauses 4-5) --";     grep -n "leave\|tv_home\|player_left\|abort" app/channels/${SLUG//-/_}_channel.rb 2>/dev/null || echo "WARN: channel may have no leave/abort/exit path"
echo "-- rematch keeps the party (clause 6) --"; grep -n "location.reload()" public/games/${SLUG}.html 2>/dev/null && echo "WARN: location.reload() on rematch mints a new code and orphans phones — reuse the code instead"
echo "-- sessions die (clause 7) --"; grep -n "SESSIONS\s*=" app/channels/${SLUG//-/_}_channel.rb 2>/dev/null && (grep -q "created_at\|sweep\|ttl\|TTL\|expire" app/channels/${SLUG//-/_}_channel.rb 2>/dev/null || echo "WARN: in-memory SESSIONS with no TTL/sweep — leaks one entry per match")
echo "-- resume contract (clause 9) --";        grep -n "ezaz_active_tv_game" public/games/${SLUG}.html 2>/dev/null || echo "WARN: resume contract not written"
echo "-- contract regression test (clauses 3-7) --"; ls test/channels/${SLUG//-/_}_channel_test.rb 2>/dev/null || echo "WARN: no channel test asserting leave-in-every-phase / abort-resets / rematch-keeps-code / session-sweep"
```

For ASC/time games also confirm: `grep -n "timeGames" public/index.html` then check your slug is in that map.

### Run it for real

- Dev server: `bin/rails server -p 5003` — **port 5003 is the real default** (`config/puma.rb`). CLAUDE.md's 3001 and the older 5001 note are both stale; use 5003 unless `PORT` is set.
- Run the test suite: `bin/rails test`.
- Open `http://localhost:5003/games/<slug...>` and verify: title screen loads, leaderboard fetches, a score POST appears in the inline board AND in the shelf High Scores modal, Escape pauses, Quit returns to store, banner link works, game keys don't scroll/trigger the browser.
- TV games: scan into the Zone from a phone (or `/tv/remote`), confirm the controller drives the game and the OK/FIRE button does the in-game action (not navigate away).

### The couch test (TV games — do this with your hands off the keyboard)

This is the test that would have caught the Snake Pit / Golden Goal failures. Open the TV page,
then **do not touch the TV's keyboard or mouse again.** Drive the entire session from a phone (a
second phone if it's multiplayer). Tick every box:

- [ ] **Join** by scanning the QR — not by typing the code.
- [ ] **Start** the game from a phone, with the TV keyboard/mouse untouched (Contract 1, 3).
- [ ] **Play** a full round driven only by phone input (Contract 1).
- [ ] **Exit** mid-game from the phone — your slot frees and you land on a home screen (Contract 4).
- [ ] **Quit** from the TV side mid-match, then confirm a phone can re-join the same code without a TV restart (Contract 5).
- [ ] **Press Home** on a phone and confirm the TV returns to `/tv` (Contract 2).
- [ ] **Rematch** and confirm already-joined phones land in the new lobby without rescanning (Contract 6).

If any box fails, the game is not done — fix it before ship. "Drove it in a browser tab" is not a
couch test; it is exactly how Golden Goal passed validation while still being unplayable.

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
