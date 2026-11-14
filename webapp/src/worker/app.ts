/**
 * El Worker «yala-web»: sirve la página y hace de servidor de la web. Rutas:
 *
 *   GET  /api/config            clave pública de Turnstile y entorno (sin sesión)
 *   GET  /api/me                con sesión: el nombre de la cuenta. Sin ella, 401
 *   GET  /api/panel             saldos, entradas y salidas del mes y últimos registros (núcleo compartido)
 *   GET  /api/registros         movimientos de 50 en 50, con filtros (`buscar_movimientos`)
 *   GET  /api/categorias        categorías y subcategorías, para filtrar y para apuntar
 *   GET  /api/bandeja           lo pendiente en la Bandeja del iPhone y lo enviado que aún no recogió
 *   GET  /api/estadisticas      Resumen, Distribución y Tendencias de un período (`?periodo=`, lote 2)
 *   GET  /api/pagos             próximos cobros de 30 días y suscripciones (lote 2)
 *   POST /api/borradores        apuntar un gasto: a la cola común de borradores (decisión D9)
 *   GET  /api/sesiones          las sesiones web de la cuenta
 *   POST /api/sesiones/cerrar   cierra otra sesión web de la cuenta ({id}); `cerrar-otras` cierra todas menos esta
 *   GET  /api/dispositivo/sesiones          el iPhone («Navegadores conectados»), con el token de su sesión
 *   POST /api/dispositivo/sesiones/cerrar   ídem, una ({id}) o `cerrar-todas`
 *   POST /auth/start            verifica Turnstile y manda al login de Apple o Google (vía Supabase)
 *   GET  /auth/callback         vuelta del login: entra (o explica por qué no) y deja la cookie
 *   POST /auth/password         SOLO staging: lo mismo con contraseña, para las pruebas de punta a punta
 *   POST /auth/logout           cierra la sesión web y la de Supabase que llevaba dentro
 *   POST /auth/qr/start         entrar con el iPhone: verifica Turnstile y da un código QR ligado a este navegador
 *   POST /auth/qr/renovar       el código siguiente (cada 60 s, hasta 10 min) sin volver a Turnstile
 *   POST /auth/qr/estado        ¿lo aprobó el iPhone? Aprobado: abre la sesión web y deja la cookie
 *   GET  /api/dispositivo/vincular?codigo=   el iPhone lee un código: qué navegador y desde dónde
 *   POST /api/dispositivo/vincular           el iPhone lo aprueba, tras Face ID ({codigo})
 *   lo demás                    la página (Vite), con las mismas cabeceras de seguridad
 *
 * Los POST con cookie exigen `Origin` = este origen (además de la cookie `SameSite=Lax`): un formulario de otro sitio no
 * puede hacer entrar, salir ni apuntar a nadie. Las rutas `/api/dispositivo/*` no leen la cookie: solo el Bearer.
 */
import { loginReturnUrl, isStaging, publicOrigin, type Env } from "./env";
import { configProblems } from "./config";
import { defaultFetch, guardEgress, type Fetcher } from "./egress";
import { withHeaders } from "./headers";
import { allow, clientIp } from "./ratelimit";
import { cloudKind } from "./cloud";
import {
  authorizeReadOnly,
  closeWebSession,
  currentUser,
  exchangeReadOnly,
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
import { bearer, makeAppVerifier, type AppVerifier } from "./device";
import { approximateCity, describeBrowser } from "./ua";
import {
  QR_CHAIN_SECONDS,
  QR_CODE_TTL_SECONDS,
  QR_COOKIE,
  browserHash,
  displayCode,
  newPairingCode,
  normalizeCode,
  pairing,
  qrChallenge,
  qrCookie,
  qrVerifier,
  type PairingRecord,
} from "./pairing";
import { InvalidInputError, bandeja, categorias, estadisticas, pagos, panel, registros, toolContext } from "./data";
import { insertWebDraft, parseWebDraft, queuedWebDrafts, WEB_DRAFTS_PER_DAY } from "./drafts";
import { isPid, sessionIndex, toPublic, type SessionEntry } from "./sessions";
import {
  LOGIN_COOKIE,
  LOGIN_TTL_SECONDS,
  SESSION_COOKIE,
  clearSessionCookie,
  createSession,
  deleteSession,
  deleteSessionByKey,
  kvKey,
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
  /** Verifica el token de la app (iPhone) en `/api/dispositivo/*`. */
  appVerify?: AppVerifier;
  nowSec?: () => number;
}

/** Margen con el que se refresca el acceso antes de que caduque. */
const REFRESH_MARGIN_SECONDS = 60;
const MAX_FORM_BYTES = 8 * 1024;
const MAX_JSON_BYTES = 4 * 1024;

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
  // Sin `Content-Length` (chunked) no se sabe el tamaño antes de leer: se rechaza. Los formularios de los navegadores
  // siempre lo mandan.
  const raw = request.headers.get("Content-Length");
  const len = raw === null ? NaN : Number(raw);
  if (!Number.isFinite(len) || len > MAX_FORM_BYTES) return null;
  const type = request.headers.get("Content-Type") ?? "";
  if (!type.startsWith("application/x-www-form-urlencoded") && !type.startsWith("multipart/form-data")) return null;
  try {
    return await request.formData();
  } catch {
    return null;
  }
}

