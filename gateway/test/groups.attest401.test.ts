/**
 * Los dos 401 de la guard de Grupos, cada uno en su sitio — unit OFFLINE, molde de `groups.killswitch.test.ts`: se
 * mockea `verifyUserToken` (sin JWKS remoto) y se stubbea `fetch` para afirmar que no se toca PostgREST.
 *
 * ## Por qué existe
 *
 * Desde el 2026-09-15 el cliente iOS lee el código de este 401 (`GatewayErrorEnvelope.isAttestRequired`): con
 * `yala_attest_required` la sesión vale y el canal de Grupos reintenta con backoff; con `yala_attest_invalid` pide
 * volver a entrar. Esa lectura solo es cierta mientras las guards emitan cada código en su sitio:
 *
 * - `yala_attest_invalid` ⇔ el JWT de usuario no verifica.
 * - `yala_attest_required` ⇔ el JWT verifica y el token de attest falta o no verifica (bajo `ENFORCE = "enforce"`).
 *   También sale sin cabecera `Authorization`, pero el cliente nunca manda una petición sin JWT.
 *
 * Si una guard devolviera `yala_attest_required` con el JWT caducado, el cliente leería una sesión muerta como un
 * fallo pasajero y reintentaría para siempre sin pedir volver a entrar. `sync/account.ts` ya lo fijaba
 * (`account.delete.test.ts`); las dos guards de Grupos —`groups/routes.ts` y `groups/rpc.ts`— no.
 *
 * ## Qué mutación mata cada caso
 *
 * 1. Cambiar el código del JWT inválido en cualquiera de las dos guards → rojo en sus rutas.
 * 2. Cambiar el del attest ausente, o dejar de exigirlo → rojo en sus rutas.
 * 3. Que un attest que no verifica —malformado o caducado— deje de dar `yala_attest_required` → rojo. El caducado es
 *    el caso real: el token de sesión dura 15 min y el cliente lo reutiliza.
 * 4. Que `code` deje de coincidir con `type` en estos 401 → rojo: el cliente lee `type`.
 *
 * Los casos de attest llevan un CONTROL con un token vigente firmado con el mismo secreto: sin él, un secreto mal
 * puesto haría fallar la verificación de cualquier token, y los casos saldrían verdes por el motivo equivocado.
 *
 * **Nadie lo corre automáticamente**: el CI no ejecuta la suite del gateway (`ci-no-corre-la-suite-del-gateway`). Se
 * corre con `npm test -- test/groups.attest401.test.ts`; el `pretest` copia los manifests.
 */
import { SignJWT } from "jose";
import { afterEach, describe, expect, it, vi } from "vitest";
import { issueSessionToken } from "../src/attest/session";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta
const GID = "grp-unit-0001";
const SIGNING_SECRET = "jwt-signing-secret-unit";

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

// Import DESPUÉS del vi.mock para que app/handlers tomen el módulo mockeado.
const { default: app } = await import("../src/index");

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

/** Producción en lo que importa aquí: `enforce` y el canal encendido. */
function makeEnv(): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "enforce",
    SUPABASE_URL: "https://attest401-unit.local",
    SUPABASE_ANON_KEY: "anon-key-unit",
    GROUPS_ENC_KEY: "enc-key-unit-0123456789",
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    JWT_SIGNING_SECRET: SIGNING_SECRET,
  } as unknown as Env;
}

/** Stub de fetch: registra cada llamada upstream para afirmar que la guard cortó antes. */
function stubUpstream(): string[] {
  const calls: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown) => {
      calls.push(typeof input === "string" ? input : ((input as Request).url ?? String(input)));
      return new Response("{}", { status: 200, headers: { "content-type": "application/json" } });
    }),
  );
  return calls;
}

interface ErrorBody {
  type: string;
  code: string | null;
}

async function errorOf(res: Response): Promise<ErrorBody> {
  return ((await res.json()) as { error: ErrorBody }).error;
}

