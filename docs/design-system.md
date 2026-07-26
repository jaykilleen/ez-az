# EZ-AZ Design System

The shell is the part of EZ-AZ that is **not** the game: the store banner, how a
game is reached, the title screen, the leaderboard, pausing, quitting and game
over. It is shared so that when a new game drops we only write the game.

Two files own it:

| File | Owns |
|---|---|
| `public/ez-az-shell.css` | How the wrapper **looks** — tokens and `.ezaz-` components |
| `public/arcade-shell.js` | How the wrapper **behaves** — `ArcadeShell` runtime |

Plus two siblings for multiplayer, which are a separate concern:
`public/arcade-cable.js` (ActionCable subscribe / exit / host-start) and
`public/arcade-tv.js` (session codes, phone-to-TV input).

**Start a new game from `docs/game-template.html`.** Copy it to
`public/games/<slug>.html` and fill in the three marked sections. Everything
else is already wired.

Game-specific layout, canvas, and gameplay UI belongs in each game file. This
system only touches the surfaces around the game. If a wrapper piece is
missing, add it to the shell rather than to your game.

---

## The `ArcadeShell` runtime

Include after the stylesheet:

```html
<link rel="stylesheet" href="/ez-az-shell.css">
<script src="/arcade-shell.js"></script>
```

Every method is independent — take only what you need.

| Call | Does |
|---|---|
| `ArcadeShell.banner()` | Injects the store banner. Idempotent. |
| `ArcadeShell.leaderboard(target, game, opts)` | Fetch **and** render. Resolves with the data. |
| `ArcadeShell.fetchScores(game)` | Fetch only. Falls back to `localStorage` when offline. |
| `ArcadeShell.renderLeaderboard(target, data, opts)` | Render data you already hold. |
| `ArcadeShell.submit(game, name, value)` | POST a score, resolves with the refreshed board. |
| `ArcadeShell.qualifies(value, data)` | Would this score make the top ten? |
| `ArcadeShell.format(value, sort)` | `"1480 pts"` or `"00:45.390"`. |
| `ArcadeShell.pause(opts)` | Wires Escape to the standard pause overlay. |

`opts` for the leaderboard renderers: `highlight` (name to mark as the player's
row) and `title` (heading, default `HIGH SCORES`).

`opts` for `pause`: `onPause` / `onResume` to stop and restart your loop, and
`enabled` — return `false` to ignore Escape, e.g. on the title screen.

```javascript
ArcadeShell.banner();

ArcadeShell.pause({
  enabled:  function () { return running; },
  onPause:  function () { running = false; },
  onResume: function () { running = true; loop(); }
});

var board;
ArcadeShell.leaderboard('#titleLb', 'late-shift').then(function (d) { board = d; });

// on game over
if (ArcadeShell.qualifies(score, board)) { showNameEntry(); }
ArcadeShell.submit('late-shift', name, score).then(function (d) {
  ArcadeShell.renderLeaderboard('#overLb', d, { highlight: name.toUpperCase() });
});
```

### Never keep a local copy of the sort direction

`/api/scores` returns `sort` (`"asc"` for time-based games, `"desc"` for
points) and `ArcadeShell` uses it. Do not add your own table of which games are
time-based — the shelf used to have one, it listed two of the four ascending
games, and hacker-pro's times rendered as `"N pts"` for months.

---

## Design Tokens

Defined as CSS custom properties on `:root`:

| Token | Value | Use |
|---|---|---|
| `--ez-teal` | `#00ffc8` | Primary brand accent; QR boxes; teal-themed buttons |
| `--ez-yellow` | `#ffe44d` | Secondary brand accent; Dino Jump; start buttons |
| `--ez-pink` | `#ff6ec7` | Tertiary brand accent; gradient use |
| `--ez-red` | `#ff4757` | Destructive actions; exit button hover |
| `--ez-gold` | `#ffd23b` | Leaderboard titles; Golden Goal; winner cards |
| `--ez-bg` | `#0a0a12` | Page background |
| `--ez-surface` | `#13131f` | Card/input backgrounds |
| `--ez-border` | `rgba(255,255,255,0.08)` | Subtle borders |
| `--ez-font` | `'Courier New', monospace` | Body font |

### 4-Slot Character Palette

The standard slot colours are consistent across all party games:

| Slot | Token | Colour | Name |
|---|---|---|---|
| 0 | `--ez-slot-0` | `#00ffaa` | GREEN |
| 1 | `--ez-slot-1` | `#ff3b6b` | PINK |
| 2 | `--ez-slot-2` | `#3aa0ff` | BLUE |
| 3 | `--ez-slot-3` | `#ffd23b` | GOLD |

Games with their own character colour palette (e.g. Dino Jump uses Slate/Pixel/Fern/Echo) may override slot colours in JS while still using the shared `.ezaz-slot-card` structure.

---

## Shell Components

### Store Banner

The fixed top strip on every page. The EZ-AZ link always uses the same brand gradient regardless of the game's accent colour.

```html
<div class="ezaz-store-banner"><a href="/">EZ-AZ</a></div>
```

