// groups-columns-guard.mjs — decisión pura del guard `check-groups-columns-applied.mjs`: qué columnas del manifest de
// Grupos no existen en la base del entorno al que se va a desplegar.
//
// Por qué (revisor con checklist del lote 1 de Compartido, 2026-11-26): un Worker con el manifest v4 anuncia
// `split_groups.is_person`, y si la base de ese entorno no tiene la columna (g37_01 sin aplicar), el reader no la
// devuelve, `canonValueFor` la hashea como `null` y el teléfono como `false`: divergencia falsa del Merkle en TODOS los
// grupos de los teléfonos v4, con reset de cursores y re-pull, y el push de la marca da 42703. El guard de versión
// (`check-manifest-not-older.mjs`) no lo ve: solo impide desplegar un manifest MÁS VIEJO.

/**
 * @param {{ entities: Record<string, { table: string, columns: Record<string, unknown> }> }} manifest
 * @param {Array<{ table_name: string, column_name: string }>} dbColumns — `information_schema.columns` del esquema public
 * @returns {{ ok: boolean, missing: string[] }} `missing` como `tabla.columna`, ordenado
 */
export function missingGroupColumns(manifest, dbColumns) {
  const present = new Set(dbColumns.map((c) => `${c.table_name}.${c.column_name}`));
  const missing = [];
  for (const entity of Object.values(manifest.entities)) {
    for (const column of Object.keys(entity.columns)) {
      const key = `${entity.table}.${column}`;
      if (!present.has(key)) missing.push(key);
    }
  }
  missing.sort();
  return { ok: missing.length === 0, missing };
}
