const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./e2e",

  // Some specs actually play the game, so they are mildly timing-sensitive on
  // a slower CI runner. One retry keeps a hiccup from blocking a deploy while
  // still failing on anything genuinely broken. Locally, no retries -- a flake
  // on your own machine is worth seeing.
  retries: process.env.CI ? 1 : 0,
  forbidOnly: !!process.env.CI,
  use: {
    // EZ-AZ dev runs on 5003; port 3000 is TXTavern (see CLAUDE.md). This was
    // pointed at 3000, so the whole suite was hitting the wrong app.
    baseURL: process.env.EZAZ_BASE_URL || "http://localhost:5003",
  },
  projects: [
    { name: "chromium", use: { browserName: "chromium" } },
  ],
});
