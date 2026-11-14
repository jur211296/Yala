/**
 * El mundo de las pruebas del Worker: un Supabase falso con estado (login social, servidor OAuth, hook que marca el
 * rol, sesiones y `GET /user`), Turnstile falso, un KV en memoria y un navegador con cookies.
 *
 * El falso modela lo que la web DEPENDE de que Supabase haga, con su forma real (medida el 13-nov contra staging):
 * `GET /oauth/authorize` responde 302 a la Site URL con `authorization_id`, y el hook da `yala_mcp_reader` SOLO a los
 * clientes OAuth de la lista. Las palancas (`hookOff`, `failRefresh`…) simulan lo que puede ir mal.
 */
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK, type JWTVerifyGetKey } from "jose";
import { createApp } from "../src/worker/app";
import { makeAppVerifier } from "../src/worker/device";
import type { Env, RateLimiter } from "../src/worker/env";
import { makeReaderVerifier } from "../src/worker/verify";
import { TURNSTILE_VERIFY_URL } from "../src/worker/egress";
import { PairingCell, type PairingRecord } from "../src/worker/pairing";

// El proyecto de staging: un Worker con ENVIRONMENT=staging solo atiende contra él (config.ts).
export const SB_URL = "https://fostjbbwstyuunmmefuk.supabase.co";
export const BASE = "https://web.yala.test";
export const WEB_CLIENT = "0f0e0d0c-0b0a-4908-8706-050403020100";
export const WEB_SECRET = "secreto-de-la-web";
export const CONNECTOR_CLIENT = "65fb5767-59a5-4f50-b77c-7970e67589c5";
export const TURNSTILE_OK = "token-humano";

export class MemoryKV {
  readonly data = new Map<string, { value: string; ttl?: number; metadata?: unknown }>();
  async get(key: string) {
    return this.data.get(key)?.value ?? null;
  }
  async getWithMetadata(key: string) {
    const e = this.data.get(key);
    return { value: e?.value ?? null, metadata: e?.metadata ?? null };
  }
  async put(key: string, value: string, opts?: { expirationTtl?: number; metadata?: unknown }) {
    this.data.set(key, { value, ttl: opts?.expirationTtl, metadata: opts?.metadata === undefined ? undefined : JSON.parse(JSON.stringify(opts.metadata)) });
  }
  async delete(key: string) {
    this.data.delete(key);
  }
  /** Sesiones guardadas (`s:`), sin contar las entradas de la lista de sesiones (`u:`), que caducan con ellas. */
  sessionCount(): number {
    return [...this.data.keys()].filter((k) => k.startsWith("s:")).length;
  }
  async list(opts: { prefix?: string; limit?: number } = {}) {
    const keys = [...this.data.entries()]
      .filter(([k]) => k.startsWith(opts.prefix ?? ""))
      .sort(([a], [b]) => a.localeCompare(b))
      .slice(0, opts.limit ?? 1000)
      .map(([name, e]) => ({ name, metadata: e.metadata }));
    return { keys, list_complete: true, cacheStatus: null };
  }
}

/** El doble del Durable Object de la lista de sesiones: un mapa por cuenta, con la misma API RPC. */
/** Los objetos de los códigos QR: la lógica REAL (`PairingCell`) sobre un `Map` por código. */
export class FakeQrPairingNamespace {
  readonly records = new Map<string, PairingRecord>();
  idFromName(name: string) {
    return name;
  }
  get(id: string) {
    return new PairingCell({
      read: async () => {
        const r = this.records.get(id);
        return r ? (JSON.parse(JSON.stringify(r)) as PairingRecord) : null;
      },
      write: async (rec) => void this.records.set(id, JSON.parse(JSON.stringify(rec)) as PairingRecord),
      drop: async () => void this.records.delete(id),
    });
  }
}

