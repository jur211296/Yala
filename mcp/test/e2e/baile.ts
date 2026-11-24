/**
 * El baile OAuth de `oauth.e2e.test.ts`, para los e2e que solo necesitan un token del conector y llamar a herramientas.
 * Copia de sus funciones (aquel fichero se queda como está: es el que demuestra el baile).
 */
import { expect } from "vitest";
import { createHash, randomBytes } from "node:crypto";

export const MCP_URL = process.env.MCP_URL ?? "https://yala-mcp-staging.misty-surf-6866.workers.dev";
export const GATEWAY_URL = process.env.GATEWAY_URL ?? "https://yala-gateway-staging.misty-surf-6866.workers.dev";
export const SUPABASE_URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";
const WORKER_SUPABASE_CLIENT = "65fb5767-59a5-4f50-b77c-7970e67589c5";
const REDIRECT = "http://localhost:53682/callback";

export const A = { email: process.env.USER_A_EMAIL ?? "", pass: process.env.USER_A_PASS ?? "" };

const b64url = (buf: Buffer) => buf.toString("base64url");

export interface AsMetadata {
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

export async function discover(): Promise<AsMetadata> {
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

export async function register(meta: AsMetadata): Promise<string> {
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
export async function authorize(meta: AsMetadata, clientId: string, user: { email: string; pass: string }) {
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
  expect(html).toMatch(/quiere (leer|usar) tus datos de Yala/);
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

export async function mcp(token: string, method: string, params: unknown = {}) {
  const res = await fetch(`${MCP_URL}/mcp`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", Accept: "application/json, text/event-stream" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { result: any }).result;
}

export async function tool(token: string, name: string, args: Record<string, unknown> = {}) {
  const r = await mcp(token, "tools/call", { name, arguments: args });
  expect(r.isError, r.content?.[0]?.text).toBeFalsy();
  return JSON.parse(r.content[0].text);
}

export async function passwordSession(user: { email: string; pass: string }): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.pass }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { access_token: string }).access_token;
}

export async function logout(token: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/auth/v1/logout?scope=local`, { method: "POST", headers: { apikey: ANON, Authorization: `Bearer ${token}` } });
}

export async function revokeWorkerGrant(user: { email: string; pass: string }) {
  const s = await passwordSession(user);
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user/oauth/grants?client_id=${WORKER_SUPABASE_CLIENT}`, {
    method: "DELETE",
    headers: { apikey: ANON, Authorization: `Bearer ${s}` },
  });
  await logout(s);
  return res.status;
}

