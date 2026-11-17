// recorrido-lote-5.mjs [base] — el recorrido del lote 5 (Planificación, Estadísticas, Grupos, Bandeja y Ajustes) en un
// Chromium sin cabeza.
//
// Comprueba lo que la suite de la web no puede, porque corre sin navegador: las tarjetas de presupuesto con «Te quedan»,
// el «?» de Pagos, Estadísticas y Grupos, los segmentos y el período de Estadísticas, el grupo abierto a la derecha en
// escritorio y en su pantalla en el celular, que las tres escrituras de Grupos siguen enviando lo mismo, la Bandeja
// encima de la pantalla en la que estabas (Esc, ✕, tocar fuera y editar un borrador encima), Ajustes a 700 px, las
// direcciones de antes y que a 390 px no haya scroll lateral.
//
// Uso: con servidor-maqueta.mjs sirviendo el build en :8787:
//   PW=<carpeta con node_modules/playwright-core> node recorrido-lote-5.mjs http://localhost:8787
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
  const ctx = await browser.newContext({ viewport: { width, height }, hasTouch: touch, isMobile: touch, locale: "es-419", acceptDownloads: true });
  const p = await ctx.newPage();
  const calls = [];
  p.on("request", (r) => {
    if (r.url().includes("/api/")) calls.push({ method: r.method(), url: r.url(), body: r.postData() });
  });
  return { p, calls };
}
const path = (p) => new URL(p.url()).pathname;
const noScroll = (p) => p.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth);

const ir = async (p, ruta) => {
  await p.goto(`${BASE}${ruta}`);
  await p.waitForLoadState("networkidle");
};

