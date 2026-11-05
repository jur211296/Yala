/**
 * El Worker como cliente OAuth CONFIDENCIAL del servidor OAuth de Supabase (aguas arriba).
 *
 * Supabase sigue siendo quien autentica al usuario y quien guarda el permiso («Yala para Claude» en
 * `/auth/v1/user/oauth/grants`). Lo que cambia es QUIÉN recibe su token: el Worker, no Claude. El token sale con
 * `role = yala_mcp_reader` porque el hook reconoce el `client_id` del Worker, y el Worker lo guarda cifrado
 * (`tokens.ts`). A Claude le da uno propio.
 *
 * Cliente confidencial (`client_secret_basic`) y PKCE S256: un código de Supabase interceptado no se canjea sin el
 * secreto del Worker. Todas las llamadas salen por `egress.ts`.
 */
import { authIssuer, upstreamCallbackUrl, type Env } from "./env";
import { guardSupabase, type Fetcher } from "./egress";

export interface UpstreamTokens {
  access: string;
  refresh: string;
}

/**
 * - `rejected`: Supabase dice que esto no va a funcionar nunca (código usado, sesión revocada, refresh reusado).
 * - `unavailable`: no se puede saber ahora (red, 5xx, límite de peticiones) o el Worker está mal configurado
 *   (secreto del cliente): no es culpa del usuario ni motivo para borrar su conexión.
 */
export type UpstreamFailure = { ok: false; kind: "rejected" | "unavailable"; status: number; code: string };
export type UpstreamResult<T> = { ok: true; value: T } | UpstreamFailure;

function headers(env: Env, bearer?: string): Record<string, string> {
  const h: Record<string, string> = { apikey: env.SUPABASE_ANON_KEY, Accept: "application/json" };
  if (bearer) h.Authorization = `Bearer ${bearer}`;
  return h;
}

function clientBasic(env: Env): string {
  // RFC 6749 §2.3.1: form-urlencode de id y secreto antes del base64.
  const id = encodeURIComponent(env.SUPABASE_OAUTH_CLIENT_ID);
  const secret = encodeURIComponent(env.SUPABASE_OAUTH_CLIENT_SECRET);
  return `Basic ${btoa(`${id}:${secret}`)}`;
}

async function readError(res: Response): Promise<string> {
  try {
    const body = (await res.json()) as { error?: unknown; error_code?: unknown; code?: unknown };
    // GoTrue tiene dos formas: la estándar (`error_code`, y `code` numérico o string según la versión de la API) y la
    // de OAuth (`error`, RFC 6749). Se leen las de texto, en ese orden.
    for (const v of [body.error_code, body.error, typeof body.code === "string" ? body.code : undefined]) {
      if (typeof v === "string" && v) return v;
    }
    return `http_${res.status}`;
  } catch {
    return `http_${res.status}`;
  }
}

/**
 * Los códigos con los que GoTrue dice que un refresh NO va a volver a funcionar (medido en su código, v2.197.0:
 * `internal/tokens/service.go` y el endpoint OAuth). Solo estos borran la conexión. Cualquier otro —secreto del
 * cliente mal (`invalid_credentials`, `invalid_client`), servidor caído, red— es «no disponible»: se reintenta, no se
 * borra nada. Una «simplificación» que meta aquí un código de configuración revocaría las conexiones de todos.
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

/** La URL a la que se manda al navegador para que Supabase autentique y pida el permiso. */
export function authorizeUrl(env: Env, state: string, codeChallenge: string): string {
  const u = new URL(`${authIssuer(env)}/oauth/authorize`);
  u.search = new URLSearchParams({
    response_type: "code",
    client_id: env.SUPABASE_OAUTH_CLIENT_ID,
    redirect_uri: upstreamCallbackUrl(env),
    code_challenge: codeChallenge,
    code_challenge_method: "S256",
    state,
  }).toString();
  return u.toString();
}

