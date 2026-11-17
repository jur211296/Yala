// recorrido-lote-6.mjs <base> [carpeta] — el recorrido del lote 6 (la entrada) en un Chromium sin cabeza, contra un
// despliegue de verdad (staging o producción), en escritorio y celular y con el sistema en claro y en oscuro:
//
//   PW=<carpeta con node_modules/playwright-core> node recorrido-lote-6.mjs https://yala-web-staging.misty-surf-6866.workers.dev
//
// Comprueba que: el fondo de la entrada es el de la bienvenida (oscuro con el sistema en claro también); Turnstile da
// su permiso y enciende los tres botones; «Continuar con Apple» y «Continuar con Google» llevan a la página de Apple y
// de Google; «Entrar con tu iPhone» enseña un QR y un código del servidor, y «Volver» regresa con los botones; y las
// direcciones de siempre (/registros, /presupuestos, /pagos…) siguen abriendo la entrada sin sesión.
// Con [carpeta], deja una captura de cada paso. No escribe nada en la cuenta: no llega a entrar.
import { createRequire } from "node:module";
import { homedir } from "node:os";

const require = createRequire(`${process.env.PW ?? process.cwd()}/`);
const { chromium } = require("playwright-core");
const [BASE, OUT] = process.argv.slice(2);
if (!BASE) throw new Error("falta la base");
const CHROME =
  process.env.CHROME ??
  `${homedir()}/Library/Caches/ms-playwright/chromium_headless_shell-1243/chrome-headless-shell-mac-arm64/chrome-headless-shell`;

let fallos = 0;
const ok = (cond, msg) => {
  console.log(`${cond ? "✓" : "✗"} ${msg}`);
  if (!cond) fallos++;
};

const browser = await chromium.launch({ executablePath: CHROME, headless: true });
for (const [tema, scheme] of [["claro", "light"], ["oscuro", "dark"]]) {
  for (const [aparato, vp, movil] of [["escritorio", { width: 1280, height: 820 }, false], ["movil", { width: 390, height: 844 }, true]]) {
    const tag = `${tema}/${aparato}`;
    const ctx = await browser.newContext({ viewport: vp, colorScheme: scheme, hasTouch: movil, isMobile: movil, locale: "es-419" });
    const p = await ctx.newPage();
    await p.goto(BASE + "/");
    await p.getByRole("heading", { name: "Entra a tu Yala" }).waitFor({ timeout: 15000 });
    const fondo = await p.evaluate(() => getComputedStyle(document.body).backgroundColor);
    ok(fondo === "rgb(8, 8, 26)", `${tag}: fondo de la bienvenida (${fondo})`);
    const apple = p.getByRole("button", { name: "Continuar con Apple" });
    const google = p.getByRole("button", { name: "Continuar con Google" });
    const iphone = p.getByRole("button", { name: "Entrar con tu iPhone" });
    await p.waitForFunction(() => [...document.querySelectorAll("form button")].every((b) => !b.disabled), null, { timeout: 20000 }).catch(() => {});
    ok((await apple.isEnabled()) && (await google.isEnabled()) && (await iphone.isEnabled()), `${tag}: Turnstile enciende los tres botones`);
    if (OUT) await p.screenshot({ path: `${OUT}/staging-entrar-${tema}-${aparato}.png` });

    // El QR: un código de verdad del servidor, y «Volver» regresa.
    await iphone.click();
    await p.getByRole("heading", { name: "Abre Yala con tu iPhone" }).waitFor();
    await p.locator(".e-qr[role=img]").waitFor({ timeout: 10000 });
    const codigo = (await p.locator(".e-codigo").textContent())?.trim() ?? "";
    ok(/^[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(codigo), `${tag}: QR con código del servidor (${codigo ? "····-····" : "vacío"})`);
    if (OUT) await p.screenshot({ path: `${OUT}/staging-qr-${tema}-${aparato}.png` });
    await p.getByRole("button", { name: "Volver" }).click();
    await p.getByRole("heading", { name: "Entra a tu Yala" }).waitFor();
    await p.waitForFunction(() => [...document.querySelectorAll("form button")].every((b) => !b.disabled), null, { timeout: 20000 }).catch(() => {});

    // Apple y Google: el formulario sale hacia su página (vía Supabase) con el permiso de Turnstile.
    for (const [boton, host] of [[apple, "appleid.apple.com"], [google, "accounts.google.com"]]) {
      await Promise.all([p.waitForURL((u) => u.hostname === host, { timeout: 20000 }).catch(() => {}), boton.click()]);
      ok(new URL(p.url()).hostname === host, `${tag}: llega a ${host}`);
      await p.goto(BASE + "/");
      await p.waitForFunction(() => [...document.querySelectorAll("form button")].every((b) => !b.disabled), null, { timeout: 20000 }).catch(() => {});
    }
    await ctx.close();
  }
}

// Las direcciones de siempre siguen abriendo (sin sesión, la entrada).
const ctx = await browser.newContext({ locale: "es-419" });
const p = await ctx.newPage();
for (const ruta of ["/registros", "/presupuestos", "/pagos", "/estadisticas", "/grupos", "/bandeja", "/configurar"]) {
  const r = await p.goto(BASE + ruta);
  await p.getByRole("heading", { name: "Entra a tu Yala" }).waitFor({ timeout: 15000 }).catch(() => {});
  ok(r?.status() === 200 && (await p.getByRole("heading", { name: "Entra a tu Yala" }).count()) === 1, `${ruta}: 200 y la entrada`);
}
await browser.close();
console.log(fallos ? `${fallos} fallos` : "todo en verde");
process.exit(fallos ? 1 : 0);
