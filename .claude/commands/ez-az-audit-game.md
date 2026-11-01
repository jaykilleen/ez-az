---
description: Audit a game slug against EZ-AZ's required patterns — registration, artwork, standard features, Phone Contract. Run before deploying any new or updated game.
---

# /ez-az-audit-game [slug]

Checks a game against every required registration and pattern from CLAUDE.md.
Run this before `/ez-az-deploy` whenever a new game is added or an existing one is updated.

If no slug is provided, ask Jay which game to audit.

---

## Step 1 — Gather slug and type

If the slug was not passed as an argument, ask Jay. Then determine the game type by checking
`app/models/game.rb` for `tv_optimised:` on that slug's entry.

---

## Step 2 — Run the registration check

Run the full bash validation block below. Replace `SLUG` with the actual slug.

```bash
SLUG="REPLACE_WITH_SLUG"

echo "=== EZ-AZ GAME AUDIT: $SLUG ==="

echo ""
echo "── Registration ──"

echo "game file:"
ls public/games/${SLUG}.html 2>/dev/null \
  || ls -d public/games/${SLUG}/ 2>/dev/null \
  || ls app/views/*/join.html.erb 2>/dev/null | grep "${SLUG//-/_}" \
  || echo "  MISSING — no game file or view found"

echo "score.rb GAME_SORT:"
grep -n "\"${SLUG}\"" app/models/score.rb || echo "  MISSING — add \"${SLUG}\" => :desc (or :asc) to GAME_SORT"

echo "game.rb GAMES:"
grep -n "slug: \"${SLUG}\"" app/models/game.rb || echo "  MISSING — add entry to GAMES"

echo "shelf card (index.html):"
grep -n "\"${SLUG}\"\|/${SLUG}" public/index.html | grep -v "gameNames\|gameTitles\|timeGames\|data-game" | head -5 \
  || echo "  MISSING — no shelf card href found"

echo "High Scores data-game:"
grep -n "data-game=\"${SLUG}\"" public/index.html || echo "  MISSING — shelf card needs data-game=\"${SLUG}\" on the scores span"

echo "gameNames / gameTitles map:"
grep -n "'${SLUG}':" public/index.html | head -3 || echo "  MISSING — add '${SLUG}': 'Title' to the gameTitles/gameNames map"

echo "timeGames map (ASC games only):"
DIR=$(grep -A2 "slug: \"${SLUG}\"" app/models/score.rb | grep -o ':asc\|:desc' | head -1)
if [ "$DIR" = ":asc" ]; then
  grep -n "${SLUG}" public/index.html | grep -i "time" \
    || echo "  WARN — game sorts ASC but slug not found in timeGames map (scores will show raw ms)"
else
  echo "  n/a (DESC game)"
fi

echo ""
echo "── Artwork ──"

COVER_ID=$(awk "/\/${SLUG}[\"\/]/{f=1} f{print} f&&/<\/a>/{exit}" public/index.html \
  | grep -oE 'id="[a-zA-Z0-9]+Cover"' | head -1 | sed -E 's/id="([^"]+)"/\1/')

if [ -z "$COVER_ID" ]; then
  echo "  MISSING — shelf card has no <canvas id=\"...Cover\"> (placeholder div counts as blank cover)"
else
  grep -q "getElementById('${COVER_ID}')\|getElementById(\"${COVER_ID}\")" public/index.html \
    && echo "  ok — ${COVER_ID} canvas + draw function found" \
    || echo "  MISSING — canvas ${COVER_ID} exists but no draw function in index.html"
fi

echo ""
echo "── Standard game features (scan game file) ──"

GAME_FILE=$(ls public/games/${SLUG}.html 2>/dev/null \
  || find app/views -name "join.html.erb" -path "*${SLUG//-/_}*" 2>/dev/null | head -1)

if [ -z "$GAME_FILE" ]; then
  echo "  SKIP — no game file to scan (check registration above)"
else
  grep -q 'store-banner\|ezaz-store-banner' "$GAME_FILE" \
    && echo "  store banner: ok" || echo "  MISSING — no store banner linking to /"

  grep -q "href=\"/\"" "$GAME_FILE" \
    && echo "  banner href: ok" || echo "  WARN — banner link may not point to /"

  grep -q "window.location.href\s*=\s*['\"]/" "$GAME_FILE" \
    && echo "  quit → store: ok" || echo "  MISSING — no quit path back to the store"

  grep -q "Escape\|keydown\|keyCode\s*===\s*27\|key.*Esc" "$GAME_FILE" \
    && echo "  pause/Escape: ok" || echo "  WARN — no Escape/pause handler detected"

  grep -q "/api/scores" "$GAME_FILE" \
    && echo "  leaderboard API: ok" || echo "  MISSING — no /api/scores calls"

  grep -q "localStorage" "$GAME_FILE" \
    && echo "  localStorage fallback: ok" || echo "  WARN — no localStorage leaderboard fallback"
fi

echo ""
echo "── Routes ──"
grep -n "${SLUG}" config/routes.rb || echo "  (no route — expected for static /games/ files)"

echo ""
echo "── TV / Phone Contract (tv_optimised games only) ──"
TV=$(grep -A5 "slug: \"${SLUG}\"" app/models/game.rb | grep "tv_optimised")
if echo "$TV" | grep -q "true"; then
  CH="app/channels/${SLUG//-/_}_channel.rb"
  [ -f "$CH" ] && echo "  channel: ok ($CH)" || echo "  MISSING — no channel file at $CH"

  grep -q "leave\|player_left\|abort" "$CH" 2>/dev/null \
    && echo "  leave action: ok" || echo "  MISSING — channel has no leave/abort path (Phone Contract clause 4)"

  grep -q "location.reload()" "$GAME_FILE" 2>/dev/null \
    && echo "  WARN — location.reload() on rematch mints a new code and orphans phones (clause 6)" \
    || echo "  rematch code reuse: ok"

  SESSIONS_LINE=$(grep -n "SESSIONS\s*=" "$CH" 2>/dev/null | head -1)
  if [ -n "$SESSIONS_LINE" ]; then
    grep -q "created_at\|sweep\|ttl\|TTL\|expire" "$CH" 2>/dev/null \
      && echo "  session TTL: ok" || echo "  WARN — in-memory SESSIONS with no TTL/sweep (clause 7)"
  fi

  grep -q "qr\|QR\|qr_code\|joinQr" "$GAME_FILE" 2>/dev/null \
    && echo "  QR join: ok" || echo "  WARN — no QR code found; phone join by typed URL only (clause 8)"
else
  echo "  n/a (standard shelf game)"
fi

echo ""
echo "=== AUDIT COMPLETE — fix every MISSING before deploying ==="
```

---

## Step 3 — Interpret results

- **MISSING** — a hard requirement from CLAUDE.md. Do not deploy until fixed.
- **WARN** — likely a problem but may be intentional (e.g. chill game with no leaderboard). Confirm with Jay.
- **ok** / **n/a** — passes.

---

## Step 4 — If issues found, fix them

Use `/ez-az-build-game` Phase 4 as the fix reference — it lists every registration point and what goes where.

---

## Step 5 — If clean, deploy

Run `/ez-az-deploy`. The audit replaces the manual scan; don't run both separately.