### Exit Button (Phone Contract clause 4)

Required on every phone screen. Frees the player slot server-side and returns them to the store.

```html
<button class="ezaz-exit-btn" id="exitBtn">EXIT</button>
```

Wire it using `ArcadeCable.attachExit` (shared games) or manually for games using a custom cable:

```javascript
// ArcadeCable games
ArcadeCable.attachExit(document.getElementById('exitBtn'), sub);

// Custom cable games (e.g. Dino Jump)
document.getElementById('exitBtn').addEventListener('click', function() {
  if (sub && mySlot !== null) { try { sub.send('leave', {}); } catch (_) {} }
  setTimeout(function() { window.location.href = '/'; }, 150);
});
```

### Primary Action Button

The main CTA on phone join screens. Games may override the background and foreground colours with CSS custom properties.

```html
<!-- Default teal -->
<button class="ezaz-btn-primary" id="joinBtn">JOIN GAME</button>

<!-- Game accent colour override -->
<button class="ezaz-btn-primary" style="--ez-btn-bg:#ffd23b;--ez-btn-fg:#141004;">KICK OFF</button>
```

### Outline Button

Secondary actions on lobby and game-over screens (back to lobby, back to store). Replaces the near-invisible `rgba(255,255,255,0.2)` treatment used by early games.

```html
<button class="ezaz-btn-outline">BACK TO LOBBY</button>
<a href="/" class="ezaz-btn-outline">BACK TO STORE</a>
```

### Name Input and Label

```html
<span class="ezaz-label">Your name</span>
<input class="ezaz-name-input" type="text" maxlength="12" placeholder="ENTER NAME"
       autocomplete="off" autocorrect="off" autocapitalize="characters" spellcheck="false">
<div class="ezaz-error-msg" id="errorMsg"></div>
```

Games may override the focus border colour:

```css
/* Game-specific accent on focus */
.ezaz-name-input:focus { border-color: #ffd23b; }
```

---

## Phone Screen Layouts

### Join Screen

```html
<div class="screen active" id="screenJoin">
  <div class="join-inner">
    <div class="game-title">GAME NAME</div>
    <div class="game-sub">Subtitle text</div>
    <span class="ezaz-label">Your name</span>
    <input class="ezaz-name-input" id="nameInput" ...>
    <div class="ezaz-error-msg" id="errorMsg"></div>
    <button class="ezaz-btn-primary" id="joinBtn" ...>JOIN GAME</button>
  </div>
</div>
```

### Lobby Screen

```html
<div class="screen" id="screenLobby">
  <div class="ezaz-lobby-inner">
    <div class="game-title">GAME NAME</div>
    <div class="ezaz-char-badge" id="lobbyBadge"></div>
    <div class="ezaz-char-name" id="lobbyCharName"></div>
    <div class="ezaz-waiting">Waiting for the host to start...</div>
  </div>
</div>
```

### Game Over Screen

```html
<div class="screen" id="screenOver">
  <div class="ezaz-gameover-inner">
    <div class="game-title">GAME NAME</div>
    <div class="ezaz-go-rank" id="goRank"></div>
    <div class="ezaz-go-name" id="goName"></div>
    <div class="ezaz-go-score" id="goScore"></div>
    <button class="ezaz-btn-outline" id="lobbyAgainBtn">BACK TO LOBBY</button>
    <a href="/" class="ezaz-btn-outline">BACK TO STORE</a>
  </div>
</div>
```

---

## TV Title Screen Primitives

### QR Join Box

The scan-to-join panel on TV title screens. Always teal-bordered because the scan action is a brand-level interaction, not a game-level one.

```html
<div class="ezaz-qr-box">
  <p class="ezaz-qr-label">SCAN TO JOIN ON YOUR PHONE</p>
  <img id="joinQr" alt="Scan to join" style="width:180px;height:180px;...">
  <p id="joinUrl" class="ezaz-qr-url"></p>
</div>
```

### Slot Cards

4-up player grid on the title screen. JS adds `.filled` and sets `--slot-colour` when a player joins.

```html
<div class="ezaz-slot-card" id="slot0">
  <div class="ezaz-slot-tag" style="color:#00ffaa;">GREEN</div>
  <div class="ezaz-slot-name" id="slot0name">EMPTY</div>
</div>
```

```javascript
function updateSlot(slot, name) {
  var el = document.getElementById('slot' + slot);
  var nm = document.getElementById('slot' + slot + 'name');
  if (el) {
    if (name) {
      el.classList.add('filled');
      el.style.setProperty('--slot-colour', COLOURS[slot]);
    } else {
      el.classList.remove('filled');
      el.style.removeProperty('--slot-colour');
    }
  }
  if (nm) nm.textContent = name || 'EMPTY';
}
```

### Leaderboard

```html
<div class="ezaz-lb-wrap" id="titleLb"></div>
```

JS renders the rows using shared classes:

