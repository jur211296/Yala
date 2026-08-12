/**
 * Unit OFFLINE de los 2 RPCs del registro de consent de Grupos (C1, g13_01) — 100 % sin red, molde EXACTO
 * de `groups.enckey.test.ts` / `groups.killswitch.test.ts`.
 *
 * ## Por qué este fichero existe (y por qué NO puede ser un e2e)
 *
 * La elección de guard es la decisión de seguridad del chip: `/groups/rpc/:fn` va por
 * `requireUserAndAttest`, así que bajo `ENFORCE = "enforce"` (producción) un request SIN el header
 * `X-Yala-Attest-Session` recibe 401 `yala_attest_required`. Staging corre `"observe"` y ahí ese mismo
 * request PASA, así que ningún e2e contra staging observa la regla; y contra producción no se puede llamar
 * desde un test (el AAGUID de `verifyAttestation.ts` rechaza por diseño cualquier build de desarrollo).
 * ⇒ el pin del lado servidor es este fichero, y el del lado cliente es `AttestWiringTests` +
 * `AttestHeaderTransportTests`. Palabra por palabra `.claude/rules/gateway-attest.md`.
 *
 * ## Lo que pinnea, y qué mutación mata cada cosa
 *
 * 1. **La guard estricta se aplica de verdad**: con `enforce` y sin header → 401 y PostgREST intacto.
 *    Mover estos `fn` a un handler con `requireUser` (o colar un `if (fn === …) skip`) pone rojo aquí.
 * 2. **`p_user_id` JAMÁS llega al RPC.** La identidad sale de `auth.uid()` dentro del RPC; un user_id del
 *    body sería exactamente el agujero por el que se registraría el consent de otra cuenta. Ampliar la
 *    allowlist de params de estos dos `fn` cae aquí.
 * 3. **Los 3 params buenos SÍ viajan** — un filtro demasiado agresivo dejaría `record_groups_consent` sin
 *    fecha, y el servidor la sustituiría por la del reintento: la falsificación silenciosa que el chip
 *    existe para evitar.
 * 4. **El `yala_bad_input` del RPC llega al cliente como 400 con su código**, que es lo que hace que el
 *    intent durable pueda distinguir «bug nuestro» (conservar + canario) de «transitorio».
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

// Import DESPUÉS del vi.mock para que app/handlers tomen el módulo mockeado.
const { default: app } = await import("../src/index");

const SUPA = "https://consent-unit.local";
const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
const AUTH = { Authorization: `Bearer ${VALID}`, "Content-Type": "application/json" };

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: SUPA,
    SUPABASE_ANON_KEY: "anon-key-unit",
    // El kill-switch es fail-closed (ausente → 0 → 403 antes de todo), así que sin esta línea el fichero
    // entero mediría el kill en vez del consent.
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    GROUPS_ENC_KEY: "enc-key-unit-0123456789",
    ...overrides,
  } as unknown as Env;
}

interface Upstream {
  fn: string | null;
  args: Record<string, unknown> | null;
}

function stubUpstream(rpcBody: unknown = {}, status = 200): Upstream[] {
  const calls: Upstream[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      const m = /\/rest\/v1\/rpc\/([^?]+)/.exec(url);
      const args = typeof init?.body === "string" ? (JSON.parse(init.body) as Record<string, unknown>) : null;
      calls.push({ fn: m ? m[1] : null, args });
      return new Response(JSON.stringify(rpcBody), { status, headers: { "content-type": "application/json" } });
    }),
  );
  return calls;
}

async function rpc(env: Env, fn: string, body: Record<string, unknown> = {}, headers = AUTH): Promise<Response> {
  return await app.fetch(
    new Request(`https://gw.local/groups/rpc/${fn}`, { method: "POST", headers, body: JSON.stringify(body) }),
    env,
    NOOP_CTX,
  );
}

async function errorOf(res: Response): Promise<{ type: string; message: string; code?: string }> {
  const j = (await res.json()) as { error: { type: string; message: string; code?: string } };
  return j.error;
}

const ACCEPTED_AT = "2026-08-11T18:04:05.123Z";
const CONSENT_FNS = ["record_groups_consent", "groups_consent_state"];

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("C1 · la guard del handler es `requireUserAndAttest` (la decisión de seguridad del chip)", () => {
  for (const fn of CONSENT_FNS) {
    it(`${fn} bajo ENFORCE=enforce y SIN header de attest → 401, sin tocar PostgREST`, async () => {
      const calls = stubUpstream();
      const res = await rpc(makeEnv({ ENFORCE: "enforce" }), fn, { p_text_version: 1 });
      expect(res.status).toBe(401);
      expect((await errorOf(res)).type).toBe("yala_attest_required");
      expect(calls).toEqual([]);
    });
  }

  it("bajo ENFORCE=observe el MISMO request pasa — la asimetría que hace inútil el e2e de staging", async () => {
    // Este caso no es decorativo: es la prueba de que un e2e contra staging habría dado verde con el
    // cliente sin cablear. Por eso el pin del lado cliente tiene que ser estructural.
    const calls = stubUpstream({ text_version: 1, accepted_at: ACCEPTED_AT, inserted: true });
    const res = await rpc(makeEnv(), "record_groups_consent", {
      p_text_version: 1,
      p_accepted_at: ACCEPTED_AT,
    });
    expect(res.status).toBe(200);
    expect(calls.map((c) => c.fn)).toEqual(["record_groups_consent"]);
  });

  it("sin Authorization → 401 en los dos, y PostgREST no se entera", async () => {
    for (const fn of CONSENT_FNS) {
      const calls = stubUpstream();
      const res = await rpc(makeEnv(), fn, {}, { "Content-Type": "application/json" });
      expect(res.status, fn).toBe(401);
      expect(calls, fn).toEqual([]);
      vi.unstubAllGlobals();
    }
  });
});

describe("C1 · el filtro de params: la identidad NUNCA viaja en el body", () => {
  it("record_groups_consent pasa los 3 params buenos y DESCARTA p_user_id", async () => {
    const calls = stubUpstream({ text_version: 2, accepted_at: ACCEPTED_AT, inserted: true });
    const res = await rpc(makeEnv(), "record_groups_consent", {
      p_text_version: 2,
      p_accepted_at: ACCEPTED_AT,
      p_path: "organizer",
      p_user_id: "99999999-9999-9999-9999-999999999999",
      p_algo_que_no_existe: true,
    });
    expect(res.status).toBe(200);
    expect(calls).toHaveLength(1);
    expect(calls[0].args).toEqual({
      p_text_version: 2,
      p_accepted_at: ACCEPTED_AT,
      p_path: "organizer",
    });
    // Explícito además del toEqual: es EL invariante, y un `toEqual` que alguien relaje mañana no lo dice.
    expect(calls[0].args).not.toHaveProperty("p_user_id");
    // No escribe columnas † ⇒ el gateway no le inyecta la llave.
    expect(calls[0].args).not.toHaveProperty("p_key");
  });

  it("groups_consent_state no acepta NINGÚN param (todo lo del body se descarta)", async () => {
    const calls = stubUpstream({ text_version: 1, accepted_at: ACCEPTED_AT });
    const res = await rpc(makeEnv(), "groups_consent_state", { p_user_id: SUB, p_text_version: 9 });
    expect(res.status).toBe(200);
    expect(calls[0].args).toEqual({});
  });
});

describe("C1 · errores del RPC", () => {
  it("yala_bad_input (fecha absurda) → 400 con el código preservado, que es lo que el intent clasifica", async () => {
    const calls = stubUpstream({ message: "yala_bad_input" }, 400);
    const res = await rpc(makeEnv(), "record_groups_consent", {
      p_text_version: 1,
      p_accepted_at: "1999-01-01T00:00:00Z",
    });
    expect(res.status).toBe(400);
    const err = await errorOf(res);
    expect(err.type).toBe("yala_rpc_error");
    expect(err.code).toBe("yala_bad_input");
    expect(calls).toHaveLength(1);
  });

  it("con el canal APAGADO → 403 yala_groups_disabled y PostgREST intacto (el intent lo conserva)", async () => {
    // No están en KILL_EXEMPT_RPCS a propósito: el consent ya ocurrió y su prueba no se tira por un 403;
    // el cliente lo trata como transitorio y reintenta cuando el canal vuelva.
    for (const fn of CONSENT_FNS) {
      const calls = stubUpstream();
      const res = await rpc(makeEnv({ GROUPS_BACKEND_ROLLOUT_PERCENT: "0" }), fn, { p_text_version: 1 });
      expect(res.status, fn).toBe(403);
      expect((await errorOf(res)).type, fn).toBe("yala_groups_disabled");
      expect(calls, fn).toEqual([]);
      vi.unstubAllGlobals();
    }
  });
});
