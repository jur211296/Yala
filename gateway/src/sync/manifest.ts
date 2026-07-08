/**
 * capability_manifest.json — SSOT del capability-set de sync (§e.1/§d.4bis). Se COPIA a la raíz del
 * gateway en `npm run sync:manifest` (pretest/pretypecheck/predeploy) desde `../capability_manifest.json`
 * (raíz del repo Yala) para que tsc, vitest y el bundler de wrangler lo resuelvan dentro del proyecto.
 *
 * Este módulo deriva del manifest todo lo que el Worker necesita SIN hardcodear entidades/columnas/grupos:
 * - qué entidades son syncables (las 16 de dominio);
 * - el mapeo columna → unidad de coherencia (group_key) o unidad singleton (la propia columna);
 * - las columnas de cada grupo (para el invariante de emisión + el nesting por unidad que consume el RPC);
 * - la proyección (poda) del pull al capability-set del cliente (E2E-C2), grupo-entero-o-nada.
 */
import manifestJson from "../../capability_manifest.json";

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
  columns: Record<string, ColumnSpec>;
}
interface Manifest {
  manifest_version: number;
  canon_version: string;
  server_only_columns: string[];
  identity_columns: string[];
  coherence_groups: Record<string, { entity: string; columns: string[] }>;
  entities: Record<string, EntitySpec>;
}

export const manifest = manifestJson as unknown as Manifest;

/** Las 16 tablas de dominio syncables (keys del manifest). Debe casar con la whitelist del RPC. */
export const SYNCABLE_ENTITIES: readonly string[] = Object.keys(manifest.entities);

export function isSyncableEntity(entity: string): boolean {
  return Object.prototype.hasOwnProperty.call(manifest.entities, entity);
}

function entitySpec(entity: string): EntitySpec | null {
  return manifest.entities[entity] ?? null;
}

/** ¿Es `col` una columna de DOMINIO conocida de `entity`? (excluye server-only / identity). */
export function isDomainColumn(entity: string, col: string): boolean {
  const spec = entitySpec(entity);
  return !!spec && Object.prototype.hasOwnProperty.call(spec.columns, col);
}

/**
 * Unidad de resolución de una columna (§d.4bis): su `group_key` si pertenece a un grupo de
 * coherencia, o su propio nombre si es una unidad singleton field-level. `null` si no es de dominio.
 */
export function unitOfColumn(entity: string, col: string): string | null {
  const spec = entitySpec(entity);
  const c = spec?.columns[col];
  if (!c) return null;
  return c.group_key ?? col;
}

/** Mapa group_key → columnas del grupo, SOLO para esta entidad (el group_key es por (entidad,columna)). */
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
 * Valida la forma de un delta de UPSERT contra el manifest (payload PARCIAL ok) y el INVARIANTE DE
 * EMISIÓN (§d.4bis, G5): un delta que toca CUALQUIER columna de un grupo DEBE traer TODAS las columnas
 * del grupo + su unit en `field_hlcs`. Devuelve el primer error, o null si la forma es válida.
 *
 * Reglas verificadas:
 *  1. `entity` es syncable.
 *  2. cada columna de `fields` es de dominio de `entity`.
 *  3. cada unidad de `field_hlcs` es válida (group_key o columna singleton) para `entity`.
 *  4. cada columna de `fields` tiene su unidad presente en `field_hlcs`.
 *  5. cada grupo TOCADO (unidad de grupo en field_hlcs, o alguna columna del grupo en fields) trae
 *     el grupo ENTERO en `fields` — si no, `coherence_group_partial` (→ 422 + canario).
 */
export function validateUpsertShape(
  entity: string,
  fields: Record<string, unknown>,
  fieldHlcs: Record<string, string>,
): ShapeError | null {
  if (!isSyncableEntity(entity)) {
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

  // Invariante de emisión: identificar grupos tocados y exigirlos completos.
  const touchedGroups = new Set<string>();
  for (const g of Object.keys(groups)) {
    if (g in fieldHlcs) touchedGroups.add(g);
  }
  for (const col of Object.keys(fields)) {
    const c = manifest.entities[entity].columns[col];
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

/**
 * Re-agrupa un `fields` PLANO por unidad para el RPC: `{unit: {col: val}}` (§d.4bis). El RPC gatea por
 * las keys de `field_hlcs` y escribe `p_fields[unit]` de la unidad ganadora — nunca conoce la membresía.
 */
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
 * capability-set del cliente (E2E-C2). v1 iOS = set COMPLETO del manifest. Un cliente que declare una
 * versión/known-set más restringida hace que el pull PODE columnas fuera del set — grupo ENTERO o nada
 * (la membresía de grupo es congelada: si no conoces todas sus columnas, se poda el grupo completo +
 * su field_hlcs[unit], para no reintroducir el "número mal convertido").
 */
export interface CapabilitySet {
  /** Columnas conocidas por entidad; null/ausente = set completo del manifest (v1). */
  columns?: Record<string, Set<string>>;
}

/** Resuelve el capability-set desde el header/query del cliente. v1 / "full" / ausente → completo. */
export function resolveCapabilitySet(raw: string | null): CapabilitySet {
  if (!raw || raw === "v1" || raw === "full") return {}; // set completo
  // Formato explícito (futuro multi-cliente): JSON {entity: [col,...]}. Best-effort; inválido → completo.
  try {
    const parsed = JSON.parse(raw) as Record<string, string[]>;
    const columns: Record<string, Set<string>> = {};
    for (const [e, cols] of Object.entries(parsed)) columns[e] = new Set(cols);
    return { columns };
  } catch {
    return {};
  }
}

/**
 * Proyecta (poda) una fila del backend al capability-set del cliente: devuelve `fields` (columnas de
 * dominio conocidas) + `field_hlcs` (unidades correspondientes). Grupo entero o nada.
 */
export function projectRowToDelta(
  entity: string,
  row: Record<string, unknown>,
  storedFieldHlcs: Record<string, string>,
  cap: CapabilitySet,
): { fields: Record<string, unknown>; field_hlcs: Record<string, string> } {
  const spec = manifest.entities[entity];
  const known = cap.columns?.[entity]; // undefined = conoce todo
  const groups = groupsOfEntity(entity);

  // Grupos que el cliente NO conoce por completo → podar el grupo entero.
  const droppedGroups = new Set<string>();
  if (known) {
    for (const [g, cols] of Object.entries(groups)) {
      if (!cols.every((c) => known.has(c))) droppedGroups.add(g);
    }
  }

  const fields: Record<string, unknown> = {};
  const field_hlcs: Record<string, string> = {};
  for (const [col, spc] of Object.entries(spec.columns)) {
    if (known && !known.has(col)) continue; // columna fuera del set
    const unit = spc.group_key ?? col;
    if (droppedGroups.has(unit)) continue; // grupo incompleto → nada
    if (col in row) fields[col] = row[col];
    if (unit in storedFieldHlcs) field_hlcs[unit] = storedFieldHlcs[unit];
  }
  return { fields, field_hlcs };
}
