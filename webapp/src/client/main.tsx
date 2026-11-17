import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { loadTexts } from "./i18n";
import { aplicarTema, temaElegido } from "./tema";
import "./styles.css";
import "./app.css";

// El tema elegido en Configurar, antes de pintar nada.
aplicarTema(temaElegido());

// El idioma se carga antes que la página: cada pantalla lee sus textos al importarse (`i18n.ts`).
void loadTexts().then(async () => {
  const { App } = await import("./App");
  const root = document.getElementById("root");
  if (root) {
    createRoot(root).render(
      <StrictMode>
        <App />
      </StrictMode>,
    );
  }
});
