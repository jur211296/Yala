// capturar-lote-5.mjs <base> <carpeta> <prefijo> — capturas de antes y después del lote 5 (Planificación,
// Estadísticas, Grupos, Bandeja y Ajustes), en claro y oscuro, escritorio (1280 × 820) y celular (390 × 844, táctil),
// con el servidor de maqueta en <base>. Mismo uso que `capturar-pantallas.mjs`:
//
//   PW=<carpeta con node_modules/playwright-core> node capturar-lote-5.mjs http://localhost:8787 <carpeta> antes
//
// Sale <carpeta>/<prefijo>-<pantalla>-<claro|oscuro>-<escritorio|movil>.png.
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
  { id: "presupuestos", path: "/presupuestos" },
  { id: "pagos", path: "/pagos" },
  { id: "estadisticas", path: "/estadisticas" },
  { id: "distribucion", path: "/estadisticas", tap: async (p) => p.getByRole("tab", { name: "Distribución" }).first().click() },
  { id: "grupos", path: "/grupos" },
  // El grupo abierto: en escritorio ancho ya está a la derecha; si no, se toca la primera tarjeta.
  { id: "grupo", path: "/grupos", tap: async (p) => { if (!(await p.locator("main .gdet").count())) await p.locator("main .gcard").first().click(); } },
  { id: "bandeja", path: "/bandeja" },
  { id: "ajustes", path: "/configurar" },
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