async function tokenRequest(env: Env, fetcher: Fetcher, body: Record<string, string>): Promise<UpstreamResult<UpstreamTokens>> {
  const f = guardSupabase(env, fetcher);
  let res: Response;
  try {
    res = await f(`${authIssuer(env)}/oauth/token`, {
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
  // Solo los códigos de la lista cerran la conexión. El resto se reintenta.
  const kind = DEFINITIVE_REJECT.has(code) ? "rejected" : "unavailable";
  return { ok: false, kind, status: res.status, code };
}

export function exchangeCode(env: Env, fetcher: Fetcher, code: string, verifier: string) {
  return tokenRequest(env, fetcher, {
    grant_type: "authorization_code",
    code,
    redirect_uri: upstreamCallbackUrl(env),
    code_verifier: verifier,
  });
}

export function refreshTokens(env: Env, fetcher: Fetcher, refresh: string) {
  return tokenRequest(env, fetcher, { grant_type: "refresh_token", refresh_token: refresh });
}

/**
 * ¿Sigue viva la sesión de Supabase? Es lo que hace que revocar corte AL MOMENTO: el access token es un JWT y
 * PostgREST lo aceptaría hasta que caduque (1 h), pero GoTrue carga la sesión en cada `GET /user`.
 *
 * - `alive`: 200.
 * - `gone`: la sesión, el usuario o el permiso ya no existen, o el usuario está bloqueado. Se retira la conexión.
 * - `stale`: el JWT no vale (caducó o no se reconoce). No se borra nada: el refresh dirá si la sesión sigue.
 * - `unknown`: no se pudo preguntar. Se falla cerrado (503) sin borrar nada.
 */
export async function sessionStatus(env: Env, fetcher: Fetcher, access: string): Promise<"alive" | "gone" | "stale" | "unknown"> {
  const f = guardSupabase(env, fetcher);
  let res: Response;
  try {
    res = await f(`${authIssuer(env)}/user`, { method: "GET", headers: headers(env, access) });
  } catch {
    return "unknown";
  }
  if (res.ok) return "alive";
  if (res.status !== 401 && res.status !== 403 && res.status !== 404) return "unknown";
  const code = await readError(res);
  const gone = ["session_not_found", "user_not_found", "user_banned", "session_expired", "refresh_token_not_found"];
  return gone.includes(code) ? "gone" : "stale";
}

// ─── Sesión web de la pantalla de login ─────────────────────────────────────────────────────────────────────────

/**
 * A dónde se manda al navegador para iniciar sesión con Apple o Google. Es el login social de Supabase en su flujo
 * PKCE: Supabase vuelve a `redirectTo` con `?code=…`, y ese código solo se canjea con el `verifier` que guardó el
 * Worker (`pkceLogin`). Sin JavaScript en la página: el flujo implícito dejaría el token en el fragmento, que el
 * servidor no ve.
 *
 * `redirectTo` tiene que estar permitido en Supabase: lo está porque es del mismo host que la Site URL (en staging,
 * la Site URL es este Worker; el runbook de producción lo repite).
 */
export function socialAuthorizeUrl(env: Env, provider: "apple" | "google", redirectTo: string, codeChallenge: string): string {
  const u = new URL(`${authIssuer(env)}/authorize`);
  u.search = new URLSearchParams({
    provider,
    redirect_to: redirectTo,
    code_challenge: codeChallenge,
    code_challenge_method: "s256",
  }).toString();
  return u.toString();
}

export interface WebSession {
  access: string;
  /** El usuario se creó en este mismo inicio de sesión (no tenía cuenta en la nube de Yala). */
  createdNow: boolean;
}

/**
 * Canje del código del login social (`grant_type=pkce`). Devuelve el access token de una sesión NORMAL: se cierra en
 * la misma petición, como la de contraseña. `null` si Supabase no lo acepta (código usado, caducado o de otro
 * navegador); lanza si no hay red.
 */
export async function pkceLogin(env: Env, fetcher: Fetcher, authCode: string, verifier: string, nowMs: number): Promise<WebSession | null> {
  const f = guardSupabase(env, fetcher);
  const res = await f(`${authIssuer(env)}/token?grant_type=pkce`, {
    method: "POST",
    headers: { ...headers(env), "Content-Type": "application/json" },
    body: JSON.stringify({ auth_code: authCode, code_verifier: verifier }),
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { access_token?: string; user?: { created_at?: string } };
  if (!body.access_token) return null;
  const created = Date.parse(body.user?.created_at ?? "");
  // Diez minutos: lo que dura el viaje a Apple o Google. Solo se usa para la auditoría.
  return { access: body.access_token, createdNow: Number.isFinite(created) && nowMs - created < 600_000 };
}

// ─── Login con contraseña (solo staging) ───────────────────────────────────────────────────────────────────────

/** Login con email y contraseña. Devuelve el access token de una sesión NORMAL: se cierra en la misma petición. */
export async function passwordLogin(env: Env, fetcher: Fetcher, email: string, password: string): Promise<string | null> {
  const f = guardSupabase(env, fetcher);
  const res = await f(`${authIssuer(env)}/token?grant_type=password`, {
    method: "POST",
    headers: { ...headers(env), "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { access_token?: string };
  return body.access_token ?? null;
}

export interface AuthorizationDetails {
  authorization_id?: string;
  redirect_uri?: string;
  /** Solo viene cuando el usuario ya había dado el permiso a este cliente: Supabase aprueba solo. */
  redirect_url?: string;
  scope?: string;
  client?: { id?: string; name?: string };
  user?: { id?: string; email?: string };
}

export async function getAuthorization(env: Env, fetcher: Fetcher, session: string, authorizationId: string) {
  const f = guardSupabase(env, fetcher);
  const res = await f(`${authIssuer(env)}/oauth/authorizations/${encodeURIComponent(authorizationId)}`, {
    method: "GET",
    headers: headers(env, session),
  });
  if (!res.ok) return { ok: false as const, status: res.status };
  return { ok: true as const, details: (await res.json()) as AuthorizationDetails };
}

export async function approveAuthorization(env: Env, fetcher: Fetcher, session: string, authorizationId: string): Promise<string | null> {
  const f = guardSupabase(env, fetcher);
  const res = await f(`${authIssuer(env)}/oauth/authorizations/${encodeURIComponent(authorizationId)}/consent`, {
    method: "POST",
    headers: { ...headers(env, session), "Content-Type": "application/json" },
    body: JSON.stringify({ action: "approve" }),
  });
  if (!res.ok) return null;
  const body = (await res.json()) as { redirect_url?: string };
  return body.redirect_url ?? null;
}

/** Cierra UNA sesión (`scope=local`). Si falla, el token caduca solo (1 h); no bloquea nada. */
export async function logout(env: Env, fetcher: Fetcher, token: string): Promise<void> {
  try {
    const f = guardSupabase(env, fetcher);
    await f(`${authIssuer(env)}/logout?scope=local`, { method: "POST", headers: headers(env, token) });
  } catch {
    // Ver arriba.
  }
}
