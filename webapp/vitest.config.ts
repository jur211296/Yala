import { defineConfig } from "vitest/config";

// Suite unitaria del Worker: sin red. La de punta a punta contra staging va aparte (vitest.e2e.config.ts).
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    exclude: ["test/e2e/**"],
    environment: "node",
  },
});
