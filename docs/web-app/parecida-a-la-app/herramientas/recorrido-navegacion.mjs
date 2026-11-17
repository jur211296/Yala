// recorrido-navegacion.mjs [base] — el recorrido del lote 3 (navegación) en un Chromium sin cabeza.
//
// Comprueba lo que la suite de la web no puede, porque corre sin navegador: navegar con el teclado por la barra
// lateral, ⌘K y Ctrl K (abre, Esc cierra y el foco vuelve), las direcciones de antes (/presupuestos, /pagos…), la
// barra del celular y que a 390 px no haya scroll lateral.
//
// Uso: con servidor-maqueta.mjs sirviendo el build en :8787 (o contra producción con sesión, pasando la base):
//   PW=<carpeta con node_modules/playwright-core> node recorrido-navegacion.mjs http://localhost:8787
// `CHROME` apunta al ejecutable; por defecto, el chromium_headless_shell de la caché de Playwright.
import { createRequire } from "node:module";
import { homedir } from "node:os";

const require = createRequire(`${process.env.PW ?? process.cwd()}/`);
const { chromium } = require("playwright-core");
const BASE = process.argv[2] ?? "http://localhost:8787";
const CHROME =
  process.env.CHROME ??
  `${homedir()}/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell`;

let fails = 0;
const check = (ok, what, detail = "") => {
  if (!ok) fails += 1;
  console.log(`${ok ? "OK  " : "FALLA"} ${what}${detail ? ` — ${detail}` : ""}`);
};

const browser = await chromium.launch({ executablePath: CHROME, headless: true });

async function page(width, height, touch) {
  const ctx = await browser.newContext({ viewport: { width, height }, hasTouch: touch, isMobile: touch, locale: "es-419" });
  return ctx.newPage();
}
const h1 = (p) => p.locator("header.topbar h1").innerText();
const current = (p, sel) => p.locator(`${sel}[aria-current="page"]`).allInnerTexts();
const path = (p) => new URL(p.url()).pathname;
const focusedText = (p) => p.evaluate(() => (document.activeElement?.textContent ?? "").trim() || document.activeElement?.getAttribute("aria-label") || "");

// ── Escritorio ──────────────────────────────────────────────────────────────────────────────────────────────────
{
  const p = await page(1280, 820, false);
  await p.goto(`${BASE}/`);
  await p.locator(".side").waitFor();
  check((await current(p, ".side .nv")).join() === "Panel", "escritorio: / marca Panel en la barra lateral");

  // Teclado: Tab recorre Buscar, las cinco secciones, Bandeja y el avatar, en ese orden.
  const order = [];
  for (let i = 0; i < 8; i += 1) {
    await p.keyboard.press("Tab");
    order.push(await focusedText(p));
  }
  const want = ["Buscar", "Panel", "Registros", "Estadísticas", "Planificación", "Grupos", "Bandeja", "Jürgen"];
  check(want.every((w, i) => order[i]?.startsWith(w)), "teclado: Tab recorre la barra lateral en orden", order.join(" › "));

  // Intro sobre Registros abre Registros.
  await p.goto(`${BASE}/`);
  await p.locator(".side").waitFor();
  for (let i = 0; i < 3; i += 1) await p.keyboard.press("Tab");
  await p.keyboard.press("Enter");
  check(path(p) === "/registros" && (await h1(p)) === "Registros", "teclado: Intro sobre «Registros» abre Registros", path(p));

  // ⌘K y Ctrl K: abren la búsqueda con el foco en el campo; Esc cierra y el foco vuelve a «Registros».
  for (const combo of ["Meta+k", "Control+k"]) {
    await p.keyboard.press(combo);
    const open = await p.locator('[role="dialog"][aria-label="Buscar"]').isVisible();
    const inField = await p.evaluate(() => document.activeElement?.getAttribute("role") === "combobox");
    check(open && inField, `${combo}: abre la búsqueda con el foco en el campo`);
    await p.keyboard.press("Escape");
    await p.waitForTimeout(50);
    const closed = (await p.locator('[role="dialog"][aria-label="Buscar"]').count()) === 0;
    check(closed && (await focusedText(p)).startsWith("Registros"), `${combo} + Esc: cierra y el foco vuelve a donde estaba`, await focusedText(p));
  }
  // ⌘K otra vez con la búsqueda abierta la cierra.
  await p.keyboard.press("Meta+k");
  await p.keyboard.press("Meta+k");
  check((await p.locator('[role="dialog"][aria-label="Buscar"]').count()) === 0, "⌘K dos veces: abre y cierra");

  // La búsqueda lleva a Planificación.
  await p.locator(".sfield").click();
  await p.keyboard.type("planif");
  await p.keyboard.press("Enter");
  check(path(p) === "/planificacion" && (await h1(p)) === "Planificación", "búsqueda: «planif» + Intro abre Planificación", path(p));

  // Direcciones de antes y la nueva.
  for (const [url, seg] of [["/presupuestos", "Presupuestos"], ["/pagos", "Pagos planificados"], ["/planificacion", "Presupuestos"]]) {
    await p.goto(`${BASE}${url}`);
    await p.locator(".psegs").waitFor();
    const ok = (await h1(p)) === "Planificación" && (await current(p, ".pseg")).join() === seg && (await current(p, ".side .nv")).join() === "Planificación";
    check(ok, `${url} abre Planificación en «${seg}»`);
  }
  await p.locator(".pseg", { hasText: "Pagos planificados" }).click();
  check(path(p) === "/pagos", "el segmento Pagos cambia la dirección a /pagos", path(p));
  await p.goBack();
  check(path(p) === "/planificacion" && (await current(p, ".pseg")).join() === "Presupuestos", "Atrás vuelve al segmento anterior", path(p));
  for (const [url, title] of [["/registros", "Registros"], ["/bandeja", "Bandeja"], ["/estadisticas", "Estadísticas"], ["/grupos", "Grupos"], ["/configurar", "Configurar"], ["/no-existe", "Panel"]]) {
    await p.goto(`${BASE}${url}`);
    await p.locator("header.topbar h1").waitFor();
    check((await h1(p)) === title, `${url} abre ${title}`);
  }
  await p.goto(`${BASE}/`);
  await p.locator(".sfoot").click();
  check(path(p) === "/configurar", "el avatar de la barra lateral abre Configurar", path(p));
  await p.locator(".side .nv", { hasText: "Bandeja" }).click();
  check(path(p) === "/bandeja", "Bandeja tiene su entrada en la barra lateral", path(p));
  await p.locator("button.add.desk").click();
  check(await p.locator('[role="dialog"]').filter({ hasText: "Monto" }).or(p.locator(".sheet[role=dialog]")).first().isVisible(), "«+ Nuevo registro» de la cabecera abre la hoja");
  await p.context().close();
}

