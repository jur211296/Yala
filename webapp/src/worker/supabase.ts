/**
 * Lo que la web pide a Supabase Auth. Todas las llamadas salen por la lista cerrada de `egress.ts`.
 *
 * Cómo entra alguien (decisiones P1 y P2 del ticket `yala-web-lote-0-cimientos`):
 *
 * 1. El navegador va al login social de Supabase (Apple o Google) en su flujo PKCE y vuelve a `/auth/callback` con un
 *    código. El Worker lo canjea por una sesión NORMAL de Supabase (`pkceLogin`). Esa sesión escribe, así que solo
 *    vive unos segundos dentro de esta petición.
 * 2. Con ella, el Worker comprueba que la cuenta usa la nube (`cloudKind`), y pide y aprueba él solo el permiso de su
 *    cliente OAuth (`grantReadOnly`): `GET /oauth/authorize` responde 302 con un `authorization_id` sin necesitar
 *    navegador, y la aprobación se hace con la sesión normal. Así la web no pasa por la Site URL de Supabase, que en
 *    staging es la pantalla de permiso del conector de Claude.
 * 3. Canjea el código con su secreto (cliente confidencial, PKCE S256) y recibe una sesión que el hook de Supabase
 *    marca `role = yala_mcp_reader`: no puede escribir.
 * 4. Cierra la sesión normal. Lo que se guarda es solo la de lectura, cifrada (`session.ts`).
 */
import { authIssuer, oauthRedirectUri, type Env } from "./env";
import type { Fetcher } from "./egress";

export interface Tokens {
  access: string;
  refresh: string;
}

/**
 * - `rejected`: Supabase dice que no va a funcionar nunca (sesión revocada, refresh reusado). Se borra la sesión web.
 * - `unavailable`: no se puede saber ahora (red, 5xx) o el Worker está mal configurado. No se borra nada.
 */
export type Failure = { ok: false; kind: "rejected" | "unavailable"; status: number; code: string };
export type Result<T> = { ok: true; value: T } | Failure;

function headers(env: Env, bearer?: string): Record<string, string> {
  const h: Record<string, string> = { apikey: env.SUPABASE_ANON_KEY, Accept: "application/json" };
  if (bearer) h.Authorization = `Bearer ${bearer}`;
  return h;
}

function clientBasic(env: Env): string {
  const id = encodeURIComponent(env.SUPABASE_OAUTH_CLIENT_ID);
  const secret = encodeURIComponent(env.SUPABASE_OAUTH_CLIENT_SECRET);
  return `Basic ${btoa(`${id}:${secret}`)}`;
}

async function readError(res: Response): Promise<string> {
  try {
    const body = (await res.json()) as { error?: unknown; error_code?: unknown; code?: unknown };
    for (const v of [body.error_code, body.error, typeof body.code === "string" ? body.code : undefined]) {
      if (typeof v === "string" && v) return v;
    }
    return `http_${res.status}`;
  } catch {
    return `http_${res.status}`;
  }
}

/**
 * Los códigos con los que GoTrue dice que un refresh NO va a volver a funcionar (la misma lista que el conector,
 * medida en GoTrue v2.197.0). Cualquier otro es «no disponible»: se reintenta, no se borra la sesión.
 */
const DEFINITIVE_REJECT = new Set([
  "invalid_grant",
  "refresh_token_not_found",
  "refresh_token_already_used",
  "session_not_found",
  "session_expired",
  "user_not_found",
  "user_banned",
]);

// ─── 1 · Login social y sesión normal ──────────────────────────────────────────────────────────────────────────

/** A dónde se manda al navegador para entrar con Apple o Google (flujo PKCE de Supabase, vuelta con `?code=`). */
export function socialAuthorizeUrl(env: Env, provider: "apple" | "google", redirectTo: string, codeChallenge: string): string {
  const u = new URL(`${authIssuer(env)}/authorize`);
  u.search = new URLSearchParams({ provider, redirect_to: redirectTo, code_challenge: codeChallenge, code_challenge_method: "s256" }).toString();
  return u.toString();
}

export interface NormalSession {
  access: string;
  userId: string;
}

async function normalSessionFrom(res: Response): Promise<NormalSession | null> {
  if (!res.ok) return null;
  const body = (await res.json()) as { access_token?: string; user?: { id?: string } };
  if (!body.access_token || !body.user?.id) return null;
  return { access: body.access_token, userId: body.user.id };
}

