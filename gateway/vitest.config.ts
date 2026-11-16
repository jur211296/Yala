import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    // `cloudflare:workers` solo existe en el runtime de Workers; la clase RPC del conector (src/connector/entrypoint.ts)
    // lo importa. En Node basta la clase vacía del stub.
    alias: { "cloudflare:workers": fileURLToPath(new URL("./test/stubs/cloudflare-workers.ts", import.meta.url)) },
  },
  test: {
    environment: "node", // Node 25 trae WebCrypto global (crypto.subtle), atob/btoa, TextEncoder
    include: ["test/**/*.test.ts"],
    // `fetch` HTTP/1 de undici 7: el de Node 26 encola los POST en paralelo (ver el fichero).
    setupFiles: ["test/setup.fetch-http1.ts"],
  },
});
