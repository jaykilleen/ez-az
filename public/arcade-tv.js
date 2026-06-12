// ArcadeTV — shared TV-side helpers for EZ-AZ arcade party games. Vanilla
// JS, raw WebSocket (no actioncable.esm dependency, so static pages under
// public/games/ can use it). Implements the TV half of the Phone Contract:
//
//   ArcadeTV.sessionCode()
//     Reads ?code= from the URL, or mints a fresh 4-char code and pins it in
//     the URL with history.replaceState — so a reload, or the /tv resume
//     banner, lands back in the SAME session (clauses 6 and 9).
//
//   ArcadeTV.connectRemote({ gameTitle, roomCode, onBack, onHome, onNavigate })
//     Subscribes to TvRemoteChannel using the token /tv saved in
//     sessionStorage ('tvRemoteToken'), announces set_state('game') on
//     connect, maps navigate onto the focus model below, and handles
//     tv_home by calling onHome (default: go to '/tv') — clause 2.
//     Safe no-op (returns null) when the page wasn't launched from /tv.
//
//   ArcadeTV.setButtons(els[, idx])
//     Registers the focusable buttons for the current TV screen. The phone
//     pad then drives them: left/up = previous, right/down = next,
//     select/action = click the focused button, back = opts.onBack() —
//     clause 1: every TV button reachable from a phone.
//
//   ArcadeTV.saveActiveGame({ slug, title, code }) / ArcadeTV.clearActiveGame()
//     The ezaz_active_tv_game resume contract (clause 9, ADR 006 §7).
(function () {
  var wsBase = window.location.origin.replace(/^http/, 'ws') + '/cable';
  var RESUME_KEY = 'ezaz_active_tv_game';
  var CODE_CHARS = 'BCDFGHJKLMNPQRSTVWXYZ23456789';

  // ── Focus model ─────────────────────────────────────────────────────────
  var buttons = [];
  var focusIdx = 0;
  var remoteOpts = null;

  function paintFocus() {
    buttons.forEach(function (el, i) {
      if (!el) return;
      if (i === focusIdx) {
        el.style.outline = '4px solid #00ffaa';
        el.style.outlineOffset = '4px';
      } else {
        el.style.outline = 'none';
        el.style.outlineOffset = '';
      }
    });
  }

  function moveFocus(step) {
    if (!buttons.length) return;
    focusIdx = (focusIdx + step + buttons.length) % buttons.length;
    paintFocus();
  }

  function handleNavigate(direction) {
    switch (direction) {
      case 'left':
      case 'up':
        moveFocus(-1);
        break;
      case 'right':
      case 'down':
        moveFocus(1);
        break;
      case 'select':
      case 'action':
        if (buttons[focusIdx]) buttons[focusIdx].click();
        break;
      case 'back':
        if (remoteOpts && remoteOpts.onBack) remoteOpts.onBack();
        break;
    }
  }

  window.ArcadeTV = {
    sessionCode: function (len) {
      len = len || 4;
      var qs = new URLSearchParams(window.location.search);
      var code = (qs.get('code') || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
      if (code.length < 4) {
        code = '';
        for (var i = 0; i < len; i++) code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
        qs.set('code', code);
        try {
          history.replaceState({}, '', window.location.pathname + '?' + qs.toString());
        } catch (e) {}
      }
      return code;
    },

    connectRemote: function (opts) {
      remoteOpts = opts || {};
      var token;
      try { token = sessionStorage.getItem('tvRemoteToken'); } catch (e) { token = null; }
      if (!token) return null;

      var identifier = JSON.stringify({ channel: 'TvRemoteChannel', token: token });
      var ws = null;

      function send(obj) {
        if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
      }
      function perform(action, data) {
        send({ command: 'message', identifier: identifier, data: JSON.stringify(Object.assign({ action: action }, data || {})) });
      }
      function connect() {
        ws = new WebSocket(wsBase);
        ws.onopen = function () { send({ command: 'subscribe', identifier: identifier }); };
        ws.onmessage = function (e) {
          var msg = JSON.parse(e.data);
          if (msg.type === 'ping' || msg.type === 'welcome') return;
          if (msg.identifier !== identifier) return;
          if (msg.type === 'confirm_subscription') {
            var state = { state: 'game' };
            if (remoteOpts.roomCode) state.room_code = remoteOpts.roomCode;
            if (remoteOpts.gameTitle) state.game_title = remoteOpts.gameTitle;
            perform('set_state', state);
            return;
          }
          var data = msg.message;
          if (!data) return;
          if (data.type === 'tv_home') {
            if (remoteOpts.onHome) remoteOpts.onHome();
            else { ArcadeTV.clearActiveGame(); window.location.href = '/tv'; }
            return;
          }
          if (data.type !== 'navigate') return;
          if (data.nav_type === 'release') return;
          if (remoteOpts.onNavigate) remoteOpts.onNavigate(data.direction);
          else handleNavigate(data.direction);
        };
        ws.onclose = function () { setTimeout(connect, 2000); };
      }
      connect();

      return { perform: perform };
    },

    setButtons: function (els, idx) {
      var prev = buttons;
      buttons = (els || []).filter(function (el) { return !!el; });
      prev.forEach(function (el) {
        if (el && buttons.indexOf(el) < 0) { el.style.outline = 'none'; el.style.outlineOffset = ''; }
      });
      focusIdx = Math.min(Math.max(idx || 0, 0), Math.max(buttons.length - 1, 0));
      paintFocus();
    },

    saveActiveGame: function (game) {
      try {
        localStorage.setItem(RESUME_KEY, JSON.stringify({
          code: game.code,
          game_slug: game.slug,
          game_title: game.title,
          started_at: Date.now()
        }));
      } catch (e) {}
    },

    clearActiveGame: function () {
      try { localStorage.removeItem(RESUME_KEY); } catch (e) {}
    }
  };
})();
