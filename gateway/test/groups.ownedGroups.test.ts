/**
 * Card y1cd · `/groups/pull` dice de qué grupos es dueño quien llama (`owned_groups`). Unit OFFLINE: se mockea
 * `verifyUserToken` y se stubbea `fetch` de PostgREST (molde `groups.enckey.test.ts`).
 *
 * El caso que lo pidió (2026-10-27): el dueño de «Matri» borró su cuenta, `groups_forget_user` pasó la propiedad a Pia
 * y la hizo admin, y el teléfono de Pia seguía sin «Invitar»: decide «dueño» con un `isOwner` local que el pull no
 * corregía (`owner_user_id` no está en el manifest).
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";

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

const env = {
  ENVIRONMENT: "staging",
  ENFORCE: "observe",
  SUPABASE_URL: "https://owned-unit.local",
  SUPABASE_ANON_KEY: "anon",
  GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
  GROUPS_ENC_KEY: "enc-key-unit-0123456789",
} as unknown as Env;
const NOOP_CTX = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;

/** PostgREST de mentira: memberships, dueños y lectores vacíos. Guarda las URLs de las lecturas de tabla. */
function stub(members: string[], owned: string[], ownedStatus = 200): string[] {
  const tableReads: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      if (url.includes("/rest/v1/rpc/")) return Response.json([]);
      tableReads.push(url);
      if (url.includes("/rest/v1/group_members")) return Response.json(members.map((g) => ({ group_id: g })));
      if (url.includes("/rest/v1/split_groups")) {
        return ownedStatus === 200 ? Response.json(owned.map((g) => ({ group_id: g }))) : new Response("{}", { status: ownedStatus });
      }
      return Response.json([]);
    }),
  );
  return tableReads;
}

async function pull(): Promise<Response> {
  return await app.fetch(
    new Request("https://gw.local/groups/pull", { headers: { Authorization: `Bearer ${VALID}` } }), env, NOOP_CTX);
}

afterEach(() => vi.unstubAllGlobals());

describe("/groups/pull · owned_groups (card y1cd)", () => {
  it("devuelve los grupos de los que quien llama es dueño, y pregunta por SU sub", async () => {
    const reads = stub(["g-a", "g-b"], ["g-b"]);
    const res = await pull();
    expect(res.status).toBe(200);
    const body = (await res.json()) as { memberships: string[]; owned_groups: string[] };
    expect(body.memberships).toEqual(["g-a", "g-b"]);
    expect(body.owned_groups).toEqual(["g-b"]);
    const ownerRead = reads.find((u) => u.includes("/rest/v1/split_groups"));
    expect(ownerRead).toContain(`owner_user_id=eq.${SUB}`);
    expect(ownerRead).toContain("deleted=eq.false");
  });

  it("sin grupos propios: lista vacía, nunca ausente (vacío dice «no eres dueño de ninguno»)", async () => {
    stub(["g-a"], []);
    const body = (await (await pull()).json()) as { owned_groups: string[] };
    expect(body.owned_groups).toEqual([]);
  });

  it("un grupo propio que ya no está en memberships no se anuncia", async () => {
    stub(["g-a"], ["g-a", "g-zombi"]);
    const body = (await (await pull()).json()) as { owned_groups: string[] };
    expect(body.owned_groups).toEqual(["g-a"]);
  });

  it("si la lectura de dueños falla, el pull falla (502), no anuncia «no eres dueño»", async () => {
    stub(["g-a"], ["g-a"], 500);
    const res = await pull();
    expect(res.status).toBe(502);
  });
});
