/**
 * `/sync/pull` y `/sync/merkle` consultan las tablas EN PARALELO — unit OFFLINE, molde de `sync.attest401.test.ts`.
 *
 * ## Por qué existe
 *
 * Card «Conectar con la cuenta tarda 22–50 s» (2026-11-14). Medido en el iPhone 14 con una cuenta de 7.221 filas: entrar
 * tardaba 55 s, y 41 de ellos eran la lectura de la cuenta en 15 páginas de `/sync/pull`. Cada página costaba ~2,2 s
 * aunque viniera vacía, porque el handler consultaba las ~22 tablas una detrás de otra. El Merkle, igual (4–6 s).
 *
 * ## Qué mutación mata cada caso
 *
 * 1. Volver al bucle en serie en el pull o en el Merkle → `maxInFlight` 1 → rojo.
 * 2. Que el paralelo cambie la página (otro orden, filas de más o de menos) → rojo en la comparación de la página.
 * 3. Que un fallo upstream deje de reportar la PRIMERA tabla que falla en el orden del manifest → rojo.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";
import { SYNCABLE_ENTITIES } from "../src/sync/manifest";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt";

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

const { default: app } = await import("../src/index");

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

function makeEnv(): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: "https://sync-parallel-unit.local",
    SUPABASE_ANON_KEY: "anon-key-unit",
    JWT_SIGNING_SECRET: "jwt-signing-secret-unit",
  } as unknown as Env;
}

/** La tabla de una URL de PostgREST (`…/rest/v1/<tabla>?…`). */
function entityOf(url: string): string {
  return url.split("/rest/v1/")[1].split("?")[0];
}

/**
 * Stub de PostgREST con latencia: cuenta cuántas consultas hay en vuelo a la vez. Cada tabla devuelve una fila con un
 * `server_seq` propio, para que la página mezclada tenga un orden que comprobar. `failing` responde 503 en esas tablas.
 */
function stubUpstream(failing: Set<string> = new Set()) {
  const state = { inFlight: 0, maxInFlight: 0, calls: 0 };
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      const entity = entityOf(url);
      state.calls += 1;
      state.inFlight += 1;
      state.maxInFlight = Math.max(state.maxInFlight, state.inFlight);
      await new Promise((r) => setTimeout(r, 5));
      state.inFlight -= 1;
      if (failing.has(entity)) return new Response("{}", { status: 503 });
      // Una fila viva por tabla en el pull; el Merkle pide un select sin `server_seq`, y la fila le vale igual.
      const index = SYNCABLE_ENTITIES.indexOf(entity);
      const row = {
        sync_id: `00000000-0000-0000-0000-${String(index).padStart(12, "0")}`,
        server_seq: SYNCABLE_ENTITIES.length - index,
        hlc: "1700000000000-0000-node",
        deleted: true,
        deleted_hlc: "1700000000000-0000-node",
        field_hlcs: {},
      };
      return new Response(JSON.stringify(url.includes("server_seq=gt.") ? [row] : []), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }),
  );
  return state;
}

const auth = { Authorization: `Bearer ${VALID}` };

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("/sync/pull consulta las tablas en paralelo y devuelve la misma página", () => {
  it("varias consultas en vuelo a la vez, una por tabla", async () => {
    const state = stubUpstream();
    const res = await app.fetch(new Request("https://gw.local/sync/pull?since=0&limit=1000", { headers: auth }), makeEnv(), NOOP_CTX);
    expect(res.status).toBe(200);
    expect(state.calls).toBe(SYNCABLE_ENTITIES.length);
    expect(state.maxInFlight).toBeGreaterThan(1);
  });

  it("la página sale ordenada por server_seq y con una fila por tabla", async () => {
    stubUpstream();
    const res = await app.fetch(new Request("https://gw.local/sync/pull?since=0&limit=1000", { headers: auth }), makeEnv(), NOOP_CTX);
    const body = (await res.json()) as { deltas: Array<{ entity_type: string; server_seq: number }>; max_server_seq: number };
    const seqs = body.deltas.map((d) => d.server_seq);
    expect(seqs).toEqual([...seqs].sort((a, b) => a - b));
    expect(new Set(body.deltas.map((d) => d.entity_type))).toEqual(new Set(SYNCABLE_ENTITIES));
    expect(body.max_server_seq).toBe(SYNCABLE_ENTITIES.length);
  });

  it("con dos tablas caídas reporta la primera en el orden del manifest", async () => {
    const [first, second] = [SYNCABLE_ENTITIES[3], SYNCABLE_ENTITIES[9]];
    stubUpstream(new Set([second, first]));
    const res = await app.fetch(new Request("https://gw.local/sync/pull?since=0", { headers: auth }), makeEnv(), NOOP_CTX);
    expect(res.status).toBe(502);
    const body = (await res.json()) as { error: { message: string } };
    expect(body.error.message).toContain(`(${first})`);
  });
});

describe("/sync/merkle lee las tablas en paralelo", () => {
  it("varias tablas en vuelo a la vez, y la respuesta trae todas", async () => {
    const state = stubUpstream();
    const res = await app.fetch(new Request("https://gw.local/sync/merkle", { headers: auth }), makeEnv(), NOOP_CTX);
    expect(res.status).toBe(200);
    expect(state.maxInFlight).toBeGreaterThan(1);
    const body = (await res.json()) as { entities: Record<string, { count: number }> };
    expect(Object.keys(body.entities)).toEqual([...SYNCABLE_ENTITIES]);
  });

  it("con dos tablas caídas reporta la primera en el orden del manifest", async () => {
    const [first, second] = [SYNCABLE_ENTITIES[2], SYNCABLE_ENTITIES[7]];
    stubUpstream(new Set([second, first]));
    const res = await app.fetch(new Request("https://gw.local/sync/merkle", { headers: auth }), makeEnv(), NOOP_CTX);
    expect(res.status).toBe(502);
    const body = (await res.json()) as { error: { message: string } };
    expect(body.error.message).toContain(`(${first})`);
  });
});