/** Un cuerpo JSON pequeño. `null` si no es JSON, no dice su tamaño o pasa de `MAX_JSON_BYTES`. */
async function readJson(request: Request): Promise<unknown | null> {
  const raw = request.headers.get("Content-Length");
  const len = raw === null ? NaN : Number(raw);
  if (!Number.isFinite(len) || len > MAX_JSON_BYTES) return null;
  if (!(request.headers.get("Content-Type") ?? "").startsWith("application/json")) return null;
  try {
    return await request.json();
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
      const appVerify = deps.appVerify ?? makeAppVerifier(env);
      const ctx = { env, fetcher, verify, appVerify, now: nowSec() };
      let res: Response;
      try {
        res = await route(request, url, ctx);
      } catch (err) {
        console.error(JSON.stringify({ evento: "web_error", ruta: url.pathname, error: err instanceof Error ? err.name : "desconocido" }));
        if (err instanceof InvalidInputError && url.pathname.startsWith("/api/")) res = json({ error: "entrada" }, 400);
        else res = url.pathname.startsWith("/api/") ? json({ error: "no_disponible" }, 503) : aviso("error");
      }
      return withHeaders(env, url.pathname, res);
    },
  };
}

interface Ctx {
  env: Env;
  fetcher: Fetcher;
  verify: ReaderVerifier;
  appVerify: AppVerifier;
  now: number;
}

