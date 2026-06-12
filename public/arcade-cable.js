// ArcadeCable — shared phone-side ActionCable client for EZ-AZ arcade party
// games (Snake Pit Royale, Golden Goal, ...). Vanilla JS, no dependencies;
// the same minimal raw-WebSocket client the games already used inline, plus
// the Phone Contract pieces every join page needs:
//
//   ArcadeCable.subscribe(channelName, code, handlers)
//     -> sub with .send(action, data). handlers.received(msg) gets every
//        broadcast/transmission; handlers.connected() fires per (re)connect.
//
//   ArcadeCable.attachExit(el, getSub[, opts])
//     Wires el as the universal EXIT control (clause 4): performs `leave`
//     to free the slot server-side, then sends the phone home ('/').
//
//   ArcadeCable.hostStart(el, getSub)
//     Host-aware START button (clause 3). Returns { update(isHost, phase) };
//     call it on every state / joined / lobby_update / session_reset message
//     and the button shows only for the host while the session is in lobby.
(function () {
  var wsBase = window.location.origin.replace(/^http/, 'ws') + '/cable';

  function Cable() { this._subs = []; this._ws = null; this._connect(); }
  Cable.prototype._connect = function () {
    var self = this;
    this._ws = new WebSocket(wsBase);
    this._ws.onopen = function () {
      self._subs.forEach(function (s) { s._subscribe(); });
    };
    this._ws.onmessage = function (e) {
      var msg = JSON.parse(e.data);
      if (msg.type === 'ping' || msg.type === 'welcome') return;
      var id = msg.identifier;
      self._subs.forEach(function (s) {
        if (s._id !== id) return;
        if (msg.type === 'confirm_subscription') { if (s._handlers.connected) s._handlers.connected(); return; }
        if (msg.message && s._handlers.received) s._handlers.received(msg.message);
      });
    };
    this._ws.onclose = function () { setTimeout(function () { self._connect(); }, 2000); };
  };
  Cable.prototype._send = function (d) {
    if (this._ws && this._ws.readyState === WebSocket.OPEN) this._ws.send(JSON.stringify(d));
  };
  Cable.prototype.subscribe = function (params, handlers) {
    var s = new Sub(this, params, handlers);
    this._subs.push(s);
    if (this._ws && this._ws.readyState === WebSocket.OPEN) s._subscribe();
    return s;
  };

  function Sub(cable, params, handlers) {
    this._cable = cable;
    this._id = JSON.stringify(params);
    this._handlers = handlers || {};
  }
  Sub.prototype._subscribe = function () {
    this._cable._send({ command: 'subscribe', identifier: this._id });
  };
  Sub.prototype.send = function (action, data) {
    this._cable._send({
      command: 'message',
      identifier: this._id,
      data: JSON.stringify(Object.assign({ action: action }, data || {}))
    });
  };

  var shared = null;
  function cable() { return shared || (shared = new Cable()); }
  function resolve(subOrFn) { return typeof subOrFn === 'function' ? subOrFn() : subOrFn; }

  window.ArcadeCable = {
    subscribe: function (channelName, code, handlers) {
      return cable().subscribe({ channel: channelName, code: code, role: 'phone' }, handlers);
    },

    attachExit: function (el, subOrFn, opts) {
      if (!el) return;
      var fired = false;
      function exit(e) {
        if (e && e.preventDefault) e.preventDefault();
        if (fired) return;
        fired = true;
        try {
          var sub = resolve(subOrFn);
          if (sub) sub.send('leave', {});
        } catch (err) {}
        // Give the leave a beat to hit the wire before navigating away.
        setTimeout(function () {
          window.location.href = (opts && opts.href) || '/';
        }, 150);
      }
      el.addEventListener('click', exit);
      el.addEventListener('touchend', exit, { passive: false });
    },

    hostStart: function (el, subOrFn) {
      if (!el) return { update: function () {} };
      el.style.display = 'none';
      function start(e) {
        if (e && e.preventDefault) e.preventDefault();
        var sub = resolve(subOrFn);
        if (sub) sub.send('start_game', {});
      }
      el.addEventListener('click', start);
      el.addEventListener('touchend', start, { passive: false });
      return {
        update: function (isHost, phase) {
          el.style.display = (isHost && (!phase || phase === 'lobby')) ? '' : 'none';
        }
      };
    }
  };
})();
