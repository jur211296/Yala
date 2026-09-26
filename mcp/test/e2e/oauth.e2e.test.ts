/**
 * E2E contra staging: el mismo baile OAuth que hace Claude, paso a paso, y luego las herramientas.
 *
 *   set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
 *   npm run test:e2e
 *
 * Qué demuestra (ADR «El conector de Claude emite sus propios tokens», docs/DECISIONS.md):
 *   1. Descubrimiento: el servidor OAuth de Claude es el WORKER (metadatos, DCR, PKCE S256, revocación).
 *   2. El baile entero: permiso por cliente en el Worker → login en Supabase → vuelta al Worker → código de Claude.
 *   3. Lo que recibe Claude NO es un token de Supabase: ni un JWT ni nada que Supabase acepte.
 *   4. Con ese token, TODAS las escrituras de la cuenta en `/auth/v1/*` fallan, y la cuenta queda idéntica.
 *   5. Las seis herramientas leen datos reales; B no ve nada de A.
 *   6. Refrescar rota; revocar corta al momento, desde Claude y desde la cuenta de Supabase.
 *   7. El login normal de la app sigue saliendo `authenticated` y sin `client_id`; Supabase ya no registra clientes.
 *
 * Cada corrida registra en el WORKER un cliente `yala-mcp-e2e-<fecha>` (caduca solo a los 90 días sin uso) y revoca
 * al final los permisos de A y B al cliente del Worker en Supabase.
 */
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createHash, randomBytes } from "node:crypto";

const MCP_URL = process.env.MCP_URL ?? "https://yala-mcp-staging.misty-surf-6866.workers.dev";
const SUPABASE_URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";
/** El cliente OAuth del Worker en Supabase staging (público; `mcp/wrangler.toml`). */
const WORKER_SUPABASE_CLIENT = "65fb5767-59a5-4f50-b77c-7970e67589c5";
const REDIRECT = "http://localhost:53682/callback";

const A = { email: process.env.USER_A_EMAIL ?? "", pass: process.env.USER_A_PASS ?? "" };
const B = { email: process.env.USER_B_EMAIL ?? "", pass: process.env.USER_B_PASS ?? "" };

const b64url = (buf: Buffer) => buf.toString("base64url");
const looksLikeJwt = (s: string) => /^eyJ[\w-]*\.[\w-]+\.[\w-]+$/.test(s);
function claimsOf(jwt: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(jwt.split(".")[1]!, "base64url").toString("utf8"));
}

interface AsMetadata {
  issuer: string;
  authorization_endpoint: string;
  token_endpoint: string;
  registration_endpoint?: string;
  revocation_endpoint?: string;
  code_challenge_methods_supported?: string[];
  client_id_metadata_document_supported?: boolean;
  [k: string]: unknown;
}

interface Tokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope: string;
  resource: string;
  token_type: string;
}

const timings: Record<string, number> = {};
async function timed<T>(label: string, f: () => Promise<T>): Promise<T> {
  const t = Date.now();
  try {
    return await f();
  } finally {
    timings[label] = Date.now() - t;
  }
}

/** Tarro de cookies del Worker: lo que haría el navegador. Nunca manda cookies a Supabase. */
class Jar {
  readonly cookies = new Map<string, string>();
  readonly seen: string[] = [];
  header(url: string): Record<string, string> {
    if (new URL(url).origin !== new URL(MCP_URL).origin || this.cookies.size === 0) return {};
    return { Cookie: [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; ") };
  }
  take(res: Response) {
    for (const sc of res.headers.getSetCookie()) {
      this.seen.push(sc);
      const [pair, ...attrs] = sc.split(";").map((s) => s.trim());
      const eq = pair!.indexOf("=");
      const name = pair!.slice(0, eq);
      const value = pair!.slice(eq + 1);
      if (attrs.some((a) => /^max-age=0$/i.test(a)) || value === "") this.cookies.delete(name);
      else this.cookies.set(name, value);
    }
  }
  async fetch(url: string, init: RequestInit = {}): Promise<Response> {
    const res = await fetch(url, { ...init, redirect: "manual", headers: { ...(init.headers as Record<string, string>), ...this.header(url) } });
    this.take(res);
    return res;
  }
}

async function discover(): Promise<AsMetadata> {
  const challenge = await fetch(`${MCP_URL}/mcp`, { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
  expect(challenge.status).toBe(401);
  const www = challenge.headers.get("www-authenticate") ?? "";
  const prmUrl = /resource_metadata="([^"]+)"/.exec(www)?.[1];
  expect(prmUrl, www).toBeTruthy();
  const prm = (await (await fetch(prmUrl!)).json()) as { resource: string; authorization_servers: string[] };
  expect(prm.resource).toBe(`${MCP_URL}/mcp`);
  const issuer = prm.authorization_servers[0]!;
  const res = await timed("discovery_ms", () => fetch(`${issuer}/.well-known/oauth-authorization-server`));
  expect(res.status).toBe(200);
  return (await res.json()) as AsMetadata;
}

async function register(meta: AsMetadata): Promise<string> {
  const res = await fetch(meta.registration_endpoint!, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_name: `yala-mcp-e2e-${new Date().toISOString().slice(0, 16)}`,
      redirect_uris: [REDIRECT],
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
    }),
  });
  const body = (await res.json()) as { client_id?: string };
  expect(res.status, JSON.stringify(body)).toBe(201);
  return body.client_id!;
}