async function route(request: Request, url: URL, ctx: Ctx): Promise<Response> {
  const { env } = ctx;
  const path = url.pathname;
  const method = request.method.toUpperCase();

  if (path.startsWith("/api/dispositivo/")) return deviceRoute(request, path, method, ctx);

  if (path.startsWith("/api/")) {
    if (method === "GET") {
      if (path === "/api/config") return json({ turnstileSiteKey: env.TURNSTILE_SITE_KEY, entorno: env.ENVIRONMENT });
      if (path === "/api/me") return withLive(request, ctx, async (live) => json({ nombre: live.account.nombre, correo: live.account.correo, equipoCompartido: live.session.shared }));
      if (path === "/api/panel") return withLive(request, ctx, async (live) => json(await panel(readCtx(ctx, live))));
      if (path === "/api/registros") return withLive(request, ctx, async (live) => json(await registros(readCtx(ctx, live), url.searchParams)));
      if (path === "/api/categorias") return withLive(request, ctx, async (live) => json(await categorias(readCtx(ctx, live))));
      if (path === "/api/bandeja") return withLive(request, ctx, (live) => inbox(ctx, live));
      if (path === "/api/estadisticas") return withLive(request, ctx, async (live) => json(await estadisticas(readCtx(ctx, live), url.searchParams)));
      if (path === "/api/pagos") return withLive(request, ctx, async (live) => json(await pagos(readCtx(ctx, live))));
      if (path === "/api/sesiones") return withLive(request, ctx, async (live) => json({ sesiones: await liveEntries(ctx, live.session.sub, live.session.pid) }));
      return json({ error: "no_existe" }, 404);
    }
    if (method !== "POST") return json({ error: "metodo" }, 405);
    if (!sameOrigin(request, env)) return json({ error: "origen" }, 403);
    if (path === "/api/borradores") return withLive(request, ctx, (live) => newDraft(request, ctx, live));
    if (path === "/api/sesiones/cerrar") return withLive(request, ctx, (live) => closeOne(request, ctx, live.session.sub, live.session.access, live.session.pid));
    if (path === "/api/sesiones/cerrar-otras") return withLive(request, ctx, (live) => closeAll(ctx, live.session.sub, live.session.access, live.session.pid));
    return json({ error: "no_existe" }, 404);
  }

  if (path.startsWith("/auth/qr/")) {
    if (method !== "POST") return json({ error: "metodo" }, 405);
    if (!sameOrigin(request, env)) return json({ error: "origen" }, 403);
    const bucket = path === "/auth/qr/start" ? "RL_AUTH" : "RL_QR";
    if (!(await allow(env, bucket, clientIp(request)))) return json({ error: "limite" }, 429, { "Retry-After": "60" });
    if (path === "/auth/qr/start") return qrStart(request, ctx);
    if (path === "/auth/qr/renovar") return qrRenew(request, ctx);
    if (path === "/auth/qr/estado") return qrStatus(request, ctx);
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
  return finishLogin(ctx, request, normal, pending.shared, [clear]);
}

async function passwordEntry(request: Request, ctx: Ctx): Promise<Response> {
  const form = await readForm(request);
  const email = form?.get("email");
  const password = form?.get("password");
  if (typeof email !== "string" || typeof password !== "string" || email.length > 200 || password.length > 200) return aviso("error");
  const normal = await passwordLogin(ctx.env, ctx.fetcher, email, password);
  if (!normal) return aviso("error");
  return finishLogin(ctx, request, normal, form?.get("compartido") === "1");
}

/**
 * Con la sesión NORMAL recién abierta: comprueba la nube, consigue la de solo lectura y cierra la normal. Pase lo que
 * pase, la normal no sale de esta función abierta.
 */
async function finishLogin(ctx: Ctx, request: Request, normal: NormalSession, shared: boolean, cookies: string[] = []): Promise<Response> {
  const { env, fetcher } = ctx;
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
    const opened = await openReaderSession(ctx, request, grant.tokens, normal.userId, shared);
    if (!opened) return aviso("error", cookies);
    log("web_entrada", { compartido: shared });
    return goTo("/", [...cookies, opened.cookie]);
  } finally {
    await logout(env, fetcher, normal.access);
  }
}

/**
 * Con los tokens de solo lectura recién canjeados: los comprueba (rol de la web, de este usuario), abre la sesión web,
 * la apunta en la lista de sesiones y cierra la que el navegador ya trajera. `null` si los tokens no valen (y entonces
 * se cierran). La comparten entrar con Apple o Google y el QR.
 */
