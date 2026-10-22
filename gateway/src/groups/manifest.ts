/**
 * group_capability_manifest.json — SSOT del capability-set de sync de GRUPOS (G2). Se COPIA a la raíz
 * del gateway en `npm run sync:manifest` (pretest/pretypecheck/predeploy) desde
 * `../group_capability_manifest.json` (raíz del repo Yala), junto al manifest personal.
 *
 * Este módulo espeja `sync/manifest.ts` pero contra el manifest de GRUPOS y con dos extensiones del
 * schema del manifest que el canal personal no tiene:
 *   - `EntitySpec.pull_only` (default false): el validador de push RECHAZA deltas de esa entidad
 *     (`group_members` es pull-only — el cliente jamás la empuja; su rename va por RPC).
 *   - `EntitySpec.push` (default "upsert_insert"): "update_only" para `split_groups` (nace SOLO vía el
 *     RPC create_group; el push solo actualiza meta — el RPC decide, aquí solo se permite pasar).
 * Un loader que ignore estos flags degrada con seguridad (default false / "upsert_insert").
 */
import groupManifestJson from "../../group_capability_manifest.json";

interface ColumnSpec {
  pg_type: string;
  format: string;
  scale?: number;
  safe?: boolean;
  group_key?: string;
}
interface EntitySpec {
  table: string;
  sync_id_source: string;
  /** "update_only" (split_groups) | "upsert_insert" (default). */
  push?: string;
  /** true (group_members) → el push la RECHAZA. Default false. */
  pull_only?: boolean;
  columns: Record<string, ColumnSpec>;
}
interface GroupManifest {
  manifest_version: number;
  canon_version: string;
  server_only_columns: string[];
  identity_columns: string[];
  coherence_groups: Record<string, { entity: string; columns: string[] }>;
  entities: Record<string, EntitySpec>;
}

export const groupManifest = groupManifestJson as unknown as GroupManifest;

/** Las 5 tablas del canal de grupos (keys del manifest). */
export const GROUP_ENTITIES: readonly string[] = Object.keys(groupManifest.entities);

export function isGroupEntity(entity: string): boolean {
  return Object.prototype.hasOwnProperty.call(groupManifest.entities, entity);
}

function entitySpec(entity: string): EntitySpec | null {
  return groupManifest.entities[entity] ?? null;
}

/** ¿Es la entidad PULL-ONLY? (group_members) → el push la rechaza con yala_bad_request. */
export function isPullOnlyEntity(entity: string): boolean {
  return entitySpec(entity)?.pull_only === true;
}

/** Modo de push de la entidad. "update_only" (split_groups) | "upsert_insert" (default). */
export function pushModeOf(entity: string): string {
  return entitySpec(entity)?.push ?? "upsert_insert";
}

/** ¿Es `col` una columna de DOMINIO conocida de `entity`? (excluye server-only / identity). */
export function isDomainColumn(entity: string, col: string): boolean {
  const spec = entitySpec(entity);
  return !!spec && Object.prototype.hasOwnProperty.call(spec.columns, col);
}

/** Unidad de resolución de una columna: su `group_key`, o su propio nombre si es singleton; null si no es de dominio. */
export function unitOfColumn(entity: string, col: string): string | null {
  const spec = entitySpec(entity);
  const c = spec?.columns[col];
  if (!c) return null;
  return c.group_key ?? col;
}

/** Mapa group_key → columnas del grupo, SOLO para esta entidad. */
export function groupsOfEntity(entity: string): Record<string, string[]> {
  const spec = entitySpec(entity);
  if (!spec) return {};
  const out: Record<string, string[]> = {};
  for (const [col, c] of Object.entries(spec.columns)) {
    if (c.group_key) (out[c.group_key] ??= []).push(col);
  }
  return out;
}

/** Todas las unidades válidas de `entity`: los group_keys + cada columna singleton. */
export function validUnits(entity: string): Set<string> {
  const spec = entitySpec(entity);
  const units = new Set<string>();
  if (!spec) return units;
  for (const [col, c] of Object.entries(spec.columns)) units.add(c.group_key ?? col);
  return units;
}

export interface ShapeError {
  type: "unknown_entity" | "unknown_column" | "unknown_unit" | "coherence_group_partial";
  detail: string;
  group?: string;
}