/** Autoriza como lo haría Claude Code, con un navegador por usuario. */
async function authorize(meta: AsMetadata, clientId: string, user: { email: string; pass: string }) {
  const jar = new Jar();
  const verifier = b64url(randomBytes(32));
  const challenge = b64url(createHash("sha256").update(verifier).digest());
  const state = b64url(randomBytes(8));
  const auth = new URL(meta.authorization_endpoint);
  auth.search = new URLSearchParams({
    response_type: "code",
    client_id: clientId,
    redirect_uri: REDIRECT,
    code_challenge: challenge,
    code_challenge_method: "S256",
    state,
    scope: "lectura",
    resource: `${MCP_URL}/mcp`,
  }).toString();

  const consent = await jar.fetch(auth.toString());
  const html = await consent.text();
  expect(consent.status, html.slice(0, 300)).toBe(200);
  expect(html).toContain("quiere leer tus datos de Yala");
  expect(html).toContain("ni tus finanzas ni los datos de tu cuenta");
  const handle = /name="handle" value="([^"]+)"/.exec(html)?.[1];
  expect(handle).toBeTruthy();

  const approve = await jar.fetch(`${MCP_URL}/authorize`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ handle: handle!, decision: "approve" }).toString(),
  });
  expect(approve.status).toBe(302);
  const toSupabase = approve.headers.get("location")!;
  expect(new URL(toSupabase).origin).toBe(SUPABASE_URL);
  expect(new URL(toSupabase).searchParams.get("client_id")).toBe(WORKER_SUPABASE_CLIENT);

  const sb = await jar.fetch(toSupabase);
  expect(sb.status, await sb.text()).toBeGreaterThanOrEqual(300);
  const consentUrl = new URL(sb.headers.get("location") ?? "", toSupabase);
  expect(consentUrl.origin + consentUrl.pathname).toBe(`${MCP_URL}/oauth/consent`);
  const authorizationId = consentUrl.searchParams.get("authorization_id")!;

  const loginForm = await jar.fetch(consentUrl.toString());
  expect(loginForm.status).toBe(200);
  const login = await jar.fetch(`${MCP_URL}/oauth/consent`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ authorization_id: authorizationId, email: user.email, password: user.pass }).toString(),
  });
  expect(login.status, (await login.text()).slice(0, 300)).toBe(303);
  const callback = login.headers.get("location")!;
  expect(new URL(callback).pathname).toBe("/oauth/supabase/callback");

  const done = await jar.fetch(callback);
  expect(done.status, (await done.text()).slice(0, 300)).toBe(302);
  const back = new URL(done.headers.get("location")!);
  expect(back.origin + back.pathname).toBe(REDIRECT);
  expect(back.searchParams.get("state")).toBe(state);
  expect(back.searchParams.get("error")).toBeNull();
  const code = back.searchParams.get("code")!;

  const tokenRes = await timed("token_ms", () =>
    fetch(meta.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: REDIRECT, client_id: clientId, code_verifier: verifier, resource: `${MCP_URL}/mcp` }),
    }),
  );
  const raw = await tokenRes.text();
  expect(tokenRes.status, raw).toBe(200);
  return { tokens: JSON.parse(raw) as Tokens, raw, jar };
}

