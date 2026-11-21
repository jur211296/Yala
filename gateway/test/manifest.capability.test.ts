/**
 * Capability-set por versión del manifest (`since`) — OFFLINE, contra el manifest real.
 *
 * Por qué existe. `accounts.parent_account_id` (tarjeta con varias divisas, 2026-10-18) es la primera columna
 * personal añadida después del lanzamiento. Hasta ese día `v1` —lo que manda todo iOS hasta 2.1— era el set
 * COMPLETO, y el Merkle serializa un NULL como `key:null`: con la columna en el manifest, la hoja de cada cuenta
 * del servidor la llevaría y la del teléfono 2.1 no ⇒ la tabla `accounts` divergente para siempre en cada teléfono
 * viejo. Estos casos fijan que `v1` sigue siendo exactamente lo de antes y que `v2` añade la columna nueva.
 *
 * Desde el 2026-10-21 (UX 2.2 · L18-8) hay una v3: `cashflow_lines.amount_changes_raw`, los cambios de monto «desde
 * este mes» de una línea del flujo de caja. `v2` es entonces todo menos esa columna, y `v3` el set completo.
 *
 * Desde el 2026-10-25 (card da5d) hay una v4: `favorite_payments.destination_account_ref`, el destino de un favorito de
 * transferencia. `v3` es todo menos esa columna, y `v4` el set completo.
 *
 * Desde el 2026-10-27 (card nmtk) hay una v5: `accounts.credit_card_statement_day` y
 * `accounts.credit_card_reminder_days_before`, el día de corte de una tarjeta y los días de antelación de su aviso. `v4`
 * es todo menos esas dos, y `v5` el set completo.
 *
 * Desde el 2026-11-01 (Grupos B, card 1) hay una v6: `tx_items.split_lines_raw`, la receta de tu parte de un gasto de
 * grupo en líneas. `v5` es todo menos esa columna.
 * Desde el 2026-11-20 hay una v7: `scheduled_payments.custom_logo_ref`, la referencia de la foto del logo propio de un
 * pago planificado. `v6` es todo menos esa columna.
 * Desde el 2026-11-20 (tarde) hay una v8: las cuatro columnas de los límites del flujo de caja atados a varios pagos
 * planificados y en otra moneda (`cashflow_lines.scheduled_payment_ids_raw`, `limit_extra_amount`, `limit_currency_code`,
 * `limit_foreign_amount`). `v7` es todo menos esas cuatro, y `v8` el set completo.
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
  it("el Worker anuncia la versión 8, y ninguna columna es posterior a ella", () => {
    expect(MANIFEST_VERSION).toBe(8);
    for (const spec of Object.values(manifest.entities)) {
      for (const c of Object.values(spec.columns) as Array<{ since?: number }>) {
        expect(c.since ?? 1).toBeLessThanOrEqual(MANIFEST_VERSION);
      }
    }
  });

  it("las columnas posteriores: parent_account_id (2), amount_changes_raw (3), destination_account_ref (4) las dos de la tarjeta (5), la receta de líneas (6), el logo propio (7) y los límites del flujo de caja (8)", () => {
    const later: string[] = [];
    for (const [entity, spec] of Object.entries(manifest.entities)) {
      for (const [col, c] of Object.entries(spec.columns) as Array<[string, { since?: number }]>) {
        if ((c.since ?? 1) > 1) later.push(`${entity}.${col}@${c.since}`);
      }
    }
    expect(later.sort()).toEqual([
      "accounts.credit_card_reminder_days_before@5",
      "accounts.credit_card_statement_day@5",
      "accounts.parent_account_id@2",
      "cashflow_lines.amount_changes_raw@3",
      "cashflow_lines.limit_currency_code@8",
      "cashflow_lines.limit_extra_amount@8",
      "cashflow_lines.limit_foreign_amount@8",
      "cashflow_lines.scheduled_payment_ids_raw@8",
      "favorite_payments.destination_account_ref@4",
      "scheduled_payments.custom_logo_ref@7",
      "tx_items.split_lines_raw@6",
    ]);
  });

  it("v1 = exactamente las columnas de antes en accounts; cashflow_lines, favoritos y tx_items sin las suyas; el resto, enteras", () => {
    const cap = resolveCapabilitySet("v1");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.accounts ?? [])].sort()).toEqual([...ACCOUNTS_V1].sort());
    expect([...(cap.columns!.cashflow_lines ?? [])]).not.toContain("amount_changes_raw");
    expect([...(cap.columns!.favorite_payments ?? [])]).not.toContain("destination_account_ref");
    expect([...(cap.columns!.tx_items ?? [])]).not.toContain("split_lines_raw");
    expect([...(cap.columns!.scheduled_payments ?? [])]).not.toContain("custom_logo_ref");
    const later = new Set(["accounts", "cashflow_lines", "favorite_payments", "tx_items", "scheduled_payments"]);
    for (const [entity, spec] of Object.entries(manifest.entities)) {
      if (later.has(entity)) continue;
      expect([...(cap.columns![entity] ?? [])].sort()).toEqual(Object.keys(spec.columns).sort());
    }
  });

  it("v2 = todo menos amount_changes_raw: el enlace de tarjeta sí, los cambios del flujo de caja no", () => {
    const cap = resolveCapabilitySet("v2");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.accounts ?? [])]).toContain("parent_account_id");
    const lines = [...(cap.columns!.cashflow_lines ?? [])];
    expect(lines).not.toContain("amount_changes_raw");
    // Sin amount_changes_raw (v3) ni las cuatro de los límites (v8): solo las columnas de la v1 y la v2.
    expect(lines.sort()).toEqual(
      (Object.entries(manifest.entities.cashflow_lines.columns) as Array<[string, { since?: number }]>)
        .filter(([, c]) => (c.since ?? 1) <= 2).map(([col]) => col).sort(),
    );
  });

  it("v3 = todo menos destination_account_ref: los cambios del flujo de caja sí, el destino del favorito no", () => {
    const cap = resolveCapabilitySet("v3");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.cashflow_lines ?? [])]).toContain("amount_changes_raw");
    const favorites = [...(cap.columns!.favorite_payments ?? [])];
    expect(favorites).not.toContain("destination_account_ref");
    expect(favorites.sort()).toEqual(
      Object.keys(manifest.entities.favorite_payments.columns).filter((c) => c !== "destination_account_ref").sort(),
    );
  });

  it("v4 = todo menos las dos columnas de la tarjeta: el destino del favorito sí", () => {
    const cap = resolveCapabilitySet("v4");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.favorite_payments ?? [])]).toContain("destination_account_ref");
    const accounts = [...(cap.columns!.accounts ?? [])];
    expect(accounts).toContain("parent_account_id");
    expect(accounts.sort()).toEqual(
      Object.keys(manifest.entities.accounts.columns)
        .filter((c) => c !== "credit_card_statement_day" && c !== "credit_card_reminder_days_before")
        .sort(),
    );
  });

  it("v5 = todo menos la receta de líneas: las columnas de la tarjeta sí", () => {
    const cap = resolveCapabilitySet("v5");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.accounts ?? [])]).toContain("credit_card_statement_day");
    const tx = [...(cap.columns!.tx_items ?? [])];
    expect(tx).not.toContain("split_lines_raw");
    expect(tx.sort()).toEqual(
      Object.keys(manifest.entities.tx_items.columns).filter((c) => c !== "split_lines_raw").sort(),
    );
  });

  it("v6 = todo menos el logo propio: la receta de líneas sí", () => {
    const cap = resolveCapabilitySet("v6");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.tx_items ?? [])]).toContain("split_lines_raw");
    const payments = [...(cap.columns!.scheduled_payments ?? [])];
    expect(payments).not.toContain("custom_logo_ref");
    expect(payments.sort()).toEqual(
      Object.keys(manifest.entities.scheduled_payments.columns).filter((c) => c !== "custom_logo_ref").sort(),
    );
  });

  it("el pull de v6 no baja la referencia del logo propio ni su unidad; el de v7 sí", () => {
    const row = { sync_id: "6b2c3d4e-2222-4333-8444-a55566667777", name: "Colegio", custom_logo_ref: "0f5e8a1c-1d2e-4f30-8a4b-5c6d7e8f9a0b.jpg" };
    const stored = { name: HLC, custom_logo_ref: HLC };
    const v6 = projectRowToDelta("scheduled_payments", row, stored, resolveCapabilitySet("v6"));
    expect(v6.fields).not.toHaveProperty("custom_logo_ref");
    expect(v6.field_hlcs).not.toHaveProperty("custom_logo_ref");
    expect(v6.fields.name).toBe("Colegio");
    const v7 = projectRowToDelta("scheduled_payments", row, stored, resolveCapabilitySet("v7"));
    expect(v7.fields.custom_logo_ref).toBe(row.custom_logo_ref);
    expect(v7.field_hlcs.custom_logo_ref).toBe(HLC);
  });

  it("el Merkle de v6 no hashea el logo propio; el de v7 sí (como null en un pago sin foto)", () => {
    const row = { sync_id: "6b2c3d4e-2222-4333-8444-a55566667777", name: "Alquiler", custom_logo_ref: null };
    const v6 = merkleColumns("scheduled_payments", resolveCapabilitySet("v6"));
    expect(v6).not.toContain("custom_logo_ref");
    expect(canonRowC1("scheduled_payments", row, v6)).not.toContain("custom_logo_ref");
    const v7 = merkleColumns("scheduled_payments", resolveCapabilitySet("v7"));
    expect(v7).toContain("custom_logo_ref");
    expect(canonRowC1("scheduled_payments", row, v7)).toContain('"custom_logo_ref":null');
  });

  it("un push con la referencia del logo propio tiene forma válida (columna safe), también al quitarla", () => {
    expect(validateUpsertShape("scheduled_payments", { custom_logo_ref: "a.jpg" }, { custom_logo_ref: HLC })).toBeNull();
    expect(validateUpsertShape("scheduled_payments", { custom_logo_ref: null }, { custom_logo_ref: HLC })).toBeNull();
  });

  it("v7 = todo menos las cuatro de los límites del flujo de caja: el logo propio sí", () => {
    const cap = resolveCapabilitySet("v7");
    expect(cap.columns).toBeDefined();
    expect([...(cap.columns!.scheduled_payments ?? [])]).toContain("custom_logo_ref");
    const lines = [...(cap.columns!.cashflow_lines ?? [])];
    const v8 = ["scheduled_payment_ids_raw", "limit_extra_amount", "limit_currency_code", "limit_foreign_amount"];
    for (const col of v8) expect(lines).not.toContain(col);
    expect(lines).toContain("amount_changes_raw");
    expect(lines.sort()).toEqual(
      Object.keys(manifest.entities.cashflow_lines.columns).filter((c) => !v8.includes(c)).sort(),
    );
  });

  it("el pull de v7 no baja los pagos, el extra ni la moneda del límite; el de v8 sí", () => {
    const ids = "0a1b2c3d-1111-4222-8333-944455556666,1b2c3d4e-2222-4333-8444-a55566667777";
    const row = {
      sync_id: "7c3d4e5f-3333-4444-8555-b66677778888", name: "Suscripciones", scheduled_payment_ids_raw: ids,
      limit_extra_amount: "30.0000", limit_currency_code: "USD", limit_foreign_amount: "500.0000",
    };
    const stored = {
      name: HLC, scheduled_payment_ids_raw: HLC, limit_extra_amount: HLC, limit_currency_code: HLC,
      limit_foreign_amount: HLC,
    };
    const v7 = projectRowToDelta("cashflow_lines", row, stored, resolveCapabilitySet("v7"));
    for (const col of ["scheduled_payment_ids_raw", "limit_extra_amount", "limit_currency_code", "limit_foreign_amount"]) {
      expect(v7.fields).not.toHaveProperty(col);
      expect(v7.field_hlcs).not.toHaveProperty(col);
    }
    expect(v7.fields.name).toBe("Suscripciones");
    const v8 = projectRowToDelta("cashflow_lines", row, stored, resolveCapabilitySet("v8"));
    expect(v8.fields.scheduled_payment_ids_raw).toBe(ids);
    expect(v8.fields.limit_currency_code).toBe("USD");
    expect(v8.field_hlcs.limit_foreign_amount).toBe(HLC);
  });

  it("el Merkle de v7 no hashea las cuatro columnas; el de v8 sí (como null en una línea sin ellas)", () => {
    const row = {
      sync_id: "7c3d4e5f-3333-4444-8555-b66677778888", name: "Renta", scheduled_payment_ids_raw: null,
      limit_extra_amount: null, limit_currency_code: null, limit_foreign_amount: null,
    };
    const v7 = merkleColumns("cashflow_lines", resolveCapabilitySet("v7"));
    expect(v7).not.toContain("limit_currency_code");
    expect(canonRowC1("cashflow_lines", row, v7)).not.toContain("scheduled_payment_ids_raw");
    const v8 = merkleColumns("cashflow_lines", resolveCapabilitySet("v8"));
    expect(v8).toContain("limit_foreign_amount");
    expect(canonRowC1("cashflow_lines", row, v8)).toContain('"scheduled_payment_ids_raw":null');
  });

  it("un push con las cuatro columnas tiene forma válida (columnas safe, cada una su unidad), también al vaciarlas", () => {
    expect(validateUpsertShape("cashflow_lines", { limit_currency_code: "USD", limit_foreign_amount: "500.0000" },
      { limit_currency_code: HLC, limit_foreign_amount: HLC })).toBeNull();
    expect(validateUpsertShape("cashflow_lines", { scheduled_payment_ids_raw: null, limit_extra_amount: null },
      { scheduled_payment_ids_raw: HLC, limit_extra_amount: HLC })).toBeNull();
  });

  it("v8, vN mayor, full y ausente = set completo", () => {
    for (const raw of ["v8", "v99", "full", null]) {
      expect(resolveCapabilitySet(raw)).toEqual({});
    }
  });

  it("el pull de v5 no baja la receta de líneas ni su unidad; el de v6 sí", () => {
    const recipe = '{"v":1,"lines":[{"kind":"transfer","amount":"500"},{"kind":"expense","amount":"10"}]}';
    const row = { sync_id: "5a1b2c3d-1111-4222-8333-944455556666", note: "Recarga Sip", split_lines_raw: recipe };
    const stored = { note: HLC, split_lines_raw: HLC };
    const v5 = projectRowToDelta("tx_items", row, stored, resolveCapabilitySet("v5"));
    expect(v5.fields).not.toHaveProperty("split_lines_raw");
    expect(v5.field_hlcs).not.toHaveProperty("split_lines_raw");
    expect(v5.fields.note).toBe("Recarga Sip");
    const v6 = projectRowToDelta("tx_items", row, stored, resolveCapabilitySet("v6"));
    expect(v6.fields.split_lines_raw).toBe(recipe);
    expect(v6.field_hlcs.split_lines_raw).toBe(HLC);
  });

  it("el Merkle de v5 no hashea la receta de líneas; el de v6 sí (como null en un movimiento sin receta)", () => {
    const row = { sync_id: "5a1b2c3d-1111-4222-8333-944455556666", note: "Súper", split_lines_raw: null };
    const v5 = merkleColumns("tx_items", resolveCapabilitySet("v5"));
    expect(v5).not.toContain("split_lines_raw");
    expect(canonRowC1("tx_items", row, v5)).not.toContain("split_lines_raw");
    const v6 = merkleColumns("tx_items", resolveCapabilitySet("v6"));
    expect(v6).toContain("split_lines_raw");
    expect(canonRowC1("tx_items", row, v6)).toContain('"split_lines_raw":null');
  });

  it("un push con la receta de líneas tiene forma válida (columna safe, su propia unidad), también al vaciarla", () => {
    expect(validateUpsertShape("tx_items", { split_lines_raw: '{"v":1}' }, { split_lines_raw: HLC })).toBeNull();
    expect(validateUpsertShape("tx_items", { split_lines_raw: null }, { split_lines_raw: HLC })).toBeNull();
  });

  it("el pull de v4 no baja el día de corte ni los días del aviso; el de v5 sí", () => {
    const row = { ...ACCOUNT_ROW, credit_card_statement_day: 15, credit_card_reminder_days_before: 3 };
    const stored = { name: HLC, credit_card_statement_day: HLC, credit_card_reminder_days_before: HLC };
    const v4 = projectRowToDelta("accounts", row, stored, resolveCapabilitySet("v4"));
    expect(v4.fields).not.toHaveProperty("credit_card_statement_day");
    expect(v4.fields).not.toHaveProperty("credit_card_reminder_days_before");
    expect(v4.field_hlcs).not.toHaveProperty("credit_card_statement_day");
    const v5 = projectRowToDelta("accounts", row, stored, resolveCapabilitySet("v5"));
    expect(v5.fields.credit_card_statement_day).toBe(15);
    expect(v5.fields.credit_card_reminder_days_before).toBe(3);
    expect(v5.field_hlcs.credit_card_statement_day).toBe(HLC);
  });

  it("el Merkle de v4 no hashea las columnas de la tarjeta; el de v5 sí (como null en una cuenta sin corte)", () => {
    const v4 = merkleColumns("accounts", resolveCapabilitySet("v4"));
    expect(v4).not.toContain("credit_card_statement_day");
    expect(canonRowC1("accounts", ACCOUNT_ROW, v4)).not.toContain("credit_card_statement_day");
    const v5 = merkleColumns("accounts", resolveCapabilitySet("v5"));
    expect(v5).toContain("credit_card_statement_day");
    expect(canonRowC1("accounts", ACCOUNT_ROW, v5)).toContain('"credit_card_statement_day":null');
  });

  it("un push con las columnas de la tarjeta tiene forma válida (columnas safe, cada una su unidad)", () => {
    const err = validateUpsertShape(
      "accounts",
      { credit_card_statement_day: 15, credit_card_reminder_days_before: 3 },
      { credit_card_statement_day: HLC, credit_card_reminder_days_before: HLC },
    );
    expect(err).toBeNull();
  });

  it("el pull de v3 no baja el destino del favorito; el de v4 sí", () => {
    const destination = "22222222-3333-4444-8555-666666666666";
    const row = {
      sync_id: "7c1e2d3f-1111-4222-8333-944455556666",
      name: "Ahorro del mes",
      destination_account_ref: destination,
    };
    const stored = { name: HLC, destination_account_ref: HLC };
    const v3 = projectRowToDelta("favorite_payments", row, stored, resolveCapabilitySet("v3"));
    expect(v3.fields).not.toHaveProperty("destination_account_ref");
    expect(v3.field_hlcs).not.toHaveProperty("destination_account_ref");
    const v4 = projectRowToDelta("favorite_payments", row, stored, resolveCapabilitySet("v4"));
    expect(v4.fields.destination_account_ref).toBe(destination);
    expect(v4.field_hlcs.destination_account_ref).toBe(HLC);
  });

  it("el pull de v2 no baja los cambios del flujo de caja; el de v3 sí", () => {
    const row = {
      sync_id: "9d2f3a1b-1111-4222-8333-944455556666",
      name: "Salario",
      amount_changes_raw: "2026-11=9000.0",
    };
    const stored = { name: HLC, amount_changes_raw: HLC };
    const v2 = projectRowToDelta("cashflow_lines", row, stored, resolveCapabilitySet("v2"));
    expect(v2.fields).not.toHaveProperty("amount_changes_raw");
    expect(v2.field_hlcs).not.toHaveProperty("amount_changes_raw");
    const v3 = projectRowToDelta("cashflow_lines", row, stored, resolveCapabilitySet("v3"));
    expect(v3.fields.amount_changes_raw).toBe("2026-11=9000.0");
    expect(v3.field_hlcs.amount_changes_raw).toBe(HLC);
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
