# EZ-AZ Design System

The shared design system for EZ-AZ lives in `public/ez-az-shell.css`. It defines the design tokens and reusable shell components that wrap every game. All shared classes use the `.ezaz-` prefix to avoid collisions with game-specific styles.

Game-specific layout, canvas, and gameplay UI belongs in each game file. This system only touches the surfaces around the game.

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

## Applying the System to a New Game

1. Add the shared stylesheet link after any Google Fonts link:
   ```html
   <link rel="stylesheet" href="/ez-az-shell.css">
   ```

2. Use `.ezaz-store-banner` on both the TV game and the phone join page.

3. Wire the exit button on every phone screen using `.ezaz-exit-btn` and `ArcadeCable.attachExit`.

4. Use `.ezaz-btn-primary` for the JOIN button, overriding `--ez-btn-bg` and `--ez-btn-fg` to match the game's accent colour.

5. Use `.ezaz-btn-outline` for all secondary navigation buttons (back to lobby, back to store).

6. Use the TV primitives (QR box, slot cards, leaderboard, score cards) with the standard class names so the shared CSS renders them consistently.

---

## Covered Games

| Game | TV file | Phone join |
|---|---|---|
| Snake Pit Royale | `public/games/snake-pit-royale.html` | `app/views/snake_pit/join.html.erb` |
| Golden Goal | `public/games/golden-goal.html` | `app/views/golden_goal/join.html.erb` |
| Dino Jump | `public/games/dino-jump.html` | `app/views/dino_jump/join.html.erb` |

Games predating the system (Family Trivia, Spotlight, Treasure Hunt) served as the design reference. Their existing primitives were extracted into this shared file.
