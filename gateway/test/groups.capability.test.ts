/**
 * Capability-set por versión del manifest de GRUPOS (`since`) — OFFLINE, contra el manifest real. Molde de
 * `manifest.capability.test.ts` (canal personal).
 *
 * Por qué existe (ticket `groups-canal-sin-capability-set`, 2026-10-24). Hasta ese día el canal de Grupos no declaraba
 * su versión de columnas: el cliente no mandaba `X-Yala-Capability-Set` y `merkleColumnsGroup` hasheaba TODAS las del
 * manifest. Como el canon serializa el NULL como `key:null`, una columna nueva cambiaba la hoja de CADA fila de un
 * teléfono que no la conocía ⇒ divergencia falsa en el 100 % de sus grupos. `split_groups.budget_limit_amount` (g14_01)
 * lo esquivó subiendo `canon_version` a `c2`, lo que apagó el Merkle de Grupos a todo el parque viejo. Estos casos
 * fijan lo que lo sustituye:
 *  - sin cabecera = v2, CONGELADO (todo iOS publicado ya conoce el presupuesto y no manda la cabecera);
 *  - `v1` poda `budget_limit_amount` en el pull y en el Merkle; `v2` la trae;
 *  - `/groups/pull` y `/groups/merkle` anuncian `manifest_version`.
 *  - v3 (g29_01, card xi74, 2026-11-02): `split_expenses.last_edited_by_member_key` y
 *    `split_settlements.recorded_by_member_key`; `v2` (y la ausencia de cabecera) no las bajan ni las hashean.
 *
 * Los casos de rutas pasan por `app.fetch` con `verifyUserToken` mockeado y `fetch` stubbeado (molde de
 * `groups.attest401.test.ts`), así que no tocan la red. A mano: `npm test -- test/groups.capability.test.ts`.
 */
import { afterEach, describe, expect, it, vi } from "vitest";
import { canonRowC1Group, merkleColumnsGroup } from "../src/groups/canon";
import {
  GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER,
  GROUP_MANIFEST_VERSION,
  groupColumnsUpTo,
  groupManifest,
  projectGroupRowToDelta,
  resolveGroupCapabilitySet,
} from "../src/groups/manifest";
import { entityHash, hex, leafChannel1 } from "../src/sync/merkle";
import type { Env } from "../src/env";
import type { GroupMerkleResponse, GroupPullResponse } from "../src/groups/types";

const SUB = "11111111-2222-3333-4444-555555555555";
const VALID = "valid-user-jwt";
const GID = "grp-capability-unit-0001";
const HLC = "2026-10-24T12:00:00.000Z-0001-00000000000000aa";

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

/** Las 11 columnas de `split_groups` que existían antes de `budget_limit_amount` (G2). Árbitro independiente del
 *  manifest: si alguien pone `since` a otra columna, o se la quita al presupuesto, los casos de v1 caen. */
const SPLIT_GROUPS_V1 = [
  "name",
  "icon_name",
  "color_hex",
  "currency_code",
  "simplify_debts",
  "show_debts_in_single_currency",
  "members_can_invite",
  "default_split_type",
  "is_archived",
  "is_hidden_for_all",
  "created_at",
];

/** Fila de `split_groups` tal como la devuelve `groups_pull_rows_split_groups` (amount como string escala 4). */
const GROUP_ROW: Record<string, unknown> = {
  group_id: GID,
  name: "Viaje a Cusco",
  icon_name: "airplane",
  color_hex: "#6366F1",
  currency_code: "PEN",
  simplify_debts: true,
  show_debts_in_single_currency: false,
  members_can_invite: true,
  default_split_type: "equal",
  is_archived: false,
  is_hidden_for_all: false,
  budget_limit_amount: "1500.0000",
  created_at: "2026-10-01T10:00:00.000Z",
  field_hlcs: { name: HLC, budget_limit_amount: HLC },
  hlc: HLC,
  deleted: false,
  server_seq: 7,
  schema_version: 1,
};

function makeEnv(): Env {
  return {
    ENVIRONMENT: "staging",
    ENFORCE: "observe",
    SUPABASE_URL: "https://capability-unit.local",
    SUPABASE_ANON_KEY: "anon-key-unit",
    GROUPS_ENC_KEY: "enc-key-unit-0123456789",
    GROUPS_BACKEND_ROLLOUT_PERCENT: "100",
    JWT_SIGNING_SECRET: "jwt-signing-secret-unit",
  } as unknown as Env;
}

