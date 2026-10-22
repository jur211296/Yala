/**
 * Gate `min_writable_version` POR-COLUMNA (§d.2, cierre SERIO 5 v3) — SEPARADO del PATCH.
 *
 * El PATCH column-by-column (§d.4) ya protege las columnas AUSENTES de un cliente viejo. Este gate
 * protege las columnas PRESENTES cuando su SEMÁNTICA cambió entre versiones: rechaza un upsert cuyo
 * `schema_version` es insuficiente para pisar una columna REINTERPRETADA — y SOLO esa columna, no
 * cualquier otra columna no-relacionada de la misma fila (por eso es por-columna, no por-fila).
 *
 * HOY la lista curada está VACÍA: ninguna columna ha cambiado de semántica → el gate nunca dispara.
 * La estructura queda lista para añadir entradas sin migración. Es append-only y análoga a la lista
 * de campos byte-a-byte del §d.1.
 *
 * Entrada = "la columna `entity.column` fue reinterpretada en la versión de protocolo `min_version`;
 * un delta que la TOCA con `schema_version < min_version` se rechaza".
 */
export interface BreakingColumn {
  entity: string;
  column: string;
  min_version: number;
}

/** Lista curada — VACÍA en v1 (§d.2: estructura lista, sin entradas). */
const CURATED: readonly BreakingColumn[] = [];

/**
 * Override SOLO para tests (golden #3): inyecta una entrada de prueba en la lista curada sin tocar el
 * contrato de producción. `setBreakingColumnsForTest(null)` restaura la lista vacía real.
 */
let testOverride: readonly BreakingColumn[] | null = null;
export function setBreakingColumnsForTest(entries: readonly BreakingColumn[] | null): void {
  testOverride = entries;
}
function activeList(): readonly BreakingColumn[] {
  return testOverride ?? CURATED;
}

export interface SchemaGateReject {
  column: string;
  min_version: number;
  client_version: number;
}

/**
 * ¿Rechaza este delta? Devuelve la PRIMERA columna reinterpretada que el delta toca con una versión
 * insuficiente, o null si pasa. Un edit de una columna NO-listada (p.ej. `note`) siempre pasa aunque
 * la fila haya recibido campos nuevos — por eso el gate es por-columna.
 */
export function checkSchemaGate(
  entity: string,
  touchedColumns: string[],
  clientVersion: number,
): SchemaGateReject | null {
  for (const bc of activeList()) {
    if (bc.entity !== entity) continue;
    if (!touchedColumns.includes(bc.column)) continue;
    if (clientVersion < bc.min_version) {
      return { column: bc.column, min_version: bc.min_version, client_version: clientVersion };
    }
  }
  return null;
}
