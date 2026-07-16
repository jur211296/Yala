/**
 * Goldens de G8-1 — registro de device tokens + fan-out de silent push, contra STAGING REAL (network ON).
 * Dos bloques:
 *   1. `/push/register` + `/push/unregister` WIRE — NO-skip: los endpoints solo tocan `push_tokens` (que YA
 *      existe) vía PostgREST; pasan HOY sin la migración g8_01.
 *   2. Fan-out semi-WIRE — `describe.skip` HASTA aplicar g8_01 (los RPCs `get_group_push_tokens` /
 *      `prune_push_token` aún no existen). TRAS aplicar: cambiar `describe.skip(` → `describe(` y re-correr.
 *      El fetch a `*.push.apple.com` se INTERCEPTA (mock); el resto pega a staging real.
 *
 * NO corre en CI (necesita red + i5-user-a/b). Los tokens dummy sembrados se limpian al final de cada test.
 */
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { exportPKCS8, generateKeyPair } from "jose";
import app from "../src/index";
import type { Env } from "../src/env";
import type { GroupPushResponse } from "../src/groups/types";

declare const process: { env: Record<string, string | undefined> };

const URL = "https://fostjbbwstyuunmmefuk.supabase.co";
const ANON =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg";
const ENC_KEY = process.env.GROUPS_ENC_KEY ?? "";

// Env base (register/unregister no necesitan APNs ni enc key). El PEM APNs se inyecta en el bloque fan-out.
const env = {
  ENVIRONMENT: "staging",
  ENFORCE: "observe",
  JWT_SIGNING_SECRET: "test-secret-please-change-0123456789",
  SUPABASE_URL: URL,
  SUPABASE_ANON_KEY: ANON,
  GROUPS_ENC_KEY: ENC_KEY,
} as unknown as Env;

let jwtA = "";
let jwtB = "";
let subA = "";
let subB = "";

