/**
 * Unit OFFLINE del guard de `GROUPS_ENC_KEY` (G7) — 100% sin red, corre en CI como account.delete /
 * apns.sign / policy. Se mockea `verifyUserToken` (evita el JWKS remoto de jose) y se stubbea `fetch`
 * para PostgREST; `callRpc`/`getRows` quedan REALES.
 *
 * Qué pinnea, y por qué hace falta un test y no basta con leer el código:
 *
 * 1. **Simetría de los CUATRO caminos.** Hasta el 2026-07-31 solo `/groups/pull` y `/groups/merkle`
 *    comprobaban la llave; los de ESCRITURA (`/groups/push`, `/groups/rpc/:fn`) inyectaban
 *    `p_key: env.GROUPS_ENC_KEY` a pelo → con el secreto ausente PostgREST recibía `undefined` y devolvía
 *    un error de firma de función que no menciona el secreto por ningún lado. El assert que carga el peso
 *    es `mensajes de los 4 === 1 solo string`: comparar rutas ENTRE SÍ no es tautológico (re-inlinear el
 *    literal viejo en cualquiera de ellas pone el test rojo), mientras que comparar contra la constante
 *    importada sí lo sería.
 * 2. **`RPC_NEEDS_ENC_KEY` es el criterio exacto, ni más ni menos.** Exigir la llave de más tumbaría
 *    `leave_group`/`approve_member`/… sin necesidad (no escriben columnas †).
 * 3. **`""` cuenta como ausente** — un secret a cadena vacía es tan inservible como no ponerlo.
 *
 * NO se puede verificar contra staging: el gateway de staging TIENE la llave, y su `ENFORCE = "observe"`
 * hace que toda esta familia de fallos sea invisible ahí (ver .claude/rules/gateway-attest.md). El pin es
 * este test.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { ENC_KEY_MISSING_MESSAGE } from "../src/groups/encKey";
import { GROUP_ENTITIES } from "../src/groups/manifest";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta
const KEY = "enc-key-unit-0123456789";
const GID = "grp-unit-0001";

// Mock parcial de userauth: verifyUserToken reconoce SOLO el token sentinela; callRpc/getRows/bearerToken
// quedan REALES (usan el fetch stubbeado abajo). Los handlers importan de este módulo.
vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

// Import DESPUÉS del vi.mock para que app/handlers tomen el módulo mockeado.
const { default: app } = await import("../src/index");

const SUPA = "https://enckey-unit.local";

// Los 4 RPCs de membresía que escriben columnas † (espejo de RPC_NEEDS_ENC_KEY en src/groups/rpc.ts) y los
// 6 que NO. Juntos son la allowlist completa: si crece una, este test obliga a clasificar la nueva.
const NEEDS_KEY = ["create_group", "join_group", "update_member_display_name", "groups_forget_user"];
const NO_KEY = [
  "create_group_invite",
  "approve_member",
  "remove_member",
  "leave_group",
  "revoke_invite",
  "transfer_group_ownership",
];

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: SUPA,
    SUPABASE_ANON_KEY: "anon-key-unit",
    // OBLIGATORIO desde el kill-switch server-side: `parseRolloutPercent` es fail-closed (ausente → 0)
    // y con 0 las 4 rutas de `/groups/*` cortan con 403 ANTES del guard de la llave, así que sin esta
    // línea todo este fichero probaría el kill en vez de `GROUPS_ENC_KEY`. Ver src/groups/killSwitch.ts.
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    ...overrides,
  } as unknown as Env;
}

interface Upstream {
  url: string;
  fn: string | null;
  args: Record<string, unknown> | null;
}

/**
 * Stub de fetch a PostgREST. Registra CADA llamada upstream (RPC o GET de tabla) para poder afirmar tanto
 * "jamás tocó PostgREST" como "el RPC recibió p_key con este valor". Todo responde 200.
 */
