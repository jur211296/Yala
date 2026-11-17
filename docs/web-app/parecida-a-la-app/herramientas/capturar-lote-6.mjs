// capturar-lote-6.mjs <base> <carpeta> <prefijo> — capturas de antes y después del lote 6 (Entrar y el código QR), en
// claro y oscuro, escritorio (1280 × 820) y celular (390 × 844, táctil), con el servidor de maqueta en <base>:
//
//   PW=<carpeta con node_modules/playwright-core> node capturar-lote-6.mjs http://localhost:8787 <carpeta> antes
//
// El servidor de maqueta siempre tiene sesión: aquí se interceptan `/api/me` (401), `/api/config` y `/auth/qr/*` para
// que la web enseñe la entrada. Turnstile es el de verdad, con la clave de prueba de Cloudflare que SIEMPRE pide
// interacción (`3x…FF`): así el widget se ve en la captura y se comprueba que se lee en los dos temas.
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
// Claves de prueba de Cloudflare: una siempre pide interacción (el widget se ve) y otra siempre pasa (habilita los botones).
const RETO = "3x00000000000000000000FF";
const PASA = "1x00000000000000000000AA";

/** Cada pantalla: la dirección, si espera a Turnstile y, si hace falta, el toque que la abre. */
const PANTALLAS = [
  { id: "entrar", path: "/", turnstile: true },
  // El QR: con la clave que siempre pasa, el botón se habilita solo y se pulsa.
  { id: "qr", path: "/", qr: true },
  { id: "qr-caducado", path: "/", qr: true, caducado: true },
  { id: "camara", path: "/v/ABCD-1234" },
  { id: "sin-nube", path: "/?aviso=sin-nube" },
  { id: "aviso-salida", path: "/?aviso=salida", turnstile: true },
];

async function rutas(page, { caducado = false, qr = false } = {}) {
  const SITE_KEY = qr ? PASA : RETO;
  await page.route("**/api/me", (r) => r.fulfill({ status: 401, contentType: "application/json", body: "{}" }));
  await page.route("**/api/config", (r) => r.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ turnstileSiteKey: SITE_KEY }) }));
  await page.route("**/auth/qr/start", (r) =>
    r.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ codigo: "K7QM-4XRT", url: "https://app.yala-app.pe/v/K7QM-4XRT", expira: Math.floor(Date.now() / 1000) + 60 }),
    }),
  );
  await page.route("**/auth/qr/estado", (r) => r.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ estado: caducado ? "error" : "esperando" }) }));
}

const browser = await chromium.launch({ executablePath: CHROME, headless: true });
for (const [tema, scheme] of [["claro", "light"], ["oscuro", "dark"]]) {
  for (const [aparato, vp, movil] of [["escritorio", { width: 1280, height: 820 }, false], ["movil", { width: 390, height: 844 }, true]]) {
    const ctx = await browser.newContext({ viewport: vp, deviceScaleFactor: 2, colorScheme: scheme, hasTouch: movil, isMobile: movil, locale: "es-419" });
    for (const s of PANTALLAS) {
      const p = await ctx.newPage();
      await rutas(p, s);
      await p.goto(BASE + s.path);
      await p.waitForLoadState("networkidle");
      if (s.turnstile) {
        // El widget vive en un shadow DOM cerrado (ningún selector lo alcanza): se le dan unos segundos para pintar su reto.
        await p.waitForTimeout(4500);
      }
      if (s.qr) {
        const b = p.getByRole("button", { name: /iPhone/ });
        await b.waitFor();
        await p.waitForFunction(() => [...document.querySelectorAll("button")].some((x) => /iPhone/.test(x.textContent ?? "") && !x.disabled), null, { timeout: 15000 });
        await b.click();
        await p.waitForTimeout(s.caducado ? 3500 : 800);
      }
      await p.waitForTimeout(300);
      const file = `${OUT}/${PRE}-${s.id}-${tema}-${aparato}.png`;
      await p.screenshot({ path: file });
      await p.close();
      console.log("ok", file);
    }
    await ctx.close();
  }
}
await browser.close();
