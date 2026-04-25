Build a QR code scanner directly into EZ-AZ so kids never need a third-party scanner app again.

## Context

The TV Zone page (`/tv_remote/show?token=XXXX&v=VERSION`) is how phones become controllers. Currently players scan the QR code on the TV using their phone's camera app or a third-party scanner — many of which have ads. We want a built-in scanner at a dedicated `/scan` page so kids can go straight there, tap Scan, and be connected.

The QR URL format is always: `https://ez-az.net/tv_remote/show?token=XXXXXX&v=VERSION`

We only care about extracting the full URL from the QR code and redirecting the phone to it.

## Goal

A clean, full-screen camera viewfinder page at `/scan` that:
1. Asks for camera permission
2. Scans QR codes in real time
3. Validates the scanned URL is an EZ-AZ TV Zone link
4. Immediately redirects to it — no extra taps

The page should be fast, ad-free, and work on both Android (Chrome) and iOS (Safari).

## Routes and files to create/edit

- **New route:** `get '/scan', to: 'scan#show'` in `config/routes.rb`
- **New controller:** `app/controllers/scan_controller.rb` (one action, renders the view, no auth needed)
- **New view:** `app/views/scan/show.html.erb` — all the logic lives here
- **Link from store:** Add a "Scan for TV" button somewhere on the main store homepage (`public/index.html`) — bottom corner, subtle, links to `/scan`

## Browser API strategy

**Primary: `BarcodeDetector` (native, no library)**
Available in Chrome on Android and Chrome desktop. Check with:
```javascript
if ('BarcodeDetector' in window) { ... }
```
Usage:
```javascript
var detector = new BarcodeDetector({ formats: ['qr_code'] });
// In a loop:
var barcodes = await detector.detect(videoElement);
if (barcodes.length) handleResult(barcodes[0].rawValue);
```

**Fallback: `jsQR` (pure JS library, ~50KB, no dependencies)**
For iOS Safari and any browser without BarcodeDetector.
Load from CDN: `https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.min.js`
Usage:
```javascript
// Draw video frame to offscreen canvas, then:
var code = jsQR(imageData.data, imageData.width, imageData.height);
if (code) handleResult(code.data);
```

Always try `BarcodeDetector` first and fall back automatically. Don't load jsQR until it's needed.

## Implementation steps

### 1. Route and controller

```ruby
# config/routes.rb — add alongside other routes
get '/scan', to: 'scan#show'
```

```ruby
# app/controllers/scan_controller.rb
class ScanController < ApplicationController
  def show; end
end
```

No layout needed — the view handles its own full-screen styling (like the TV Zone page).

### 2. The view (`app/views/scan/show.html.erb`)

Structure:
```
Full-screen dark page (#0a0a12)
  Store banner (EZ-AZ link, same as other pages)
  Camera viewfinder (video element, fills most of screen)
  Aiming reticle overlay (CSS box in centre, animated corners)
  Status text below viewfinder ("Point at the QR code on the TV")
  Error state (camera denied, no QR found, wrong QR)
```

Key JS logic:

```javascript
var VIDEO_W = 640, VIDEO_H = 480;
var scanning = true;

async function startScanner() {
  var stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: 'environment', width: VIDEO_W, height: VIDEO_H }
  });
  videoEl.srcObject = stream;
  await videoEl.play();

  if ('BarcodeDetector' in window) {
    scanWithBarcodeDetector();
  } else {
    await loadScript('https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.min.js');
    scanWithJsQR();
  }
}

async function scanWithBarcodeDetector() {
  var detector = new BarcodeDetector({ formats: ['qr_code'] });
  while (scanning) {
    try {
      var results = await detector.detect(videoEl);
      if (results.length) { handleResult(results[0].rawValue); return; }
    } catch (e) {}
    await sleep(150);
  }
}

function scanWithJsQR() {
  var canvas = document.createElement('canvas');
  canvas.width = VIDEO_W; canvas.height = VIDEO_H;
  var ctx = canvas.getContext('2d');
  function tick() {
    if (!scanning) return;
    ctx.drawImage(videoEl, 0, 0, VIDEO_W, VIDEO_H);
    var img = ctx.getImageData(0, 0, VIDEO_W, VIDEO_H);
    var code = jsQR(img.data, img.width, img.height);
    if (code) { handleResult(code.data); return; }
    requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}

function handleResult(raw) {
  scanning = false;
  // Validate it's an EZ-AZ TV Zone URL
  try {
    var url = new URL(raw);
    if (url.hostname === 'ez-az.net' && url.pathname === '/tv_remote/show' && url.searchParams.get('token')) {
      showStatus('Connected! Loading your controller...');
      setTimeout(function() { window.location.href = raw; }, 400);
      return;
    }
  } catch (e) {}
  // Not a valid EZ-AZ QR code
  showError('That\'s not an EZ-AZ QR code. Point at the code on the TV.');
  setTimeout(function() { scanning = true; resumeScanning(); }, 2000);
}
```

Handle camera permission denial gracefully:
```javascript
startScanner().catch(function(err) {
  if (err.name === 'NotAllowedError') {
    showError('Camera permission denied. Tap here to try again.');
  } else {
    showError('Could not start camera: ' + err.message);
  }
});
```

### 3. Aiming reticle CSS

```css
.reticle {
  position: absolute;
  width: 220px; height: 220px;
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  pointer-events: none;
}
/* Four corner L-shapes using ::before/::after on child divs */
.reticle-corner {
  position: absolute;
  width: 40px; height: 40px;
  border-color: #00ffc8;
  border-style: solid;
}
.reticle-corner.tl { top: 0; left: 0; border-width: 4px 0 0 4px; }
.reticle-corner.tr { top: 0; right: 0; border-width: 4px 4px 0 0; }
.reticle-corner.bl { bottom: 0; left: 0; border-width: 0 0 4px 4px; }
.reticle-corner.br { bottom: 0; right: 0; border-width: 0 4px 4px 0; }
/* Scanning line animation */
.reticle-line {
  position: absolute;
  left: 8px; right: 8px; height: 2px;
  background: linear-gradient(to right, transparent, #00ffc8, transparent);
  animation: scan-sweep 2s ease-in-out infinite;
}
@keyframes scan-sweep {
  0%, 100% { top: 8px; opacity: 0.6; }
  50% { top: calc(100% - 10px); opacity: 1; }
}
```

### 4. Link from the store

In `public/index.html`, add a small "Scan for TV" button somewhere unobtrusive — bottom-right corner of the page, or in the existing nav/footer area. Should be subtle (not the primary CTA) since it's only useful when a TV is nearby.

```html
<a href="/scan" class="scan-link">📷 Scan for TV</a>
```

## Validation logic (important)

Only accept QR codes that:
- Parse as a valid URL
- Have hostname `ez-az.net` (or `localhost` / `127.0.0.1` for dev)
- Have pathname exactly `/tv_remote/show`
- Have a non-empty `token` param

Anything else: show a friendly message and resume scanning. Don't redirect to arbitrary URLs.

## Dev / localhost testing

The hostname check needs to allow `localhost` during development:
```javascript
var VALID_HOSTS = ['ez-az.net', 'localhost', '127.0.0.1'];
if (VALID_HOSTS.includes(url.hostname) && url.pathname === '/tv_remote/show' ...) { ... }
```

## What success looks like

Kid opens ez-az.net on their phone → taps "Scan for TV" → camera opens inside the app → points at TV → instantly becomes a controller. No camera app. No ads. No redirects through a third-party scanner.
