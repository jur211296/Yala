// recorrido-lote-4.mjs [base] — el recorrido del lote 4 (Panel, Registros y Nuevo registro) en un Chromium sin cabeza.
//
// Comprueba lo que la suite de la web no puede, porque corre sin navegador: el «?» del saldo, los títulos de sección que
// llevan a su pantalla, el resumen «Te queda» y cuándo se esconde, los filtros, el detalle a la derecha en escritorio y
// en hoja en el celular, Exportar CSV, la hoja «Nuevo registro» con el teclado (foco en el monto, sugerida, Intro envía,
// Esc cierra), el ojo y que a 390 px no haya scroll lateral.
//
// Uso: con servidor-maqueta.mjs sirviendo el build en :8787:
//   PW=<carpeta con node_modules/playwright-core> node recorrido-lote-4.mjs http://localhost:8787
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

// ── Escritorio: Panel ──────────────────────────────────────────────────────────────────────────────────────────
{
  const { p } = await page(1280, 820, false);
  await p.goto(`${BASE}/`);
  await p.waitForLoadState("networkidle");
  check((await p.locator(".saldo .cap").innerText()) === "Tu saldo hoy", "el Panel abre con «Tu saldo hoy»");
  const q = p.locator("button.ayuda");
  check((await q.getAttribute("aria-expanded")) === "false", "el «?» empieza cerrado");
  await q.click();
  check((await q.getAttribute("aria-expanded")) === "true", "el «?» se abre");
  check((await p.locator(".ayuda-t").innerText()).includes("Suma todas tus cuentas"), "el «?» explica la cifra con el texto de la app");
  await q.press("Enter");
  check((await p.locator(".ayuda-t").count()) === 0, "Intro sobre el «?» lo vuelve a cerrar");
  check((await p.locator(".cuenta").count()) === 4, "Tus finanzas enseña las cuatro cuentas");
  check((await p.locator(".panel-ult .fila").count()) >= 5, "Últimos registros con la fila de la app");
  check((await p.locator(".panel-ult .pildora").first().innerText()) === "Esencial", "la fila lleva la píldora de necesidad");
  check((await p.locator(".panel-ult .fila").filter({ hasText: "Sueldo" }).locator(".pildora").count()) === 0, "un ingreso no lleva píldora de necesidad");
  check((await p.locator(".dist-f").count()) === 5, "Distribución enseña las cinco categorías del mes");
  check((await p.locator(".plan-c").count()) === 2, "Planificación enseña Pagos planificados y Presupuestos");
  await p.locator('.sec-ir[href="/estadisticas"]').click();
  check(path(p) === "/estadisticas", "la flecha de Distribución lleva a Estadísticas", path(p));
  await p.goBack();
  await p.locator('.plan-c[href="/pagos"]').click();
  check(path(p) === "/pagos", "la tarjeta de Pagos planificados lleva a Pagos", path(p));
  await p.goBack();
  await p.locator('.sec-ir[href="/registros"]').click();
  check(path(p) === "/registros", "la flecha de Últimos registros lleva a Registros", path(p));
  // El ojo tapa las cifras nuevas.
  await p.locator("button.eye").click();
  const blur = await p.evaluate(() =>
    [...document.querySelectorAll("main .amt, main .big, main .monto")].every((e) => {
      for (let x = e; x && x !== document.body; x = x.parentElement) if (getComputedStyle(x).filter.includes("blur")) return true;
      return false;
    }),
  );
  check(blur, "con el ojo, todas las cifras de Registros salen tapadas");
  await p.locator("button.eye").click();
}

