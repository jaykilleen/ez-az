// Service worker for EZ-AZ.
//
// Strategy:
//   - HTML and JSON (store pages, manifest) are ALWAYS network-first with
//     NO cache fallback — this stops stale /closed.html or stale
//     /opening-hours.js from keeping users trapped after a deploy.
//   - Other static assets (images, fonts, JS libs) use network-first with
//     cache fallback so the store is still usable briefly when offline.
//   - The SHELL pre-cache deliberately does NOT include HTML files; those
//     are fetched fresh on every navigation.
//
// Bump CACHE_NAME whenever the cached asset list below changes so old
// caches are cleaned up on activate.

const CACHE_NAME = 'ez-az-20260415-2030';

// Only non-HTML, rarely-changing assets go in the shell pre-cache.
const SHELL = [
  '/controls.js'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      return cache.addAll(SHELL);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (names) {
      return Promise.all(
        names.filter(function (name) { return name !== CACHE_NAME; })
             .map(function (name) { return caches.delete(name); })
      );
    })
  );
  self.clients.claim();
});

function isHtmlNavigation(request) {
  if (request.mode === 'navigate') return true;
  var accept = request.headers.get('accept') || '';
  return accept.indexOf('text/html') !== -1;
}

function isManifest(request) {
  return request.url.indexOf('/manifest.json') !== -1;
}

function isOpeningHoursScript(request) {
  return request.url.indexOf('/opening-hours.js') !== -1;
}

self.addEventListener('fetch', function (event) {
  var request = event.request;

  // Network-only (no cache fallback) for HTML navigations, the manifest,
  // and the opening-hours script. These control whether the store is
  // reachable and must never be served stale.
  if (isHtmlNavigation(request) || isManifest(request) || isOpeningHoursScript(request)) {
    event.respondWith(fetch(request));
    return;
  }

  // Everything else: network-first with cache fallback
  event.respondWith(
    fetch(request).then(function (response) {
      var clone = response.clone();
      caches.open(CACHE_NAME).then(function (cache) {
        cache.put(request, clone);
      });
      return response;
    }).catch(function () {
      return caches.match(request);
    })
  );
});
