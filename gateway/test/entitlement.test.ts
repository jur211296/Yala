/**
 * Unit OFFLINE de `/account/entitlement` (C-8) — el derecho Pro por CUENTA, no por Apple ID.
 * 100% sin red: se mockea `verifyUserToken` (evita el JWKS remoto) y `verifyStoreKitJWS` (evita
 * necesitar un JWS realmente firmado por Apple); `env.DB` es un fake D1 que registra las statements.
 *
 * Lo que pinnea, en orden de gravedad si se rompiera:
 *  - **appAccountToken manda sobre el JWT**: una suscripción que declaró OTRA cuenta jamás se
 *    reasigna (409). Sin esto, cualquiera con una sesión válida podría adoptar una suscripción ajena
 *    con solo poseer su JWS.
 *  - **«Última vinculación gana» borra el vínculo anterior** en el MISMO batch: sin el DELETE
 *    cross-cuenta, dos cuentas quedarían Pro con una sola suscripción (o el UNIQUE haría fallar el
 *    re-vínculo legítimo de quien cambia de cuenta de Yala).
 *  - **Un JWS inválido/expirado no otorga ni destruye nada**: devuelve el estado real de la cuenta.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER_SUB = "99999999-8888-7777-6666-555555555555";
const VALID = "valid-user-jwt";
const FUTURE = Date.now() + 30 * 24 * 3600 * 1000;

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

/** El JWS es opaco para el handler: el mock decide qué entitlement "trae firmado". */
const verifyStoreKitJWSMock = vi.fn();
vi.mock("../src/storekit/verifyStoreKitJWS", () => ({
  verifyStoreKitJWS: (...args: unknown[]) => verifyStoreKitJWSMock(...args),
}));

const { default: app } = await import("../src/index");

// --------------------------------------------------------------------------------- fake D1

interface Statement {
  sql: string;
  params: unknown[];
}

/** D1 mínimo: guarda las statements emitidas y devuelve la fila configurada en los SELECT. */
function makeDB(row: Record<string, unknown> | null): { statements: Statement[]; batches: Statement[][]; db: unknown } {
  const statements: Statement[] = [];
  const batches: Statement[][] = [];
  const prepare = (sql: string) => {
    const stmt: Statement = { sql, params: [] };
    const bound = {
      __stmt: stmt,
      bind: (...params: unknown[]) => {
        stmt.params = params;
        return bound;
      },
      first: async () => {
        statements.push(stmt);
        return row;
      },
      run: async () => {
        statements.push(stmt);
        return { success: true };
      },
    };
    return bound;
  };
  const db = {
    prepare,
    batch: async (stmts: { __stmt: Statement }[]) => {
      batches.push(stmts.map((s) => s.__stmt));
      return stmts.map(() => ({ success: true }));
    },
  };
  return { statements, batches, db };
}

function makeEnv(row: Record<string, unknown> | null = null): {
  env: Env;
  statements: Statement[];
  batches: Statement[][];
} {
  const { statements, batches, db } = makeDB(row);
  const env = {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: "https://entitlement-unit.local",
    SUPABASE_ANON_KEY: "anon-key-unit",
    DB: db,
  } as unknown as Env;
  return { env, statements, batches };
}

function boundRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    user_id: SUB,
    entitlement_product: "com.yala.pro.yearly",
    entitlement_expires_at: FUTURE,
    original_transaction_id: "2000000111",
    bound_via: "app_account_token",
    created_at: Date.now(),
    updated_at: Date.now(),
    ...overrides,
  };
}

async function bind(env: Env, body: unknown, headers: Record<string, string> = {}): Promise<Response> {
  return app.fetch(
    new Request("https://gw.local/account/entitlement", {
      method: "POST",
      headers: { "content-type": "application/json", ...headers },
      body: JSON.stringify(body),
    }),
    env,
  );
}

async function get(env: Env, headers: Record<string, string> = {}): Promise<Response> {
  return app.fetch(new Request("https://gw.local/account/entitlement", { method: "GET", headers }), env);
}

beforeEach(() => {
  verifyStoreKitJWSMock.mockReset();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

// ------------------------------------------------------------------------------ guards de auth

describe("/account/entitlement — auth", () => {
  it("POST sin Authorization → 401 y NO escribe nada", async () => {
    const { env, batches } = makeEnv();
    const res = await bind(env, { storekit_jws: "jws" });
    expect(res.status).toBe(401);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_attest_required");
    expect(batches).toHaveLength(0);
  });

  it("POST con JWT inválido → 401 y NO verifica el JWS siquiera", async () => {
    const { env } = makeEnv();
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: "Bearer nope" });
    expect(res.status).toBe(401);
    expect(verifyStoreKitJWSMock).not.toHaveBeenCalled();
  });

  it("GET sin Authorization → 401", async () => {
    const { env } = makeEnv();
    expect((await get(env)).status).toBe(401);
  });
});

// ---------------------------------------------------------------------------------- bind (POST)

