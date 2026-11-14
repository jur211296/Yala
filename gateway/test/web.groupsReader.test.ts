/**
 * Yala web, lote 3 · `readGroupsForWeb` (la entrada interna `WebGroupsReader`). Unit OFFLINE: se mockea
 * `verifyUserToken` y se stubbea `fetch` de PostgREST (molde `groups.ownedGroups.test.ts`).
 *
 * Lo que fija: solo staging con el interruptor puesto; solo el rol de la web (un token `authenticated` por aquí se
 * saltaría App Attest); el JWT viaja tal cual y la llave va en el cuerpo, nunca en la URL; solo los RPC lectores; y lo
 * borrado no sale.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Env } from "../src/env";

const SUB = "11111111-2222-3333-4444-555555555555";

function jwt(role: string): string {
  const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
  return `${b64({ alg: "ES256" })}.${b64({ sub: SUB, role })}.firma`;
}
const WEB = jwt("yala_mcp_reader");
const PHONE = jwt("authenticated");

vi.mock("../src/sync/userauth", async (importOriginal) => {
  const actual = await importOriginal<typeof import("../src/sync/userauth")>();
  return {
    ...actual,
    verifyUserToken: vi.fn(async (_env: Env, token: string) => (token === WEB || token === PHONE ? { sub: SUB, token } : null)),
  };
});

const { readGroupsForWeb } = await import("../src/web/groupsReader");

const env = {
  ENVIRONMENT: "staging",
  SUPABASE_URL: "https://web-reader.local",
  SUPABASE_ANON_KEY: "anon",
  GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
  GROUPS_ENC_KEY: "enc-key-unit-0123456789",
  WEB_GROUPS_READER: "on",
} as unknown as Env;

interface Call {
  url: string;
  auth: string | null;
  body: Record<string, unknown> | null;
}

function stub(rpcStatus = 200): Call[] {
  const calls: Call[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = String(input);
      const headers = new Headers(init?.headers);
      const body = init?.body ? (JSON.parse(String(init.body)) as Record<string, unknown>) : null;
      calls.push({ url, auth: headers.get("Authorization"), body });
      if (url.includes("/rest/v1/group_members?")) {
        return Response.json([{ group_id: "g1", member_key: "m-ana" }]);
      }
      if (url.includes("/rpc/")) {
        if (rpcStatus !== 200) return new Response("boom", { status: rpcStatus });
        const fn = url.split("/rpc/")[1];
        if (fn === "groups_pull_rows_split_groups") return Response.json([{ group_id: "g1", name: "Viaje", server_seq: 1 }]);
        if (fn === "groups_pull_rows_split_expenses")
          return Response.json([
            { group_id: "g1", sync_id: "e1", amount: "10.0000", deleted: false, server_seq: 2 },
            { group_id: "g1", sync_id: "e2", amount: "99.0000", deleted: true, server_seq: 3 },
          ]);
        return Response.json([]);
      }
      return new Response("no", { status: 404 });
    }),
  );
  return calls;
}

afterEach(() => vi.unstubAllGlobals());

describe("readGroupsForWeb", () => {
  it("lee los grupos activos con el token de la web, por los RPC lectores, y sin lo borrado", async () => {
    const calls = stub();
    const r = await readGroupsForWeb(env, WEB);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.groups).toHaveLength(1);
    expect(r.groups[0].me).toBe("m-ana");
    expect(r.groups[0].group?.name).toBe("Viaje");
    expect(r.groups[0].expenses.map((e) => e.sync_id)).toEqual(["e1"]);
    // El JWT viaja tal cual; la llave va en el cuerpo y nunca en la URL.
    for (const c of calls) {
      expect(c.auth).toBe(`Bearer ${WEB}`);
      expect(c.url).not.toContain("enc-key");
    }
    const rpcs = calls.filter((c) => c.url.includes("/rpc/"));
    expect(rpcs.map((c) => c.url.split("/rpc/")[1]).sort()).toEqual([
      "groups_pull_rows_group_members",
      "groups_pull_rows_split_expenses",
      "groups_pull_rows_split_groups",
      "groups_pull_rows_split_settlements",
      "groups_pull_rows_split_shares",
    ]);
    expect(rpcs.every((c) => c.body?.p_key === "enc-key-unit-0123456789" && c.body?.p_group_id === "g1")).toBe(true);
    // Solo membresías activas y propias.
    const mem = calls.find((c) => c.url.includes("/group_members?"));
    expect(mem?.url).toContain(`user_id=eq.${SUB}`);
    expect(mem?.url).toContain("status=eq.active");
    expect(mem?.url).toContain("order=joined_at.desc");
    expect(mem?.url).not.toContain("group_id=eq.");
  });

  it("con un grupo pedido, solo lee ese (el detalle)", async () => {
    const calls = stub();
    const r = await readGroupsForWeb(env, WEB, "g1");
    expect(r.ok).toBe(true);
    expect(calls.find((c) => c.url.includes("/group_members?"))?.url).toContain("group_id=eq.g1");
  });

  it("rechaza el token del iPhone: por aquí se saltaría App Attest", async () => {
    const calls = stub();
    expect(await readGroupsForWeb(env, PHONE)).toEqual({ ok: false, error: "role" });
    expect(calls).toHaveLength(0);
  });

  it("rechaza un token que no verifica", async () => {
    stub();
    expect(await readGroupsForWeb(env, jwt("yala_mcp_reader") + "x")).toEqual({ ok: false, error: "token" });
  });

  it("está apagada sin el interruptor y en producción", async () => {
    const calls = stub();
    expect(await readGroupsForWeb({ ...env, WEB_GROUPS_READER: undefined } as Env, WEB)).toEqual({ ok: false, error: "disabled" });
    expect(await readGroupsForWeb({ ...env, ENVIRONMENT: "production" } as Env, WEB)).toEqual({ ok: false, error: "disabled" });
    expect(calls).toHaveLength(0);
  });

  it("respeta el kill-switch de Grupos y la falta de llave", async () => {
    stub();
    expect(await readGroupsForWeb({ ...env, GROUPS_BACKEND_ROLLOUT_PERCENT: "0" } as Env, WEB)).toEqual({ ok: false, error: "groups_off" });
    expect(await readGroupsForWeb({ ...env, GROUPS_ENC_KEY: undefined } as Env, WEB)).toEqual({ ok: false, error: "no_key" });
  });

  it("una tabla que llena todas las páginas marca la lectura como cortada", async () => {
    const full = Array.from({ length: 1000 }, (_, i) => ({ group_id: "g1", sync_id: `s${i}`, amount: "1.0000", deleted: false, server_seq: i + 1 }));
    vi.stubGlobal(
      "fetch",
      vi.fn(async (input: unknown) => {
        const url = String(input);
        if (url.includes("/rest/v1/group_members?")) return Response.json([{ group_id: "g1", member_key: "m-ana" }]);
        if (url.endsWith("/rpc/groups_pull_rows_split_shares")) return Response.json(full);
        return Response.json([]);
      }),
    );
    const r = await readGroupsForWeb(env, WEB);
    expect(r.ok && r.truncated).toBe(true);
  });

  it("un RPC que falla no devuelve una lista a medias", async () => {
    stub(500);
    expect(await readGroupsForWeb(env, WEB)).toEqual({ ok: false, error: "upstream" });
  });
});