export class FakeSessionIndexNamespace {
  readonly byUser = new Map<string, Map<string, { entry: Record<string, unknown>; expira: number }>>();
  readonly slots = new Map<string, number>();
  idFromName(name: string) {
    return name;
  }
  get(id: string) {
    const rows = this.byUser.get(id) ?? new Map();
    this.byUser.set(id, rows);
    const copy = <T>(x: T): T => JSON.parse(JSON.stringify(x)) as T;
    return {
      put: async (entry: Record<string, unknown>, expira: number) => void rows.set(entry.pid as string, { entry: copy(entry), expira }),
      remove: async (pid: string) => void rows.delete(pid),
      list: async (now: number) => {
        for (const [pid, r] of rows) if (r.expira <= now) rows.delete(pid);
        return [...rows.values()].map((r) => copy(r.entry)).sort((a, b) => (b.uso as number) - (a.uso as number));
      },
      touch: async (pid: string, uso: number, sid: string, expira: number) => {
        const r = rows.get(pid);
        if (r) rows.set(pid, { entry: { ...r.entry, uso, sid }, expira });
      },
      has: async (pid: string, now: number) => {
        const r = rows.get(pid);
        return !!r && r.expira > now;
      },
      takeDraftSlot: async (dia: string, max: number) => {
        const key = `${id}:${dia}`;
        const n = this.slots.get(key) ?? 0;
        if (n >= max) return false;
        this.slots.set(key, n + 1);
        return true;
      },
    };
  }
  count(): number {
    return [...this.byUser.values()].reduce((n, m) => n + m.size, 0);
  }
}

/**
 * Un D1 de verdad (SQLite en memoria, `node:sqlite`) con el esquema de la cola del gateway: la web escribe en la tabla
 * real `mail_drafts` con su SQL real, JSON incluido.
 */
export class MemoryD1 {
  readonly db = new DatabaseSync(":memory:");
  constructor() {
    this.db.exec(readFileSync(new URL("../../gateway/migrations/0003_mail_forwarding.sql", import.meta.url), "utf8"));
  }
  prepare(sql: string) {
    const stmt = this.db.prepare(sql);
    const make = (args: unknown[]) => ({
      bind: (...more: unknown[]) => make([...args, ...more]),
      first: async <T>() => (stmt.get(...(args as never[])) as T | undefined) ?? null,
      all: async <T>() => ({ results: stmt.all(...(args as never[])) as T[] }),
      run: async () => ({ meta: { changes: Number(stmt.run(...(args as never[])).changes) } }),
    });
    return make([]);
  }
  rows(): { id: string; user_id: string; created_at: number; payload: Record<string, unknown> }[] {
    return (this.db.prepare("SELECT * FROM mail_drafts ORDER BY created_at").all() as { id: string; user_id: string; created_at: number; payload: string }[]).map(
      (r) => ({ ...r, payload: JSON.parse(r.payload) as Record<string, unknown> }),
    );
  }
}

export class FakeLimiter implements RateLimiter {
  private readonly counts = new Map<string, number>();
  constructor(private readonly max = Number.POSITIVE_INFINITY) {}
  async limit({ key }: { key: string }) {
    const n = (this.counts.get(key) ?? 0) + 1;
    this.counts.set(key, n);
    return { success: n <= this.max };
  }
}

export interface TestUser {
  id: string;
  email: string;
  password: string;
  name?: string;
  kind: "complete" | "groups_only" | null;
}

interface Sess {
  id: string;
  userId: string;
  clientId: string | null;
  refresh: string;
}

interface Authz {
  id: string;
  clientId: string;
  redirectUri: string;
  challenge: string;
  state: string;
  userId?: string;
  code?: string;
  used?: boolean;
}

const rand = () => Math.random().toString(36).slice(2, 12) + Math.random().toString(36).slice(2, 12);

