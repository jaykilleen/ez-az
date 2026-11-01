---
description: Deploy EZ-AZ to production. Runs tests, then dispatches push → GitHub Actions → polls /api/version until live.
---

# /ez-az-deploy — EZ-AZ production deploy

Deploys to ez-az.net via the standard push-to-main pattern.

## Pre-deploy checks (do these first, every time)

1. `bin/rails test` — all 500+ tests green. Do not push a red suite.
2. If this deploy includes a new game, run `/ez-az-audit-game <slug>` and clear every MISSING/WARN before pushing.
3. `git status --short` — nothing load-bearing uncommitted. Audio files, worktree-focus.md and other local artefacts are fine to ignore.

## Then follow the global `/deploy` skill

This project uses the standard pattern:

- **Push target:** `git push origin <branch>:main`
- **CI:** `.github/workflows/deploy.yml` — runs `bin/rails test` AND `npx playwright test` before deploying. Both must pass.
- **Production host:** `ez-az.net`
- **Version endpoint:** `https://ez-az.net/api/version` (returns `{"version":"...","env":"..."}`)
- **Version file:** `lib/ez_az/version.rb` — bump `STRING` if the local value already matches live, format `YYYYMMDD.N`

Poll `/api/version` until the new version string is live. GitHub Actions success alone is not confirmation — the container can build green and boot wrong.

## Invoke

Run `/deploy` — the global skill handles everything from here per the steps above.

## After the version is confirmed live — What's New

Once `/api/version` confirms the new version is live, prompt Jay to add a What's New announcement.
What's New is database-driven (`Announcement` model). New entries go in via the Rails console on production:

```bash
# SSH into production and run:
kamal console   # or: kamal app exec --reuse "bin/rails console"
```

```ruby
Announcement.create!(
  emoji: '🦣',         # pick something that fits the release
  title: 'Mammoth Games',
  body: 'Run, hide, and survive. Someone is IT — but nobody knows who. Play on your phone with up to 4 players.'
)
```

Ask Jay: "Do you want to add a What's New announcement for this release? I can draft the emoji, title, and body — just let me know what to highlight."

If Jay says yes, draft the announcement based on what shipped, confirm it, then give him the console command with the content filled in. Do not run it yourself — it goes to the production database.
