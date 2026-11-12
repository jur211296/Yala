/**
 * Card sztn: el texto concreto del aviso de actividad de un grupo (`src/groups/notice.ts`). Offline y puro.
 */
import { describe, expect, it } from "vitest";
import { composeGroupNotice, parseGroupPushNotice, type GroupPushNotice } from "../src/groups/notice";
import type { GroupSyncDelta } from "../src/groups/types";
import type { SyncDeltaResult } from "../src/sync/types";

const G = "SplitGroup-1";
const E = "11111111-1111-4111-8111-111111111111";
const S1 = "22222222-2222-4222-8222-222222222222";
const P = "33333333-3333-4333-8333-333333333333";

const NOTICE: GroupPushNotice = {
  actors: { [G]: "María P." },
  groups: { [G]: "Jurpi ❤️" },
  rows: {
    [E]: { concept: "Foppy Pet Store", amount: "S/ 40.60" },
    [S1]: { parent: E },
    [P]: { amount: "S/ 20.00", from: "Ana", to: "Jürgen" },
  },
};

function d(entity_type: string, sync_id: string | null, op: "upsert" | "tombstone" = "upsert", fields?: Record<string, unknown>): GroupSyncDelta {
  return { entity_type, group_id: G, sync_id, op, fields, hlc: "h" } as GroupSyncDelta;
}
const applied = (outcome: unknown): SyncDeltaResult => ({ sync_id: "", status: "applied", outcome });
const NEW = applied({ op: "upsert", inserted: true, applied_units: ["gmoney"] });
const EDIT = (units: string[]) => applied({ op: "upsert", applied_units: units });
const TOMB = applied({ op: "tombstone", applied: true });

