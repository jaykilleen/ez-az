// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jay Killeen
//
// Shared viewport + canvas-scaling helper for EZ-AZ games.
//
// Why this exists:
//   Most EZ-AZ games draw into a fixed-size canvas (e.g. 700x800). On
//   mobile that canvas is wider and taller than the viewport, so the
//   game either overflows the screen (with overflow:hidden cropping
//   the edges) or forces the player to pinch-zoom out, which also
//   shrinks the touch controls to the point of being unusable.
//   See issue #10 (Bloom) and #12 (audit) for the full picture.
//
// What it does:
//   - Locks default mobile gestures that get in the way of gameplay
//     (text selection, double-tap zoom, pull-to-refresh)
//   - Exposes EzAzGame.fitCanvas(canvas, { aspect? }) which sizes the
//     canvas's *CSS* width/height to fit within the viewport while
//     preserving the canvas's intrinsic render resolution. Drawing
//     code doesn't change — the browser scales the rendered bitmap to
//     the CSS size.
//   - Listens for resize and orientationchange so rotating a phone
//     mid-game keeps the canvas fitted.
//   - Never scales the canvas larger than its intrinsic size, so
//     desktop users still see the crisp, un-upscaled art.

(function () {
  // Body-level gesture hygiene. Injected as a shared stylesheet so
  // each game doesn't have to repeat it.
  var style = document.createElement("style");
  style.setAttribute("data-ez-az", "viewport");
  style.textContent =
    "html, body { touch-action: manipulation;" +
    "  -webkit-user-select: none; user-select: none;" +
    "  -webkit-tap-highlight-color: transparent;" +
    "  overscroll-behavior: none; }";
  document.head.appendChild(style);

  function fitCanvas(canvas, opts) {
    if (!canvas) return null;
    opts = opts || {};

    var intrinsicW = canvas.width;
    var intrinsicH = canvas.height;
    var aspect = opts.aspect || (intrinsicW / intrinsicH);

    function resize() {
      var maxW = window.innerWidth;
      var maxH = window.innerHeight;

      // Largest size that fits within the viewport AND preserves aspect,
      // capped at the intrinsic bitmap so desktop doesn't upscale.
      var w = Math.min(intrinsicW, maxW, maxH * aspect);
      var h = w / aspect;

      canvas.style.width  = w + "px";
      canvas.style.height = h + "px";
      canvas.style.display = "block";
    }

    resize();
    // Defer to the next frame so any game CSS that changes body size
    // (banners, overlays) is applied before we measure.
    requestAnimationFrame(resize);

    window.addEventListener("resize", resize);
    window.addEventListener("orientationchange", function () {
      // orientationchange fires slightly before innerWidth/innerHeight
      // update on some platforms; a second tick catches the new size.
      requestAnimationFrame(resize);
      setTimeout(resize, 150);
    });

    return { resize: resize };
  }

  window.EzAzGame = window.EzAzGame || {};
  window.EzAzGame.fitCanvas = fitCanvas;
})();
