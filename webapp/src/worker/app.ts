/**
 * El Worker «yala-web»: sirve la página y hace de servidor de la web. Rutas:
 *
 *   GET  /api/config            clave pública de Turnstile y entorno (sin sesión)
 *   GET  /api/me                con sesión: el nombre de la cuenta. Sin ella, 401
 *   POST /auth/start            verifica Turnstile y manda al login de Apple o Google (vía Supabase)
 *   GET  /auth/callback         vuelta del login: entra (o explica por qué no) y deja la cookie
 *   POST /auth/password         SOLO staging: lo mismo con contraseña, para las pruebas de punta a punta
 *   POST /auth/logout           cierra la sesión web y la de Supabase que llevaba dentro
 *   lo demás                    la página (Vite), con las mismas cabeceras de seguridad
 *
 * Los POST exigen `Origin` = este origen (además de la cookie `SameSite=Lax`): un formulario de otro sitio no puede
 * hacer entrar ni salir a nadie.
 */
import { loginReturnUrl, isStaging, publicOrigin, type Env } from "./env";
import { configProblems } from "./config";
import { defaultFetch, guardEgress, type Fetcher } from "./egress";
import { withHeaders } from "./headers";
import { allow, clientIp } from "./ratelimit";
import { cloudKind } from "./cloud";
import {
  currentUser,
  grantReadOnly,
  logout,
  passwordLogin,
  pkceLogin,
  refreshTokens,
  socialAuthorizeUrl,
  type NormalSession,
} from "./supabase";
import { verifyTurnstile } from "./turnstile";
import { makeReaderVerifier, type ReaderVerifier } from "./verify";
import {
  LOGIN_COOKIE,
  LOGIN_TTL_SECONDS,
  SESSION_COOKIE,
  clearSessionCookie,
  createSession,
  deleteSession,
  loadSession,
  loginCookie,
  randomToken,
  readCookie,
  remainingSeconds,
  s256,
  saveSession,
  savePendingLogin,
  sessionCookie,
  takePendingLogin,
  type Session,
} from "./session";

export interface AppDeps {
  /** El `fetch` de salida SIN envolver: la app lo pasa siempre por la lista cerrada. */
  fetcher?: Fetcher;
  verify?: ReaderVerifier;
  nowSec?: () => number;
}

/** Margen con el que se refresca el acceso antes de que caduque. */
const REFRESH_MARGIN_SECONDS = 60;
const MAX_FORM_BYTES = 8 * 1024;

export type Aviso = "sin-nube" | "solo-grupos" | "error" | "cancelado" | "caducada" | "verificacion" | "salida" | "limite";

function log(evento: string, extra: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ evento, ...extra }));
}

function json(body: unknown, status = 200, extra: HeadersInit = {}): Response {
  return Response.json(body, { status, headers: extra });
}

function goTo(path: string, cookies: string[] = []): Response {
  const headers = new Headers({ Location: path });
  for (const c of cookies) headers.append("Set-Cookie", c);
  return new Response(null, { status: 303, headers });
}

function aviso(a: Aviso, cookies: string[] = []): Response {
  return goTo(`/?aviso=${a}`, cookies);
}

function sameOrigin(request: Request, env: Env): boolean {
  return request.headers.get("Origin") === publicOrigin(env);
}

async function readForm(request: Request): Promise<FormData | null> {
  const len = Number(request.headers.get("Content-Length") ?? "0");
  if (len > MAX_FORM_BYTES) return null;
  const type = request.headers.get("Content-Type") ?? "";
  if (!type.startsWith("application/x-www-form-urlencoded") && !type.startsWith("multipart/form-data")) return null;
  try {
    return await request.formData();
  } catch {
    return null;
  }
}

export function createApp(deps: AppDeps = {}) {
  const nowSec = deps.nowSec ?? (() => Math.floor(Date.now() / 1000));

  return {
    async fetch(request: Request, env: Env): Promise<Response> {
      const url = new URL(request.url);
      const problems = configProblems(env);
      if (problems.length > 0) {
        console.error(JSON.stringify({ evento: "config_invalida", problemas: problems }));
        return withHeaders(env as Env, url.pathname, json({ error: "no_disponible" }, 503, { "Retry-After": "300" }));
      }
      const fetcher = guardEgress(env, deps.fetcher ?? defaultFetch);
      const verify = deps.verify ?? makeReaderVerifier(env);
      const ctx = { env, fetcher, verify, now: nowSec() };
      let res: Response;
      try {
        res = await route(request, url, ctx);
      } catch (err) {
        console.error(JSON.stringify({ evento: "web_error", ruta: url.pathname, error: err instanceof Error ? err.name : "desconocido" }));
        res = url.pathname.startsWith("/api/") ? json({ error: "no_disponible" }, 503) : aviso("error");
      }
      return withHeaders(env, url.pathname, res);
    },
  };
}

