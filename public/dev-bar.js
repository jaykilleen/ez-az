if (location.hostname === 'localhost' || location.hostname === '127.0.0.1') {
  var wrap = document.createElement('div');
  wrap.id = 'az-dev-bar';
  wrap.style.cssText = [
    'position:fixed', 'top:0', 'left:0',
    'width:64px', 'height:64px',
    'overflow:hidden', 'z-index:99999', 'pointer-events:none'
  ].join(';');

  var ribbon = document.createElement('div');
  ribbon.textContent = 'DEV';
  ribbon.style.cssText = [
    'position:absolute', 'top:14px', 'left:-18px',
    'width:80px', 'padding:3px 0',
    'background:#ff6b00', 'color:#fff',
    'font-family:monospace', 'font-size:9px', 'font-weight:bold',
    'text-align:center', 'letter-spacing:0.08em',
    'transform:rotate(-45deg)'
  ].join(';');

  wrap.appendChild(ribbon);
  document.body.appendChild(wrap);
}
