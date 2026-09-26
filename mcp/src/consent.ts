/**
 * Pantalla de consentimiento del servidor OAuth de Supabase. Supabase redirige aquí
 * (Site URL + `/oauth/consent?authorization_id=…`) y es esta página la que dice «sí» o «no» en nombre del usuario.
 *
 * Flujo, todo en servidor y sin JavaScript en el navegador:
 *   1. GET  /oauth/consent?authorization_id=…  → formulario de inicio de sesión.
 *   2. POST /oauth/consent (email + contraseña)  → inicia sesión en Supabase, pide los detalles de la autorización y
 *      enseña QUIÉN pide acceso, A QUÉ DOMINIO volverá y qué podrá leer. Guarda el token de esa sesión en una cookie
 *      HttpOnly de 5 minutos atada al authorization_id.
 *   3. POST /oauth/consent/decision (aprobar | denegar) → lo manda a Supabase, CIERRA la sesión web (su token puede
 *      escribir; no debe sobrevivir a esta página) y redirige a lo que Supabase devuelva.
 *
 * Fase 0: solo email y contraseña, que es lo que tienen los usuarios de prueba de staging. En producción los
 * usuarios entran con Apple o Google, y eso necesita un Services ID de Apple y un cliente web de Google (fase 1).
 *
 * El nombre del cliente lo elige quien se registra por DCR, así que es texto NO confiable: se escapa, y la página
 * enseña siempre el dominio de vuelta, que es lo que de verdad identifica a dónde irá el código.
 */
import { authIssuer, type Env } from "./env";
import type { Fetcher } from "./data";

const COOKIE = "yala_mcp_consent";

/**
 * Dominios a los que la pantalla acepta devolver el código. Con DCR abierto cualquiera registra un cliente llamado
 * «Claude» que vuelve a su propio dominio; enseñar el dominio no basta si el usuario no lo lee. Fase 0: solo Claude
 * (claude.ai / claude.com, que usan claude.ai y Desktop) y el loopback de Claude Code. Cualquier otro se rechaza
 * antes de pedir el permiso. Si el día de mañana hace falta otro cliente, se añade aquí a propósito.
 */
const ALLOWED_REDIRECT_HOSTS = new Set(["claude.ai", "claude.com"]);
const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

export function isAllowedRedirect(uri: string | undefined): boolean {
  if (!uri) return false;
  let u: URL;
  try {
    u = new URL(uri);
  } catch {
    return false;
  }
  if (LOOPBACK_HOSTS.has(u.hostname)) return u.protocol === "http:" || u.protocol === "https:";
  return u.protocol === "https:" && ALLOWED_REDIRECT_HOSTS.has(u.hostname);
}
const COOKIE_MAX_AGE = 300;
const AUTH_ID_RE = /^[A-Za-z0-9_-]{8,128}$/;

interface AuthorizationDetails {
  authorization_id?: string;
  redirect_uri?: string;
  redirect_url?: string;
  scope?: string;
  client?: { id?: string; client_id?: string; name?: string; client_name?: string; uri?: string };
  user?: { id?: string; email?: string };
}

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] as string);
}

const SECURITY_HEADERS: Record<string, string> = {
  "Content-Type": "text/html; charset=utf-8",
  "Cache-Control": "no-store",
  // Sin scripts, sin recursos externos, y nadie puede meter esta página en un iframe (clickjacking sobre «Autorizar»).
  // form-action no se fija: Chrome la aplica también a la redirección final hacia el callback de Claude.
  "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
};

