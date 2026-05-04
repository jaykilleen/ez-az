// Letterbox - endless hopper. Az rides his bike up through Gumdale, hopping
// one tile at a time. Cross roads, ride logs across the creek, time the
// train, hit every letterbox you pass. Don't fall behind the morning sun.

(function () {
  var canvas = document.getElementById('game');
  var ctx = canvas.getContext('2d');
  var W = canvas.width = 700;
  var H = canvas.height = 800;
  if (window.EzAzGame) EzAzGame.fitCanvas(canvas);

  // ===== CONSTANTS =====
  var COLS = 14;
  var TILE_W = 50;
  var LANE_H = 64;
  var GUTTER = (W - COLS * TILE_W) / 2; // centre tiles in canvas
  var HOP_FRAMES = 9;
  var INITIAL_LANE = 6; // Az starts here from bottom of map
  var INITIAL_COL = 7;

  // ===== STATE =====
  var state = 'title'; // title | playing | paused | end
  var lanes = {};       // laneIndex -> lane object
  var az = null;
  var camera = 0;       // float, bottom-most visible lane index
  var score = 0;
  var letterboxesHit = 0;
  var coffeesGrabbed = 0;
  var maxLane = 0;
  var deathReason = '';
  var keys = {};
  var hopQueue = [];
  var frame = 0;
  var finalScore = 0;
  var sunTint = 0;

  function reset() {
    lanes = {};
    az = {
      lane: INITIAL_LANE,
      col: INITIAL_COL,
      x: tileX(INITIAL_COL) + TILE_W / 2,
      hop: null,
      facing: 'up',
      onLog: null,
      dead: false
    };
    camera = 0;
    score = 0;
    letterboxesHit = 0;
    coffeesGrabbed = 0;
    maxLane = INITIAL_LANE;
    deathReason = '';
    hopQueue = [];
    sunTint = 0;
    // Pre-generate from lane 0 to a buffer above Az
    for (var i = 0; i < INITIAL_LANE + 20; i++) ensureLane(i);
  }

  function tileX(col) { return GUTTER + col * TILE_W; }
  function laneScreenY(laneIdx) { return H - (laneIdx - camera + 1) * LANE_H; }

  // ===== LANE GENERATION =====
  var lastLaneTypes = [];
  function pickLaneType(laneIdx) {
    if (laneIdx < 4) return 'grass'; // safe runway at start
    var weights = [
      ['grass', 35],
      ['road', 28],
      ['footpath', 14],
      ['creek', 10],
      ['tracks', 5],
      ['road_fast', 8]
    ];
    // Avoid 3 of the same type in a row, and avoid creek-after-creek
    if (lastLaneTypes.length >= 2 && lastLaneTypes[lastLaneTypes.length - 1] === lastLaneTypes[lastLaneTypes.length - 2]) {
      weights = weights.filter(function (w) { return w[0] !== lastLaneTypes[lastLaneTypes.length - 1]; });
    }
    var total = 0;
    weights.forEach(function (w) { total += w[1]; });
    var r = Math.random() * total;
    var t = weights[0][0];
    for (var i = 0; i < weights.length; i++) {
      if (r < weights[i][1]) { t = weights[i][0]; break; }
      r -= weights[i][1];
    }
    return t;
  }

  function ensureLane(idx) {
    if (lanes[idx]) return lanes[idx];
    var type = pickLaneType(idx);
    var lane = { idx: idx, type: type };
    var difficulty = Math.min(1, idx / 200);
    if (type === 'grass') {
      lane.letterboxes = [];
      lane.coffees = [];
      lane.papers = [];
      lane.decorations = [];
      // 60% chance of letterbox
      if (idx >= 4 && Math.random() < 0.7) {
        lane.letterboxes.push({ col: 1 + Math.floor(Math.random() * (COLS - 2)), hit: false, flag: true });
      }
      if (Math.random() < 0.25) {
        lane.coffees.push({ col: 1 + Math.floor(Math.random() * (COLS - 2)), taken: false });
      }
      // Decorations (trees) on edges only — don't block playable tiles
      var blockedCols = {};
      lane.letterboxes.forEach(function (m) { blockedCols[m.col] = true; });
      lane.coffees.forEach(function (c) { blockedCols[c.col] = true; });
      // Trees on outer columns only (0 and COLS-1)
      if (Math.random() < 0.4) lane.decorations.push({ col: 0, kind: 'tree' });
      if (Math.random() < 0.4) lane.decorations.push({ col: COLS - 1, kind: 'tree' });
    } else if (type === 'road' || type === 'road_fast') {
      lane.dir = Math.random() < 0.5 ? -1 : 1;
      lane.cars = [];
      var fast = type === 'road_fast';
      var baseSpeed = fast ? 2.6 : 1.5;
      var speed = baseSpeed + Math.random() * (fast ? 1.6 : 1.0) + difficulty * 0.8;
      var gap = (fast ? 280 : 200) + Math.random() * 200;
      var startX = lane.dir === 1 ? -100 - Math.random() * gap : W + 100 + Math.random() * gap;
      var endX = lane.dir === 1 ? W + 200 : -200;
      lane.spawnX = startX;
      lane.endX = endX;
      lane.gap = gap;
      lane.spawnTimer = Math.floor(Math.random() * 80);
      lane.speed = speed * lane.dir;
      lane.fast = fast;
      // Pre-spawn 1-2 cars at random positions across the lane
      var preCount = 1 + Math.floor(Math.random() * 2);
      for (var pi = 0; pi < preCount; pi++) {
        lane.cars.push({
          x: lane.dir === 1 ? -100 + (W + 200) * Math.random() : -100 + (W + 200) * Math.random(),
          palette: Math.floor(Math.random() * 6)
        });
      }
    } else if (type === 'footpath') {
      lane.dir = Math.random() < 0.5 ? -1 : 1;
      lane.kids = [];
      lane.speed = (0.8 + Math.random() * 0.6 + difficulty * 0.5) * lane.dir;
      lane.gap = 140 + Math.random() * 80;
      lane.spawnTimer = 0;
      var preK = 1 + Math.floor(Math.random() * 2);
      for (var ki = 0; ki < preK; ki++) {
        lane.kids.push({
          x: -100 + (W + 200) * Math.random(),
          variant: Math.floor(Math.random() * 3)
        });
      }
    } else if (type === 'creek') {
      lane.dir = Math.random() < 0.5 ? -1 : 1;
      lane.logs = [];
      lane.speed = (0.7 + Math.random() * 0.6) * lane.dir;
      // Pre-spawn 2-3 logs spread out
      var lc = 2 + Math.floor(Math.random() * 2);
      for (var li = 0; li < lc; li++) {
        lane.logs.push({
          x: (W * li / lc) + Math.random() * 80,
          w: TILE_W * (1 + Math.floor(Math.random() * 3))
        });
      }
      lane.spawnGap = 180 + Math.random() * 120;
      lane.spawnTimer = lane.spawnGap;
    } else if (type === 'tracks') {
      lane.train = { state: 'idle', x: 0, dir: 0, timer: 90 + Math.floor(Math.random() * 180) };
    }
    lanes[idx] = lane;
    lastLaneTypes.push(type);
    if (lastLaneTypes.length > 4) lastLaneTypes.shift();
    return lane;
  }

  // ===== INPUT =====
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') {
      if (state === 'playing') pauseGame();
      else if (state === 'paused') resumeGame();
      e.preventDefault();
      return;
    }
    keys[e.code] = true;
    if (state === 'playing') {
      var dir = null;
      if (e.code === 'ArrowUp' || e.code === 'KeyW') dir = 'up';
      else if (e.code === 'ArrowDown' || e.code === 'KeyS') dir = 'down';
      else if (e.code === 'ArrowLeft' || e.code === 'KeyA') dir = 'left';
      else if (e.code === 'ArrowRight' || e.code === 'KeyD') dir = 'right';
      if (dir && hopQueue.length < 2) {
        hopQueue.push(dir);
        e.preventDefault();
      }
    }
    if (e.code === 'Space' || e.code === 'Enter') {
      if (state === 'title' || state === 'end') startGame();
      else if (state === 'paused') resumeGame();
    }
  });
  document.addEventListener('keyup', function (e) { keys[e.code] = false; });

  // ===== AUDIO =====
  var audioCtx = null, musicPlaying = false;
  function ensureAudio() {
    if (!audioCtx) {
      try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) {}
    }
    if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
  }
  function beep(freq, duration, type, gain) {
    if (!audioCtx) return;
    var o = audioCtx.createOscillator();
    var g = audioCtx.createGain();
    o.type = type || 'sine';
    o.frequency.setValueAtTime(freq, audioCtx.currentTime);
    g.gain.setValueAtTime(gain || 0.12, audioCtx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + duration);
    o.connect(g); g.connect(audioCtx.destination);
    o.start(); o.stop(audioCtx.currentTime + duration);
  }
  function playHop()    { beep(620, 0.06, 'triangle', 0.08); }
  function playMail()   { beep(880, 0.08, 'square', 0.12); setTimeout(function(){ beep(1320, 0.12, 'square', 0.10); }, 60); }
  function playCoffee() { beep(660, 0.08, 'triangle', 0.12); setTimeout(function(){ beep(990, 0.12, 'triangle', 0.10); }, 60); }
  function playSplash() { beep(180, 0.15, 'sawtooth', 0.18); setTimeout(function(){ beep(140, 0.2, 'sine', 0.12); }, 80); }
  function playCrash()  { beep(120, 0.18, 'sawtooth', 0.2); setTimeout(function(){ beep(80, 0.3, 'sawtooth', 0.15); }, 90); }
  function playHorn()   { beep(260, 0.18, 'square', 0.14); }
  function playTrainWhistle() { beep(880, 0.4, 'triangle', 0.18); setTimeout(function(){ beep(660, 0.6, 'triangle', 0.14); }, 200); }
  function playTrainPass() { beep(80, 0.6, 'sawtooth', 0.25); }
  function playBark()   { beep(300, 0.06, 'sawtooth', 0.16); setTimeout(function(){ beep(220, 0.1, 'sawtooth', 0.14); }, 60); }
  function playJingle() {
    [523, 659, 784, 1047].forEach(function (n, i) { setTimeout(function () { beep(n, 0.18, 'triangle', 0.12); }, i * 110); });
  }
  function startMusic() {
    if (!audioCtx || musicPlaying) return;
    musicPlaying = true;
    var melody = [392, 440, 494, 523, 587, 523, 494, 440, 392, 440, 494, 587];
    var bass = [196, 196, 247, 262, 294, 262, 247, 196, 196, 196, 247, 294];
    var i = 0;
    function tick() {
      if (!musicPlaying) return;
      beep(melody[i % melody.length], 0.18, 'triangle', 0.035);
      beep(bass[i % bass.length], 0.4, 'sine', 0.045);
      i++;
      setTimeout(tick, 290);
    }
    tick();
  }
  function stopMusic() { musicPlaying = false; }

  // ===== STATE TRANSITIONS =====
  window.startGame = function () {
    ensureAudio();
    document.getElementById('titleScreen').style.display = 'none';
    document.getElementById('endScreen').style.display = 'none';
    var nameSection = document.getElementById('nameEntrySection');
    if (nameSection) nameSection.style.display = 'none';
    var nameInput = document.getElementById('nameInput');
    if (nameInput) { nameInput.value = ''; nameInput.blur(); }
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    reset();
    state = 'playing';
    startMusic();
  };
  function pauseGame() { state = 'paused'; document.getElementById('pauseScreen').style.display = 'flex'; stopMusic(); }
  window.resumeGame = function () { document.getElementById('pauseScreen').style.display = 'none'; state = 'playing'; startMusic(); };
  window.quitGame = function () { window.location.href = '/tv'; };
  function gameOver(reason) {
    if (state === 'end') return;
    state = 'end';
    az.dead = true;
    deathReason = reason;
    stopMusic();
    finalScore = score;
    setTimeout(function () {
      document.getElementById('finalScoreDisplay').textContent = finalScore + ' pts';
      document.getElementById('deathLine').textContent = deathLineFor(reason);
      document.getElementById('endScreen').style.display = 'flex';
      fetchLeaderboard(true);
    }, 700);
  }
  function deathLineFor(reason) {
    return ({
      'car': 'Splat. Should have looked both ways.',
      'kid': 'Took out by a kid on a scooter. Brutal.',
      'creek': 'Into the creek. Bike too. Az is not amused.',
      'train': 'The 6:42 to Cleveland does not stop for letters.',
      'sun': "The sun's up. Mums and dads are at work already.",
      'edge': 'Carried off the side. The creek wins again.'
    })[reason] || 'Ride over.';
  }

  // ===== UPDATE =====
  function startHop(dir) {
    if (az.hop || az.dead) return;
    var dCol = 0, dLane = 0;
    if (dir === 'up') dLane = 1;
    else if (dir === 'down') dLane = -1;
    else if (dir === 'left') dCol = -1;
    else if (dir === 'right') dCol = 1;

    // Determine starting col based on current x (in case Az was on a log)
    var fromCol = az.col;
    if (az.onLog) fromCol = pixelToCol(az.x);

    var toCol = fromCol + dCol;
    var toLane = az.lane + dLane;

    // Block at map edges
    if (toCol < 0 || toCol >= COLS) return;
    if (toLane < Math.floor(camera) - 1) return;

    // Block hopping into trees/houses on grass lane
    var targetLane = ensureLane(toLane);
    if (targetLane.type === 'grass') {
      var blocked = false;
      (targetLane.decorations || []).forEach(function (d) {
        if (d.col === toCol && d.kind === 'tree') blocked = true;
      });
      if (blocked) return;
    }

    az.hop = {
      fromCol: fromCol,
      fromLane: az.lane,
      toCol: toCol,
      toLane: toLane,
      progress: 0,
      dir: dir
    };
    az.facing = dir;
    az.onLog = null;
    playHop();
  }

  function pixelToCol(x) {
    return Math.round((x - GUTTER - TILE_W / 2) / TILE_W);
  }

  function update() {
    frame++;
    if (state !== 'playing') return;

    // Camera creep speeds up with progress
    var creepRate = 0.012 + Math.min(0.02, maxLane / 6000);
    camera += creepRate;

    // Resolve hop animation
    if (az.hop) {
      az.hop.progress++;
      if (az.hop.progress >= HOP_FRAMES) {
        az.lane = az.hop.toLane;
        az.col = az.hop.toCol;
        az.x = tileX(az.col) + TILE_W / 2;
        az.hop = null;
        onArriveTile();
      }
    } else if (hopQueue.length > 0) {
      startHop(hopQueue.shift());
    }

    // Generate lanes ahead
    var maxNeeded = Math.ceil(camera) + 16;
    for (var li = 0; li < maxNeeded; li++) ensureLane(li);

    // Cull old lanes well below camera
    var cullBelow = Math.floor(camera) - 6;
    for (var k in lanes) {
      if (parseInt(k, 10) < cullBelow) delete lanes[k];
    }

    // Update lane entities for visible + buffer
    var startL = Math.floor(camera) - 1;
    var endL = Math.ceil(camera) + 14;
    for (var lN = startL; lN <= endL; lN++) {
      var L = lanes[lN];
      if (!L) continue;
      updateLane(L);
    }

    // If Az on log lane (creek), follow log
    var azLane = lanes[az.lane];
    if (azLane && azLane.type === 'creek' && !az.hop) {
      var found = null;
      for (var i = 0; i < azLane.logs.length; i++) {
        var log = azLane.logs[i];
        if (az.x >= log.x && az.x <= log.x + log.w) { found = log; break; }
      }
      if (found) {
        if (!az.onLog || az.onLog.log !== found) {
          az.onLog = { log: found, offset: az.x - found.x };
        }
        az.x = found.x + az.onLog.offset;
      } else {
        // Drown
        gameOver('creek');
        playSplash();
      }
      // Carried off-screen
      if (az.x < -10 || az.x > W + 10) {
        gameOver('edge');
        playSplash();
      }
    } else {
      az.onLog = null;
      if (azLane) az.x = tileX(az.col) + TILE_W / 2;
    }

    // Hit checks
    checkHits();

    // Camera death
    if (az.lane < camera - 0.4) {
      gameOver('sun');
    }

    // Sun tint as camera advances toward Az
    var gap = az.lane - camera;
    sunTint = Math.max(0, 1 - gap / 4);
  }

  function updateLane(L) {
    if (L.type === 'road' || L.type === 'road_fast') {
      // Move existing cars
      for (var ci = L.cars.length - 1; ci >= 0; ci--) {
        L.cars[ci].x += L.speed;
        if ((L.speed > 0 && L.cars[ci].x > W + 80) || (L.speed < 0 && L.cars[ci].x < -80)) {
          L.cars.splice(ci, 1);
        }
      }
      // Spawn new cars
      L.spawnTimer--;
      if (L.spawnTimer <= 0) {
        var sx = L.speed > 0 ? -60 : W + 60;
        L.cars.push({ x: sx, palette: Math.floor(Math.random() * 6) });
        L.spawnTimer = (L.gap / Math.abs(L.speed)) * 0.9;
      }
    } else if (L.type === 'footpath') {
      for (var ki = L.kids.length - 1; ki >= 0; ki--) {
        L.kids[ki].x += L.speed;
        if ((L.speed > 0 && L.kids[ki].x > W + 60) || (L.speed < 0 && L.kids[ki].x < -60)) {
          L.kids.splice(ki, 1);
        }
      }
      L.spawnTimer--;
      if (L.spawnTimer <= 0) {
        var sx2 = L.speed > 0 ? -40 : W + 40;
        L.kids.push({ x: sx2, variant: Math.floor(Math.random() * 3) });
        L.spawnTimer = (L.gap / Math.abs(L.speed)) * 1.0;
      }
    } else if (L.type === 'creek') {
      L.logs.forEach(function (log) { log.x += L.speed; });
      // Despawn off-screen
      L.logs = L.logs.filter(function (log) {
        return !(L.speed > 0 && log.x > W + 60) && !(L.speed < 0 && log.x + log.w < -60);
      });
      // Spawn new logs
      L.spawnTimer--;
      if (L.spawnTimer <= 0) {
        var sx3 = L.speed > 0 ? -TILE_W * 3 - 20 : W + 20;
        L.logs.push({ x: sx3, w: TILE_W * (1 + Math.floor(Math.random() * 3)) });
        L.spawnTimer = L.spawnGap / Math.abs(L.speed) * Math.abs(L.speed) + 60;
        // Actually just reset to spawnGap frames
        L.spawnTimer = L.spawnGap;
      }
    } else if (L.type === 'tracks') {
      var t = L.train;
      t.timer--;
      if (t.state === 'idle' && t.timer <= 0) {
        t.state = 'warning';
        t.timer = 50;
        t.dir = Math.random() < 0.5 ? 1 : -1;
        playTrainWhistle();
      } else if (t.state === 'warning' && t.timer <= 0) {
        t.state = 'sweeping';
        t.x = t.dir === 1 ? -200 : W + 200;
        t.timer = 30;
        playTrainPass();
      } else if (t.state === 'sweeping') {
        t.x += t.dir * 18;
        if ((t.dir === 1 && t.x > W + 200) || (t.dir === -1 && t.x < -200)) {
          t.state = 'idle';
          t.timer = 180 + Math.floor(Math.random() * 200);
        }
      }
    }
  }

  function onArriveTile() {
    var L = lanes[az.lane];
    if (!L) return;

    if (az.lane > maxLane) {
      // Forward progress reward
      var advanced = az.lane - maxLane;
      score += advanced;
      maxLane = az.lane;
    }

    if (L.type === 'grass') {
      // Letterboxes adjacent to Az or under Az: deliver
      L.letterboxes.forEach(function (m) {
        if (!m.hit && Math.abs(m.col - az.col) <= 1) {
          m.hit = true; m.flag = false;
          letterboxesHit++;
          score += 100;
          playMail();
          spawnPopup('+100', tileX(m.col) + TILE_W / 2, laneScreenY(az.lane) + LANE_H / 2 - 8, '#2a8a3a');
        }
      });
      L.coffees.forEach(function (c) {
        if (!c.taken && c.col === az.col) {
          c.taken = true;
          coffeesGrabbed++;
          score += 75;
          playCoffee();
          spawnPopup('+75 COFFEE!', tileX(c.col) + TILE_W / 2, laneScreenY(az.lane) + LANE_H / 2 - 8, '#d63f3f');
        }
      });
    }
  }

  // ===== HIT CHECKS =====
  function checkHits() {
    var L = lanes[az.lane];
    if (!L || az.dead || az.hop) return;
    if (L.type === 'road' || L.type === 'road_fast') {
      for (var i = 0; i < L.cars.length; i++) {
        var c = L.cars[i];
        if (Math.abs(c.x - az.x) < 30) { gameOver('car'); playCrash(); playHorn(); return; }
      }
    } else if (L.type === 'footpath') {
      for (var i2 = 0; i2 < L.kids.length; i2++) {
        var k = L.kids[i2];
        if (Math.abs(k.x - az.x) < 22) { gameOver('kid'); playCrash(); return; }
      }
    } else if (L.type === 'tracks') {
      var t = L.train;
      if (t.state === 'sweeping' && Math.abs(t.x - az.x) < W) {
        // Train spans the whole lane while sweeping
        gameOver('train');
        return;
      }
    }
  }

  // ===== POPUPS =====
  var popups = [];
  function spawnPopup(text, x, y, colour) { popups.push({ text: text, x: x, y: y, age: 0, colour: colour }); }

  // ===== RENDER =====
  function render() {
    // Sky gradient that warms as sunTint rises
    var skyTop = lerpColor('#a8d8e8', '#ff9a4a', sunTint);
    var skyBot = lerpColor('#cfeaff', '#ffd9a8', sunTint);
    var grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, skyTop); grad.addColorStop(1, skyBot);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    if (state === 'title') return;

    // Draw lanes from bottom (oldest visible) to top
    var startL = Math.floor(camera) - 1;
    var endL = Math.floor(camera) + 13;
    for (var lN = endL; lN >= startL; lN--) {
      var L = lanes[lN];
      if (!L) continue;
      drawLane(L);
    }

    // Sun warning bar at the very bottom of the screen
    if (sunTint > 0.2) {
      var alpha = sunTint;
      ctx.fillStyle = 'rgba(255, 100, 40,' + (alpha * 0.5) + ')';
      ctx.fillRect(0, H - 16, W, 16);
      ctx.fillStyle = '#fff';
      ctx.font = 'bold 11px "Press Start 2P", monospace';
      ctx.textAlign = 'center';
      ctx.fillText('☀ KEEP MOVING', W / 2, H - 4);
    }

    // Az
    drawAz();

    // Popups
    for (var pi = popups.length - 1; pi >= 0; pi--) {
      var pop = popups[pi];
      pop.age++;
      var alpha = 1 - pop.age / 60;
      ctx.fillStyle = pop.colour;
      ctx.globalAlpha = alpha;
      ctx.font = 'bold 13px "Press Start 2P", monospace';
      ctx.textAlign = 'center';
      ctx.fillText(pop.text, pop.x, pop.y - pop.age * 0.7);
      ctx.globalAlpha = 1;
      if (pop.age > 60) popups.splice(pi, 1);
    }

    drawHUD();
  }

  function drawLane(L) {
    var y = laneScreenY(L.idx);
    if (y < -LANE_H || y > H) return;

    if (L.type === 'grass') {
      // Two slightly different greens for stripe pattern
      var g1 = L.idx % 2 === 0 ? '#8dd66a' : '#7fc85a';
      ctx.fillStyle = g1;
      ctx.fillRect(0, y, W, LANE_H);
      // Tiny grass tufts
      ctx.fillStyle = 'rgba(0,0,0,0.07)';
      for (var ti = 0; ti < 14; ti++) {
        var tx = ((L.idx * 11 + ti * 19) % W);
        var ty = y + ((L.idx * 7 + ti * 13) % LANE_H);
        ctx.fillRect(tx, ty, 2, 2);
      }
      // Decorations (trees) on outer columns
      (L.decorations || []).forEach(function (d) {
        if (d.kind === 'tree') drawTree(tileX(d.col) + TILE_W / 2, y + LANE_H / 2);
      });
      // Coffees
      L.coffees.forEach(function (c) {
        if (!c.taken) drawCoffee(tileX(c.col) + TILE_W / 2, y + LANE_H / 2);
      });
      // Letterboxes
      L.letterboxes.forEach(function (m) { drawLetterbox(tileX(m.col) + TILE_W / 2, y + LANE_H / 2 + 4, m.hit, m.flag); });
    } else if (L.type === 'road' || L.type === 'road_fast') {
      ctx.fillStyle = L.type === 'road_fast' ? '#2a2a36' : '#3a3a44';
      ctx.fillRect(0, y, W, LANE_H);
      // Road edge
      ctx.fillStyle = '#666';
      ctx.fillRect(0, y, W, 2);
      ctx.fillRect(0, y + LANE_H - 2, W, 2);
      // Centre dashes
      ctx.fillStyle = '#ffe44d';
      for (var dx = 8; dx < W; dx += 36) ctx.fillRect(dx, y + LANE_H / 2 - 2, 18, 4);
      // Cars
      L.cars.forEach(function (c) { drawCar(c.x, y + LANE_H / 2, L.speed > 0 ? 0 : Math.PI, c.palette); });
    } else if (L.type === 'footpath') {
      ctx.fillStyle = '#cfcfcf';
      ctx.fillRect(0, y, W, LANE_H);
      ctx.fillStyle = 'rgba(0,0,0,0.08)';
      for (var sx = 0; sx < W; sx += 56) ctx.fillRect(sx, y + LANE_H / 2 - 1, 56, 2);
      L.kids.forEach(function (k) { drawKid(k.x, y + LANE_H / 2, L.speed > 0 ? 0 : Math.PI); });
    } else if (L.type === 'creek') {
      // Water
      var w1 = '#3a78c8';
      ctx.fillStyle = w1;
      ctx.fillRect(0, y, W, LANE_H);
      // Wave shimmer
      ctx.strokeStyle = 'rgba(255,255,255,0.25)';
      ctx.lineWidth = 1;
      for (var wx = 0; wx < W; wx += 36) {
        ctx.beginPath();
        ctx.moveTo(wx + (frame % 36), y + 12);
        ctx.lineTo(wx + 12 + (frame % 36), y + 16);
        ctx.lineTo(wx + 24 + (frame % 36), y + 12);
        ctx.stroke();
      }
      // Logs
      L.logs.forEach(function (log) { drawLog(log.x, y + LANE_H / 2, log.w); });
    } else if (L.type === 'tracks') {
      ctx.fillStyle = '#6a4a2a';
      ctx.fillRect(0, y, W, LANE_H);
      // Sleepers
      ctx.fillStyle = '#3a2818';
      for (var sl = 4; sl < W; sl += 24) ctx.fillRect(sl, y + 6, 16, LANE_H - 12);
      // Rails
      ctx.fillStyle = '#999';
      ctx.fillRect(0, y + LANE_H * 0.3, W, 3);
      ctx.fillRect(0, y + LANE_H * 0.7, W, 3);
      // Train
      var t = L.train;
      if (t.state === 'warning') {
        if ((frame >> 2) % 2 === 0) {
          ctx.fillStyle = '#d63f3f';
          ctx.fillRect(0, y, W, LANE_H);
          ctx.fillStyle = '#fff';
          ctx.font = 'bold 14px "Press Start 2P", monospace';
          ctx.textAlign = 'center';
          ctx.fillText('TRAIN!', W / 2, y + LANE_H / 2 + 5);
        }
      } else if (t.state === 'sweeping') {
        drawTrain(t.x, y + LANE_H / 2, t.dir);
      }
    }
  }

  function drawAz() {
    var laneY = laneScreenY(az.lane);
    var x, y;
    var lift = 0;
    if (az.hop) {
      var p = az.hop.progress / HOP_FRAMES;
      var fromX = tileX(az.hop.fromCol) + TILE_W / 2;
      var toX = tileX(az.hop.toCol) + TILE_W / 2;
      var fromY = laneScreenY(az.hop.fromLane) + LANE_H / 2;
      var toY = laneScreenY(az.hop.toLane) + LANE_H / 2;
      x = fromX + (toX - fromX) * p;
      y = fromY + (toY - fromY) * p;
      lift = Math.sin(p * Math.PI) * 16;
    } else {
      x = az.x;
      y = laneY + LANE_H / 2;
    }
    var facing = ({ up: -Math.PI / 2, down: Math.PI / 2, left: Math.PI, right: 0 })[az.facing];

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.beginPath();
    ctx.ellipse(x, y + 8, 14 - lift * 0.3, 7 - lift * 0.2, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.save();
    ctx.translate(x, y - lift);
    ctx.rotate(facing);
    // Bike body
    ctx.fillStyle = '#d63f3f';
    ctx.fillRect(-12, -3, 24, 6);
    ctx.fillStyle = '#222';
    ctx.fillRect(-16, -2, 6, 4);
    ctx.fillRect(10, -2, 6, 4);
    // Az
    ctx.fillStyle = '#4ea84e';
    ctx.beginPath(); ctx.ellipse(-1, 0, 9, 7, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#3a8a3a';
    ctx.beginPath();
    ctx.moveTo(-9, 0); ctx.lineTo(-15, -3); ctx.lineTo(-15, 3); ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#4ea84e';
    ctx.beginPath(); ctx.arc(6, 0, 6, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#3a8a3a';
    ctx.fillRect(8, -3, 6, 6);
    ctx.fillStyle = '#fff';
    ctx.beginPath(); ctx.arc(8, -3, 1.4, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#000';
    ctx.beginPath(); ctx.arc(8.4, -3, 0.7, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
  }

  // ===== SPRITES =====
  function drawTree(x, y) {
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath(); ctx.ellipse(x + 5, y + 5, 16, 12, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#3a7a3a';
    ctx.beginPath(); ctx.arc(x, y, 18, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#4ea84e';
    ctx.beginPath(); ctx.arc(x - 4, y - 4, 12, 0, Math.PI * 2); ctx.fill();
  }

  function drawLetterbox(x, y, hit, flag) {
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath(); ctx.ellipse(x + 2, y + 8, 10, 5, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#5a3018';
    ctx.fillRect(x - 2, y - 2, 4, 14);
    ctx.fillStyle = hit ? '#2a8a3a' : '#d63f3f';
    ctx.fillRect(x - 13, y - 13, 26, 16);
    ctx.fillStyle = hit ? '#1f6628' : '#a02828';
    ctx.fillRect(x - 13, y - 13, 26, 3);
    ctx.fillStyle = '#222';
    ctx.fillRect(x - 6, y - 6, 12, 2);
    if (flag) {
      ctx.fillStyle = '#888';
      ctx.fillRect(x + 12, y - 13, 1, 12);
      ctx.fillStyle = '#ffe44d';
      ctx.beginPath();
      ctx.moveTo(x + 13, y - 13); ctx.lineTo(x + 19, y - 10); ctx.lineTo(x + 13, y - 7);
      ctx.closePath(); ctx.fill();
    }
  }

  function drawCoffee(x, y) {
    var bob = Math.sin(frame * 0.1) * 2;
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.beginPath(); ctx.ellipse(x + 2, y + 12, 11, 4, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.beginPath(); ctx.arc(x, y + bob, 11, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#5a3018';
    ctx.beginPath(); ctx.arc(x, y + bob, 7, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.font = 'bold 11px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('♥', x, y + bob);
  }

  function drawCar(x, y, facing, palette) {
    var COL = ['#d63838', '#3870c8', '#e8b020', '#6a6a6a', '#a838b8', '#3a8a4a'];
    var c = COL[palette % COL.length];
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(facing);
    ctx.fillStyle = 'rgba(0,0,0,0.4)';
    ctx.fillRect(-22 + 3, -11 + 3, 44, 22);
    ctx.fillStyle = c;
    ctx.fillRect(-22, -11, 44, 22);
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.fillRect(14, -11, 1, 22);
    ctx.fillRect(-15, -11, 1, 22);
    ctx.fillStyle = '#a8d8e8';
    ctx.fillRect(8, -9, 6, 18);
    ctx.fillStyle = 'rgba(168,216,232,0.7)';
    ctx.fillRect(-14, -9, 6, 18);
    ctx.fillStyle = '#222';
    ctx.fillRect(-19, -13, 7, 3);
    ctx.fillRect(-19, 10, 7, 3);
    ctx.fillRect(12, -13, 7, 3);
    ctx.fillRect(12, 10, 7, 3);
    ctx.fillStyle = '#fff8a8';
    ctx.fillRect(20, -8, 3, 4);
    ctx.fillRect(20, 4, 3, 4);
    ctx.restore();
  }

  function drawKid(x, y, facing) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(facing);
    ctx.fillStyle = 'rgba(0,0,0,0.3)';
    ctx.fillRect(-12, -4 + 2, 24, 5);
    // Skateboard
    ctx.fillStyle = '#5a3018';
    ctx.fillRect(-12, -4, 24, 3);
    ctx.fillStyle = '#222';
    ctx.fillRect(-10, -5, 3, 1);
    ctx.fillRect(7, -5, 3, 1);
    // Body
    ctx.fillStyle = '#3870c8';
    ctx.beginPath(); ctx.ellipse(0, 0, 5, 6, 0, 0, Math.PI * 2); ctx.fill();
    // Head
    ctx.fillStyle = '#d63f3f';
    ctx.beginPath(); ctx.arc(0, 0, 4, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#222';
    ctx.fillRect(2, -1, 4, 2);
    ctx.restore();
  }

  function drawLog(x, y, w) {
    ctx.fillStyle = 'rgba(0,0,0,0.4)';
    ctx.fillRect(x + 3, y - 16 + 3, w, 32);
    // Log body
    ctx.fillStyle = '#8a5828';
    ctx.fillRect(x, y - 16, w, 32);
    // Bark texture
    ctx.fillStyle = '#5a3818';
    for (var bx = 0; bx < w; bx += 14) {
      ctx.fillRect(x + bx, y - 16, 2, 32);
    }
    // End rings
    ctx.fillStyle = '#a87838';
    ctx.fillRect(x, y - 16, 5, 32);
    ctx.fillRect(x + w - 5, y - 16, 5, 32);
    ctx.strokeStyle = '#5a3818';
    ctx.lineWidth = 1;
    ctx.beginPath(); ctx.arc(x + 2, y, 3, 0, Math.PI * 2); ctx.stroke();
    ctx.beginPath(); ctx.arc(x + w - 3, y, 3, 0, Math.PI * 2); ctx.stroke();
  }

  function drawTrain(x, y, dir) {
    ctx.save();
    ctx.translate(x, y);
    ctx.scale(dir, 1);
    ctx.fillStyle = 'rgba(0,0,0,0.4)';
    ctx.fillRect(-180 + 4, -20 + 4, 360, 40);
    // Body
    ctx.fillStyle = '#1a3850';
    ctx.fillRect(-180, -20, 360, 40);
    // Stripe
    ctx.fillStyle = '#ffe44d';
    ctx.fillRect(-180, -2, 360, 4);
    // Front cone
    ctx.fillStyle = '#1a3850';
    ctx.beginPath();
    ctx.moveTo(180, -20); ctx.lineTo(220, 0); ctx.lineTo(180, 20);
    ctx.closePath(); ctx.fill();
    // Windows
    ctx.fillStyle = '#a8d8e8';
    for (var wi = -160; wi < 160; wi += 60) ctx.fillRect(wi, -14, 24, 12);
    // Wheels
    ctx.fillStyle = '#222';
    for (var wh = -160; wh < 160; wh += 50) {
      ctx.beginPath(); ctx.arc(wh, 18, 6, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();
  }

  // ===== HUD =====
  function drawHUD() {
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(0, 0, W, 44);
    ctx.fillStyle = '#fff';
    ctx.font = '11px "Press Start 2P", monospace';
    ctx.textAlign = 'left';
    ctx.fillText('SCORE', 14, 18);
    ctx.fillStyle = '#ffe44d';
    ctx.font = '20px "Press Start 2P", monospace';
    ctx.fillText(String(score), 14, 38);

    ctx.fillStyle = '#fff';
    ctx.font = '11px "Press Start 2P", monospace';
    ctx.fillText('MAIL', 220, 18);
    ctx.fillStyle = '#ffe44d';
    ctx.font = '18px "Press Start 2P", monospace';
    ctx.fillText(String(letterboxesHit), 220, 38);

    ctx.fillStyle = '#fff';
    ctx.font = '11px "Press Start 2P", monospace';
    ctx.fillText('COFFEES', 330, 18);
    ctx.fillStyle = '#ffe44d';
    ctx.font = '18px "Press Start 2P", monospace';
    ctx.fillText(String(coffeesGrabbed), 330, 38);

    ctx.fillStyle = '#fff';
    ctx.font = '11px "Press Start 2P", monospace';
    ctx.fillText('DEEPEST', 470, 18);
    ctx.fillStyle = '#ffe44d';
    ctx.font = '18px "Press Start 2P", monospace';
    ctx.fillText(String(maxLane), 470, 38);
  }

  // ===== UTIL =====
  function lerpColor(a, b, t) {
    var ar = parseInt(a.slice(1, 3), 16), ag = parseInt(a.slice(3, 5), 16), ab = parseInt(a.slice(5, 7), 16);
    var br = parseInt(b.slice(1, 3), 16), bg = parseInt(b.slice(3, 5), 16), bb = parseInt(b.slice(5, 7), 16);
    var r = Math.round(ar + (br - ar) * t);
    var g = Math.round(ag + (bg - ag) * t);
    var bx = Math.round(ab + (bb - ab) * t);
    return 'rgb(' + r + ',' + g + ',' + bx + ')';
  }

  // ===== LEADERBOARD =====
  function fetchLeaderboard(isEnd) {
    fetch('/api/scores?game=letterbox')
      .then(function (r) { return r.json(); })
      .then(function (d) {
        try { localStorage.setItem('letterbox-scores', JSON.stringify(d.scores)); } catch (e) {}
        renderLeaderboard(d.scores, isEnd);
      })
      .catch(function () {
        var cached = [];
        try { cached = JSON.parse(localStorage.getItem('letterbox-scores') || '[]'); } catch (e) {}
        renderLeaderboard(cached, isEnd);
      });
  }
  function renderLeaderboard(scores, isEnd) {
    var targetEl = isEnd ? 'leaderboardSection' : 'titleLeaderboard';
    var container = document.getElementById(targetEl);
    scores = scores || [];
    var html = '<div class="lb-title">TOP DELIVERIES</div>';
    if (scores.length === 0) html += '<div class="lb-empty">No scores yet. Be the first!</div>';
    for (var i = 0; i < Math.max(scores.length, 10); i++) {
      if (i < scores.length) {
        html += '<div class="lb-row"><span>' + (i + 1) + '. ' + scores[i].name + '</span><span>' + scores[i].value + '</span></div>';
      } else {
        html += '<div class="lb-row placeholder"><span>' + (i + 1) + '. ---</span><span>-</span></div>';
      }
    }
    container.innerHTML = html;
    if (isEnd) {
      var qualifies = scores.length < 10 || finalScore > scores[scores.length - 1].value;
      if (qualifies && finalScore > 0) {
        document.getElementById('nameEntrySection').style.display = '';
        document.getElementById('nameInput').focus();
      }
    }
  }
  window.saveScore = function () {
    var nameInput = document.getElementById('nameInput');
    var name = nameInput.value.trim();
    fetch('/api/scores', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ game: 'letterbox', name: name, value: Math.floor(finalScore) })
    })
    .then(function (r) { return r.json(); })
    .then(function (d) {
      document.getElementById('nameEntrySection').style.display = 'none';
      try { localStorage.setItem('letterbox-scores', JSON.stringify(d.scores)); } catch (e) {}
      renderEndLeaderboard(d.scores, name.toUpperCase() || 'JAYKILL');
    })
    .catch(function () { document.getElementById('nameEntrySection').style.display = 'none'; });
  };
  function renderEndLeaderboard(scores, playerName) {
    var container = document.getElementById('leaderboardSection');
    scores = scores || [];
    var html = '<div class="lb-title">TOP DELIVERIES</div>';
    var hi = false;
    for (var i = 0; i < Math.max(scores.length, 10); i++) {
      if (i < scores.length) {
        var isP = !hi && scores[i].name === playerName.substring(0, 12) && scores[i].value === Math.floor(finalScore);
        if (isP) hi = true;
        html += '<div class="lb-row' + (isP ? ' highlight' : '') + '"><span>' + (i + 1) + '. ' + scores[i].name + '</span><span>' + scores[i].value + '</span></div>';
      } else {
        html += '<div class="lb-row placeholder"><span>' + (i + 1) + '. ---</span><span>-</span></div>';
      }
    }
    container.innerHTML = html;
  }

  // ===== INIT =====
  fetchLeaderboard(false);
  function loop() { update(); render(); requestAnimationFrame(loop); }
  loop();
})();
