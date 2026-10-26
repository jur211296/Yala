/**
 * Card `9f9u` (ticket `gateway-has-no-telemetry`): los canarios del gateway dejan rastro en Analytics Engine, no
 * solo en `wrangler tail`. Offline: el dataset es un doble que apunta cada `writeDataPoint`.
 *
 * Discrimina: con el código de antes (solo `console.log`) ninguno de estos casos escribe un datapoint.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { exportPKCS8, generateKeyPair } from "jose";
import type { Env } from "../src/env";
import { fanOutGroupPush } from "../src/groups/routes";
import { _resetJwtCacheForTests } from "../src/push/apns";
import { SERVER_CANARIES, serverCanary } from "../src/serverCanary";
import { readFileSync } from "node:fs";

interface Point {
  blobs: string[];
  doubles: number[];
  indexes: string[];
}

function fakeDataset(points: Point[]) {
  return { writeDataPoint: (p: Point) => points.push(p) };
}

async function makePem(): Promise<string> {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
}

function env(points: Point[], pem: string | undefined, overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    APPLE_TEAM_ID: "3WKFFVD66J",
    APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala.dev",
    APNS_KEY_ID: pem ? "TESTKEYID1" : undefined,
    APNS_AUTH_KEY: pem,
    SUPABASE_URL: "https://stub.local",
    SUPABASE_ANON_KEY: "anon-stub",
    PUSH_ROLE_JWT: "machine.jwt.token",
    METRICS: fakeDataset(points),
    ...overrides,
  } as unknown as Env;
}

const AUTH = { userJWT: "dummy.jwt.token", sub: "u-a" };

function stubFetch(router: (url: string) => Response) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string | URL | Request) => {
      const u = typeof url === "string" ? url : url instanceof URL ? url.toString() : (url as Request).url;
      return router(u);
    }),
  );
}

const tokens = (n: number) =>
  new Response(
    JSON.stringify(Array.from({ length: n }, (_, i) => ({ user_id: `u-${i}`, device_token: String(i).repeat(64).slice(0, 64), platform: "ios-prod" }))),
    { status: 200 },
  );

const names = (points: Point[]) => points.map((p) => p.blobs[1]);

describe("canarios del gateway en Analytics Engine", () => {
  beforeEach(() => _resetJwtCacheForTests());
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("la forma es la de POST /metrics, con app = install = gateway", () => {
    const points: Point[] = [];
    serverCanary(env(points, undefined), "groupApnsSendFailed", "500/InternalServerError");
    expect(points).toEqual([
      { blobs: ["canary", "groupApnsSendFailed", "500/InternalServerError", "gateway", "gateway"], doubles: [1], indexes: ["gateway"] },
    ]);
  });

  it("sin binding no hace nada ni lanza", () => {
    expect(() => serverCanary({ METRICS: undefined }, "groupFanoutDelivered", "", 3)).not.toThrow();
  });

  it("APNs falla por un motivo que no es token muerto → groupApnsSendFailed + entregados 0", async () => {
    const pem = await makePem();
    const points: Point[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokens(1);
      if (url.includes("push.apple.com")) return new Response(JSON.stringify({ reason: "TooManyRequests" }), { status: 429 });
      return new Response("{}", { status: 200 });
    });
    await fanOutGroupPush(env(points, pem), AUTH, ["g-1"]);
    expect(names(points)).toEqual(["groupApnsSendFailed", "groupFanoutDelivered"]);
    expect(points[0].blobs[2]).toBe("429/TooManyRequests");
    expect(points[1].doubles).toEqual([0]);
  });

  it("los entregados se cuentan en UNA fila por fan-out", async () => {
    const pem = await makePem();
    const points: Point[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokens(3);
      if (url.includes("push.apple.com")) return new Response("{}", { status: 200 });
      return new Response("{}", { status: 200 });
    });
    await fanOutGroupPush(env(points, pem), AUTH, ["g-1"]);
    expect(names(points)).toEqual(["groupFanoutDelivered"]);
    expect(points[0].doubles).toEqual([3]);
  });

  it("token muerto → groupPushTokenPruned; el podado que falla → groupPushTokenPruneFailed", async () => {
    const pem = await makePem();
    const points: Point[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokens(1);
      if (url.includes("push.apple.com")) return new Response(JSON.stringify({ reason: "BadDeviceToken" }), { status: 400 });
      if (url.includes("/rpc/prune_push_token")) return new Response("{}", { status: 503 });
      return new Response("{}", { status: 200 });
    });
    await fanOutGroupPush(env(points, pem), AUTH, ["g-1"]);
    expect(names(points)).toEqual(["groupPushTokenPruned", "groupPushTokenPruneFailed", "groupFanoutDelivered"]);
    expect(points[1].blobs[2]).toBe("503");
  });

  it("la RPC de tokens responde no-2xx → groupFanoutTokensRpcFailed con el nombre de la RPC", async () => {
    const pem = await makePem();
    const points: Point[] = [];
    stubFetch(() => new Response("{}", { status: 403 }));
    await fanOutGroupPush(env(points, pem), AUTH, ["g-1"], null, { kind: "admins" });
    expect(names(points)).toEqual(["groupFanoutTokensRpcFailed"]);
    expect(points[0].blobs[2]).toBe("get_group_admin_push_tokens/403");
  });

  it("sin APNs o sin credencial de máquina, cada fan-out lo dice", async () => {
    const points: Point[] = [];
    stubFetch(() => new Response("{}", { status: 200 }));
    await fanOutGroupPush(env(points, undefined), AUTH, ["g-1"]);
    const pem = await makePem();
    await fanOutGroupPush(env(points, pem, { PUSH_ROLE_JWT: undefined }), AUTH, ["g-1"]);
    expect(names(points)).toEqual(["groupFanoutApnsNotConfigured", "groupFanoutPushRoleMissing"]);
  });

  it("el detalle nunca lleva un device token", async () => {
    const pem = await makePem();
    const points: Point[] = [];
    stubFetch((url) => {
      if (url.includes("/rpc/get_group_push_tokens")) return tokens(1);
      if (url.includes("push.apple.com")) return new Response(JSON.stringify({ reason: "BadDeviceToken" }), { status: 400 });
      return new Response("{}", { status: 200 });
    });
    await fanOutGroupPush(env(points, pem), AUTH, ["g-1"]);
    for (const p of points) expect(p.blobs.join("|")).not.toContain("0".repeat(16));
  });

  it("cada canario de la lista está documentado en qa/cloud/README.md", () => {
    const readme = readFileSync(new URL("../../qa/cloud/README.md", import.meta.url), "utf8");
    for (const name of SERVER_CANARIES) expect(readme, name).toContain(name);
  });
});
