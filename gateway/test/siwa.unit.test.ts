/**
 * Units OFFLINE de `/account/siwa/exchange` + `/account/siwa/revoke` (B1, revoke 5.1.1(v)) — 100% sin
 * red, corren en CI (molde account.delete.test.ts + push.fanout.unit.test.ts): `verifyUserToken`
 * mockeado (evita el JWKS remoto de jose) y `fetch` stubbeado para appleid.apple.com.
 *
 * NO hay golden WIRE contra Apple real: un authorization_code real solo existe en un device tras un
 * sign-in interactivo (paridad con el patrón APNs — los endpoints se cubren offline).
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { decodeJwt, decodeProtectedHeader, exportPKCS8, generateKeyPair } from "jose";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta

// Mock parcial de userauth: verifyUserToken reconoce SOLO el token sentinela; el resto queda REAL.
vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) =>
      token === VALID ? { sub: SUB, token } : null,
    ),
  };
});

// Import DESPUÉS del vi.mock para que app/handlers tomen el módulo mockeado.
const { default: app } = await import("../src/index");

const TEAM = "3WKFFVD66J";
const BUNDLE = "com.jurgenschmidt.yala.dev";
const KEY_ID = "SIWATESTK1";
const CODE = "c_valid_authorization_code_0123456789";
const REFRESH = "r_valid_refresh_token_0123456789";

async function makePem(): Promise<string> {
  const { privateKey } = await generateKeyPair("ES256", { extractable: true });
  return exportPKCS8(privateKey);
}

/** Env staging mínimo. Sin RATE_LIMITER (el gate se omite); ENFORCE observe (attest opcional en revoke). */
function makeEnv(pem: string | undefined, overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    APPLE_TEAM_ID: TEAM,
    APPLE_BUNDLE_IDS: BUNDLE,
    SIWA_KEY_ID: pem ? KEY_ID : undefined,
    SIWA_AUTH_KEY: pem,
    ...overrides,
  } as unknown as Env;
}

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

function post(path: string, body: unknown, env: Env, headers: Record<string, string> = {}) {
  return app.request(
    path,
    {
      method: "POST",
      headers: { "content-type": "application/json", Authorization: `Bearer ${VALID}`, ...headers },
      body: JSON.stringify(body),
    },
    env,
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("/account/siwa/exchange — units offline", () => {
  it("happy path: form EXACTO hacia Apple (SIN redirect_uri) + client_secret ES256 correcto + respuesta minimizada", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url === "https://appleid.apple.com/auth/token") {
        return new Response(
          JSON.stringify({
            access_token: "apple-access", // NO debe reenviarse
            refresh_token: "apple-refresh-token",
            id_token: "apple-id-token", // NO debe reenviarse
          }),
          { status: 200, headers: { "content-type": "application/json" } },
        );
      }
      throw new Error(`unexpected fetch: ${url}`);
    }, calls);

    const res = await post("/account/siwa/exchange", { authorization_code: CODE }, makeEnv(pem));
    expect(res.status).toBe(200);
    // Minimización: SOLO refresh_token (jamás id_token/access_token de Apple).
    expect(await res.json()).toEqual({ refresh_token: "apple-refresh-token" });

    expect(calls.length).toBe(1);
    const form = new URLSearchParams(calls[0].init?.body as string);
    expect(form.get("grant_type")).toBe("authorization_code");
    expect(form.get("code")).toBe(CODE);
    expect(form.get("client_id")).toBe(BUNDLE);
    expect(form.has("redirect_uri")).toBe(false); // AJUSTE #3: flujo nativo — se OMITE
    expect((calls[0].init?.headers as Record<string, string>)["content-type"]).toBe(
      "application/x-www-form-urlencoded",
    );

    // El client_secret es un JWT ES256 firmado con la .p8: kid/iss/sub/aud según la doc de Apple.
    const secret = form.get("client_secret")!;
    const header = decodeProtectedHeader(secret);
    expect(header.alg).toBe("ES256");
    expect(header.kid).toBe(KEY_ID);
    const claims = decodeJwt(secret);
    expect(claims.iss).toBe(TEAM);
    expect(claims.sub).toBe(BUNDLE);
    expect(claims.aud).toBe("https://appleid.apple.com");
    expect(typeof claims.exp).toBe("number");
    // exp corto (5 min por request, sin cache) — margen de reloj de ±60s.
    expect((claims.exp! - claims.iat!)).toBeLessThanOrEqual(6 * 60);
  });

  it("503 yala_siwa_not_configured sin SIWA_AUTH_KEY (cero fetches a Apple)", async () => {
    const calls: Recorded[] = [];
    stubFetch(() => new Response("{}", { status: 200 }), calls);
    const res = await post("/account/siwa/exchange", { authorization_code: CODE }, makeEnv(undefined));
    expect(res.status).toBe(503);
    const body = (await res.json()) as { error: { type: string } };
    expect(body.error.type).toBe("yala_siwa_not_configured");
    expect(calls.length).toBe(0);
  });

  it("401 sin JWT (Authorization ausente corta antes de cualquier fetch)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => new Response("{}", { status: 200 }), calls);
    const res = await app.request(
      "/account/siwa/exchange",
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ authorization_code: CODE }) },
      makeEnv(pem),
    );
    expect(res.status).toBe(401);
    expect(calls.length).toBe(0);
  });

  it("400 yala_bad_input con shape inválido (corto / charset fuera de [A-Za-z0-9._-])", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => new Response("{}", { status: 200 }), calls);
    for (const bad of ["corto", "tiene espacios y $imbolos!", 42, null, "x".repeat(3000)]) {
      const res = await post("/account/siwa/exchange", { authorization_code: bad }, makeEnv(pem));
      expect(res.status).toBe(400);
      const body = (await res.json()) as { error: { type: string } };
      expect(body.error.type).toBe("yala_bad_input");
    }
    expect(calls.length).toBe(0); // jamás llegó a Apple
  });

  it("error de Apple → 502 SIN leak del body de Apple (puede portar tokens)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(
      () => new Response(JSON.stringify({ error: "invalid_grant", secret_leak: "apple-body" }), { status: 400 }),
      calls,
    );
    const res = await post("/account/siwa/exchange", { authorization_code: CODE }, makeEnv(pem));
    expect(res.status).toBe(502);
    const text = await res.text();
    expect(text).not.toContain("invalid_grant");
    expect(text).not.toContain("apple-body");
    expect(text).not.toContain(CODE); // ni el code entero de vuelta
  });
});

