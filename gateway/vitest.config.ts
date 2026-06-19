import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node", // Node 25 trae WebCrypto global (crypto.subtle), atob/btoa, TextEncoder
    include: ["test/**/*.test.ts"],
  },
});