// ── Escritorio ─────────────────────────────────────────────────────────────────────────────────────────────────
{
  const { p, calls } = await page(1280, 820, false);

  await ir(p, "/presupuestos");
  check((await p.locator(".bud").count()) === 5, "Presupuestos enseña las cinco tarjetas");
  check((await p.locator(".bud").filter({ hasText: "Comidas fuera" }).locator(".bud-rl").innerText()) === "Te quedan", "a la derecha, «Te quedan»");
  check((await p.locator(".bud").filter({ hasText: "Ocio" }).locator(".bud-rl").innerText()) === "Te pasaste por", "al pasarse, «Te pasaste por»");
  check((await p.locator(".bud").filter({ hasText: "Comidas fuera" }).locator(".bud-st").innerText()) === "En el límite", "en riesgo, «En el límite»");
  check((await p.locator(".bud").filter({ hasText: "Comidas fuera" }).locator(".bud-l").innerText()).replace(/\s/g, " ").includes("de S/ 1,800.00 · 15 días"), "la línea gris «X de Y · 15 días»");
  const cols = await p.evaluate(() => getComputedStyle(document.querySelector(".buds")).gridTemplateColumns.split(" ").length);
  check(cols === 2, "en escritorio, dos columnas", String(cols));
  const barra = await p.locator(".bud").filter({ hasText: "Cuidado personal" }).locator(".bar i").evaluate((e) => getComputedStyle(e).backgroundColor);
  check(barra === "rgb(168, 85, 247)", "la barra lleva el color de la categoría", barra);

  await ir(p, "/pagos");
  check(path(p) === "/pagos", "/pagos sigue abriendo Pagos planificados");
  check((await p.locator(".saldo .cap").innerText()).startsWith("Por pagar"), "«Por pagar…» es la cifra principal");
  await p.locator("button.ayuda").click();
  check((await p.locator(".ayuda-t").innerText()).includes("próximos 30 días"), "el «?» de Pagos explica la cifra");
  check((await p.locator(".pag-cols > section").count()) === 2, "Próximos cobros y Suscripciones lado a lado");
  check((await p.locator(".pag-cols .fila").count()) === 6, "cuatro cobros y dos suscripciones con la fila de la app");
  check((await p.locator(".pag-cols .fila").first().locator(".amt").innerText()).startsWith("−"), "un cobro de gasto lleva signo, como en Registros");

  await ir(p, "/estadisticas");
  const tabs = await p.locator(".est-bar [role=tab]").allInnerTexts();
  check(JSON.stringify(tabs) === JSON.stringify(["Resumen", "Tendencias", "Distribución"]), "segmentos en el orden de la app", tabs.join(", "));
  check((await p.locator(".saldo .cap").first().innerText()) === "Te queda", "la cifra principal es «Te queda»");
  check(!(await p.locator(".saldo .big").first().innerText()).includes("+"), "«Te queda» sin «+» delante");
  await p.locator(".saldo button.ayuda").click();
  check((await p.locator(".ayuda-t").innerText()).includes("transferencias"), "el «?» dice que no cuentan las transferencias");
  check((await p.locator(".kpi-c").count()) === 2, "Gasto medio diario y Gasto más alto en tarjetas");
  const fila = await p.evaluate(() => {
    const a = document.querySelector(".est-top .saldo").getBoundingClientRect().top;
    const b = document.querySelector(".kpi-c").getBoundingClientRect().top;
    return Math.abs(a - b) < 40;
  });
  check(fila, "en escritorio, la cifra y las tarjetas en la misma fila");
  check((await p.locator(".slice .circ svg").count()) === 5, "cada categoría con su ícono");
  const antes = calls.length;
  await p.locator(".est-per select").selectOption("mes_pasado");
  await p.waitForLoadState("networkidle");
  check(calls.slice(antes).some((c) => c.url.includes("periodo=mes_pasado")), "la cápsula del período pide el mes pasado");
  check((await p.locator(".saldo .cap").first().innerText()) === "Te quedó", "y el rótulo pasa a «Te quedó»");
  await p.locator(".est-bar [role=tab]", { hasText: "Distribución" }).click();
  check((await p.locator(".donut").count()) === 1, "Distribución con su gráfico");
  await p.locator(".est-bar [role=tab]", { hasText: "Tendencias" }).click();
  check((await p.locator(".est-per").count()) === 0, "en Tendencias no hay período");

  await ir(p, "/grupos");
  check((await p.locator(".saldo .cap").first().innerText()) === "Te deben en total · en S/", "«Te deben en total · en S/», como la app");
  check((await p.locator(".g-head .big").innerText()).replace(/\s/g, "") === "S/366.50", "el neto en grande", await p.locator(".g-head .big").innerText());
  check((await p.locator(".gbar i").count()) === 2, "la barra rosa y verde");
  check((await p.locator(".gsplit .gdet").count()) === 1, "en escritorio, el grupo abierto a la derecha");
  check((await p.locator(".gcard[aria-current=true]").innerText()).includes("Viaje a Cusco"), "abierto el primero, marcado en la lista");
  check((await p.locator(".gdet .back").count()) === 0, "sin «‹ Grupos» cuando la lista está al lado");
  await p.locator(".gcard", { hasText: "Depa Miraflores" }).click();
  check((await p.locator(".gcard[aria-current=true]").innerText()).includes("Depa Miraflores"), "tocar otro grupo lo abre a la derecha");
  await p.waitForLoadState("networkidle");
  // Las tres escrituras: el mismo formulario y la misma llamada que el lote 3.
  await p.locator(".gdet button.pseg", { hasText: "Nuevo gasto" }).click();
  check((await p.locator("form.sheet[aria-label='Nuevo gasto']").count()) === 1, "«Nuevo gasto» abre su formulario");
  await p.locator("form.sheet input[inputmode=decimal]").fill("30");
  await p.locator("form.sheet input[maxlength='120']").fill("Prueba recorrido");
  const g0 = calls.length;
  await p.locator("form.sheet button[type=submit]").click();
  await p.waitForTimeout(400);
  const gasto = calls.slice(g0).find((c) => c.url.endsWith("/api/grupos/gasto"));
  check(!!gasto && JSON.parse(gasto.body).importe === 30 && JSON.parse(gasto.body).descripcion === "Prueba recorrido", "envía el gasto a /api/grupos/gasto", gasto?.body ?? "");
  await p.keyboard.press("Escape");
  await p.locator(".gdet button.pseg", { hasText: "Saldar" }).click();
  check((await p.locator("form.sheet[aria-label='Saldar']").count()) === 1, "«Saldar» abre su formulario");
  await p.keyboard.press("Escape");
  check((await p.locator("form.sheet").count()) === 0, "Esc lo cierra");
  const i0 = calls.length;
  await p.locator(".gdet button.pseg", { hasText: "Invitar" }).click();
  await p.waitForTimeout(300);
  check(calls.slice(i0).some((c) => c.url.endsWith("/api/grupos/invitar")), "«Invitar» pide el enlace");
  await p.keyboard.press("Escape");
  await p.locator(".gtabs [role=tab]", { hasText: "Gastos" }).click();
  check((await p.locator(".gdet .row .circ svg").count()) === 3, "los gastos del grupo con el ícono de su categoría");

  // La Bandeja encima de la pantalla en la que estabas.
  await ir(p, "/registros");
  await p.locator(".side a.nv[href='/bandeja']").click();
  check(path(p) === "/bandeja", "la Bandeja tiene su dirección");
  check((await p.locator("[role=dialog] #band-titulo").innerText()).startsWith("Bandeja de Entrada"), "se llama «Bandeja de Entrada»");
  check((await p.locator(".reg-lista").count()) === 1, "Registros sigue debajo");
  const lado = await p.locator(".sheet.band").boundingBox();
  check(!!lado && lado.x + lado.width > 1250 && lado.x > 600, "en escritorio, panel a la derecha", JSON.stringify(lado));
  check(await p.evaluate(() => document.activeElement?.classList.contains("cerrar")), "el foco va a la ✕ al abrir");
  await p.locator(".band-f button", { hasText: "Editar" }).click();
  check((await p.locator("form.nr").count()) === 1, "Editar abre el borrador encima");
  await p.keyboard.press("Escape");
  check((await p.locator("form.nr").count()) === 0 && (await p.locator(".sheet.band").count()) === 1, "Esc cierra solo el borrador; la Bandeja sigue");
  await p.keyboard.press("Escape");
  check((await p.locator(".sheet.band").count()) === 0 && path(p) === "/registros", "Esc cierra la Bandeja y vuelve a Registros", path(p));
  await ir(p, "/bandeja");
  check((await p.locator(".saldo .cap").first().innerText()) === "Tu saldo hoy", "abierta de entrada, debajo va el Panel");
  await p.mouse.click(300, 400);
  check((await p.locator(".sheet.band").count()) === 0 && path(p) === "/", "tocar fuera la cierra", path(p));

  await ir(p, "/configurar");
  check((await p.locator(".topbar h1").innerText()) === "Ajustes", "Configurar se llama «Ajustes»");
  const ancho = await p.locator(".ajustes").evaluate((e) => e.getBoundingClientRect().width);
  check(ancho <= 700.5, "Ajustes en una columna de 700 px", String(ancho));
  check((await p.locator(".aj-sq").count()) >= 7, "filas con el cuadrito de color");
  await p.locator(".aj-fila select").first().selectOption("claro");
  check((await p.evaluate(() => document.documentElement.dataset.tema)) === "claro", "el tema se sigue eligiendo aquí");
  await p.locator(".aj-fila select").first().selectOption("sistema");
  check((await p.locator(".sfoot span span").innerText()) === "Ajustes", "el pie de la barra lateral dice «Ajustes»");
}