async function sha256b64url(text: string): Promise<string> {
  const d = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
  let s = "";
  for (const b of d) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export class FakeSupabase {
  readonly users = new Map<string, TestUser>();
  readonly sessions = new Map<string, Sess>();
  readonly authorizations = new Map<string, Authz>();
  readonly socialFlows = new Map<string, { userId: string; challenge: string; used?: boolean }>();
  readonly calls: { method: string; path: string; search: string; auth: string | null }[] = [];
  /** Clientes OAuth a los que el hook da `yala_mcp_reader`. Sin la web aquí, el hook la rechaza (403). */
  readonly hookAllow = new Set([CONNECTOR_CLIENT, WEB_CLIENT]);
  /** El hook apagado: los tokens OAuth salen con `authenticated` (el riesgo que la web tiene que rechazar). */
  hookOff = false;
  /** El usuario ya dio el permiso antes: Supabase devuelve `redirect_url` sin pedir consentimiento. */
  alreadyConsented = false;
  failRefresh: { status: number; code: string } | null = null;
  userDown = false;
  /** `GET /user` responde este 4xx sin código de GoTrue (un proxy o un WAF delante). */
  userOpaque4xx: number | null = null;
  turnstileOk = true;
  accessTtl = 3600;
  /** `yala_web_close_session` no responde (5xx). */
  closeRpcDown = false;
  /** Filas de las tablas de la nube, por usuario: lo que devuelve PostgREST a quien tenga SELECT. */
  readonly tables = new Map<string, Record<string, unknown>[]>();
  /** Tablas que el rol de solo lectura puede leer (`mcp0_01` + `web1_01`). */
  readonly readerTables = new Set([
    "accounts", "tx_items", "categories", "subcategories", "tags", "budgets", "scheduled_payments", "user_preferences", "exchange_rates", "inbox_drafts",
  ]);
  now = () => Math.floor(Date.now() / 1000);

  private constructor(
    private readonly privateKey: CryptoKey,
    readonly jwks: JWTVerifyGetKey,
  ) {}

  static async create(): Promise<FakeSupabase> {
    const { privateKey, publicKey } = await generateKeyPair("ES256");
    const jwk: JWK = { ...(await exportJWK(publicKey)), kid: "k1", alg: "ES256" };
    return new FakeSupabase(privateKey as CryptoKey, createLocalJWKSet({ keys: [jwk] }));
  }

  addUser(u: Partial<TestUser> & { email: string }): TestUser {
    const user: TestUser = { id: crypto.randomUUID(), password: "clave", kind: "complete", ...u };
    this.users.set(user.email, user);
    return user;
  }

  /** Lo que haría Apple o Google + Supabase: un código de login social ligado a ese challenge. */
  socialCode(user: TestUser, challenge: string): string {
    const code = `social_${rand()}`;
    this.socialFlows.set(code, { userId: user.id, challenge });
    return code;
  }

  private async sign(s: Sess): Promise<string> {
    let role = "authenticated";
    if (s.clientId && !this.hookOff) role = "yala_mcp_reader";
    const claims: Record<string, unknown> = { role, session_id: s.id };
    if (s.clientId) claims.client_id = s.clientId;
    return new SignJWT(claims)
      .setProtectedHeader({ alg: "ES256", kid: "k1" })
      .setIssuer(`${SB_URL}/auth/v1`)
      .setSubject(s.userId)
      .setIssuedAt(this.now())
      .setExpirationTime(this.now() + this.accessTtl)
      .sign(this.privateKey);
  }

  private async issue(userId: string, clientId: string | null) {
    const s: Sess = { id: crypto.randomUUID(), userId, clientId, refresh: `rt_${rand()}` };
    this.sessions.set(s.id, s);
    return { access_token: await this.sign(s), refresh_token: s.refresh, session: s };
  }

  private sessionOf(auth: string | null): Sess | null {
    const raw = auth?.replace(/^Bearer /, "") ?? "";
    const payload = raw.split(".")[1];
    if (!payload) return null;
    try {
      const claims = JSON.parse(atob(payload.replace(/-/g, "+").replace(/_/g, "/"))) as { session_id?: string; exp?: number };
      if ((claims.exp ?? 0) <= this.now()) return null;
      return this.sessions.get(claims.session_id ?? "") ?? null;
    } catch {
      return null;
    }
  }

  /** El token de la sesión de la APP de un usuario (lo que manda el iPhone): `authenticated` y sin `client_id`. */
  async appToken(user: TestUser): Promise<string> {
    return (await this.issue(user.id, null)).access_token;
  }

  /** Un token de una sesión de cliente OAuth (la web, el conector): lleva `client_id`. */
  async clientToken(user: TestUser, clientId: string): Promise<string> {
    return (await this.issue(user.id, clientId)).access_token;
  }

  /** Mete filas en una tabla de la nube, de este usuario. */
  seed(table: string, user: TestUser, rows: Record<string, unknown>[]): void {
    const list = this.tables.get(table) ?? [];
    list.push(...rows.map((r) => ({ deleted: false, ...r, user_id: user.id })));
    this.tables.set(table, list);
  }

  /** Sesiones abiertas de un usuario, por tipo. */
  openSessions(userId: string): { normal: number; web: number } {
    const all = [...this.sessions.values()].filter((s) => s.userId === userId);
    return { normal: all.filter((s) => !s.clientId).length, web: all.filter((s) => s.clientId === WEB_CLIENT).length };
  }

  readonly fetcher = async (input: Request | string | URL, init?: RequestInit): Promise<Response> => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    const method = (init?.method ?? "GET").toUpperCase();
    const headers = new Headers(init?.headers);
    const body = typeof init?.body === "string" ? init.body : "";
    this.calls.push({ method, path: url.pathname, search: url.search, auth: headers.get("Authorization") });

    if (url.toString() === TURNSTILE_VERIFY_URL) {
      const form = new URLSearchParams(body);
      return Response.json({ success: this.turnstileOk && form.get("response") === TURNSTILE_OK });
    }
    const path = url.pathname;

    if (path === "/rest/v1/profiles") {
      const s = this.sessionOf(headers.get("Authorization"));
      if (!s) return Response.json({ code: "PGRST301" }, { status: 401 });
      // El rol de solo lectura no tiene SELECT sobre `profiles` (medido en staging).
      if (s.clientId) return Response.json({ code: "42501", message: "permission denied for table profiles" }, { status: 403 });
      const user = [...this.users.values()].find((u) => u.id === s.userId)!;
      return Response.json(user.kind ? [{ kind: user.kind }] : []);
    }

    if (method === "POST" && path === "/rest/v1/rpc/yala_web_close_session") {
      if (this.closeRpcDown) return new Response("caído", { status: 503 });
      // `web1_01`: borra la sesión SOLO si es del cliente web y de quien llama. Con otro id, no hace nada.
      const caller = this.sessionOf(headers.get("Authorization"));
      if (!caller) return Response.json({ code: "PGRST301" }, { status: 401 });
      const { p_session_id } = JSON.parse(body) as { p_session_id: string };
      const target = this.sessions.get(p_session_id);
      const closed = !!target && target.userId === caller.userId && target.clientId === WEB_CLIENT;
      if (closed) this.sessions.delete(p_session_id);
      return Response.json(closed);
    }

    const table = /^\/rest\/v1\/([a-z_]+)$/.exec(path)?.[1];
    if (method === "GET" && table) {
      const s = this.sessionOf(headers.get("Authorization"));
      if (!s) return Response.json({ code: "PGRST301" }, { status: 401 });
      if (s.clientId && !this.readerTables.has(table)) return Response.json({ code: "42501" }, { status: 403 });
      // RLS: solo las filas propias. Los filtros de PostgREST no se simulan (salvo `deleted` y el estado de la Bandeja):
      // las pruebas siembran lo que la consulta debe devolver. Una sola página.
      if (Number(url.searchParams.get("offset") ?? "0") > 0) return Response.json([]);
      let rows = (this.tables.get(table) ?? []).filter((r) => r.user_id === s.userId && r.deleted !== true);
      if (url.searchParams.get("status_raw") === "eq.pending") rows = rows.filter((r) => r.status_raw === "pending");
      const limit = Number(url.searchParams.get("limit") ?? "1000");
      return Response.json(rows.slice(0, limit));
    }

    if (method === "POST" && path === "/auth/v1/token" && url.searchParams.get("grant_type") === "pkce") {
      const { auth_code, code_verifier } = JSON.parse(body) as { auth_code: string; code_verifier: string };
      const flow = this.socialFlows.get(auth_code);
      if (!flow || flow.used || (await sha256b64url(code_verifier)) !== flow.challenge) {
        return Response.json({ error_code: "flow_state_not_found" }, { status: 404 });
      }
      flow.used = true;
      const t = await this.issue(flow.userId, null);
      return Response.json({ access_token: t.access_token, refresh_token: t.refresh_token, user: { id: flow.userId } });
    }

    if (method === "POST" && path === "/auth/v1/token" && url.searchParams.get("grant_type") === "password") {
      const { email, password } = JSON.parse(body) as { email: string; password: string };
      const user = this.users.get(email);
      if (!user || user.password !== password) return Response.json({ error_code: "invalid_credentials" }, { status: 400 });
      const t = await this.issue(user.id, null);
      return Response.json({ access_token: t.access_token, refresh_token: t.refresh_token, user: { id: user.id } });
    }

    if (method === "GET" && path === "/auth/v1/oauth/authorize") {
      const q = url.searchParams;
      const a: Authz = {
        id: rand() + rand(),
        clientId: q.get("client_id") ?? "",
        redirectUri: q.get("redirect_uri") ?? "",
        challenge: q.get("code_challenge") ?? "",
        state: q.get("state") ?? "",
      };
      this.authorizations.set(a.id, a);
      // A la Site URL (el conector en staging), no a la web: la web no tiene que seguir este salto.
      return new Response(null, { status: 302, headers: { Location: `https://conector.yala.test/oauth/consent?authorization_id=${a.id}` } });
    }

    const authz = /^\/auth\/v1\/oauth\/authorizations\/([^/]+)(\/consent)?$/.exec(path);
    if (authz) {
      const s = this.sessionOf(headers.get("Authorization"));
      if (!s) return Response.json({ error_code: "session_not_found" }, { status: 401 });
      const a = this.authorizations.get(authz[1]!);
      if (!a || a.used) return Response.json({ error_code: "oauth_authorization_not_found" }, { status: 404 });
      a.userId = s.userId;
      const redirect = () => {
        a.code = `code_${rand()}`;
        const r = new URL(a.redirectUri);
        r.searchParams.set("code", a.code);
        r.searchParams.set("state", a.state);
        return r.toString();
      };
      if (!authz[2] && method === "GET") {
        if (this.alreadyConsented) return Response.json({ redirect_url: redirect() });
        return Response.json({ authorization_id: a.id, client: { id: a.clientId, name: "Yala web" }, user: { id: s.userId } });
      }
      if (authz[2] && method === "POST") return Response.json({ redirect_url: redirect() });
    }

    if (method === "POST" && path === "/auth/v1/oauth/token") {
      const [id, secret] = atob((headers.get("Authorization") ?? "").replace(/^Basic /, "")).split(":").map(decodeURIComponent);
      if (id !== WEB_CLIENT || secret !== WEB_SECRET) return Response.json({ error_code: "invalid_credentials" }, { status: 400 });
      const form = new URLSearchParams(body);
      if (form.get("grant_type") === "authorization_code") {
        const a = [...this.authorizations.values()].find((x) => x.code === form.get("code"));
        if (!a || a.used || !a.userId || form.get("redirect_uri") !== a.redirectUri) return Response.json({ error: "invalid_grant" }, { status: 400 });
        if ((await sha256b64url(form.get("code_verifier") ?? "")) !== a.challenge) return Response.json({ error: "invalid_grant" }, { status: 400 });
        if (!this.hookOff && !this.hookAllow.has(a.clientId)) return Response.json({ error_code: "hook_error" }, { status: 403 });
        a.used = true;
        const t = await this.issue(a.userId, a.clientId);
        return Response.json({ access_token: t.access_token, refresh_token: t.refresh_token });
      }
      if (form.get("grant_type") === "refresh_token") {
        if (this.failRefresh) return Response.json({ error_code: this.failRefresh.code }, { status: this.failRefresh.status });
        const s = [...this.sessions.values()].find((x) => x.refresh === form.get("refresh_token"));
        if (!s) return Response.json({ error_code: "refresh_token_not_found" }, { status: 400 });
        s.refresh = `rt_${rand()}`;
        return Response.json({ access_token: await this.sign(s), refresh_token: s.refresh });
      }
    }

    if (method === "GET" && path === "/auth/v1/user") {
      if (this.userDown) return new Response("caído", { status: 502 });
      if (this.userOpaque4xx) return new Response("<html>bloqueado</html>", { status: this.userOpaque4xx });
      const raw = headers.get("Authorization")?.replace(/^Bearer /, "") ?? "";
      const claims = JSON.parse(atob((raw.split(".")[1] ?? "").replace(/-/g, "+").replace(/_/g, "/")) || "{}") as { exp?: number; session_id?: string };
      if ((claims.exp ?? 0) <= this.now()) return Response.json({ error_code: "bad_jwt" }, { status: 401 });
      const s = this.sessions.get(claims.session_id ?? "");
      if (!s) return Response.json({ error_code: "session_not_found" }, { status: 403 });
      const user = [...this.users.values()].find((u) => u.id === s.userId)!;
      return Response.json({ id: user.id, email: user.email, user_metadata: user.name ? { full_name: user.name } : {} });
    }

    if (method === "POST" && path === "/auth/v1/logout") {
      const s = this.sessionOf(headers.get("Authorization"));
      if (s) this.sessions.delete(s.id);
      return new Response(null, { status: 204 });
    }

    return Response.json({ error: "no simulado", path }, { status: 404 });
  };
}

