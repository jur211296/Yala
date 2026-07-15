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
