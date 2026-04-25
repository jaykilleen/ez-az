// EZ-AZ TV Engine
// Include in any TV-optimised game. Reads the token + ActionCable path stored
// by the TV shelf page, connects to TvRemoteChannel, and maps phone D-pad
// inputs to keyboard events that the game already handles.
//
// Player assignment: server assigns slots (P1/P2) via slot_assigned/rejoined
// broadcasts. Falls back to first-come-first-served for anonymous clients.
// P1 → Arrow keys + ShiftRight (action)
// P2 → WASD + ShiftLeft (action)

(function () {
  var token  = sessionStorage.getItem('tvRemoteToken');
  var acPath = sessionStorage.getItem('tvAcPath');
  if (!token || !acPath) return;

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

  // Player slot assignment — updated from server broadcasts (slot_assigned/rejoined).
  // Falls back to first-come-first-served for anonymous clients.
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

  import(acPath).then(function (mod) {
    var consumer = mod.createConsumer();

    consumer.subscriptions.create(
      { channel: 'TvRemoteChannel', token: token },
      {
        connected: function () {
          this.perform('set_state', { state: 'game' });
        },
        received: function (data) {
          // Server-assigned slots take priority over first-come-first-served
          if (data.type === 'slot_assigned' || data.type === 'rejoined') {
            if (data.phone_id && data.slot != null) {
              playerMap[data.phone_id] = data.slot - 1;  // 0-indexed
            }
            return;
          }

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
