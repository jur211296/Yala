/**
 * Capability-set por versión del manifest (`since`) — OFFLINE, contra el manifest real.
 *
 * Por qué existe. `accounts.parent_account_id` (tarjeta con varias divisas, 2026-10-18) es la primera columna
 * personal añadida después del lanzamiento. Hasta ese día `v1` —lo que manda todo iOS hasta 2.1— era el set
 * COMPLETO, y el Merkle serializa un NULL como `key:null`: con la columna en el manifest, la hoja de cada cuenta
 * del servidor la llevaría y la del teléfono 2.1 no ⇒ la tabla `accounts` divergente para siempre en cada teléfono
 * viejo. Estos casos fijan que `v1` sigue siendo exactamente lo de antes y que `v2` añade la columna nueva.
 */
import { describe, expect, it } from "vitest";
import { canonRowC1, merkleColumns } from "../src/sync/canon";
import {
  MANIFEST_VERSION,
  columnsUpTo,
  manifest,
  projectRowToDelta,
  resolveCapabilitySet,
  validateUpsertShape,
} from "../src/sync/manifest";

const HLC = "2026-10-18T12:00:00.000Z-0001-00000000000000aa";

/** Las 12 columnas de `accounts` que existían antes de `parent_account_id` (I5). */
const ACCOUNTS_V1 = [
  "name",
  "currency_code",
  "color_hex",
  "icon_name",
  "type",
  "account_number",
  "adjustment_mode",
  "exclude_from_statistics",
  "is_archived",
  "is_system_account",
  "credit_card_payment_reminder",
  "credit_card_payment_day",
];

const ACCOUNT_ROW = {
  sync_id: "8c1e2f0a-1111-4222-8333-944455556666",
  name: "Visa BCP",
  currency_code: "USD",
  color_hex: "#6366F1",
  icon_name: "creditcard",
  type: "creditCard",
  account_number: null,
  adjustment_mode: "manual",
  exclude_from_statistics: false,
  is_archived: false,
  is_system_account: false,
  credit_card_payment_reminder: false,
  credit_card_payment_day: 5,
  parent_account_id: null,
};

describe("capability-set por versión del manifest", () => {
  it("el Worker anuncia la versión 2, y ninguna columna es posterior a ella", () => {
    expect(MANIFEST_VERSION).toBe(2);
    for (const spec of Object.values(manifest.entities)) {
      for (const c of Object.values(spec.columns) as Array<{ since?: number }>) {
        expect(c.since ?? 1).toBeLessThanOrEqual(MANIFEST_VERSION);
      }
    }
  });

  it("parent_account_id es la única columna con since 2", () => {
    const later: string[] = [];
    for (const [entity, spec] of Object.entries(manifest.entities)) {
      for (const [col, c] of Object.entries(spec.columns) as Array<[string, { since?: number }]>) {
        if ((c.since ?? 1) > 1) later.push(`${entity}.${col}`);
      }
    }
    expect(later).toEqual(["accounts.parent_account_id"]);
  });

  it("v1 = exactamente las columnas de antes en accounts; el resto de tablas, enteras", () => {
    const cap = resolveCapabilitySet("v1");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.accounts ?? [])].sort()).toEqual([...ACCOUNTS_V1].sort());
    for (const [entity, spec] of Object.entries(manifest.entities)) {
      if (entity === "accounts") continue;
      expect([...(cap.columns![entity] ?? [])].sort()).toEqual(Object.keys(spec.columns).sort());
    }
  });

  it("v2, vN mayor, full y ausente = set completo", () => {
    for (const raw of ["v2", "v3", "v99", "full", null]) {
      expect(resolveCapabilitySet(raw)).toEqual({});
    }
  });

  it("v0 se lee como v1 (no deja una tabla sin columnas)", () => {
    expect(resolveCapabilitySet("v0")).toEqual({ columns: columnsUpTo(1) });
  });

  it("el Merkle de v1 no hashea la columna nueva y su payload es el de antes (sin la key)", () => {
    const v1 = merkleColumns("accounts", resolveCapabilitySet("v1"));
    expect(v1).not.toContain("parent_account_id");
    const payloadV1 = canonRowC1("accounts", ACCOUNT_ROW, v1);
    expect(payloadV1).not.toContain("parent_account_id");
    // Control: con v2 la key sí entra (como null), que es lo que rompería a un teléfono 2.1 sin esto.
    const v2 = merkleColumns("accounts", resolveCapabilitySet("v2"));
    expect(v2).toContain("parent_account_id");
    expect(canonRowC1("accounts", ACCOUNT_ROW, v2)).toContain('"parent_account_id":null');
  });

  it("el pull de v1 no baja la columna nueva ni su unidad; el de v2 sí", () => {
    const parent = "11111111-2222-4333-8444-555555555555";
    const row = { ...ACCOUNT_ROW, parent_account_id: parent };
    const stored = { name: HLC, parent_account_id: HLC };
    const v1 = projectRowToDelta("accounts", row, stored, resolveCapabilitySet("v1"));
    expect(v1.fields).not.toHaveProperty("parent_account_id");
    expect(v1.field_hlcs).not.toHaveProperty("parent_account_id");
    expect(v1.fields.name).toBe("Visa BCP");
    const v2 = projectRowToDelta("accounts", row, stored, resolveCapabilitySet("v2"));
    expect(v2.fields.parent_account_id).toBe(parent);
    expect(v2.field_hlcs.parent_account_id).toBe(HLC);
  });

  it("un push con la columna nueva tiene forma válida (columna safe, su propia unidad)", () => {
    const err = validateUpsertShape(
      "accounts",
      { parent_account_id: "11111111-2222-4333-8444-555555555555" },
      { parent_account_id: HLC },
    );
    expect(err).toBeNull();
  });
});