// ── Escritorio: Registros ──────────────────────────────────────────────────────────────────────────────────────
{
  const { p, calls } = await page(1280, 820, false);
  await p.goto(`${BASE}/registros`);
  await p.waitForLoadState("networkidle");
  check((await p.locator(".resumen .cap").innerText()) === "Te queda", "Registros abre con «Te queda»");
  check(calls.some((c) => c.url.includes("/api/estadisticas?periodo=mes_actual")), "el resumen sale de Estadísticas del mes");
  check((await p.locator(".reg-det").count()) === 1, "en escritorio el detalle está a la derecha");
  check((await p.locator(".reg-det .det-top b").innerText()) === "Almuerzo menú", "abre con el primer registro");
  await p.locator(".fila").nth(3).click();
  check((await p.locator(".reg-det .det-top b").innerText()) === "Plaza Vea", "tocar otra fila cambia el detalle", await p.locator(".reg-det .det-top b").innerText());
  check((await p.locator('.fila[aria-current="true"]').innerText()).includes("Plaza Vea"), "la fila abierta queda marcada");
  check((await p.locator(".modal").count()) === 0, "en escritorio no se abre hoja");
  check((await p.locator(".dia").first().innerText()).replace(/\s/g, "").includes("−S/51.40"), "el día lleva lo gastado", await p.locator(".dia").first().innerText());
  // Teclado: Tab llega a una fila e Intro la abre.
  await p.locator(".fila").nth(1).focus();
  await p.keyboard.press("Enter");
  check((await p.locator(".reg-det .det-top b").innerText()) === "Café y pan", "Intro sobre una fila la abre a la derecha");
  // Filtros.
  calls.length = 0;
  await p.locator('select[aria-label="Fecha"]').selectOption("pasado");
  await p.waitForLoadState("networkidle");
  check(calls.some((c) => c.url.includes("/api/registros?desde=")), "Mes pasado pide los registros con su rango");
  check(calls.some((c) => c.url.includes("periodo=mes_pasado")), "y el resumen del mes pasado");
  check((await p.locator(".resumen .cap").innerText()) === "Te quedó", "el mes pasado dice «Te quedó»");
  await p.locator('select[aria-label="Cuenta"]').selectOption("Tarjeta Visa");
  await p.waitForLoadState("networkidle");
  check(calls.some((c) => c.url.includes("cuenta=Tarjeta+Visa")), "filtrar por cuenta pide esa cuenta");
  check((await p.locator(".resumen").count()) === 0, "con filtro de cuenta el resumen no sale (no recogería el filtro)");
  check((await p.locator(".cap-sel.on").count()) === 2, "el filtro puesto queda en índigo");
  await p.locator('select[aria-label="Cuenta"]').selectOption("");
  await p.locator('select[aria-label="Fecha"]').selectOption("todo");
  await p.waitForLoadState("networkidle");
  check((await p.locator(".resumen").count()) === 0, "con «Todo» no hay resumen");
  await p.locator('input[aria-label="Buscar en las notas"]').fill("café");
  await p.waitForTimeout(600);
  check(calls.some((c) => c.url.includes("texto=caf")), "buscar en las notas pide el texto");
  await p.locator('input[aria-label="Buscar en las notas"]').fill("");
  await p.waitForTimeout(600);
  const dl = p.waitForEvent("download", { timeout: 5000 }).catch(() => null);
  await p.locator("button.exp").click();
  const d = await dl;
  check(!!d && /\.csv$/.test(d.suggestedFilename()), "Exportar CSV baja el archivo", d?.suggestedFilename() ?? "sin descarga");
}

