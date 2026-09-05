const { test, expect } = require("@playwright/test");

test.describe("Space Dodge", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/games/space-dodge.html");
  });

  test("title screen loads", async ({ page }) => {
    await expect(page.locator("#startScreen")).toBeVisible();
    await expect(page.getByText("Charlie & Cooper's Space Dodge!")).toBeVisible();
    await expect(page.getByRole("button", { name: "1 PLAYER" })).toBeVisible();
    await expect(page.getByRole("button", { name: "2 PLAYER - BLAST OFF!" })).toBeVisible();
  });

  test("clicking start begins the game", async ({ page }) => {
    await page.getByRole("button", { name: "1 PLAYER" }).click();
    await expect(page.locator("#startScreen")).toBeHidden();
    await expect(page.locator("canvas#game")).toBeVisible();
  });

  // Space Dodge now uses the shared ArcadeShell pause overlay (migrated in
  // 6573820) instead of a bespoke quit-confirm dialog -- Escape pauses
  // (PAUSED + RESUME + QUIT TO STORE), matching the standard game features
  // in CLAUDE.md, rather than prompting to quit outright.
  test("escape key opens the pause overlay", async ({ page }) => {
    await page.getByRole("button", { name: "1 PLAYER" }).click();
    await expect(page.locator("#startScreen")).toBeHidden();
    await page.keyboard.press("Escape");
    await expect(page.locator(".ezaz-pause")).toBeVisible();
    await expect(page.locator(".ezaz-pause-title")).toHaveText("PAUSED");
    await expect(page.getByRole("button", { name: "RESUME" })).toBeVisible();
    await expect(page.getByRole("link", { name: "QUIT TO STORE" })).toBeVisible();
  });

  test("resume button resumes the game", async ({ page }) => {
    await page.getByRole("button", { name: "1 PLAYER" }).click();
    await page.keyboard.press("Escape");
    await expect(page.locator(".ezaz-pause")).toBeVisible();
    await page.getByRole("button", { name: "RESUME" }).click();
    await expect(page.locator(".ezaz-pause")).toBeHidden();
    await expect(page.locator("canvas#game")).toBeVisible();
  });

  test("quit goes back to store", async ({ page }) => {
    await page.getByRole("button", { name: "1 PLAYER" }).click();
    await page.keyboard.press("Escape");
    await page.getByRole("link", { name: "QUIT TO STORE" }).click();
    await expect(page).toHaveURL("/");
  });
});
