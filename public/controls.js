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
    Space:      { key: ' ',          code: 'Space',       keyCode: 32 },
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

  function isTablet() {
    return window.innerWidth >= 600;
  }

  // Inject styles. Control positions use env(safe-area-inset-*) so the
  // joystick, action buttons, and pause button clear the iOS notch and
  // home indicator (addresses part of #12's audit + closes #11).
  var style = document.createElement('style');
  style.textContent =
    '.ez-controls{position:fixed;top:0;left:0;right:0;bottom:0;pointer-events:none;z-index:20}' +

    // Joystick (phone)
    '.ez-joy-base{position:absolute;' +
      'bottom:max(env(safe-area-inset-bottom),24px);' +
      'left:max(env(safe-area-inset-left),24px);' +
      'pointer-events:auto;' +
      'width:min(30vw,150px);height:min(30vw,150px);border-radius:50%;' +
      'background:rgba(255,255,255,0.08);border:2px solid rgba(255,255,255,0.2);' +
      'touch-action:none;-webkit-user-select:none;user-select:none}' +
    '.ez-joy-knob{position:absolute;width:40%;height:40%;border-radius:50%;' +
      'background:rgba(255,255,255,0.3);border:2px solid rgba(255,255,255,0.4);' +
      'top:50%;left:50%;transform:translate(-50%,-50%);pointer-events:none;' +
      'transition:background 0.1s}' +
    '.ez-joy-base.active .ez-joy-knob{background:rgba(255,255,255,0.5)}' +

    // WASD pad (tablet)
    '.ez-wasd{position:absolute;' +
      'bottom:max(env(safe-area-inset-bottom),24px);' +
      'left:max(env(safe-area-inset-left),24px);' +
      'display:flex;flex-direction:column;gap:8px;align-items:center;' +
      'pointer-events:auto;-webkit-user-select:none;user-select:none}' +
    '.ez-wasd-row{display:flex;gap:8px}' +
    '.ez-wasd-btn{width:80px;height:80px;border-radius:14px;' +
      'background:rgba(255,255,255,0.1);border:2px solid rgba(255,255,255,0.25);' +
      'color:rgba(255,255,255,0.8);display:flex;align-items:center;justify-content:center;' +
      'font-family:"Press Start 2P",monospace;font-size:18px;font-weight:bold;' +
      'touch-action:none;-webkit-user-select:none;user-select:none}' +
    '.ez-wasd-btn.active{background:rgba(255,255,255,0.3);border-color:rgba(255,255,255,0.6)}' +

    // Action buttons area (right side)
    '.ez-btn-area{position:absolute;' +
      'bottom:max(env(safe-area-inset-bottom),24px);' +
      'right:max(env(safe-area-inset-right),24px);' +
      'pointer-events:auto;' +
      'display:flex;flex-direction:column;gap:12px;align-items:center;touch-action:none;' +
      '-webkit-user-select:none;user-select:none}' +
    '.ez-btn{width:64px;height:64px;border-radius:50%;' +
      'background:rgba(255,255,255,0.1);border:2px solid rgba(255,255,255,0.25);' +
      'color:rgba(255,255,255,0.7);display:flex;align-items:center;justify-content:center;' +
      'font-family:"Press Start 2P",monospace;font-size:10px;touch-action:none;' +
      '-webkit-user-select:none;user-select:none}' +
    '.ez-btn.tablet{width:90px;height:90px;font-size:13px}' +
    '.ez-btn.active{background:rgba(255,255,255,0.3);border-color:rgba(255,255,255,0.5)}' +

    // Pause button
    '.ez-btn-pause{width:40px;height:40px;font-size:14px;position:absolute;' +
      'top:max(env(safe-area-inset-top),44px);' +
      'right:max(env(safe-area-inset-right),12px);' +
      'pointer-events:auto;border-radius:50%;' +
      'background:rgba(255,255,255,0.08);border:2px solid rgba(255,255,255,0.2);' +
      'color:rgba(255,255,255,0.6);display:flex;align-items:center;justify-content:center;' +
      'touch-action:none;-webkit-user-select:none;user-select:none}' +
    '.ez-btn-pause.active{background:rgba(255,255,255,0.3)}';
  document.head.appendChild(style);

  function init() {
    var container = document.createElement('div');
    container.className = 'ez-controls';

    var tablet = isTablet();

    if (tablet) {
      buildWasd(container);
    } else {
      buildJoystick(container);
    }

    buildActionButtons(container, tablet);
    buildPauseButton(container);

    document.body.appendChild(container);

    document.addEventListener('visibilitychange', function() {
      if (document.hidden) {
        releaseAllKeys();
      }
    });
  }

  var heldKeys = {};

  function releaseAllKeys() {
    for (var code in heldKeys) {
      if (heldKeys[code]) fireKey('keyup', heldKeys[code]);
    }
    heldKeys = {};
  }

  // --- Joystick (phone) ---
  var joyTouchId = null;
  var joyCenter  = { x: 0, y: 0 };
  var joyRadius  = 0;
  var dirs = { up: false, down: false, left: false, right: false };
  var dirKeys = {
    up: KEY.ArrowUp, down: KEY.ArrowDown,
    left: KEY.ArrowLeft, right: KEY.ArrowRight
  };

  function buildJoystick(container) {
    var joyBase = document.createElement('div');
    joyBase.className = 'ez-joy-base';
    var joyKnob = document.createElement('div');
    joyKnob.className = 'ez-joy-knob';
    joyBase.appendChild(joyKnob);
    container.appendChild(joyBase);

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
        if (angle > -2.749 && angle < -0.393) newDirs.up    = true;
        if (angle > 0.393  && angle < 2.749)  newDirs.down  = true;
        if (angle > 1.963  || angle < -1.963) newDirs.left  = true;
        if (angle > -1.178 && angle < 1.178)  newDirs.right = true;
      }

      for (var d in dirs) {
        if (dirs[d] && !newDirs[d]) fireKey('keyup',   dirKeys[d]);
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
      joyCenter.y = rect.top  + rect.height / 2;
      joyRadius   = rect.width / 2;
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
  }

  // --- WASD buttons (tablet) ---
  function buildWasd(container) {
    var pad = document.createElement('div');
    pad.className = 'ez-wasd';

    var mapping = [
      { label: 'W', key: KEY.ArrowUp },
      { label: 'A', key: KEY.ArrowLeft },
      { label: 'S', key: KEY.ArrowDown },
      { label: 'D', key: KEY.ArrowRight }
    ];

    var topRow = document.createElement('div');
    topRow.className = 'ez-wasd-row';
    var botRow = document.createElement('div');
    botRow.className = 'ez-wasd-row';

    mapping.forEach(function(m) {
      var btn = document.createElement('div');
      btn.className = 'ez-wasd-btn';
      btn.textContent = m.label;
      var touchId = null;

      btn.addEventListener('touchstart', function(e) {
        e.preventDefault();
        if (touchId !== null) return;
        touchId = e.changedTouches[0].identifier;
        btn.classList.add('active');
        fireKey('keydown', m.key);
      });

      function release(e) {
        for (var i = 0; i < e.changedTouches.length; i++) {
          if (e.changedTouches[i].identifier === touchId) {
            touchId = null;
            btn.classList.remove('active');
            fireKey('keyup', m.key);
            break;
          }
        }
      }

      btn.addEventListener('touchend',    release);
      btn.addEventListener('touchcancel', release);

      if (m.label === 'W') {
        topRow.appendChild(btn);
      } else {
        botRow.appendChild(btn);
      }
    });

    pad.appendChild(topRow);
    pad.appendChild(botRow);
    container.appendChild(pad);
  }

  // --- Action buttons ---
  function buildActionButtons(container, tablet) {
    if (buttons.length === 0) return;

    var btnArea = document.createElement('div');
    btnArea.className = 'ez-btn-area';

    buttons.forEach(function(name) {
      var def = BUTTON_DEFS[name.trim()];
      if (!def) return;
      var btn = document.createElement('div');
      btn.className = tablet ? 'ez-btn tablet' : 'ez-btn';
      btn.textContent = def.label;
      var btnTouchId = null;

      btn.addEventListener('touchstart', function(e) {
        e.preventDefault();
        if (btnTouchId !== null) return;
        btnTouchId = e.changedTouches[0].identifier;
        btn.classList.add('active');
        def.keys.forEach(function(k) { fireKey('keydown', k); });
      });

      function release(e) {
        for (var i = 0; i < e.changedTouches.length; i++) {
          if (e.changedTouches[i].identifier === btnTouchId) {
            btn.classList.remove('active');
            def.keys.forEach(function(k) { fireKey('keyup', k); });
            btnTouchId = null;
            break;
          }
        }
      }

      btn.addEventListener('touchend',    release);
      btn.addEventListener('touchcancel', release);

      btnArea.appendChild(btn);
    });

    container.appendChild(btnArea);
  }

  // --- Pause button ---
  function buildPauseButton(container) {
    var pauseBtn = document.createElement('div');
    pauseBtn.className = 'ez-btn-pause';
    pauseBtn.textContent = '||';

    pauseBtn.addEventListener('touchstart', function(e) {
      e.preventDefault();
      pauseBtn.classList.add('active');
      fireKey('keydown', KEY.Escape);
    });
    pauseBtn.addEventListener('touchend', function() {
      pauseBtn.classList.remove('active');
      fireKey('keyup', KEY.Escape);
    });
    pauseBtn.addEventListener('touchcancel', function() {
      pauseBtn.classList.remove('active');
      fireKey('keyup', KEY.Escape);
    });

    container.appendChild(pauseBtn);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