export function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    PUBLIC_URL: BASE,
    SUPABASE_URL: SB_URL,
    SUPABASE_ANON_KEY: "anon-publica",
    SUPABASE_OAUTH_CLIENT_ID: WEB_CLIENT,
    SUPABASE_OAUTH_CLIENT_SECRET: WEB_SECRET,
    TURNSTILE_SITE_KEY: "1x00000000000000000000AA",
    TURNSTILE_SECRET_KEY: "1x0000000000000000000000000000000AA",
    WEB_KV: new MemoryKV() as unknown as KVNamespace,
    DRAFTS_DB: new MemoryD1() as unknown as D1Database,
    SESSION_INDEX: new FakeSessionIndexNamespace() as unknown as DurableObjectNamespace,
    QR_PAIRING: new FakeQrPairingNamespace() as unknown as DurableObjectNamespace,
    DEFAULT_TIMEZONE: "America/Lima",
    ASSETS: { fetch: async () => new Response("<!doctype html><title>Yala</title>", { headers: { "Content-Type": "text/html" } }) } as unknown as Fetcher,
    ...overrides,
  };
}

/**
 * Un navegador mínimo: guarda las cookies que el Worker pone y las devuelve, respetando `Path` y `Max-Age=0`, y aplica
 * la regla del prefijo `__Host-` como Chrome, Firefox y Safari: sin `Secure`, con `Domain` o con otra ruta que `/`,
 * la cookie se descarta en silencio (así se perdía la del login, con `Path=/auth`).
 */