// ── Celular (390 px) ─────────────────────────────────────────────────────────────────────────────────────────
{
  const { p } = await page(390, 844, true);
  for (const r of ["/presupuestos", "/pagos", "/estadisticas", "/grupos", "/configurar", "/bandeja"]) {
    await ir(p, r);
    check(await noScroll(p), `${r} sin scroll lateral a 390 px`);
  }
  await ir(p, "/estadisticas");
  const vis = await p.locator(".est-bar .pseg-l").evaluateAll((els) => els.filter((e) => getComputedStyle(e).display !== "none").map((e) => e.textContent));
  check(JSON.stringify(vis) === JSON.stringify(["Resumen"]), "en el celular, solo el segmento elegido con nombre", vis.join(","));
  await ir(p, "/grupos");
  check((await p.locator(".gsplit").count()) === 0, "en el celular, la lista sola");
  await p.locator(".gcard").first().click();
  check((await p.locator(".gdet .back").count()) === 1, "tocar un grupo lo abre con «‹ Grupos»");
  await p.locator(".gdet .back").click();
  check((await p.locator(".gcard").count()) === 3, "«‹ Grupos» vuelve a la lista");
  await ir(p, "/bandeja");
  const hoja = await p.locator(".sheet.band").boundingBox();
  check(!!hoja && Math.round(hoja.y + hoja.height) >= 843 && hoja.width >= 389, "en el celular, la hoja sube desde abajo a todo el ancho", JSON.stringify(hoja));
  await p.locator(".sheet.band button.cerrar").click();
  check(path(p) === "/", "la ✕ la cierra", path(p));
}

await browser.close();
console.log(fails === 0 ? "\nTodo en verde." : `\n${fails} comprobaciones en rojo.`);
process.exit(fails === 0 ? 0 : 1);
