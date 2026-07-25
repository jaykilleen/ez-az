---
Date: 2026-07-26
Status: Accepted
Related: ADR 012
Triggers:
  - changing opening hours, school holiday dates, or the closed-page redirect
  - debugging "why is the store shut / open right now?"
  - adding a client that needs to know whether the store is open
  - considering removing the duplicated hours rules in opening-hours.js
Topics: store-hours, api, closed-screen, observability
---

# ADR 013 -- The Server Is Authoritative for Store Hours

## Context

Opening hours were implemented twice: `app/models/store_hours.rb` enforces them
server-side, and `public/opening-hours.js` decides client-side whether to
redirect to `/closed.html`. Each carried its own copy of the timetable and its
own copy of the school-holiday table, with a comment asking future maintainers
to keep them in sync.

That arrangement failed twice in two days:

1. A boundary bug in the JS `nextOpening()` made the countdown restart at 24
   hours the moment the store opened (fixed in 83abe47).
2. The holiday table held one stale, slightly wrong range and nothing after it,
   so the whole winter break ran on 4pm weekday hours (fixed in 7fa5d58).

The second was invisible for 16 days. `/api/store/status` existed but reported
only `{override, open_until}` -- it could not say whether the store was
actually open, so there was no way to check the timetable in production. The
only signal was a child finding the store shut.

## Decision

**The server is authoritative for whether the store is open. The client's copy
of the rules is a fallback for when the server cannot be reached.**

### `/api/store/status` reports resolved state

```json
{
  "open": true,
  "override": false,
  "open_until": null,
  "schedule": "holiday",
  "opens_at": "07:30",
  "closes_at": "19:30",
  "holiday": { "from": "2026-09-19", "to": "2026-10-05" },
  "now": "2026-09-22T08:00:00+10:00",
  "zone": "Australia/Brisbane"
}
```

`schedule` is one of `weekday`, `saturday`, `sunday`, `holiday` and says which
timetable applied. `holiday` names the matched period or is null. `override`
and `open_until` keep their original meaning so a browser holding a cached
`opening-hours.js` still works.

`StoreHours.window_for` is the single source of truth for the rules; `open?`
and `status` both go through it so they cannot disagree.

### `?at=<iso8601>` answers hypotheticals

`GET /api/store/status?at=2026-09-22T08:00:00+10:00` reports what the store
would do at that moment. Times without an offset are read in the store's
timezone. Unparseable input falls back to now.

This is read-only. It changes the answer, never the store, and no access
decision keys off this endpoint -- `RespectsStoreHours` calls `StoreHours.open?`
with the real clock. It exists so the holiday calendar can be verified against
production the day it ships, rather than discovered wrong months later.

### The client prefers the server's answer

`opening-hours.js` still computes hours locally, but when the status fetch
succeeds it takes `d.open` as the truth. The fetch was already on the critical
path for the redirect decision, so this costs no extra latency. On network
failure it silently falls back to the local rules.

### The duplicated tables stay, and stay guarded

The JS keeps its own timetable and holiday table so the closed page still
behaves sensibly offline. `StoreHoursTest` guards the duplication directly:
one test parses the JS holiday array and fails on any drift from the Ruby one,
another fails once the data is within 30 days of running out.

## Consequences

- The store's state is observable in production. "Why is it shut?" is answered
  by one curl, including which timetable applied and which holiday matched.
- The holiday calendar is verifiable the day it ships. A future date can be
  queried directly instead of waiting for it to arrive.
- The client and server can no longer disagree in the normal case, because the
  client defers. They can still disagree offline, which is why the drift test
  stays.
- The response grew from 2 fields to 9. It is unauthenticated and reveals only
  the opening hours, which are published on the closed page anyway.
- `?at=` is an unauthenticated time-travel parameter. It is safe only for as
  long as nothing keys authorisation off this endpoint. Anything that needs to
  gate access must call `StoreHours.open?` directly, never this JSON.
- Deleting the JS rules entirely would make the closed page depend on a network
  round trip to know anything. Deliberately not done -- see ADR 012, where the
  whole point was that a TV screen with no manual refresh must self-heal.
