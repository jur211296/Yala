/**
 * Las páginas que ve el usuario al conectar su IA, renderizadas en servidor y sin JavaScript.
 *
 * Todo texto que viene del cliente (su nombre lo elige quien se registra por DCR) es NO confiable: se escapa, y la
 * página enseña siempre el dominio de vuelta, que es lo que de verdad identifica a dónde irá el acceso. La marca
 * «× Claude» de la cabecera sale de esa vuelta (`clientLabelFromRedirects`), nunca del nombre elegido.
 *
 * Marca de la web de Yala (encargo «Conecta tu IA», 2026-11-23): logo en SVG dentro de la página, índigo, cian y rosa,
 * y la tipografía del sistema (la CSP no carga nada de fuera: sin `font-src`). Botones oficiales «Continuar con Apple»
 * (negro en claro, blanco en oscuro, guía de Apple) y «Continuar con Google» (blanco o gris oscuro con la G de color,
 * guía de Google). Sin página «Listo»: tras iniciar sesión se vuelve directo a la IA (decisión 5 de Jürgen).
 */
import type { AuthRequest, ClientInfo } from "@cloudflare/workers-oauth-provider";
import { clientLabelFromRedirects } from "./writeTool";

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] as string);
}

const SECURITY_HEADERS: Record<string, string> = {
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store",
  // Sin scripts, sin recursos externos, y nadie puede meter esta página en un iframe (clickjacking sobre «Continuar»).
  // form-action no se fija: Chrome la aplica también a la redirección final hacia el callback de Claude.
  "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

/** El logo de la web (`Web/public/logo.svg`): la palabra, el punto cian y el subrayado rosa. */
const LOGO = `<svg class="logo" viewBox="0 0 78 40" role="img" aria-label="Yala"><text x="0" y="30" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, system-ui, sans-serif" font-size="28" font-weight="700" fill="currentColor">Yala</text><circle cx="70" cy="9" r="5" fill="#00F3FF"/><rect x="25" y="35" width="35" height="4" rx="2" fill="#FF0080"/></svg>`;

const APPLE_LOGO = `<svg viewBox="0 0 814 1000" aria-hidden="true"><path fill="currentColor" d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57-155.5-127C46.7 790.7 0 663 0 541.8c0-194.4 126.4-297.5 250.8-297.5 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/></svg>`;

const GOOGLE_LOGO = `<svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>`;

const STYLE = `
*,*::before,*::after{box-sizing:border-box}
:root{color-scheme:light dark;--bg:#FAFAFC;--card:#FFFFFF;--fg:#0F172A;--muted:#475569;--line:#E2E8F0;--accent:#4F46E5;--accent-text:#4F46E5;--soft:#EEF0FF;--ok:#15803D;--ok-bg:#DCFCE7;--no:#B91C1C;--no-bg:#FEE2E2;--warn:#92400E;--warn-bg:#FEF3C7;--glow:rgba(99,102,241,.20)}
@media (prefers-color-scheme:dark){:root{--bg:#0F172A;--card:#1E293B;--fg:#F1F5F9;--muted:#94A3B8;--line:#334155;--accent:#4F46E5;--accent-text:#A5B4FC;--soft:#262E5A;--ok:#4ADE80;--ok-bg:rgba(34,197,94,.16);--no:#FCA5A5;--no-bg:rgba(239,68,68,.16);--warn:#FCD34D;--warn-bg:#3A2E0F;--glow:rgba(99,102,241,.28)}}
html{-webkit-text-size-adjust:100%}
body{margin:0;min-height:100vh;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif;display:flex;flex-direction:column;align-items:center;padding:28px 16px 24px;background-image:radial-gradient(ellipse 80% 45% at 50% -10%,var(--glow),transparent)}
.wrap{width:100%;max-width:440px;display:flex;flex-direction:column;gap:16px}
.brand{display:flex;align-items:center;gap:10px;padding:0 4px}
.logo{height:30px;width:auto;color:var(--fg)}
.brand .x{color:var(--muted);font-size:15px}.brand .ai{font-weight:600;font-size:16px}
main{background:var(--card);border:1px solid var(--line);border-radius:20px;width:100%;padding:24px 20px;box-shadow:0 1px 2px rgba(15,23,42,.04),0 12px 32px -18px rgba(15,23,42,.25)}
h1{font-size:23px;line-height:1.2;letter-spacing:-.02em;margin:0 0 10px;text-wrap:balance;overflow-wrap:anywhere}
p{margin:10px 0;color:var(--muted)}strong{color:var(--fg)}
.step{font-size:13px;font-weight:600;color:var(--accent-text);margin:0 0 6px;letter-spacing:.01em}
.dest{display:flex;flex-wrap:wrap;align-items:center;gap:6px;font-size:14px;color:var(--muted);margin:0 0 14px}
.dest code{font:600 14px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--soft);color:var(--fg);border-radius:6px;padding:2px 8px;overflow-wrap:anywhere}
.warn{color:var(--warn)}.warn strong{color:var(--warn)}
.can{list-style:none;margin:14px 0;padding:14px;border:1px solid var(--line);border-radius:14px;display:flex;flex-direction:column;gap:12px}
.can li{display:flex;gap:10px;align-items:flex-start;font-size:15px;color:var(--muted)}
.can .k{flex:0 0 22px;height:22px;border-radius:7px;display:grid;place-items:center;font-size:12px;font-weight:700;margin-top:1px}
.k.y{background:var(--ok-bg);color:var(--ok)}.k.p{background:var(--soft);color:var(--accent-text)}.k.n{background:var(--no-bg);color:var(--no)}
.note{background:var(--warn-bg);border-radius:14px;padding:12px 14px;margin:14px 0}.note p{margin:0;color:var(--warn);font-size:14px}.note strong{color:var(--warn)}
.fine{font-size:13px}
label{display:block;margin:12px 0 4px;font-size:14px;color:var(--fg)}
input{width:100%;padding:11px 12px;border:1px solid var(--line);border-radius:10px;background:transparent;color:var(--fg);font:inherit}
button{font:600 16px/1.2 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif;min-height:48px;padding:12px 16px;border-radius:12px;border:1px solid var(--line);background:transparent;color:var(--fg);cursor:pointer;width:100%}
button.primary{background:var(--accent);border-color:var(--accent);color:#fff}
.row{display:flex;gap:10px;margin-top:20px}.row>*{flex:1}
form{margin:0}
.social{display:flex;flex-direction:column;gap:12px;margin-top:20px}
.social button{display:flex;align-items:center;justify-content:center;gap:10px;min-height:48px;border-radius:10px;font-weight:500;font-size:17px}
.social svg{flex:0 0 auto}
button.apple{background:#000;border-color:#000;color:#fff}.apple svg{width:16px;height:19px;margin-top:-2px}
button.google{background:#fff;border-color:#747775;color:#1F1F1F}.google svg{width:20px;height:20px}
@media (prefers-color-scheme:dark){button.apple{background:#fff;border-color:#fff;color:#000}button.google{background:#131314;border-color:#8E918F;color:#E3E3E3}}
details{margin-top:20px}summary{cursor:pointer;color:var(--muted);font-size:14px}
.tag{display:inline-block;font-size:12px;padding:2px 10px;border-radius:99px;border:1px solid var(--line);color:var(--muted)}
.mark{width:48px;height:48px;border-radius:50%;display:grid;place-items:center;font-size:24px;font-weight:700;background:var(--warn-bg);color:var(--warn);margin-bottom:14px}
footer{text-align:center;font-size:13px;color:var(--muted)}
@media (max-width:360px){main{padding:20px 16px}h1{font-size:21px}.row{flex-direction:column-reverse}}
`;

export interface PageOptions {
  /** El nombre de la IA que pide, si se conoce por su vuelta: «Yala × Claude» en la cabecera. */
  ai?: string | null;
}

export function page(title: string, body: string, status = 200, extra?: Headers, opts: PageOptions = {}): Response {
  const ai = opts.ai ? `<span class="x" aria-hidden="true">×</span><span class="ai">${escapeHtml(opts.ai)}</span>` : "";
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title><style>${STYLE}</style></head><body><div class="wrap">
<header class="brand">${LOGO}${ai}</header>
<main>${body}</main>
<footer>yala-app.pe</footer>
</div></body></html>`;
  const headers = new Headers(extra);
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) headers.set(k, v);
  return new Response(html, { status, headers });
}

export function errorPage(message: string, status = 400, extra?: Headers): Response {
  return page("Yala", `<div class="mark" aria-hidden="true">!</div><h1>No se pudo continuar</h1><p>${escapeHtml(message)}</p>`, status, extra);
}

const STAGING_TAG = `<p><span class="tag">staging · solo cuentas de prueba</span></p>`;

function isLoopback(host: string): boolean {
  return host === "localhost" || host === "[::1]" || /^127(\.\d{1,3}){3}$/.test(host);
}

/**
 * El permiso, por cliente, ANTES de mandar al usuario a iniciar sesión. Es lo que pide la guía de seguridad de MCP
 * para un servidor que autentica a través de otro (el «confused deputy»): quién pide, a dónde volverá el acceso, y
 * qué podrá hacer. `handle` liga el formulario a este navegador (cookie `__Host-` de la librería).
 */
export function consentPage(
  client: ClientInfo,
  request: AuthRequest,
  handle: string,
  headers: Headers,
  staging: boolean,
  canDraft = false,
): Response {
  const name = client.clientName?.trim() || "Una aplicación";
  const host = new URL(request.redirectUri).hostname;
  const local = isLoopback(host);
  const where = local
    ? `<p class="warn"><strong>El acceso irá a una aplicación de tu computadora.</strong> Sigue solo si acabas de empezar la conexión desde ella.</p>`
    : `<p class="dest">Volverá a: <code>${escapeHtml(host)}</code></p>`;
  // Con la cola de la Bandeja enlazada (`CONNECTOR_DRAFTS`) el conector ofrece `apuntar_movimiento`: el permiso lo dice.
  const draftItem = canDraft
    ? `<li><span class="k p" aria-hidden="true">✦</span><span>Y podrá <strong>apuntar</strong> gastos e ingresos como borradores en tu Bandeja. Ninguno cuenta hasta que tú lo confirmes en la app.</span></li>`
    : "";
  const cannot = canDraft
    ? `<li><span class="k n" aria-hidden="true">✕</span><span><strong>No podrá</strong> cambiar ni borrar nada, ni confirmar un borrador: ni tus finanzas ni los datos de tu cuenta. Tampoco verá tus grupos.</span></li>`
    : `<li><span class="k n" aria-hidden="true">✕</span><span><strong>No podrá</strong> crear, cambiar ni borrar nada: ni tus finanzas ni los datos de tu cuenta. Tampoco verá tus grupos.</span></li>`;
  const body = `<p class="step">Paso 1 de 2</p><h1>${escapeHtml(name)} quiere ${canDraft ? "usar" : "leer"} tus datos de Yala</h1>
${staging ? STAGING_TAG : ""}${where}
<ul class="can">
<li><span class="k y" aria-hidden="true">✓</span><span>Si continúas, inicias sesión en Yala y podrá <strong>leer</strong> tus cuentas y sus saldos, tus movimientos, categorías y etiquetas, tus presupuestos y tus pagos recurrentes.</span></li>
${draftItem}${cannot}
</ul>
${CLOUD_ONLY_NOTE}
<form method="post" action="/authorize">
<input type="hidden" name="handle" value="${escapeHtml(handle)}">
<div class="row"><button name="decision" value="deny" type="submit">No permitir</button>
<button class="primary" name="decision" value="approve" type="submit">Continuar</button></div></form>
<p class="fine">Puedes quitarle el acceso cuando quieras. El nombre «${escapeHtml(name)}» lo eligió la propia aplicación al registrarse.</p>`;
  const ai = clientLabelFromRedirects(client.redirectUris ?? []);
  return page(`Conectar Yala con ${name}`, body, 200, headers, { ai });
}

/**
 * El aviso para quien guarda sus datos en su iCloud (decisión de Jürgen del 2026-10-29): el conector solo lee la nube de
 * Yala, y quien está en iCloud privado no verá nada. Es solo un aviso: no bloquea. Va en el permiso, antes de iniciar
 * sesión, porque iniciar sesión con Apple o Google en una cuenta que no existe la crea vacía.
 */
export const CLOUD_ONLY_NOTE = `<div class="note"><p><strong>Solo funciona con la nube de Yala.</strong> Si tus datos viven en tu iCloud, esta aplicación no podrá verlos. Para usarlo, en Yala ve a Ajustes → «Dónde viven tus datos» → «Activar la nube», y luego vuelve a conectar.</p></div>`;

export type SocialProvider = "apple" | "google";

/**
 * Inicio de sesión en Yala tras el permiso: con Apple o con Google, la misma cuenta que usa en la app. Cada botón es un
 * formulario sin JavaScript que manda a Supabase (`authorize.ts`, `startSocialLogin`).
 *
 * El email y la contraseña solo existen en staging, plegados, para las cuentas de prueba y el e2e. En producción no se
 * pintan y `authorize.ts` los rechaza aunque alguien los mande.
 */
export function loginPage(authorizationId: string, opts: { staging: boolean; message?: string; status?: number }): Response {
  const id = escapeHtml(authorizationId);
  const warning = opts.message ? `<div class="note"><p><strong>${escapeHtml(opts.message)}</strong></p></div>` : "";
  const social = (provider: SocialProvider, label: string, logo: string) =>
    `<form method="post" action="/oauth/consent/social"><input type="hidden" name="authorization_id" value="${id}"><input type="hidden" name="provider" value="${provider}"><button class="${provider}" type="submit">${logo}<span>${label}</span></button></form>`;
  const password = opts.staging
    ? `<details${opts.message && opts.status === 401 ? " open" : ""}><summary>Cuenta de prueba (solo staging)</summary>
<form method="post" action="/oauth/consent">
<input type="hidden" name="authorization_id" value="${id}">
<label for="email">Email</label><input id="email" name="email" type="email" autocomplete="username" required>
<label for="password">Contraseña</label><input id="password" name="password" type="password" autocomplete="current-password" required>
<div class="row"><button class="primary" type="submit">Continuar</button></div></form></details>`
    : "";
  return page(
    "Iniciar sesión en Yala",
    `<p class="step">Paso 2 de 2</p><h1>Inicia sesión en Yala</h1><p>Usa la misma cuenta con la que entras en la app para terminar de conectar.</p>
${opts.staging ? STAGING_TAG : ""}${warning}
<div class="social">${social("apple", "Continuar con Apple", APPLE_LOGO)}${social("google", "Continuar con Google", GOOGLE_LOGO)}</div>
${password}`,
    opts.status ?? (opts.message ? 401 : 200),
  );
}
