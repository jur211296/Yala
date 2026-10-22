import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// Suite unitaria: sin red. Los e2e contra staging van aparte (vitest.e2e.config.ts).
export default defineConfig({
  resolve: {
    // La librería OAuth importa `cloudflare:workers`, que solo existe en el runtime de Workers (ver el stub).
    alias: { "cloudflare:workers": fileURLToPath(new URL("./test/stubs/cloudflare-workers.ts", import.meta.url)) },
  },
  test: {
    // Sin esto vitest carga la librería con el cargador de Node, que no pasa por el alias de arriba.
    server: { deps: { inline: ["@cloudflare/workers-oauth-provider"] } },
    include: ["test/**/*.test.ts"],
    exclude: ["test/e2e/**"],
    environment: "node",
  },
});
