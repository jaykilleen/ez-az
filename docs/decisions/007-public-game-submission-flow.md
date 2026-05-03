# ADR 007 — Public Game Submission Flow for Non-Developer Families

**Status:** Accepted
**Date:** May 2026

---

## Context

The original EZ-AZ contribution path was GitHub: fork the repo, copy the kid's game into `public/games/`, register it in the `Game` model and `Score::GAME_SORT`, open a PR. This works for developers but is a hard wall for the families EZ-AZ exists for. Most parents do not have a GitHub account; even those who do don't want to spelunk a Rails repo to deploy their 8-year-old's HTML game.

The friction was visible in real-world feedback: families enthusiastic about kids building games with AI, but no path from "kid finished the game" to "game on the store" without a developer in the loop.

We need a contribution flow that:

1. Requires no GitHub knowledge or developer tooling from the parent.
2. Lets the parent's AI assistant (Claude, ChatGPT, etc.) do the technical work on their behalf.
3. Keeps Jay in the review loop — published games still need approval.
4. Doesn't compromise security (submitted HTML runs in users' browsers; can't be allowed to phish or host malware).

---

## Decision

### Two-tier shipped path

**Tier 1 — Documentation that AI agents can read and follow:**

- `/llms.txt` — site overview at the project root, pointing to deeper docs. Follows the [llmstxt.org](https://llmstxt.org/) convention.
- `/llms-submit.txt` — full submission runbook: game-file format, required HTML patterns (store banner, leaderboard wiring, escape pause), slug rules, required fields, API endpoint, examples, tone guidance.

The runbook is written for an AI to follow autonomously. It explicitly tells the AI to **fix submission issues themselves** rather than bouncing the parent back with a list of complaints — the kid did the creative work, the polish is the AI's job.

**Tier 2 — Server-side submission flow:**

- `POST /api/submissions` (public, IP rate-limited 5/hour, 1 MB HTML cap). Accepts `{slug, title, creators, tagline, score_direction, is_chill, game_html, contact_email, notes}`. Validates slug uniqueness against existing games + reserved slugs.
- `Submission` model with `status` (pending / approved / rejected) and `html_warnings` advisory checks (missing store banner, no `/api/scores` call, no Escape handler, external script tags).
- Admin queue at `/admin/submissions`, gated by HTTP basic auth (`ADMIN_PASSWORD` env). Index lists pending + recently reviewed; detail page renders the submitted HTML in a `sandbox="allow-scripts"` iframe (no same-origin so submitted code can't pivot the admin UI).
- SubmissionMailer through SendGrid SMTP (per cross-project standard) emails Jay on each new submission. Falls through silently if `SENDGRID_API_KEY` not set — submissions still land in the queue.

### Approve flow stays manual (for now)

When Jay clicks Approve, the submission is **marked approved but not auto-published**. The flash notice tells him to copy the HTML into `public/games/<slug>.html`, register in the `Game` model + `Score::GAME_SORT`, then deploy via the existing release flow.

This is intentional. Auto-publishing was Tier 3 in the original design conversation and was deferred until we've seen what real submissions look like. Concerns:

- Bad actors could submit malicious HTML; eyeball review with iframe preview is a strong gate.
- Slug squatting / reserved-slug abuse needs human judgement.
- Game-shelf curation (taglines, sort order) benefits from manual touch.

Tier 3 (one-click auto-publish) is a future ADR.

### Validation philosophy: lenient inbound, advisory warnings

Hard validation rejects only the things that genuinely block processing:

- Slug format / collision
- Required field missing
- Email format
- HTML > 1 MB
- Rate limit

Everything else (missing store banner, no leaderboard wiring, no Escape handler, external script tags) is shown as an **advisory warning** on the admin detail page. Lets innovative submissions through; Jay decides.

### Submission iframe sandbox

The preview iframe uses `sandbox="allow-scripts"` deliberately **without** `allow-same-origin`. This means:

- The game runs and renders.
- The game cannot fetch `/api/scores` during preview (the leaderboard wiring goes untested in the queue — that's OK, it's reviewable visually).
- The game cannot read cookies or hit other endpoints on the EZ-AZ origin.

This trades a small loss of preview fidelity for strong containment of unreviewed submissions.

---

## Operator notes

- `ADMIN_PASSWORD` and `SENDGRID_API_KEY` should be set as GitHub Actions secrets (referenced in `.github/workflows/deploy.yml`) and propagated via Kamal to production. The default admin password (`ezaz-dev-only`) is intentionally weak as a deploy-time reminder.
- The `Submission` table is SQLite (same as everything else). Submission HTML lives in the DB, not on disk — keeps backups simple and avoids file-permission concerns.
- Emails come `from: jay@retailtasker.com.au` and `reply_to: <submitter contact_email>` so Jay can reply directly from his inbox without leaving Mail.app.

---

## Consequences

- A parent with no developer skills can now publish their kid's game by saying to their AI assistant: *"Submit my kid's game to ez-az.net, instructions at https://ez-az.net/llms-submit.txt"*.
- The submission spec (in `/llms-submit.txt`) becomes the canonical definition of "what makes a valid EZ-AZ game". Future game-template work should align with it.
- The admin queue is the only existing **gated admin surface** in EZ-AZ. Future admin features (e.g. moderation, banning, runtime config) should reuse the same `Admin::` namespace and `http_basic_authenticate_with` pattern, OR get a proper auth layer at that point.
- The `Submission` model's `html_warnings` checks are the seed for an eventual lint-as-you-submit feature. If submissions consistently miss the same patterns, that signal goes back into refining the runbook.
- Auto-publish (Tier 3) is deliberately deferred until we've seen real submissions. When it ships, it should reuse the approval transition; the file write + Game model update + commit + deploy can all be triggered from the same admin button.
- Remix submissions (a parent submits a Spotlight question pack or a Treasure Hunt theme variant rather than a from-scratch game) are a future expansion (see `~/.claude/projects/-home-jay-projects-ez-az/memory/backlog_remix_submissions.md`). The `Submission` model already has room for a `kind` field or similar when this lands.