/** Las cuatro rutas que llama el cliente iOS, servidas por las dos guards de Grupos. */
const ROUTES: Array<{ name: string; request: (headers: Record<string, string>) => Request }> = [
  {
    name: "POST /groups/push (routes.ts)",
    request: (headers) =>
      new Request("https://gw.local/groups/push", {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ deltas: [] }),
      }),
  },
  {
    name: "GET /groups/pull (routes.ts)",
    request: (headers) => new Request("https://gw.local/groups/pull", { headers }),
  },
  {
    name: "GET /groups/merkle (routes.ts)",
    request: (headers) => new Request(`https://gw.local/groups/merkle?group_id=${GID}`, { headers }),
  },
  {
    name: "POST /groups/rpc/leave_group (rpc.ts)",
    request: (headers) =>
      new Request("https://gw.local/groups/rpc/leave_group", {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ p_group_id: GID }),
      }),
  },
];

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("los dos 401 de la guard de Grupos no se confunden (lo que lee el cliente iOS)", () => {
  for (const route of ROUTES) {
    it(`${route.name}: JWT que no verifica → 401 yala_attest_invalid, sin tocar upstream`, async () => {
      const calls = stubUpstream();
      const res = await app.fetch(route.request({ Authorization: "Bearer jwt-caducado" }), makeEnv(), NOOP_CTX);
      expect(res.status).toBe(401);
      const error = await errorOf(res);
      expect(error.type).toBe("yala_attest_invalid");
      expect(error.code).toBe(error.type);
      expect(calls).toEqual([]);
    });

    it(`${route.name}: JWT válido sin attest → 401 yala_attest_required, sin tocar upstream`, async () => {
      const calls = stubUpstream();
      const res = await app.fetch(route.request({ Authorization: `Bearer ${VALID}` }), makeEnv(), NOOP_CTX);
      expect(res.status).toBe(401);
      const error = await errorOf(res);
      expect(error.type).toBe("yala_attest_required");
      expect(error.code).toBe(error.type);
      expect(calls).toEqual([]);
    });

    it(`${route.name}: JWT válido con un attest que no verifica → también yala_attest_required`, async () => {
      const calls = stubUpstream();
      const res = await app.fetch(
        route.request({ Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": "Bearer attest-que-no-verifica" }),
        makeEnv(),
        NOOP_CTX,
      );
      expect(res.status).toBe(401);
      expect((await errorOf(res)).type).toBe("yala_attest_required");
      expect(calls).toEqual([]);
    });

    it(`${route.name}: JWT válido con un attest CADUCADO → también yala_attest_required`, async () => {
      // Firmado con el mismo secreto que el control de abajo: lo único que falla es la fecha.
      const nowSec = Math.floor(Date.now() / 1000);
      const expired = await new SignJWT({ tier: "free" })
        .setProtectedHeader({ alg: "HS256" })
        .setSubject("key-unit")
        .setIssuedAt(nowSec - 3600)
        .setExpirationTime(nowSec - 60)
        .sign(new TextEncoder().encode(SIGNING_SECRET));
      const calls = stubUpstream();
      const res = await app.fetch(
        route.request({ Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": `Bearer ${expired}` }),
        makeEnv(),
        NOOP_CTX,
      );
      expect(res.status).toBe(401);
      expect((await errorOf(res)).type).toBe("yala_attest_required");
      expect(calls).toEqual([]);
    });

    it(`${route.name}: control — JWT válido con un attest vigente pasa la guard`, async () => {
      const { token } = await issueSessionToken(makeEnv(), { keyId: "key-unit", tier: "free" });
      stubUpstream();
      const res = await app.fetch(
        route.request({ Authorization: `Bearer ${VALID}`, "X-Yala-Attest-Session": `Bearer ${token}` }),
        makeEnv(),
        NOOP_CTX,
      );
      expect(res.status).not.toBe(401);
    });
  }
});
