import { defineConfig } from "vitest/config";

// Punta a punta contra el Worker desplegado en staging. Necesita las contraseñas de los usuarios de prueba
// (~/Secrets/yala-supabase-test/test-users.env); sin ellas, los casos se saltan.
export default defineConfig({
  test: { include: ["test/e2e/**/*.e2e.test.ts"], environment: "node", testTimeout: 60_000 },
});
