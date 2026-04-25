if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
  var bar = document.createElement('div');
  bar.id = 'az-dev-bar';
  bar.textContent = '🦕 DEV MODE — localhost:' + location.port + ' (not production, rawr)';
  bar.style.cssText = [
    'position:fixed', 'top:0', 'left:0', 'right:0', 'z-index:99999',
    'background:#ff6b00', 'color:#fff', 'font-family:monospace',
    'font-size:11px', 'text-align:center', 'padding:3px 0',
    'letter-spacing:0.05em', 'pointer-events:none'
  ].join(';');
  document.body.appendChild(bar);
  document.body.style.marginTop = '22px';
}
