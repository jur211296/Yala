import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Solo la página del navegador. El Worker lo empaqueta wrangler (`main` en wrangler.toml) y sirve esta carpeta como
// sus «assets»: misma origen, sin CORS y con las cabeceras de seguridad que pone el Worker a todo.
export default defineConfig({
  plugins: [react()],
  build: { outDir: "dist/client", emptyOutDir: true, sourcemap: false },
});
