// EZ-AZ TV Engine
// Include in any TV-optimised game. Reads the token + ActionCable path stored
// by the TV shelf page, connects to TvRemoteChannel, and maps phone D-pad
// inputs to keyboard events that the game already handles.
//
// Player assignment: first phone to send input = P1, second = P2.
// P1 → Arrow keys + ShiftRight (action)
// P2 → WASD + ShiftLeft (action)
//
// Usage: <script src="/tv-engine.js"></script>  (before </body>)

(function () {
  var token  = sessionStorage.getItem('tvRemoteToken');
  var acPath = sessionStorage.getItem('tvAcPath');
  if (!token || !acPath) return;

  // ── Key maps ────────────────────────────────────────────────────────────
  var P1 = {
    up:     { key: 'ArrowUp',    code: 'ArrowUp',    keyCode: 38 },
    down:   { key: 'ArrowDown',  code: 'ArrowDown',  keyCode: 40 },
    left:   { key: 'ArrowLeft',  code: 'ArrowLeft',  keyCode: 37 },
    right:  { key: 'ArrowRight', code: 'ArrowRight', keyCode: 39 },
    select: { key: 'Enter',      code: 'Enter',      keyCode: 13 },
    back:   { key: 'Escape',     code: 'Escape',     keyCode: 27 },
    action: { key: 'Shift',      code: 'ShiftRight', keyCode: 16, shiftKey: true }
  };

  var P2 = {
    up:     { key: 'w',      code: 'KeyW',      keyCode: 87 },
    down:   { key: 's',      code: 'KeyS',      keyCode: 83 },
    left:   { key: 'a',      code: 'KeyA',      keyCode: 65 },
    right:  { key: 'd',      code: 'KeyD',      keyCode: 68 },
    select: { key: 'Enter',  code: 'Enter',     keyCode: 13 },
    back:   { key: 'Escape', code: 'Escape',    keyCode: 27 },
    action: { key: 'Shift',  code: 'ShiftLeft', keyCode: 16, shiftKey: true }
  };

  var MAPS = [P1, P2];

  // ── Player slot assignment ───────────────────────────────────────────────
  // First phone_id seen = P1, second = P2.
  var playerMap = {};
  var nextSlot  = 0;

  function slotFor(phoneId) {
    if (!phoneId) return 0;
    if (playerMap[phoneId] === undefined) {
      if (nextSlot >= MAPS.length) return -1;
      playerMap[phoneId] = nextSlot++;
    }
    return playerMap[phoneId];
  }

  // ── Key event firing ─────────────────────────────────────────────────────
  // Track held state per player+key to avoid spurious repeat keydowns.
  var held = {};

  function fire(evType, k, tag) {
    if (evType === 'keydown') {
      if (held[tag]) return;
      held[tag] = true;
    } else {
      if (!held[tag]) return;
      held[tag] = false;
    }
    document.dispatchEvent(new KeyboardEvent(evType, {
      key:      k.key,
      code:     k.code,
      keyCode:  k.keyCode,
      which:    k.keyCode,
      shiftKey: !!k.shiftKey,
      bubbles:  true,
      cancelable: true
    }));
  }

  // ── Connect ──────────────────────────────────────────────────────────────
  import(acPath).then(function (mod) {
    var consumer = mod.createConsumer();

    consumer.subscriptions.create(
      { channel: 'TvRemoteChannel', token: token },
      {
        connected: function () {
          this.perform('set_state', { state: 'game' });
        },
        received: function (data) {
          if (data.type !== 'navigate') return;

          var slot = slotFor(data.phone_id);
          if (slot < 0) return;

          var map = MAPS[slot];
          var k   = map[data.direction];
          if (!k) return;

          var tag    = slot + '_' + k.code;
          var evType = data.nav_type === 'release' ? 'keyup' : 'keydown';
          fire(evType, k, tag);
        }
      }
    );
  });
})();
