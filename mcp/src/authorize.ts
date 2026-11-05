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
 *   3. GET  /oauth/consent            → Supabase manda aquí (Site URL + authorization path): «Continuar con Apple» y
 *                                        «Continuar con Google» (y, solo en staging, email y contraseña).
 *   4. POST /oauth/consent/social     → guarda un `verifier` PKCE ligado a este navegador y manda al login social de
 *                                        Supabase, que vuelve a…
 *      GET  /oauth/consent/social     → …aquí con un código: se canjea, y con esa sesión web se aprueba la
 *                                        autorización del cliente del Worker y se cierra la sesión, TODO en esta
 *                                        petición. Vuelve al callback del Worker.
 *      POST /oauth/consent            → lo mismo con email y contraseña. Solo staging (cuentas de prueba y e2e).
 *   5. GET  /oauth/supabase/callback  → recupera la petición de Claude (solo con la cookie de este navegador),
 *                                        canjea el código como cliente confidencial, verifica que el token es de solo
 *                                        lectura y termina la autorización de Claude con su propio código.
 *
 * El canje del código de Claude, el refresh y la revocación (RFC 7009) los sirve la librería en `/oauth/token`.
 */
import { AuthorizationError, type AuthRequest, type OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import type { UpstreamVerifier } from "./auth";
import { auditEvent } from "./audit";
import { publicOrigin, upstreamCallbackUrl, type Env } from "./env";
import type { Fetcher } from "./egress";
import { consentPage, errorPage, loginPage, type SocialProvider } from "./pages";
import { SCOPE, type GrantProps } from "./tokens";
import {
  approveAuthorization,
  authorizeUrl,
  exchangeCode,
  getAuthorization,
  hasCloudProfile,
  logout,
  passwordLogin,
  pkceLogin,
  socialAuthorizeUrl,
} from "./upstream";

/**
 * Vueltas a las que se acepta devolver el código de autorización. La lista es por URL EXACTA, no por dominio: con
 * registro dinámico cualquiera registra un cliente que vuelve a `https://claude.ai/algo-suyo`, y basta un open
 * redirect en ese dominio para robar el código. Se acepta solo lo que la propia documentación de Claude declara
 * ([auth]): el callback fijo de las apps (claude.ai / claude.com, que cubre Desktop y móvil) y el loopback de Claude
 * Code, con puerto variable pero ruta `/callback`. Se comprueba al registrar el cliente y otra vez al autorizar.
 *
 * [auth]: https://claude.com/docs/connectors/building/authentication
 */
const HOSTED_CALLBACKS = new Set(["https://claude.ai/api/mcp/auth_callback", "https://claude.com/api/mcp/auth_callback"]);
const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

export function isAllowedRedirect(uri: string | undefined): boolean {
  if (!uri) return false;
  let u: URL;
  try {
    u = new URL(uri);
  } catch {
    return false;
  }
  // Solo la forma canónica: `https:claude.ai/x` o variantes que el parser normaliza no cuentan como la URL exacta.
  if (u.href !== uri || u.username || u.password || u.hash) return false;
  if (LOOPBACK_HOSTS.has(u.hostname)) {
    // Claude Code: loopback en cualquier puerto, ruta /callback, sin query. RFC 8252.
    return u.protocol === "http:" && u.pathname === "/callback" && u.search === "";
  }
  return HOSTED_CALLBACKS.has(uri);
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

/**
 * ¿Trae este navegador ALGUNA cookie de «Continuar» de los últimos 10 min? Es solo una primera barrera para el
 * formulario de login. Lo que de verdad ata cada conexión a su navegador es `finishUpstream` en el callback, que
 * exige la cookie del `state` concreto; sin ella, el código nunca se canjea aquí.
 */
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
  // PKCE obligatorio para todos. La librería ya lo exige a los clientes públicos; un cliente confidencial que se
  // registrara por DCR podría saltárselo, y Claude siempre manda PKCE S256, así que esto solo frena a otros.
  if (!req.codeChallenge) return errorRedirect(req.redirectUri, "invalid_request", req.state, req.issuer);
  const client = await oauth.lookupClient(req.clientId);
  if (!client) return errorPage("La solicitud de conexión no es válida. Vuelve a conectar desde Claude.");
  const consent = await oauth.beginConsent(req);
  return consentPage(client, req, consent.handle, consent.headers, env.ENVIRONMENT === "staging");
}

// ─── 2 · POST /authorize ───────────────────────────────────────────────────────────────────────────────────────

async function decideConsent(request: Request, env: Env): Promise<Response> {
  const oauth = helpers(env);
  const form = await readForm(request);
  if (!form) return errorPage("No se pudo leer el formulario. Vuelve a conectar desde Claude.");
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

function isStaging(env: Env): boolean {
  return env.ENVIRONMENT === "staging";
}

function showLogin(request: Request, env: Env): Response {
  const authorizationId = new URL(request.url).searchParams.get("authorization_id") ?? "";
  if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
  if (!hasUpstreamBinding(request)) return errorPage("Empieza la conexión desde Claude.");
  return loginPage(authorizationId, { staging: isStaging(env) });
}

async function loginAndApprove(request: Request, env: Env, deps: AuthorizeDeps): Promise<Response> {
  const form = await readForm(request);
  if (!form) return errorPage("No se pudo leer el formulario. Vuelve a conectar desde Claude.");
  const authorizationId = String(form.get("authorization_id") ?? "");
  const email = String(form.get("email") ?? "").trim();
  const password = String(form.get("password") ?? "");
  if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
  // Un POST de otro sitio no trae la cookie (SameSite=Lax): esto también frena el login forzado.
  if (!hasUpstreamBinding(request)) return errorPage("Empieza la conexión desde Claude.");
  if (!isStaging(env)) return errorPage("El inicio de sesión con contraseña solo existe en staging.", 403);
  if (!email || !password) return loginPage(authorizationId, { staging: true, message: "Escribe tu email y tu contraseña." });

  let session: string | null;
  try {
    session = await passwordLogin(env, deps.fetcher, email, password);
  } catch {
    return errorPage("Yala no respondió. Prueba de nuevo en un momento.", 503);
  }
  if (!session) return loginPage(authorizationId, { staging: true, message: "Email o contraseña incorrectos." });
  return approveWithWebSession(env, deps, session, authorizationId);
}

/** Lo que ve quien entra con una cuenta que no usa la nube de Yala. */
export const NO_CLOUD_MESSAGE =
  "Esta cuenta todavía no usa la nube de Yala, así que Claude no tendría nada que leer. En Yala ve a Ajustes → «Dónde viven tus datos» → «Activar la nube» con esta misma cuenta, y luego vuelve a conectar. Si tu nube está en tu otra cuenta, elige esa.";

/**
 * Con la sesión web recién abierta (contraseña o Apple/Google), comprueba que la cuenta usa la nube, aprueba la
 * autorización que pidió ESTE Worker y cierra esa sesión. La sesión web es NORMAL (`authenticated`): puede escribir. Por eso vive solo dentro de esta petición.
 */
async function approveWithWebSession(
  env: Env,
  deps: AuthorizeDeps,
  session: string,
  authorizationId: string,
  extraHeaders?: Headers,
): Promise<Response> {
  try {
    // Sin la nube de Yala, Claude no tendría nada que leer: no se conecta y se explica qué hacer. La autorización
    // pendiente sigue valiendo, así que puede probar con su otra cuenta (Apple o Google) sin volver a Claude.
    if (!(await hasCloudProfile(env, deps.fetcher, session))) {
      auditEvent("mcp_autorizacion", { resultado: "sin_nube" });
      const res = loginPage(authorizationId, { staging: isStaging(env), message: NO_CLOUD_MESSAGE, status: 403 });
      for (const c of extraHeaders?.getSetCookie() ?? []) res.headers.append("Set-Cookie", c);
      return res;
    }
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
    const headers = new Headers(extraHeaders);
    headers.set("Location", target);
    headers.set("Cache-Control", "no-store");
    return new Response(null, { status: 303, headers });
  } catch {
    // Un fallo de red hablando con Supabase, no un bug: se pide reintentar.
    return errorPage("Yala no respondió. Prueba de nuevo en un momento.", 503);
  } finally {
    await logout(env, deps.fetcher, session);
  }
}

// ─── 4 · Login con Apple o Google (/oauth/consent/social) ───────────────────────────────────────────────────────

/** Cookie que liga la vuelta del login social a ESTE navegador. Solo lleva un identificador al azar. */
const SOCIAL_COOKIE = "__Host-yala-social";
/** Lo que dura el viaje a Apple o Google. Pasado, hay que volver a pulsar el botón. */
const SOCIAL_TTL_SECONDS = 600;
const SOCIAL_KEY_PREFIX = "yala:social:";
const NONCE_RE = /^[A-Za-z0-9_-]{43}$/;

interface SocialPending {
  v: 1;
  authorizationId: string;
  verifier: string;
  provider: SocialProvider;
}

function socialReturnUrl(env: Env): string {
  return `${publicOrigin(env)}/oauth/consent/social`;
}

function readCookie(request: Request, name: string): string | null {
  const cookie = request.headers.get("Cookie") ?? "";
  for (const part of cookie.split(/;\s*/)) {
    const eq = part.indexOf("=");
    if (eq > 0 && part.slice(0, eq) === name) return part.slice(eq + 1);
  }
  return null;
}

function socialCookie(value: string, maxAge: number): string {
  // SameSite=Lax: la vuelta desde Supabase es una navegación GET de primer nivel, así que la cookie viaja; un POST de
  // otro sitio, no.
  return `${SOCIAL_COOKIE}=${value}; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=${maxAge}`;
}

/**
 * «Continuar con Apple» / «Continuar con Google»: guarda el `verifier` PKCE en el KV, bajo un identificador que solo
 * conoce la cookie de este navegador, y manda al login social de Supabase.
 */
async function startSocialLogin(request: Request, env: Env): Promise<Response> {
  const form = await readForm(request);
  if (!form) return errorPage("No se pudo leer el formulario. Vuelve a conectar desde Claude.");
  const authorizationId = String(form.get("authorization_id") ?? "");
  const provider = String(form.get("provider") ?? "");
  if (!AUTH_ID_RE.test(authorizationId)) return errorPage("Falta la solicitud de autorización o no es válida.");
  if (provider !== "apple" && provider !== "google") return errorPage("Elige Apple o Google para iniciar sesión.");
  if (!hasUpstreamBinding(request)) return errorPage("Empieza la conexión desde Claude.");

  const nonce = b64url(crypto.getRandomValues(new Uint8Array(32)));
  const verifier = b64url(crypto.getRandomValues(new Uint8Array(32)));
  const pending: SocialPending = { v: 1, authorizationId, verifier, provider };
  await env.OAUTH_KV.put(SOCIAL_KEY_PREFIX + nonce, JSON.stringify(pending), { expirationTtl: SOCIAL_TTL_SECONDS });
  const location = socialAuthorizeUrl(env, provider, socialReturnUrl(env), await s256(verifier));
  return new Response(null, {
    status: 303,
    headers: { Location: location, "Cache-Control": "no-store", "Set-Cookie": socialCookie(nonce, SOCIAL_TTL_SECONDS) },
  });
}

function parsePending(raw: string | null): SocialPending | null {
  if (!raw) return null;
  try {
    const p = JSON.parse(raw) as Partial<SocialPending>;
    if (p.v !== 1 || typeof p.authorizationId !== "string" || !AUTH_ID_RE.test(p.authorizationId)) return null;
    if (typeof p.verifier !== "string" || (p.provider !== "apple" && p.provider !== "google")) return null;
    return p as SocialPending;
  } catch {
    return null;
  }
}

/** Vuelta de Supabase tras Apple o Google: canjea el código con el `verifier` de este navegador y aprueba. */
async function finishSocialLogin(request: Request, env: Env, deps: AuthorizeDeps): Promise<Response> {
  const url = new URL(request.url);
  const clear = new Headers({ "Set-Cookie": socialCookie("", 0) });
  const nonce = readCookie(request, SOCIAL_COOKIE);
  if (!nonce || !NONCE_RE.test(nonce)) {
    return errorPage("Este inicio de sesión caducó o se abrió en otro navegador. Vuelve a conectar desde Claude.", 400, clear);
  }
  const key = SOCIAL_KEY_PREFIX + nonce;
  const raw = await env.OAUTH_KV.get(key);
  // Un solo uso: aunque el canje falle, para reintentar hay que volver a pulsar el botón.
  if (raw) await env.OAUTH_KV.delete(key);
  const pending = parsePending(raw);
  if (!pending) {
    return errorPage("Este inicio de sesión caducó o se abrió en otro navegador. Vuelve a conectar desde Claude.", 400, clear);
  }
  if (!hasUpstreamBinding(request)) return errorPage("Empieza la conexión desde Claude.", 400, clear);

  const retry = (message: string, status: number) => {
    const res = loginPage(pending.authorizationId, { staging: isStaging(env), message, status });
    res.headers.append("Set-Cookie", socialCookie("", 0));
    return res;
  };
  const code = url.searchParams.get("code");
  if (!code) {
    // Cancelar en Apple o Google vuelve con `error`; cualquier otra cosa sin código, igual: se puede volver a probar.
    return retry("No se completó el inicio de sesión. Puedes intentarlo otra vez.", 400);
  }
  let web: Awaited<ReturnType<typeof pkceLogin>>;
  try {
    web = await pkceLogin(env, deps.fetcher, code, pending.verifier, deps.nowSec() * 1000);
  } catch {
    return errorPage("Yala no respondió. Prueba de nuevo en un momento.", 503, clear);
  }
  if (!web) return retry("No se pudo iniciar sesión. Puedes intentarlo otra vez.", 401);
  if (web.createdNow) auditEvent("mcp_autorizacion", { resultado: `cuenta_nueva_${pending.provider}` });
  return approveWithWebSession(env, deps, web.access, pending.authorizationId, clear);
}

/** Lee el formulario; si el cuerpo no es un formulario (Content-Type raro), devuelve null en vez de un 500. */
async function readForm(request: Request): Promise<FormData | null> {
  try {
    return await request.formData();
  } catch {
    return null;
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
    // La sesión ya no sirve para el Worker: se cierra, no se entrega nada. Si no se pudo verificar (JWKS caído), es un
    // fallo pasajero y Claude puede reintentar toda la conexión; si el token es malo, es un error del servidor.
    await logout(env, deps.fetcher, exchanged.value.access);
    return fail(check.reason === "unavailable" ? "temporarily_unavailable" : "server_error", `token_${check.reason}`);
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
  if (path === "/oauth/consent/social") {
    if (request.method === "POST") return startSocialLogin(request, env);
    if (request.method === "GET") return finishSocialLogin(request, env, deps);
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, POST" } });
  }
  if (path === "/oauth/consent") {
    if (request.method === "GET") return showLogin(request, env);
    if (request.method === "POST") return loginAndApprove(request, env, deps);
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, POST" } });
  }
  if (path === "/oauth/supabase/callback") {
    if (request.method === "GET") return finishAuthorization(request, env, deps);
    return new Response("Method not allowed", { status: 405, headers: { Allow: "GET" } });
  }
  return null;
}
