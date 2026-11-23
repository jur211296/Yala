/**
 * E2E contra staging de «Conecta tu IA» (`src/connections.ts`): la app lista y quita sus IA conectadas con su sesión
 * normal de la nube.
 *
 *   set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
 *   npx vitest run --config vitest.e2e.config.ts test/e2e/conectaTuIA.e2e.test.ts
 *
 * Conecta una IA de prueba con A (el baile OAuth entero), comprueba que la lista la enseña, que ni B ni el token de la
 * IA pueden quitarla, que A sí, y que tras quitarla la IA ya no lee. Al final cierra las sesiones de prueba y retira el
 * permiso de A al cliente del Worker en Supabase, como `oauth.e2e.test.ts`.
 */
import { afterAll, describe, expect, it } from "vitest";
import { createHash, randomBytes } from "node:crypto";

const MCP_URL = process.env.MCP_URL ?? "https://yala-mcp-staging.misty-surf-6866.workers.dev";
const SUPABASE_URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";
const WORKER_SUPABASE_CLIENT = "65fb5767-59a5-4f50-b77c-7970e67589c5";
const REDIRECT = "http://localhost:53682/callback";

const A = { email: process.env.USER_A_EMAIL ?? "", pass: process.env.USER_A_PASS ?? "" };
const B = { email: process.env.USER_B_EMAIL ?? "", pass: process.env.USER_B_PASS ?? "" };

interface Row {
  id: string;
  ia: string | null;
  vuelta: string | null;
  local: boolean;
  conectadaEl: number;
}

const appSessions: string[] = [];

async function appSession(user: { email: string; pass: string }): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.pass }),
  });
  expect(res.status).toBe(200);
  const token = ((await res.json()) as { access_token: string }).access_token;
  appSessions.push(token);
  return token;
}

async function list(token: string) {
  const res = await fetch(`${MCP_URL}/connections`, { headers: { Authorization: `Bearer ${token}` } });
  return { status: res.status, body: res.status === 200 ? ((await res.json()) as { conexiones: Row[] }) : null };
}

function remove(token: string, id: string) {
  return fetch(`${MCP_URL}/connections/${id}`, { method: "DELETE", headers: { Authorization: `Bearer ${token}` } });
}

function mcpInit(token: string) {
  return fetch(`${MCP_URL}/mcp`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "e2e", version: "0" } } }),
  });
}

