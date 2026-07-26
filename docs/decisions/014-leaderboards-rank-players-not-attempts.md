---
Date: 2026-07-26
Status: Accepted
Triggers:
  - changing how /api/scores builds a leaderboard
  - adding a new game with a leaderboard
  - a player asking why they only appear once on a board
  - wondering where a player's other attempts went
Topics: leaderboards, scores, kids-experience
---

# ADR 014 -- Leaderboards Rank Players, Not Attempts

## Context

`Score.top_10` returned the ten highest rows for a game. Because a row is an
attempt rather than a player, anyone who played a lot took the whole board.

Production on 2026-07-26:

| Game | Rows | Distinct players |
|---|---|---|
| space-dodge | 10 | 2 (ZANDER held 9) |
| bloom | 7 | 4 |
| az-cipher | 7 | 5 |
| late-shift | 5 | 3 |

On space-dodge one child occupied nine of ten slots. Every other kid in the
family was invisible on the board of the store's flagship game, and the only
way onto it was to beat a score that was already there nine times over.

This is the same complaint as issue #52 ("score submission fills every
leaderboard slot with same player"), which was treated as a bug and fixed for
Cat vs Mouse. That fix addressed duplicate submissions from one game session.
This is the same end state reached legitimately, by playing a lot.

## Decision

**A leaderboard shows the top ten players, one row each, at their personal
best.**

`Score.top_10(game)` groups by name and takes `MAX(value)` for points-based
games or `MIN(value)` for time-based ones, ordered by that aggregate.

Nothing is lost by collapsing the rows. The API already returns a signed-in
player's own attempt history separately as `my_scores`, alongside `my_best`,
so personal history has its own home and the shared board is for ranking
players against each other.

The method returns an Array rather than a relation, deliberately. The query is
grouped, and `.count` on a grouped relation returns a Hash keyed by group,
which is a trap for a caller expecting a number.

Grouping is by `name`, not `player_id`, because most scores have no player
attached -- games post a name and only signed-in players get a `player_id`.
Name is what actually identifies a kid here.

## Consequences

- Boards get shorter and more varied. space-dodge goes from ten rows to two,
  which is an honest picture of who has played it and leaves eight slots open.
- More kids see themselves on more boards, which is the point.
- Two children who choose the same name are treated as one player. They are
  indistinguishable to us anyway.
- Name variants stay separate: `COOPER` and `COOPER KILLE` are two rows, as
  are `LACHIE` and `PRO LACHIE`. Merging them would need a judgement we cannot
  safely make automatically. Signing in avoids the problem, since the server
  overrides the posted name with the player's username.
- After posting a score worse than your best you will not see a new row, only
  your existing best. Games show the just-played score on their own game-over
  screen, so the number is not lost.
- `top_10` loads at most ten grouped rows, so this is no more expensive than
  before.
