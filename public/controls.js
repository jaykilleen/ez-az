(function() {
  if (!('ontouchstart' in window) && navigator.maxTouchPoints <= 0) return;

  var script = document.currentScript;
  var buttonConfig = (script && script.getAttribute('data-buttons')) || 'sprint';
  var buttons = buttonConfig === 'none' ? [] : buttonConfig.split(',');

  var KEY = {
    ArrowUp:    { key: 'ArrowUp',    code: 'ArrowUp',    keyCode: 38 },
    ArrowDown:  { key: 'ArrowDown',  code: 'ArrowDown',  keyCode: 40 },
    ArrowLeft:  { key: 'ArrowLeft',  code: 'ArrowLeft',  keyCode: 37 },
    ArrowRight: { key: 'ArrowRight', code: 'ArrowRight', keyCode: 39 },
    ShiftLeft:  { key: 'Shift',      code: 'ShiftLeft',  keyCode: 16 },
    Space:      { key: ' ',          code: 'Space',      keyCode: 32 },
    Escape:     { key: 'Escape',     code: 'Escape',     keyCode: 27 }
  };

  var BUTTON_DEFS = {
    sprint: { label: 'RUN',  keys: [KEY.ShiftLeft, KEY.Space] },
    shoot:  { label: 'FIRE', keys: [KEY.ShiftLeft] },
    attack: { label: 'ATK',  keys: [KEY.ShiftLeft] },
    block:  { label: 'BLK',  keys: [KEY.Space] }
  };

  function fireKey(type, entry) {
    document.dispatchEvent(new KeyboardEvent(type, {
      key: entry.key,
      code: entry.code,
      keyCode: entry.keyCode,
      which: entry.keyCode,
      shiftKey: entry.key === 'Shift',
      bubbles: true,
      cancelable: true
    }));
  }

  // Inject styles
  var style = document.createElement('style');
  style.textContent =
    '.ez-controls{position:fixed;top:0;left:0;right:0;bottom:0;pointer-events:none;z-index:20}' +
    '.ez-joy-base{position:absolute;bottom:24px;left:24px;pointer-events:auto;' +
      'width:min(30vw,150px);height:min(30vw,150px);border-radius:50%;' +
      'background:rgba(255,255,255,0.08);border:2px solid rgba(255,255,255,0.2);' +
      'touch-action:none;-webkit-user-select:none;user-select:none}' +
    '.ez-joy-knob{position:absolute;width:40%;height:40%;border-radius:50%;' +
      'background:rgba(255,255,255,0.3);border:2px solid rgba(255,255,255,0.4);' +
      'top:50%;left:50%;transform:translate(-50%,-50%);pointer-events:none;' +
      'transition:background 0.1s}' +
    '.ez-joy-base.active .ez-joy-knob{background:rgba(255,255,255,0.5)}' +
    '.ez-btn-area{position:absolute;bottom:24px;right:24px;pointer-events:auto;' +
      'display:flex;flex-direction:column;gap:12px;align-items:center;touch-action:none;' +
      '-webkit-user-select:none;user-select:none}' +
    '.ez-btn{width:64px;height:64px;border-radius:50%;' +
      'background:rgba(255,255,255,0.1);border:2px solid rgba(255,255,255,0.25);' +
      'color:rgba(255,255,255,0.7);display:flex;align-items:center;justify-content:center;' +
      'font-family:"Press Start 2P",monospace;font-size:10px;touch-action:none;' +
      '-webkit-user-select:none;user-select:none}' +
    '.ez-btn.active{background:rgba(255,255,255,0.3);border-color:rgba(255,255,255,0.5)}' +
    '.ez-btn-pause{width:40px;height:40px;font-size:14px;position:absolute;top:44px;right:12px;' +
      'pointer-events:auto;border-radius:50%;' +
      'background:rgba(255,255,255,0.08);border:2px solid rgba(255,255,255,0.2);' +
      'color:rgba(255,255,255,0.6);display:flex;align-items:center;justify-content:center;' +
      'touch-action:none;-webkit-user-select:none;user-select:none}' +
    '.ez-btn-pause.active{background:rgba(255,255,255,0.3)}';
  document.head.appendChild(style);

  function init() {
    var container = document.createElement('div');
    container.className = 'ez-controls';

    // --- Joystick ---
    var joyBase = document.createElement('div');
    joyBase.className = 'ez-joy-base';
    var joyKnob = document.createElement('div');
    joyKnob.className = 'ez-joy-knob';
    joyBase.appendChild(joyKnob);
    container.appendChild(joyBase);

    var joyTouchId = null;
    var joyCenter = { x: 0, y: 0 };
    var joyRadius = 0;
    var dirs = { up: false, down: false, left: false, right: false };
    var dirKeys = {
      up: KEY.ArrowUp, down: KEY.ArrowDown,
      left: KEY.ArrowLeft, right: KEY.ArrowRight
    };

    function updateJoy(tx, ty) {
      var dx = tx - joyCenter.x;
      var dy = ty - joyCenter.y;
      var dist = Math.sqrt(dx * dx + dy * dy);
      var maxDist = joyRadius;
      if (dist > maxDist) { dx = dx / dist * maxDist; dy = dy / dist * maxDist; }

      joyKnob.style.transform = 'translate(calc(-50% + ' + dx + 'px), calc(-50% + ' + dy + 'px))';

      var deadZone = joyRadius * 0.2;
      var newDirs = { up: false, down: false, left: false, right: false };
      if (dist > deadZone) {
        var angle = Math.atan2(dy, dx);
        // 8-way: use 22.5 degree slices
        if (angle > -2.749 && angle < -0.393) newDirs.up = true;    // -157.5 to -22.5
        if (angle > 0.393 && angle < 2.749) newDirs.down = true;    // 22.5 to 157.5
        if (angle > 1.963 || angle < -1.963) newDirs.left = true;   // 112.5 to -112.5 (wraps)
        if (angle > -1.178 && angle < 1.178) newDirs.right = true;  // -67.5 to 67.5
      }

      for (var d in dirs) {
        if (dirs[d] && !newDirs[d]) fireKey('keyup', dirKeys[d]);
        if (!dirs[d] && newDirs[d]) fireKey('keydown', dirKeys[d]);
      }
      dirs = newDirs;
    }

    function releaseJoy() {
      joyKnob.style.transform = 'translate(-50%, -50%)';
      joyBase.classList.remove('active');
      for (var d in dirs) {
        if (dirs[d]) fireKey('keyup', dirKeys[d]);
      }
      dirs = { up: false, down: false, left: false, right: false };
      joyTouchId = null;
    }

    joyBase.addEventListener('touchstart', function(e) {
      e.preventDefault();
      if (joyTouchId !== null) return;
      var t = e.changedTouches[0];
      joyTouchId = t.identifier;
      var rect = joyBase.getBoundingClientRect();
      joyCenter.x = rect.left + rect.width / 2;
      joyCenter.y = rect.top + rect.height / 2;
      joyRadius = rect.width / 2;
      joyBase.classList.add('active');
      updateJoy(t.clientX, t.clientY);
    });

    joyBase.addEventListener('touchmove', function(e) {
      e.preventDefault();
      for (var i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === joyTouchId) {
          updateJoy(e.changedTouches[i].clientX, e.changedTouches[i].clientY);
          break;
        }
      }
    });

    joyBase.addEventListener('touchend', function(e) {
      for (var i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === joyTouchId) { releaseJoy(); break; }
      }
    });
    joyBase.addEventListener('touchcancel', function(e) {
      for (var i = 0; i < e.changedTouches.length; i++) {
        if (e.changedTouches[i].identifier === joyTouchId) { releaseJoy(); break; }
      }
    });

    // --- Action buttons ---
    if (buttons.length > 0) {
      var btnArea = document.createElement('div');
      btnArea.className = 'ez-btn-area';

      buttons.forEach(function(name) {
        var def = BUTTON_DEFS[name.trim()];
        if (!def) return;
        var btn = document.createElement('div');
        btn.className = 'ez-btn';
        btn.textContent = def.label;
        var btnTouchId = null;

        btn.addEventListener('touchstart', function(e) {
          e.preventDefault();
          if (btnTouchId !== null) return;
          btnTouchId = e.changedTouches[0].identifier;
          btn.classList.add('active');
          def.keys.forEach(function(k) { fireKey('keydown', k); });
        });
        btn.addEventListener('touchend', function(e) {
          for (var i = 0; i < e.changedTouches.length; i++) {
            if (e.changedTouches[i].identifier === btnTouchId) {
              btn.classList.remove('active');
              def.keys.forEach(function(k) { fireKey('keyup', k); });
              btnTouchId = null;
              break;
            }
          }
        });
        btn.addEventListener('touchcancel', function(e) {
          for (var i = 0; i < e.changedTouches.length; i++) {
            if (e.changedTouches[i].identifier === btnTouchId) {
              btn.classList.remove('active');
              def.keys.forEach(function(k) { fireKey('keyup', k); });
              btnTouchId = null;
              break;
            }
          }
        });

        btnArea.appendChild(btn);
      });

      container.appendChild(btnArea);
    }

    // --- Pause button ---
    var pauseBtn = document.createElement('div');
    pauseBtn.className = 'ez-btn-pause';
    pauseBtn.textContent = '||';
    pauseBtn.addEventListener('touchstart', function(e) {
      e.preventDefault();
      pauseBtn.classList.add('active');
      fireKey('keydown', KEY.Escape);
    });
    pauseBtn.addEventListener('touchend', function(e) {
      pauseBtn.classList.remove('active');
      fireKey('keyup', KEY.Escape);
    });
    pauseBtn.addEventListener('touchcancel', function(e) {
      pauseBtn.classList.remove('active');
      fireKey('keyup', KEY.Escape);
    });
    container.appendChild(pauseBtn);

    document.body.appendChild(container);

    // Release all keys on tab hide
    document.addEventListener('visibilitychange', function() {
      if (document.hidden) {
        releaseJoy();
        // Release any held action button keys
        buttons.forEach(function(name) {
          var def = BUTTON_DEFS[name.trim()];
          if (def) def.keys.forEach(function(k) { fireKey('keyup', k); });
        });
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
