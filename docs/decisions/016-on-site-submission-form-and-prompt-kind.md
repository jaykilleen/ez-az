---
Date: 2026-07-31
Status: Accepted
Related: ADR 007
Triggers:
  - touching the Submission model, the submission API, or the admin review queue
  - adding a new way for families to reach the submission flow
  - a submitted game gets flagged, rejected, or needs a new dangerous-pattern rule
  - deciding whether an idea-only ("I don't have code yet") submission belongs
Topics: submissions, security, public-form
---

# ADR 016 -- On-Site Submission Form, Idea-Only Submissions, and a Hard Security Floor

## Context

ADR 007 built the submission pipeline (`Submission` model, `POST /api/submissions`,
the admin review queue, the sandboxed non-same-origin preview iframe, the
deliberate no-auto-publish rule) but only one door into it: an external AI
agent reading `/llms-submit.txt` and calling the API on a parent's behalf.
There was no page on `ez-az.net` itself a kid or parent could use directly.

Two gaps surfaced once that was pointed out:

1. **No path for an idea with no code yet.** A kid who wants to describe a
   game but hasn't (or can't yet) built it had nowhere to go. The only
   `Submission` shape was "finished HTML file," which doesn't fit "here's
   what I'm imagining."
2. **The dangerous-pattern checks that existed (`html_warnings`) were all
   advisory.** An external script tag, for instance, was a warning Jay had
   to notice and judge -- not a block. For a flow that now also accepts a
   direct file upload from anyone on the internet (not just a parent typing
   through their own AI assistant, who has some inherent friction/traceability),
   that felt like too thin a floor.

## Decision

### A public on-site form at `/submit`

`SubmitController#new` renders a single vanilla-JS page (no Turbo, no
Stimulus, consistent with the rest of EZ-AZ) with two tabs:

- **"I have an idea"** -- a text description only. No slug, no code.
- **"I built the game"** -- title/creators/contact fields plus either a
  direct `.html` file upload or (for API/AI-agent clients) an inline
  `game_html` JSON string. Both paths hit the same `POST /api/submissions`
  endpoint that already existed.

The homepage's stale "Got a game?" CTA (previously pointing at a GitHub-PR
flow described on `/help.html`, which predated ADR 007 and was never
updated) now points at `/submit`. `/llms.txt` and `/llms-submit.txt` are
updated to mention the on-site form and the new submission kind so an AI
agent following the runbook knows both doors exist.

### `Submission#kind`: `"html"` (default) vs `"prompt"`

One model, one admin queue, not a parallel inbox -- less duplication, and
Jay reviews everything in one place regardless of how finished it is.

- `kind: "prompt"` requires only `title`, `creators`, `contact_email`, and
  `idea_prompt` (free text, capped at 2000 chars). `slug`, `tagline`,
  `score_direction`, and `game_html` are not required -- they don't mean
  anything yet for an idea with no code.
- `kind: "html"` (or omitted, for backward compatibility with existing API
  callers) keeps ADR 007's original required-field set unchanged.
- The `submissions` table gained `kind` (string, default `"html"`) and
  `idea_prompt` (text, nullable); `game_html`, `slug`, and `tagline` were
  relaxed to nullable at the DB level to allow prompt-kind rows.
- The admin show page branches on `kind`: html-kind still gets the
  sandboxed iframe preview; prompt-kind shows the idea text instead (there
  is nothing to preview). `Admin::SubmissionsController#preview` 404s for
  prompt-kind rows rather than trying to render `nil` as HTML.
- Approving a prompt-kind submission does not tell Jay to "copy the HTML"
  (there isn't any) -- the flash message instead says to go build it first.

### A hard-rejection floor for dangerous patterns, in addition to ADR 007's existing backstops

`Submission::DANGEROUS_PATTERNS` is checked at save time, before a
submission ever reaches the review queue. Any match rejects the submission
outright (400, one clear reason, no partial credit for the rest):

- `document.cookie`
- `window.parent` / `window.top` / `top.location` (frame/clickjacking reach)
- an embedded `<iframe>`
- `eval()` or the `Function` constructor
- `document.write()`
- a `<script src="https://...">` pointing at an external URL
- a `fetch`/`XMLHttpRequest`/`WebSocket`/`EventSource` call to an absolute
  external URL

These are concrete, low-false-positive attack primitives -- none has a
legitimate reason to appear in a self-contained single-player canvas game.
The previous advisory-only warning for external `<script src>` is now
folded into this hard list rather than staying a soft warning.

**This is a floor, not a replacement for ADR 007's real defence.** A
regex can be dodged by someone determined enough. The actual backstops
remain: submissions are never auto-published (a human still copies
approved HTML into the repo by hand), and the admin preview iframe still
has no `allow-same-origin`. The pattern scan just means Jay's queue isn't
the first line of defence against the obvious stuff anymore.

### Upload handling reads file metadata before file contents

`Api::SubmissionsController#load_uploaded_html!` checks the uploaded
file's extension (`.html`/`.htm` only) and `.size` against
`Submission::MAX_HTML_BYTES` **before** calling `.read`. An attacker
handing over an oversized file doesn't get to make the server allocate
that much memory just to find out it's too big.

### Rate-limit bug fix

`check_rate_limit!` previously called `render` on the 429 path but did not
return from the calling `create` action, so a request over the 5/hour
limit still ran `Submission.new(...).save` and then hit a
`DoubleRenderError` trying to render twice -- meaning the rate limit
never actually blocked a save, it just turned the response into a
confusing 500 instead of the intended 429. `create` now returns early
based on `check_rate_limit!`'s boolean result.

## Consequences

- A parent or kid with no AI assistant and no GitHub account can now reach
  the submission flow directly from the store's homepage.
- An idea can be submitted before any code exists, and Jay can build it (or
  have Claude build it) later via the same review queue -- this is the
  natural on-ramp for future `/build-game` sessions.
- The dangerous-pattern list is the new seed for "what gets an upload
  rejected automatically" -- if a legitimate game genuinely needs one of
  these (unlikely), the runbook tells them to email Jay first rather than
  submit and hope.
- Full test coverage was added for all of the above (model validation
  matrix, per-pattern rejection, upload extension/size checks, rate limit
  behaviour including the fix, admin preview 404 for prompt-kind) --
  ADR 007 shipped without any submission tests; this ADR's changes do not
  repeat that gap.
- Remix submissions (still a documented future expansion in ADR 007) would
  most naturally become a third `kind` value when they land.
