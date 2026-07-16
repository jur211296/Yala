/**
 * Units OFFLINE del fan-out de silent push (G8-1) + guard de auth del registro. 100% sin red (fetch
 * stubbeado): corren en CI como los unit de apns.sign/attest. Ejercen `fanOutGroupPush` como función pura
 * (env + JWT dummy + fetch stub) — no pegan a staging ni a APNs reales.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Hono } from "hono";
import { exportPKCS8, generateKeyPair } from "jose";
import type { Env } from "../src/env";
import { fanOutGroupPush } from "../src/groups/routes";
import { handlePushRegister } from "../src/push/register";
import { _resetJwtCacheForTests } from "../src/push/apns";

const RPC_URL = "https://stub.local";

async function makePem(): Promise<string> {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
}

/** Env base para el fan-out. Sin RATE_LIMITER (skip del rate-limit); ENFORCE observe (attest opcional). */
function makeFanoutEnv(pem: string | undefined, overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    APPLE_TEAM_ID: "3WKFFVD66J",
    APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala.dev",
    APNS_KEY_ID: pem ? "TESTKEYID1" : undefined,
    APNS_AUTH_KEY: pem,
    SUPABASE_URL: RPC_URL,
    SUPABASE_ANON_KEY: "anon-stub",
    ...overrides,
  } as unknown as Env;
}

const AUTH = { userJWT: "dummy.jwt.token" };

interface Recorded {
  url: string;
  init?: RequestInit;
}

/** Stub de fetch: registra cada llamada; responde según un router por-URL. */
function stubFetch(router: (url: string, init?: RequestInit) => Response, sink: Recorded[]) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string | URL | Request, init?: RequestInit) => {
      const u = typeof url === "string" ? url : url instanceof URL ? url.toString() : (url as Request).url;
      sink.push({ url: u, init });
      return router(u, init);
    }),
  );
}

function tokensResponse(rows: Array<{ user_id: string; device_token: string; platform: string }>): Response {
  return new Response(JSON.stringify(rows), { status: 200, headers: { "content-type": "application/json" } });
}

const APPLE_OK = () => new Response("{}", { status: 200, headers: { "apns-id": "x" } });

describe("fanOutGroupPush — units offline", () => {
  beforeEach(() => _resetJwtCacheForTests());
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("short-circuit sin APNS_KEY_ID: cero fetches (ni PostgREST ni Apple)", async () => {
    const calls: Recorded[] = [];
    stubFetch(() => APPLE_OK(), calls);
    await fanOutGroupPush(makeFanoutEnv(undefined), AUTH, ["g-1"]);
    expect(calls.length).toBe(0);
  });

  it("happy path: 1 grupo → get_group_push_tokens + 1 push a Apple (host por platform, payload yala)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) {
        return tokensResponse([{ user_id: "u-b", device_token: "b".repeat(64), platform: "ios-sandbox" }]);
      }
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);

    const apple = calls.filter((c) => c.url.includes("push.apple.com"));
    expect(apple.length).toBe(1);
    expect(apple[0].url).toContain("api.sandbox.push.apple.com"); // ios-sandbox
    expect(apple[0].url).toContain("b".repeat(64));
    const headers = apple[0].init?.headers as Record<string, string>;
    expect(headers["apns-push-type"]).toBe("background");
    expect(headers["apns-priority"]).toBe("5");
    const payload = JSON.parse(apple[0].init?.body as string);
    expect(payload.aps["content-available"]).toBe(1);
    expect(payload.yala.kind).toBe("groups-sync");
  });

  it("dedup cross-grupo: un member en 2 grupos del batch recibe UN solo push", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    const shared = { user_id: "u-b", device_token: "b".repeat(64), platform: "ios-prod" };
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse([shared]);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1", "g-2"]);

    // 2 grupos → 2 RPCs de tokens, pero el token repetido → 1 solo push a Apple.
    expect(calls.filter((c) => c.url.includes("/rpc/get_group_push_tokens")).length).toBe(2);
    expect(calls.filter((c) => c.url.includes("push.apple.com")).length).toBe(1);
  });

  it("cap de 50: 60 tokens distintos → exactamente 50 pushes a Apple", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    const rows = Array.from({ length: 60 }, (_, i) => ({
      user_id: `u-${i}`,
      device_token: i.toString(16).padStart(64, "0"),
      platform: "ios-prod",
    }));
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokensResponse(rows);
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);
    expect(calls.filter((c) => c.url.includes("push.apple.com")).length).toBe(50);
  });

  it("BadDeviceToken → prune_push_token del par (best-effort)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) {
        return tokensResponse([{ user_id: "u-b", device_token: "d".repeat(64), platform: "ios-prod" }]);
      }
      if (url.includes("push.apple.com")) {
        return new Response(JSON.stringify({ reason: "BadDeviceToken" }), { status: 400 });
      }
      if (url.includes("/rpc/prune_push_token")) return new Response(JSON.stringify({ pruned: 1 }), { status: 200 });
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);

    const prune = calls.filter((c) => c.url.includes("/rpc/prune_push_token"));
    expect(prune.length).toBe(1);
    const pruneBody = JSON.parse(prune[0].init?.body as string);
    expect(pruneBody.p_user_id).toBe("u-b");
    expect(pruneBody.p_device_token).toBe("d".repeat(64));
  });

  it("get_group_push_tokens upstream error → sin push, sin crash (best-effort)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return new Response("boom", { status: 500 });
      if (url.includes("push.apple.com")) return APPLE_OK();
      return new Response("{}", { status: 200 });
    }, calls);

    await fanOutGroupPush(makeFanoutEnv(pem), AUTH, ["g-1"]);
    expect(calls.filter((c) => c.url.includes("push.apple.com")).length).toBe(0);
  });
});

describe("/push/register — guard offline (sin red)", () => {
  const app = new Hono<{ Bindings: Env }>();
  app.post("/push/register", handlePushRegister);

  it("401 sin JWT (Authorization ausente → requireUserAndAttest corta antes de cualquier fetch)", async () => {
    const calls: Recorded[] = [];
    stubFetch(() => new Response("{}", { status: 200 }), calls);
    const res = await app.request(
      "/push/register",
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ device_token: "a".repeat(64), platform: "ios-prod" }) },
      makeFanoutEnv(undefined),
    );
    expect(res.status).toBe(401);
    expect(calls.length).toBe(0); // ni siquiera intentó verificar el JWT (no hay Bearer)
    vi.unstubAllGlobals();
  });
});
