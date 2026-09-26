/**
 * El baile OAuth de Claude contra ESTE Worker, con Supabase aguas arriba.
 *
 * Por qué así (ADR «El conector de Claude emite sus propios tokens», docs/DECISIONS.md): GoTrue acepta cualquier
 * token del usuario en `/auth/v1/user*` y no mira el cliente ni el scope. Si Claude recibiera el token de Supabase,
 * podría cambiar la cuenta. Así que Claude recibe un token opaco del Worker, atado a `…/mcp`, y la sesión de
 * Supabase (de solo lectura en la base) se queda cifrada dentro del Worker.
 *
 *   1. GET  /authorize                → la librería valida cliente, vuelta, PKCE y recurso; aquí se exige además que
 *                                        la vuelta sea de Claude, y se pide el permiso (`consentPage`).
 *   2. POST /authorize                → «No permitir» vuelve a Claude con `access_denied`. «Continuar» guarda la
 *                                        petición (ligada al navegador) y manda a Supabase como el cliente del Worker.
 *   3. GET  /oauth/consent            → Supabase manda aquí (Site URL + authorization path): formulario de login.
 *   4. POST /oauth/consent            → login, aprobación de la autorización del cliente del Worker y cierre de la
 *                                        sesión web, TODO en esta petición. Vuelve al callback del Worker.
 *   5. GET  /oauth/supabase/callback  → recupera la petición de Claude (solo con la cookie de este navegador),
 *                                        canjea el código como cliente confidencial, verifica que el token es de solo
 *                                        lectura y termina la autorización de Claude con su propio código.
 *
 * El canje del código de Claude, el refresh y la revocación (RFC 7009) los sirve la librería en `/oauth/token`.
 */
import { AuthorizationError, type AuthRequest, type OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import type { UpstreamVerifier } from "./auth";
import { auditEvent } from "./audit";
import { upstreamCallbackUrl, type Env } from "./env";
import type { Fetcher } from "./egress";
import { consentPage, errorPage, loginPage } from "./pages";
import { SCOPE, type GrantProps } from "./tokens";
import { approveAuthorization, authorizeUrl, exchangeCode, getAuthorization, logout, passwordLogin } from "./upstream";

/**
 * Dominios a los que se acepta devolver el acceso. Con registro dinámico, cualquiera registra un cliente llamado
 * «Claude» que vuelve a su propio dominio; enseñar el dominio no basta si el usuario no lo lee. Solo Claude
 * (claude.ai / claude.com, que usan claude.ai y Desktop) y el loopback de Claude Code. Se aplica al registrar el
 * cliente y otra vez al pedir el permiso. Si mañana hace falta otro cliente, se añade aquí a propósito.
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
  if (u.username || u.password || u.hash) return false;
  if (LOOPBACK_HOSTS.has(u.hostname)) return u.protocol === "http:" || u.protocol === "https:";
  return u.protocol === "https:" && ALLOWED_REDIRECT_HOSTS.has(u.hostname);
}

/** Política del registro dinámico: todas las vueltas tienen que estar en la lista. */
export function registrationPolicy({ clientMetadata }: { clientMetadata: Record<string, unknown> }) {
  const uris = clientMetadata["redirect_uris"];
  if (!Array.isArray(uris) || uris.length === 0 || !uris.every((u) => typeof u === "string" && isAllowedRedirect(u))) {
    return { code: "invalid_redirect_uri", description: "Solo Claude puede conectarse a Yala", status: 400 };
  }
  return undefined;
}

const AUTH_ID_RE = /^[A-Za-z0-9_-]{8,128}$/;
/** Prefijo de la cookie con la que la librería liga al navegador la vuelta desde Supabase. */
const UPSTREAM_COOKIE_PREFIX = "__Host-oauth-upstream-";

/** ¿Viene este navegador de un «Continuar» en la pantalla de permiso de hace menos de 10 minutos? */
function hasUpstreamBinding(request: Request): boolean {
  const cookie = request.headers.get("Cookie") ?? "";
  return cookie.split(/;\s*/).some((part) => part.startsWith(UPSTREAM_COOKIE_PREFIX));
}

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function s256(verifier: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))));
}

/** Vuelta de error a Claude. Solo con una vuelta ya validada (la guardada, o la que la librería validó). */
function errorRedirect(redirectUri: string, code: string, state: string | undefined, issuer: string | undefined, headers = new Headers()) {
  const u = new URL(redirectUri);
  u.searchParams.set("error", code);
  if (state) u.searchParams.set("state", state);
  if (issuer) u.searchParams.set("iss", issuer);
  headers.set("Location", u.toString());
  headers.set("Cache-Control", "no-store");
  return new Response(null, { status: 302, headers });
}

export interface AuthorizeDeps {
  fetcher: Fetcher;
  verify: UpstreamVerifier;
  nowSec: () => number;
}

