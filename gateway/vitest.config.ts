import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node", // Node 25 trae WebCrypto global (crypto.subtle), atob/btoa, TextEncoder
    include: ["test/**/*.test.ts"],
    // `fetch` HTTP/1 de undici 7: el de Node 26 encola los POST en paralelo (ver el fichero).
    setupFiles: ["test/setup.fetch-http1.ts"],
  },
});