// ── Escritorio: Nuevo registro ─────────────────────────────────────────────────────────────────────────────────
{
  const { p, calls } = await page(1280, 820, false);
  await p.goto(`${BASE}/`);
  await p.waitForLoadState("networkidle");
  const opener = p.locator("button.add:visible").first();
  await opener.click();
  const sheet = p.locator("form.nr");
  check((await sheet.getAttribute("aria-label")) === "Nuevo registro", "la hoja se llama «Nuevo registro»");
  check(await p.evaluate(() => document.activeElement?.getAttribute("aria-label") === "Importe"), "el foco abre en el monto");
  check((await p.locator(".nr-cur").innerText()) === "S/", "la divisa va con su símbolo");
  check((await p.locator(".nr-dia span").innerText()) === "Hoy", "el día dice «Hoy»");
  // Las categorías llegan al abrir la hoja (`/api/categorias`): las sugeridas aparecen cuando están.
  await p.locator(".nr-chip").nth(2).waitFor({ timeout: 3000 }).catch(() => undefined);
  check((await p.locator(".nr-chip").count()) === 3, "tres categorías sugeridas");
  await p.keyboard.type("12,5");
  await p.locator(".nr-chip").first().click();
  check((await p.locator(".nr-chip").first().getAttribute("aria-pressed")) === "true", "la sugerida queda elegida");
  check((await p.locator('select[aria-label="Categoría"]').inputValue()) !== "", "y se ve en la cápsula Categoría");
  await p.locator('input[aria-label="Descripción"]').fill("Prueba");
  calls.length = 0;
  await p.locator('input[aria-label="Descripción"]').press("Enter");
  await p.waitForTimeout(400);
  const post = calls.find((c) => c.method === "POST" && c.url.endsWith("/api/borradores"));
  const body = post ? JSON.parse(post.body) : {};
  check(!!post && body.importe === 12.5 && body.tipo === "gasto" && body.descripcion === "Prueba" && !!body.subcategoria, "Intro envía el borrador con monto, descripción y categoría", post?.body ?? "sin envío");
  check((await p.locator(".toast").innerText().catch(() => "")).includes("Bandeja"), "y avisa que va a la Bandeja");
  await opener.click();
  await p.locator(".nr-tipo button", { hasText: "Ingreso" }).click();
  check((await p.locator(".nr-q").innerText()) === "¿Cuánto recibiste?", "con Ingreso pregunta «¿Cuánto recibiste?»");
  check((await p.locator(".nr-chip").count()) <= 1, "las sugeridas cambian a las de ingreso");
  await p.keyboard.press("Escape");
  check((await p.locator("form.nr").count()) === 0, "Esc cierra la hoja");
}

// ── Celular (390 px) ───────────────────────────────────────────────────────────────────────────────────────────
{
  const { p } = await page(390, 844, true);
  for (const r of ["/", "/registros"]) {
    await p.goto(`${BASE}${r}`);
    await p.waitForLoadState("networkidle");
    check(await noScroll(p), `${r} a 390 px sin scroll lateral`);
  }
  await p.goto(`${BASE}/`);
  await p.waitForLoadState("networkidle");
  const order = await p.evaluate(() => {
    const s = document.querySelector(".saldo")?.getBoundingClientRect().top ?? 0;
    const a = document.querySelector(".acts .add")?.getBoundingClientRect().top ?? 0;
    return a > s;
  });
  check(order, "en el celular «+ Nuevo registro» va debajo del saldo, como en la app");
  await p.goto(`${BASE}/registros`);
  await p.waitForLoadState("networkidle");
  check((await p.locator(".reg-det").count()) === 0, "en el celular no hay detalle a la derecha");
  await p.locator(".fila").first().click();
  check((await p.locator(".det-sheet").count()) === 1, "tocar una fila abre el detalle en hoja");
  check(await noScroll(p), "la hoja del detalle no desborda");
  await p.locator(".det-sheet button.cerrar").click();
  check((await p.locator(".det-sheet").count()) === 0, "la ✕ la cierra");
  await p.locator("button.add:visible").first().click();
  check(await noScroll(p), "la hoja «Nuevo registro» cabe en 390 px");
  const box = await p.locator("form.nr").boundingBox();
  check(!!box && box.x >= 0 && box.x + box.width <= 390.5, "la hoja va a todo el ancho", JSON.stringify(box));
}

await browser.close();
console.log(fails === 0 ? "\nTodo en verde." : `\n${fails} comprobaciones en rojo.`);
process.exit(fails === 0 ? 0 : 1);
