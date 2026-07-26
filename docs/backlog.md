# EZ-AZ Backlog

Where work lives before it starts. Three sections, roughly prioritised:

- **Next** — agreed, ready to pick up. Top item is the default "what's next".
- **Soon** — wanted, not yet scheduled. Promote into Next when Next empties.
- **Ideas** — worth keeping, not yet argued for. May never happen.

Items carry stable IDs (`BL-NNN`) so they can be referenced in commits, ADRs
and conversation. Numbers are never reused.

Two other queues exist and are **not** duplicated here:

- **GitHub issues** — bugs and the Learning Centre content backlog
  (`gh issue list`). 16 open as of 2026-07-26, mostly learning-path content.
- **In-app bug reports** — submitted by players, triaged via the `ez-az` MCP
  tools (`list_pending_bugs`, `approve_bug`, `dismiss_bug`, `squash_bug`).

---

## Next

### BL-001 — Decide: one visual register or two?
**Needs Jay, not code.** EZ-AZ has two deliberate looks for the world around
games: the arcade primitives in `public/ez-az-shell.css` (Press Start 2P,
fixed banner, slot cards) used by Dino Jump / Snake Pit Royale / Golden Goal,
and a softer broadcast style (fluid vw/vh, system font, no `/api/scores`
leaderboard) used by Family Trivia / Spotlight / Treasure Hunt.

PR 57 unified only the shared colour tokens across the broadcast games,
pixel-identical and safe. It deliberately did not force arcade components onto
them — that would be a redesign of the gold-standard games, not a migration
(ADR 011 flagged it as deferred-cosmetic).

Decision needed: unify into one look, or keep two intentional registers? If
unify, it needs its own card with before/after screenshots and a real design
pass, not a CSS swap. Blocks any further shell rollout.

Also parked on this: the unified Zone (`tv_remote/show.html.erb`) and the TV
room views are not on the shell and have no safe one-line adoption path.

**Comparison captured 2026-07-26.** All six lobbies screenshotted at
1920x1080 and sent to Jay as a side-by-side. What it showed:

| | Arcade | Broadcast |
|---|---|---|
| Screen used | ~middle half, big dead bands | Full frame, two columns |
| Brand mark | Tiny mono `EZ-AZ`, top centre | Large gradient wordmark, top left |
| Header | None | Title, sound, Exit, room-code chip |
| Status | None | Bottom bar: waiting + connection |
| Type | Press Start 2P throughout, small | Inter, real heading hierarchy |

The screenshots surfaced a third option worth considering alongside
"unify" and "keep both":

- **A. Keep two registers.** Nothing to build. Defensible if they're two
  product lines, but the split currently follows build order rather than
  intent -- Snake Pit and Trivia are both "four phones round a TV".
- **B. Unify onto the broadcast look.** One coherent store, but costs the
  pixel-arcade character that genuinely suits those three games.
- **C. Shared skeleton, per-game skin.** Adopt the broadcast *layout*
  everywhere (full-frame two-column, header with Exit and room code, bottom
  status bar) while each game keeps its own typeface and palette. Fixes the
  measurable problems without discarding the arcade character, and is close
  to what `ez-az-shell.css` was already reaching for -- ADR 011 extracted
  shared *components*, where the real gap is shared *layout*.

Open question, not yet a finding: the arcade lobbies show no on-screen Exit,
only "ESC pauses". That's fine with a keyboard but may leave no quit path on
a Google TV. Worth checking how these actually get launched before treating
it as a defect.

Related: ADR 011, ADR 010.

### BL-002 — Descent Party Mode (4-player TV split-screen)
Up to 4 players each get a quadrant of the TV, each running their own maze
simultaneously. Descent already has 4 characters (Slate, Pixel, Fern, Echo) —
one per player.

Design questions to settle first:
- Same maze for all (fair race) or independent mazes (chaos)?
- Independent floor progression or everyone advances together?
- Win condition: most floors when someone hits the bottom, or a time limit?

Build notes:
- Descent uses ~30 globals; needs a `GameInstance` class refactor so 4 can run
  independently. This is the bulk of the work.
- One canvas, 4 clipped regions (960×540 each on 1920×1080).
- `TvRemoteChannel` needs a `join_descent` action — in-memory slot assignment
  per token, no DB Room required.
- Navigate broadcasts must carry the sending slot so the TV knows which
  quadrant moved.
- Phone Zone needs a Descent screen: D-pad plus a sprint button (replaces the
  Shift key).
- New file `public/games/descent-party.html` — don't hack the single-player
  game.

Related: ADR 001, ADR 010 (Phone Contract).

---

## Soon

### BL-003 — Store unlock window after solving Cipher
Solving Cipher opens the store for 15 minutes. Conceived as part of the Cipher
game, deferred because it's a store-level concern.

At the `public/index.html` level: lock icon on the shelf when there's no recent
solve, clicking the lock goes to Cipher, a solve writes a localStorage
timestamp, store reads as open for 15 minutes. Consider showing the lock
visual only rather than actually blocking play.

Note the overlap with `StoreHours` and the `store_open_until` counter — decide
whether this is the same mechanism or a separate cosmetic layer before
building.

### BL-004 — Gamer show page
`GET /gamers/:username` — a public profile with a player's best scores and the
games they submitted. Gives kids somewhere on EZ-AZ that is theirs.

- Username is already the handle; no new model field needed for identity.
- Needs `creator_username` on `Game` to attribute authorship.
- Best scores: top `Score` per game for that player.
- Link from the login button once logged in ("Hi CHARLIE →").

Build once at least one game has a known author to test against. Model
checklist applies to new columns. Related: ADR 002.

