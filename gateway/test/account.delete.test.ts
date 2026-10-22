/**
 * Unit OFFLINE de `handleAccountDelete` (`POST /account/delete`, G5-D1) — 100% sin red, corre en CI como
 * apns.sign / policy / attest. Se mockea `verifyUserToken` (evita el JWKS remoto de jose) y se stubbea
 * `fetch` para el RPC de PostgREST; `callRpc` (el passthrough real) queda intacto.
 *
 * Cubre los guards de `requireUserAndAttest` (la ASIMETRÍA con el resto de `/account/*`: esta ruta SÍ
 * exige App Attest bajo ENFORCE=enforce) y el passthrough del RPC `delete_personal_account` (happy →
 * counts jsonb; upstream 500 → 502; error yala_* del RPC → 400 con el código preservado). La verificación
 * WIRE end-to-end (filas realmente borradas + exists=false) es one-shot vía MCP contra staging — ver
 * qa/cloud/README y el comentario de exclusión en account.goldens.test.ts.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta

// Mock parcial de userauth: verifyUserToken reconoce SOLO el token sentinela; callRpc/getRows/bearerToken
// quedan REALES (callRpc usa el fetch stubbeado abajo). El handler importa ambos de este módulo.
vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) =>
      token === VALID ? { sub: SUB, token } : null,
    ),
  };
});

// Import DESPUÉS del vi.mock para que app/handler tomen el módulo mockeado.
const { default: app } = await import("../src/index");

const SUPA = "https://delete-unit.local";

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: SUPA,
    SUPABASE_ANON_KEY: "anon-key-unit",
    ...overrides,
  } as unknown as Env;
}

/** Stub de fetch: solo el RPC de PostgREST (verifyUserToken está mockeado → no hay fetch de JWKS). */
function stubFetch(rpc: { status: number; body: unknown }): { rpcCalls: number } {
  const state = { rpcCalls: 0 };
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown) => {
      const url = typeof input === "string" ? input : (input as Request).url ?? String(input);
      if (url.includes("/rest/v1/rpc/delete_personal_account")) {
        state.rpcCalls += 1;
        return new Response(JSON.stringify(rpc.body), {
          status: rpc.status,
          headers: { "content-type": "application/json" },
        });
      }
      throw new Error(`unexpected fetch: ${url}`);
    }),
  );
  return state;
}