/** Fila de `split_expenses` tal como la devuelve `groups_pull_rows_split_expenses` tras g29_01: con autor. */
const EXPENSE_ID = "7b1e2f0a-1111-4222-8333-944455556666";
const EXPENSE_ROW: Record<string, unknown> = {
  group_id: GID,
  sync_id: EXPENSE_ID,
  amount: "40.0000",
  currency_code: "PEN",
  expense_description: "Cena",
  note: null,
  date: "2026-11-01T20:00:00.000Z",
  created_at: "2026-11-01T20:00:00.000Z",
  paid_by_member_key: "member-ana",
  split_type: "equal",
  is_settled: false,
  is_opening_balance: false,
  subcategory_name: null,
  last_edited_by_member_key: "member-jurgen",
  field_hlcs: { gmoney: HLC, expense_description: HLC, last_edited_by_member_key: HLC },
  hlc: HLC,
  deleted: false,
  server_seq: 8,
  schema_version: 1,
};

/** PostgREST de mentira: una membresía (GID), la fila de `split_groups` y la de `split_expenses`; el resto, vacías. */
function stubUpstream(row: Record<string, unknown> = GROUP_ROW, expense: Record<string, unknown> = EXPENSE_ROW): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: unknown, init?: RequestInit) => {
      const url = typeof input === "string" ? input : ((input as Request).url ?? String(input));
      const json = (body: unknown) =>
        new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
      if (url.includes("/rest/v1/group_members?")) return json([{ group_id: GID }]);
      if (url.endsWith("/rest/v1/rpc/groups_pull_rows_split_groups")) {
        const args = JSON.parse(String(init?.body ?? "{}")) as { p_after_seq?: number };
        return json((args.p_after_seq ?? 0) < Number(row.server_seq) ? [row] : []);
      }
      if (url.endsWith("/rest/v1/rpc/groups_pull_rows_split_expenses")) {
        const args = JSON.parse(String(init?.body ?? "{}")) as { p_after_seq?: number };
        return json((args.p_after_seq ?? 0) < Number(expense.server_seq) ? [expense] : []);
      }
      return json([]);
    }),
  );
}

async function pull(capability?: string): Promise<GroupPullResponse> {
  const headers: Record<string, string> = { Authorization: `Bearer ${VALID}` };
  if (capability !== undefined) headers["X-Yala-Capability-Set"] = capability;
  const res = await app.fetch(new Request("https://gw.local/groups/pull", { headers }), makeEnv(), NOOP_CTX);
  expect(res.status).toBe(200);
  return (await res.json()) as GroupPullResponse;
}

async function merkle(capability?: string): Promise<GroupMerkleResponse> {
  const headers: Record<string, string> = { Authorization: `Bearer ${VALID}` };
  if (capability !== undefined) headers["X-Yala-Capability-Set"] = capability;
  const res = await app.fetch(
    new Request(`https://gw.local/groups/merkle?group_id=${GID}`, { headers }),
    makeEnv(),
    NOOP_CTX,
  );
  expect(res.status).toBe(200);
  return (await res.json()) as GroupMerkleResponse;
}

/** entityHash de `split_groups` con UNA fila, hasheada con las columnas dadas: el oráculo, con las primitivas A-4. */
async function splitGroupsHash(columns: string[]): Promise<string> {
  const payload = canonRowC1Group("split_groups", GROUP_ROW, columns);
  return hex(await entityHash([{ syncId: GID.toLowerCase(), leaf: await leafChannel1(GID.toLowerCase(), payload) }]));
}