/** El baile OAuth de una IA, con un navegador de cookies mínimo. Devuelve el access token del Worker. */
async function connectAI(user: { email: string; pass: string }): Promise<string> {
  const cookies = new Map<string, string>();
  const go = async (url: string, init: RequestInit = {}) => {
    const sameOrigin = new URL(url).origin === new URL(MCP_URL).origin;
    const headers: Record<string, string> = { ...(init.headers as Record<string, string>) };
    if (sameOrigin && cookies.size) headers.Cookie = [...cookies].map(([k, v]) => `${k}=${v}`).join("; ");
    const res = await fetch(url, { ...init, redirect: "manual", headers });
    for (const sc of res.headers.getSetCookie()) {
      const [pair, ...attrs] = sc.split(";").map((s) => s.trim());
      const eq = pair!.indexOf("=");
      const value = pair!.slice(eq + 1);
      if (attrs.some((a) => /^max-age=0$/i.test(a)) || value === "") cookies.delete(pair!.slice(0, eq));
      else cookies.set(pair!.slice(0, eq), value);
    }
    return res;
  };
  const form = (body: Record<string, string>) => ({
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(body).toString(),
  });

  const reg = await fetch(`${MCP_URL}/oauth/register`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_name: `yala-conecta-e2e-${new Date().toISOString().slice(0, 16)}`,
      redirect_uris: [REDIRECT],
      grant_types: ["authorization_code", "refresh_token"],
      response_types: ["code"],
      token_endpoint_auth_method: "none",
    }),
  });
  expect(reg.status).toBe(201);
  const clientId = ((await reg.json()) as { client_id: string }).client_id;

  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const state = randomBytes(8).toString("base64url");
  const auth = new URL(`${MCP_URL}/authorize`);
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
  const consent = await go(auth.toString());
  const html = await consent.text();
  expect(consent.status).toBe(200);
  // La página nueva, con marca: el logo y «Yala × Claude» por la vuelta local.
  expect(html).toContain('aria-label="Yala"');
  expect(html).toContain('<span class="ai">Claude</span>');
  const handle = /name="handle" value="([^"]+)"/.exec(html)![1]!;

  const approve = await go(`${MCP_URL}/authorize`, form({ handle, decision: "approve" }));
  expect(approve.status).toBe(302);
  const toSupabase = approve.headers.get("location")!;
  const sb = await go(toSupabase);
  const consentUrl = new URL(sb.headers.get("location") ?? "", toSupabase);
  const authorizationId = consentUrl.searchParams.get("authorization_id")!;
  const login = await go(`${MCP_URL}/oauth/consent`, form({ authorization_id: authorizationId, email: user.email, password: user.pass }));
  expect(login.status).toBe(303);
  const done = await go(login.headers.get("location")!);
  expect(done.status).toBe(302);
  const code = new URL(done.headers.get("location")!).searchParams.get("code")!;
  const tok = await fetch(`${MCP_URL}/oauth/token`, form({ grant_type: "authorization_code", code, redirect_uri: REDIRECT, client_id: clientId, code_verifier: verifier, resource: `${MCP_URL}/mcp` }));
  expect(tok.status).toBe(200);
  return ((await tok.json()) as { access_token: string }).access_token;
}

describe.skipIf(!A.pass || !B.pass)("Conecta tu IA contra staging", () => {
  afterAll(async () => {
    const s = await appSession(A);
    await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants?client_id=${WORKER_SUPABASE_CLIENT}`, { method: "DELETE", headers: { apikey: ANON, Authorization: `Bearer ${s}` } });
    for (const t of appSessions) {
      await fetch(`${SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ANON, Authorization: `Bearer ${t}` } });
    }
  });

  it("lista, protege y desconecta una IA de verdad", { timeout: 150_000 }, async () => {
    const appA = await appSession(A);
    const before = await list(appA);
    expect(before.status).toBe(200);
    const known = new Set(before.body!.conexiones.map((c) => c.id));

    const aiToken = await connectAI(A);
    expect((await mcpInit(aiToken)).status).toBe(200);

    // El listado de KV va atrasado hasta un minuto: se espera a que aparezca.
    let mine: Row[] = [];
    for (let i = 0; i < 16 && mine.length === 0; i++) {
      if (i) await new Promise((r) => setTimeout(r, 5_000));
      mine = (await list(appA)).body!.conexiones.filter((c) => !known.has(c.id));
    }
    expect(mine).toHaveLength(1);
    expect(mine[0]).toMatchObject({ ia: "Claude", vuelta: "localhost", local: true });
    expect(Math.abs(mine[0]!.conectadaEl - Date.now() / 1000)).toBeLessThan(300);

    // Ni el token de la IA ni otra cuenta pueden verla ni quitarla.
    expect((await list(aiToken)).status).toBe(401);
    expect((await remove(aiToken, mine[0]!.id)).status).toBe(401);
    expect((await remove(await appSession(B), mine[0]!.id)).status).toBe(404);
    expect((await mcpInit(aiToken)).status).toBe(200);

    // La app la quita: la IA deja de leer al momento.
    expect((await remove(appA, mine[0]!.id)).status).toBe(204);
    expect((await mcpInit(aiToken)).status).toBe(401);
    const last = await list(appA);
    expect(last.body!.conexiones.map((c) => c.id)).not.toContain(mine[0]!.id);
  });

  it("sin sesión de la app, 401", async () => {
    const res = await fetch(`${MCP_URL}/connections`);
    expect(res.status).toBe(401);
  });
});