function stubUpstream(rpcBody: unknown = {}, rows: unknown[] = []): Upstream[] {
  const calls: Upstream[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      const m = /\/rest\/v1\/rpc\/([^?]+)/.exec(url);
      const args = typeof init?.body === "string" ? (JSON.parse(init.body) as Record<string, unknown>) : null;
      calls.push({ url, fn: m ? m[1] : null, args });
      const body = m ? rpcBody : rows;
      return new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
    }),
  );
  return calls;
}

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
const AUTH = { Authorization: `Bearer ${VALID}` };

async function pull(env: Env): Promise<Response> {
  return await app.fetch(new Request("https://gw.local/groups/pull", { headers: AUTH }), env, NOOP_CTX);
}
async function merkle(env: Env): Promise<Response> {
  return await app.fetch(new Request(`https://gw.local/groups/merkle?group_id=${GID}`, { headers: AUTH }), env, NOOP_CTX);
}
async function push(env: Env, deltas: unknown[] = []): Promise<Response> {
  return await app.fetch(
    new Request("https://gw.local/groups/push", {
      method: "POST",
      headers: { ...AUTH, "Content-Type": "application/json" },
      body: JSON.stringify({ deltas }),
    }),
    env,
    NOOP_CTX,
  );
}
async function rpc(env: Env, fn: string, body: Record<string, unknown> = {}): Promise<Response> {
  return await app.fetch(
    new Request(`https://gw.local/groups/rpc/${fn}`, {
      method: "POST",
      headers: { ...AUTH, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    env,
    NOOP_CTX,
  );
}

async function errorOf(res: Response): Promise<{ type: string; message: string }> {
  const j = (await res.json()) as { error: { type: string; message: string } };
  return j.error;
}

/** Los 4 caminos que inyectan `p_key`, con el mismo shape de invocación. */
const PATHS: Array<{ name: string; call: (env: Env) => Promise<Response> }> = [
  { name: "GET /groups/pull", call: pull },
  { name: "GET /groups/merkle", call: merkle },
  { name: "POST /groups/push", call: (env) => push(env, []) },
  { name: "POST /groups/rpc/create_group", call: (env) => rpc(env, "create_group", { p_group_id: GID, p_name: "n" }) },
];

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("GROUPS_ENC_KEY ausente — los 4 caminos fallan IGUAL de fuerte", () => {
  for (const { name, call } of PATHS) {
    it(`${name} → 503 yala_unavailable que NOMBRA el secreto, sin tocar PostgREST`, async () => {
      const calls = stubUpstream();
      const res = await call(makeEnv()); // sin GROUPS_ENC_KEY
      expect(res.status).toBe(503);
      const err = await errorOf(res);
      expect(err.type).toBe("yala_unavailable");
      // El error se explica a sí mismo: nombra el secreto que falta (no hace falta leer el gateway).
      expect(err.message).toContain("GROUPS_ENC_KEY");
      expect(err.message).toBe(ENC_KEY_MISSING_MESSAGE);
      // Corta ANTES de cualquier request upstream: nada aplicado a medias, ni ciphertext servido.
      expect(calls).toEqual([]);
    });
  }

  it("el mensaje es EL MISMO en los 4 (un solo literal, no cuatro que divergen)", async () => {
    const mensajes = new Set<string>();
    const statuses = new Set<number>();
    for (const { call } of PATHS) {
      stubUpstream();
      const res = await call(makeEnv());
      statuses.add(res.status);
      mensajes.add((await errorOf(res)).message);
      vi.unstubAllGlobals();
    }
    expect(statuses).toEqual(new Set([503]));
    expect(mensajes.size).toBe(1);
  });

  it("GROUPS_ENC_KEY = \"\" cuenta como AUSENTE en los 4 (un secret vacío es igual de inservible)", async () => {
    for (const { name, call } of PATHS) {
      const calls = stubUpstream();
      const res = await call(makeEnv({ GROUPS_ENC_KEY: "" }));
      expect(res.status, name).toBe(503);
      expect(calls, name).toEqual([]);
      vi.unstubAllGlobals();
    }
  });
});

describe("/groups/rpc/:fn — RPC_NEEDS_ENC_KEY es el criterio EXACTO", () => {
  for (const fn of NEEDS_KEY) {
    it(`${fn} escribe columnas † → sin llave, 503 y jamás llama a PostgREST`, async () => {
      const calls = stubUpstream();
      const res = await rpc(makeEnv(), fn);
      expect(res.status).toBe(503);
      expect((await errorOf(res)).message).toBe(ENC_KEY_MISSING_MESSAGE);
      expect(calls).toEqual([]);
    });
  }

  for (const fn of NO_KEY) {
    it(`${fn} NO escribe † → sin llave sigue funcionando, y el RPC no recibe p_key`, async () => {
      const calls = stubUpstream({ ok: true });
      const res = await rpc(makeEnv(), fn, { p_group_id: GID });
      expect(res.status).toBe(200);
      expect(calls.map((c) => c.fn)).toEqual([fn]);
      expect(calls[0].args).not.toHaveProperty("p_key");
    });
  }

  it("fn fuera de la allowlist → 404 aunque falte la llave (el guard de allowlist manda)", async () => {
    const calls = stubUpstream();
    const res = await rpc(makeEnv(), "apply_group_delta");
    expect(res.status).toBe(404);
    expect((await errorOf(res)).type).toBe("yala_bad_request");
    expect(calls).toEqual([]);
  });

  it("sin Authorization → 401, no 503 (el auth corta antes; no se filtra el estado de config)", async () => {
    const calls = stubUpstream();
    const res = await app.fetch(
      new Request("https://gw.local/groups/rpc/create_group", { method: "POST" }),
      makeEnv(),
      NOOP_CTX,
    );
    expect(res.status).toBe(401);
    expect(calls).toEqual([]);
  });
});

describe("con la llave presente, se inyecta su VALOR (y solo donde toca)", () => {
  it("/groups/rpc/create_group → el RPC recibe p_key con el valor del secret", async () => {
    const calls = stubUpstream({ group_id: GID });
    const res = await rpc(makeEnv({ GROUPS_ENC_KEY: KEY }), "create_group", { p_group_id: GID, p_name: "Piso" });
    expect(res.status).toBe(200);
    expect(calls).toHaveLength(1);
    expect(calls[0].fn).toBe("create_group");
    expect(calls[0].args?.p_key).toBe(KEY);
    // El cliente jamás manda p_key: si lo intenta, la PARAM_ALLOWLIST lo descarta y gana el inyectado.
    expect(calls[0].args?.p_name).toBe("Piso");
  });

  it("/groups/rpc/create_group ignora un p_key del CLIENTE y usa el del entorno", async () => {
    const calls = stubUpstream({ group_id: GID });
    await rpc(makeEnv({ GROUPS_ENC_KEY: KEY }), "create_group", { p_group_id: GID, p_key: "llave-del-atacante" });
    expect(calls[0].args?.p_key).toBe(KEY);
  });

  it("/groups/push → apply_group_delta recibe p_key (la llave THREADEADA, no releída de env)", async () => {
    const calls = stubUpstream({ noop: false });
    const res = await push(makeEnv({ GROUPS_ENC_KEY: KEY }), [
      {
        entity_type: "split_expenses",
        group_id: GID,
        sync_id: "sync-unit-1",
        op: "tombstone",
        hlc: "2026-07-31T12:00:00.000Z-0001-0000000000000aa",
      },
    ]);
    expect(res.status).toBe(200);
    const applied = calls.filter((c) => c.fn === "apply_group_delta");
    expect(applied).toHaveLength(1);
    expect(applied[0].args?.p_key).toBe(KEY);
  });

  it("/groups/pull → los 5 RPCs lectores reciben p_key", async () => {
    // 1er fetch: GET group_members (memberships) → una membresía. Después, los 5 readers del grupo.
    const calls = stubUpstream([], [{ group_id: GID }]);
    const res = await pull(makeEnv({ GROUPS_ENC_KEY: KEY }));
    expect(res.status).toBe(200);
    const readers = calls.filter((c) => c.fn?.startsWith("groups_pull_rows_"));
    expect(readers).toHaveLength(GROUP_ENTITIES.length);
    for (const r of readers) expect(r.args?.p_key, r.fn ?? "?").toBe(KEY);
  });
});