/**
 * Valida la forma de un delta de UPSERT contra el manifest de grupos + el INVARIANTE DE EMISIÓN (un
 * delta que toca CUALQUIER columna de un grupo DEBE traer TODAS las del grupo + su unit en field_hlcs).
 * Espejo de `sync/manifest.ts::validateUpsertShape`. Devuelve el primer error, o null si válida.
 */
export function validateUpsertShape(
  entity: string,
  fields: Record<string, unknown>,
  fieldHlcs: Record<string, string>,
): ShapeError | null {
  if (!isGroupEntity(entity)) {
    return { type: "unknown_entity", detail: entity };
  }
  const units = validUnits(entity);
  const groups = groupsOfEntity(entity);

  for (const col of Object.keys(fields)) {
    if (!isDomainColumn(entity, col)) {
      return { type: "unknown_column", detail: `${entity}.${col}` };
    }
  }
  for (const unit of Object.keys(fieldHlcs)) {
    if (!units.has(unit)) {
      return { type: "unknown_unit", detail: `${entity}:${unit}` };
    }
  }
  for (const col of Object.keys(fields)) {
    const unit = unitOfColumn(entity, col)!;
    if (!(unit in fieldHlcs)) {
      return { type: "unknown_unit", detail: `${entity}.${col} sin field_hlcs['${unit}']` };
    }
  }

  const touchedGroups = new Set<string>();
  for (const g of Object.keys(groups)) {
    if (g in fieldHlcs) touchedGroups.add(g);
  }
  for (const col of Object.keys(fields)) {
    const c = groupManifest.entities[entity].columns[col];
    if (c.group_key) touchedGroups.add(c.group_key);
  }
  for (const g of touchedGroups) {
    if (!(g in fieldHlcs)) {
      return { type: "coherence_group_partial", detail: `${entity}:${g} sin field_hlcs`, group: g };
    }
    for (const col of groups[g]) {
      if (!(col in fields)) {
        return { type: "coherence_group_partial", detail: `${entity}:${g} falta '${col}'`, group: g };
      }
    }
  }
  return null;
}

/** Re-agrupa un `fields` PLANO por unidad para el RPC: `{unit: {col: val}}`. */
export function nestFieldsByUnit(entity: string, fields: Record<string, unknown>): Record<string, Record<string, unknown>> {
  const nested: Record<string, Record<string, unknown>> = {};
  for (const [col, val] of Object.entries(fields)) {
    const unit = unitOfColumn(entity, col);
    if (unit === null) continue; // ya validado; defensivo
    (nested[unit] ??= {})[col] = val;
  }
  return nested;
}

/**
 * Proyecta (poda) una fila del backend a `fields` (columnas de dominio conocidas) + `field_hlcs` (las
 * unidades correspondientes). v1 = un solo cliente (set completo del manifest), sin capability-set.
 */
export function projectGroupRowToDelta(
  entity: string,
  row: Record<string, unknown>,
  storedFieldHlcs: Record<string, string>,
): { fields: Record<string, unknown>; field_hlcs: Record<string, string> } {
  const spec = groupManifest.entities[entity];
  const fields: Record<string, unknown> = {};
  const field_hlcs: Record<string, string> = {};
  if (!spec) return { fields, field_hlcs };
  for (const [col, spc] of Object.entries(spec.columns)) {
    const unit = spc.group_key ?? col;
    if (col in row) fields[col] = row[col];
    if (unit in storedFieldHlcs) field_hlcs[unit] = storedFieldHlcs[unit];
  }
  return { fields, field_hlcs };
}

/**
 * Identidad de fila del canal de grupos según el `sync_id_source` del manifest:
 *   - split_groups → group_id (el group_id ES la identidad; sin sync_id)
 *   - group_members → member_key
 *   - split_expenses/shares/settlements → sync_id
 * Es la key del leaf del Merkle y el `sync_id` que se expone en el PulledGroupDelta.
 */
export function rowIdentity(entity: string, row: Record<string, unknown>): string {
  if (entity === "split_groups") return String(row.group_id ?? "");
  if (entity === "group_members") return String(row.member_key ?? "");
  return String(row.sync_id ?? "");
}