// ── Celular, 390 px ─────────────────────────────────────────────────────────────────────────────────────────────
{
  const p = await page(390, 844, true);
  for (const url of ["/", "/registros", "/planificacion", "/presupuestos", "/pagos", "/estadisticas", "/grupos", "/bandeja", "/configurar", "/mas"]) {
    await p.goto(`${BASE}${url}`);
    await p.locator("header.topbar h1").waitFor();
    await p.waitForTimeout(150);
    const w = await p.evaluate(() => Math.max(document.documentElement.scrollWidth, document.body.scrollWidth));
    check(w <= 390, `390 px: ${url} sin scroll lateral`, `ancho ${w}`);
  }
  await p.goto(`${BASE}/`);
  await p.locator(".mtabs").waitFor();
  check((await p.locator(".mtabs .mt").allInnerTexts()).map((s) => s.trim()).join("|") === "Panel|Registros|Grupos|Más", "celular: pestañas Panel, Registros, Grupos y Más");
  check(await p.locator(".msearch").isVisible(), "celular: la lupa va aparte");
  check(await p.locator(".acts .add").isVisible(), "celular: «+ Nuevo registro» en el contenido del Panel");
  check(!(await p.locator(".side").isVisible()) && !(await p.locator("button.add.desk").isVisible()), "celular: sin barra lateral ni botón de la cabecera");
  await p.locator(".topbar .inbox").click();
  check(path(p) === "/bandeja" && (await h1(p)) === "Bandeja", "celular: el botón de arriba a la izquierda abre la Bandeja", path(p));
  await p.locator(".topbar a.av").click();
  check(path(p) === "/configurar", "celular: el avatar abre Configurar", path(p));
  await p.goto(`${BASE}/pagos`);
  await p.locator(".mtabs").waitFor();
  check((await current(p, ".mt")).join() === "Más", "celular: /pagos marca Más");
  await p.locator(".mt", { hasText: "Más" }).click();
  await p.locator(".tile", { hasText: "Presupuestos" }).click();
  check(path(p) === "/presupuestos" && (await current(p, ".pseg")).join() === "Presupuestos", "celular: Más › Presupuestos abre su segmento", path(p));
  await p.locator(".msearch").click();
  check(await p.locator('[role="dialog"][aria-label="Buscar"]').isVisible(), "celular: la lupa abre la búsqueda");
  await p.context().close();
}

await browser.close();
console.log(fails ? `\n${fails} comprobaciones fallaron` : "\nTodo el recorrido en verde");
process.exit(fails ? 1 : 0);
