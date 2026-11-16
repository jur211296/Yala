/**
 * Telemetría propia, decisión 5 (2026-11-06): lo que solo ve el servidor —avisos de Apple y la última pregunta de IA
 * del cupo— deja un datapoint `e = "server"` en Analytics Engine para que el panel lo cuente. Offline: el dataset es
 * un doble que apunta cada `writeDataPoint`, y la firma de Apple se sustituye.
 *
 * Discrimina: con el código de antes el webhook no escribe nada en METRICS y `applyCheck` no marca el agotamiento.
 */
import { beforeEach, describe, expect, it, vi } from "vitest";
import { readFileSync } from "node:fs";

vi.mock("../src/storekit/verifyAppleJWS", () => ({ verifyAppleJWS: vi.fn() }));
vi.mock("../src/db", () => ({
  updateEntitlementByOriginalTxn: vi.fn(async () => undefined),
  updateAccountEntitlementByOriginalTxn: vi.fn(async () => undefined),
}));

import app from "../src/index";
import { verifyAppleJWS } from "../src/storekit/verifyAppleJWS";
import { SERVER_EVENTS, appstoreNotificationDetail, serverEvent } from "../src/serverEvent";
import { applyCheck, type CheckRequest } from "../src/rate_limiter";
import { gateAIRequest } from "../src/ratelimit";
import type { Env } from "../src/env";

interface Point {
  blobs: string[];
  doubles: number[];
  indexes: string[];
}

function dataset(points: Point[]) {
  return { writeDataPoint: (p: Point) => points.push(p) };
}

const verify = vi.mocked(verifyAppleJWS);

function postWebhook(points: Point[]) {
  return app.request(
    "/webhooks/appstore",
    { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ signedPayload: "outer" }) },
    { APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala", METRICS: dataset(points) },
  );
}

describe("serverEvent — forma del datapoint", () => {
  it("blobs [server, nombre, detalle, gateway, gateway], doubles [x], indexes [gateway]", () => {
    const points: Point[] = [];
    serverEvent({ METRICS: dataset(points) as unknown as AnalyticsEngineDataset }, "aiQuotaExhausted", "free|daily|text");
    expect(points).toEqual([
      { blobs: ["server", "aiQuotaExhausted", "free|daily|text", "gateway", "gateway"], doubles: [1], indexes: ["gateway"] },
    ]);
  });

  it("sin binding no hace nada (y no lanza)", () => {
    expect(() => serverEvent({}, "aiQuotaExhausted")).not.toThrow();
  });

  it("cada evento de la lista está documentado en qa/cloud/README.md", () => {
    const readme = readFileSync(new URL("../../qa/cloud/README.md", import.meta.url), "utf8");
    for (const name of SERVER_EVENTS) expect(readme, name).toContain(name);
  });
});

describe("appstoreNotificationDetail", () => {
  it.each([
    [{ notificationType: "SUBSCRIBED", subtype: "INITIAL_BUY", offerDiscountType: "FREE_TRIAL", environment: "Production" }, "SUBSCRIBED|INITIAL_BUY|trial|Production"],
    [{ notificationType: "SUBSCRIBED", subtype: "INITIAL_BUY", offerDiscountType: null, environment: "Production" }, "SUBSCRIBED|INITIAL_BUY|paid|Production"],
    [{ notificationType: "DID_RENEW", subtype: undefined, offerDiscountType: "PAY_AS_YOU_GO", environment: "Sandbox" }, "DID_RENEW|-|paid|Sandbox"],
    [{ notificationType: "TEST", subtype: undefined, offerDiscountType: undefined, environment: "Sandbox" }, "TEST|-|-|Sandbox"],
    // Nada que no tenga forma de slug llega al dataset.
    [{ notificationType: "a b", subtype: 3, offerDiscountType: undefined, environment: "x".repeat(41) }, "-|-|-|-"],
  ])("%j → %s", (args, expected) => {
    expect(appstoreNotificationDetail(args)).toBe(expected);
  });
});

