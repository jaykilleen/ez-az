const { defineConfig } = require("@playwright/test");

module.exports = defineConfig({
  testDir: "./e2e",
  use: {
    // EZ-AZ dev runs on 5003; port 3000 is TXTavern (see CLAUDE.md). This was
    // pointed at 3000, so the whole suite was hitting the wrong app.
    baseURL: process.env.EZAZ_BASE_URL || "http://localhost:5003",
  },
  projects: [
    { name: "chromium", use: { browserName: "chromium" } },
  ],
});
