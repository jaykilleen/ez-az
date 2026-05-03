# ADR 006 — TV Party Game Patterns: Spotlight, Treasure Hunt, Card-Game Architecture

**Status:** Accepted
**Date:** May 2026

---

## Context

Family Trivia (ADR 005-era) proved the TV+phone party model works: TV is the Stage, phones are Zones, ActionCable carries state. But Trivia is a closed-form quiz — no player-private state, all phones see the same input options.

The family wanted more. Two new game shapes were added in this round:

1. **Spotlight** — a "what would they say?" family conversation game. One player is the Spotlight per round; everyone else guesses what the Spotlight would say. Spotlight then picks a favourite for a bonus. Designed to be **evergreen** — playable on any night, not tied to specific holidays or events.
2. **Treasure Hunt** — a simultaneous-reveal card game. Each round shows a challenge; everyone plays one card from their hand; winner takes the pot. Designed to be **standard-deck compatible** — the 52-card deck deliberately maps to ♥/♠/♣/♦ so the rules also work with physical cards on holidays.

Both games exposed gaps in the existing Stage/Zone architecture that needed first-class support, not one-off hacks.

---

## Decisions

### 1. Two-lane scoring (Spotlight)

Spotlight scores via two independent mechanics:

- **Match (+2)**: a guesser's submission, normalised, equals the Spotlight's actual answer.
- **Pick bonus (+3)**: the Spotlight chooses their favourite non-spotlight submission, awarding +3 to that player on top of any match.

The two lanes can stack on a single submission (matched + picked = +5). This was deliberate — one lane rewards luck/insight, the other rewards style/cleverness. Kids tend to win the match lane; adults tend to win the pick lane.

**Why not a single combined score?** Tested earlier, felt punitive for the player who guessed correctly but wasn't picked. The two-lane structure keeps both kinds of "good answer" rewarded.

### 2. Standard-deck compatibility (Treasure Hunt)

Treasure Hunt's deck is **52 cards: 4 colours × 1–13**, mapped to suits as:

- Red ↔ ♥ Hearts
- Blue ↔ ♠ Spades
- Green ↔ ♣ Clubs
- Yellow ↔ ♦ Diamonds

Aces = 1, J = 11, Q = 12, K = 13. Challenges that filter by colour are phrased as "Reds Rule" / "Hearts Rule" interchangeably. Closest-To targets sit naturally on the 1–13 scale (3–11 random).

This means the game can be played on a kitchen table at Christmas with a real deck — same rules, same flow, no app required. The lobby explicitly prints the suit mapping so families can transition between digital and physical.

**Why not just 1–9 or a custom deck?** Memorability and reusability. The standard playing-card deck is the most widely-distributed game-design constraint in the world. Building inside it makes Treasure Hunt a recipe families can take with them.

### 3. Per-round refill from a shared deck

Each player is dealt 5 cards at game start. After every round:

- Tied players' cards return to their **hand** (not their pot — that was the original design and felt punitive in playtest)
- Round winner takes the pot into their treasure pile
- Hands refill back to 5 from the shared deck (skipped on the final round to avoid wasting cards that won't be played)

This matches everyone's intuition for card games — you draw to refill — and sustains hand strategy across the whole game.

### 4. Card-count scoring, not pot-value

Initial design scored pots by **summed card value** (1+5+13 = 19 points). Playtest exposed the bias: winning a "Lowest Wins" round earns a small pot of low cards; winning "Highest Wins" earns a big pot of high cards. Same effort, different rewards.

Final scoring: **card count is the score** (each round won = +N cards regardless of values). Total pot value remains as the **tiebreaker** on the podium. Every challenge type is now equally rewarding.

### 5. Per-slot ActionCable streams for player-private state

Trivia and Spotlight only need public broadcasts — every phone sees the same payload. Treasure Hunt introduced **player-private hand state** that other players must not see.

Pattern: each phone's `subscribed` block opens **two** streams:

```ruby
stream_from "treasure:#{code}"          # public game stream
stream_from "treasure:#{code}:p#{slot}" # personal stream — only this slot
```

Hand updates (deal, refill, tie-return) broadcast on the per-slot stream:

```ruby
ActionCable.server.broadcast(
  "treasure:#{code}:p#{slot}",
  { type: "deal", slot: slot, hand: s[:hands][slot.to_s] }
)
```

Other slots' subscribers don't receive these payloads — privacy is preserved at the transport layer, not by client-side filtering.

**Future card games should adopt this pattern.** Any game with player-private state (cards, hidden goals, secret dice) uses public-stream + per-slot-stream. The public stream carries observable round state; the personal stream carries each phone's private view.

### 6. Phone Zone gains a hand-of-cards screen

The Zone (`tv_remote/show.html.erb`) gained a new `data-screen="treasure"` containing a 3-column card grid (`#th-hand`), tap-to-select, and a Lock-It-In confirm button. The card visual is colour-coded with corner numbers + suit symbol matching the standard-deck mapping.

This is the first **player-private inventory** UI in the Zone. Future games that show cards, dice, secret roles, etc. should reuse the card-grid CSS scaffold (`.th-card-btn`, `.th-hand`).

### 7. Resume banner on the TV store front

If a TV game tab closes mid-session (accidentally or intentionally), the in-memory game state on the server is still alive (4-hour Room TTL). Each TV game writes `{code, game_slug, started_at}` to localStorage on load and clears it on `game_over`. The TV store front (`/tv`) reads localStorage on load — if there's a recent game, a "Resume" banner appears with a one-click return.

No new server endpoint was needed: the existing `/games/<slug>/<code>` controllers already redirect gracefully when a Room expires.

### 8. Background music — shared module, procedural Web Audio

`public/tv-music.js` exposes a global `Music` API: `start(track)`, `stop()`, `setMuted(bool)`, `attachMuteButton(el)`. Three procedural tracks (trivia / spotlight / treasure) loop until stopped. Mute preference persists in localStorage. Auto-starts on the user's "Start Game" click (browser autoplay-safe), stops on game over.

Music is **per-game-typed** — each TV view passes its own track name. Adding a new TV game = define a new track in `tv-music.js` and call `Music.start('your-slug')` on start.

---

## Consequences

- New TV party games can mix and match the patterns above. Spotlight-shaped (text-input simultaneous reveal) and Treasure-shaped (card-pick simultaneous reveal) both inherit cleanly.
- Per-slot ActionCable streams are the canonical way to deliver private state. Avoid client-side filtering of public payloads.
- Card-game variants (different decks, different challenge pools) should preserve the standard-deck mapping where possible — accessibility for offline play matters.
- The `data-screen="treasure"` shape is reusable. Naming convention for new game screens: `data-screen="<slug-or-shape>"` with sub-states managed by `showXxxPhase(name)` helpers.
- Music tracks should stay short (8 beats) and low-volume by default. Long melodies become annoying loops at TV volume.
