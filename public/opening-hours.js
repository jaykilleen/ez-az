// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jay Killeen
//
// Opening hours. Auto-redirects to /closed.html if the store is shut
// right now, and exposes window.EzAzHours for other pages (e.g.
// closed.html's countdown) to share the same rules.
//
// Normal hours:
//   Mon-Fri  4pm - 7:30pm
//   Sat      7:30am - 7:30pm
//   Sun      7:30am - 5pm
//
// During school holidays, weekdays swap to Saturday hours (7:30am-7:30pm).
// Add or remove ranges in HOLIDAYS below as terms change. Ranges are
// inclusive and checked in the visitor's local timezone (ISO YYYY-MM-DD).
// Once the end date passes, normal hours resume automatically.

(function () {
  var HOLIDAYS = [
    // Autumn school holidays 2026
    { from: "2026-04-04", to: "2026-04-21" }
  ];

  function pad2(n) { return n < 10 ? "0" + n : "" + n; }

  function isoDate(d) {
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
  }

  function onHoliday(d) {
    var iso = isoDate(d);
    return HOLIDAYS.some(function (h) { return iso >= h.from && iso <= h.to; });
  }

  // Returns { openMin, closeMin } for the given date's day-of-week
  // and holiday status. Times are minutes from midnight, local time.
  function hoursFor(d) {
    var day = d.getDay();
    if (day === 0) return { openMin: 450,  closeMin: 1020 }; // Sun  7:30am-5pm
    if (day === 6) return { openMin: 450,  closeMin: 1170 }; // Sat  7:30am-7:30pm
    if (onHoliday(d)) return { openMin: 450, closeMin: 1170 }; // Holiday weekday
    return            { openMin: 960,  closeMin: 1170 };     // Weekday 4pm-7:30pm
  }

  function isOpen(d) {
    var h  = hoursFor(d);
    var hm = d.getHours() * 60 + d.getMinutes();
    return hm >= h.openMin && hm < h.closeMin;
  }

  // Returns a Date for the next time the store opens after `from`.
  function nextOpening(from) {
    var d  = new Date(from || new Date());
    var hm = d.getHours() * 60 + d.getMinutes();
    var today = hoursFor(d);

    if (hm < today.openMin) {
      // Opens later today
      var t = new Date(d);
      t.setHours(Math.floor(today.openMin / 60), today.openMin % 60, 0, 0);
      return t;
    }

    // Opens tomorrow
    var tomorrow = new Date(d);
    tomorrow.setDate(d.getDate() + 1);
    var h = hoursFor(tomorrow);
    tomorrow.setHours(Math.floor(h.openMin / 60), h.openMin % 60, 0, 0);
    return tomorrow;
  }

  // Expose the API for other scripts (closed.html uses this)
  window.EzAzHours = {
    HOLIDAYS:    HOLIDAYS,
    isOpen:      isOpen,
    onHoliday:   onHoliday,
    hoursFor:    hoursFor,
    nextOpening: nextOpening
  };

  // Auto-redirect unless we're on localhost (dev convenience)
  if (location.hostname === "localhost" || location.hostname === "127.0.0.1") return;

  var storeOpen    = isOpen(new Date());
  var onClosedPage = location.pathname === "/closed.html";

  if (!storeOpen && !onClosedPage) {
    // Store is shut and we're trying to use it — send to the closed page
    window.location.replace("/closed.html");
  } else if (storeOpen && onClosedPage) {
    // Store has opened while we were sitting on the closed page — send home
    window.location.replace("/");
  }
})();