### BL-015 — Merge player name variants on leaderboards
Production boards carry the same kid under more than one name: `COOPER` and
`COOPER KILLE`, `LACHIE` and `PRO LACHIE`. Since ADR 014 ranks players rather
than attempts, each variant now takes its own slot.

Merging automatically is not safe -- `GUY` and `CHEESE` might be anyone, and
two kids could legitimately pick similar names. Options: let a signed-in
player claim past scores posted under a chosen name, or give Jay a small admin
merge action. Signing in already avoids the problem going forward, because the
server overrides the posted name with the player's username.

Related: ADR 014, BL-004.

### BL-005 — Trivia theme picker
Pick a theme before the game starts (Animals, Science, Australia, Sports)
instead of one mixed pool. `TriviaChannel#build_session` filters QUESTIONS by
category before shuffling; the lobby and the phone Zone both need to show the
options.

### BL-006 — Watch: favourites, completions, Az level-up
Mark videos complete and favourite them on `/watch`. Az awards level titles per
category — "You're now a Level 2 Physicist, mate."

- `video_completions`: player_id, track_slug, video_idx, completed_at
- favourites (own table or a flag on completions)
- Level thresholds per category (2 videos = L1, 5 = L2, all = L3)
- Az delivers the level-up in her own voice
- Badges on `/watch`, and on the gamer page (BL-004) if that exists

Do this once `/watch` is battle-tested, not before.

### BL-007 — Unify the store front and the TV view, drop `/tv`
Make `public/index.html` serve as the TV display via responsive CSS, and retire
the separate `/tv` route and `TvController`. One URL, one codebase.

- `/tv` currently creates the Room and generates the pairing QR — that moves to
  the store front's `/api/tv_session`.
- Needs a "lean back" layout: bigger text, higher contrast, no hover states,
  boxes sized for 10-foot viewing.
- `tv-engine.js` reads `tvRemoteToken` from sessionStorage and doesn't care
  which URL it runs on, so the engine needs no change.
- Keep `/tv` as a redirect for bookmarked TVs.

Depends on the phone-companion work landing on `/` first.

---

## Ideas

### BL-008 — EZ-AZ PWA with a built-in QR scanner
Install EZ-AZ to the home screen, tap "Connect to TV", scan the TV's QR with
the in-app scanner. Phone becomes the controller without ever touching a
browser — no camera app, no Safari, no cached page.

`BarcodeDetector` works natively in Chrome/Android and in iOS Safari 17+ via
Shape Detection; `jsQR` is the fallback. Service worker: network-first for Zone
HTML so cache-busting still works, cache-first for game assets. Solves the
token-freshness problem outright, since the user always scans live.

### BL-009 — Phone Zone as an installable PWA
The Zone page as a home-screen app so regulars never rescan. Manifest ("EZ-AZ
Remote", Az icon, standalone, `#0a0a12`), service worker, last-used token in
localStorage for auto-reconnect.

Tension: the QR token changes per TV session, so a hardcoded home-screen URL
goes stale. Pairs with the shipped `device_token` reconnect work — reconnect
from storage rather than prompting. Overlaps heavily with BL-008; likely one
piece of work, not two.

### BL-010 — NAPLAN curriculum packs for Trivia
Question packs by school year (3, 5, 7, 9) with Numeracy, Reading and Language
Conventions categories, playable as a whole family. Needs the theme picker
(BL-005) to select them. New files under `db/questions/`.

### BL-011 — Remix submissions
Let families remix existing games rather than only submitting new ones:
Spotlight question packs, Treasure Hunt card art, Trivia subject packs. Much
lower bar than building from scratch.

When designing the submission API, leave room for a `submission_kind` field
(`new_game` vs `remix`) — a remix needs a `parent_game_slug` plus variant data,
not a full HTML file. Related: ADR 007.

### BL-012 — Recycle inactive player logins
Free usernames after 90 days of no scores, sessions or activity — except for
anyone credited as a game creator, who keeps their handle permanently because
their work is on the shelf.

Clear `username`, `device_token`, `pin_digest` (or soft-delete). Scheduled rake
task. Build a dry-run mode first so the recycle list can be reviewed before
anything is cleared. Depends on BL-004 for `creator_username`.

### BL-013 — EZ-AZ MCP server for store ops
`open_store(hours)`, `close_store()`, `store_status()` as first-class tools
instead of remembered `kamal app exec` one-liners.

Partly overtaken: an `ez-az` MCP server now exists for bug triage, so this is
about adding store-ops tools to it rather than building one. Still only worth
it at 3+ ops actions — right now the store override is a fine one-liner.

### BL-014 — Safe Browsing check on the QR scanner
Server-side Google Safe Browsing check in the `/scan` URL confirm flow, to
catch phishing and malware before a kid opens the link. The scanner already
shows a URL preview and an HTTPS warning.

`GET /api/safe_url?url=...`, key stays server-side, ~200ms on the confirm step
is acceptable. Jay asked for this as a follow-up on 2026-04-26.

---

## Design intent worth preserving

Not backlog items — constraints that should shape whatever gets built.

- **Treasure Hunt's deck is dual-purpose.** 52 cards, 4 colours × 1–13, mapping
  onto a standard deck (Red↔Hearts, Blue↔Spades, Green↔Clubs,
  Yellow↔Diamonds). Challenges use single-suit rules, never red/black pairings,
  so they translate to real cards on a car trip. "Closest to 7" is the midpoint
  of 1–13. Preserve this mapping in any future card game.
- **Games stay bespoke, the shell is shared.** The consistent surfaces are the
  shelf, game selection, start overlay, pause/quit, game over, the leaderboard
  modal and the QR-join lobby. The game itself can look and play however it
  wants. See ADR 011 and `docs/design-system.md`.
