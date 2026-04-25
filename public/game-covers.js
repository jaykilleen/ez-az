// EZ-AZ Game Cover Art
// Canvas cover art drawing functions for each game box.
// Each IIFE references a canvas by hardcoded ID matching the store shelf.

// Draw the Space Dodge cover art on the canvas
(function () {
  const canvas = document.getElementById('spaceDodgeCover');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const H = canvas.height;

  // Space background
  const grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#0b0b2a');
  grad.addColorStop(0.5, '#1a0a2e');
  grad.addColorStop(1, '#0b0b2a');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);

  // Stars
  for (let i = 0; i < 60; i++) {
    const x = Math.random() * W;
    const y = Math.random() * H;
    const r = Math.random() * 1.5 + 0.3;
    const alpha = Math.random() * 0.7 + 0.3;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(255, 255, 255, ${alpha})`;
    ctx.fill();
  }

  // Planet in background
  ctx.beginPath();
  ctx.arc(160, 60, 30, 0, Math.PI * 2);
  const planetGrad = ctx.createRadialGradient(155, 55, 5, 160, 60, 30);
  planetGrad.addColorStop(0, '#4a6fff');
  planetGrad.addColorStop(1, '#1a1a4a');
  ctx.fillStyle = planetGrad;
  ctx.fill();

  // Planet ring
  ctx.beginPath();
  ctx.ellipse(160, 60, 44, 10, -0.2, 0, Math.PI * 2);
  ctx.strokeStyle = 'rgba(100, 150, 255, 0.4)';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Ship 1 (Player 1 - blue)
  function drawShip(x, y, color, glowColor) {
    // Glow
    ctx.shadowColor = glowColor;
    ctx.shadowBlur = 15;

    ctx.beginPath();
    ctx.moveTo(x, y - 16);
    ctx.lineTo(x - 12, y + 12);
    ctx.lineTo(x, y + 6);
    ctx.lineTo(x + 12, y + 12);
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();

    // Cockpit
    ctx.beginPath();
    ctx.arc(x, y - 4, 4, 0, Math.PI * 2);
    ctx.fillStyle = glowColor;
    ctx.fill();

    // Engine flame
    ctx.shadowBlur = 0;
    ctx.beginPath();
    ctx.moveTo(x - 5, y + 12);
    ctx.lineTo(x, y + 22);
    ctx.lineTo(x + 5, y + 12);
    ctx.fillStyle = '#ff8800';
    ctx.fill();

    ctx.shadowBlur = 0;
    ctx.shadowColor = 'transparent';
  }

  drawShip(80, 190, '#4488ff', '#66aaff');
  drawShip(140, 200, '#ff8844', '#ffaa66');

  // Laser beams
  ctx.shadowColor = '#ff4444';
  ctx.shadowBlur = 6;
  ctx.strokeStyle = '#ff4444';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(80, 174);
  ctx.lineTo(75, 130);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(140, 184);
  ctx.lineTo(145, 140);
  ctx.stroke();
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Asteroids
  function drawAsteroid(x, y, r) {
    ctx.beginPath();
    for (let i = 0; i < 8; i++) {
      const angle = (i / 8) * Math.PI * 2;
      const jitter = r * (0.7 + Math.random() * 0.5);
      const px = x + Math.cos(angle) * jitter;
      const py = y + Math.sin(angle) * jitter;
      if (i === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fillStyle = '#555';
    ctx.fill();
    ctx.strokeStyle = '#777';
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  drawAsteroid(40, 120, 12);
  drawAsteroid(180, 130, 9);
  drawAsteroid(110, 100, 7);

  // Explosion / power-up glow
  ctx.beginPath();
  ctx.arc(40, 120, 16, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(255, 100, 0, 0.15)';
  ctx.fill();

  // Title text
  ctx.shadowColor = '#ff6ec7';
  ctx.shadowBlur = 10;
  ctx.font = 'bold 18px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#fff';
  ctx.fillText('SPACE', W / 2, H - 48);
  ctx.fillText('DODGE', W / 2, H - 24);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#ffe44d';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#ffe44d';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();

// Draw the Bloom cover art on the canvas
(function () {
  const canvas = document.getElementById('bloomCover');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const H = canvas.height;

  // Dark grey landscape background
  const grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#1a1a1a');
  grad.addColorStop(0.6, '#222222');
  grad.addColorStop(1, '#181818');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);

  // Grey hills in background
  ctx.beginPath();
  ctx.moveTo(0, 180);
  ctx.quadraticCurveTo(60, 140, 120, 170);
  ctx.quadraticCurveTo(180, 200, 220, 180);
  ctx.lineTo(220, H);
  ctx.lineTo(0, H);
  ctx.fillStyle = '#252525';
  ctx.fill();

  // Grey ground
  ctx.fillStyle = '#222';
  ctx.fillRect(0, 200, W, H - 200);

  // Grey trees
  for (let i = 0; i < 5; i++) {
    const tx = 20 + i * 45;
    const ty = 140 + (i % 2) * 20;
    ctx.fillStyle = '#2a2a2a';
    ctx.fillRect(tx + 6, ty + 15, 6, 12);
    ctx.beginPath();
    ctx.arc(tx + 9, ty + 10, 12, 0, Math.PI * 2);
    ctx.fillStyle = '#2d2d2d';
    ctx.fill();
  }

  // Glowing heart in the centre
  const hx = W / 2;
  const hy = 130;

  // Colour bloom radius from heart
  const bloomR = 70;
  const bloomGrad = ctx.createRadialGradient(hx, hy, 0, hx, hy, bloomR);
  bloomGrad.addColorStop(0, 'rgba(90, 140, 50, 0.4)');
  bloomGrad.addColorStop(0.5, 'rgba(60, 100, 30, 0.2)');
  bloomGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');
  ctx.fillStyle = bloomGrad;
  ctx.beginPath();
  ctx.arc(hx, hy, bloomR, 0, Math.PI * 2);
  ctx.fill();

  // Heart glow
  ctx.beginPath();
  ctx.arc(hx, hy, 18, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(255, 80, 128, 0.2)';
  ctx.fill();
  ctx.beginPath();
  ctx.arc(hx, hy, 10, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(255, 80, 128, 0.3)';
  ctx.fill();

  // Heart shape
  ctx.save();
  ctx.translate(hx, hy);
  ctx.beginPath();
  ctx.moveTo(0, 5);
  ctx.bezierCurveTo(-9, -4, -15, -11, -9, -15);
  ctx.bezierCurveTo(-3, -19, 0, -13, 0, -9);
  ctx.bezierCurveTo(0, -13, 3, -19, 9, -15);
  ctx.bezierCurveTo(15, -11, 9, -4, 0, 5);
  ctx.fillStyle = '#ff5080';
  ctx.fill();
  ctx.restore();

  // Small Az in centre bottom
  const ax = W / 2;
  const ay = 195;

  // Az body
  ctx.fillStyle = '#00cc88';
  ctx.fillRect(ax - 5, ay, 10, 12);
  // Belly
  ctx.fillStyle = '#66eebb';
  ctx.fillRect(ax - 3, ay + 2, 6, 7);
  // Head
  ctx.beginPath();
  ctx.arc(ax, ay - 4, 7, 0, Math.PI * 2);
  ctx.fillStyle = '#00cc88';
  ctx.fill();
  // Spikes
  ctx.fillStyle = '#00aa66';
  for (let s = -1; s <= 1; s++) {
    ctx.beginPath();
    ctx.moveTo(ax + s * 4 - 1.5, ay - 9);
    ctx.lineTo(ax + s * 4, ay - 14);
    ctx.lineTo(ax + s * 4 + 1.5, ay - 9);
    ctx.fill();
  }
  // Eyes
  ctx.fillStyle = 'white';
  ctx.beginPath(); ctx.arc(ax - 3, ay - 5, 2, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(ax + 3, ay - 5, 2, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#111';
  ctx.beginPath(); ctx.arc(ax - 2.5, ay - 4.5, 1, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(ax + 3.5, ay - 4.5, 1, 0, Math.PI * 2); ctx.fill();
  // Feet
  ctx.fillStyle = '#00bb77';
  ctx.fillRect(ax - 5, ay + 12, 4, 3);
  ctx.fillRect(ax + 1, ay + 12, 4, 3);

  // Title text
  ctx.shadowColor = '#00cc88';
  ctx.shadowBlur = 10;
  ctx.font = 'bold 22px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#fff';
  ctx.fillText('BLOOM', W / 2, H - 28);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#ffe44d';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#ffe44d';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();

// Draw the Cat vs Mouse cover art on the canvas
(function () {
  const canvas = document.getElementById('catMouseCover');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const H = canvas.height;

  // Warm dark background
  const grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#1a1008');
  grad.addColorStop(0.5, '#221a0e');
  grad.addColorStop(1, '#1a1008');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);

  // Floor line
  ctx.strokeStyle = '#3a2a15';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(0, 200);
  ctx.lineTo(W, 200);
  ctx.stroke();

  // Pegs
  const pegs = [{x: 50, y: 80}, {x: 170, y: 70}, {x: 180, y: 160}, {x: 60, y: 150}];
  pegs.forEach(function(p) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, 6, 0, Math.PI * 2);
    ctx.fillStyle = '#8B7355';
    ctx.fill();
    ctx.strokeStyle = '#f0c040';
    ctx.lineWidth = 2;
    ctx.stroke();
  });

  // Rope between pegs
  ctx.beginPath();
  ctx.moveTo(pegs[0].x, pegs[0].y);
  for (let i = 1; i < pegs.length; i++) {
    ctx.lineTo(pegs[i].x, pegs[i].y);
  }
  ctx.strokeStyle = '#c8a050';
  ctx.lineWidth = 2.5;
  ctx.setLineDash([6, 4]);
  ctx.stroke();
  ctx.setLineDash([]);

  // Cat (left side)
  const cx = 70, cy = 185;
  // Body
  ctx.fillStyle = '#e8a030';
  ctx.beginPath();
  ctx.ellipse(cx, cy, 14, 10, 0, 0, Math.PI * 2);
  ctx.fill();
  // Head
  ctx.beginPath();
  ctx.arc(cx - 10, cy - 12, 10, 0, Math.PI * 2);
  ctx.fill();
  // Ears
  ctx.fillStyle = '#d08820';
  ctx.beginPath();
  ctx.moveTo(cx - 18, cy - 18);
  ctx.lineTo(cx - 14, cy - 28);
  ctx.lineTo(cx - 10, cy - 18);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(cx - 6, cy - 18);
  ctx.lineTo(cx - 2, cy - 28);
  ctx.lineTo(cx + 2, cy - 18);
  ctx.fill();
  // Eyes
  ctx.fillStyle = '#fff';
  ctx.beginPath(); ctx.arc(cx - 13, cy - 14, 3, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(cx - 6, cy - 14, 3, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#111';
  ctx.beginPath(); ctx.arc(cx - 12, cy - 14, 1.5, 0, Math.PI * 2); ctx.fill();
  ctx.beginPath(); ctx.arc(cx - 5, cy - 14, 1.5, 0, Math.PI * 2); ctx.fill();
  // Nose
  ctx.fillStyle = '#ff8899';
  ctx.beginPath();
  ctx.moveTo(cx - 10, cy - 9);
  ctx.lineTo(cx - 8, cy - 7);
  ctx.lineTo(cx - 12, cy - 7);
  ctx.fill();
  // Tail
  ctx.strokeStyle = '#e8a030';
  ctx.lineWidth = 3;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.moveTo(cx + 14, cy);
  ctx.quadraticCurveTo(cx + 28, cy - 20, cx + 22, cy - 30);
  ctx.stroke();

  // Mouse (right side)
  const mx = 155, my = 188;
  // Body
  ctx.fillStyle = '#999';
  ctx.beginPath();
  ctx.ellipse(mx, my, 8, 6, 0, 0, Math.PI * 2);
  ctx.fill();
  // Head
  ctx.beginPath();
  ctx.arc(mx + 8, my - 3, 6, 0, Math.PI * 2);
  ctx.fill();
  // Ear
  ctx.fillStyle = '#bbb';
  ctx.beginPath();
  ctx.arc(mx + 10, my - 9, 4, 0, Math.PI * 2);
  ctx.fill();
  // Eye
  ctx.fillStyle = '#111';
  ctx.beginPath();
  ctx.arc(mx + 11, my - 4, 1.5, 0, Math.PI * 2);
  ctx.fill();
  // Tail
  ctx.strokeStyle = '#888';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(mx - 8, my);
  ctx.quadraticCurveTo(mx - 18, my + 8, mx - 22, my + 2);
  ctx.stroke();

  // Title text
  ctx.shadowColor = '#f0c040';
  ctx.shadowBlur = 10;
  ctx.font = 'bold 18px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#fff';
  ctx.fillText('CAT VS', W / 2, H - 48);
  ctx.fillText('MOUSE', W / 2, H - 24);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#ffe44d';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#ffe44d';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();

// Draw the Dodgeball cover art
(function () {
  const canvas = document.getElementById('dodgeballCover');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const H = canvas.height;

  // Gymnasium floor background
  for (let y = 0; y < H; y += 8) {
    for (let x = 0; x < W; x += 20) {
      const row = Math.floor(y / 8);
      const offsetX = (row % 2) * 10;
      const shade = ((Math.floor((x + offsetX) / 20) + row) % 2 === 0) ? '#6B4914' : '#805919';
      ctx.fillStyle = shade;
      ctx.fillRect(x, y, 20, 8);
    }
  }

  // Centre line
  ctx.strokeStyle = '#e44';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(0, H * 0.48);
  ctx.lineTo(W, H * 0.48);
  ctx.stroke();

  // Court boundary
  ctx.strokeStyle = '#ddd';
  ctx.lineWidth = 2;
  ctx.strokeRect(10, 30, W - 20, H - 80);

  // Centre circle
  ctx.beginPath();
  ctx.arc(W / 2, H * 0.48, 30, 0, Math.PI * 2);
  ctx.strokeStyle = '#e44';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Red player (top)
  function drawPlayer(x, y, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(x, y, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#fdb';
    ctx.beginPath();
    ctx.arc(x, y - 4, 5, 0, Math.PI * 2);
    ctx.fill();
  }

  drawPlayer(80, 90, '#e44');
  drawPlayer(150, 75, '#e44');
  drawPlayer(70, 170, '#48f');
  drawPlayer(160, 185, '#48f');

  // Balls
  function drawBall(x, y) {
    ctx.fillStyle = '#f80';
    ctx.beginPath();
    ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.beginPath();
    ctx.arc(x - 1.5, y - 1.5, 2, 0, Math.PI * 2);
    ctx.fill();
  }

  drawBall(110, H * 0.48);
  drawBall(W / 2, H * 0.48 - 8);
  drawBall(160, H * 0.48 + 5);

  // Speed lines from a thrown ball
  ctx.strokeStyle = 'rgba(255,136,0,0.5)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(160, H * 0.48 + 5);
  ctx.lineTo(150, 80);
  ctx.stroke();

  // Referee
  ctx.fillStyle = '#222';
  ctx.fillRect(W / 2 - 6, H * 0.48 - 6, 12, 12);
  ctx.fillStyle = '#ddd';
  ctx.fillRect(W / 2 - 4, H * 0.48 - 4, 8, 2);
  ctx.fillRect(W / 2 - 4, H * 0.48, 8, 2);

  // "1988" big text
  ctx.save();
  ctx.font = 'bold 40px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(255,228,77,0.15)';
  ctx.fillText('1988', W / 2, H / 2 + 15);
  ctx.restore();

  // Title text
  ctx.shadowColor = '#e44';
  ctx.shadowBlur = 10;
  ctx.font = 'bold 14px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#fff';
  ctx.fillText('DODGEBALL', W / 2, H - 38);
  ctx.font = 'bold 9px "Press Start 2P", monospace';
  ctx.fillStyle = '#ffe44d';
  ctx.fillText('WORLD CHAMP', W / 2, H - 20);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#ffe44d';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#ffe44d';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();

// Draw the Descent cover art
(function () {
  const canvas = document.getElementById('descentCover');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const W = canvas.width;
  const H = canvas.height;

  // Dark background
  const grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#0a0a0a');
  grad.addColorStop(0.5, '#111118');
  grad.addColorStop(1, '#000');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);

  // Maze walls
  ctx.strokeStyle = '#3a3a4a';
  ctx.lineWidth = 2;
  // Procedural mini-maze pattern
  const cs = 22;
  const seed = [1,0,1,1,0,1,0,0,1,1,0,1,1,0,0,1,0,1,1,0,1,0,1,1,0,0,1,0,1,1];
  let si = 0;
  for (let y = 30; y < H - 60; y += cs) {
    for (let x = 10; x < W - 10; x += cs) {
      const s = seed[si % seed.length];
      si++;
      if (s) {
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x, y + cs);
        ctx.stroke();
      } else {
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + cs, y);
        ctx.stroke();
      }
    }
  }

  // Flashlight cone from centre
  const cx = W / 2, cy = H * 0.45;
  const coneGrad = ctx.createRadialGradient(cx, cy, 10, cx, cy, 120);
  coneGrad.addColorStop(0, 'rgba(255, 240, 200, 0.25)');
  coneGrad.addColorStop(0.6, 'rgba(255, 240, 200, 0.08)');
  coneGrad.addColorStop(1, 'rgba(255, 240, 200, 0)');
  ctx.fillStyle = coneGrad;
  ctx.beginPath();
  ctx.moveTo(cx, cy);
  const angle = -Math.PI / 2;
  const spread = Math.PI / 5;
  ctx.lineTo(cx + Math.cos(angle - spread) * 140, cy + Math.sin(angle - spread) * 140);
  ctx.lineTo(cx + Math.cos(angle + spread) * 140, cy + Math.sin(angle + spread) * 140);
  ctx.closePath();
  ctx.fill();

  // Character silhouette (small circle)
  ctx.fillStyle = '#a0a0a0';
  ctx.beginPath();
  ctx.arc(cx, cy, 8, 0, Math.PI * 2);
  ctx.fill();
  // Eyes
  ctx.fillStyle = '#fff';
  ctx.beginPath();
  ctx.arc(cx - 2, cy - 3, 2, 0, Math.PI * 2);
  ctx.arc(cx + 2, cy - 3, 2, 0, Math.PI * 2);
  ctx.fill();

  // Breadcrumbs
  const crumbs = [[80, 100], [160, 70], [50, 180], [180, 160], [100, 220], [140, 250]];
  crumbs.forEach(function(p) {
    ctx.fillStyle = 'rgba(200, 180, 150, 0.3)';
    ctx.beginPath();
    ctx.arc(p[0], p[1], 2.5, 0, Math.PI * 2);
    ctx.fill();
  });

  // Guitar glow at bottom
  ctx.fillStyle = 'rgba(255, 228, 77, 0.12)';
  ctx.beginPath();
  ctx.arc(W / 2, H - 70, 20, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(255, 228, 77, 0.06)';
  ctx.beginPath();
  ctx.arc(W / 2, H - 70, 35, 0, Math.PI * 2);
  ctx.fill();

  // Title text
  ctx.shadowColor = '#888';
  ctx.shadowBlur = 8;
  ctx.font = 'bold 16px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#aaa';
  ctx.fillText('DESCENT', W / 2, H - 28);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#888';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#888';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();

// Draw the Corrupted cover art
(function () {
  var canvas = document.getElementById('corruptedCover');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var W = canvas.width;
  var H = canvas.height;

  // Dark purple corridor background
  var grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#0a001a');
  grad.addColorStop(0.5, '#150030');
  grad.addColorStop(1, '#0a001a');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);

  // First-person corridor walls (perspective lines)
  ctx.strokeStyle = '#3a1858';
  ctx.lineWidth = 2;
  // Left wall
  ctx.beginPath();
  ctx.moveTo(0, 0); ctx.lineTo(60, 60);
  ctx.moveTo(0, H - 60); ctx.lineTo(60, H - 120);
  ctx.moveTo(0, 40); ctx.lineTo(50, 80);
  ctx.stroke();
  // Right wall
  ctx.beginPath();
  ctx.moveTo(W, 0); ctx.lineTo(W - 60, 60);
  ctx.moveTo(W, H - 60); ctx.lineTo(W - 60, H - 120);
  ctx.moveTo(W, 40); ctx.lineTo(W - 50, 80);
  ctx.stroke();

  // Corridor walls solid
  ctx.fillStyle = '#1a0830';
  ctx.beginPath();
  ctx.moveTo(0, 0); ctx.lineTo(60, 50); ctx.lineTo(60, H - 110); ctx.lineTo(0, H - 50);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(W, 0); ctx.lineTo(W - 60, 50); ctx.lineTo(W - 60, H - 110); ctx.lineTo(W, H - 50);
  ctx.fill();

  // Floor
  ctx.fillStyle = '#100020';
  ctx.beginPath();
  ctx.moveTo(60, H - 110); ctx.lineTo(W - 60, H - 110);
  ctx.lineTo(W, H - 50); ctx.lineTo(0, H - 50);
  ctx.fill();

  // Ceiling
  ctx.fillStyle = '#080010';
  ctx.beginPath();
  ctx.moveTo(60, 50); ctx.lineTo(W - 60, 50);
  ctx.lineTo(W, 0); ctx.lineTo(0, 0);
  ctx.fill();

  // Zombie silhouette in corridor
  var zx = W / 2, zy = 105;
  // Body
  ctx.fillStyle = '#2a1040';
  ctx.fillRect(zx - 12, zy - 30, 24, 40);
  // Head
  ctx.beginPath();
  ctx.arc(zx, zy - 36, 10, 0, Math.PI * 2);
  ctx.fill();
  // Arms reaching forward
  ctx.fillRect(zx - 22, zy - 20, 12, 6);
  ctx.fillRect(zx + 10, zy - 18, 12, 6);
  // Glowing red eyes
  ctx.fillStyle = '#ff0000';
  ctx.shadowColor = '#ff0000';
  ctx.shadowBlur = 8;
  ctx.beginPath();
  ctx.arc(zx - 4, zy - 38, 2, 0, Math.PI * 2);
  ctx.arc(zx + 4, zy - 38, 2, 0, Math.PI * 2);
  ctx.fill();
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Sword in foreground (player weapon)
  ctx.save();
  ctx.translate(W * 0.7, H - 100);
  ctx.rotate(-0.3);
  // Blade
  ctx.fillStyle = '#aaa';
  ctx.fillRect(-3, -55, 6, 45);
  // Crossguard
  ctx.fillStyle = '#aa8800';
  ctx.fillRect(-10, -12, 20, 4);
  // Handle
  ctx.fillStyle = '#553300';
  ctx.fillRect(-3, -10, 6, 14);
  ctx.restore();

  // Purple corruption glow
  var corruptGrad = ctx.createRadialGradient(W/2, H/2, 20, W/2, H/2, 130);
  corruptGrad.addColorStop(0, 'rgba(180, 77, 255, 0.1)');
  corruptGrad.addColorStop(1, 'rgba(180, 77, 255, 0)');
  ctx.fillStyle = corruptGrad;
  ctx.fillRect(0, 0, W, H);

  // Title text
  ctx.shadowColor = '#b44dff';
  ctx.shadowBlur = 12;
  ctx.font = 'bold 14px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.fillStyle = '#fff';
  ctx.fillText('CORRUPTED', W / 2, H - 28);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#b44dff';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#b44dff';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();

// Draw the Az's Cipher cover art
(function () {
  var canvas = document.getElementById('cipherCover');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var W = canvas.width, H = canvas.height;

  // Background
  var bg = ctx.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#05050f');
  bg.addColorStop(1, '#0a0a18');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // Scattered cipher letters in background
  var alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  ctx.font = 'bold 11px Courier New';
  for (var i = 0; i < 40; i++) {
    var x = 8 + (i % 8) * 26 + (Math.floor(i / 8) % 2) * 12;
    var y = 18 + Math.floor(i / 8) * 22;
    var opacity = 0.08 + (i % 5) * 0.04;
    ctx.fillStyle = 'rgba(204,136,68,' + opacity + ')';
    ctx.textAlign = 'center';
    ctx.fillText(alpha[i % 26], x, y);
  }

  // Padlock body
  var lx = W / 2, ly = H / 2 + 10;
  // Shackle (arc)
  ctx.beginPath();
  ctx.arc(lx, ly - 28, 22, Math.PI, 0, false);
  ctx.strokeStyle = '#cc8844';
  ctx.lineWidth = 6;
  ctx.stroke();

  // Lock body
  ctx.beginPath();
  var bw = 52, bh = 42, br = 6;
  var bx = lx - bw / 2, by = ly - 10;
  ctx.moveTo(bx + br, by);
  ctx.lineTo(bx + bw - br, by);
  ctx.arcTo(bx + bw, by, bx + bw, by + br, br);
  ctx.lineTo(bx + bw, by + bh - br);
  ctx.arcTo(bx + bw, by + bh, bx + bw - br, by + bh, br);
  ctx.lineTo(bx + br, by + bh);
  ctx.arcTo(bx, by + bh, bx, by + bh - br, br);
  ctx.lineTo(bx, by + br);
  ctx.arcTo(bx, by, bx + br, by, br);
  ctx.closePath();
  ctx.fillStyle = '#1a1200';
  ctx.fill();
  ctx.strokeStyle = '#cc8844';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Keyhole
  ctx.beginPath();
  ctx.arc(lx, by + 16, 7, 0, Math.PI * 2);
  ctx.fillStyle = '#cc8844';
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(lx - 5, by + 22);
  ctx.lineTo(lx + 5, by + 22);
  ctx.lineTo(lx + 3, by + 34);
  ctx.lineTo(lx - 3, by + 34);
  ctx.closePath();
  ctx.fill();

  // Glow around lock
  ctx.shadowColor = '#cc8844';
  ctx.shadowBlur = 18;
  ctx.strokeStyle = '#cc884455';
  ctx.lineWidth = 1;
  ctx.strokeRect(bx - 4, by - 4, bw + 8, bh + 8);
  ctx.shadowBlur = 0;

  // Title
  ctx.fillStyle = '#00ff88';
  ctx.font = 'bold 13px Courier New';
  ctx.textAlign = 'center';
  ctx.shadowColor = '#00ff88';
  ctx.shadowBlur = 8;
  ctx.fillText("CIPHER", W / 2, H - 36);
  ctx.shadowBlur = 0;

  ctx.fillStyle = '#334455';
  ctx.font = '9px Courier New';
  ctx.fillText('CRACK THE CODE', W / 2, H - 20);
})();

// Draw the Trivia cover art on the canvas
(function () {
  var canvas = document.getElementById('triviaCover');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var W = canvas.width;
  var H = canvas.height;

  // Dark game show background
  var bg = ctx.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#080818');
  bg.addColorStop(0.5, '#0d0d24');
  bg.addColorStop(1, '#080818');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // Spotlight rays from centre top
  ctx.save();
  var rayColours = ['rgba(255,220,50,0.04)', 'rgba(255,100,200,0.04)', 'rgba(50,220,255,0.04)', 'rgba(100,255,150,0.04)'];
  for (var r = 0; r < 8; r++) {
    var rayAngle = (r / 8) * Math.PI * 2 - Math.PI / 2;
    ctx.beginPath();
    ctx.moveTo(W / 2, H * 0.38);
    ctx.lineTo(
      W / 2 + Math.cos(rayAngle - 0.15) * 200,
      H * 0.38 + Math.sin(rayAngle - 0.15) * 200
    );
    ctx.lineTo(
      W / 2 + Math.cos(rayAngle + 0.15) * 200,
      H * 0.38 + Math.sin(rayAngle + 0.15) * 200
    );
    ctx.closePath();
    ctx.fillStyle = rayColours[r % rayColours.length];
    ctx.fill();
  }
  ctx.restore();

  // Outer glow ring
  var outerGlow = ctx.createRadialGradient(W / 2, H * 0.38, 30, W / 2, H * 0.38, 80);
  outerGlow.addColorStop(0, 'rgba(255, 220, 50, 0.18)');
  outerGlow.addColorStop(0.5, 'rgba(255, 100, 200, 0.10)');
  outerGlow.addColorStop(1, 'rgba(0, 0, 0, 0)');
  ctx.fillStyle = outerGlow;
  ctx.beginPath();
  ctx.arc(W / 2, H * 0.38, 80, 0, Math.PI * 2);
  ctx.fill();

  // Big glowing "?" in the centre
  ctx.save();
  ctx.shadowColor = '#ffe44d';
  ctx.shadowBlur = 30;
  ctx.font = 'bold 96px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  // Rainbow gradient on the "?"
  var qGrad = ctx.createLinearGradient(W / 2 - 40, H * 0.25, W / 2 + 40, H * 0.5);
  qGrad.addColorStop(0, '#ff6ec7');
  qGrad.addColorStop(0.5, '#00ffc8');
  qGrad.addColorStop(1, '#ffe44d');
  ctx.fillStyle = qGrad;
  ctx.fillText('?', W / 2, H * 0.38);
  ctx.restore();

  // Four player buzzer circles at the bottom
  var buzzers = [
    { x: W * 0.18, colour: '#ff4444', label: '1' },
    { x: W * 0.40, colour: '#4488ff', label: '2' },
    { x: W * 0.62, colour: '#ffaa22', label: '3' },
    { x: W * 0.84, colour: '#44dd66', label: '4' }
  ];
  var buzzerY = H - 72;

  buzzers.forEach(function (b) {
    // Glow
    ctx.beginPath();
    ctx.arc(b.x, buzzerY, 22, 0, Math.PI * 2);
    ctx.fillStyle = b.colour.replace(')', ', 0.25)').replace('rgb', 'rgba');
    ctx.shadowColor = b.colour;
    ctx.shadowBlur = 12;
    ctx.fill();
    ctx.shadowBlur = 0;

    // Circle
    ctx.beginPath();
    ctx.arc(b.x, buzzerY, 16, 0, Math.PI * 2);
    ctx.fillStyle = b.colour;
    ctx.fill();

    // Highlight
    ctx.beginPath();
    ctx.arc(b.x - 4, buzzerY - 5, 5, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.fill();

    // Player number
    ctx.font = 'bold 10px "Press Start 2P", monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#fff';
    ctx.fillText(b.label, b.x, buzzerY);
  });

  // Title text
  ctx.shadowColor = '#ff6ec7';
  ctx.shadowBlur = 12;
  ctx.font = 'bold 14px "Press Start 2P", monospace';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'alphabetic';
  ctx.fillStyle = '#fff';
  ctx.fillText('TRIVIA', W / 2, H - 28);
  ctx.shadowBlur = 0;
  ctx.shadowColor = 'transparent';

  // Rating badge
  ctx.fillStyle = '#ffe44d';
  ctx.font = 'bold 10px "Press Start 2P", monospace';
  ctx.textAlign = 'left';
  ctx.fillText('E', 12, 26);
  ctx.strokeStyle = '#ffe44d';
  ctx.lineWidth = 1.5;
  ctx.strokeRect(6, 12, 20, 20);
})();