/** Canje del código del login social. `null` si Supabase no lo acepta (usado, caducado, de otro navegador). */
export async function pkceLogin(env: Env, fetcher: Fetcher, authCode: string, verifier: string): Promise<NormalSession | null> {
  const res = await fetcher(`${authIssuer(env)}/token?grant_type=pkce`, {
    method: "POST",
    headers: { ...headers(env), "Content-Type": "application/json" },
    body: JSON.stringify({ auth_code: authCode, code_verifier: verifier }),
  });
  return normalSessionFrom(res);
}

/** Login con contraseña: SOLO staging (la lista cerrada lo niega en cualquier otro entorno). Para las pruebas e2e. */
export async function passwordLogin(env: Env, fetcher: Fetcher, email: string, password: string): Promise<NormalSession | null> {
  const res = await fetcher(`${authIssuer(env)}/token?grant_type=password`, {
    method: "POST",
    headers: { ...headers(env), "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  return normalSessionFrom(res);
}

/** Cierra UNA sesión (`scope=local`). Si falla, el token caduca solo (1 h). */
export async function logout(env: Env, fetcher: Fetcher, token: string): Promise<void> {
  try {
    await fetcher(`${authIssuer(env)}/logout?scope=local`, { method: "POST", headers: headers(env, token) });
  } catch {
    // Ver arriba.
  }
}

/**
 * Cierra a distancia UNA sesión web en Supabase, por su `session_id`, con el token de quien la cierra (el iPhone o otra
 * sesión web de la misma cuenta). La función (`webapp/supabase/web1_01_bandeja_y_sesiones.sql`) solo borra sesiones del
 * cliente OAuth de la web y de `auth.uid()`: con un id ajeno no hace nada. `true` si la cerró o ya no existía.
 */
export async function closeWebSession(env: Env, fetcher: Fetcher, token: string, sessionId: string): Promise<boolean> {
  try {
    const res = await fetcher(`${env.SUPABASE_URL.replace(/\/+$/, "")}/rest/v1/rpc/yala_web_close_session`, {
      method: "POST",
      headers: { ...headers(env, token), "Content-Type": "application/json" },
      body: JSON.stringify({ p_session_id: sessionId }),
    });
    return res.ok;
  } catch {
    return false;
  }
}

// ─── 2 · El permiso de solo lectura ────────────────────────────────────────────────────────────────────────────

export type GrantFailure = "authorize" | "details" | "wrong_client" | "wrong_user" | "consent" | "redirect" | "exchange";
export type GrantResult = { ok: true; tokens: Tokens } | { ok: false; step: GrantFailure; status?: number };

const AUTH_ID_RE = /^[A-Za-z0-9_-]{8,128}$/;

/** El `code` de la URL de vuelta, si es la vuelta registrada de la web y trae el `state` que se pidió. */
export function codeFromRedirect(env: Env, redirectUrl: string, state: string): string | null {
  let u: URL;
  try {
    u = new URL(redirectUrl);
  } catch {
    return null;
  }
  if (`${u.origin}${u.pathname}` !== oauthRedirectUri(env)) return null;
  if (u.searchParams.get("state") !== state) return null;
  return u.searchParams.get("code");
}

/**
 * Pide el permiso del cliente OAuth de la web, lo aprueba con la sesión normal del usuario y canjea el código.
 * `verifier` y `challenge` son el PKCE de ESTA petición; `state`, un valor al azar que la vuelta tiene que repetir.
 */
export async function grantReadOnly(
  env: Env,
  fetcher: Fetcher,
  normal: NormalSession,
  pkce: { verifier: string; challenge: string; state: string },
): Promise<GrantResult> {
  const authorize = new URL(`${authIssuer(env)}/oauth/authorize`);
  authorize.search = new URLSearchParams({
    response_type: "code",
    client_id: env.SUPABASE_OAUTH_CLIENT_ID,
    redirect_uri: oauthRedirectUri(env),
    code_challenge: pkce.challenge,
    code_challenge_method: "S256",
    state: pkce.state,
  }).toString();
  const first = await fetcher(authorize.toString(), { method: "GET", headers: headers(env), redirect: "manual" });
  const location = first.headers.get("Location");
  if (first.status < 300 || first.status >= 400 || !location) return { ok: false, step: "authorize", status: first.status };
  let authorizationId: string | null = null;
  try {
    authorizationId = new URL(location).searchParams.get("authorization_id");
  } catch {
    authorizationId = null;
  }
  if (!authorizationId || !AUTH_ID_RE.test(authorizationId)) return { ok: false, step: "authorize", status: first.status };

  const base = `${authIssuer(env)}/oauth/authorizations/${encodeURIComponent(authorizationId)}`;
  const details = await fetcher(base, { method: "GET", headers: headers(env, normal.access) });
  if (!details.ok) return { ok: false, step: "details", status: details.status };
  const d = (await details.json()) as { redirect_url?: string; client?: { id?: string }; user?: { id?: string } };

  let redirectUrl = d.redirect_url;
  if (!redirectUrl) {
    // Primera vez: Supabase enseña a quién se da el permiso y para quién. Tiene que ser la web y este usuario.
    if (d.client?.id !== env.SUPABASE_OAUTH_CLIENT_ID) return { ok: false, step: "wrong_client" };
    if (d.user?.id !== normal.userId) return { ok: false, step: "wrong_user" };
    const consent = await fetcher(`${base}/consent`, {
      method: "POST",
      headers: { ...headers(env, normal.access), "Content-Type": "application/json" },
      body: JSON.stringify({ action: "approve" }),
    });
    if (!consent.ok) return { ok: false, step: "consent", status: consent.status };
    redirectUrl = ((await consent.json()) as { redirect_url?: string }).redirect_url;
  }
  const code = redirectUrl ? codeFromRedirect(env, redirectUrl, pkce.state) : null;
  if (!code) return { ok: false, step: "redirect" };

  const exchanged = await tokenRequest(env, fetcher, {
    grant_type: "authorization_code",
    code,
    redirect_uri: oauthRedirectUri(env),
    code_verifier: pkce.verifier,
  });
  if (!exchanged.ok) return { ok: false, step: "exchange", status: exchanged.status };
  return { ok: true, tokens: exchanged.value };
}

async function tokenRequest(env: Env, fetcher: Fetcher, body: Record<string, string>): Promise<Result<Tokens>> {
  let res: Response;
  try {
    res = await fetcher(`${authIssuer(env)}/oauth/token`, {
      method: "POST",
      headers: { ...headers(env), Authorization: clientBasic(env), "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(body).toString(),
    });
  } catch {
    return { ok: false, kind: "unavailable", status: 0, code: "network" };
  }
  if (res.ok) {
    const json = (await res.json()) as { access_token?: string; refresh_token?: string };
    if (!json.access_token || !json.refresh_token) return { ok: false, kind: "unavailable", status: res.status, code: "malformed" };
    return { ok: true, value: { access: json.access_token, refresh: json.refresh_token } };
  }
  const code = await readError(res);
  return { ok: false, kind: DEFINITIVE_REJECT.has(code) ? "rejected" : "unavailable", status: res.status, code };
}

export function refreshTokens(env: Env, fetcher: Fetcher, refresh: string): Promise<Result<Tokens>> {
  return tokenRequest(env, fetcher, { grant_type: "refresh_token", refresh_token: refresh });
}

// ─── 3 · Con la sesión de solo lectura ─────────────────────────────────────────────────────────────────────────

export interface Account {
  nombre: string;
  correo: string | null;
}

/** Qué se enseña como nombre: el de Apple o Google si lo dieron; si no, el correo; si tampoco, «Tu cuenta». */
export function accountFrom(user: { email?: unknown; user_metadata?: Record<string, unknown> | null }): Account {
  const meta = user.user_metadata ?? {};
  const correo = typeof user.email === "string" && user.email ? user.email : null;
  for (const key of ["full_name", "name"]) {
    const v = meta[key];
    if (typeof v === "string" && v.trim()) return { nombre: v.trim(), correo };
  }
  return { nombre: correo ?? "", correo };
}

/**
 * `GET /user` con la sesión de lectura: el nombre de la cuenta y, de paso, si la sesión sigue viva. GoTrue carga la
 * sesión en cada `GET /user`, así que una sesión cerrada desde otro sitio se nota al momento aunque el JWT no caduque.
 * - `alive`: 200, con la cuenta.
 * - `gone`: la sesión o el usuario ya no existen. Se borra la sesión web.
 * - `stale`: el JWT no vale (caducó): hay que refrescar.
 * - `unknown`: no se pudo preguntar. 503, sin borrar nada.
 */
export async function currentUser(
  env: Env,
  fetcher: Fetcher,
  access: string,
): Promise<{ status: "alive"; account: Account } | { status: "gone" | "stale" | "unknown" }> {
  let res: Response;
  try {
    res = await fetcher(`${authIssuer(env)}/user`, { method: "GET", headers: headers(env, access) });
  } catch {
    return { status: "unknown" };
  }
  if (res.ok) return { status: "alive", account: accountFrom((await res.json()) as Parameters<typeof accountFrom>[0]) };
  if (res.status !== 401 && res.status !== 403 && res.status !== 404) return { status: "unknown" };
  const code = await readError(res);
  const gone = ["session_not_found", "user_not_found", "user_banned", "session_expired", "refresh_token_not_found"];
  return { status: gone.includes(code) ? "gone" : "stale" };
}
