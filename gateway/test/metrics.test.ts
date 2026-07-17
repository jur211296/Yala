import { describe, expect, it, vi } from "vitest";
import app from "../src/index";
import { parseMetricsBody } from "../src/metrics";

/**
 * POST /metrics (2026-07-17, sustituye TelemetryDeck) — ingestión pública ping/register/canary → AE.
 * Unit/offline: el binding METRICS se mockea; goldens del shape EXACTO de writeDataPoint
 * (blobs [e,n,d,app,install] / doubles [x] / indexes [install]) + tabla de rechazos 400.
 */

const INSTALL = "a1b2c3d4e5f60718"; // 16 hex — el mínimo válido

interface WrittenPoint {
  blobs?: string[];
  doubles?: number[];
  indexes?: string[];
}

function makeDataset() {
  return { writeDataPoint: vi.fn<(p: WrittenPoint) => void>() };
}

function postMetrics(body: unknown, env: Record<string, unknown>): Response | Promise<Response> {
  return app.request(
    "/metrics",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: typeof body === "string" ? body : JSON.stringify(body),
    },
    env,
  );
}

describe("POST /metrics — goldens del shape writeDataPoint", () => {
  it("ping: blobs [e,'','',app,install], doubles [1], indexes [install]", async () => {
    const ds = makeDataset();
    const res = await postMetrics({ v: 1, install: INSTALL, app: "2.0.5", events: [{ e: "ping" }] }, { METRICS: ds });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, accepted: 1 });
    expect(ds.writeDataPoint).toHaveBeenCalledExactlyOnceWith({
      blobs: ["ping", "", "", "2.0.5", INSTALL],
      doubles: [1],
      indexes: [INSTALL],
    });
  });

  it("register con variante: n/d viajan como blob2/blob3", async () => {
    const ds = makeDataset();
    const res = await postMetrics(
      { v: 1, install: INSTALL, events: [{ e: "register", n: "local", d: "groupsOnly" }] },
      { METRICS: ds },
    );
    expect(res.status).toBe(200);
    expect(ds.writeDataPoint).toHaveBeenCalledExactlyOnceWith({
      blobs: ["register", "local", "groupsOnly", "", INSTALL],
      doubles: [1],
      indexes: [INSTALL],
    });
  });

  it("canary con valor: x viaja como double1", async () => {
    const ds = makeDataset();
    await postMetrics(
      { v: 1, install: INSTALL, events: [{ e: "canary", n: "cloudSyncMerkleDivergence", d: "tx_items", x: 3 }] },
      { METRICS: ds },
    );
    expect(ds.writeDataPoint).toHaveBeenCalledExactlyOnceWith({
      blobs: ["canary", "cloudSyncMerkleDivergence", "tx_items", "", INSTALL],
      doubles: [3],
      indexes: [INSTALL],
    });
  });

  it("batch: un datapoint POR evento, en orden", async () => {
    const ds = makeDataset();
    const res = await postMetrics(
      { v: 1, install: INSTALL, events: [{ e: "ping" }, { e: "register", n: "cloud", d: "migration" }] },
      { METRICS: ds },
    );
    expect(await res.json()).toEqual({ ok: true, accepted: 2 });
    expect(ds.writeDataPoint).toHaveBeenCalledTimes(2);
    expect(ds.writeDataPoint.mock.calls[0][0].blobs?.[0]).toBe("ping");
    expect(ds.writeDataPoint.mock.calls[1][0].blobs?.[0]).toBe("register");
  });

  it("binding METRICS ausente → 200 accepted:0 (el cliente no debe reintentar por config server-side)", async () => {
    const res = await postMetrics({ v: 1, install: INSTALL, events: [{ e: "ping" }] }, {});
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, accepted: 0 });
  });

  it("sin auth ni attest: 200 sin Authorization (paridad /config)", async () => {
    const ds = makeDataset();
    const res = await postMetrics({ v: 1, install: INSTALL, events: [{ e: "ping" }] }, { METRICS: ds });
    expect(res.status).toBe(200);
  });
});

describe("POST /metrics — rechazos 400 (yala_bad_input, y JAMÁS se escribe)", () => {
  it("tabla de bodies inválidos", async () => {
    const ds = makeDataset();
    const cases: unknown[] = [
      "not-json{",
      { v: 2, install: INSTALL, events: [{ e: "ping" }] }, // versión desconocida
      { v: 1, events: [{ e: "ping" }] }, // sin install
      { v: 1, install: "ZZZZ", events: [{ e: "ping" }] }, // install no-hex
      { v: 1, install: "abc123", events: [{ e: "ping" }] }, // install corto (<16)
      { v: 1, install: INSTALL, events: [] }, // events vacío
      { v: 1, install: INSTALL, events: [{ e: "purchase" }] }, // evento fuera de whitelist
      { v: 1, install: INSTALL, events: [{ e: "canary", n: "bad name!" }] }, // n fuera de regex
      { v: 1, install: INSTALL, events: [{ e: "canary", n: "a".repeat(65) }] }, // n >64
      { v: 1, install: INSTALL, events: [{ e: "canary", n: "ok", d: "a".repeat(129) }] }, // d >128
      { v: 1, install: INSTALL, events: [{ e: "canary", n: "ok", x: Number.NaN }] }, // x no finito
      { v: 1, install: INSTALL, app: "a".repeat(33), events: [{ e: "ping" }] }, // app >32
      { v: 1, install: INSTALL, events: Array.from({ length: 26 }, () => ({ e: "ping" })) }, // cap 25
    ];
    for (const body of cases) {
      const res = await postMetrics(body, { METRICS: ds });
      expect(res.status, JSON.stringify(body).slice(0, 80)).toBe(400);
    }
    expect(ds.writeDataPoint).not.toHaveBeenCalled();
  });

  it("body demasiado grande → 400", () => {
    const big = JSON.stringify({ v: 1, install: INSTALL, events: [{ e: "canary", n: "x", d: "y".repeat(120) }] });
    const padded = big + " ".repeat(9000);
    expect(parseMetricsBody(padded)).toBe("body too large");
  });

  it("parseMetricsBody acepta el caso válido mínimo y el máximo del cap", () => {
    const min = JSON.stringify({ v: 1, install: INSTALL, events: [{ e: "ping" }] });
    expect(typeof parseMetricsBody(min)).toBe("object");
    const max = JSON.stringify({
      v: 1,
      install: "f".repeat(64),
      events: Array.from({ length: 25 }, () => ({ e: "ping" })),
    });
    expect(typeof parseMetricsBody(max)).toBe("object");
  });
});