async function mcp(token: string, method: string, params: unknown = {}) {
  const res = await fetch(`${MCP_URL}/mcp`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { result: any }).result;
}

async function tool(token: string, name: string, args: Record<string, unknown> = {}) {
  const r = await mcp(token, "tools/call", { name, arguments: args });
  expect(r.isError, r.content?.[0]?.text).toBeFalsy();
  return JSON.parse(r.content[0].text);
}

async function passwordSession(user: { email: string; pass: string }): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.pass }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { access_token: string }).access_token;
}

async function logout(token: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ANON, Authorization: `Bearer ${token}` } });
}

/** Lo que de la cuenta de un usuario podría cambiar una escritura en `/auth/v1/*`. */
async function accountSnapshot(user: { email: string; pass: string }) {
  const s = await passwordSession(user);
  const u = (await (await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON, Authorization: `Bearer ${s}` } })).json()) as Record<string, any>;
  await logout(s);
  return {
    id: u.id,
    email: u.email,
    new_email: u.new_email ?? null,
    phone: u.phone ?? null,
    new_phone: u.new_phone ?? null,
    user_metadata: u.user_metadata,
    app_metadata: u.app_metadata,
    factors: (u.factors ?? []).map((f: any) => f.id).sort(),
    identities: (u.identities ?? []).map((i: any) => i.identity_id ?? i.id).sort(),
  };
}