async function openReaderSession(
  ctx: Ctx,
  request: Request,
  tokens: { access: string; refresh: string },
  expectedSub: string,
  shared: boolean,
): Promise<{ cookie: string } | null> {
  const { env, fetcher, verify, now } = ctx;
  const check = await verify(tokens.access, expectedSub);
  if (!check.ok) {
    // No es de solo lectura, o no es de la web, o no es de este usuario: no se guarda. Se cierra para no dejarla viva.
    await logout(env, fetcher, tokens.access);
    log("web_permiso_rechazado", { motivo: check.reason });
    return null;
  }
  let token: string;
  const pid = randomToken(9);
  try {
    token = await createSession(
      env.WEB_KV,
      { sub: check.claims.sub, sid: check.claims.sessionId, access: tokens.access, accessExp: check.claims.exp, refresh: tokens.refresh },
      shared,
      now,
      pid,
    );
    const browser = describeBrowser(request.headers.get("User-Agent"));
    await sessionIndex(env, check.claims.sub).put(
      { pid, k: await kvKey(token), sid: check.claims.sessionId, creada: now, uso: now, compartido: shared, ...browser, ciudad: approximateCity(request) },
      now + remainingSeconds({ createdAt: now, lastSeen: now, shared }, now),
    );
  } catch (err) {
    // Sin dónde guardarla, la sesión de lectura no la usaría nadie: se cierra en vez de dejarla viva.
    await logout(env, fetcher, tokens.access);
    throw err;
  }
  // Si el navegador ya traía una sesión (volvió a entrar sin salir), la anterior se cierra: una cookie vieja no debe
  // seguir valiendo 30 días.
  await closeSession(ctx, readCookie(request, SESSION_COOKIE));
  return { cookie: sessionCookie(token, shared, remainingSeconds({ createdAt: now, lastSeen: now, shared }, now)) };
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

interface Live {
  token: string;
  session: Session;
  account: { nombre: string; correo: string | null };
}

/** Borra una sesión que ya no sirve: la del KV y su entrada en la lista. */
async function dropSession(ctx: Ctx, token: string, session: Session): Promise<void> {
  await deleteSession(ctx.env.WEB_KV, token);
  if (session.pid) await sessionIndex(ctx.env, session.sub).remove(session.pid);
}

/**
 * La sesión de esta cookie, VIVA: refrescada si toca y comprobada contra Supabase (`GET /user`) en cada petición. Esa
 * comprobación es lo que hace que una sesión cerrada desde el iPhone deje de leer al momento: PostgREST no mira si la
 * sesión de Supabase sigue abierta, `GET /user` sí. Si sigue viva, corre `handler` y renueva la cookie al salir.
 */
async function withLive(request: Request, ctx: Ctx, handler: (live: Live) => Promise<Response>): Promise<Response> {
  const { env, fetcher, now } = ctx;
  const token = readCookie(request, SESSION_COOKIE);
  const session = await loadSession(env.WEB_KV, token, now);
  if (!token || !session) return unauthorized(!!token);
  if (!(await allow(env, "RL_API", session.sid))) return json({ error: "limite" }, 429, { "Retry-After": "60" });
  // La lista de sesiones manda. Una sesión que no está en ella (cerrada desde el iPhone u otra pestaña, aunque el KV aún
  // sirva una copia vieja en otro punto de presencia; o del lote 0, sin id) no lee, y se borra.
  if (!session.pid || !(await sessionIndex(env, session.sub).has(session.pid, now))) {
    log("web_sesion_retirada", { motivo: session.pid ? "fuera_de_la_lista" : "sin_id" });
    await logout(env, fetcher, session.access);
    await deleteSession(env.WEB_KV, token);
    return unauthorized(true);
  }

  let fresh = await ensureFresh(ctx, session);
  if (!fresh.ok) {
    if (!fresh.gone) return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
    await dropSession(ctx, token, session);
    return unauthorized(true);
  }
  let changed = fresh.changed;
  let user = await currentUser(env, fetcher, session.access);
  if (user.status === "stale" && !changed) {
    // El JWT dejó de valer antes de lo previsto (reloj, rotación de claves): un refresh y otra vez.
    fresh = await ensureFresh(ctx, session, true);
    if (!fresh.ok) {
      if (!fresh.gone) return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
      await dropSession(ctx, token, session);
      return unauthorized(true);
    }
    changed = true;
    user = await currentUser(env, fetcher, session.access);
  }
  // Solo `gone` borra: un 4xx sin código de GoTrue (un proxy, un WAF) dice que no se sabe, no que la sesión murió.
  if (user.status === "unknown" || user.status === "stale") return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
  if (user.status !== "alive") {
    log("web_sesion_retirada", { motivo: `user_${user.status}` });
    await dropSession(ctx, token, session);
    return unauthorized(true);
  }

  const res = await handler({ token, session, account: user.account });
  const wrote = await saveSession(env.WEB_KV, token, session, now, changed);
  if (wrote && session.pid) await touchEntry(ctx, session).catch(() => undefined);
  if (wrote && !session.shared) res.headers.append("Set-Cookie", sessionCookie(token, false, remainingSeconds(session, now)));
  return res;
}

/** Mueve «último uso» (y el `session_id`, si un refresh lo cambió) en la entrada de la lista. */
async function touchEntry(ctx: Ctx, session: Session): Promise<void> {
  if (!session.pid) return;
  await sessionIndex(ctx.env, session.sub).touch(session.pid, ctx.now, session.sid, ctx.now + remainingSeconds(session, ctx.now));
}

function readCtx(ctx: Ctx, live: Live) {
  return toolContext(ctx.env, ctx.fetcher, live.session.access, new Date(ctx.now * 1000));
}

// ─── Bandeja y apuntar ─────────────────────────────────────────────────────────────────────────────────────────

async function inbox(ctx: Ctx, live: Live): Promise<Response> {
  const [pendientes, enviados] = await Promise.all([bandeja(readCtx(ctx, live)), queuedWebDrafts(ctx.env, live.session.sub, ctx.now * 1000)]);
  return json({ pendientes, enviados });
}

async function newDraft(request: Request, ctx: Ctx, live: Live): Promise<Response> {
  const body = await readJson(request);
  if (body === null) return json({ error: "entrada" }, 400);
  const nowMs = ctx.now * 1000;
  const parsed = parseWebDraft(body, nowMs);
  if (!parsed.ok) return json({ error: "entrada", campo: parsed.campo }, 400);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  if (!(await sessionIndex(ctx.env, live.session.sub).takeDraftSlot(day, WEB_DRAFTS_PER_DAY))) {
    log("web_borrador_tope");
    return json({ error: "tope_diario", tope: WEB_DRAFTS_PER_DAY }, 429);
  }
  const id = await insertWebDraft(ctx.env, live.session.sub, parsed.value, nowMs);
  log("web_borrador");
  return json({ id }, 201);
}

// ─── Sesiones ──────────────────────────────────────────────────────────────────────────────────────────────────

/** Las sesiones vivas de la cuenta (las caducadas las retira el propio índice al leer). */
async function liveEntries(ctx: Ctx, sub: string, currentPid: string | null) {
  return (await sessionIndex(ctx.env, sub).list(ctx.now)).map((e) => toPublic(e, currentPid));
}

/** Cierra una sesión de la lista: su sesión de Supabase (con el token de quien cierra), la del KV y la entrada. */
async function closeEntry(ctx: Ctx, sub: string, callerToken: string, e: SessionEntry): Promise<boolean> {
  const supabase = await closeWebSession(ctx.env, ctx.fetcher, callerToken, e.sid);
  await deleteSessionByKey(ctx.env.WEB_KV, e.k);
  await sessionIndex(ctx.env, sub).remove(e.pid);
  return supabase;
}

async function closeOne(request: Request, ctx: Ctx, sub: string, callerToken: string, currentPid: string | null): Promise<Response> {
  const body = (await readJson(request)) as { id?: unknown } | null;
  const id = body?.id;
  if (!isPid(id)) return json({ error: "entrada" }, 400);
  // Esta misma sesión se cierra con «Salir», que además borra la cookie.
  if (id === currentPid) return json({ error: "es_esta" }, 409);
  const e = (await sessionIndex(ctx.env, sub).list(ctx.now)).find((x) => x.pid === id);
  if (!e) return json({ cerradas: 0 });
  const supabase = await closeEntry(ctx, sub, callerToken, e);
  log("web_sesion_cerrada", { desde: currentPid ? "web" : "iphone", supabase_cerrada: supabase });
  return json({ cerradas: 1 });
}

async function closeAll(ctx: Ctx, sub: string, callerToken: string, currentPid: string | null): Promise<Response> {
  const entries = (await sessionIndex(ctx.env, sub).list(ctx.now)).filter((e) => e.pid !== currentPid);
  let supabase = 0;
  for (const e of entries) if (await closeEntry(ctx, sub, callerToken, e)) supabase++;
  log("web_sesiones_cerradas", { desde: currentPid ? "web" : "iphone", n: entries.length, supabase_cerradas: supabase });
  return json({ cerradas: entries.length });
}

// ─── El iPhone («Navegadores conectados») ──────────────────────────────────────────────────────────────────────

async function deviceRoute(request: Request, path: string, method: string, ctx: Ctx): Promise<Response> {
  const raw = bearer(request);
  if (!raw) return json({ error: "sin_sesion" }, 401);
  const check = await ctx.appVerify(raw);
  if (!check.ok) return check.reason === "unavailable" ? json({ error: "no_disponible" }, 503, { "Retry-After": "30" }) : json({ error: "sin_sesion" }, 401);
  if (!(await allow(ctx.env, "RL_API", `app:${check.sub}`))) return json({ error: "limite" }, 429, { "Retry-After": "60" });
  // La firma sola no basta: un token de una sesión de la app ya cerrada vale hasta su `exp`. `GET /user` sí lo sabe.
  const alive = await currentUser(ctx.env, ctx.fetcher, raw);
  if (alive.status === "unknown") return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
  if (alive.status !== "alive") return json({ error: "sin_sesion" }, 401);
  if (path === "/api/dispositivo/vincular" && method === "GET") return qrPeek(request, ctx, check.sub);
  if (path === "/api/dispositivo/vincular" && method === "POST") return qrApprove(request, ctx, check.sub, raw);
  if (path === "/api/dispositivo/sesiones" && method === "GET") return json({ sesiones: await liveEntries(ctx, check.sub, null) });
  if (path === "/api/dispositivo/sesiones/cerrar" && method === "POST") return closeOne(request, ctx, check.sub, raw, null);
  if (path === "/api/dispositivo/sesiones/cerrar-todas" && method === "POST") return closeAll(ctx, check.sub, raw, null);
  return json({ error: "no_existe" }, 404);
}

/**
 * Cierra la sesión web de esta cookie y la de Supabase que lleva dentro. Con el acceso caducado `logout` no la
 * encuentra: se refresca antes; si el refresh no responde, se intenta igual con el acceso guardado.
 */
async function closeSession(ctx: Ctx, token: string | null): Promise<boolean> {
  const { env, fetcher, now } = ctx;
  if (!token) return false;
  const session = await loadSession(env.WEB_KV, token, now);
  let closed = false;
  if (session) {
    const fresh = await ensureFresh(ctx, session).catch(() => ({ ok: false as const, gone: false }));
    await logout(env, fetcher, session.access);
    closed = fresh.ok;
    if (session.pid) await sessionIndex(env, session.sub).remove(session.pid);
  }
  await deleteSession(env.WEB_KV, token);
  return closed;
}

async function signOut(request: Request, ctx: Ctx): Promise<Response> {
  const token = readCookie(request, SESSION_COOKIE);
  if (token) log("web_salida", { supabase_cerrada: await closeSession(ctx, token) });
  return aviso("salida", [clearSessionCookie()]);
}

// ─── Entrar con el iPhone (QR, lote 2) ─────────────────────────────────────────────────────────────────────────

/** Crea el objeto de un código nuevo. Reintenta si el código ya existía (40 bits: prácticamente nunca). */
async function newCode(ctx: Ctx, base: Omit<PairingRecord, "creada" | "expira">): Promise<string> {
  for (let i = 0; i < 3; i++) {
    const code = newPairingCode();
    const created = await pairing(ctx.env, code).create({ ...base, creada: ctx.now, expira: ctx.now + QR_CODE_TTL_SECONDS });
    if (created) return code;
  }
  throw new Error("qr: sin código libre");
}

function codeResponse(env: Env, code: string, now: number, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { codigo: displayCode(code), url: `${publicOrigin(env)}/v/${code}`, expira: now + QR_CODE_TTL_SECONDS, ...extra };
}

async function qrStart(request: Request, ctx: Ctx): Promise<Response> {
  const { env, fetcher, now } = ctx;
  const body = (await readJson(request)) as { turnstile?: unknown; compartido?: unknown } | null;
  const token = typeof body?.turnstile === "string" ? body.turnstile : null;
  if (!(await verifyTurnstile(env, fetcher, token, request.headers.get("CF-Connecting-IP")))) {
    log("web_qr_turnstile_rechazado");
    return json({ error: "verificacion" }, 403);
  }
  const secret = randomToken();
  const browser = describeBrowser(request.headers.get("User-Agent"));
  const code = await newCode(ctx, {
    bh: await browserHash(secret),
    challenge: await qrChallenge(secret),
    inicio: now,
    compartido: body?.compartido === true,
    ...browser,
    ciudad: approximateCity(request),
  });
  log("web_qr_codigo");
  return json(codeResponse(env, code, now), 200, { "Set-Cookie": qrCookie(secret, QR_CHAIN_SECONDS + 180) });
}

async function qrRenew(request: Request, ctx: Ctx): Promise<Response> {
  const { env, now } = ctx;
  const secret = readCookie(request, QR_COOKIE);
  const body = (await readJson(request)) as { codigo?: unknown } | null;
  const old = normalizeCode(body?.codigo);
  if (!secret || !old) return json({ error: "caducado" }, 410);
  const bh = await browserHash(secret);
  const prev = await pairing(env, old).retire(bh, now);
  // Leído por el iPhone, aprobado, de otro navegador o pasados 10 minutos: no se renueva.
  if (!prev || now - prev.inicio > QR_CHAIN_SECONDS) return json({ error: "caducado" }, 410);
  const code = await newCode(ctx, { bh, challenge: await qrChallenge(secret), ...prev });
  return json(codeResponse(env, code, now));
}

async function qrStatus(request: Request, ctx: Ctx): Promise<Response> {
  const { env, fetcher, now } = ctx;
  const secret = readCookie(request, QR_COOKIE);
  const body = (await readJson(request)) as { codigo?: unknown } | null;
  const code = normalizeCode(body?.codigo);
  if (!secret || !code) return json({ estado: "caducado" });
  const st = await pairing(env, code).status(await browserHash(secret), now);
  if (st.estado !== "aprobado") return json(st.estado === "caducado" ? { estado: "caducado" } : { estado: st.estado, expira: st.expira });

  // Aprobado: el código de autorización solo se canjea con el `verifier` que sale de ESTA cookie.
  const clearQr = qrCookie("", 0);
  const grant = await exchangeReadOnly(env, fetcher, st.auth, await qrVerifier(secret));
  if (!grant.ok) {
    log("web_qr_canje_fallido", { estado: grant.status ?? null });
    return json({ estado: "error" }, 200, { "Set-Cookie": clearQr });
  }
  const opened = await openReaderSession(ctx, request, grant.tokens, st.sub, st.compartido);
  if (!opened) return json({ estado: "error" }, 200, { "Set-Cookie": clearQr });
  log("web_entrada", { compartido: st.compartido, via: "qr" });
  const headers = new Headers();
  headers.append("Set-Cookie", clearQr);
  headers.append("Set-Cookie", opened.cookie);
  return json({ estado: "dentro" }, 200, headers);
}

/** El iPhone lee un código: queda suyo y recibe qué navegador lo pidió y desde dónde. */
async function qrPeek(request: Request, ctx: Ctx, sub: string): Promise<Response> {
  const code = normalizeCode(new URL(request.url).searchParams.get("codigo"));
  if (!code) return json({ error: "codigo" }, 400);
  const claimed = await pairing(ctx.env, code).claim(sub, ctx.now);
  if (!claimed) return json({ error: "caducado" }, 404);
  return json({ codigo: displayCode(code), ...claimed.info });
}

/**
 * El iPhone aprueba, tras Face ID. Con SU sesión (que no se guarda): comprueba que la cuenta usa la nube, pide el
 * permiso de solo lectura de la web con el `challenge` del código y deja en el objeto solo el código de autorización.
 */
async function qrApprove(request: Request, ctx: Ctx, sub: string, appToken: string): Promise<Response> {
  const { env, fetcher, now } = ctx;
  const body = (await readJson(request)) as { codigo?: unknown } | null;
  const code = normalizeCode(body?.codigo);
  if (!code) return json({ error: "codigo" }, 400);
  const obj = pairing(env, code);
  const claimed = await obj.claim(sub, now);
  if (!claimed) return json({ error: "caducado" }, 404);
  const kind = await cloudKind(env, fetcher, appToken);
  if (kind !== "complete") return json({ error: kind === "groups_only" ? "solo_grupos" : "sin_nube" }, 409);
  const auth = await authorizeReadOnly(env, fetcher, { access: appToken, userId: sub }, { challenge: claimed.challenge, state: randomToken(16) });
  if (!auth.ok) {
    log("web_qr_permiso_fallido", { paso: auth.step, estado: auth.status ?? null });
    return json({ error: "no_disponible" }, 503, { "Retry-After": "30" });
  }
  if (!(await obj.approve(sub, auth.code, now))) return json({ error: "caducado" }, 404);
  log("web_qr_aprobado");
  return json({ ok: true, navegador: claimed.info.navegador, sistema: claimed.info.sistema });
}
