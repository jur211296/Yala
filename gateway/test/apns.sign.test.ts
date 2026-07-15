/**
 * Spike G0 — firma del JWT de provider de APNs + guards de /v1/debug/push.
 * 100% OFFLINE (fetch stubbeado): corre en CI como los unit de attest/policy.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Hono } from "hono";
import {
  decodeProtectedHeader,
  exportPKCS8,
  generateKeyPair,
  jwtVerify,
} from "jose";
import type { Env } from "../src/env";
import { _resetJwtCacheForTests, sendPush, signApnsJwt } from "../src/push/apns";
import { handleDebugPush } from "../src/push/routes";

const TEAM_ID = "3WKFFVD66J";
const KEY_ID = "TESTKEYID1";

async function makeKeys() {
  const { privateKey, publicKey } = await generateKeyPair("ES256", { extractable: true });
  return { pem: await exportPKCS8(privateKey), publicKey };
}

function makeEnv(pem: string, overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    APPLE_TEAM_ID: TEAM_ID,
    APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala.dev",
    DEV_SHARED_SECRET: "test-dev-secret",
    APNS_KEY_ID: KEY_ID,
    APNS_AUTH_KEY: pem,
    ...overrides,
  } as Env;
}

describe("signApnsJwt", () => {
  it("firma ES256 con kid/iss/iat correctos y sin exp", async () => {
    const { pem, publicKey } = await makeKeys();
    const jwt = await signApnsJwt(pem, KEY_ID, TEAM_ID);

    const header = decodeProtectedHeader(jwt);
    expect(header.alg).toBe("ES256");
    expect(header.kid).toBe(KEY_ID);

    const { payload } = await jwtVerify(jwt, publicKey); // sin maxTokenAge: la ausencia de exp no rompe
    expect(payload.iss).toBe(TEAM_ID);
    const nowSec = Date.now() / 1000;
    expect(Math.abs((payload.iat ?? 0) - nowSec)).toBeLessThan(5);
    expect(payload.exp).toBeUndefined();
  });

  it("acepta PEM con \\n literales (secret pegado sin saltos)", async () => {
    const { pem, publicKey } = await makeKeys();
    const escaped = pem.replace(/\n/g, "\\n");
    const jwt = await signApnsJwt(escaped, KEY_ID, TEAM_ID);
    const { payload } = await jwtVerify(jwt, publicKey);
    expect(payload.iss).toBe(TEAM_ID);
  });
});

describe("sendPush — cache del JWT y diagnóstico de transporte", () => {
  let authHeaders: string[];

  beforeEach(() => {
    _resetJwtCacheForTests();
    authHeaders = [];
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-07-14T12:00:00Z"));
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: RequestInit) => {
        authHeaders.push((init.headers as Record<string, string>).authorization);
        return new Response("{}", { status: 200, headers: { "apns-id": "test-apns-id" } });
      }),
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  const req = { deviceToken: "a".repeat(64), sandbox: true } as const;

  it("reusa el token dentro del TTL y re-firma tras 51 min o al rotar keyId", async () => {
    const { pem } = await makeKeys();
    const env = makeEnv(pem);

    const r1 = await sendPush(env, req);
    await sendPush(env, req);
    expect(r1.delivered).toBe(true);
    expect(r1.apnsId).toBe("test-apns-id");
    expect(authHeaders[0]).toBe(authHeaders[1]); // cache HIT

    vi.advanceTimersByTime(51 * 60 * 1000);
    await sendPush(env, req);
    expect(authHeaders[2]).not.toBe(authHeaders[1]); // expiró → re-firma

    await sendPush(makeEnv(pem, { APNS_KEY_ID: "OTHERKEY01" }), req);
    expect(authHeaders[3]).not.toBe(authHeaders[2]); // keyId rotado → re-firma
  });

  it("selecciona host por sandbox y topic del primer bundle id (CSV)", async () => {
    const { pem } = await makeKeys();
    const env = makeEnv(pem, { APPLE_BUNDLE_IDS: "com.a.uno, com.b.dos" });
    const r = await sendPush(env, { ...req, sandbox: false });
    expect(r.host).toBe("https://api.push.apple.com");
    expect(r.topic).toBe("com.a.uno");
  });

  it("fetch que LANZA resuelve con transportError (jamás rechaza)", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new TypeError("connection failed: ALPN");
      }),
    );
    const { pem } = await makeKeys();
    const r = await sendPush(makeEnv(pem), req);
    expect(r.delivered).toBe(false);
    expect(r.status).toBeUndefined();
    expect(r.transportError).toContain("ALPN");
  });
});

describe("handleDebugPush — guards (vía app.request de Hono)", () => {
  const app = new Hono<{ Bindings: Env }>();
  app.post("/v1/debug/push", handleDebugPush);

  const post = (env: Env, headers: Record<string, string> = {}, body: unknown = {}) =>
    app.request(
      "/v1/debug/push",
      {
        method: "POST",
        headers: { "content-type": "application/json", ...headers },
        body: JSON.stringify(body),
      },
      env,
    );

  it("404 en producción (allowsDevBypass)", async () => {
    const { pem } = await makeKeys();
    const res = await post(makeEnv(pem, { ENVIRONMENT: "production" }), {
      "X-Yala-Dev-Secret": "test-dev-secret",
    });
    expect(res.status).toBe(404);
  });

  it("401 con dev secret ausente o inválido", async () => {
    const { pem } = await makeKeys();
    expect((await post(makeEnv(pem))).status).toBe(401);
    expect((await post(makeEnv(pem), { "X-Yala-Dev-Secret": "wrong" })).status).toBe(401);
  });

  it("503 sin secrets de APNs configurados", async () => {
    const { pem } = await makeKeys();
    const res = await post(makeEnv(pem, { APNS_AUTH_KEY: undefined, APNS_KEY_ID: undefined }), {
      "X-Yala-Dev-Secret": "test-dev-secret",
    });
    expect(res.status).toBe(503);
  });

  it("400 con deviceToken no-hex-64", async () => {
    const { pem } = await makeKeys();
    const res = await post(
      makeEnv(pem),
      { "X-Yala-Dev-Secret": "test-dev-secret" },
      { deviceToken: "zzzz" },
    );
    expect(res.status).toBe(400);
  });
});
