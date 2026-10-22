/**
 * El mundo de los tests unitarios: el Worker de verdad (`createApp`), un KV en memoria, un Supabase falso con estado
 * y un navegador con cookies. `connect()` recorre el baile entero como lo hace Claude Code.
 */
import { expect } from "vitest";
import { createApp } from "../src/index";
import type { Env } from "../src/env";
import { randB64url, sha256b64url } from "./b64";
import { MemoryKV } from "./kv";
import { FakeSupabase, SB_URL, USER_A, WORKER_SB_CLIENT, WORKER_SB_SECRET, type TestUser } from "./supabase-fake";

export const BASE = "https://mcp.yala.test";
export const RESOURCE = `${BASE}/mcp`;
export const REDIRECT = "http://localhost:53682/callback";

export function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    SUPABASE_URL: SB_URL,
    SUPABASE_ANON_KEY: "anon-publica",
    DEFAULT_TIMEZONE: "America/Lima",
    PUBLIC_URL: BASE,
    SUPABASE_OAUTH_CLIENT_ID: WORKER_SB_CLIENT,
    SUPABASE_OAUTH_CLIENT_SECRET: WORKER_SB_SECRET,
    OAUTH_KV: new MemoryKV() as unknown as KVNamespace,
    ...overrides,
  };
}

export function ctx(): ExecutionContext {
  return { waitUntil() {}, passThroughOnException() {}, props: {} } as unknown as ExecutionContext;
}

export interface World {
  app: ReturnType<typeof createApp>;
  env: Env;
  supabase: FakeSupabase;
  kv: MemoryKV;
  call(input: string | Request, init?: RequestInit): Promise<Response>;
}

export async function world(opts: { env?: Partial<Env>; now?: () => Date } = {}): Promise<World> {
  const supabase = await FakeSupabase.create();
  const env = makeEnv(opts.env);
  // El resolver del JWKS consulta la palanca `jwksThrows`: así un test puede simular que las claves de Supabase no
  // responden (el fallo pasajero que NO debe borrar la conexión).
  const keys: typeof supabase.jwks = (header, token) => {
    if (supabase.jwksThrows) throw supabase.jwksThrows;
    return supabase.jwks(header, token);
  };
  const app = createApp({ fetcher: supabase.fetcher, upstreamKeys: keys, now: opts.now });
  return {
    app,
    env,
    supabase,
    kv: env.OAUTH_KV as unknown as MemoryKV,
    call: (input, init) => app.fetch(typeof input === "string" ? new Request(input, init) : input, env, ctx()),
  };
}

/** Un navegador mínimo: guarda y manda cookies, y no sigue redirecciones solo. */
export class Browser {
  readonly cookies = new Map<string, string>();
  constructor(private readonly w: World) {}

  async fetch(url: string, init: RequestInit = {}): Promise<Response> {
    const headers = new Headers(init.headers);
    if (this.cookies.size) headers.set("Cookie", [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; "));
    const res = await this.w.call(new Request(url, { ...init, headers }));
    for (const sc of res.headers.getSetCookie()) {
      const [pair, ...attrs] = sc.split(";").map((s) => s.trim());
      const eq = pair!.indexOf("=");
      const name = pair!.slice(0, eq);
      const value = pair!.slice(eq + 1);
      if (attrs.some((a) => /^max-age=0$/i.test(a)) || value === "") this.cookies.delete(name);
      else this.cookies.set(name, value);
    }
    return res;
  }

  form(url: string, fields: Record<string, string>): Promise<Response> {
    return this.fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(fields).toString(),
    });
  }
}