describe("/account/siwa/revoke — units offline", () => {
  it("happy path: form con token_type_hint=refresh_token → { revoked: true }", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch((url) => {
      if (url === "https://appleid.apple.com/auth/revoke") return new Response("", { status: 200 });
      throw new Error(`unexpected fetch: ${url}`);
    }, calls);

    const res = await post("/account/siwa/revoke", { refresh_token: REFRESH }, makeEnv(pem));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ revoked: true });

    expect(calls.length).toBe(1);
    const form = new URLSearchParams(calls[0].init?.body as string);
    expect(form.get("token")).toBe(REFRESH);
    expect(form.get("token_type_hint")).toBe("refresh_token");
    expect(form.get("client_id")).toBe(BUNDLE);
    expect(form.get("client_secret")).toBeTruthy();
    expect(form.has("redirect_uri")).toBe(false);
  });

  it("503 sin secret · 401 sin JWT · 400 shape (espejo del exchange)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => new Response("", { status: 200 }), calls);

    const noSecret = await post("/account/siwa/revoke", { refresh_token: REFRESH }, makeEnv(undefined));
    expect(noSecret.status).toBe(503);

    const noJwt = await app.request(
      "/account/siwa/revoke",
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ refresh_token: REFRESH }) },
      makeEnv(pem),
    );
    expect(noJwt.status).toBe(401);

    const badShape = await post("/account/siwa/revoke", { refresh_token: "no vale" }, makeEnv(pem));
    expect(badShape.status).toBe(400);
    const body = (await badShape.json()) as { error: { type: string } };
    expect(body.error.type).toBe("yala_bad_input");

    expect(calls.length).toBe(0);
  });

  it("error de Apple → 502 sin leak (el cliente lo trata best-effort)", async () => {
    const pem = await makePem();
    const calls: Recorded[] = [];
    stubFetch(() => new Response(JSON.stringify({ error: "invalid_client" }), { status: 400 }), calls);
    const res = await post("/account/siwa/revoke", { refresh_token: REFRESH }, makeEnv(pem));
    expect(res.status).toBe(502);
    const text = await res.text();
    expect(text).not.toContain("invalid_client");
    expect(text).not.toContain(REFRESH);
  });
});
