import { describe, expect, it } from "vitest";
import type { Breadcrumb, ErrorEvent } from "@sentry/cloudflare";
import { scrubBreadcrumb, scrubEvent, scrubText, sentryOptions } from "../src/sentry";
import type { Env } from "../src/env";
import app from "../src/index";

describe("sentryOptions", () => {
  it("sin DSN no arranca el SDK", () => {
    expect(sentryOptions({} as Env)).toBeUndefined();
    expect(sentryOptions({ SENTRY_DSN: "  " } as Env)).toBeUndefined();
  });

  it("con DSN: sin PII por defecto, sin trazas y con los dos filtros", () => {
    const opts = sentryOptions({ SENTRY_DSN: "https://k@o1.ingest.sentry.io/1", ENVIRONMENT: "staging" } as Env);
    expect(opts?.dataCollection).toMatchObject({
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
      stackFrameVariables: false,
    });
    expect(opts?.tracesSampleRate).toBe(0);
    expect(opts?.environment).toBe("staging");
    expect(opts?.beforeSend).toBe(scrubEvent);
    expect(opts?.beforeBreadcrumb).toBe(scrubBreadcrumb);
  });
});

describe("scrubText", () => {
  it("tapa correos, importes y tokens", () => {
    const out = scrubText(
      "ana.perez@gmail.com pagó S/ 123.45, $9 y 1,234.50 USD 20; Bearer abc.def eyJhbGciOi.eyJzdWIi.sig sk-proj-abcdefgh123",
    );
    expect(out).not.toMatch(/ana\.perez|gmail|123\.45|\$9|1,234\.50|USD 20|abc\.def|eyJ|sk-proj/);
    expect(out).toContain("[email]");
    expect(out).toContain("[monto]");
    expect(out).toContain("[token]");
  });

  it("deja lo que no es dato del usuario", () => {
    expect(scrubText("D1_ERROR: no such table groups (status 500)")).toBe("D1_ERROR: no such table groups (status 500)");
  });
});

describe("scrubEvent", () => {
  it("del request solo quedan método y ruta; fuera usuario, extra y variables locales", () => {
    const event = {
      type: undefined,
      request: {
        method: "POST",
        url: "https://gw.example/sync/push?from=2026-01-01&currency=PEN",
        data: '{"amount": 120.5, "note": "cena con Ana"}',
        query_string: "from=2026-01-01",
        headers: { authorization: "Bearer eyJx.eyJy.z", cookie: "s=1" },
        cookies: { s: "1" },
      },
      user: { email: "ana@example.com", ip_address: "1.2.3.4" },
      extra: { body: { amount: 120.5 } },
      server_name: "host",
      sdk: { name: "sentry.javascript.cloudflare", version: "11" },
      exception: {
        values: [
          {
            type: "Error",
            value: "fallo con ana@example.com por S/ 99.90",
            stacktrace: { frames: [{ filename: "a.js", vars: { body: { amount: 120.5 } } }] },
          },
        ],
      },
      breadcrumbs: [
        { category: "fetch", data: { method: "POST", url: "https://api.openai.com/v1/chat?key=x", status_code: 200, body: "x" } },
        { category: "console", message: "usuario ana@example.com", data: { arguments: [{ amount: 5 }] } },
      ],
    } as unknown as ErrorEvent;

    const out = scrubEvent(event);
    const json = JSON.stringify(out);
    expect(out.request).toEqual({ method: "POST", url: "https://gw.example/sync/push" });
    expect(out.user).toBeUndefined();
    expect(out.extra).toBeUndefined();
    expect(out.sdk?.settings?.infer_ip).toBe("never");
    expect(json).not.toMatch(/ana@|120\.5|99\.90|cena|authorization|cookie|key=x|arguments/);
    expect(out.breadcrumbs?.[0]?.data).toEqual({ method: "POST", url: "https://api.openai.com/v1/chat", status_code: 200 });
  });
});

describe("scrubBreadcrumb", () => {
  it("un breadcrumb HTTP pierde payload y query", () => {
    const crumb: Breadcrumb = { type: "http", data: { method: "GET", url: "/rates/live?base=PEN", request_body_size: 3 } };
    expect(scrubBreadcrumb(crumb)?.data).toEqual({ method: "GET", url: "/rates/live", status_code: undefined });
  });
});

describe("POST /v1/debug/sentry", () => {
  const env = { ENVIRONMENT: "staging", DEV_SHARED_SECRET: "s" } as unknown as Env;

  it("en producción no existe", async () => {
    const res = await app.request("/v1/debug/sentry", { method: "POST" }, { ...env, ENVIRONMENT: "production" });
    expect(res.status).toBe(404);
  });

  it("sin el secreto de dev, 401", async () => {
    const res = await app.request("/v1/debug/sentry", { method: "POST" }, env);
    expect(res.status).toBe(401);
  });

  it("con el secreto lanza y el gateway responde el 500 de siempre", async () => {
    const res = await app.request(
      "/v1/debug/sentry",
      { method: "POST", headers: { "X-Yala-Dev-Secret": "s" } },
      env,
    );
    expect(res.status).toBe(500);
  });
});