```javascript
function renderLb(elId, hlName) {
  var el = document.getElementById(elId);
  if (!el) return;
  if (!lbData.length) {
    el.innerHTML = '<div class="ezaz-lb-title">HIGH SCORES</div>'
                 + '<div class="ezaz-lb-empty">No scores yet. Be the first!</div>';
    return;
  }
  var h = '<div class="ezaz-lb-title">HIGH SCORES</div>';
  lbData.slice(0, 10).forEach(function(row, i) {
    var hl = hlName && row.name === hlName ? ' highlight' : '';
    h += '<div class="ezaz-lb-row' + hl + '"><span>#' + (i + 1) + ' '
       + row.name + '</span><span>' + row.value + '</span></div>';
  });
  el.innerHTML = h;
}
```

### Name Entry (leaderboard save)

```html
<div id="nameEntry" style="display:none;">
  <p style="...">YOUR NAME:</p>
  <input type="text" id="nameInput" class="ezaz-lb-name-input" maxlength="10" placeholder="NAME">
  <button class="ezaz-btn-save" onclick="saveScore()">SAVE</button>
</div>
```

### Score Cards (end screen)

```javascript
sorted.forEach(function(p, i) {
  grid += '<div class="ezaz-score-card' + (i === 0 ? ' winner' : '') + '">';
  grid += '<div class="ezaz-score-tag" style="color:' + p.colour + '">' + p.name + '</div>';
  grid += '<div class="ezaz-score-val">' + p.score + ' pts</div>';
  grid += '<div class="ezaz-score-rank">' + (i === 0 ? 'CHAMPION' : '#' + (i + 1)) + '</div>';
  grid += '</div>';
});
```

### Hint Text

```html
<p class="ezaz-hint">Keyboard still works &nbsp;|&nbsp; ESC to pause</p>
```

---

## Pause Overlay

Built and wired by `ArcadeShell.pause()`. Games should not hand-roll it.

```html
<!-- created for you; shown here only so the structure is documented -->
<div class="ezaz-pause">
  <div class="ezaz-pause-inner">
    <div class="ezaz-pause-title">PAUSED</div>
    <button class="ezaz-btn-primary" data-ezaz-resume>RESUME</button>
    <a href="/" class="ezaz-btn-outline">QUIT TO STORE</a>
  </div>
</div>
```

## Title / Game Over Screen

A full-screen overlay that stops the game auto-playing, and the same structure
again for game over. Add `.hidden` to hide one. Theme the heading with
`--ez-title-colour`.

```html
<div class="ezaz-title" id="titleScreen">
  <div class="ezaz-title-name">YOUR GAME</div>
  <div class="ezaz-title-tag">One line on what the player does.</div>
  <p class="ezaz-hint">Arrow keys to move &nbsp;|&nbsp; ESC to pause</p>
  <button class="ezaz-btn-primary" id="startBtn">START</button>
  <div class="ezaz-lb-wrap" id="titleLb"></div>
</div>
```

---

## Applying the System to a New Game

**Copy `docs/game-template.html` to `public/games/<slug>.html`.** It already has
all of the below. Then:

1. Fill in the three marked sections: your styles, your loop, your input.
2. Call `gameOver()` when the run ends — that is the only contract the wrapper
   needs from your game.
3. Register the slug in `app/models/score.rb`, `app/models/game.rb` and the
   shelf in `public/index.html` (see CLAUDE.md), then run
   `bin/rails test test/models/game_test.rb`.

For a phone-controlled party game, additionally use `.ezaz-exit-btn` with
`ArcadeCable.attachExit` on every phone screen (Phone Contract clause 4), and
`.ezaz-btn-primary` for JOIN, overriding `--ez-btn-bg` / `--ez-btn-fg` to your
accent colour.

---

## Adoption

`ShellAdoptionTest` enforces this for new games and holds an explicit list of
the games that predate it. The list is allowed to shrink and nothing may be
added to it.

| Game | Shell CSS | `ArcadeShell` |
|---|---|---|
| Magnet Lab | yes | yes — banner, leaderboard, submit, qualifies |
| Snake Pit Royale | yes | not yet |
| Golden Goal | yes | not yet |
| Dino Jump | yes | not yet |
| The other ten | no | no |

Magnet Lab is the worked example. It lost 43 lines: its own copy of the banner
CSS, `loadLeaderboard`, `renderLB`, a private `escape()` and a hand-rolled
POST. Its canvas-drawn pause was deliberately left alone — the shell's pause is
an HTML overlay, and a canvas game drawing its own is a legitimate choice.

One gotcha found doing it: if a game centres overlay children with
`align-items`, an intermediate wrapper shrink-wraps and the shell's
`width: 100%` resolves against it, collapsing the leaderboard rows. Give the
wrapper an explicit width.

Games predating the system (Family Trivia, Spotlight, Treasure Hunt) served as
the design reference; their primitives were extracted into the shared CSS.

Migrating the remaining games is deliberately a separate pass — it means
editing large, self-contained game files that cannot be automatically
playtested, so it should be done one game at a time with a browser check each
time. The wrapper being shared matters most for the *next* game; the existing
ones already work.
