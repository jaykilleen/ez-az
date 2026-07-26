// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jay Killeen
//
// arcade-shell.js — the shared runtime for everything that WRAPS a game.
//
// ez-az-shell.css owns how the wrapper looks. This file owns how it behaves,
// so a new game only has to write the game itself: the store banner, the
// leaderboard (fetch, render, submit, qualify), score formatting and the
// pause overlay all come from here.
//
// Before this existed, docs/design-system.md documented these as snippets to
// paste into each game, and thirteen games each carried their own slightly
// different copy.
//
// Sits alongside its siblings, which cover different concerns:
//   arcade-cable.js — ActionCable subscribe / exit / host-start (multiplayer)
//   arcade-tv.js    — session codes, phone-to-TV remote input
//   arcade-shell.js — the wrapper around any game, single-player included
//
// Usage:
//   <link rel="stylesheet" href="/ez-az-shell.css">
//   <script src="/arcade-shell.js"></script>
//
//   ArcadeShell.banner();
//   ArcadeShell.pause({ onPause: stopLoop, onResume: startLoop });
//   ArcadeShell.leaderboard('#titleLb', 'late-shift');
//
// Every piece is optional and independent -- take only what you need.
// Plain ES5, no build step, to match the self-contained game files.

(function () {
  'use strict';

  var API = '/api/scores';
  var LS_PREFIX = 'ezaz.scores.';

  // ── Formatting ──────────────────────────────────────────────────────────

  function pad(n, width) {
    var s = String(n);
    while (s.length < width) { s = '0' + s; }
    return s;
  }

  // Time-based games store milliseconds. Matches the shelf's formatter.
  function formatTime(ms) {
    var totalSec = Math.max(0, ms / 1000);
    return pad(Math.floor(totalSec / 60), 2) + ':' +
           pad(Math.floor(totalSec % 60), 2) + '.' +
           pad(Math.floor(ms % 1000), 3);
  }

  // `sort` comes from the server so there is no local copy of GAME_SORT to
  // drift out of date. 'asc' means lowest wins, i.e. a time.
  function format(value, sort) {
    return sort === 'asc' ? formatTime(value) : value + ' pts';
  }

  // ── Local fallback ──────────────────────────────────────────────────────
  // A game should still show a board if the server is unreachable.

  function cacheKey(game) { return LS_PREFIX + game; }

  function readCache(game) {
    try {
      var raw = window.localStorage.getItem(cacheKey(game));
      return raw ? JSON.parse(raw) : null;
    } catch (_) { return null; }
  }

  function writeCache(game, data) {
    try {
      window.localStorage.setItem(cacheKey(game), JSON.stringify({
        scores: data.scores || [], sort: data.sort || 'desc'
      }));
    } catch (_) { /* private mode or quota — not worth failing over */ }
  }

  // ── Data ────────────────────────────────────────────────────────────────

  function normalise(d) {
    return {
      scores:   d.scores    || [],
      sort:     d.sort      || 'desc',
      myBest:   d.my_best   || null,
      myScores: d.my_scores || [],
      player:   d.player    || null,
      offline:  !!d.offline
    };
  }

  function rank(scores, sort) {
    return scores.slice().sort(function (a, b) {
      return sort === 'asc' ? a.value - b.value : b.value - a.value;
    }).slice(0, 10);
  }

  function fetchScores(game) {
    return fetch(API + '?game=' + encodeURIComponent(game), { cache: 'no-store' })
      .then(function (r) { return r.json(); })
      .then(function (d) { writeCache(game, d); return normalise(d); })
      .catch(function () {
        var cached = readCache(game);
        return normalise({
          scores:  cached ? cached.scores : [],
          sort:    cached ? cached.sort : 'desc',
          offline: true
        });
      });
  }

  function submit(game, name, value) {
    return fetch(API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ game: game, name: name, value: value })
    })
      .then(function (r) { return r.json(); })
      .then(function (d) { writeCache(game, d); return normalise(d); })
      .catch(function () {
        // Keep the player's score visible locally even if the post failed.
        var cached = readCache(game) || { scores: [], sort: 'desc' };
        cached.scores = rank(cached.scores.concat([ { name: name, value: value } ]), cached.sort);
        writeCache(game, cached);
        return normalise({ scores: cached.scores, sort: cached.sort, offline: true });
      });
  }

  // Would this value make the board? Boards hold ten, so anything better than
  // the last entry qualifies, as does any score on a board that isn't full.
  function qualifies(value, data) {
    var scores = (data && data.scores) || [];
    if (scores.length < 10) { return true; }
    var worst = scores[scores.length - 1].value;
    return (data.sort === 'asc') ? value < worst : value > worst;
  }

  // ── Rendering ───────────────────────────────────────────────────────────

  function resolve(target) {
    return typeof target === 'string' ? document.querySelector(target) : target;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // Renders the standard HIGH SCORES block using the shared .ezaz-lb-* classes.
  //   opts.highlight — name to mark as the current player's row
  //   opts.title     — heading text (default "HIGH SCORES")
  function renderLeaderboard(target, data, opts) {
    var el = resolve(target);
    if (!el) { return; }
    opts = opts || {};

    var title = '<div class="ezaz-lb-title">' + escapeHtml(opts.title || 'HIGH SCORES') + '</div>';

    if (!data || !data.scores.length) {
      el.innerHTML = title + '<div class="ezaz-lb-empty">No scores yet. Be the first!</div>';
      return;
    }

    var html = title;
    data.scores.slice(0, 10).forEach(function (row, i) {
      var mine = opts.highlight && row.name === opts.highlight ? ' highlight' : '';
      html += '<div class="ezaz-lb-row' + mine + '">' +
                '<span>#' + (i + 1) + ' ' + escapeHtml(row.name) + '</span>' +
                '<span>' + escapeHtml(format(row.value, data.sort)) + '</span>' +
              '</div>';
    });
    el.innerHTML = html;
  }

  // Fetch and render in one call -- the common case on a title screen.
  // Resolves with the data so the caller can keep it for `qualifies`.
  function leaderboard(target, game, opts) {
    return fetchScores(game).then(function (data) {
      renderLeaderboard(target, data, opts);
      return data;
    });
  }

  // ── Store banner ────────────────────────────────────────────────────────

  function banner() {
    if (document.querySelector('.ezaz-store-banner')) { return; }
    var bar = document.createElement('div');
    bar.className = 'ezaz-store-banner';
    bar.innerHTML = '<a href="/">EZ-AZ</a>';
    document.body.insertBefore(bar, document.body.firstChild);
  }

  // ── Pause overlay ───────────────────────────────────────────────────────
  //
  // Escape pauses, showing Resume and Quit to Store, per the standard game
  // features in CLAUDE.md.
  //   opts.onPause / opts.onResume — stop and restart the game loop
  //   opts.enabled — called before pausing; return false to ignore Escape,
  //                  e.g. while on the title screen or already game over

  function pause(opts) {
    opts = opts || {};
    var paused = false;

    var overlay = document.createElement('div');
    overlay.className = 'ezaz-pause';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-label', 'Paused');
    overlay.innerHTML =
      '<div class="ezaz-pause-inner">' +
        '<div class="ezaz-pause-title">PAUSED</div>' +
        '<button class="ezaz-btn-primary" data-ezaz-resume>RESUME</button>' +
        '<a href="/" class="ezaz-btn-outline">QUIT TO STORE</a>' +
      '</div>';
    document.body.appendChild(overlay);

    function show() {
      if (paused) { return; }
      if (opts.enabled && opts.enabled() === false) { return; }
      paused = true;
      overlay.classList.add('open');
      if (opts.onPause) { opts.onPause(); }
    }

    function hide() {
      if (!paused) { return; }
      paused = false;
      overlay.classList.remove('open');
      if (opts.onResume) { opts.onResume(); }
    }

    overlay.querySelector('[data-ezaz-resume]').addEventListener('click', hide);

    document.addEventListener('keydown', function (e) {
      if (e.key !== 'Escape' && e.keyCode !== 27) { return; }
      e.preventDefault();
      if (paused) { hide(); } else { show(); }
    });

    return { show: show, hide: hide, isPaused: function () { return paused; } };
  }

  window.ArcadeShell = {
    banner: banner,
    pause: pause,
    leaderboard: leaderboard,
    renderLeaderboard: renderLeaderboard,
    fetchScores: fetchScores,
    submit: submit,
    qualifies: qualifies,
    format: format,
    formatTime: formatTime
  };
})();
