const { test, expect } = require("@playwright/test");

// Games are migrating onto the shared wrapper one at a time (BL-016). A
// migrated game renders its board with ArcadeShell using .ezaz-lb-* classes
// and "#1 NAME"; a pre-shell game still hand-rolls .lb-* and "1. NAME".
//
// Flip `shell` to true as each game is migrated. If a migration is missed
// here, the assertions below fail loudly rather than silently testing markup
// that no longer exists.
const GAMES = [
  { name: "Space Dodge", path: "/games/space-dodge.html", format: "pts", shell: true },
  { name: "Cat vs Mouse", path: "/games/cat-vs-mouse.html", format: "pts", shell: false },
  { name: "Bloom", path: "/games/bloom.html", format: "time", shell: true },
];

function selectors(shell) {
  return shell
    ? { title: ".ezaz-lb-title", empty: ".ezaz-lb-empty", row: ".ezaz-lb-row", rank: "#1 ACE" }
    : { title: ".lb-title", empty: ".lb-empty", row: ".lb-row", rank: "1. ACE" };
}

// The shared runtime reads the ranking direction off the response, so the mock
// has to send it or a time-based game will be formatted as points.
function scoresBody(scores, format) {
  return JSON.stringify({ scores, sort: format === "time" ? "asc" : "desc" });
}

for (const game of GAMES) {
  const s = selectors(game.shell);

  test.describe(`${game.name} title leaderboard`, () => {
    test("shows leaderboard container with empty state and placeholders", async ({
      page,
    }) => {
      await page.route("**/api/scores*", (route) =>
        route.fulfill({
          status: 200,
          contentType: "application/json",
          body: scoresBody([], game.format),
        })
      );
      await page.goto(game.path);
      const lb = page.locator(".title-leaderboard");
      await expect(lb).toBeVisible();
      await expect(lb.locator(s.title)).toHaveText("LEADERBOARD");

      // A padded board shows ten placeholder rows AND keeps the encouragement.
      await expect(lb.locator(s.row)).toHaveCount(10);
      await expect(lb.locator(`${s.row}.placeholder`)).toHaveCount(10);
      await expect(lb.locator(s.empty)).toHaveText("No scores yet. Be the first!");
    });

    test("renders scored rows with placeholders to fill 10", async ({
      page,
    }) => {
      await page.route("**/api/scores*", (route) =>
        route.fulfill({
          status: 200,
          contentType: "application/json",
          body: scoresBody(
            [
              { name: "ACE", value: game.format === "time" ? 45000 : 500 },
              { name: "BEE", value: game.format === "time" ? 60000 : 300 },
              { name: "CAT", value: game.format === "time" ? 90000 : 100 },
            ],
            game.format
          ),
        })
      );
      await page.goto(game.path);
      const lb = page.locator(".title-leaderboard");
      await expect(lb).toBeVisible();
      await expect(lb.locator(s.title)).toHaveText("LEADERBOARD");

      // 3 real + 7 placeholders = 10 total
      await expect(lb.locator(s.row)).toHaveCount(10);
      await expect(lb.locator(`${s.row}:not(.placeholder)`)).toHaveCount(3);
      await expect(lb.locator(`${s.row}.placeholder`)).toHaveCount(7);
      await expect(lb.locator(s.empty)).toHaveCount(0);

      const firstRow = lb.locator(s.row).first();
      await expect(firstRow).toContainText(s.rank);

      // Time-based games must render MM:SS.mmm, not a raw point value. This is
      // the case that used to break: the shelf kept its own list of which
      // games were time-based and it had drifted.
      if (game.format === "time") {
        await expect(firstRow).toContainText("00:45.000");
      } else {
        await expect(firstRow).toContainText("500");
      }
    });

    test("does not show name entry input on title screen", async ({
      page,
    }) => {
      await page.route("**/api/scores*", (route) =>
        route.fulfill({
          status: 200,
          contentType: "application/json",
          body: scoresBody([], game.format),
        })
      );
      await page.goto(game.path);
      const lb = page.locator(".title-leaderboard");
      await expect(lb.locator("input")).toHaveCount(0);
    });
  });
}
