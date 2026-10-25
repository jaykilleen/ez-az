---
Date: 2026-10-25
Status: Accepted
Triggers:
  - deploy workflow fails before any test or build step runs
  - ruby/setup-ruby or Playwright browser install errors in CI
  - changing the Ruby version, the CI runner image, or Playwright
Topics: deployment, ci, ruby, testing
---

# ADR 020 -- Ruby Is Pinned to 3.4.12, and the e2e Job Is Pinned to ubuntu-24.04

## Context

On 2026-10-25 the release for Balloon Pop (the Deploy workflow, `.github/workflows/deploy.yml`) failed twice
in a row, before a single test ran, for reasons that had nothing to do with the
game. Both had the same root cause: `ubuntu-latest` now resolves to
**Ubuntu 26.04**, and the workflow had never been run on it.

1. **`ruby/setup-ruby` could not find Ruby 3.4.2.** Newer runner images only
   build the latest patch release of each Ruby series. The error named
   3.4.12 as the available 3.4.x.
2. **Playwright 1.58.2 could not install Chromium.** The `e2e` job failed at
   `npx playwright install --with-deps chromium` with "Playwright does not
   support chromium on ubuntu26.04-x64".

Because `deploy` has `needs: [test, e2e]` (see CLAUDE.md), either failure
blocked production. Production stayed on 20261021.2 throughout; nothing was
half-deployed.

## Decision

1. **Ruby moves from 3.4.2 to 3.4.12 everywhere at once:** `.ruby-version`, the
   `Dockerfile` (`ARG RUBY_VERSION`), and the three `ruby-version:` entries in
   `deploy.yml`. They must stay identical so CI tests the same Ruby that
   production runs. Pinning an exact patch (rather than `3.4`) keeps that
   guarantee, at the cost of a manual bump when the runner image moves again.
2. **Only the `e2e` job is pinned to `runs-on: ubuntu-24.04`.** `test` and
   `deploy` stay on `ubuntu-latest`; both passed on 26.04 once Ruby was fixed.
   The pin carries a comment in the workflow saying why and when to remove it.
3. **Playwright is not upgraded as part of this fix.** The project is on 1.58;
   1.64 was current. Upgrading changes the browser and could change how the
   specs behave, which is a separate piece of work from unblocking a release.

## Why

- Changing Ruby alone fixed the first failure, but a runner pin alone would
  have left CI on Ruby 3.4.2 while ubuntu-latest kept moving. Bumping Ruby
  is the durable fix; the e2e pin is the smallest change that gets past the
  second failure.
- The smallest working change was preferred over a broad "pin everything to
  24.04": `test` and `deploy` have no known problem on 26.04, so pinning them
  would be hiding a runner that works.

## Consequences

- If `ruby/setup-ruby` fails again with "Unavailable version", the runner
  image has moved on. Bump the Ruby patch in all four places above together.
- When Playwright is upgraded to a release that supports ubuntu-26.04, remove
  the `ubuntu-24.04` pin on the `e2e` job and return it to `ubuntu-latest`.
  `ubuntu-24.04` will eventually leave GitHub's hosted runners, so this pin has a
  shelf life.
- Local development runs whatever Ruby `.ruby-version` names. Anyone on 3.4.2
  should install 3.4.12 to match CI and production.
- The first run on 3.4.12 passed the full Rails suite, so no gem incompatibility
  is known.

## Related

- ADR 019 -- Kamal Is the Sole Deployment System (the workflow this protects)