/** entityHash de `split_expenses` con la fila de `EXPENSE_ROW`, hasheada con las columnas dadas. */
async function splitExpensesHash(columns: string[]): Promise<string> {
  const payload = canonRowC1Group("split_expenses", EXPENSE_ROW, columns);
  const id = EXPENSE_ID.toLowerCase();
  return hex(await entityHash([{ syncId: id, leaf: await leafChannel1(id, payload) }]));
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("capability-set de Grupos por versión del manifest", () => {
  it("el manifest de Grupos va por la v3: el presupuesto en v2 y los dos autores en v3", () => {
    expect(GROUP_MANIFEST_VERSION).toBe(3);
    expect(GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER).toBe(2);
    const later: string[] = [];
    for (const [entity, spec] of Object.entries(groupManifest.entities)) {
      for (const [col, c] of Object.entries(spec.columns) as Array<[string, { since?: number }]>) {
        expect(c.since ?? 1).toBeLessThanOrEqual(GROUP_MANIFEST_VERSION);
        if ((c.since ?? 1) > 1) later.push(`${entity}.${col}@${c.since}`);
      }
    }
    expect(later).toEqual([
      "split_groups.budget_limit_amount@2",
      "split_expenses.last_edited_by_member_key@3",
      "split_settlements.recorded_by_member_key@3",
    ]);
  });

  it("v1 = exactamente las columnas de antes en split_groups; el resto de tablas, sin las de v3", () => {
    const cap = resolveGroupCapabilitySet("v1");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.split_groups ?? [])].sort()).toEqual([...SPLIT_GROUPS_V1].sort());
    for (const [entity, spec] of Object.entries(groupManifest.entities)) {
      if (entity === "split_groups") continue;
      const v1 = Object.entries(spec.columns as Record<string, { since?: number }>)
        .filter(([, c]) => (c.since ?? 1) <= 1)
        .map(([col]) => col);
      expect([...(cap.columns![entity] ?? [])].sort()).toEqual(v1.sort());
    }
  });

  it("sin cabecera = v2, congelado aunque el manifest suba: desde la v3 ya no es el set completo", () => {
    // La ausencia es la proyección de v2, no «completo»: todo iOS publicado hasta 2.1 la omite y no conoce los autores.
    for (const raw of [null, undefined, ""]) {
      expect(resolveGroupCapabilitySet(raw)).toEqual({ columns: groupColumnsUpTo(2) });
    }
    expect(groupColumnsUpTo(2).split_expenses.has("last_edited_by_member_key")).toBe(false);
    expect(groupColumnsUpTo(2).split_settlements.has("recorded_by_member_key")).toBe(false);
    // Lo que fija el «congelado»: la ausencia es la proyección de v2, no la de la versión del Worker.
    expect(groupColumnsUpTo(GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER).split_groups.has("budget_limit_amount")).toBe(true);
  });

  it("v3, vN mayor y full = set completo; v2 sin los autores; v0 se lee como v1; un valor ilegible = completo", () => {
    for (const raw of ["v3", "v99", "full", "basura", "{no-json"]) {
      expect(resolveGroupCapabilitySet(raw)).toEqual({});
    }
    expect(resolveGroupCapabilitySet("v2")).toEqual({ columns: groupColumnsUpTo(2) });
    expect(resolveGroupCapabilitySet("v0")).toEqual({ columns: groupColumnsUpTo(1) });
  });

  it("el pull de v1 no baja budget_limit_amount ni su unidad; el de v2 y el de sin cabecera, sí", () => {
    const stored = GROUP_ROW.field_hlcs as Record<string, string>;
    const v1 = projectGroupRowToDelta("split_groups", GROUP_ROW, stored, resolveGroupCapabilitySet("v1"));
    expect(v1.fields).not.toHaveProperty("budget_limit_amount");
    expect(v1.field_hlcs).not.toHaveProperty("budget_limit_amount");
    expect(v1.fields.name).toBe("Viaje a Cusco");
    expect(v1.field_hlcs.name).toBe(HLC);
    for (const raw of ["v2", null]) {
      const p = projectGroupRowToDelta("split_groups", GROUP_ROW, stored, resolveGroupCapabilitySet(raw));
      expect(p.fields.budget_limit_amount).toBe("1500.0000");
      expect(p.field_hlcs.budget_limit_amount).toBe(HLC);
    }
  });

  it("un grupo de coherencia que el cliente no conoce entero se poda entero (gshare sin amount = sin el trío)", () => {
    // Ninguna columna agrupada tiene `since` hoy, así que la poda grupo-entero-o-nada solo se ejerce con el formato
    // explícito. Sin este caso, quitar esa poda pasaba en verde.
    const cap = resolveGroupCapabilitySet(JSON.stringify({ split_shares: ["expense_id", "member_key", "is_paid"] }));
    const row = {
      sync_id: "9d2f3a1b-1111-4222-8333-944455556666",
      expense_id: "8c1e2f0a-1111-4222-8333-944455556666",
      member_key: "member-1",
      amount: "12.5000",
      is_paid: false,
    };
    const p = projectGroupRowToDelta("split_shares", row, { gshare: HLC, is_paid: HLC }, cap);
    expect(p.fields).toEqual({ is_paid: false });
    expect(p.field_hlcs).toEqual({ is_paid: HLC });
    expect(merkleColumnsGroup("split_shares", cap)).toEqual(["is_paid"]);
  });

  it("el Merkle de v1 no hashea budget_limit_amount y su payload no lleva la key; el de v2 sí, también como null", () => {
    const v1 = merkleColumnsGroup("split_groups", resolveGroupCapabilitySet("v1"));
    expect([...v1].sort()).toEqual([...SPLIT_GROUPS_V1].sort());
    expect(canonRowC1Group("split_groups", { ...GROUP_ROW, budget_limit_amount: null }, v1)).not.toContain(
      "budget_limit_amount",
    );
    // Control: con v2 la key entra aunque sea NULL — lo que rompería a un teléfono que no la conoce sin la poda.
    const v2 = merkleColumnsGroup("split_groups", resolveGroupCapabilitySet("v2"));
    expect(v2).toContain("budget_limit_amount");
    expect(canonRowC1Group("split_groups", { ...GROUP_ROW, budget_limit_amount: null }, v2)).toContain(
      '"budget_limit_amount":null',
    );
    // Y las otras tablas no cambian entre v1 y v2 (en ellas solo hay columnas de v1 y de v3).
    for (const entity of Object.keys(groupManifest.entities)) {
      if (entity === "split_groups") continue;
      expect(merkleColumnsGroup(entity, resolveGroupCapabilitySet("v1"))).toEqual(
        merkleColumnsGroup(entity, resolveGroupCapabilitySet("v2")),
      );
    }
  });
});