describe("composeGroupNotice", () => {
  it("alta de gasto con sus cuotas: UN aviso concreto con quién, concepto, importe y grupo", () => {
    const a = composeGroupNotice(G, [d("split_expenses", E), d("split_shares", S1)], [NEW, NEW], NOTICE);
    expect(a).toEqual({
      title: "Jurpi ❤️",
      locKey: "notifications.groups.push.expenseAdded",
      locArgs: ["María P.", "Foppy Pet Store", "S/ 40.60"],
    });
  });

  it("edición de gasto → expenseEdited; solo la cuota cambiada también es editar ese gasto", () => {
    expect(composeGroupNotice(G, [d("split_expenses", E)], [EDIT(["note"])], NOTICE)?.locKey).toBe(
      "notifications.groups.push.expenseEdited",
    );
    const share = composeGroupNotice(G, [d("split_shares", S1)], [EDIT(["gshare"])], NOTICE);
    expect(share?.locKey).toBe("notifications.groups.push.expenseEdited");
    expect(share?.locArgs).toEqual(["María P.", "Foppy Pet Store", "S/ 40.60"]);
  });

  it("una cuota borrada no cuenta sola; una cuota sin pista usa el expense_id de sus campos", () => {
    expect(composeGroupNotice(G, [d("split_shares", S1, "tombstone")], [TOMB], NOTICE)).toBeNull();
    const noHint: GroupPushNotice = { ...NOTICE, rows: { [E]: NOTICE.rows![E] } };
    const a = composeGroupNotice(
      G,
      [d("split_shares", "44444444-4444-4444-8444-444444444444", "upsert", { expense_id: E })],
      [EDIT(["gshare"])],
      noHint,
    );
    expect(a?.locKey).toBe("notifications.groups.push.expenseEdited");
  });

  it("alta partida entre dos subidas: las cuotas NUEVAS sin su gasto no repiten «editó»", () => {
    // La primera subida trajo el gasto («agregó»); la segunda, solo sus cuotas recién insertadas.
    expect(composeGroupNotice(G, [d("split_shares", S1)], [NEW], NOTICE)).toBeNull();
  });

  it("cambiar el reparto (cuotas borradas + nuevas, sin el gasto) → editó; con el gasto en el lote manda el gasto", () => {
    const old = "55555555-5555-4555-8555-555555555555";
    expect(
      composeGroupNotice(G, [d("split_shares", old, "tombstone"), d("split_shares", S1)], [TOMB, NEW], NOTICE)?.locKey,
    ).toBe("notifications.groups.push.expenseEdited");
    // Alta con sus cuotas: «agregó», no «editó».
    expect(composeGroupNotice(G, [d("split_shares", S1), d("split_expenses", E)], [NEW, NEW], NOTICE)?.locKey).toBe(
      "notifications.groups.push.expenseAdded",
    );
  });

  it("recorta a 120 caracteres sin partir un emoji", () => {
    const long = "a".repeat(119) + "❤️‍🔥";
    const n: GroupPushNotice = { ...NOTICE, groups: { [G]: long } };
    const title = composeGroupNotice(G, [d("split_expenses", E)], [NEW], n)!.title;
    expect(Array.from(title).length).toBe(120);
    expect(title.endsWith("a❤")).toBe(true);
    expect(title.includes("\uFFFD")).toBe(false);
  });

  it("gasto sin concepto → variante sin concepto", () => {
    const n: GroupPushNotice = { ...NOTICE, rows: { [E]: { amount: "S/ 5.00" } } };
    expect(composeGroupNotice(G, [d("split_expenses", E)], [NEW], n)).toEqual({
      title: "Jurpi ❤️",
      locKey: "notifications.groups.push.expenseAddedNoConcept",
      locArgs: ["María P.", "S/ 5.00"],
    });
  });

  it("borrado de gasto → expenseDeleted con quién", () => {
    expect(composeGroupNotice(G, [d("split_expenses", E, "tombstone"), d("split_shares", S1, "tombstone")], [TOMB, TOMB], NOTICE)).toEqual({
      title: "Jurpi ❤️",
      locKey: "notifications.groups.push.expenseDeleted",
      locArgs: ["María P."],
    });
  });

  it("saldo inicial: alta y edición tienen texto propio (por la pista o por el campo del delta)", () => {
    const n: GroupPushNotice = { ...NOTICE, rows: { [E]: { amount: "S/ 40.00", opening: true }, [S1]: { parent: E } } };
    expect(composeGroupNotice(G, [d("split_expenses", E)], [NEW], n)?.locKey).toBe("notifications.groups.push.openingAdded");
    expect(composeGroupNotice(G, [d("split_expenses", E)], [EDIT(["gmoney"])], n)).toEqual({
      title: "Jurpi ❤️",
      locKey: "notifications.groups.push.openingEdited",
      locArgs: ["María P.", "S/ 40.00"],
    });
    expect(composeGroupNotice(G, [d("split_shares", S1)], [EDIT(["gshare"])], n)?.locKey).toBe(
      "notifications.groups.push.openingEdited",
    );
    const byField = composeGroupNotice(G, [d("split_expenses", E, "upsert", { is_opening_balance: true })], [NEW], NOTICE);
    expect(byField?.locKey).toBe("notifications.groups.push.openingAdded");
  });

  it("pagos: alta, edición y borrado", () => {
    expect(composeGroupNotice(G, [d("split_settlements", P)], [NEW], NOTICE)).toEqual({
      title: "Jurpi ❤️",
      locKey: "notifications.groups.push.settlementAdded",
      locArgs: ["María P.", "Ana", "Jürgen", "S/ 20.00"],
    });
    expect(composeGroupNotice(G, [d("split_settlements", P)], [EDIT(["smoney"])], NOTICE)?.locKey).toBe(
      "notifications.groups.push.settlementEdited",
    );
    expect(composeGroupNotice(G, [d("split_settlements", P, "tombstone")], [TOMB], NOTICE)?.locKey).toBe(
      "notifications.groups.push.settlementDeleted",
    );
  });

  it("ajustes del grupo → groupUpdated", () => {
    expect(composeGroupNotice(G, [d("split_groups", null)], [EDIT(["name"])], NOTICE)?.locKey).toBe(
      "notifications.groups.push.groupUpdated",
    );
  });

  it("varias cosas en una subida → «hizo N cambios»", () => {
    const a = composeGroupNotice(G, [d("split_expenses", E), d("split_settlements", P)], [NEW, NEW], NOTICE);
    expect(a).toEqual({ title: "Jurpi ❤️", locKey: "notifications.groups.push.several", locArgs: ["María P.", "2"] });
  });

  it("marcar saldado o cuota pagada, solos, no son noticia", () => {
    expect(composeGroupNotice(G, [d("split_expenses", E)], [EDIT(["is_settled"])], NOTICE)).toBeNull();
    expect(composeGroupNotice(G, [d("split_shares", S1)], [EDIT(["is_paid"])], NOTICE)).toBeNull();
  });

  it("sin quién o sin nombre de grupo (cliente anterior) → null: el llamador manda el genérico", () => {
    expect(composeGroupNotice(G, [d("split_expenses", E)], [NEW], undefined)).toBeNull();
    expect(composeGroupNotice(G, [d("split_expenses", E)], [NEW], { groups: { [G]: "Jurpi" } })).toBeNull();
  });

  it("solo cuentan los deltas APLICADOS y del grupo pedido", () => {
    const noop: SyncDeltaResult = { sync_id: E, status: "noop" };
    expect(composeGroupNotice(G, [d("split_expenses", E)], [noop], NOTICE)).toBeNull();
    const other = { ...d("split_expenses", E), group_id: "SplitGroup-2" } as GroupSyncDelta;
    expect(composeGroupNotice(G, [other], [NEW], NOTICE)).toBeNull();
  });
});

describe("parseGroupPushNotice", () => {
  it("descarta lo que no es string y baja los sync_id a minúsculas", () => {
    const n = parseGroupPushNotice({
      actors: { [G]: "Ana", x: 3 },
      groups: { [G]: "Jurpi" },
      rows: { [E.toUpperCase()]: { concept: "Taxi", amount: 7, opening: "sí" } },
    });
    expect(n?.actors).toEqual({ [G]: "Ana" });
    expect(n?.rows?.[E]).toEqual({ concept: "Taxi" });
  });

  it("basura → undefined", () => {
    expect(parseGroupPushNotice(undefined)).toBeUndefined();
    expect(parseGroupPushNotice("x")).toBeUndefined();
  });
});