async function revokeWorkerGrant(user: { email: string; pass: string }) {
  const s = await passwordSession(user);
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants?client_id=${WORKER_SUPABASE_CLIENT}`, {
    method: "DELETE",
    headers: { apikey: ANON, Authorization: `Bearer ${s}` },
  });
  await logout(s);
  return res.status;
}

describe.skipIf(!A.pass || !B.pass)("conector de Claude contra staging (OAuth propio del Worker)", () => {
  let meta: AsMetadata;
  let clientId: string;
  let a: Awaited<ReturnType<typeof authorize>>;
  let b: Awaited<ReturnType<typeof authorize>>;

  beforeAll(async () => {
    meta = await discover();
    clientId = await register(meta);
    a = await authorize(meta, clientId, A);
    b = await authorize(meta, clientId, B);
  });

  afterAll(async () => {
    console.log("MEDIDA tiempos:", JSON.stringify(timings));
    // No dejar permisos vivos del cliente del Worker para A y B.
    await revokeWorkerGrant(A);
    await revokeWorkerGrant(B);
  });

  it("descubrimiento: el servidor OAuth es el Worker, con DCR, PKCE S256 y revocación", () => {
    expect(meta.issuer).toBe(MCP_URL);
    expect(meta.code_challenge_methods_supported).toEqual(["S256"]);
    expect(meta.registration_endpoint).toBe(`${MCP_URL}/oauth/register`);
    expect(meta.revocation_endpoint).toBe(meta.token_endpoint);
    console.log("MEDIDA metadatos AS:", JSON.stringify(meta));
    expect(timings.discovery_ms!).toBeLessThan(10_000);
    expect(timings.token_ms!).toBeLessThan(10_000);
  });

  it("lo que recibe Claude no es un token de Supabase", () => {
    const t = a.tokens;
    console.log("MEDIDA token de Claude:", JSON.stringify({ keys: Object.keys(t).sort(), expires_in: t.expires_in, scope: t.scope, resource: t.resource }));
    expect(Object.keys(t).sort()).toEqual(["access_token", "expires_in", "refresh_token", "resource", "scope", "token_type"]);
    expect(looksLikeJwt(t.access_token)).toBe(false);
    expect(looksLikeJwt(t.refresh_token)).toBe(false);
    expect(a.raw).not.toMatch(/eyJ[\w-]+\.[\w-]+\./);
    expect(t.resource).toBe(`${MCP_URL}/mcp`);
    expect(t.scope).toBe("lectura");
    expect(t.expires_in).toBeLessThanOrEqual(3540);
    // Ninguna cookie del baile lleva un token de Supabase: la sesión web no sale de la petición del login.
    for (const c of [...a.jar.seen, ...b.jar.seen]) expect(c).not.toMatch(/eyJ[\w-]+\.[\w-]+\./);
  });

  it("con el token de Claude, NINGUNA escritura de la cuenta en /auth/v1/* pasa, y la cuenta queda igual", async () => {
    const before = await accountSnapshot(A);
    const h = { apikey: ANON, Authorization: `Bearer ${a.tokens.access_token}`, "Content-Type": "application/json" };
    const fakeId = "00000000-0000-4000-8000-000000000000";
    // Cada sonda, si el token valiera, haría algo inofensivo o reversible; el oráculo fuerte es el `error_code`:
    // GoTrue rechaza el TOKEN (bad_jwt) antes de mirar qué se pide.
    const probes: [string, string, unknown?][] = [
      ["PUT", "/auth/v1/user", {}],
      ["PUT", "/auth/v1/user", { data: { mcp_e2e_probe: "1" } }],
      ["PUT", "/auth/v1/user", { email: A.email }],
      ["PUT", "/auth/v1/user", { password: A.pass }],
      ["PUT", "/auth/v1/user", { phone: "+51900000000" }],
      ["POST", "/auth/v1/factors", { factor_type: "totp", friendly_name: "mcp-e2e-probe" }],
      ["POST", `/auth/v1/factors/${fakeId}/challenge`, {}],
      ["DELETE", `/auth/v1/factors/${fakeId}`],
      ["POST", "/auth/v1/factors/recovery-codes", {}],
      ["POST", "/auth/v1/logout?scope=global"],
      ["GET", "/auth/v1/reauthenticate"],
      ["GET", "/auth/v1/user/identities/authorize?provider=google&skip_http_redirect=true"],
      ["DELETE", `/auth/v1/user/identities/${fakeId}`],
      ["DELETE", `/auth/v1/user/oauth/grants?client_id=${WORKER_SUPABASE_CLIENT}`],
      ["POST", "/auth/v1/passkeys/registration/options", {}],
      ["POST", `/auth/v1/oauth/authorizations/${fakeId}/consent`, { action: "approve" }],
      ["GET", "/auth/v1/user"],
    ];
    const results: Record<string, { status: number; code: string }> = {};
    for (const [method, path, body] of probes) {
      const res = await fetch(`${SUPABASE_URL}${path}`, { method, headers: h, ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
      const json = (await res.json().catch(() => ({}))) as { error_code?: string; error?: string };
      // Solo las CLAVES del cuerpo: una sonda lleva la contraseña de A y el log no debe verla nunca.
      const shape = body && typeof body === "object" ? ` {${Object.keys(body).join(",")}}` : "";
      results[`${method} ${path}${shape} #${Object.keys(results).length}`] = { status: res.status, code: json.error_code ?? json.error ?? "" };
    }
    console.log("MEDIDA escrituras de la cuenta con el token de Claude:", JSON.stringify(results));
    for (const [probe, r] of Object.entries(results)) {
      expect(r.status, probe).toBeGreaterThanOrEqual(400);
      // Los endpoints tras `requireAuthentication` rechazan el token en sí. Passkeys está apagado: cae antes.
      if (!probe.includes("/passkeys/")) expect(["bad_jwt", "no_authorization"], `${probe} → ${r.code}`).toContain(r.code);
    }

    // Tampoco el refresh de Claude se convierte en una sesión de Supabase, por ninguna de las dos puertas.
    const rt1 = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: { apikey: ANON, "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: a.tokens.refresh_token }),
    });
    const rt2 = await fetch(`${SUPABASE_URL}/auth/v1/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: a.tokens.refresh_token, client_id: WORKER_SUPABASE_CLIENT }),
    });
    // Y PostgREST tampoco lo acepta, ni para leer.
    const pg = await fetch(`${SUPABASE_URL}/rest/v1/accounts?select=sync_id&limit=1`, { headers: { apikey: ANON, Authorization: `Bearer ${a.tokens.access_token}` } });
    console.log("MEDIDA refresh/PostgREST con credenciales de Claude:", JSON.stringify({ token: rt1.status, oauth_token: rt2.status, postgrest: pg.status }));
    for (const s of [rt1.status, rt2.status, pg.status]) expect(s).toBeGreaterThanOrEqual(400);

    const after = await accountSnapshot(A);
    expect(after).toEqual(before);
  });

  it("A lee sus datos con las seis herramientas", async () => {
    const list = await mcp(a.tokens.access_token, "tools/list");
    expect(list.tools).toHaveLength(6);
    const cuentas = await tool(a.tokens.access_token, "listar_cuentas");
    expect(cuentas.cuentas.length).toBeGreaterThan(0);
    const cats = await tool(a.tokens.access_token, "listar_categorias");
    expect(cats.categorias.length).toBeGreaterThan(0);
    const movs = await tool(a.tokens.access_token, "buscar_movimientos", { limite: 5 });
    expect(movs.movimientos.length).toBeGreaterThan(0);
    const resumen = await tool(a.tokens.access_token, "resumen_periodo", { periodo: "rango", desde: "2026-01-01", hasta: "2026-09-26" });
    expect(resumen.movimientos).toBeGreaterThanOrEqual(0);
    const presupuestos = await tool(a.tokens.access_token, "estado_presupuestos");
    expect(Array.isArray(presupuestos.presupuestos)).toBe(true);
    const recurrentes = await tool(a.tokens.access_token, "listar_recurrentes");
    expect(Array.isArray(recurrentes.pagos)).toBe(true);
    console.log(
      "MEDIDA A:",
      JSON.stringify({
        cuentas: cuentas.cuentas.length,
        total: cuentas.total,
        categorias: cats.total,
        resumen: { ingresos: resumen.ingresos, gastos: resumen.gastos, movimientos: resumen.movimientos },
        presupuestos: presupuestos.presupuestos.length,
        recurrentes: recurrentes.pagos.length,
      }),
    );
  });

  it("B no ve nada de A", async () => {
    const aAccounts = new Set((await tool(a.tokens.access_token, "listar_cuentas", { incluir_archivadas: true })).cuentas.map((c: any) => c.id));
    const bCuentas = await tool(b.tokens.access_token, "listar_cuentas", { incluir_archivadas: true });
    for (const c of bCuentas.cuentas) expect(aAccounts.has(c.id)).toBe(false);
    const aMovs = new Set((await tool(a.tokens.access_token, "buscar_movimientos", { limite: 200 })).movimientos.map((m: any) => m.id));
    const bMovs = await tool(b.tokens.access_token, "buscar_movimientos", { limite: 200 });
    for (const m of bMovs.movimientos) expect(aMovs.has(m.id)).toBe(false);
    expect(aAccounts.size).toBeGreaterThan(0);
    console.log("MEDIDA B:", JSON.stringify({ cuentas: bCuentas.cuentas.length, movimientos_pagina: bMovs.movimientos.length }));
  });

  it("GET /mcp responde 405 (sin stream SSE)", async () => {
    const res = await fetch(`${MCP_URL}/mcp`, { headers: { Authorization: `Bearer ${a.tokens.access_token}`, Accept: "text/event-stream" } });
    expect(res.status).toBe(405);
  });

  it("refrescar rota el token de Claude y sigue leyendo", async () => {
    const res = await fetch(meta.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: a.tokens.refresh_token, client_id: clientId }),
    });
    const t = (await res.json()) as Tokens;
    expect(res.status, JSON.stringify(t)).toBe(200);
    expect(t.refresh_token).not.toBe(a.tokens.refresh_token);
    expect(looksLikeJwt(t.access_token)).toBe(false);
    const cats = await tool(t.access_token, "listar_categorias");
    expect(cats.total).toBeGreaterThan(0);
    a.tokens = t;
  });

  it("revocar desde Claude (RFC 7009) corta al momento", async () => {
    const rev = await fetch(meta.revocation_endpoint!, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ token: b.tokens.refresh_token, token_type_hint: "refresh_token", client_id: clientId }),
    });
    expect(rev.status).toBe(200);
    const live = await fetch(`${MCP_URL}/mcp`, {
      method: "POST",
      headers: { Authorization: `Bearer ${b.tokens.access_token}`, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "listar_categorias", arguments: {} } }),
    });
    console.log("MEDIDA tras revocar desde Claude:", live.status);
    expect(live.status).toBe(401);
  });

  it("revocar desde la cuenta de Supabase corta al momento, no a la hora", async () => {
    const t0 = Date.now();
    const del = await revokeWorkerGrant(A);
    expect(del).toBeLessThan(300);
    const live = await fetch(`${MCP_URL}/mcp`, {
      method: "POST",
      headers: { Authorization: `Bearer ${a.tokens.access_token}`, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "listar_categorias", arguments: {} } }),
    });
    const refresh = await fetch(meta.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: a.tokens.refresh_token, client_id: clientId }),
    });
    console.log("MEDIDA tras revocar desde la cuenta:", JSON.stringify({ mcp: live.status, refresh: refresh.status, ms: Date.now() - t0 }));
    expect(live.status).toBe(401);
    expect(refresh.status).toBeGreaterThanOrEqual(400);
  });

  it("el login normal de la app no cambió: authenticated y sin client_id", async () => {
    const s = await passwordSession(A);
    const c = claimsOf(s);
    await logout(s);
    expect(c.role).toBe("authenticated");
    expect(c.client_id).toBeUndefined();
  });

  it("Supabase no da tokens a otro cliente OAuth, aunque el propio usuario lo apruebe (hook con lista cerrada)", async () => {
    // El cliente público de la fase 0 con el que se conectó Claude Code (sigue registrado; borrarlo exige service_role).
    const OLD_CLIENT = "f5a0fc94-f924-447d-a735-0cefbe085b00";
    const OLD_REDIRECT = "http://localhost:54853/callback";
    const verifier = b64url(randomBytes(32));
    const auth = new URL(`${SUPABASE_URL}/auth/v1/oauth/authorize`);
    auth.search = new URLSearchParams({
      response_type: "code",
      client_id: OLD_CLIENT,
      redirect_uri: OLD_REDIRECT,
      code_challenge: b64url(createHash("sha256").update(verifier).digest()),
      code_challenge_method: "S256",
      state: "e2e",
    }).toString();
    const start = await fetch(auth, { redirect: "manual" });
    const authorizationId = new URL(start.headers.get("location") ?? "", auth).searchParams.get("authorization_id");
    expect(authorizationId, `${start.status}`).toBeTruthy();
    // B aprueba por la API con su propia sesión: la pantalla del Worker no lo dejaría (no es su cliente).
    const s = await passwordSession(B);
    let token: Response | null = null;
    try {
      // Como hace la pantalla: primero leer la autorización (eso la ata al usuario), luego aprobarla.
      const details = await fetch(`${SUPABASE_URL}/auth/v1/oauth/authorizations/${authorizationId}`, {
        headers: { apikey: ANON, Authorization: `Bearer ${s}` },
      });
      expect(details.status, await details.clone().text()).toBe(200);
      const consent = await fetch(`${SUPABASE_URL}/auth/v1/oauth/authorizations/${authorizationId}/consent`, {
        method: "POST",
        headers: { apikey: ANON, Authorization: `Bearer ${s}`, "Content-Type": "application/json" },
        body: JSON.stringify({ action: "approve" }),
      });
      const consentBody = await consent.text();
      const redirectUrl = (JSON.parse(consentBody) as { redirect_url?: string }).redirect_url ?? `sin redirect_url: ${consent.status} ${consentBody.slice(0, 200)}`;
      const code = new URL(redirectUrl, SUPABASE_URL).searchParams.get("code");
      expect(code, redirectUrl).toBeTruthy();
      token = await fetch(`${SUPABASE_URL}/auth/v1/oauth/token`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ grant_type: "authorization_code", code: code!, redirect_uri: OLD_REDIRECT, client_id: OLD_CLIENT, code_verifier: verifier }),
      });
      const body = await token.text();
      console.log("MEDIDA token para un cliente de la fase 0:", token.status, body.replace(/eyJ[\w.-]+/g, "<jwt>").slice(0, 160));
      expect(body).not.toMatch(/eyJ[\w-]+\.[\w-]+\./);
      expect(token.status).toBeGreaterThanOrEqual(400);
    } finally {
      await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants?client_id=${OLD_CLIENT}`, { method: "DELETE", headers: { apikey: ANON, Authorization: `Bearer ${s}` } });
      await logout(s);
    }
  });

  it("Supabase ya no registra clientes OAuth: el único es el del Worker", async () => {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/oauth/clients/register`, {
      method: "POST",
      headers: { apikey: ANON, "Content-Type": "application/json" },
      body: JSON.stringify({ client_name: "Claude", redirect_uris: [REDIRECT], token_endpoint_auth_method: "none" }),
    });
    console.log("MEDIDA DCR en Supabase:", res.status);
    expect(res.status).toBeGreaterThanOrEqual(400);
  });
});