export class Browser {
  readonly jar = new Map<string, { value: string; path: string; maxAge: number | null }>();
  constructor(
    private readonly call: (req: Request) => Promise<Response>,
    readonly origin = BASE,
  ) {}

  cookieHeader(path: string): string {
    return [...this.jar.entries()]
      .filter(([, c]) => path.startsWith(c.path))
      .map(([k, c]) => `${k}=${c.value}`)
      .join("; ");
  }

  async request(path: string, init: RequestInit & { form?: Record<string, string> } = {}): Promise<Response> {
    const url = path.startsWith("http") ? path : `${BASE}${path}`;
    const headers = new Headers(init.headers);
    const cookie = this.cookieHeader(new URL(url).pathname);
    if (cookie) headers.set("Cookie", cookie);
    let body = init.body;
    if (init.form) {
      body = new URLSearchParams(init.form).toString();
      headers.set("Content-Type", "application/x-www-form-urlencoded");
      if (!headers.has("Origin")) headers.set("Origin", this.origin);
      // Un navegador manda siempre la longitud de un formulario; el Worker rechaza los que no la traen.
      headers.set("Content-Length", String(new TextEncoder().encode(body as string).length));
    }
    const res = await this.call(new Request(url, { method: init.method ?? (init.form ? "POST" : "GET"), headers, body, redirect: "manual" }));
    for (const c of res.headers.getSetCookie()) {
      const [pair, ...attrs] = c.split(/;\s*/);
      const eq = pair!.indexOf("=");
      const name = pair!.slice(0, eq);
      const value = pair!.slice(eq + 1);
      const path = attrs.find((a) => a.startsWith("Path="))?.slice(5) ?? "/";
      const maxAgeAttr = attrs.find((a) => a.startsWith("Max-Age="));
      const maxAge = maxAgeAttr ? Number(maxAgeAttr.slice(8)) : null;
      if (name.startsWith("__Host-") && (path !== "/" || !attrs.includes("Secure") || attrs.some((a) => a.startsWith("Domain=")))) continue;
      if (maxAge === 0) this.jar.delete(name);
      else this.jar.set(name, { value, path, maxAge });
    }
    return res;
  }
}