interface Ctx {
  env: Env;
  fetcher: Fetcher;
  verify: ReaderVerifier;
  now: number;
}

async function route(request: Request, url: URL, ctx: Ctx): Promise<Response> {
  const { env } = ctx;
  const path = url.pathname;
  const method = request.method.toUpperCase();

  if (path.startsWith("/api/")) {
    if (method !== "GET") return json({ error: "metodo" }, 405);
    if (path === "/api/config") return json({ turnstileSiteKey: env.TURNSTILE_SITE_KEY, entorno: env.ENVIRONMENT });
    if (path === "/api/me") return me(request, ctx);
    return json({ error: "no_existe" }, 404);
  }

  if (path.startsWith("/auth/")) {
    if (!(await allow(env, "RL_AUTH", clientIp(request)))) {
      return method === "GET" ? aviso("limite") : new Response("Demasiados intentos. Prueba en un minuto.", { status: 429, headers: { "Retry-After": "60" } });
    }
    if (path === "/auth/callback" && method === "GET") return callback(request, url, ctx);
    if (method !== "POST") return new Response("No existe", { status: 404 });
    if (!sameOrigin(request, env)) return new Response("Origen no permitido", { status: 403 });
    if (path === "/auth/start") return start(request, ctx);
    if (path === "/auth/logout") return signOut(request, ctx);
    if (path === "/auth/password" && isStaging(env)) return passwordEntry(request, ctx);
    return new Response("No existe", { status: 404 });
  }

  // La página. Solo GET y HEAD; el resto no tiene nada que hacer aquí.
  if (method !== "GET" && method !== "HEAD") return new Response("No existe", { status: 405 });
  return env.ASSETS.fetch(request);
}

// ─── Entrar ────────────────────────────────────────────────────────────────────────────────────────────────────

async function start(request: Request, ctx: Ctx): Promise<Response> {
  const { env, fetcher } = ctx;
  const form = await readForm(request);
  const provider = form?.get("provider");
  if (provider !== "apple" && provider !== "google") return aviso("error");
  const shared = form?.get("compartido") === "1";
  const turnstile = form?.get("cf-turnstile-response");
  const human = await verifyTurnstile(env, fetcher, typeof turnstile === "string" ? turnstile : null, request.headers.get("CF-Connecting-IP"));
  if (!human) {
    log("web_turnstile_rechazado");
    return aviso("verificacion");
  }
  const verifier = randomToken();
  const nonce = await savePendingLogin(env.WEB_KV, { verifier, shared });
  const location = socialAuthorizeUrl(env, provider, loginReturnUrl(env), await s256(verifier));
  return goTo(location, [loginCookie(nonce, LOGIN_TTL_SECONDS)]);
}

async function callback(request: Request, url: URL, ctx: Ctx): Promise<Response> {
  const { env, fetcher } = ctx;
  const clear = loginCookie("", 0);
  const pending = await takePendingLogin(env.WEB_KV, readCookie(request, LOGIN_COOKIE));
  if (url.searchParams.has("error")) return aviso("cancelado", [clear]);
  const code = url.searchParams.get("code");
  if (!pending) return aviso("caducada", [clear]);
  if (!code || code.length > 512) return aviso("error", [clear]);
  const normal = await pkceLogin(env, fetcher, code, pending.verifier);
  if (!normal) return aviso("caducada", [clear]);
  return finishLogin(ctx, normal, pending.shared, [clear]);
}

async function passwordEntry(request: Request, ctx: Ctx): Promise<Response> {
  const form = await readForm(request);
  const email = form?.get("email");
  const password = form?.get("password");
  if (typeof email !== "string" || typeof password !== "string" || email.length > 200 || password.length > 200) return aviso("error");
  const normal = await passwordLogin(ctx.env, ctx.fetcher, email, password);
  if (!normal) return aviso("error");
  return finishLogin(ctx, normal, form?.get("compartido") === "1");
}

/**
 * Con la sesión NORMAL recién abierta: comprueba la nube, consigue la de solo lectura y cierra la normal. Pase lo que
 * pase, la normal no sale de esta función abierta.
 */
