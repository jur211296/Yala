/**
 * Unit OFFLINE del kill-switch de Grupos (`GROUPS_BACKEND_ROLLOUT_PERCENT`) — 100 % sin red, corre en CI
 * como account.delete / groups.enckey / policy. Molde EXACTO de `groups.enckey.test.ts`: se mockea
 * `verifyUserToken` (evita el JWKS remoto de jose) y se stubbea `fetch` para PostgREST.
 *
 * ## Por qué el pin TIENE que ser offline (y no un e2e contra staging)
 *
 * La asimetría de este repo hace que staging no pruebe NADA de esta familia: sirve los tres percents al
 * **100** y corre `ENFORCE = "observe"`, así que ni el canal apagado ni el token de attest ausente son
 * observables ahí. Y a producción no se puede llamar desde un test. ⇒ el único sitio donde esta regla se
 * ejerce es este fichero. Misma lección que `.claude/rules/gateway-attest.md`.
 *
 * ## Qué pinnea, y qué mutación mata a cada cosa
 *
 * 1. **El guard existe en los CUATRO caminos.** Quitarlo de cualquiera → esa fila roja.
 * 2. **Es un KILL, no un ROLLOUT.** `percent > 0` NO rechaza, ni con 1, ni con 50, ni con 99 — el
 *    servidor no puede conocer el bucket del device (el seed de instalación jamás sale del device) y
 *    calcularlo desde otra cosa produciría una partición distinta de la del cliente. Un guard escrito
 *    como rollout (`bucket < percent`, o `percent < 100` ⇒ rechazar) pone rojos esos tres casos.
 * 3. **Fail-closed y COHERENTE con `GET /config`.** Ausente/inválido → 0 → rechazo, y la tabla de
 *    equivalencia compara los DOS consumidores del mismo parser: si alguien parsea por su cuenta en el
 *    guard, un valor basura se leería OFF en un sitio y ON en el otro (split-brain) y la tabla cae.
 * 4. **`groups_forget_user` está EXENTO** (teardown del borrado de cuenta; el cliente ya lo exceptúa por
 *    capacidad compilada). Meterlo en el kill → rojo. Sacar del kill cualquiera de los otros 11 → rojo.
 * 5. **El orden**: el kill va ANTES de la auth y ANTES del guard de `GROUPS_ENC_KEY`, para que con el
 *    canal apagado el cliente vea SIEMPRE el apagado deliberado y nunca un 401/503 que lo mandaría a
 *    re-firmar o a un backoff sobre un veredicto que ningún reintento cambia.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { GROUPS_DISABLED_MESSAGE, KILL_EXEMPT_RPCS } from "../src/groups/killSwitch";
import { PARAM_ALLOWLIST } from "../src/groups/rpc";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt"; // token sentinela: el mock de verifyUserToken lo acepta
const KEY = "enc-key-unit-0123456789";
const GID = "grp-unit-0001";

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

// Import DESPUÉS del vi.mock para que app/handlers tomen el módulo mockeado.
const { default: app } = await import("../src/index");

const SUPA = "https://killswitch-unit.local";

/**
 * La allowlist completa de `/groups/rpc/:fn`, LEÍDA del módulo y no copiada a mano: si fuera un espejo
 * manual, un RPC nuevo nacería sin clasificar —ni en el kill ni en los exentos— y ningún test lo notaría,
 * que es justo el agujero por el que este chip entró (una var que solo dos ficheros leían).
 */
const ALL_RPCS = Object.keys(PARAM_ALLOWLIST);
/** Las 11 entradas que el kill SÍ corta = allowlist menos los exentos. Si nace un RPC, hay que clasificarlo. */
const KILLED_RPCS = ALL_RPCS.filter((fn) => !KILL_EXEMPT_RPCS.has(fn));

function makeEnv(percent: string | undefined, overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: SUPA,
    SUPABASE_ANON_KEY: "anon-key-unit",
    GROUPS_ENC_KEY: KEY,
    ...(percent === undefined ? {} : { GROUPS_BACKEND_ROLLOUT_PERCENT: percent }),
    ...overrides,
  } as unknown as Env;
}

