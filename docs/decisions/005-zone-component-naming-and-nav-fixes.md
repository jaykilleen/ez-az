# ADR 005 — Zone Component Naming and Navigation Bug Fixes

**Status:** Accepted  
**Date:** April 2026

---

## Context

ADR 001 established the Zone as the phone companion experience but left the internal components unnamed. Conversations about bugs and features were ambiguous ("the tab bar", "the D-pad section", "that rail thing"). We need a stable vocabulary so that future work can reference components precisely without describing their position or CSS class each time.

Three navigation bugs surfaced that also clarified the architecture:

1. **Double-fire on the Shelf**: The store front was calling `handleNavigate` on both `press` and `release` events, so every button press moved focus twice. The first press of any direction set focus to game 0 then immediately navigated away from it on release.

2. **Rail missing from non-game screens**: The Zone Rail (tab bar) only appeared during the trivia buzzer screen. On shelf, lobby, waiting and watching screens the D-pad was visible but there was no way to reach the Options tab — users got stuck with no exit.

3. **Family Trivia still showed BUZZ button**: The trivia lobby QR code was pointing to `rooms/join` (old system). Scanning it landed on `rooms/play.html.erb` which has the legacy BUZZ-to-answer mechanic. The new system expects phones to land on the Zone (`/tv/remote`) and use `TriviaChannel` for A/B/C/D answers.

---

## The Naming System

### Phone side (the Zone)

| Name | What it is | HTML/CSS |
|------|-----------|----------|
| **Zone** | The entire phone companion experience | `.zone`, `tv_remote/show.html.erb` |
| **Zone Bar** | Top strip: EZ-AZ brand + live connection dot | `.zone-bar` |
| **Zone Screen** | The current main content panel | `.zone-content[data-screen]` |
| **Zone Rail** | Three-tab navigation bar at the bottom | `.zone-tabs` + `.zone-tab` |
| **Zone Pad** | The D-pad directional controller | `.zone-dpad` + `.dpad` |
| **Action Button** | The circular FIRE button on the Pad | `.fire-btn` |
| **Options Panel** | The overlay that appears on the Options tab | `.zone-options-panel` |

Zone Screen states: `claim` · `shelf` · `lobby` · `waiting` · `buzzer` · `watching` · `disconnected`

Zone Rail tabs: `game` · `remote` · `options`

### TV side (the Stage)

| Name | What it is | Location |
|------|-----------|----------|
| **Stage** | Whatever is on the big screen | All TV-facing views |
| **Shelf** | The store front on the Stage | `public/index.html` |
| **Party Stage** | Any game-specific TV view with Zone support | `trivia/show.html.erb`, etc. |
| **QR Badge** | The always-visible QR scan badge on the Shelf | `.phone-qr-badge` in `index.html` |

### The engine

| Name | What it is |
|------|-----------|
| **TvRemote** | The ActionCable channel (`TvRemoteChannel`) — the protocol between Stage and Zone |
| **Zone Engine** | The JavaScript in `tv_remote/show.html.erb` that drives the Zone |
| **DPAD_SCREENS** | The JS set of Zone Screen names where the Pad is shown by default |
| **TABBED_SCREENS** | The JS set of Zone Screen names where the Rail is shown |

---

## Decisions

### 1. Filter press-only events on the Shelf

The Shelf listens for `navigate` events from TvRemote and calls `handleNavigate`. TvRemote broadcasts both `press` and `release` for each button, so every D-pad tap was firing `handleNavigate` twice. Fixed by filtering:

```javascript
if (data.type === 'navigate' && data.nav_type !== 'release') handleNavigate(data.direction);
```

### 2. Zone Rail visible on all connected screens

The Rail existed but was only shown when the Zone Screen was `buzzer`. Everything else had the Pad visible at the bottom but no Rail — no route to Options, no exit.

The Rail is now shown for all `TABBED_SCREENS` (`shelf`, `lobby`, `waiting`, `watching`, `buzzer`). The `applyTab` function handles both party (buzzer) and non-party screens:

- **Party screens**: Game tab shows buzzer content; Remote tab shows Pad; Options tab shows Options Panel
- **Non-party screens**: Game tab shows screen content + Pad; Options tab hides Pad and shows Options Panel

The claim and disconnected screens still have no Rail — those are entry/error states, not usage states.

### 3. Trivia rooms are self-contained Zone anchors

The old flow had trivia rooms relying on the Shelf's TvRemote token (stored in `sessionStorage`) for Zone sync. This broke if the TV navigated to trivia directly, or if the phone scanned the trivia QR code (which pointed to the old rooms system).

New flow:
- Trivia rooms get their own `tv_token` on creation
- The trivia lobby QR code points to `tv_remote_url(token: room.tv_token, code: room.code)` — the Zone, not the old rooms system
- `trivia/show.html.erb` subscribes to TvRemote using the room's own token, not `sessionStorage`
- The Zone handles join, slot assignment, and TriviaChannel subscription as it does for any party game

The old `rooms/play` endpoint and BUZZ mechanic remain in place for legacy rooms but are no longer reachable via Family Trivia.

### 4. No-store cache headers on Zone entry points

`TvRemoteController` and `ScanController` now set `Cache-Control: no-store`. Zone URLs include session tokens so they're already cache-busted by URL, but `no-store` prevents edge cases where the browser holds a stale copy of an old Zone version.

---

## Consequences

- Any future conversation about the Zone can use: Zone Bar, Zone Screen, Zone Rail, Zone Pad, Action Button, Options Panel
- The Rail must remain accessible from all TABBED_SCREENS — never hide it without a clear reason
- New party games must give their room a `tv_token` and use `tv_remote_url` for QR codes — do not use `join_room_url`
- The Zone Engine JS (`PARTY_SCREENS`, `TABBED_SCREENS`, `DPAD_SCREENS`) is the source of truth for what appears where