describe("las rutas de Grupos leen la cabecera y anuncian su versión", () => {
  it("GET /groups/pull con v1 poda budget_limit_amount y anuncia manifest_version 3", async () => {
    stubUpstream();
    const body = await pull("v1");
    expect(body.manifest_version).toBe(3);
    const delta = body.deltas.find((d) => d.entity_type === "split_groups");
    expect(delta).toBeDefined();
    expect(delta!.fields).not.toHaveProperty("budget_limit_amount");
    expect(delta!.field_hlcs).not.toHaveProperty("budget_limit_amount");
    expect(delta!.fields.name).toBe("Viaje a Cusco");
  });

  it("GET /groups/pull con v2 y sin cabecera trae budget_limit_amount", async () => {
    for (const capability of ["v2", undefined]) {
      stubUpstream();
      const body = await pull(capability);
      expect(body.manifest_version).toBe(3);
      const delta = body.deltas.find((d) => d.entity_type === "split_groups");
      expect(delta?.fields.budget_limit_amount).toBe("1500.0000");
      expect(delta?.field_hlcs.budget_limit_amount).toBe(HLC);
      vi.unstubAllGlobals();
    }
  });

  it("GET /groups/merkle con v1 hashea split_groups sin budget_limit_amount y anuncia manifest_version 3", async () => {
    stubUpstream();
    const body = await merkle("v1");
    expect(body.manifest_version).toBe(3);
    expect(body.entities.split_groups.hash).toBe(await splitGroupsHash(SPLIT_GROUPS_V1));
    // Control: el hash de v1 no es el de las 12 columnas (si coincidieran, el caso no mediría la poda).
    expect(body.entities.split_groups.hash).not.toBe(await splitGroupsHash([...SPLIT_GROUPS_V1, "budget_limit_amount"]));
  });

  it("GET /groups/merkle con v2 y sin cabecera hashea las 12 columnas (el root de hoy no cambia)", async () => {
    const full = await splitGroupsHash([...SPLIT_GROUPS_V1, "budget_limit_amount"]);
    const roots: string[] = [];
    for (const capability of ["v2", undefined]) {
      stubUpstream();
      const body = await merkle(capability);
      expect(body.manifest_version).toBe(3);
      expect(body.entities.split_groups.hash).toBe(full);
      roots.push(body.root);
      vi.unstubAllGlobals();
    }
    expect(roots[0]).toBe(roots[1]);
  });
});

describe("v3 · el autor del gasto (g29_01, card xi74)", () => {
  it("el pull de v3 baja last_edited_by_member_key con su HLC; el de v2 y el de sin cabecera, no", async () => {
    stubUpstream();
    const v3 = await pull("v3");
    const d3 = v3.deltas.find((d) => d.entity_type === "split_expenses");
    expect(d3?.fields.last_edited_by_member_key).toBe("member-jurgen");
    expect(d3?.field_hlcs.last_edited_by_member_key).toBe(HLC);
    expect(d3?.fields.paid_by_member_key).toBe("member-ana");
    vi.unstubAllGlobals();
    for (const capability of ["v2", undefined]) {
      stubUpstream();
      const body = await pull(capability);
      const d = body.deltas.find((x) => x.entity_type === "split_expenses");
      expect(d).toBeDefined();
      expect(d!.fields).not.toHaveProperty("last_edited_by_member_key");
      expect(d!.field_hlcs).not.toHaveProperty("last_edited_by_member_key");
      expect(d!.fields.paid_by_member_key).toBe("member-ana");
      vi.unstubAllGlobals();
    }
  });

  it("el Merkle de v2 hashea split_expenses sin el autor; el de v3, con él", async () => {
    const v2Columns = merkleColumnsGroup("split_expenses", resolveGroupCapabilitySet("v2"));
    expect(v2Columns).not.toContain("last_edited_by_member_key");
    const full = merkleColumnsGroup("split_expenses");
    expect(full).toContain("last_edited_by_member_key");
    stubUpstream();
    const v2 = await merkle("v2");
    expect(v2.entities.split_expenses.hash).toBe(await splitExpensesHash(v2Columns));
    vi.unstubAllGlobals();
    stubUpstream();
    const v3 = await merkle("v3");
    expect(v3.entities.split_expenses.hash).toBe(await splitExpensesHash(full));
    // Control: si los dos hashes coincidieran, el caso no mediría la poda.
    expect(v3.entities.split_expenses.hash).not.toBe(v2.entities.split_expenses.hash);
  });
});
