/**
 * groups/canon.ts — re-serializador canónico c1 del canal de GRUPOS para el Merkle (§d.7). Reusa los
 * PRIMITIVOS del codec personal (`sync/canon.ts`: encoders por valor, aritmética numérica/temporal) y
 * solo cambia el SSOT (el manifest de grupos) y la lista de columnas server-authored.
 *
 * DIFERENCIA CLAVE vs `sync/canon.ts::encodeCanonC1`: aquí `user_id` es una columna de DOMINIO
 * (group_members) y DEBE poder ser leaf — el guard server-authored del codec personal la prohíbe. Por
 * eso el guard local usa el `server_only_columns` del manifest de grupos (que NO incluye user_id).
 */
import {
  CanonError,
  encodeCanonValue,
  encodeJSONStringC1,
  millisFromPostgresText,
  utf8Compare,
  type CanonValue,
} from "../sync/canon";
import { groupManifest, groupsOfEntity } from "./manifest";

/** Columnas server-authored del canal de grupos que JAMÁS son leaves (guard defensivo; user_id NO está). */
const GROUP_SERVER_AUTHORED = new Set([
  "server_seq",
  "hlc",
  "field_hlcs",
  "deleted",
  "deleted_hlc",
  "schema_version",
  "updated_at",
  "owner_user_id",
  "group_id",
  "sync_id",
]);

/** Serializa un mapa columna->CanonValue al string canónico c1 (espejo de encodeCanonC1, guard de grupos). */
function encodeGroupCanonC1(fields: Record<string, CanonValue>, groupedColumns: Set<string>): string {
  for (const key of Object.keys(fields)) {
    if (GROUP_SERVER_AUTHORED.has(key)) throw new CanonError("serverAuthoredKey", key);
  }
  const keys = Object.keys(fields).sort(utf8Compare);
  const entries: string[] = [];
  for (const key of keys) {
    const fragment = encodeCanonValue(fields[key], groupedColumns.has(key));
    if (fragment === null) continue; // uuid[] vacía singleton (no ocurre en grupos)
    entries.push(`${encodeJSONStringC1(key)}:${fragment}`);
  }
  return "{" + entries.join(",") + "}";
}

/** Mapea un valor crudo de PostgREST a su CanonValue según el `format` del manifest (espejo del personal). */
function canonValueFor(format: string, scale: number | undefined, raw: unknown): CanonValue {
  if (raw === null || raw === undefined) {
    if (format === "uuid_lower_array") return { t: "uuidArray", values: [] };
    return { t: "null" };
  }
  switch (format) {
    case "decimal_fixed": {
      const t = scale === 8 ? "rate" : "money";
      if (typeof raw === "string") return { t, text: raw };
      return { t, double: raw as number };
    }
    case "iso8601_ms_utc":
      return { t: "timestampMs", ms: millisFromPostgresText(String(raw)) };
    case "uuid_lower":
      return { t: "uuid", value: String(raw) };
    case "uuid_lower_array":
      return { t: "uuidArray", values: (raw as string[]).map(String) };
    case "utf8":
      return { t: "string", value: String(raw) };
    case "bool_tristate":
      return { t: "bool", value: raw as boolean };
    case "int":
      return { t: "int", value: raw as number };
    case "text_array":
    case "jcs":
      return { t: "jsonValue", value: raw };
    default:
      return { t: "jsonValue", value: raw };
  }
}

/** Columnas de dominio de `entity` a incluir en el leaf del Merkle (todas — grupos no tienen local_day). */
export function merkleColumnsGroup(entity: string): string[] {
  const spec = groupManifest.entities[entity];
  if (!spec) return [];
  return Object.keys(spec.columns);
}

/** Re-serializa UNA fila de grupo (valores de PostgREST) al payload canónico c1 del leaf. */
export function canonRowC1Group(entity: string, row: Record<string, unknown>, columns: string[]): string {
  const spec = groupManifest.entities[entity];
  const grouped = new Set<string>();
  const fields: Record<string, CanonValue> = {};
  for (const col of columns) {
    const spc = spec?.columns[col];
    if (!spc) continue;
    if (spc.group_key) grouped.add(col);
    fields[col] = canonValueFor(spc.format, spc.scale, row[col]);
  }
  return encodeGroupCanonC1(fields, grouped);
}