describe("POST /account/entitlement — vínculo", () => {
  it("sin storekit_jws → 400 yala_bad_request", async () => {
    const { env, batches } = makeEnv();
    const res = await bind(env, {}, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(400);
    expect(batches).toHaveLength(0);
  });

  it("JWS con appAccountToken propio → vincula como 'app_account_token'", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.yearly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000111",
      appAccountToken: SUB,
      environment: "Production",
    });
    const { env, batches } = makeEnv(boundRow());
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ pro: true, product: "com.yala.pro.yearly", expires_at_ms: FUTURE });

    // «Última gana»: DELETE del vínculo en otra cuenta + upsert, ATÓMICO en un batch.
    expect(batches).toHaveLength(1);
    expect(batches[0]).toHaveLength(2);
    expect(batches[0][0].sql).toContain("DELETE FROM account_entitlements");
    expect(batches[0][0].sql).toContain("user_id != ?");
    expect(batches[0][0].params).toEqual(["2000000111", SUB]);
    expect(batches[0][1].sql).toContain("INSERT INTO account_entitlements");
    expect(batches[0][1].params).toContain("app_account_token");
  });

  it("JWS SIN appAccountToken (compra anterior al fix) → vincula por JWT, marcado 'jwt'", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.monthly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000222",
      appAccountToken: null,
      environment: "Production",
    });
    const { env, batches } = makeEnv(boundRow({ bound_via: "jwt", original_transaction_id: "2000000222" }));
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(batches[0][1].params).toContain("jwt");
  });

  it("JWS con appAccountToken de OTRA cuenta VIVA → 409 y NO escribe", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.yearly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000333",
      appAccountToken: OTHER_SUB,
      environment: "Production",
    });
    // La fila existente es de la otra cuenta: la suscripción tiene dueño vivo.
    const { env, batches } = makeEnv(boundRow({ user_id: OTHER_SUB, original_transaction_id: "2000000333" }));
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(409);
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_entitlement_owner_mismatch");
    expect(batches).toHaveLength(0);
  });

  /// Quien borra su cuenta de Yala y crea otra arrastra un `appAccountToken` que nombra a la cuenta
  /// vieja PARA SIEMPRE (Apple no permite cambiarlo en una suscripción ya comprada). Si el 409
  /// mirara solo el token, ese usuario perdería su Pro sin salida — contra «última gana».
  it("appAccountToken de una cuenta que ya NO tiene la suscripción → vincula igual", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.yearly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000555",
      appAccountToken: OTHER_SUB,
      environment: "Production",
    });
    const { env, batches } = makeEnv(null); // nadie reclamó esa txn
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(batches).toHaveLength(1);
  });

  /// Un JWS es un string que su dueño puede guardar y reenviar. Tras un reembolso, re-bindearlo
  /// resucitaría el derecho hasta la fecha original: Pro gratis a cambio de devolver el dinero.
  it("suscripción YA revocada por el webhook → el bind NO la resucita", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.yearly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000666",
      appAccountToken: SUB,
      environment: "Production",
    });
    const { env, batches } = makeEnv(boundRow({ entitlement_expires_at: 0, original_transaction_id: "2000000666" }));
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(((await res.json()) as { pro: boolean }).pro).toBe(false);
    expect(batches).toHaveLength(0);
  });

  /// TestFlight compra en sandbox GRATIS. Otorgar derecho de CUENTA desde ahí en el Worker de
  /// producción sería Pro permanente y cross-device a cambio de nada; el tester conserva su Pro
  /// local, que es lo que necesita para probar.
  it("JWS de Sandbox en el Worker de producción → no otorga derecho de cuenta", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.yearly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000777",
      appAccountToken: SUB,
      environment: "Sandbox",
    });
    const { env, batches } = makeEnv(null);
    (env as unknown as { ENVIRONMENT: string }).ENVIRONMENT = "production";
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(((await res.json()) as { pro: boolean }).pro).toBe(false);
    expect(batches).toHaveLength(0);
  });

  it("JWS inválido/expirado/revocado (null) → 200 con el estado REAL, sin escribir", async () => {
    verifyStoreKitJWSMock.mockResolvedValue(null);
    const { env, batches } = makeEnv(null);
    const res = await bind(env, { storekit_jws: "jws" }, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ pro: false, product: null, expires_at_ms: null });
    expect(batches).toHaveLength(0);
  });

  it("un user_id inyectado por el body se DESCARTA (el sub sale del JWT)", async () => {
    verifyStoreKitJWSMock.mockResolvedValue({
      productId: "com.yala.pro.yearly",
      expiresAtMs: FUTURE,
      originalTransactionId: "2000000444",
      appAccountToken: null,
      environment: "Production",
    });
    const { env, batches } = makeEnv(boundRow());
    await bind(env, { storekit_jws: "jws", user_id: OTHER_SUB }, { Authorization: `Bearer ${VALID}` });
    expect(batches[0][1].params[0]).toBe(SUB);
    expect(batches[0][1].params).not.toContain(OTHER_SUB);
  });
});

// -------------------------------------------------------------------------------- lectura (GET)

describe("GET /account/entitlement — consulta", () => {
  it("cuenta sin vínculo → pro:false", async () => {
    const { env } = makeEnv(null);
    const res = await get(env, { Authorization: `Bearer ${VALID}` });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ pro: false, product: null, expires_at_ms: null });
  });

  it("vínculo vigente → pro:true con el expiry firmado por Apple (el cliente lo cachea)", async () => {
    const { env } = makeEnv(boundRow());
    const res = await get(env, { Authorization: `Bearer ${VALID}` });
    expect(await res.json()).toEqual({
      pro: true,
      product: "com.yala.pro.yearly",
      expires_at_ms: FUTURE,
    });
  });

  it("vínculo EXPIRADO → pro:false, pero conserva product/expiry (diagnóstico y copy de churn)", async () => {
    const past = Date.now() - 1000;
    const { env } = makeEnv(boundRow({ entitlement_expires_at: past }));
    const res = await get(env, { Authorization: `Bearer ${VALID}` });
    expect(await res.json()).toEqual({
      pro: false,
      product: "com.yala.pro.yearly",
      expires_at_ms: past,
    });
  });

  it("revocado por el webhook (expires_at = 0) → pro:false", async () => {
    const { env } = makeEnv(boundRow({ entitlement_expires_at: 0 }));
    const res = await get(env, { Authorization: `Bearer ${VALID}` });
    expect(((await res.json()) as { pro: boolean }).pro).toBe(false);
  });
});