interface Upstream {
  url: string;
  fn: string | null;
}

/** Stub de fetch a PostgREST: registra cada llamada upstream para afirmar "jamás tocó PostgREST". */
function stubUpstream(rpcBody: unknown = {}, rows: unknown[] = []): Upstream[] {
  const calls: Upstream[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      const m = /\/rest\/v1\/rpc\/([^?]+)/.exec(url);
      calls.push({ url, fn: m ? m[1] : null });
      return new Response(JSON.stringify(m ? rpcBody : rows), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
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
  return await app.fetch(
    new Request(`https://gw.local/groups/merkle?group_id=${GID}`, { headers: AUTH }), env, NOOP_CTX);
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
async function config(env: Env): Promise<number> {
  const res = await app.fetch(new Request("https://gw.local/config"), env, NOOP_CTX);
  const j = (await res.json()) as { flags: { groupsBackendRolloutPercent: number } };
  return j.flags.groupsBackendRolloutPercent;
}

async function errorOf(res: Response): Promise<{ type: string; message: string }> {
  const j = (await res.json()) as { error: { type: string; message: string } };
  return j.error;
}

/** Los CUATRO caminos de `/groups/*`, con el mismo shape de invocación. */
const PATHS: Array<{ name: string; call: (env: Env) => Promise<Response> }> = [
  { name: "GET /groups/pull", call: pull },
  { name: "GET /groups/merkle", call: merkle },
  { name: "POST /groups/push", call: (env) => push(env, []) },
  { name: "POST /groups/rpc/create_group", call: (env) => rpc(env, "create_group", { p_group_id: GID, p_name: "n" }) },
];

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("percent 0 — los 4 caminos rechazan IGUAL de fuerte, sin tocar PostgREST", () => {
  for (const { name, call } of PATHS) {
    it(`${name} → 403 yala_groups_disabled que NOMBRA la var, sin request upstream`, async () => {
      const calls = stubUpstream();
      const res = await call(makeEnv("0"));
      expect(res.status).toBe(403);
      const err = await errorOf(res);
      expect(err.type).toBe("yala_groups_disabled");
      // El error se explica a sí mismo: nombra la var y dice que NO es transitorio.
      expect(err.message).toContain("GROUPS_BACKEND_ROLLOUT_PERCENT");
      expect(err.message).toContain("no reintentar");
      expect(err.message).toBe(GROUPS_DISABLED_MESSAGE);
      expect(calls).toEqual([]);
    });
  }

  it("/groups/push con deltas REALES corta ANTES de escribir (no basta con probarlo en vacío)", async () => {
    // Los otros casos mandan `deltas: []`, donde «no tocó PostgREST» se cumpliría igual sin guard porque no
    // hay nada que aplicar. Con un delta de verdad, un `apply_group_delta` en la lista de llamadas sería una
    // ESCRITURA aceptada con el canal apagado — el fallo que el kill existe para impedir.
    const calls = stubUpstream({ noop: false });
    const res = await push(makeEnv("0"), [
      {
        entity_type: "split_expenses",
        group_id: GID,
        sync_id: "sync-kill-1",
        op: "upsert",
        fields: { amount_minor: 12345 },
        field_hlcs: { amount_minor: "2026-08-03T00:00:00.000Z-0001-0000000000000aa" },
        hlc: "2026-08-03T00:00:00.000Z-0001-0000000000000aa",
      },
    ]);
    expect(res.status).toBe(403);
    expect((await errorOf(res)).type).toBe("yala_groups_disabled");
    expect(calls).toEqual([]);
    expect(calls.some((c) => c.fn === "apply_group_delta")).toBe(false);
  });

  it("el mensaje y el status son LOS MISMOS en los 4 (un solo literal, no cuatro que divergen)", async () => {
    const mensajes = new Set<string>();
    const statuses = new Set<number>();
    const types = new Set<string>();
    for (const { call } of PATHS) {
      stubUpstream();
      const res = await call(makeEnv("0"));
      statuses.add(res.status);
      const err = await errorOf(res);
      mensajes.add(err.message);
      types.add(err.type);
      vi.unstubAllGlobals();
    }
    expect(statuses).toEqual(new Set([403]));
    expect(types).toEqual(new Set(["yala_groups_disabled"]));
    expect(mensajes.size).toBe(1);
  });
});

describe("es un KILL, no un ROLLOUT — cualquier percent > 0 deja pasar", () => {
  // El servidor NO puede conocer el bucket del device (el seed de instalación jamás sale del device: al
  // gateway solo llega un SHA-256 truncado, y solo en /metrics). Un guard que decidiera por cohorte
  // produciría una partición DISTINTA de la del cliente → split-brain. Estos 3 valores intermedios son la
  // aserción que mata a esa implementación.
  for (const percent of ["1", "50", "99", "100"]) {
    it(`percent "${percent}" → los 4 caminos NO rechazan (el cliente decide con su bucket)`, async () => {
      for (const { name, call } of PATHS) {
        stubUpstream({ group_id: GID, member_key: SUB }, [{ group_id: GID }]);
        const res = await call(makeEnv(percent));
        expect(res.status, `${name} @ ${percent}`).not.toBe(403);
        vi.unstubAllGlobals();
      }
    });
  }

  it("percent \"1\" → /groups/pull llega de verdad a PostgREST (no es un 200 vacío por corte silencioso)", async () => {
    const calls = stubUpstream([], [{ group_id: GID }]);
    const res = await pull(makeEnv("1"));
    expect(res.status).toBe(200);
    expect(calls.length).toBeGreaterThan(0);
  });
});

describe("fail-closed y COHERENTE con lo que GET /config publica", () => {
  // Un solo parser (`parseRolloutPercent`, importado de config.ts) para los dos consumidores: si el guard
  // parseara por su cuenta, un valor basura podría leerse OFF en /config y ON en las rutas — y esa
  // incoherencia es exactamente la clase de fallo que el kill-switch existe para cerrar.
  // ⚠️ Los TRES valores marcados DISCRIMINAN, y son los únicos de esta lista que lo hacen: son los que
  // separan `parseRolloutPercent` (parseInt + clamp) de un `Number(raw) > 0` escrito a mano, que es la
  // forma más natural de "simplificar" este guard. Medido: con `Number(...)`, `"0.5"` y `"0.9"` dejan PASAR
  // mientras /config publica 0 (el kill no corta con el cliente ya apagado), y `"1abc"` RECHAZA mientras
  // /config publica 1 (el gateway tumba un canal que /config declara vivo). Divergencia en las dos
  // direcciones. Sin estos tres, la tabla pasa con el parser propio puesto y no prueba lo que dice probar.
  const RAW: Array<{ raw: string | undefined; label: string }> = [
    { raw: undefined, label: "var AUSENTE" },
    { raw: "", label: "cadena vacía" },
    { raw: "0", label: "cero" },
    { raw: "abc", label: "no numérico" },
    { raw: "-1", label: "negativo (clamp a 0)" },
    { raw: "0.5", label: "decimal por debajo de 1 → DISCRIMINANTE" },
    { raw: "0.9", label: "decimal casi 1 → DISCRIMINANTE" },
    { raw: "1abc", label: "número con cola basura → DISCRIMINANTE" },
    { raw: "1", label: "uno" },
    { raw: "50", label: "cincuenta" },
    { raw: "100", label: "cien" },
    { raw: "500", label: "por encima de 100 (clamp a 100)" },
  ];

  for (const { raw, label } of RAW) {
    it(`${label} → "/config publica 0" ⟺ "las rutas rechazan"`, async () => {
      const env = makeEnv(raw);
      const published = await config(env);
      stubUpstream({ group_id: GID }, [{ group_id: GID }]);
      const res = await pull(env);
      expect(res.status === 403, `published=${published}`).toBe(published === 0);
    });
  }
});

describe("/groups/rpc/:fn — el kill corta las 11 no-exentas y NO el teardown", () => {
  for (const fn of KILLED_RPCS) {
    it(`${fn} lo corta el kill → 403 con el canal apagado, sin tocar PostgREST`, async () => {
      const calls = stubUpstream();
      const res = await rpc(makeEnv("0"), fn, { p_group_id: GID });
      expect(res.status).toBe(403);
      expect((await errorOf(res)).type).toBe("yala_groups_disabled");
      expect(calls).toEqual([]);
    });
  }

  it("groups_forget_user es TEARDOWN → pasa con el canal apagado y llega a PostgREST (derecho de supresión)", async () => {
    // El cliente ya lo exceptúa por capacidad COMPILADA (`ensureEligibleForTeardown`): bloquearlo aquí
    // dejaría al usuario sin poder borrar su cuenta mientras durase el kill. Ver killSwitch.ts.
    const calls = stubUpstream({ groups_transferred: 0, groups_tombstoned: 0, memberships_anonymized: 1 });
    const res = await rpc(makeEnv("0"), "groups_forget_user");
    expect(res.status).toBe(200);
    expect(calls.map((c) => c.fn)).toEqual(["groups_forget_user"]);
  });

  it("el set de exentos es EXACTAMENTE uno (crecer sin pensarlo abre el kill por la puerta de atrás)", () => {
    expect([...KILL_EXEMPT_RPCS]).toEqual(["groups_forget_user"]);
    // Y todos los exentos tienen que estar en la allowlist real: un nombre mal escrito sería un exento
    // fantasma que no exime nada y un RPC real que se sigue cortando sin que nadie lo note.
    for (const fn of KILL_EXEMPT_RPCS) expect(ALL_RPCS).toContain(fn);
  });

  it("la allowlist REAL está clasificada entera: cada fn es o killed o exento, sin huérfanos", () => {
    // ALL_RPCS sale de `PARAM_ALLOWLIST` (importada), así que añadir un RPC al gateway sin decidir su lado
    // rompe aquí. Es el pin que impide que el kill nazca incompleto la próxima vez.
    expect(ALL_RPCS.length).toBeGreaterThan(0);
    for (const fn of ALL_RPCS) {
      const clasificado = KILL_EXEMPT_RPCS.has(fn) || KILLED_RPCS.includes(fn);
      expect(clasificado, `RPC sin clasificar en el kill-switch: ${fn}`).toBe(true);
    }
    expect(KILLED_RPCS.length + KILL_EXEMPT_RPCS.size).toBe(ALL_RPCS.length);
  });

  it("un fn INEXISTENTE recibe el mismo 403 que uno real → sigue sin haber oráculo de la allowlist", async () => {
    const calls = stubUpstream();
    const real = await rpc(makeEnv("0"), "create_group");
    const fake = await rpc(makeEnv("0"), "fake_fn_que_no_existe");
    expect(fake.status).toBe(real.status);
    expect((await errorOf(fake)).message).toBe((await errorOf(real)).message);
    expect(calls).toEqual([]);
  });
});

describe("ORDEN de los guards — el apagado se ve SIEMPRE, nunca disfrazado", () => {
  // Las CUATRO rutas, no solo pull: el orden se cablea handler por handler, así que un guard puesto después
  // de la auth en cualquiera de ellas devolvería 401 y mandaría al usuario a re-firmar por un apagado.
  it("sin Authorization + canal apagado → 403 del kill en las 4 rutas, NO 401", async () => {
    const env = makeEnv("0");
    for (const req of [
      new Request("https://gw.local/groups/push", { method: "POST", body: "{}" }),
      new Request("https://gw.local/groups/pull"),
      new Request("https://gw.local/groups/merkle?group_id=whatever8"),
      new Request("https://gw.local/groups/rpc/create_group", { method: "POST", body: "{}" }),
    ]) {
      const calls = stubUpstream();
      const res = await app.fetch(req, env, NOOP_CTX);
      expect(res.status, req.url).toBe(403);
      expect((await errorOf(res)).type, req.url).toBe("yala_groups_disabled");
      expect(calls, req.url).toEqual([]);
      vi.unstubAllGlobals();
    }
  });

  it("canal apagado + ENFORCE=enforce → sigue siendo el 403 del kill (el kill precede al attest)", async () => {
    // Con el guard después de `requireUserAndAttest`, en producción (`enforce`) un device sin token de attest
    // recibiría 401 `yala_attest_required` en vez del apagado — el error que costó todo el 2026-07-31.
    const calls = stubUpstream();
    const res = await app.fetch(
      new Request("https://gw.local/groups/pull", { headers: AUTH }),
      makeEnv("0", { ENFORCE: "enforce" }),
      NOOP_CTX,
    );
    expect(res.status).toBe(403);
    expect((await errorOf(res)).type).toBe("yala_groups_disabled");
    expect(calls).toEqual([]);
  });

  // Las TRES rutas, no solo pull: es exactamente lo que afirma `groups.goldens.test.ts` («auth: sin JWT →
  // 401 en push/pull/merkle»), y ese fichero no se puede correr sin `GROUPS_ENC_KEY` en el entorno ⇒ el
  // ajuste de su env queda sin ejercitar allí. Aquí sí se ejercita, offline y sin secretos.
  it("sin Authorization + canal ENCENDIDO → 401 en push/pull/merkle (el kill no altera el camino normal)", async () => {
    const env = makeEnv("100");
    for (const req of [
      new Request("https://gw.local/groups/push", { method: "POST", body: "{}" }),
      new Request("https://gw.local/groups/pull"),
      new Request("https://gw.local/groups/merkle?group_id=whatever8"),
    ]) {
      const calls = stubUpstream();
      const res = await app.fetch(req, env, NOOP_CTX);
      expect(res.status, req.url).toBe(401);
      expect(calls, req.url).toEqual([]);
      vi.unstubAllGlobals();
    }
  });

  it("canal apagado + GROUPS_ENC_KEY ausente → 403 del kill, NO el 503 de la llave", async () => {
    const calls = stubUpstream();
    const res = await pull(makeEnv("0", { GROUPS_ENC_KEY: undefined }));
    expect(res.status).toBe(403);
    expect((await errorOf(res)).type).toBe("yala_groups_disabled");
    expect(calls).toEqual([]);
  });

  it("canal apagado NO afecta a otras rutas del gateway (/config y /healthz siguen vivos)", async () => {
    const env = makeEnv("0");
    expect(await config(env)).toBe(0);
    const health = await app.fetch(new Request("https://gw.local/healthz"), env, NOOP_CTX);
    expect(health.status).toBe(200);
  });

  // Las dos rutas EXENTAS POR OMISIÓN. Sin este pin, la exención es una ausencia de código y nada distingue
  // «decidido que pase» de «se nos olvidó»; y si alguien las mete en el kill, `unregister` —que es teardown
  // del sign-out— dejaría tokens huérfanos recibiendo silent pushes de un canal del que el usuario ya salió.
  // El racional completo, en el header de killSwitch.ts.
  it("/push/register y /push/unregister NO llevan el kill (register es inocuo, unregister es teardown)", async () => {
    for (const path of ["/push/register", "/push/unregister"]) {
      stubUpstream({ ok: true });   // sin stub la ruta sale a PostgREST de verdad y el caso expira
      const res = await app.fetch(
        new Request(`https://gw.local${path}`, {
          method: "POST",
          headers: { ...AUTH, "Content-Type": "application/json" },
          body: JSON.stringify({ device_token: "a".repeat(64), platform: "ios-prod" }),
        }),
        makeEnv("0"),
        NOOP_CTX,
      );
      expect(res.status, path).not.toBe(403);
      vi.unstubAllGlobals();
    }
  });
});
