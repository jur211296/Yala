import { defineConfig } from "vitest/config";

// Suite unitaria: sin red. Los e2e contra staging van aparte (vitest.e2e.config.ts).
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    exclude: ["test/e2e/**"],
    environment: "node",
  },
});