async function del(env: Env, headers: Record<string, string> = {}): Promise<Response> {
  return await app.fetch(
    new Request("https://gw.local/account/delete", { method: "POST", headers }),
    env,
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("handleAccountDelete — guards de auth (offline)", () => {
  it("GET /account/delete → 404 (solo POST está cableado)", async () => {
    const res = await app.fetch(new Request("https://gw.local/account/delete", { method: "GET" }), makeEnv());
    expect(res.status).toBe(404);
  });

  it("sin Authorization → 401 yala_attest_required (jamás toca el RPC)", async () => {
    const state = stubFetch({ status: 200, body: {} });
    const res = await del(makeEnv());
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_attest_required");
    expect(state.rpcCalls).toBe(0);
  });

  it("JWT inválido → 401 yala_attest_invalid (jamás toca el RPC)", async () => {
    const state = stubFetch({ status: 200, body: {} });
    const res = await del(makeEnv(), { Authorization: "Bearer not-the-sentinel" });
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_attest_invalid");
    expect(state.rpcCalls).toBe(0);
  });

  it("ENFORCE=enforce sin sesión de attest → 401 yala_attest_required (attest OBLIGATORIO — asimetría G5-D1)", async () => {
    const state = stubFetch({ status: 200, body: {} });
    const res = await del(makeEnv({ ENFORCE: "enforce" }), { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_attest_required");
    expect(state.rpcCalls).toBe(0); // el attest corta ANTES del RPC destructivo
  });
});

describe("handleAccountDelete — passthrough del RPC (offline)", () => {
  const counts = { accounts: 3, budgets: 1, tx_items: 42, subcategories: 0, profiles: 1 };

  it("happy (ENFORCE=observe, sin attest) → 200 con los counts del RPC tal cual", async () => {
    const state = stubFetch({ status: 200, body: counts });
    const res = await del(makeEnv(), { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual(counts);
    expect(state.rpcCalls).toBe(1);
  });

  it("RPC upstream 500 → 502 yala_unavailable", async () => {
    stubFetch({ status: 500, body: { message: "boom" } });
    const res = await del(makeEnv(), { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(502);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_unavailable");
  });

  it("error yala_* del RPC (P0001) → 400 con el código preservado", async () => {
    // El guard auth.uid() del RPC lanza yala_not_authorized; PostgREST lo devuelve como { message }.
    stubFetch({ status: 400, body: { code: "P0001", message: "yala_not_authorized" } });
    const res = await del(makeEnv(), { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(400);
    const err = (await res.json()) as { error: { type: string; code: string } };
    expect(err.error.type).toBe("yala_rpc_error");
    expect(err.error.code).toBe("yala_not_authorized");
  });
});

// ------------------------------------------------------------------------------------------------------
// Qué queda en Cloudflare tras «Eliminar mi cuenta» (card `tablero-al-eliminar-una-cuenta-no-se-borran-la-c-3sge`).
//
// Lo LIGADO A LA CUENTA se borra: el derecho Pro (`account_entitlements`, D1) y el contador de uso de la cuenta (Durable
// Object `sub:<sub>`, el que usa `requireUser` en producción). Lo del DISPOSITIVO se queda, a propósito: la fila de
// `attest_keys` de D1 (por keyId, sin columna de cuenta) y su contador, que guarda el cupo de prueba de la IA. La
// política lo dice en «Cuánto tiempo guardamos tus datos».
// ------------------------------------------------------------------------------------------------------

describe("handleAccountDelete — lo que queda en Cloudflare (offline)", () => {
  const DEVICE_KEY = "device-key-id-base64";

  /** D1 de mentira: apunta cada sentencia con sus parámetros. */
  function fakeDB() {
    const statements: { sql: string; params: unknown[] }[] = [];
    const db = {
      prepare(sql: string) {
        const entry = { sql, params: [] as unknown[] };
        const stmt = {
          bind(...params: unknown[]) {
            entry.params = params;
            return stmt;
          },
          async run() {
            statements.push(entry);
            return { success: true };
          },
          async first() {
            statements.push(entry);
            return null;
          },
        };
        return stmt;
      },
      async batch(stmts: { run: () => Promise<unknown> }[]) {
        for (const s of stmts) await s.run();
        return [];
      },
    };
    return { db, statements };
  }

  /** Durable Object de mentira: apunta a qué cubo se le pidió qué. */
  function fakeLimiter() {
    const calls: { bucket: string; op: string }[] = [];
    const ns = {
      idFromName: (name: string) => name,
      get: (bucket: string) => ({
        fetch: async (_url: string, init?: RequestInit) => {
          const body = JSON.parse(String(init?.body ?? "{}")) as { op?: string };
          calls.push({ bucket, op: body.op ?? "check" });
          return body.op === "forget" || body.op === "refund"
            ? Response.json({ ok: true })
            : Response.json({ allowed: true, reason: null });
        },
      }),
    };
    return { ns, calls };
  }

  async function attestHeader(env: Env): Promise<string> {
    const { issueSessionToken } = await import("../src/attest/session");
    const { token } = await issueSessionToken(env, { keyId: DEVICE_KEY, tier: "free" });
    return token;
  }

  function envWith(db: unknown, limiter: unknown, enforce = "enforce"): Env {
    return makeEnv({
      ENFORCE: enforce,
      JWT_SIGNING_SECRET: "jwt-secret-unit-delete",
      DB: db as Env["DB"],
      RATE_LIMITER: limiter as Env["RATE_LIMITER"],
    });
  }

  it("borrado con éxito → se olvida el contador de la CUENTA (sub:<sub>) y se borra su derecho Pro", async () => {
    stubFetch({ status: 200, body: { profiles: 1 } });
    const { db, statements } = fakeDB();
    const { ns, calls } = fakeLimiter();
    const env = envWith(db, ns);
    const res = await del(env, { Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": await attestHeader(env) });
    expect(res.status).toBe(200);

    expect(calls).toContainEqual({ bucket: `sub:${SUB}`, op: "forget" });
    const entitlementDelete = statements.find((s) => /DELETE FROM account_entitlements/.test(s.sql));
    expect(entitlementDelete?.params).toEqual([SUB]);
  });

  it("el cubo que se olvida es EL MISMO que cuentan las rutas de cuenta (requireUser)", async () => {
    // Si alguien cambia el nombre del cubo en un lado y no en el otro, el borrado olvidaría un contador que no existe.
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify([]), { status: 200, headers: { "content-type": "application/json" } })),
    );
    const { ns, calls } = fakeLimiter();
    const env = envWith(fakeDB().db, ns);
    const res = await app.fetch(
      new Request("https://gw.local/account/exists", { method: "GET", headers: { Authorization: `Bearer ${VALID}` } }),
      env,
    );
    expect(res.status).toBe(200);
    expect(calls).toContainEqual({ bucket: `sub:${SUB}`, op: "check" });
  });

  it("lo del DISPOSITIVO se conserva: ninguna sentencia toca attest_keys y su contador (keyId) no se olvida", async () => {
    stubFetch({ status: 200, body: { profiles: 1 } });
    const { db, statements } = fakeDB();
    const { ns, calls } = fakeLimiter();
    const env = envWith(db, ns);
    const res = await del(env, { Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": await attestHeader(env) });
    expect(res.status).toBe(200);

    // El request llegó atestado: el rate-limit del propio borrado cuenta en el cubo del dispositivo…
    expect(calls).toContainEqual({ bucket: DEVICE_KEY, op: "check" });
    // …y ese cubo NO se olvida: guarda el cupo de prueba de la IA, que no se repone nunca.
    expect(calls.filter((c) => c.op === "forget").map((c) => c.bucket)).toEqual([`sub:${SUB}`]);
    expect(statements.some((s) => /attest_keys/i.test(s.sql))).toBe(false);
  });

  it("si el RPC falla, no se olvida nada (el derecho y el contador siguen con la cuenta viva)", async () => {
    stubFetch({ status: 500, body: { message: "boom" } });
    const { db, statements } = fakeDB();
    const { ns, calls } = fakeLimiter();
    const env = envWith(db, ns);
    const res = await del(env, { Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": await attestHeader(env) });
    expect(res.status).toBe(502);
    expect(calls.some((c) => c.op === "forget")).toBe(false);
    expect(statements.length).toBe(0);
  });

  it("un fallo al olvidar el contador no tumba la respuesta: la cuenta ya está borrada", async () => {
    stubFetch({ status: 200, body: { profiles: 1 } });
    const { db } = fakeDB();
    const broken = {
      idFromName: (name: string) => name,
      get: () => ({
        fetch: async (_url: string, init?: RequestInit) => {
          const body = JSON.parse(String(init?.body ?? "{}")) as { op?: string };
          if (body.op === "forget") throw new Error("DO caído");
          return Response.json({ allowed: true, reason: null });
        },
      }),
    };
    const env = envWith(db, broken);
    const res = await del(env, { Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": await attestHeader(env) });
    expect(res.status).toBe(200);
  });
});

describe("RateLimiter — op forget", () => {
  it("borra todo el estado del Durable Object", async () => {
    const { RateLimiter } = await import("../src/rate_limiter");
    const store = new Map<string, unknown>([["s", { day: "2026-10-15", counts: { sync: 3 }, burst: [1], trial: { voice: 2 } }]]);
    const state = {
      storage: {
        get: async (k: string) => store.get(k),
        put: async (k: string, v: unknown) => void store.set(k, v),
        deleteAll: async () => store.clear(),
      },
    } as unknown as DurableObjectState;
    const limiter = new RateLimiter(state, {} as Env);
    const res = await limiter.fetch(new Request("https://ratelimiter/forget", { method: "POST", body: JSON.stringify({ op: "forget" }) }));
    expect(res.status).toBe(200);
    expect(store.size).toBe(0);
  });
});
