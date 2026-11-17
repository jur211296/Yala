// capturar-pantallas.mjs <base> <carpeta> <prefijo> — capturas de antes y después que piden un toque (lote 4).
//
// `capturar-web.sh` solo abre una dirección. Esto abre además la hoja «Nuevo registro» y el detalle de un registro, en
// claro y oscuro, escritorio (1280 × 820) y celular (390 × 844, táctil), con el servidor de maqueta en <base>.
//
//   PW=<carpeta con node_modules/playwright-core> node capturar-pantallas.mjs http://localhost:8787 <carpeta> antes
//
// Sale <carpeta>/<prefijo>-<pantalla>-<claro|oscuro>-<escritorio|movil>.png. `CHROME` apunta al ejecutable; por
// defecto, el chromium_headless_shell de la caché de Playwright.
import { createRequire } from "node:module";
import { homedir } from "node:os";

const require = createRequire(`${process.env.PW ?? process.cwd()}/`);
const { chromium } = require("playwright-core");
const [BASE = "http://localhost:8787", OUT = ".", PRE = "captura"] = process.argv.slice(2);
const CHROME =
  process.env.CHROME ??
  `${homedir()}/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell`;

/** Cada pantalla: la dirección y, si hace falta, el toque que la abre. */
const PANTALLAS = [
  { id: "panel", path: "/" },
  { id: "panel-abajo", path: "/", scroll: true },
  { id: "registros", path: "/registros" },
  // El detalle: el primer registro de la lista (en escritorio ancho ya está abierto a la derecha).
  { id: "detalle", path: "/registros", tap: async (p) => p.locator("main .fila, main .row-btn").first().click() },
  // «+ Nuevo registro» (antes «+ Apuntar»): el botón visible de la cabecera o del contenido.
  { id: "nuevo", path: "/", tap: async (p) => p.locator("button.add:visible").first().click() },
];

const browser = await chromium.launch({ executablePath: CHROME, headless: true });
for (const [tema, scheme] of [["claro", "light"], ["oscuro", "dark"]]) {
  for (const [aparato, vp, movil] of [["escritorio", { width: 1280, height: 820 }, false], ["movil", { width: 390, height: 844 }, true]]) {
    const ctx = await browser.newContext({ viewport: vp, deviceScaleFactor: 2, colorScheme: scheme, hasTouch: movil, isMobile: movil, locale: "es-419" });
    for (const s of PANTALLAS) {
      const p = await ctx.newPage();
      await p.goto(BASE + s.path);
      await p.waitForLoadState("networkidle");
      await p.waitForTimeout(300);
      if (s.tap) {
        await s.tap(p);
        await p.waitForTimeout(400);
      }
      if (s.scroll) {
        await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
        await p.waitForTimeout(300);
      }
      const file = `${OUT}/${PRE}-${s.id}-${tema}-${aparato}.png`;
      await p.screenshot({ path: file });
      await p.close();
      console.log("ok", file);
    }
    await ctx.close();
  }
}
await browser.close();
