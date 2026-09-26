/**
 * E2E de la fase 0 contra staging: el mismo baile OAuth que hace Claude, paso a paso, y luego las herramientas.
 *
 *   set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
 *   npm run test:e2e
 *
 * Qué demuestra:
 *   1. Descubrimiento: metadatos del recurso → servidor de autorización de Supabase → DCR + PKCE S256.
 *   2. La pantalla de consentimiento del Worker completa el flujo y cierra su sesión web.
 *   3. El token que recibe el cliente sale con role = yala_mcp_reader y client_id, también tras refrescarlo.
 *   4. Con él, las seis herramientas leen datos reales; B no ve nada de A.
 *   5. Con ese mismo token, PostgREST NO deja escribir ni llamar RPC de escritura.
 *   6. Revocar el permiso desde la cuenta del usuario corta el refresh.
 *
 * Cada corrida registra un cliente OAuth nuevo en staging (DCR), llamado `yala-mcp-e2e-<fecha>`. No hay forma de
 * borrarlo sin service_role, que este repo no usa; se revoca su permiso al final.
 */
import { beforeAll, describe, expect, it } from "vitest";
import { createHash, randomBytes } from "node:crypto";

const MCP_URL = process.env.MCP_URL ?? "https://yala-mcp-staging.misty-surf-6866.workers.dev";
const SUPABASE_URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";
const REDIRECT = "http://localhost:53682/callback";

const A = { email: process.env.USER_A_EMAIL ?? "", pass: process.env.USER_A_PASS ?? "" };
const B = { email: process.env.USER_B_EMAIL ?? "", pass: process.env.USER_B_PASS ?? "" };

function b64url(buf: Buffer): string {
  return buf.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function claimsOf(jwt: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(jwt.split(".")[1]!, "base64url").toString("utf8"));
}

interface Discovery {
  issuer: string;
  authorization_endpoint: string;
  token_endpoint: string;
  registration_endpoint?: string;
  code_challenge_methods_supported?: string[];
  client_id_metadata_document_supported?: boolean;
  [k: string]: unknown;
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

async function discover(): Promise<Discovery> {
  const prm = (await (await fetch(`${MCP_URL}/.well-known/oauth-protected-resource`)).json()) as { authorization_servers: string[] };
  const issuer = prm.authorization_servers[0]!;
  const u = new URL(issuer);
  // RFC 8414 con path: /.well-known/oauth-authorization-server + path del emisor.
  const res = await timed("discovery_ms", () => fetch(`${u.origin}/.well-known/oauth-authorization-server${u.pathname}`));
  expect(res.status).toBe(200);
  return (await res.json()) as Discovery;
}

async function register(meta: Discovery): Promise<string> {
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
  expect(res.status, JSON.stringify(body)).toBeLessThan(300);
  return body.client_id!;
}

interface Tokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
}

/** Autoriza como lo haría Claude y devuelve los tokens, más la sesión web que usó la pantalla de consentimiento. */
async function authorize(meta: Discovery, clientId: string, user: { email: string; pass: string }) {
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
    scope: "openid email",
    resource: `${MCP_URL}/mcp`,
  }).toString();
  const start = await fetch(auth, { redirect: "manual" });
  const consentUrl = new URL(start.headers.get("location") ?? "", auth);
  expect(start.status, await start.text()).toBeGreaterThanOrEqual(300);
  expect(consentUrl.origin).toBe(new URL(MCP_URL).origin);
  expect(consentUrl.pathname).toBe("/oauth/consent");
  const authorizationId = consentUrl.searchParams.get("authorization_id")!;

  const login = await fetch(`${MCP_URL}/oauth/consent`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ authorization_id: authorizationId, email: user.email, password: user.pass }).toString(),
    redirect: "manual",
  });
  const html = await login.text();
  expect(login.status, html.slice(0, 300)).toBe(200);
  expect(html).toContain("quiere leer tus datos de Yala");
  const cookie = (login.headers.get("set-cookie") ?? "").split(";")[0]!;
  const webSession = cookie.split(".").slice(1).join(".");

  const decision = await fetch(`${MCP_URL}/oauth/consent/decision`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Cookie: cookie },
    body: new URLSearchParams({ authorization_id: authorizationId, decision: "approve" }).toString(),
    redirect: "manual",
  });
  expect(decision.status).toBe(303);
  const back = new URL(decision.headers.get("location")!);
  expect(back.origin + back.pathname).toBe(REDIRECT);
  expect(back.searchParams.get("state")).toBe(state);
  const code = back.searchParams.get("code")!;

  const tokenRes = await timed("token_ms", () =>
    fetch(meta.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "authorization_code", code, redirect_uri: REDIRECT, client_id: clientId, code_verifier: verifier }),
    }),
  );
  const tokens = (await tokenRes.json()) as Tokens;
  expect(tokenRes.status, JSON.stringify(tokens)).toBe(200);
  return { tokens, webSession };
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

