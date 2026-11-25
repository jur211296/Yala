/**
 * `/account/entitlement` con D1 saturada (2026-11-25, YALA-GATEWAY-3 y -4; YALA-GATEWAY-2 fue `/mail/drafts` en la
 * misma traza). D1 real (SQLite) con el error de producción inyectado.
 *
 * Lo que fija:
 *  - **Un instante de saturación ya no llega al usuario**: el bind y el GET se reintentan y responden 200.
 *  - **La vinculación queda UNA vez**: tras el reintento hay una sola fila para la suscripción y un solo batch
 *    ejecutado.
 *  - **Cada intento vuelve a leer**: si el webhook revoca la suscripción entre dos intentos, el siguiente no la
 *    resucita. Reintentar solo la escritura reusaría una decisión tomada sobre datos viejos.
 *  - **Con tope y salida clara**: D1 saturada siempre ⇒ 3 intentos y 503 `yala_unavailable` con `Retry-After`, sin
 *    escribir nada. Cualquier otro error sigue en 500 y sin reintento.
 */
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../../src/env";
import { errorSaturada, makeD1Saturable, type D1Saturable } from "./fakeD1Saturable";

const SUB = "11111111-2222-3333-4444-555555555555";
const OTHER_SUB = "99999999-8888-7777-6666-555555555555";
const VALID = "valid-user-jwt";
const FUTURE = Date.now() + 30 * 24 * 3600 * 1000;
const TXN = "2000000111";

