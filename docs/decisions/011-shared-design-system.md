# ADR 011 — Shared Design System (ez-az-shell.css)

**Status:** Accepted
**Date:** 12 June 2026

---

## Context

Three of the early party games (Snake Pit Royale, Golden Goal, Dino Jump) each carried their own
copy of the same visual primitives: store banner, exit button, name input, join button, lobby
screen, game-over screen, TV QR box, slot cards, leaderboard, and score cards. The copies had
drifted from each other and from the reference games (Family Trivia, Spotlight, Treasure Hunt)
in ways that weakened the brand:

1. Store banner links used each game's own accent colour instead of the shared brand gradient.
2. Game-over "back to store" buttons were near-invisible (`rgba(255,255,255,0.2)` on dark
   backgrounds).
3. QR join boxes were tinted with the game's own colour instead of the brand-level teal.
4. Primary buttons on two games used a gray gradient, giving no visual signal.
5. Dino Jump's phone join page had no EXIT button, violating Phone Contract clause 4.

A design audit of the reference games extracted a consistent set of tokens and component
classes. The goal of this ADR is to capture that extraction and the decisions made during it.

---

## Decisions

### 1. Single shared stylesheet: `public/ez-az-shell.css`

All design tokens and shell components live in one file. Games include it with:

```html
<link rel="stylesheet" href="/ez-az-shell.css">
```

This file is served as a static asset by Propshaft, so no build step is required. It covers
both TV game HTML files (`public/games/`) and phone join ERB views (`app/views/*/join.html.erb`).

### 2. All shared classes use the `.ezaz-` prefix

This avoids collisions with game-specific styles. Game-level CSS stays in the game file and
uses short names without prefix. The shell CSS never sets canvas, gameplay, or controller
layout styles.

### 3. Design tokens as CSS custom properties on `:root`

Brand colours (`--ez-teal`, `--ez-yellow`, `--ez-pink`, `--ez-red`, `--ez-gold`), surface
colours (`--ez-bg`, `--ez-surface`, `--ez-border`), and the 4-slot character palette
(`--ez-slot-0` through `--ez-slot-3`) are declared as CSS custom properties so games can
reference them in their own bespoke styles.

### 4. Store banner is always the brand gradient

`.ezaz-store-banner a` uses `linear-gradient(90deg, #ff6ec7, #00ffc8, #ffe44d)` regardless of
which game is displaying. This is a brand-level chrome, not a game-level accent.

### 5. QR join box is always teal-bordered

The scan-to-join action is a brand-level interaction (you are joining the EZ-AZ store, not just
the game). `.ezaz-qr-box` always uses `rgba(0,255,200,0.3)` border and
`rgba(0,255,200,0.06)` background.

### 6. Primary button supports per-game colour overrides via CSS custom properties

`.ezaz-btn-primary` reads `--ez-btn-bg` and `--ez-btn-fg` at the element level. Game join
pages set these on the element itself:

```html
<button class="ezaz-btn-primary" style="--ez-btn-bg:#ffd23b;--ez-btn-fg:#14110c;">KICK OFF</button>
```

This means one class definition handles all game accent colours without duplication.

### 7. TV slot cards use `.filled` class + `--slot-colour` CSS custom property

When a phone joins, JS adds `.filled` to the `.ezaz-slot-card` and sets
`--slot-colour` to the character's colour. The shared CSS handles the visual transition. Games
with their own character colour palettes (e.g. Dino Jump's Slate/Pixel/Fern/Echo) still use
the shared card structure while supplying their own colours through `--slot-colour`.

### 8. Leaderboard rows and score cards rendered via JS must use `ezaz-*` class names

TV games that build their leaderboard or score grids with `innerHTML` strings must use the
shared class names (`ezaz-lb-row`, `ezaz-score-card`, etc.) in those strings. Bespoke
equivalents (`lb-row`, `score-card`, etc.) in game-local CSS are removed once the game is
migrated.

### 9. Dino Jump EXIT button violation fixed alongside the design pass

Dino Jump's phone join page was missing the EXIT button required by Phone Contract clause 4.
Since the design pass touched that file anyway, the violation was fixed in the same commit. Dino
Jump uses a custom cable implementation (`AzCable`) rather than `ArcadeCable`, so `attachExit`
could not be reused; the exit handler was wired manually with the same 150 ms delay pattern.

### 10. Reference games are not migrated in this pass

Family Trivia, Spotlight, and Treasure Hunt served as the source of truth for the design
tokens. Their existing styles closely match the shared system. Migrating them to use `ez-az-shell.css`
would be purely cosmetic and requires careful regression testing of their join flows and TV views.
That work is deferred to a future pass.

---

## Consequences

- Three games (Snake Pit Royale, Golden Goal, Dino Jump) now share one source of truth for
  store banner, exit button, join/lobby/gameover chrome, and TV lobby primitives.
- New games must include `ez-az-shell.css` and follow the component conventions in
  `docs/design-system.md`.
- Any change to a shared primitive (e.g. updating the leaderboard row hover colour) is made
  once in `ez-az-shell.css` and takes effect across all migrated games immediately.
- Games using `ArcadeCable` (`ArcadeCable.attachExit`, `ArcadeCable.hostStart`) satisfy
  Phone Contract clauses 3 and 4 automatically. Games using a custom cable must wire these
  manually; `docs/design-system.md` documents the pattern.
