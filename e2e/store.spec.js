const { test, expect } = require("@playwright/test");

test.describe("Store homepage", () => {
  test("loads with Az, tagline, and version number", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator(".az-container")).toBeVisible();
    await expect(page.getByText("The Family Video Game Store")).toBeVisible();
    await expect(page.locator(".store-version")).toBeVisible();
  });

  test("shelf shows Space Dodge and Bloom game cards", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator('a.game-box[href="/games/space-dodge.html"]')).toBeVisible();
    await expect(page.locator('a.game-box[href="/games/bloom.html"]')).toBeVisible();
    await expect(page.getByText("Space Dodge")).toBeVisible();
    await expect(page.getByText("Bloom")).toBeVisible();
  });

  test("clicking Space Dodge card navigates to the game", async ({ page }) => {
    await page.goto("/");
    await page.locator('a.game-box[href="/games/space-dodge.html"]').click();
    await expect(page).toHaveURL("/games/space-dodge.html");
  });

  test("clicking Bloom card navigates to the game", async ({ page }) => {
    await page.goto("/");
    await page.locator('a.game-box[href="/games/bloom.html"]').click();
    await expect(page).toHaveURL("/games/bloom.html");
  });

  test("help page loads", async ({ page }) => {
    await page.goto("/help.html");
    await expect(page.getByRole("heading", { name: "Submit your game", level: 1 })).toBeVisible();
  });

  test("submit-your-game link on homepage works", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("link", { name: "Submit your game" }).click();
    await expect(page).toHaveURL("/submit");
  });
});

test.describe("Game page banner", () => {
  // Space Dodge is on the shared wrapper now too (6573820), so its banner is
  // .ezaz-store-banner from ez-az-shell.css rather than a per-game
  // .store-banner -- same as Bloom below.
  test("Space Dodge has EZ-AZ banner linking back to store", async ({ page }) => {
    await page.goto("/games/space-dodge.html");
    const banner = page.locator(".ezaz-store-banner a");
    await expect(banner).toBeVisible();
    await expect(banner).toHaveAttribute("href", "/");
    await banner.click();
    await expect(page).toHaveURL("/");
  });

  // Bloom is on the shared wrapper, so its banner is .ezaz-store-banner from
  // ez-az-shell.css rather than a per-game .store-banner. Games still to
  // migrate (BL-016) keep the old class.
  test("Bloom has EZ-AZ banner linking back to store", async ({ page }) => {
    await page.goto("/games/bloom.html");
    const banner = page.locator(".ezaz-store-banner a");
    await expect(banner).toBeVisible();
    await expect(banner).toHaveAttribute("href", "/");
    await banner.click();
    await expect(page).toHaveURL("/");
  });
});

test.describe("404 page", () => {
  test("returns 404 with back link", async ({ page }) => {
    const response = await page.goto("/nope");
    expect(response.status()).toBe(404);
    await expect(page.getByText("Back to EZ-AZ")).toBeVisible();
  });
});