vi.mock("../../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

const verifyStoreKitJWSMock = vi.fn();
vi.mock("../../src/storekit/verifyStoreKitJWS", () => ({
  verifyStoreKitJWS: (...args: unknown[]) => verifyStoreKitJWSMock(...args),
}));

const { default: app } = await import("../../src/index");

const AUTH = { authorization: `Bearer ${VALID}` };

function makeEnv(d1: D1Saturable, environment = "staging"): Env {
  return {
    ENVIRONMENT: environment,
    ENFORCE: "observe",
    SUPABASE_URL: "https://d1-overloaded.local",
    SUPABASE_ANON_KEY: "anon",
    DB: d1.db,
  } as unknown as Env;
}

function entitlement(overrides: Record<string, unknown> = {}) {
  return {
    productId: "com.yala.pro.yearly",
    expiresAtMs: FUTURE,
    originalTransactionId: TXN,
    appAccountToken: null,
    environment: "Production",
    ...overrides,
  };
}

async function bind(env: Env): Promise<Response> {
  return app.fetch(
    new Request("https://gw.local/account/entitlement", {
      method: "POST",
      headers: { "content-type": "application/json", ...AUTH },
      body: JSON.stringify({ storekit_jws: "jws" }),
    }),
    env,
  );
}

async function get(env: Env): Promise<Response> {
  return app.fetch(new Request("https://gw.local/account/entitlement", { method: "GET", headers: AUTH }), env);
}

function filasDeLaSuscripcion(d1: D1Saturable) {
  return d1.sqlite.prepare("SELECT * FROM account_entitlements WHERE original_transaction_id = ?").all(TXN) as {
    user_id: string;
    entitlement_expires_at: number;
  }[];
}

/** Falla las `n` primeras llamadas que cumplan `filtro` con el error de producción. */
function fallarPrimeras(n: number, filtro: (op: string, sql: string) => boolean = () => true) {
  let restantes = n;
  return (op: string, sql: string) => {
    if (restantes > 0 && filtro(op, sql)) {
      restantes--;
      return errorSaturada();
    }
    return null;
  };
}

beforeEach(() => {
  verifyStoreKitJWSMock.mockReset();
});

describe("POST /account/entitlement con D1 saturada", () => {
  it("un batch saturado se reintenta: 200 Pro, una sola fila y un solo batch ejecutado", async () => {
    const d1 = makeD1Saturable();
    verifyStoreKitJWSMock.mockResolvedValue(entitlement());
    d1.inyectar(fallarPrimeras(1, (op) => op === "batch"));

    const res = await bind(makeEnv(d1));
    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ pro: true, product: "com.yala.pro.yearly", expires_at_ms: FUTURE });

    const filas = filasDeLaSuscripcion(d1);
    expect(filas).toHaveLength(1);
    expect(filas[0].user_id).toBe(SUB);
    expect(d1.batchesEjecutados()).toBe(1);
    expect(d1.llamadas.filter((l) => l.op === "batch")).toHaveLength(2); // uno fallido + uno bueno
  });

  it("la lectura inicial saturada también se reintenta y la vinculación queda una vez", async () => {
    const d1 = makeD1Saturable();
    verifyStoreKitJWSMock.mockResolvedValue(entitlement());
    d1.inyectar(fallarPrimeras(2, (op) => op === "first"));

    const res = await bind(makeEnv(d1));
    expect(res.status).toBe(200);
    expect(((await res.json()) as { pro: boolean }).pro).toBe(true);
    expect(filasDeLaSuscripcion(d1)).toHaveLength(1);
    expect(d1.batchesEjecutados()).toBe(1);
  });

  it("repetir el bind entero (el reintento del cliente) no duplica nada", async () => {
    const d1 = makeD1Saturable();
    verifyStoreKitJWSMock.mockResolvedValue(entitlement());
    const env = makeEnv(d1);
    expect((await bind(env)).status).toBe(200);
    expect((await bind(env)).status).toBe(200);
    expect(filasDeLaSuscripcion(d1)).toHaveLength(1);
  });

  it("cada intento vuelve a leer: una revocación entre intentos NO se resucita", async () => {
    const d1 = makeD1Saturable();
    // Otra cuenta tenía la suscripción viva; el bind por JWT (sin appAccountToken) la reclamaría («última gana»).
    d1.sqlite
      .prepare(
        "INSERT INTO account_entitlements (user_id, entitlement_product, entitlement_expires_at, original_transaction_id, bound_via, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      )
      .run(OTHER_SUB, "com.yala.pro.yearly", FUTURE, TXN, "jwt", 1, 1);
    verifyStoreKitJWSMock.mockResolvedValue(entitlement());

    let primerBatch = true;
    d1.inyectar((op) => {
      if (op === "batch" && primerBatch) {
        primerBatch = false;
        // Mientras el primer intento esperaba en la cola, el webhook de Apple revocó la suscripción (reembolso).
        d1.sqlite.prepare("UPDATE account_entitlements SET entitlement_expires_at = 0 WHERE original_transaction_id = ?").run(TXN);
        return errorSaturada();
      }
      return null;
    });

    const res = await bind(makeEnv(d1));
    expect(res.status).toBe(200);
    expect(((await res.json()) as { pro: boolean }).pro).toBe(false);
    const filas = filasDeLaSuscripcion(d1);
    expect(filas).toHaveLength(1);
    expect(filas[0]).toMatchObject({ user_id: OTHER_SUB, entitlement_expires_at: 0 });
    expect(d1.batchesEjecutados()).toBe(0);
  });

  it("tiene tope: D1 saturada siempre ⇒ 3 intentos, 503 con Retry-After y nada escrito", async () => {
    const d1 = makeD1Saturable();
    verifyStoreKitJWSMock.mockResolvedValue(entitlement());
    d1.inyectar((op) => (op === "batch" ? errorSaturada() : null));

    const res = await bind(makeEnv(d1));
    expect(res.status).toBe(503);
    expect(res.headers.get("retry-after")).toBe("2");
    expect(((await res.json()) as { error: { type: string } }).error.type).toBe("yala_unavailable");
    expect(d1.llamadas.filter((l) => l.op === "batch")).toHaveLength(3);
    expect(filasDeLaSuscripcion(d1)).toHaveLength(0);
  });

  it("el caso exacto de producción: compra sandbox en producción con la lectura saturada una vez ⇒ 200 sin Pro", async () => {
    const d1 = makeD1Saturable();
    verifyStoreKitJWSMock.mockResolvedValue(entitlement({ environment: "Sandbox" }));
    d1.inyectar(fallarPrimeras(1, (op) => op === "first"));

    const res = await bind(makeEnv(d1, "production"));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ pro: false, product: null, expires_at_ms: null });
    expect(d1.batchesEjecutados()).toBe(0);
  });

  it("un error de D1 que no es saturación no se reintenta y sigue en 500", async () => {
    const d1 = makeD1Saturable();
    verifyStoreKitJWSMock.mockResolvedValue(entitlement());
    d1.inyectar((op) => (op === "batch" ? new Error("D1_ERROR: no such table: account_entitlements") : null));

    const res = await bind(makeEnv(d1));
    expect(res.status).toBe(500);
    expect(res.headers.get("retry-after")).toBeNull();
    expect(d1.llamadas.filter((l) => l.op === "batch")).toHaveLength(1);
  });
});

describe("GET /account/entitlement con D1 saturada", () => {
  it("una lectura saturada se reintenta y responde 200", async () => {
    const d1 = makeD1Saturable();
    d1.inyectar(fallarPrimeras(1));
    const res = await get(makeEnv(d1));
    expect(res.status).toBe(200);
    expect(d1.llamadas.filter((l) => l.op === "first")).toHaveLength(2);
  });

  it("saturada siempre ⇒ 503 con Retry-After tras 3 lecturas", async () => {
    const d1 = makeD1Saturable();
    d1.inyectar(() => errorSaturada());
    const res = await get(makeEnv(d1));
    expect(res.status).toBe(503);
    expect(res.headers.get("retry-after")).toBe("2");
    expect(d1.llamadas).toHaveLength(3);
  });
});
