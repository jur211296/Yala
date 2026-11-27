import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
// @ts-expect-error — módulo .mjs sin tipos: es el script del `predeploy`.
import { missingGroupColumns } from "../scripts/groups-columns-guard.mjs";

/**
 * Guard de despliegue (lote 1 de Compartido, 2026-11-26): no deja desplegar un Worker cuyo manifest de Grupos declara
 * columnas que la base del entorno no tiene. Sin él, desplegar producción desde 2.3 antes de g37_01 hashearía
 * `is_person` como null en el servidor y como false en el teléfono: divergencia falsa en todos los grupos.
 */
describe("check-groups-columns-applied — columnas del manifest de Grupos en la base", () => {
  const manifest = JSON.parse(readFileSync(new URL("../group_capability_manifest.json", import.meta.url), "utf8"));
  const allColumns = Object.values(manifest.entities as Record<string, { table: string; columns: object }>).flatMap(
    (e) => Object.keys(e.columns).map((c) => ({ table_name: e.table, column_name: c })),
  );

  it("con todas las columnas, despliega", () => {
    expect(missingGroupColumns(manifest, allColumns)).toEqual({ ok: true, missing: [] });
  });

  it("sin split_groups.is_person (g37_01 sin aplicar), para y la nombra", () => {
    const withoutMark = allColumns.filter((c) => !(c.table_name === "split_groups" && c.column_name === "is_person"));
    expect(missingGroupColumns(manifest, withoutMark)).toEqual({ ok: false, missing: ["split_groups.is_person"] });
  });

  it("una columna de otra tabla con el mismo nombre no cuenta", () => {
    const rows = allColumns
      .filter((c) => !(c.table_name === "split_groups" && c.column_name === "is_person"))
      .concat({ table_name: "split_expenses", column_name: "is_person" });
    expect(missingGroupColumns(manifest, rows).missing).toEqual(["split_groups.is_person"]);
  });

  it("columnas que la base tiene de más no estorban", () => {
    const rows = allColumns.concat({ table_name: "split_groups", column_name: "owner_user_id" });
    expect(missingGroupColumns(manifest, rows).ok).toBe(true);
  });
});