function decodeSub(jwt: string): string {
  let p = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  p += "=".repeat((4 - (p.length % 4)) % 4);
  return (JSON.parse(atob(p)) as { sub: string }).sub;
}
async function login(email: string, password: string): Promise<string> {
  const res = await fetch(`${URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const body = (await res.json()) as { access_token?: string };
  if (!body.access_token) throw new Error(`login ${email} failed: ${JSON.stringify(body)}`);
  return body.access_token;
}

// Ctx no-op para app.fetch (AJUSTE #1). El bloque fan-out usa uno COLECTOR (abajo).
const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

async function register(jwt: string, deviceToken: string, platform: string): Promise<number> {
  const res = await app.fetch(
    new Request("https://gw.local/push/register", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ device_token: deviceToken, platform }),
    }),
    env,
    NOOP_CTX,
  );
  return res.status;
}
async function unregister(jwt: string, deviceToken: string): Promise<number> {
  const res = await app.fetch(
    new Request("https://gw.local/push/unregister", {
      method: "POST",
      headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify({ device_token: deviceToken }),
    }),
    env,
    NOOP_CTX,
  );
  return res.status;
}
/** Cuenta las filas push_tokens (user, token) directo por PostgREST con el JWT del user (RLS per-user). */
async function countToken(jwt: string, sub: string, deviceToken: string): Promise<number> {
  const res = await fetch(`${URL}/rest/v1/push_tokens?user_id=eq.${sub}&device_token=eq.${deviceToken}&select=device_token`, {
    headers: { apikey: ANON, Authorization: `Bearer ${jwt}` },
  });
  const rows = (await res.json()) as unknown[];
  return Array.isArray(rows) ? rows.length : 0;
}

function dummyToken(seed: string): string {
  // hex-64 determinista por seed (para poder limpiarlo). No es un token APNs real.
  let s = "";
  for (let i = 0; i < 64; i++) s += (((seed.charCodeAt(i % seed.length) + i) % 16)).toString(16);
  return s;
}

beforeAll(async () => {
  jwtA = await login("i5-user-a@test.yala", "I5-Passw0rd-A!");
  jwtB = await login("i5-user-b@test.yala", "I5-Passw0rd-B!");
  subA = decodeSub(jwtA);
  subB = decodeSub(jwtB);
}, 30_000);

describe("G8 goldens · /push/register + /push/unregister contra staging real", () => {
  it("401 sin JWT", async () => {
    const res = await app.fetch(
      new Request("https://gw.local/push/register", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ device_token: dummyToken("x"), platform: "ios-prod" }) }),
      env,
      NOOP_CTX,
    );
    expect(res.status).toBe(401);
  }, 30_000);

  it("400 device_token no-hex-64", async () => {
    expect(await register(jwtA, "zzzz", "ios-prod")).toBe(400);
  }, 30_000);

  it("400 platform inválida", async () => {
    expect(await register(jwtA, dummyToken("plat"), "android")).toBe(400);
  }, 30_000);

  it("upsert idempotente: 2 registros del MISMO par → 1 sola fila; unregister la borra", async () => {
    const tok = dummyToken("idem-a");
    expect(await register(jwtA, tok, "ios-sandbox")).toBe(200);
    expect(await register(jwtA, tok, "ios-prod")).toBe(200); // re-registro (platform cambia) → merge, no dup
    expect(await countToken(jwtA, subA, tok)).toBe(1);

    expect(await unregister(jwtA, tok)).toBe(200);
    expect(await countToken(jwtA, subA, tok)).toBe(0);
  }, 60_000);

  it("aislamiento per-user: el token de A no aparece bajo B (RLS)", async () => {
    const tok = dummyToken("iso-a");
    expect(await register(jwtA, tok, "ios-prod")).toBe(200);
    expect(await countToken(jwtB, subB, tok)).toBe(0); // B no ve el token de A
    expect(await unregister(jwtA, tok)).toBe(200);
  }, 60_000);
});

// ============================================================================
// Fan-out semi-WIRE · REQUIERE g8_01 aplicada (get_group_push_tokens / prune_push_token).
// ⚠️ ACTIVACIÓN POR EL LOOP: tras aplicar g8_01, cambiar `describe.skip(` → `describe(` y re-correr npm test.
// Interceptor SELECTIVO de fetch: *.push.apple.com → mock; el resto → fetch REAL (staging). Teardown en
// afterEach restaura el fetch original (sin él, el stub se filtra a los goldens hermanos que pegan a staging).
// ============================================================================
async function makeApnsPem(): Promise<string> {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
}

describe("G8 goldens · fan-out de silent push (post-aplicación g8_01)", () => {
  let apnsEnv: Env;
  let appleHits: Array<{ url: string; init?: RequestInit }>;
  let appleResponder: () => Response;

  beforeAll(async () => {
    const pem = await makeApnsPem();
    apnsEnv = {
      ...env,
      APPLE_TEAM_ID: "3WKFFVD66J",
      APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala.dev",
      APNS_KEY_ID: "TESTKEYID1",
      APNS_AUTH_KEY: pem,
    } as unknown as Env;
  });

  afterEach(() => vi.unstubAllGlobals());

  /** Wrap selectivo: apple → mock (registrado en appleHits); el resto → fetch REAL capturado antes del stub. */
  function installApnsInterceptor() {
    appleHits = [];
    const realFetch = globalThis.fetch;
    vi.stubGlobal("fetch", async (url: string | URL | Request, init?: RequestInit) => {
      const u = typeof url === "string" ? url : "url" in (url as Request) ? (url as Request).url : String(url);
      if (u.includes("push.apple.com")) {
        appleHits.push({ url: u, init });
        return appleResponder();
      }
      return realFetch(url as never, init as never);
    });
  }

  /** push con ctx COLECTOR: junta las promesas de waitUntil (el fan-out) para poder awaitarlas. */
  async function pushCollect(jwt: string, deltas: unknown[]): Promise<GroupPushResponse> {
    const promises: Promise<unknown>[] = [];
    const ctx = { waitUntil(p: Promise<unknown>) { promises.push(p); }, passThroughOnException() {} } as unknown as ExecutionContext;
    const res = await app.fetch(
      new Request("https://gw.local/groups/push", {
        method: "POST",
        headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
        body: JSON.stringify({ deltas }),
      }),
      apnsEnv,
      ctx,
    );
    const body = (await res.json()) as GroupPushResponse;
    await Promise.all(promises); // esperar el fan-out (waitUntil) ANTES de assertar
    return body;
  }

  // Setup de grupo compartido A+B (create/invite/join/approve) directo por RPC.
  async function rpc(jwt: string, fn: string, args: Record<string, unknown>): Promise<any> {
    const finalArgs = ["create_group", "join_group"].includes(fn) ? { ...args, p_key: ENC_KEY } : args;
    const res = await fetch(`${URL}/rest/v1/rpc/${fn}`, {
      method: "POST",
      headers: { apikey: ANON, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
      body: JSON.stringify(finalArgs),
    });
    const text = await res.text();
    return text ? JSON.parse(text) : null;
  }
  async function setupSharedGroup(): Promise<string> {
    const gid = `g8-fanout-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    await rpc(jwtA, "create_group", { p_group_id: gid, p_name: "G8 fanout", p_currency_code: "PEN", p_icon_name: "star", p_color_hex: "#112233", p_display_name: "Alice", p_default_split_type: "equal" });
    const inv = await rpc(jwtA, "create_group_invite", { p_group_id: gid, p_ttl_seconds: 3600, p_max_uses: null });
    const joined = await rpc(jwtB, "join_group", { p_token: inv as string, p_display_name: "Bob", p_legacy_member_key: null });
    await rpc(jwtA, "approve_member", { p_group_id: gid, p_member_key: joined.member_key as string });
    return gid;
  }

  it("A push delta → fan-out despierta SOLO a B (no a A); host sandbox; headers background/5; payload yala", async () => {
    const gid = await setupSharedGroup();
    const tokA = dummyToken("fanA");
    const tokB = dummyToken("fanB");
    expect(await register(jwtA, tokA, "ios-sandbox")).toBe(200);
    expect(await register(jwtB, tokB, "ios-sandbox")).toBe(200);

    appleResponder = () => new Response("{}", { status: 200, headers: { "apns-id": "ok" } });
    installApnsInterceptor();

    const h = `${new Date(Date.UTC(2026, 6, 15, 12, 0, 0)).toISOString()}-0001-000000000000000a`;
    const r = await pushCollect(jwtA, [
      { entity_type: "split_expenses", group_id: gid, sync_id: crypto.randomUUID(), op: "upsert", fields: { amount: 10, currency_code: "PEN", note: "fanout" }, field_hlcs: { gmoney: h, note: h }, hlc: h, client_mutation_id: crypto.randomUUID() },
    ]);
    expect(r.results[0].status).toBe("applied");

    // El fan-out golpeó APNs EXACTAMENTE 1 vez, con el token de B (no el de A).
    expect(appleHits.length).toBe(1);
    expect(appleHits[0].url).toContain(tokB);
    expect(appleHits[0].url).not.toContain(tokA);
    expect(appleHits[0].url).toContain("api.sandbox.push.apple.com");
    const headers = appleHits[0].init?.headers as Record<string, string>;
    expect(headers["apns-push-type"]).toBe("background");
    expect(headers["apns-priority"]).toBe("5");
    const payload = JSON.parse(appleHits[0].init?.body as string);
    expect(payload.aps["content-available"]).toBe(1);
    expect(payload.yala.kind).toBe("groups-sync");

    await unregister(jwtA, tokA);
    await unregister(jwtB, tokB);
  }, 120_000);

  it("APNs 400 BadDeviceToken → prune borra la fila de push_tokens de B", async () => {
    const gid = await setupSharedGroup();
    const tokB = dummyToken("pruneB");
    expect(await register(jwtB, tokB, "ios-sandbox")).toBe(200);
    expect(await countToken(jwtB, subB, tokB)).toBe(1);

    appleResponder = () => new Response(JSON.stringify({ reason: "BadDeviceToken" }), { status: 400 });
    installApnsInterceptor();

    const h = `${new Date(Date.UTC(2026, 6, 15, 12, 30, 0)).toISOString()}-0001-000000000000000a`;
    const r = await pushCollect(jwtA, [
      { entity_type: "split_expenses", group_id: gid, sync_id: crypto.randomUUID(), op: "upsert", fields: { amount: 20, currency_code: "PEN", note: "prune" }, field_hlcs: { gmoney: h, note: h }, hlc: h, client_mutation_id: crypto.randomUUID() },
    ]);
    expect(r.results[0].status).toBe("applied");
    expect(appleHits.length).toBe(1);

    // El prune (best-effort, dentro del waitUntil ya awaited) borró el token muerto de B.
    expect(await countToken(jwtB, subB, tokB)).toBe(0);
  }, 120_000);
});
