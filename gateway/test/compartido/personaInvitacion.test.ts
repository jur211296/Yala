/**
 * Compartido lote 3 (g38_01): una persona es un grupo de dos que nace con su sitio reservado, y quien abre su enlace
 * entra sin aprobación. Unit OFFLINE: `verifyUserToken` mockeado y `fetch` stubbeado; `callRpc` queda REAL.
 *
 * Qué fija:
 * 1. `create_person_group` pasa la allowlist con SUS params (lo desconocido se descarta) y recibe la llave inyectada
 *    (escribe el nombre de la persona y el de su sitio, columnas †). Sin llave, 503 sin tocar PostgREST.
 * 2. El aviso de membresía de una persona: entra activa (`is_person`, `changed`) → avisa a los ADMINS (en una persona,
 *    su creador). Re-tap (`changed:false`) → nada. Y un `active` SIN `is_person` (la rama no-op de un grupo normal)
 *    sigue sin avisar a nadie, como antes.
 * La rama SQL (sitio reservado, sin aprobación, sin tercero, grupo normal intacto) la fija el banco
 * `bash qa/cloud/g38_01-remote.sh staging test`, que corre contra la base real dentro de una transacción deshecha.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt";
const KEY = "enc-key-unit-0123456789";
const SUPA = "https://compartido-unit.local";

vi.mock("../../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === VALID ? { sub: SUB, token } : null)),
  };
});

const { default: app } = await import("../../src/index");
const { notifyMembershipChange } = await import("../../src/groups/rpc");

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: SUPA,
    SUPABASE_ANON_KEY: "anon-key-unit",
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    GROUPS_ENC_KEY: KEY,
    ...overrides,
  } as unknown as Env;
}

interface Upstream {
  url: string;
  fn: string | null;
  args: Record<string, unknown> | null;
}

function stubUpstream(rpcBody: unknown = {}): Upstream[] {
  const calls: Upstream[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      const m = /\/rest\/v1\/rpc\/([^?]+)/.exec(url);
      const args = typeof init?.body === "string" ? (JSON.parse(init.body) as Record<string, unknown>) : null;
      calls.push({ url, fn: m ? m[1] : null, args });
      return new Response(JSON.stringify(m ? rpcBody : []), { status: 200, headers: { "content-type": "application/json" } });
    }),
  );
  return calls;
}

const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

async function rpc(env: Env, fn: string, body: Record<string, unknown>): Promise<Response> {
  return await app.fetch(
    new Request(`https://gw.local/groups/rpc/${fn}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${VALID}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    }),
    env,
    NOOP_CTX,
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("create_person_group — el alta de una persona pasa por el Worker", () => {
  const BODY = {
    p_group_id: "SplitGroup-unit-persona",
    p_name: "Marta",
    p_currency_code: "PEN",
    p_icon_name: "person.fill",
    p_color_hex: "#14B8A6",
    p_display_name: "Jürgen",
    p_person_member_key: "0f3c1a52-1111-4222-8333-944455556666",
    // Lo que el cliente nunca debe poder colar: se descarta en silencio.
    p_key: "inyectada-por-el-cliente",
    p_user_id: "otro",
    p_members_can_invite: true,
  };

  it("llega a PostgREST con sus params, sin lo desconocido y con la llave del Worker", async () => {
    const calls = stubUpstream({ group_id: BODY.p_group_id, member_key: SUB, person_member_key: BODY.p_person_member_key });
    const res = await rpc(makeEnv(), "create_person_group", BODY);
    expect(res.status).toBe(200);
    const call = calls.find((c) => c.fn === "create_person_group");
    expect(call).toBeDefined();
    expect(call?.args).toEqual({
      p_group_id: BODY.p_group_id,
      p_name: "Marta",
      p_currency_code: "PEN",
      p_icon_name: "person.fill",
      p_color_hex: "#14B8A6",
      p_display_name: "Jürgen",
      p_person_member_key: BODY.p_person_member_key,
      p_key: KEY,
    });
  });

  it("sin la llave de cifrado: 503 y PostgREST no se toca", async () => {
    const calls = stubUpstream({});
    const res = await rpc(makeEnv({ GROUPS_ENC_KEY: "" } as Partial<Env>), "create_person_group", BODY);
    expect(res.status).toBe(503);
    expect(calls.length).toBe(0);
  });

  it("con el canal de Grupos apagado (kill-switch): 403, como create_group", async () => {
    const calls = stubUpstream({});
    const res = await rpc(makeEnv({ GROUPS_BACKEND_ROLLOUT_PERCENT: "0" } as Partial<Env>), "create_person_group", BODY);
    expect(res.status).toBe(403);
    expect(calls.length).toBe(0);
  });
});

describe("join_group de una persona — avisa a quien la creó, sin pedir aprobación", () => {
  function fakeCtx(env: Env, sink: Promise<unknown>[]) {
    return {
      env,
      get executionCtx() {
        return { waitUntil: (p: Promise<unknown>) => sink.push(p), passThroughOnException() {} };
      },
    } as unknown as Parameters<typeof notifyMembershipChange>[0];
  }

  /** Env con push encendido. El resolver de tokens contesta vacío: basta con ver a QUIÉN se le pidieron tokens. */
  function pushEnv(): Env {
    return makeEnv({
      APNS_KEY_ID: "TESTKEYID1",
      APNS_AUTH_KEY: "pem-no-usada-sin-tokens",
      PUSH_ROLE_JWT: "machine.jwt.token",
      APPLE_TEAM_ID: "3WKFFVD66J",
      APPLE_BUNDLE_IDS: "com.jurgenschmidt.yala.dev",
    } as Partial<Env>);
  }

  const AUTH = { userJWT: "dummy.jwt.token", sub: "u-marta" };

  it("entra activa (is_person, changed) → pide los tokens de los ADMINS", async () => {
    const calls = stubUpstream([]);
    const pending: Promise<unknown>[] = [];
    notifyMembershipChange(fakeCtx(pushEnv(), pending), AUTH, "join_group", {
      group_id: "g-persona",
      member_key: "mk-sitio",
      status: "active",
      changed: true,
      is_person: true,
    });
    await Promise.all(pending);
    expect(calls.some((c) => c.fn === "get_group_admin_push_tokens")).toBe(true);
    expect(calls.some((c) => c.fn === "get_group_push_tokens")).toBe(false);
  });

  it("re-toca su enlace ya dentro (changed:false) → no avisa a nadie", async () => {
    const calls = stubUpstream([]);
    const pending: Promise<unknown>[] = [];
    notifyMembershipChange(fakeCtx(pushEnv(), pending), AUTH, "join_group", {
      group_id: "g-persona",
      member_key: "mk-sitio",
      status: "active",
      changed: false,
      is_person: true,
    });
    await Promise.all(pending);
    expect(calls.length).toBe(0);
  });

  it("un `active` de un grupo NORMAL (rama no-op, sin is_person) sigue sin avisar", async () => {
    const calls = stubUpstream([]);
    const pending: Promise<unknown>[] = [];
    notifyMembershipChange(fakeCtx(pushEnv(), pending), AUTH, "join_group", {
      group_id: "g-viaje",
      member_key: "mk-1",
      status: "active",
      changed: false,
    });
    await Promise.all(pending);
    expect(calls.length).toBe(0);
  });
});
