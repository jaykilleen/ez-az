(function () {
  'use strict';

  var SLUG = (function () {
    var m = window.location.pathname.match(/\/games\/([^/]+?)(?:\.html?)?(?:\/.*)?$/);
    return m ? m[1] : null;
  })();

  if (!SLUG) return;

  function buildUI() {
    var banner = document.querySelector('.ezaz-store-banner, .store-banner');
    var btn = document.createElement('button');
    btn.textContent = 'Bug?';
    btn.setAttribute('aria-label', 'Report a bug in this game');
    btn.setAttribute('type', 'button');

    if (banner) {
      var pos = window.getComputedStyle(banner).position;
      if (pos === 'static') banner.style.position = 'relative';
      btn.style.cssText = [
        'position:absolute',
        'right:12px',
        'top:50%',
        'transform:translateY(-50%)',
        'background:transparent',
        'border:1px solid rgba(0,255,200,0.3)',
        'color:#00ffc8',
        'font-family:inherit',
        'font-size:11px',
        'padding:3px 8px',
        'border-radius:4px',
        'cursor:pointer',
        'opacity:0.7',
        'line-height:1',
        'z-index:1001',
      ].join(';');
      banner.appendChild(btn);
    } else {
      btn.style.cssText = [
        'position:fixed',
        'top:8px',
        'right:12px',
        'background:rgba(0,0,0,0.7)',
        'border:1px solid rgba(0,255,200,0.3)',
        'color:#00ffc8',
        'font-family:inherit',
        'font-size:11px',
        'padding:4px 10px',
        'border-radius:4px',
        'cursor:pointer',
        'z-index:9999',
        'line-height:1',
      ].join(';');
      document.body.appendChild(btn);
    }

    btn.addEventListener('click', openModal);
  }

  function openModal() {
    if (document.getElementById('ezaz-bug-overlay')) return;

    var overlay = document.createElement('div');
    overlay.id = 'ezaz-bug-overlay';
    overlay.style.cssText = [
      'position:fixed',
      'inset:0',
      'background:rgba(0,0,0,0.85)',
      'z-index:99999',
      'display:flex',
      'align-items:center',
      'justify-content:center',
      'padding:20px',
      'box-sizing:border-box',
    ].join(';');

    var modal = document.createElement('div');
    modal.style.cssText = [
      'background:#13131f',
      'border:1px solid rgba(0,255,200,0.2)',
      'border-radius:10px',
      'padding:24px',
      'width:100%',
      'max-width:420px',
      'font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif',
      'color:#e0e0e0',
      'box-sizing:border-box',
    ].join(';');

    modal.innerHTML = [
      '<div style="font-family:\'Press Start 2P\',monospace;font-size:12px;color:#ff6ec7;margin-bottom:16px;line-height:1.6">Report a Bug</div>',
      '<div style="font-size:12px;color:#666;margin-bottom:16px">',
      'Game: <span style="color:#aaa">' + SLUG + '</span>',
      '</div>',
      '<textarea id="ezaz-bug-desc"',
      ' placeholder="What went wrong? What were you doing when it happened?"',
      ' maxlength="2000"',
      ' style="width:100%;background:#0a0a12;border:1px solid #2a2a3e;color:#fff;padding:10px;border-radius:6px;font-size:14px;font-family:inherit;min-height:100px;resize:vertical;box-sizing:border-box"',
      '></textarea>',
      '<div id="ezaz-bug-msg" style="font-size:13px;line-height:1.6;margin-top:10px;min-height:20px"></div>',
      '<div style="display:flex;gap:10px;margin-top:16px">',
      '<button id="ezaz-bug-submit" type="button"',
      ' style="flex:1;padding:12px;font-family:\'Press Start 2P\',monospace;font-size:10px;line-height:1.6;background:#00ffc8;color:#0a0a12;border:none;border-radius:6px;cursor:pointer">',
      'Submit',
      '</button>',
      '<button id="ezaz-bug-cancel" type="button"',
      ' style="padding:12px 16px;background:transparent;border:1px solid #333;color:#666;border-radius:6px;cursor:pointer;font-size:13px">',
      'Cancel',
      '</button>',
      '</div>',
    ].join('');

    overlay.appendChild(modal);
    document.body.appendChild(overlay);

    var desc      = document.getElementById('ezaz-bug-desc');
    var msg       = document.getElementById('ezaz-bug-msg');
    var submitBtn = document.getElementById('ezaz-bug-submit');
    var cancelBtn = document.getElementById('ezaz-bug-cancel');

    function close() { overlay.remove(); }

    cancelBtn.addEventListener('click', close);
    overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });

    function showMsg(kind, text) {
      msg.style.color = kind === 'ok' ? '#2ed573' : '#ff4757';
      msg.textContent = text;
    }

    submitBtn.addEventListener('click', function () {
      var text = desc.value.trim();
      if (!text) {
        showMsg('error', 'Describe the bug first.');
        return;
      }

      submitBtn.disabled = true;
      submitBtn.textContent = '...';
      msg.textContent = '';

      var data = new FormData();
      data.append('game_slug', SLUG);
      data.append('description', text);

      fetch('/bugs', {
        method: 'POST',
        headers: { 'Accept': 'application/json' },
        body: data
      })
        .then(function (r) {
          return r.json().then(function (body) { return { ok: r.ok, body: body }; });
        })
        .then(function (res) {
          if (res.ok) {
            showMsg('ok', res.body.message || 'Bug reported! Az will investigate.');
            desc.value = '';
            submitBtn.textContent = 'Sent ✓';
          } else {
            showMsg('error', res.body.error || 'Could not submit. Visit /bugs to try again.');
            submitBtn.disabled = false;
            submitBtn.textContent = 'Submit';
          }
        })
        .catch(function () {
          showMsg('error', 'Could not reach the server. Try again.');
          submitBtn.disabled = false;
          submitBtn.textContent = 'Submit';
        });
    });

    desc.focus();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', buildUI);
  } else {
    buildUI();
  }
})();
