/**
 * Las páginas que ve el usuario al conectar Claude, renderizadas en servidor y sin JavaScript.
 *
 * Todo texto que viene del cliente (su nombre lo elige quien se registra por DCR) es NO confiable: se escapa, y la
 * página enseña siempre el dominio de vuelta, que es lo que de verdad identifica a dónde irá el acceso.
 */
import type { AuthRequest, ClientInfo } from "@cloudflare/workers-oauth-provider";

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

export function page(title: string, body: string, status = 200, extra?: Headers): Response {
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title><style>
:root{color-scheme:light dark;--bg:#f6f6f8;--card:#fff;--fg:#1c1c1e;--muted:#6b6b70;--accent:#5b4bff;--line:#e3e3e8;--warn:#9a5b00}
@media (prefers-color-scheme:dark){:root{--bg:#0f0f12;--card:#1b1b20;--fg:#f2f2f5;--muted:#9a9aa2;--line:#2c2c33;--warn:#f0b35a}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,system-ui,sans-serif;display:flex;justify-content:center;padding:32px 16px}
main{background:var(--card);border:1px solid var(--line);border-radius:16px;max-width:420px;width:100%;padding:24px}
h1{font-size:20px;margin:0 0 8px}p,li{color:var(--muted)}strong{color:var(--fg)}.warn{color:var(--warn)}
label{display:block;margin:12px 0 4px;font-size:14px}input{width:100%;box-sizing:border-box;padding:10px;border:1px solid var(--line);border-radius:10px;background:transparent;color:var(--fg);font:inherit}
button{font:inherit;padding:10px 16px;border-radius:10px;border:1px solid var(--line);background:transparent;color:var(--fg);cursor:pointer}
button.primary{background:var(--accent);border-color:var(--accent);color:#fff}.row{display:flex;gap:8px;margin-top:20px;justify-content:flex-end}
.tag{display:inline-block;font-size:12px;padding:2px 8px;border-radius:99px;border:1px solid var(--line);color:var(--muted)}
</style></head><body><main>${body}</main></body></html>`;
  const headers = new Headers(extra);
  for (const [k, v] of Object.entries(SECURITY_HEADERS)) headers.set(k, v);
  return new Response(html, { status, headers });
}

export function errorPage(message: string, status = 400, extra?: Headers): Response {
  return page("Yala", `<h1>No se pudo continuar</h1><p>${escapeHtml(message)}</p>`, status, extra);
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
export function consentPage(client: ClientInfo, request: AuthRequest, handle: string, headers: Headers, staging: boolean): Response {
  const name = client.clientName?.trim() || "Una aplicación";
  const host = new URL(request.redirectUri).hostname;
  const local = isLoopback(host);
  const where = local
    ? `<p class="warn"><strong>El acceso irá a una aplicación de tu computadora.</strong> Sigue solo si acabas de empezar la conexión desde ella.</p>`
    : `<p>Volverá a: <strong>${escapeHtml(host)}</strong></p>`;
  const body = `<h1>${escapeHtml(name)} quiere leer tus datos de Yala</h1>
${staging ? STAGING_TAG : ""}${where}
<p>El nombre «${escapeHtml(name)}» lo eligió la propia aplicación al registrarse.</p>
<p>Si continúas, inicias sesión en Yala y podrá <strong>leer</strong>:</p>
<ul><li>tus cuentas y sus saldos</li><li>tus movimientos, categorías y etiquetas</li><li>tus presupuestos</li><li>tus pagos recurrentes</li></ul>
<p><strong>No podrá</strong> crear, cambiar ni borrar nada: ni tus finanzas ni los datos de tu cuenta. Tampoco verá tus grupos. Puedes quitarle el acceso cuando quieras.</p>
<form method="post" action="/authorize">
<input type="hidden" name="handle" value="${escapeHtml(handle)}">
<div class="row"><button name="decision" value="deny" type="submit">No permitir</button>
<button class="primary" name="decision" value="approve" type="submit">Continuar</button></div></form>`;
  return page(`Conectar Yala con ${name}`, body, 200, headers);
}

/** Inicio de sesión en Yala tras el permiso. Solo existe en staging: en producción, Apple y Google (fase 1). */
export function loginPage(authorizationId: string, message?: string): Response {
  const warning = message ? `<p><strong>${escapeHtml(message)}</strong></p>` : "";
  return page(
    "Iniciar sesión en Yala",
    `<h1>Inicia sesión en Yala</h1><p>Entra con tu cuenta de Yala en la nube para terminar de conectar.</p>
${STAGING_TAG}${warning}
<form method="post" action="/oauth/consent">
<input type="hidden" name="authorization_id" value="${escapeHtml(authorizationId)}">
<label for="email">Email</label><input id="email" name="email" type="email" autocomplete="username" required>
<label for="password">Contraseña</label><input id="password" name="password" type="password" autocomplete="current-password" required>
<div class="row"><button class="primary" type="submit">Continuar</button></div></form>`,
    message ? 401 : 200,
  );
}
