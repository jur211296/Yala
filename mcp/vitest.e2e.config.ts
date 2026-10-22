import { defineConfig } from "vitest/config";

// E2E contra el Worker de staging y Supabase staging. Necesita red y las contraseñas de los usuarios de
// prueba (ver mcp/README.md). No corre en CI.
export default defineConfig({
  test: {
    include: ["test/e2e/**/*.e2e.test.ts"],
    environment: "node",
    testTimeout: 60_000,
    hookTimeout: 60_000,
  },
});