export async function register(w: World, redirectUris: string[] = [REDIRECT], name = "Claude Code (yala-staging)") {
  const res = await w.call(`${BASE}/oauth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_name: name,
      redirect_uris: redirectUris,
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
    }),
  });
  return { res, body: (await res.json()) as { client_id?: string; error?: string } };
}

export function authorizeUrl(clientId: string, challenge: string, state: string, extra: Record<string, string> = {}) {
  return (
    `${BASE}/authorize?` +
    new URLSearchParams({
      response_type: "code",
      client_id: clientId,
      redirect_uri: REDIRECT,
      code_challenge: challenge,
      code_challenge_method: "S256",
      state,
      resource: RESOURCE,
      ...extra,
    }).toString()
  );
}

export interface WorkerTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope: string;
  resource: string;
  token_type: string;
}

/** El baile entero, paso a paso, como Claude Code. Comprueba cada salto y devuelve los tokens del Worker. */
export async function connect(w: World, user: TestUser = USER_A, opts: { scope?: string } = {}) {
  const { body: reg } = await register(w);
  const clientId = reg.client_id!;
  const verifier = randB64url(32);
  const challenge = await sha256b64url(verifier);
  const state = randB64url(8);
  const browser = new Browser(w);

  const consent = await browser.fetch(authorizeUrl(clientId, challenge, state, opts.scope ? { scope: opts.scope } : {}));
  const html = await consent.text();
  expect(consent.status, html.slice(0, 300)).toBe(200);
  const handle = /name="handle" value="([^"]+)"/.exec(html)?.[1];
  expect(handle).toBeTruthy();

  const approve = await browser.form(`${BASE}/authorize`, { handle: handle!, decision: "approve" });
  expect(approve.status).toBe(302);
  const consentUrl = w.supabase.visitAuthorize(approve.headers.get("Location")!, BASE);
  const authorizationId = new URL(consentUrl).searchParams.get("authorization_id")!;

  const loginForm = await browser.fetch(consentUrl);
  expect(loginForm.status).toBe(200);
  const login = await browser.form(`${BASE}/oauth/consent`, { authorization_id: authorizationId, email: user.email, password: user.password });
  expect(login.status, await login.clone().text()).toBe(303);

  const callback = await browser.fetch(login.headers.get("Location")!);
  expect(callback.status, await callback.clone().text()).toBe(302);
  const back = new URL(callback.headers.get("Location")!);
  expect(back.origin + back.pathname).toBe(REDIRECT);
  expect(back.searchParams.get("state")).toBe(state);
  const code = back.searchParams.get("code")!;

  const tokenRes = await w.call(`${BASE}/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: REDIRECT, client_id: clientId, code_verifier: verifier, resource: RESOURCE }),
  });
  const raw = await tokenRes.text();
  expect(tokenRes.status, raw).toBe(200);
  return { clientId, tokens: JSON.parse(raw) as WorkerTokens, raw, back, browser };
}

export async function refresh(w: World, clientId: string, refreshToken: string) {
  const res = await w.call(`${BASE}/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: refreshToken, client_id: clientId }),
  });
  return { res, body: (await res.json()) as Partial<WorkerTokens> & { error?: string } };
}

export const INIT = {
  jsonrpc: "2.0",
  id: 1,
  method: "initialize",
  params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "0" } },
};

export async function rpc(w: World, token: string | null, body: unknown) {
  const headers: Record<string, string> = { "Content-Type": "application/json", Accept: "application/json, text/event-stream" };
  if (token) headers.Authorization = `Bearer ${token}`;
  return w.call(`${BASE}/mcp`, { method: "POST", headers, body: JSON.stringify(body) });
}

export async function callTool(w: World, token: string, name: string, args: Record<string, unknown> = {}) {
  const res = await rpc(w, token, { jsonrpc: "2.0", id: 9, method: "tools/call", params: { name, arguments: args } });
  return { res, body: res.status === 200 ? ((await res.json()) as { result: { isError?: boolean; content: { text: string }[] } }) : null };
}

/** ¿Parece un JWT? (tres trozos base64url y cabecera JSON). Lo que Claude reciba no debe serlo. */
export function looksLikeJwt(s: string): boolean {
  return /^eyJ[\w-]*\.[\w-]+\.[\w-]+$/.test(s);
}

/** Las conexiones (grants) vivas en el KV de la librería. Para afirmar directamente que una se borró o se conservó. */
export function grantCount(w: World): number {
  return [...w.kv.store.keys()].filter((k) => k.startsWith("grant:")).length;
}