function helpers(env: Env): OAuthHelpers {
  if (!env.OAUTH_PROVIDER) throw new Error("La librería OAuth no inyectó sus helpers");
  return env.OAUTH_PROVIDER;
}

// ─── 1 · GET /authorize ────────────────────────────────────────────────────────────────────────────────────────

async function showConsent(request: Request, env: Env): Promise<Response> {
  const oauth = helpers(env);
  let req: AuthRequest;
  try {
    req = await oauth.parseAuthRequest(request);
  } catch (err) {
    if (!(err instanceof AuthorizationError)) throw err;
    // Con `redirectUri`, la librería ya validó cliente y vuelta; aun así, solo se redirige a la lista.
    if (err.redirectUri && isAllowedRedirect(err.redirectUri)) return errorRedirect(err.redirectUri, err.code, err.state, err.issuer);
    return errorPage("La solicitud de conexión no es válida. Vuelve a conectar desde Claude.");
  }
  if (!isAllowedRedirect(req.redirectUri)) {
    return errorPage("Esta aplicación no está autorizada a conectarse con Yala.", 403);
  }
  const client = await oauth.lookupClient(req.clientId);
  if (!client) return errorPage("La solicitud de conexión no es válida. Vuelve a conectar desde Claude.");
  const consent = await oauth.beginConsent(req);
  return consentPage(client, req, consent.handle, consent.headers, env.ENVIRONMENT === "staging");
}

// ─── 2 · POST /authorize ───────────────────────────────────────────────────────────────────────────────────────

async function decideConsent(request: Request, env: Env): Promise<Response> {
  const oauth = helpers(env);
  const form = await request.formData();
  const handle = String(form.get("handle") ?? "");
  const decision = String(form.get("decision") ?? "");
  try {
    if (decision === "deny") {
      const denied = await oauth.denyConsent(request, handle);
      auditEvent("mcp_autorizacion", { cliente: denied.request.clientId, resultado: "no_permitida" });
      return new Response(null, { status: 302, headers: denied.headers });
    }
    if (decision !== "approve") return errorPage("Decisión no válida.");
    // El scope lo decide la página: el único que existe. Lo que Claude pidiera de más no se concede.
    const approved = await oauth.approveConsent(request, handle, { scope: [SCOPE] });
    const verifier = b64url(crypto.getRandomValues(new Uint8Array(32)));
    const upstream = await oauth.beginUpstream(approved.request, { data: { verifier }, headers: approved.headers });
    upstream.headers.set("Location", authorizeUrl(env, upstream.state, await s256(verifier)));
    return new Response(null, { status: 302, headers: upstream.headers });
  } catch (err) {
    if (err instanceof AuthorizationError) {
      return errorPage("Esta página caducó, ya se usó o se abrió en otro navegador. Vuelve a conectar desde Claude.");
    }
    throw err;
  }
}

// ─── 3 y 4 · /oauth/consent (la página de autorización que Supabase tiene configurada) ─────────────────────────

function showLogin(request: Request): Response {
  const authorizationId = new URL(request.url).searchParams.get("authorization_id") ?? "";
  if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
  if (!hasUpstreamBinding(request)) return errorPage("Empieza la conexión desde Claude.");
  return loginPage(authorizationId);
}

async function loginAndApprove(request: Request, env: Env, deps: AuthorizeDeps): Promise<Response> {
  const form = await request.formData();
  const authorizationId = String(form.get("authorization_id") ?? "");
  const email = String(form.get("email") ?? "").trim();
  const password = String(form.get("password") ?? "");
  if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
  // Un POST de otro sitio no trae la cookie (SameSite=Lax): esto también frena el login forzado.
  if (!hasUpstreamBinding(request)) return errorPage("Empieza la conexión desde Claude.");
  if (env.ENVIRONMENT !== "staging") return errorPage("El inicio de sesión con contraseña solo existe en staging.", 403);
  if (!email || !password) return loginPage(authorizationId, "Escribe tu email y tu contraseña.");

  const session = await passwordLogin(env, deps.fetcher, email, password);
  if (!session) return loginPage(authorizationId, "Email o contraseña incorrectos.");
  // La sesión web es NORMAL (`authenticated`): puede escribir. Vive solo dentro de esta petición.
  try {
    const got = await getAuthorization(env, deps.fetcher, session, authorizationId);
    if (!got.ok) return errorPage("La solicitud de autorización caducó o no existe. Vuelve a conectar desde Claude.");
    let redirectUrl: string | null;
    if (!got.details.authorization_id && got.details.redirect_url) {
      // Ya había permiso para el cliente del Worker: Supabase aprueba solo. La vuelta se valida abajo.
      redirectUrl = got.details.redirect_url;
    } else {
      // Solo se aprueba la autorización que pidió ESTE Worker, hacia su propia vuelta.
      if (got.details.client?.id !== env.SUPABASE_OAUTH_CLIENT_ID || got.details.redirect_uri !== upstreamCallbackUrl(env)) {
        return errorPage("Esta solicitud no viene de la conexión de Yala con Claude.", 403);
      }
      redirectUrl = await approveAuthorization(env, deps.fetcher, session, authorizationId);
    }
    const target = callbackTarget(env, redirectUrl);
    if (!target) return errorPage("Yala no aceptó la conexión. Vuelve a conectar desde Claude.", 502);
    return new Response(null, { status: 303, headers: { Location: target, "Cache-Control": "no-store" } });
  } finally {
    await logout(env, deps.fetcher, session);
  }
}