export interface World {
  env: Env;
  supabase: FakeSupabase;
  kv: MemoryKV;
  d1: MemoryD1;
  /** Un segundo navegador (otra sesión web de la misma cuenta, u otra persona). */
  newBrowser(): Browser;
  browser: Browser;
  clock: { now: number };
  call(req: Request): Promise<Response>;
  /** Entra con Apple como lo haría el navegador: /auth/start → (Apple) → /auth/callback. Devuelve la última respuesta. */
  socialLogin(user: TestUser, opts?: { compartido?: boolean; turnstile?: string; browser?: Browser }): Promise<Response>;
}

export async function world(overrides: Partial<Env> = {}): Promise<World> {
  const supabase = await FakeSupabase.create();
  const env = makeEnv(overrides);
  const clock = { now: 1_800_000_000 };
  supabase.now = () => clock.now;
  const app = createApp({
    fetcher: supabase.fetcher,
    verify: makeReaderVerifier(env, supabase.jwks),
    appVerify: makeAppVerifier(env, supabase.jwks),
    nowSec: () => clock.now,
  });
  const call = (req: Request) => app.fetch(req, env);
  const browser = new Browser(call);
  return {
    env,
    supabase,
    kv: env.WEB_KV as unknown as MemoryKV,
    d1: env.DRAFTS_DB as unknown as MemoryD1,
    newBrowser: () => new Browser(call),
    browser,
    clock,
    call,
    async socialLogin(user, opts = {}) {
      const b = opts.browser ?? browser;
      const form: Record<string, string> = { provider: "apple", "cf-turnstile-response": opts.turnstile ?? TURNSTILE_OK };
      if (opts.compartido) form.compartido = "1";
      const start = await b.request("/auth/start", { form });
      const location = start.headers.get("Location") ?? "";
      if (!location.startsWith(SB_URL)) return start;
      const to = new URL(location);
      const code = supabase.socialCode(user, to.searchParams.get("code_challenge") ?? "");
      const back = new URL(to.searchParams.get("redirect_to") ?? "");
      back.searchParams.set("code", code);
      return b.request(back.toString());
    },
  };
}
