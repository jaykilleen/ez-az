// Shared background music module for TV party games (Trivia, Spotlight, Treasure Hunt).
// Loops a procedural Web Audio pattern. Browser autoplay policy means start() must be
// called from a user gesture (e.g. the Start Game click).
//
// Usage:
//   Music.start('treasure');     // begin loop
//   Music.stop();                // stop loop and tear down audio context
//   Music.setMuted(true);        // mute without stopping (volume ramp)
//   Music.isMuted();             // boolean — persisted in localStorage
//   Music.attachMuteButton(el);  // wire a button as toggle (updates label)

(function (global) {
  var ctx = null;
  var master = null;
  var schedulerTimer = null;
  var nextNoteAt = 0;
  var beatStep = 0;
  var currentTrack = null;
  var muted = false;
  var stopFlag = false;
  var mutePref = 'ezaz_tv_music_muted';
  var muteButtons = [];

  try { muted = localStorage.getItem(mutePref) === '1'; } catch (_) { muted = false; }

  // ── Note frequencies ────────────────────────────────────────────────
  var NF = {};
  'C Db D Eb E F Gb G Ab A Bb B'.split(' ').forEach(function (n, i) {
    for (var o = 0; o < 8; o++) NF[n + o] = 440 * Math.pow(2, (i - 9 + (o - 4) * 12) / 12);
  });

  // ── Tones ────────────────────────────────────────────────────────────
  function tone(freq, when, dur, type, gain, attack) {
    var o = ctx.createOscillator();
    var g = ctx.createGain();
    o.type = type || 'triangle';
    o.frequency.setValueAtTime(freq, when);
    var a = attack == null ? 0.01 : attack;
    g.gain.setValueAtTime(0, when);
    g.gain.linearRampToValueAtTime(gain, when + a);
    g.gain.exponentialRampToValueAtTime(0.0001, when + dur);
    o.connect(g);
    g.connect(master);
    o.start(when);
    o.stop(when + dur + 0.05);
  }

  function pluck(freq, when, dur, gain) { tone(freq, when, dur, 'triangle', gain, 0.005); }
  function pad(freq, when, dur, gain)   { tone(freq, when, dur, 'sine',     gain, 0.4); }
  function bass(freq, when, dur, gain)  { tone(freq, when, dur, 'sawtooth', gain * 0.5, 0.01); }

  function tick(when, gain) {
    var bufSize = ctx.sampleRate * 0.05;
    var buf = ctx.createBuffer(1, bufSize, ctx.sampleRate);
    var data = buf.getChannelData(0);
    for (var i = 0; i < bufSize; i++) data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / bufSize, 4);
    var src = ctx.createBufferSource();
    src.buffer = buf;
    var g = ctx.createGain();
    g.gain.value = gain;
    var hp = ctx.createBiquadFilter();
    hp.type = 'highpass';
    hp.frequency.value = 6000;
    src.connect(hp); hp.connect(g); g.connect(master);
    src.start(when);
  }

  // ── Track patterns ────────────────────────────────────────────────────
  // Each function takes (when, beat) and schedules notes for that beat.
  // Tempo defines the beat duration. Tracks loop their own beat counter.
  var TRACKS = {
    trivia: {
      tempo: 130,           // BPM
      gain: 0.18,
      pattern: function (t, beat) {
        // 8-beat bouncy quiz-show loop
        var step = beat % 8;
        var bassNotes = [NF.C2, NF.C2, NF.G2, NF.G2, NF.A2, NF.A2, NF.F2, NF.G2];
        bass(bassNotes[step], t, 0.45, 0.32);
        if (step % 2 === 0) tick(t, 0.06);
        // Melody: arpeggio
        var melody = [NF.E5, NF.G5, NF.C6, NF.G5, NF.A5, NF.C6, NF.F5, NF.B5];
        pluck(melody[step], t, 0.3, 0.12);
        if (step === 0 || step === 4) {
          pluck(NF.E6, t + 0.25, 0.18, 0.06);
        }
      }
    },

    spotlight: {
      tempo: 85,
      gain: 0.16,
      pattern: function (t, beat) {
        // 8-beat warm theatrical loop, F major
        var step = beat % 8;
        // Pad chord every 4 beats
        if (step === 0) {
          pad(NF.F3, t, 1.6, 0.18);
          pad(NF.A3, t, 1.6, 0.14);
          pad(NF.C4, t, 1.6, 0.12);
        } else if (step === 4) {
          pad(NF.D3, t, 1.6, 0.18);
          pad(NF.F3, t, 1.6, 0.14);
          pad(NF.A3, t, 1.6, 0.12);
        }
        // Sparse melody
        var melody = [NF.F5, null, NF.A5, null, NF.G5, null, NF.E5, null];
        if (melody[step]) pluck(melody[step], t, 0.7, 0.1);
      }
    },

    treasure: {
      tempo: 105,
      gain: 0.17,
      pattern: function (t, beat) {
        // 8-beat adventurous A-minor loop
        var step = beat % 8;
        var bassSeq = [NF.A2, NF.A2, NF.E3, NF.A2, NF.F2, NF.F2, NF.G2, NF.E3];
        bass(bassSeq[step], t, 0.4, 0.3);
        // Pluck arpeggio in upper register
        var melody = [NF.A4, NF.C5, NF.E5, NF.A5, NF.G4, NF.B4, NF.D5, NF.F5];
        pluck(melody[step], t, 0.32, 0.1);
        // Soft tick on offbeats
        if (step % 2 === 1) tick(t, 0.04);
        // Mystery accent every 8
        if (step === 7) pad(NF.A3, t, 0.6, 0.12);
      }
    },

    hacker: {
      tempo: 124,
      gain: 0.14,
      pattern: function (t, beat) {
        // 16-beat tense cyber loop in C minor
        var step = beat % 16;
        // Driving bass on every 2nd step
        var bassSeq = [NF.C2, null, NF.C2, null, NF.G2, null, NF.Eb2, null,
                       NF.C2, null, NF.C2, null, NF.Bb2, null, NF.G2, null];
        if (bassSeq[step]) bass(bassSeq[step], t, 0.28, 0.32);
        // Keyboard chatter — high tick on every offbeat
        if (step % 2 === 1) tick(t, 0.05);
        // Sparse melodic stabs — minor 7 arpeggio
        var melody = [NF.C5, null, null, NF.Eb5, null, NF.G5, null, NF.Bb5,
                      NF.C6, null, NF.G5, null, NF.Eb5, null, NF.C5, null];
        if (melody[step]) pluck(melody[step], t, 0.22, 0.09);
        // Sub pulse every 8 — adds urgency
        if (step === 0 || step === 8) pad(NF.C3, t, 0.6, 0.08);
      }
    }
  };

  // ── Scheduler ─────────────────────────────────────────────────────────
  function ensureContext() {
    if (ctx) return;
    var Ctx = global.AudioContext || global.webkitAudioContext;
    if (!Ctx) return;
    ctx = new Ctx();
    master = ctx.createGain();
    master.gain.value = 0;
    master.connect(ctx.destination);
  }

  function targetGain() {
    if (!currentTrack) return 0;
    return muted ? 0 : (TRACKS[currentTrack] ? TRACKS[currentTrack].gain : 0);
  }

  function rampMaster(target, secs) {
    if (!master) return;
    var now = ctx.currentTime;
    master.gain.cancelScheduledValues(now);
    master.gain.setValueAtTime(master.gain.value, now);
    master.gain.linearRampToValueAtTime(target, now + secs);
  }

  function loop() {
    if (stopFlag || !ctx || !currentTrack) return;
    var track = TRACKS[currentTrack];
    if (!track) return;
    var beatDur = 60 / track.tempo;
    while (nextNoteAt < ctx.currentTime + 0.25) {
      try { track.pattern(nextNoteAt, beatStep); } catch (_) {}
      beatStep = (beatStep + 1) % 1024;
      nextNoteAt += beatDur;
    }
    schedulerTimer = setTimeout(loop, 60);
  }

  function start(track) {
    if (!TRACKS[track]) return;
    ensureContext();
    if (!ctx) return;
    if (ctx.state === 'suspended') ctx.resume();
    stopFlag = false;
    currentTrack = track;
    nextNoteAt = ctx.currentTime + 0.1;
    beatStep = 0;
    rampMaster(targetGain(), 0.6);
    if (schedulerTimer) clearTimeout(schedulerTimer);
    loop();
  }

  function stop() {
    stopFlag = true;
    if (schedulerTimer) { clearTimeout(schedulerTimer); schedulerTimer = null; }
    rampMaster(0, 0.4);
    setTimeout(function () {
      currentTrack = null;
      if (ctx && ctx.state !== 'closed') {
        try { ctx.close(); } catch (_) {}
      }
      ctx = null;
      master = null;
    }, 500);
  }

  function setMuted(m) {
    muted = !!m;
    try { localStorage.setItem(mutePref, muted ? '1' : '0'); } catch (_) {}
    rampMaster(targetGain(), 0.2);
    muteButtons.forEach(updateButtonLabel);
  }

  function isMuted() { return muted; }

  function updateButtonLabel(btn) {
    btn.setAttribute('aria-pressed', muted ? 'true' : 'false');
    btn.textContent = muted ? '🔇' : '🔊';
    btn.title = muted ? 'Unmute music' : 'Mute music';
  }

  function attachMuteButton(btn) {
    if (!btn || muteButtons.indexOf(btn) !== -1) return;
    muteButtons.push(btn);
    updateButtonLabel(btn);
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      setMuted(!muted);
    });
  }

  global.Music = {
    start: start,
    stop: stop,
    setMuted: setMuted,
    isMuted: isMuted,
    attachMuteButton: attachMuteButton
  };
})(typeof window !== 'undefined' ? window : this);