function page(title: string, body: string, status = 200, extraHeaders: Record<string, string> = {}): Response {
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escapeHtml(title)}</title><style>
:root{color-scheme:light dark;--bg:#f6f6f8;--card:#fff;--fg:#1c1c1e;--muted:#6b6b70;--accent:#5b4bff;--line:#e3e3e8}
@media (prefers-color-scheme:dark){:root{--bg:#0f0f12;--card:#1b1b20;--fg:#f2f2f5;--muted:#9a9aa2;--line:#2c2c33}}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,system-ui,sans-serif;display:flex;justify-content:center;padding:32px 16px}
main{background:var(--card);border:1px solid var(--line);border-radius:16px;max-width:420px;width:100%;padding:24px}
h1{font-size:20px;margin:0 0 8px}p,li{color:var(--muted)}strong{color:var(--fg)}
label{display:block;margin:12px 0 4px;font-size:14px}input{width:100%;box-sizing:border-box;padding:10px;border:1px solid var(--line);border-radius:10px;background:transparent;color:var(--fg);font:inherit}
button{font:inherit;padding:10px 16px;border-radius:10px;border:1px solid var(--line);background:transparent;color:var(--fg);cursor:pointer}
button.primary{background:var(--accent);border-color:var(--accent);color:#fff}.row{display:flex;gap:8px;margin-top:20px;justify-content:flex-end}
.tag{display:inline-block;font-size:12px;padding:2px 8px;border-radius:99px;border:1px solid var(--line);color:var(--muted)}
</style></head><body><main>${body}</main></body></html>`;
  return new Response(html, { status, headers: { ...SECURITY_HEADERS, ...extraHeaders } });
}

function errorPage(message: string, status = 400): Response {
  return page("Yala", `<h1>No se pudo continuar</h1><p>${escapeHtml(message)}</p>`, status, { "Set-Cookie": clearCookie() });
}

function clearCookie(): string {
  return `${COOKIE}=; Path=/oauth; HttpOnly; Secure; SameSite=Strict; Max-Age=0`;
}

function readCookie(request: Request): { authorizationId: string; token: string } | null {
  const header = request.headers.get("Cookie") ?? "";
  for (const part of header.split(/;\s*/)) {
    const eq = part.indexOf("=");
    if (eq < 0 || part.slice(0, eq) !== COOKIE) continue;
    const value = part.slice(eq + 1);
    const dot = value.indexOf(".");
    if (dot < 0) return null;
    const authorizationId = value.slice(0, dot);
    const token = value.slice(dot + 1);
    if (!AUTH_ID_RE.test(authorizationId) || !token) return null;
    return { authorizationId, token };
  }
  return null;
}

function loginForm(authorizationId: string, message?: string): Response {
  const warning = message ? `<p><strong>${escapeHtml(message)}</strong></p>` : "";
  return page(
    "Conectar Yala",
    `<h1>Conectar Yala</h1><p>Inicia sesión con tu cuenta de Yala en la nube para decidir si das acceso.</p>
<p><span class="tag">staging · solo cuentas de prueba</span></p>${warning}
<form method="post" action="/oauth/consent">
<input type="hidden" name="authorization_id" value="${escapeHtml(authorizationId)}">
<label for="email">Email</label><input id="email" name="email" type="email" autocomplete="username" required>
<label for="password">Contraseña</label><input id="password" name="password" type="password" autocomplete="current-password" required>
<div class="row"><button class="primary" type="submit">Continuar</button></div></form>`,
    message ? 401 : 200,
  );
}

function hostOf(uri: string | undefined): string {
  if (!uri) return "(desconocido)";
  try {
    const u = new URL(uri);
    return u.host;
  } catch {
    return "(no válido)";
  }
}

function consentScreen(details: AuthorizationDetails, authorizationId: string, sessionToken: string): Response {
  const clientName = details.client?.name ?? details.client?.client_name ?? "Una aplicación";
  const email = details.user?.email ?? "tu cuenta";
  const body = `<h1>${escapeHtml(clientName)} quiere leer tus datos de Yala</h1>
<p>Cuenta: <strong>${escapeHtml(email)}</strong><br>Volverá a: <strong>${escapeHtml(hostOf(details.redirect_uri))}</strong></p>
<p>Si autorizas, podrá <strong>leer</strong>:</p>
<ul><li>tus cuentas y sus saldos</li><li>tus movimientos, categorías y etiquetas</li><li>tus presupuestos</li><li>tus pagos recurrentes</li></ul>
<p><strong>No podrá</strong> crear, cambiar ni borrar nada, ni ver tus grupos. Puedes quitarle el acceso cuando quieras.</p>
<form method="post" action="/oauth/consent/decision">
<input type="hidden" name="authorization_id" value="${escapeHtml(authorizationId)}">
<div class="row"><button name="decision" value="deny" type="submit">No permitir</button>
<button class="primary" name="decision" value="approve" type="submit">Permitir</button></div></form>`;
  return page("Autorizar acceso a Yala", body, 200, {
    "Set-Cookie": `${COOKIE}=${authorizationId}.${sessionToken}; Path=/oauth; HttpOnly; Secure; SameSite=Strict; Max-Age=${COOKIE_MAX_AGE}`,
  });
}

function authHeaders(env: Env, token?: string): Record<string, string> {
  const h: Record<string, string> = { apikey: env.SUPABASE_ANON_KEY, "Content-Type": "application/json", Accept: "application/json" };
  if (token) h.Authorization = `Bearer ${token}`;
  return h;
}

async function passwordLogin(env: Env, fetcher: Fetcher, email: string, password: string): Promise<string | null> {
  const res = await fetcher(`${authIssuer(env)}/token?grant_type=password`, {
    method: "POST",
    headers: authHeaders(env),
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { access_token?: string };
  return body.access_token ?? null;
}

async function getDetails(env: Env, fetcher: Fetcher, token: string, authorizationId: string) {
  const res = await fetcher(`${authIssuer(env)}/oauth/authorizations/${encodeURIComponent(authorizationId)}`, {
    method: "GET",
    headers: authHeaders(env, token),
  });
  if (!res.ok) return { ok: false as const, status: res.status };
  return { ok: true as const, details: (await res.json()) as AuthorizationDetails };
}

async function logout(env: Env, fetcher: Fetcher, token: string): Promise<void> {
  try {
    await fetcher(`${authIssuer(env)}/logout?scope=local`, { method: "POST", headers: authHeaders(env, token) });
  } catch {
    // Si falla, el token caduca solo (1 h). No bloquea la redirección.
  }
}

/** El redirect_url que devuelve Supabase va al cliente OAuth: solo a los dominios de la lista. */
function safeRedirect(url: string | undefined): string | null {
  return url && isAllowedRedirect(url) ? new URL(url).toString() : null;
}

export async function handleConsent(request: Request, env: Env, fetcher: Fetcher = fetch): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/oauth/consent") {
    const authorizationId = url.searchParams.get("authorization_id") ?? "";
    if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
    return loginForm(authorizationId);
  }

  if (request.method === "POST" && url.pathname === "/oauth/consent") {
    const form = await request.formData();
    const authorizationId = String(form.get("authorization_id") ?? "");
    const email = String(form.get("email") ?? "").trim();
    const password = String(form.get("password") ?? "");
    if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
    if (env.ENVIRONMENT !== "staging") return errorPage("El inicio de sesión con contraseña solo existe en staging.", 403);
    if (!email || !password) return loginForm(authorizationId, "Escribe tu email y tu contraseña.");

    const token = await passwordLogin(env, fetcher, email, password);
    if (!token) return loginForm(authorizationId, "Email o contraseña incorrectos.");

    const got = await getDetails(env, fetcher, token, authorizationId);
    if (!got.ok) {
      await logout(env, fetcher, token);
      return errorPage("La solicitud de autorización caducó o no existe. Vuelve a conectar desde Claude.", 400);
    }
    // Ya consentido antes: Supabase devuelve solo la URL de vuelta.
    if (!got.details.authorization_id && got.details.redirect_url) {
      await logout(env, fetcher, token);
      const target = safeRedirect(got.details.redirect_url);
      if (!target) return errorPage("La dirección de vuelta no es válida.");
      return new Response(null, { status: 303, headers: { Location: target, "Cache-Control": "no-store", "Set-Cookie": clearCookie() } });
    }
    if (!isAllowedRedirect(got.details.redirect_uri)) {
      await logout(env, fetcher, token);
      return errorPage("Esta aplicación no está autorizada a conectarse con Yala.", 403);
    }
    return consentScreen(got.details, authorizationId, token);
  }

  if (request.method === "POST" && url.pathname === "/oauth/consent/decision") {
    const form = await request.formData();
    const authorizationId = String(form.get("authorization_id") ?? "");
    const decision = String(form.get("decision") ?? "");
    const cookie = readCookie(request);
    if (!cookie || cookie.authorizationId !== authorizationId) {
      return errorPage("La sesión de esta página caducó. Vuelve a conectar desde Claude.", 400);
    }
    if (decision !== "approve" && decision !== "deny") return errorPage("Decisión no válida.");

    const res = await fetcher(`${authIssuer(env)}/oauth/authorizations/${encodeURIComponent(authorizationId)}/consent`, {
      method: "POST",
      headers: authHeaders(env, cookie.token),
      body: JSON.stringify({ action: decision }),
    });
    const body = res.ok ? ((await res.json()) as { redirect_url?: string }) : null;
    await logout(env, fetcher, cookie.token);
    const target = safeRedirect(body?.redirect_url);
    if (!target) return errorPage("Supabase no aceptó la decisión. Vuelve a conectar desde Claude.", 502);
    return new Response(null, { status: 303, headers: { Location: target, "Cache-Control": "no-store", "Set-Cookie": clearCookie() } });
  }

  return new Response("Not found", { status: 404 });
}
