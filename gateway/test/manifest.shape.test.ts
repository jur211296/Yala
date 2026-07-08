/**
 * validateUpsertShape — tests OFFLINE del invariante de emisión (§d.4bis) contra el manifest real.
 * Foco: DIFERIDOS #25 opción 1 — una `uuid[]` VACÍA dentro de un grupo de coherencia viaja como `[]`
 * explícito y DEBE contar como "presente" (la presencia es `col in fields`); un grupo al que le FALTA
 * la key sigue siendo `coherence_group_partial` (el bug original sigue rechazado si un cliente viejo
 * omite la columna).
 */
import { describe, expect, it } from "vitest";
import { nestFieldsByUnit, validateUpsertShape } from "../src/sync/manifest";

const HLC = "2026-07-08T12:00:00.000Z-0001-00000000000000aa";

/** Grupo budget completo (las 6 columnas congeladas) con las 3 uuid[] VACÍAS — caso mayoritario #25. */
const budgetGroupFields = {
  currency_code: "PEN",
  limit_amount: "500.0000",
  natures: null,
  subcategory_ids: [],
  account_ids: [],
  tag_refs: [],
};

describe("validateUpsertShape · [] explícito en grupo (DIFERIDOS #25 opción 1)", () => {
  it("acepta el grupo budget completo con uuid[] vacías como []", () => {
    const err = validateUpsertShape("budgets", budgetGroupFields, { budget: HLC });
    expect(err).toBeNull();
  });

  it("rechaza el grupo si una uuid[] vacía se OMITE en vez de viajar como [] (bug original de #25)", () => {
    const { account_ids: _dropped, ...partial } = budgetGroupFields;
    const err = validateUpsertShape("budgets", partial, { budget: HLC });
    expect(err?.type).toBe("coherence_group_partial");
    expect(err?.group).toBe("budget");
    expect(err?.detail).toContain("account_ids");
  });

  it("acepta singleton uuid[] vacía como [] si el cliente la manda (presencia = col in fields)", () => {
    // tx_items.tag_refs es singleton: el codec c1 la OMITE cuando está vacía, pero si un cliente la
    // mandara como [] no es un error de forma (solo requiere su unit en field_hlcs).
    const err = validateUpsertShape("tx_items", { tag_refs: [] }, { tag_refs: HLC });
    expect(err).toBeNull();
  });

  it("nestFieldsByUnit pasa los [] verbatim dentro de su unidad", () => {
    const nested = nestFieldsByUnit("budgets", budgetGroupFields);
    expect(nested.budget).toBeDefined();
    expect(nested.budget.account_ids).toEqual([]);
    expect(nested.budget.tag_refs).toEqual([]);
    expect(Object.keys(nested.budget).sort()).toEqual([
      "account_ids",
      "currency_code",
      "limit_amount",
      "natures",
      "subcategory_ids",
      "tag_refs",
    ]);
  });
});