describe("POST /webhooks/appstore — apunta el tipo de aviso", () => {
  beforeEach(() => verify.mockReset());

  it("prueba gratis de nuestro bundle: un datapoint, sin ids ni importes", async () => {
    verify
      .mockResolvedValueOnce({
        notificationType: "SUBSCRIBED",
        subtype: "INITIAL_BUY",
        data: { bundleId: "com.jurgenschmidt.yala", environment: "Production", signedTransactionInfo: "inner" },
      })
      .mockResolvedValueOnce({
        originalTransactionId: "2000000123456789",
        productId: "com.yala.pro.yearly",
        expiresDate: 1_800_000_000_000,
        bundleId: "com.jurgenschmidt.yala",
        offerDiscountType: "FREE_TRIAL",
        price: 29990,
      });
    const points: Point[] = [];
    const res = await postWebhook(points);
    expect(res.status).toBe(200);
    expect(points).toEqual([
      {
        blobs: ["server", "appstoreNotification", "SUBSCRIBED|INITIAL_BUY|trial|Production", "gateway", "gateway"],
        doubles: [1],
        indexes: ["gateway"],
      },
    ]);
    expect(JSON.stringify(points)).not.toContain("2000000123456789");
    expect(JSON.stringify(points)).not.toContain("29990");
  });

  it("aviso de OTRA app (el G3 firma todas): no se apunta", async () => {
    verify.mockResolvedValueOnce({ notificationType: "SUBSCRIBED", data: { bundleId: "com.otra.app", environment: "Production" } });
    const points: Point[] = [];
    expect((await postWebhook(points)).status).toBe(200);
    expect(points).toEqual([]);
  });

  it("firma inválida: 401 y nada en el dataset", async () => {
    verify.mockResolvedValueOnce(null);
    const points: Point[] = [];
    expect((await postWebhook(points)).status).toBe(401);
    expect(points).toEqual([]);
  });
});

describe("applyCheck — `exhausted` solo en la petición que gasta la última unidad", () => {
  const t0 = Date.UTC(2026, 10, 6, 12);

  it("cupo diario de 3: la 3.ª marca, la 1.ª y 2.ª no, la 4.ª se rechaza sin marcar", () => {
    const s = { day: "2026-11-06", counts: {}, burst: [] };
    const req = { category: "text", daily: 3, burstPerMin: 100 };
    const out = [0, 1, 2, 3].map((i) => applyCheck(s, req, t0 + i));
    expect(out.map((r) => r.allowed)).toEqual([true, true, true, false]);
    expect(out.map((r) => r.exhausted ?? false)).toEqual([false, false, true, false]);
  });

  it("prueba de Free de 1: la única petición la agota", () => {
    const s = { day: "2026-11-06", counts: {}, burst: [] };
    expect(applyCheck(s, { category: "voice", trial: 1, burstPerMin: 5 }, t0).exhausted).toBe(true);
  });

  it("leer una nota abierta no gasta, así que no marca", () => {
    const s = { day: "2026-11-06", counts: {}, burst: [], notes: [] as number[] };
    applyCheck(s, { category: "voice", daily: 1, burstPerMin: 5, notePairing: "grant" }, t0);
    expect(applyCheck(s, { category: "voice", daily: 1, burstPerMin: 5, notePairing: "consume" }, t0 + 1).exhausted).toBeUndefined();
  });
});

describe("gateAIRequest — apunta `aiQuotaExhausted` solo en categorías de IA", () => {
  function envWithLimiter(points: Point[], counts: Record<string, number> = {}): Env {
    const stores = new Map<string, Parameters<typeof applyCheck>[0]>();
    let now = Date.UTC(2026, 10, 6, 12);
    return {
      ENFORCE: "enforce",
      METRICS: dataset(points),
      RATE_LIMITER: {
        idFromName: (name: string) => name,
        get: (id: string) => ({
          fetch: async (_url: string, init?: RequestInit) => {
            const req = JSON.parse(String(init?.body ?? "{}")) as CheckRequest;
            const stored = stores.get(id) ?? { day: "2026-11-06", counts: { ...counts }, burst: [] };
            stores.set(id, stored);
            now += 61_000;
            return Response.json(applyCheck(stored, req, now));
          },
        }),
      },
    } as unknown as Env;
  }

  it("Free con la prueba de voz (5): la 5.ª petición apunta una vez y la 6.ª, rechazada, no", async () => {
    const points: Point[] = [];
    const env = envWithLimiter(points);
    const claims = { keyId: "k1", tier: "free" as const };
    const blocked: boolean[] = [];
    for (let i = 0; i < 6; i++) blocked.push((await gateAIRequest(env, claims, "voice")).blocked !== null);
    expect(blocked).toEqual([false, false, false, false, false, true]);
    expect(points.map((p) => p.blobs.slice(0, 3))).toEqual([["server", "aiQuotaExhausted", "free|trial|voice"]]);
  });

  it("tipos de cambio (mismo limitador, no es IA): no apunta aunque agote", async () => {
    const points: Point[] = [];
    // El cupo de tasas es de miles: el estado arranca a una petición del tope.
    const env = envWithLimiter(points, { rates: 1999, insights: 59 });
    const claims = { keyId: "k2", tier: "pro" as const };
    expect((await gateAIRequest(env, claims, "rates")).blocked).toBeNull();
    expect(points).toEqual([]);
    // Control: la misma situación en una categoría de IA sí apunta.
    expect((await gateAIRequest(env, claims, "insights")).blocked).toBeNull();
    expect(points.map((p) => p.blobs[2])).toEqual(["pro|daily|insights"]);
  });
});