/** La vuelta de Supabase solo puede ir al callback del Worker, con su código. */
function callbackTarget(env: Env, url: string | null | undefined): string | null {
  if (!url) return null;
  let u: URL;
  let expected: URL;
  try {
    u = new URL(url);
    expected = new URL(upstreamCallbackUrl(env));
  } catch {
    return null;
  }
  if (u.origin !== expected.origin || u.pathname !== expected.pathname || u.username || u.password) return null;
  return u.toString();
}

// ─── 5 · GET /oauth/supabase/callback ──────────────────────────────────────────────────────────────────────────

async function finishAuthorization(request: Request, env: Env, deps: AuthorizeDeps): Promise<Response> {
  const oauth = helpers(env);
  const url = new URL(request.url);
  let original: AuthRequest;
  let data: { verifier?: string };
  let headers: Headers;
  try {
    ({ request: original, data, headers } = await oauth.finishUpstream<{ verifier?: string }>(request));
  } catch (err) {
    if (err instanceof AuthorizationError) {
      return errorPage("Esta conexión caducó o se abrió en otro navegador. Vuelve a conectar desde Claude.");
    }
    throw err;
  }
  const fail = (code: string, motivo: string) => {
    auditEvent("mcp_autorizacion", { cliente: original.clientId, resultado: motivo });
    return errorRedirect(original.redirectUri, code, original.state, original.issuer, headers);
  };

  if (url.searchParams.get("error")) return fail("access_denied", "supabase_denego");
  const code = url.searchParams.get("code");
  if (!code || !data?.verifier) return fail("server_error", "sin_codigo");

  const exchanged = await exchangeCode(env, deps.fetcher, code, data.verifier);
  if (!exchanged.ok) {
    return fail(exchanged.kind === "unavailable" ? "temporarily_unavailable" : "access_denied", `canje_${exchanged.code}`);
  }
  const check = await deps.verify(exchanged.value.access);
  if (!check.ok) {
    // El hook no marcó el token como de solo lectura (o es de otro cliente): no se entrega nada y se cierra.
    await logout(env, deps.fetcher, exchanged.value.access);
    return fail("server_error", `token_${check.reason}`);
  }

  const now = deps.nowSec();
  const props: GrantProps = {
    v: 1,
    sub: check.claims.sub,
    sid: check.claims.sessionId,
    authorizedAt: now,
    refresh: exchanged.value.refresh,
    access: exchanged.value.access,
    accessExp: check.claims.exp,
  };
  let redirectTo: string;
  try {
    ({ redirectTo } = await oauth.completeAuthorization({
      request: original,
      userId: check.claims.sub,
      // `metadata` se guarda SIN cifrar en el KV: nada personal.
      metadata: { autorizado: now },
      scope: [SCOPE],
      props,
    }));
  } catch (err) {
    // Sin grant no hay quien use esta sesión de Supabase: se cierra en vez de dejarla huérfana.
    await logout(env, deps.fetcher, exchanged.value.access);
    console.error(JSON.stringify({ evento: "mcp_autorizacion_error", error: err instanceof Error ? err.name : "desconocido" }));
    return fail("server_error", "grant_no_guardado");
  }
  auditEvent("mcp_autorizacion", { cliente: original.clientId, sub: check.claims.sub, resultado: "concedida" });
  headers.set("Location", redirectTo);
  headers.set("Cache-Control", "no-store");
  return new Response(null, { status: 302, headers });
}

// ─── Enrutado ──────────────────────────────────────────────────────────────────────────────────────────────────

export async function handleAuthorizeRoutes(request: Request, env: Env, deps: AuthorizeDeps): Promise<Response | null> {
  const path = new URL(request.url).pathname;
  if (path === "/authorize") {
    if (request.method === "GET") return showConsent(request, env);
    if (request.method === "POST") return decideConsent(request, env);
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, POST" } });
  }
  if (path === "/oauth/consent") {
    if (request.method === "GET") return showLogin(request);
    if (request.method === "POST") return loginAndApprove(request, env, deps);
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, POST" } });
  }
  if (path === "/oauth/supabase/callback") {
    if (request.method === "GET") return finishAuthorization(request, env, deps);
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET" } });
  }
  return null;
}
