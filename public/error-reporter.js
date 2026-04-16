// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jay Killeen
//
// Capture-and-report bridge for the EZ-AZ public error tracker (#33).
//
// Hooks window.onerror and unhandledrejection, POSTs errors to
// /api/errors, and keeps a per-page-load Set of fingerprints so the
// same error doesn't spam the server from a tight game loop.
//
// By design this script NEVER throws — if it couldn't post, it silently
// drops the report. An error reporter that errors while reporting
// errors is its own special kind of hell.

(function () {
  if (window.EzAzErrors) return;   // idempotent
  window.EzAzErrors = true;

  var seen = new Set();

  function fingerprint(message, stack) {
    var firstFrame = (stack || "").split("\n", 1)[0] || "";
    return (message || "").slice(0, 200) + "\0" + firstFrame.slice(0, 200);
  }

  function gameSlug() {
    var match = location.pathname.match(/\/games\/([a-z0-9-]+)\.html$/i);
    return match ? match[1].toLowerCase() : null;
  }

  function send(payload) {
    try {
      var body = JSON.stringify(payload);
      // sendBeacon works even during page unload; fall back to fetch.
      var url = "/api/errors";
      if (navigator.sendBeacon) {
        var blob = new Blob([body], { type: "application/json" });
        if (navigator.sendBeacon(url, blob)) return;
      }
      fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: body,
        keepalive: true
      }).catch(function () { /* swallow */ });
    } catch (e) {
      // never let the reporter itself throw
    }
  }

  function report(message, stack, extra) {
    message = (message || "").toString();
    stack   = (stack   || "").toString();
    var fp = fingerprint(message, stack);
    if (seen.has(fp)) return;
    seen.add(fp);

    send({
      message:    message,
      stack:      stack,
      game:       gameSlug(),
      user_agent: navigator.userAgent,
      url:        location.pathname + location.search,
      extra:      extra || null
    });
  }

  window.addEventListener("error", function (event) {
    var err = event.error;
    var message = (err && err.message) || event.message || "Unknown error";
    var stack   = (err && err.stack)   || (event.filename + ":" + event.lineno + ":" + event.colno);
    report(message, stack);
  });

  window.addEventListener("unhandledrejection", function (event) {
    var reason = event.reason;
    var message, stack;
    if (reason && typeof reason === "object") {
      message = reason.message || String(reason);
      stack   = reason.stack   || "";
    } else {
      message = "Unhandled promise rejection: " + String(reason);
      stack   = "";
    }
    report(message, stack, { kind: "unhandledrejection" });
  });

  // Expose for manual/test use.
  window.EzAzReportError = report;
})();