async function logout(token: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ANON, Authorization: `Bearer ${token}` } });
}

async function passwordSession(user: { email: string; pass: string }): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.pass }),
  });
  return ((await res.json()) as { access_token: string }).access_token;
}

describe.skipIf(!A.pass || !B.pass)("fase 0 contra staging", () => {
  let meta: Discovery;
  let clientId: string;
  let a: { tokens: Tokens; webSession: string };
  let b: { tokens: Tokens; webSession: string };

  beforeAll(async () => {
    meta = await discover();
    clientId = await register(meta);
    a = await authorize(meta, clientId, A);
    b = await authorize(meta, clientId, B);
  });

  it("descubrimiento: PKCE S256 y registro dinámico anunciados (y qué dice de CIMD)", () => {
    expect(meta.code_challenge_methods_supported).toContain("S256");
    expect(meta.registration_endpoint).toBeTruthy();
    console.log("MEDIDA metadatos AS:", JSON.stringify({ ...meta, cimd: meta.client_id_metadata_document_supported ?? "no anunciado" }));
    console.log("MEDIDA tiempos:", JSON.stringify(timings));
    expect(timings.discovery_ms!).toBeLessThan(10_000);
    expect(timings.token_ms!).toBeLessThan(10_000);
  });

  it("el token de Claude es de solo lectura: role yala_mcp_reader y client_id", () => {
    const c = claimsOf(a.tokens.access_token);
    console.log("MEDIDA claims:", JSON.stringify({ role: c.role, aud: c.aud, client_id: c.client_id, scope: c.scope, exp_s: a.tokens.expires_in }));
    expect(c.role).toBe("yala_mcp_reader");
    expect(c.client_id).toBe(clientId);
    expect(a.tokens.refresh_token).toBeTruthy();
  });

  it("la pantalla de consentimiento cerró su sesión web", async () => {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: ANON, Authorization: `Bearer ${a.webSession}` } });
    console.log("MEDIDA sesión web tras decidir:", res.status);
    expect(res.status).toBeGreaterThanOrEqual(400);
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
        categorias: cats.total,
        resumen: { ingresos: resumen.ingresos, gastos: resumen.gastos, movimientos: resumen.movimientos },
        presupuestos: presupuestos.presupuestos.length,
        recurrentes: recurrentes.pagos.length,
        a_revisar: recurrentes.a_revisar,
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
    // Y por debajo del MCP: con el token de B, PostgREST no devuelve ninguna fila de A.
    const aSub = claimsOf(a.tokens.access_token).sub as string;
    const res = await fetch(`${SUPABASE_URL}/rest/v1/tx_items?select=sync_id&user_id=eq.${aSub}&limit=5`, {
      headers: { apikey: ANON, Authorization: `Bearer ${b.tokens.access_token}` },
    });
    expect(await res.json()).toEqual([]);
    console.log("MEDIDA B:", JSON.stringify({ cuentas: bCuentas.cuentas.length, movimientos_pagina: bMovs.movimientos.length }));
  });

  it("con el token de Claude, PostgREST no deja escribir ni llamar RPC de escritura", async () => {
    expect(claimsOf(a.tokens.access_token).role).toBe("yala_mcp_reader");
    const h = { apikey: ANON, Authorization: `Bearer ${a.tokens.access_token}`, "Content-Type": "application/json", Prefer: "return=minimal" };
    const aSub = claimsOf(a.tokens.access_token).sub as string;
    const patch = await fetch(`${SUPABASE_URL}/rest/v1/accounts?user_id=eq.${aSub}`, { method: "PATCH", headers: h, body: JSON.stringify({ name: "hackeada" }) });
    const insert = await fetch(`${SUPABASE_URL}/rest/v1/tags`, {
      method: "POST",
      headers: h,
      body: JSON.stringify({ user_id: aSub, sync_id: crypto.randomUUID(), hlc: "x", server_seq: 0, name: "hack" }),
    });
    // `delete_personal_account` (SECURITY DEFINER) NO se llama aquí: si la defensa fallara, borraría la cuenta de A.
    // Su denegación se midió en SQL como yala_mcp_reader (42501, ver qa/cloud/mcp0_01_readonly_role.sql).
    const rpcPref = await fetch(`${SUPABASE_URL}/rest/v1/rpc/apply_pref`, {
      method: "POST",
      headers: h,
      body: JSON.stringify({ p_key: "mcp-e2e-probe", p_value: "y", p_hlc: "z" }),
    });
    const statuses = { patch: patch.status, insert: insert.status, apply_pref: rpcPref.status };
    console.log("MEDIDA escrituras con token de Claude:", JSON.stringify(statuses));
    for (const s of Object.values(statuses)) expect([401, 403]).toContain(s);
  });

  // HUECO CONOCIDO, medido el 2026-09-26: GoTrue acepta el token de Claude en `PUT /auth/v1/user` (200). El rol
  // de solo lectura vive en Postgres y GoTrue no lo mira, así que el token podría cambiar el email, la contraseña
  // o los metadatos de la cuenta. Bloquea la fase 1: ticket `claude-mcp-oauth-token-can-change-the-account`.
  // `it.fails` a propósito: el día que Supabase lo cierre, este test se pone rojo y avisa de que hay que retirarlo.
  it.fails("con el token de Claude, GoTrue no deja cambiar la cuenta", async () => {
    // Sonda inocua: una clave de metadatos, que se borra justo después.
    const h = { apikey: ANON, Authorization: `Bearer ${a.tokens.access_token}`, "Content-Type": "application/json" };
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, { method: "PUT", headers: h, body: JSON.stringify({ data: { mcp_e2e_probe: "1" } }) });
    console.log("MEDIDA PUT /auth/v1/user con token de Claude:", res.status);
    if (res.ok) await fetch(`${SUPABASE_URL}/auth/v1/user`, { method: "PUT", headers: h, body: JSON.stringify({ data: { mcp_e2e_probe: null } }) });
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it("GET /mcp responde 405 (sin stream SSE)", async () => {
    const res = await fetch(`${MCP_URL}/mcp`, { headers: { Authorization: `Bearer ${a.tokens.access_token}`, Accept: "text/event-stream" } });
    expect(res.status).toBe(405);
  });

  it("refrescar mantiene el rol de solo lectura", async () => {
    const res = await fetch(meta.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: a.tokens.refresh_token, client_id: clientId }),
    });
    const t = (await res.json()) as Tokens;
    expect(res.status, JSON.stringify(t)).toBe(200);
    const c = claimsOf(t.access_token);
    expect(c.role).toBe("yala_mcp_reader");
    expect(c.client_id).toBe(clientId);
    a.tokens = t;
  });

  it("revocar desde la cuenta del usuario corta el refresh (y se mide qué pasa con el token vivo)", async () => {
    const session = await passwordSession(B);
    const h = { apikey: ANON, Authorization: `Bearer ${session}` };
    const grants = await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants`, { headers: h });
    const list = (await grants.json()) as unknown[];
    console.log("MEDIDA grants de B:", grants.status, JSON.stringify(list).slice(0, 400));
    expect(grants.status).toBe(200);
    const del = await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants?client_id=${encodeURIComponent(clientId)}`, { method: "DELETE", headers: h });
    expect(del.status).toBeLessThan(300);
    const refresh = await fetch(meta.token_endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: b.tokens.refresh_token, client_id: clientId }),
    });
    const refreshBody = await refresh.text();
    const live = await fetch(`${MCP_URL}/mcp`, {
      method: "POST",
      headers: { Authorization: `Bearer ${b.tokens.access_token}`, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "listar_categorias", arguments: {} } }),
    });
    const liveBody = await live.text();
    console.log("MEDIDA tras revocar:", JSON.stringify({ refresh: refresh.status, refreshBody: refreshBody.slice(0, 200), mcp: live.status, mcpBody: liveBody.slice(0, 200) }));
    await logout(session);
    expect(refresh.status).toBeGreaterThanOrEqual(400);
    // Revoca también el de A para no dejar permisos vivos del cliente de prueba.
    const sa = await passwordSession(A);
    await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants?client_id=${encodeURIComponent(clientId)}`, {
      method: "DELETE",
      headers: { apikey: ANON, Authorization: `Bearer ${sa}` },
    });
    await logout(sa);
  });
});