async function finishLogin(ctx: Ctx, normal: NormalSession, shared: boolean, cookies: string[] = []): Promise<Response> {
  const { env, fetcher, verify, now } = ctx;
  try {
    const kind = await cloudKind(env, fetcher, normal.access);
    if (kind !== "complete") {
      log("web_entrada_sin_nube", { tipo: kind });
      return aviso(kind === "groups_only" ? "solo-grupos" : "sin-nube", cookies);
    }
    const verifier = randomToken();
    const grant = await grantReadOnly(env, fetcher, normal, { verifier, challenge: await s256(verifier), state: randomToken(16) });
    if (!grant.ok) {
      log("web_permiso_fallido", { paso: grant.step, estado: grant.status ?? null });
      return aviso("error", cookies);
    }
    const check = await verify(grant.tokens.access, normal.userId);
    if (!check.ok) {
      // No es de solo lectura, o no es de la web, o no es de este usuario: no se guarda. Se cierra para no dejarla viva.
      await logout(env, fetcher, grant.tokens.access);
      log("web_permiso_rechazado", { motivo: check.reason });
      return aviso("error", cookies);
    }
    const token = await createSession(
      env.WEB_KV,
      { sub: check.claims.sub, sid: check.claims.sessionId, access: grant.tokens.access, accessExp: check.claims.exp, refresh: grant.tokens.refresh },
      shared,
      now,
    );
    log("web_entrada", { compartido: shared });
    return goTo("/", [...cookies, sessionCookie(token, shared, remainingSeconds({ createdAt: now, lastSeen: now, shared }, now))]);
  } finally {
    await logout(env, fetcher, normal.access);
  }
}

// ─── Con sesión ────────────────────────────────────────────────────────────────────────────────────────────────

type Fresh = { ok: true; changed: boolean } | { ok: false; gone: boolean };

/** Refresca el acceso si está por caducar (o si `force`). `gone`: la sesión ya no sirve y se borra. */
async function ensureFresh(ctx: Ctx, session: Session, force = false): Promise<Fresh> {
  const { env, fetcher, verify, now } = ctx;
  if (!force && session.accessExp - now > REFRESH_MARGIN_SECONDS) return { ok: true, changed: false };
  const r = await refreshTokens(env, fetcher, session.refresh);
  if (!r.ok) {
    if (r.kind === "rejected") log("web_sesion_retirada", { motivo: `supabase_${r.code}` });
    return { ok: false, gone: r.kind === "rejected" };
  }
  const check = await verify(r.value.access, session.sub);
  if (!check.ok) {
    if (check.reason === "unavailable") return { ok: false, gone: false };
    await logout(env, fetcher, r.value.access);
    log("web_sesion_retirada", { motivo: `token_${check.reason}` });
    return { ok: false, gone: true };
  }
  session.access = r.value.access;
  session.refresh = r.value.refresh;
  session.accessExp = check.claims.exp;
  session.sid = check.claims.sessionId;
  return { ok: true, changed: true };
}

function unauthorized(hadCookie: boolean): Response {
  return json({ error: "sin_sesion" }, 401, hadCookie ? { "Set-Cookie": clearSessionCookie() } : {});
}

async function me(request: Request, ctx: Ctx): Promise<Response> {
  const { env, fetcher, now } = ctx;
  const token = readCookie(request, SESSION_COOKIE);
  const session = await loadSession(env.WEB_KV, token, now);
  if (!token || !session) return unauthorized(!!token);
  if (!(await allow(env, "RL_API", session.sid))) return json({ error: "limite" }, 429, { "Retry-After": "60" });

  let fresh = await ensureFresh(ctx, session);
  if (!fresh.ok) {
    if (!fresh.gone) return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
    await deleteSession(env.WEB_KV, token);
    return unauthorized(true);
  }
  let changed = fresh.changed;
  let user = await currentUser(env, fetcher, session.access);
  if (user.status === "stale" && !changed) {
    // El JWT dejó de valer antes de lo previsto (reloj, rotación de claves): un refresh y otra vez.
    fresh = await ensureFresh(ctx, session, true);
    if (!fresh.ok) {
      if (!fresh.gone) return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
      await deleteSession(env.WEB_KV, token);
      return unauthorized(true);
    }
    changed = true;
    user = await currentUser(env, fetcher, session.access);
  }
  if (user.status === "unknown") return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
  if (user.status !== "alive") {
    log("web_sesion_retirada", { motivo: `user_${user.status}` });
    await deleteSession(env.WEB_KV, token);
    return unauthorized(true);
  }

  const wrote = await saveSession(env.WEB_KV, token, session, now, changed);
  const headers: Record<string, string> = {};
  if (wrote && !session.shared) headers["Set-Cookie"] = sessionCookie(token, false, remainingSeconds(session, now));
  return json({ nombre: user.account.nombre, correo: user.account.correo, equipoCompartido: session.shared }, 200, headers);
}

async function signOut(request: Request, ctx: Ctx): Promise<Response> {
  const { env, fetcher, now } = ctx;
  const token = readCookie(request, SESSION_COOKIE);
  const session = await loadSession(env.WEB_KV, token, now);
  if (token && session) {
    // Cerrar también la sesión de Supabase. Con el acceso caducado `logout` no la encuentra: se refresca antes.
    const fresh = await ensureFresh(ctx, session).catch(() => ({ ok: false as const, gone: false }));
    if (fresh.ok) await logout(env, fetcher, session.access);
    await deleteSession(env.WEB_KV, token);
    log("web_salida", { supabase_cerrada: fresh.ok });
  } else if (token) {
    await deleteSession(env.WEB_KV, token);
  }
  return aviso("salida", [clearSessionCookie()]);
}
