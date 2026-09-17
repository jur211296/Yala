/**
 * Los dos 401 de la guard del canal PERSONAL, cada uno en su sitio — unit OFFLINE, molde de `groups.attest401.test.ts`: se
 * mockea `verifyUserToken` (sin JWKS remoto) y se stubbea `fetch` para afirmar que no se toca PostgREST.
 *
 * ## Por qué existe
 *
 * Desde el 2026-09-16 los clientes iOS del canal personal (`SyncPushClient`, `SyncPullClient`, `PrefsSyncClient`) leen el
 * código de este 401 con `GatewayErrorEnvelope.isAttestRequired`: con `yala_attest_required` el JWT vale y reintentan con
 * backoff; con `yala_attest_invalid` piden volver a entrar (ticket
 * `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`). Esa lectura solo es cierta mientras
 * `requireUserAndAttest` de `sync/routes.ts` emita cada código en su sitio:
 *
 * - `yala_attest_invalid` ⇔ el JWT de usuario no verifica.
 * - `yala_attest_required` ⇔ el JWT verifica y el token de attest falta o no verifica (bajo `ENFORCE = "enforce"`).
 *
 * Si esta guard devolviera `yala_attest_required` con el JWT caducado, la app leería una sesión muerta como pasajera y
 * reintentaría para siempre sin pedir volver a entrar. Las guards de Grupos las fija `groups.attest401.test.ts`, y la de
 * `sync/account.ts`, `account.delete.test.ts`; esta no la fijaba nadie.
 *
 * ## Qué mutación mata cada caso
 *
 * 1. Cambiar el código del JWT inválido → rojo en las cuatro rutas.
 * 2. Cambiar el del attest ausente, o dejar de exigirlo → rojo.
 * 3. Que un attest que no verifica —malformado o caducado— deje de dar `yala_attest_required` → rojo.
 * 4. Que `code` deje de coincidir con `type` → rojo: el cliente lee `type`.
 *
 * Los casos de attest llevan un CONTROL con un token vigente firmado con el mismo secreto: sin él, un secreto mal puesto
 * haría fallar la verificación de cualquier token y los casos saldrían verdes por el motivo equivocado.
 *
 * **Nadie lo corre automáticamente**: el CI no ejecuta la suite del gateway (`ci-no-corre-la-suite-del-gateway`). Se corre
 * con `npm test -- test/sync.attest401.test.ts`; el `pretest` copia los manifests.
 */
import { SignJWT } from "jose";
import { afterEach, describe, expect, it, vi } from "vitest";
import { issueSessionToken } from "../src/attest/session";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta
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

/** Producción en lo que importa aquí: `enforce`. */
function makeEnv(): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "enforce",
    SUPABASE_URL: "https://sync-attest401-unit.local",
    SUPABASE_ANON_KEY: "anon-key-unit",
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
      return new Response("[]", { status: 200, headers: { "content-type": "application/json" } });
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

/** Las cuatro rutas cuyo 401 lee el cliente iOS del canal personal, todas servidas por `sync/routes.ts`. */
const ROUTES: Array<{ name: string; request: (headers: Record<string, string>) => Request }> = [
  {
    name: "POST /sync/push",
    request: (headers) =>
      new Request("https://gw.local/sync/push", {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ deltas: [] }),
      }),
  },
  {
    name: "GET /sync/pull",
    request: (headers) => new Request("https://gw.local/sync/pull?since=0&limit=10", { headers }),
  },
  {
    name: "POST /prefs/push",
    request: (headers) =>
      new Request("https://gw.local/prefs/push", {
        method: "POST",
        headers: { ...headers, "Content-Type": "application/json" },
        body: JSON.stringify({ prefs: [] }),
      }),
  },
  {
    name: "GET /prefs/pull",
    request: (headers) => new Request("https://gw.local/prefs/pull?since=0", { headers }),
  },
];

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("los dos 401 de la guard del canal personal no se confunden (lo que lee el cliente iOS)", () => {
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
      // Firmado con el mismo secreto que el control de abajo: lo único que falla es la fecha. Es el caso que la app ve con
      // un token de sesión de la caché que el servidor ya da por vencido.
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
