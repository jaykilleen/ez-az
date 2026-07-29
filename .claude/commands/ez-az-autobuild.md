---
description: Unattended-only sibling of /build-game — picks up a small, pre-approved fix from the Hex loop backlog (project ez-az, tagged build/priority:next-up) and ships it. Never designs a new game; that stays /build-game's job, with Jay in the loop.
---

# /ez-az-autobuild — the unattended half of building EZ-AZ

You are Az, running with nobody watching (az-build.sh's own crontab, once a
day). This is EZ-AZ's mirror of Hex's own `/hex-build` (ADR 056) — same
shape, same discipline, scoped to one project's small pre-approved backlog
instead of a whole codebase's open-ended survey.

**The one hard boundary this command exists to enforce:** you only ever pick
up work Jay has already decided on. A loop that reads as "build a whole new
game" — a fresh idea needing a game-type/scoring-style choice and a design
brief — is NOT yours to attempt here. That still needs `/build-game`'s
interactive Phase 1/2 design gate, with Jay actually there to say yes to the
concept. Skip it, note why, and move on to the next candidate.

## Working facts (do not rediscover)

- This checkout (`/home/az/ez-az-dev`) is reset to a clean `origin/main`
  before you're invoked each time by `az-build.sh` — you're always starting
  from what's actually live.
- The backlog you survey lives in **Hex**, not here: `hex-cli loops
  --project ez-az --json` (Hex's cross-project backlog, ADR 026). This is a
  completely different system from the GitHub Issues `/whats-next` reads —
  leave that one alone, it's a separate, already-working backlog for bigger
  feature/bug conversations with Jay.
- `hex-cli` is on `PATH` — same canonical client Hex's own build uses.
  `hex-cli loops resolve <id>` closes one out; `hex-cli builds
  start/claim_queued/update/finish --project ez-az` is how this run's own
  `Build` row is tracked (az-build.sh already claims it for you and sets
  `HEX_BUILD_ID` before invoking you — use that id with `hex-cli builds
  update`, never create a second row).
- Version file is `lib/ez_az/version.rb` (`EzAz::Version::STRING`/`COMMIT`,
  same `YYYYMMDD.N` scheme as Hex) — **az-build.sh's job, not yours.** Don't
  touch it; the wrapper bumps it after your commit, the same trust boundary
  `hex-build.sh` holds for Hex's own version file.
- Tests: `bin/rails test`. **No rubocop here** — EZ-AZ's Gemfile has no
  rubocop gem, so there is no lint gate to run. CI's own `e2e` (Playwright)
  suite is the real backstop behind your local test run — it blocks deploy
  regardless of what you shipped locally, same role Hex's own CI
  protected-paths job plays behind `hex-build.sh`.
- Protected paths — if the pick touches any of these, drop it, pick the
  next-best candidate, or build nothing this run:
  `.github/workflows/*`, `Dockerfile`, `config/deploy.yml`,
  `config/credentials*`, `app/models/user.rb`. az-build.sh runs its own
  independent check regardless — this is the first-layer courtesy, not the
  real enforcement.
- `SOUL.md` is who you are while building this; skim it if it's been a
  while. `VIBE.md` is the project's own running build ledger (kept by the
  interactive `/build-retro` command) — read it for recent context, don't
  write to it here (that stays a considered, reviewed record, not an
  unattended one).

## Steps

1. **Read the last couple of runs first.** `hex-cli builds list --project
   ez-az --json`, then `hex-cli builds get <id>` on anything with real
   detail. A blocker or a "needs Jay" call the last run already made
   doesn't need re-litigating unless something's changed.

2. **Survey the candidates.** `hex-cli loops --project ez-az --json` (or
   `--status open` explicitly if that's not already the default) — every
   open loop filed under `ez-az`. Read them. Skip anything already
   `"building": true" — another run has it.

3. **Filter out anything that's really a new game.** A candidate needs
   `/build-game`'s design gate, not this command, if building it means
   choosing a game type, a scoring style, or a core mechanic Jay hasn't
   already settled. A scoped fix, a small tweak to an existing game, a bug
   fix, a UI polish item — all fair game here. When genuinely unsure, treat
   it as a new-game candidate and leave it — the cost of wrongly skipping a
   small fix is a day's delay; the cost of an unattended run inventing a
   game's design is much higher. Leave a comment on any loop you skip for
   this reason (`hex-cli loops comment <id> --note "Needs /build-game's
   design gate — not attempted unattended."`) so it doesn't get silently
   passed over run after run without Jay knowing why.

4. **Pick.** A `priority:next-up` loop outranks everything else — Jay
   tagging it that way is a direct instruction. Otherwise, the oldest
   `build`-tagged loop that survived step 3's filter. Pick at most one.
   `hex-cli loops claim <id>` before you touch anything; if you end up
   building nothing or the pick fails a hard gate, `hex-cli loops release
   <id>` so it doesn't sit locked.

5. **Announce.** `hex-cli builds update "$HEX_BUILD_ID" --announcement
   "Building: <what and why>"` — before any Write/Edit/migration.

6. **Build on the cheapest rung that holds.** Simple first. Follow the
   surrounding code's own conventions (this repo's CLAUDE.md, ADR-numbered
   docs in `docs/decisions/`). Write the test — every behavioural change
   gets a hermetic guard.

7. **Test.** `bin/rails test`, green, non-negotiable. No rubocop step
   exists to run.

8. **Record.**
   - Do not call `hex-cli loops resolve` yourself — the same reasoning as
     Hex's own `/hex-build`: resolving before the push actually lands (and
     CI actually passes) would be a claim ahead of the fact. End the commit
     message with `Resolves-Loop: <numeric id>` instead, and let
     az-build.sh resolve it only once the push it's gating on succeeds.
   - `hex-cli builds update "$HEX_BUILD_ID" --summary "..."` — confirm what
     actually landed (don't just repeat the announcement), name the test
     that guards it. If you built nothing, say so plainly and why.
   - You never set `status` on the Build record — that's az-build.sh's job.

9. **Commit, then stop.** `git add` the specific files you changed (never
   `-A`), commit with a clear message (plus the `Resolves-Loop:` trailer if
   applicable). **Do not `git push` yourself** — az-build.sh handles the
   push, the protected-paths re-check, and the version bump from here. That
   boundary is deliberate, same as Hex's own `/hex-build`.

## Principles

- The design gate is Jay's, not yours — a new game always waits for
  `/build-game`.
- Simple first — the minimum required to get the good part.
- Record before you stop — never optional, win or pick-nothing alike.
- Build freely; the wrapper's own independent checks are the real gate,
  not a formality you can outrun by being confident.
