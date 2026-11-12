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
  /** manifest_version que estrenó la columna (ausente = 1). Ver `resolveGroupCapabilitySet`. */
  since?: number;
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

/**
 * Versión del manifest de GRUPOS de este Worker. Se anuncia en `/groups/pull` y `/groups/merkle` (`manifest_version`):
 * el cliente iOS declara la menor entre la suya y ésta (`GroupsSyncCapability.swift`), como en el canal personal
 * (`sync/manifest.ts::MANIFEST_VERSION`). Es una versión DISTINTA de la personal: cada canal tiene su manifest.
 */
export const GROUP_MANIFEST_VERSION: number = groupManifest.manifest_version;

/**
 * Nivel que se supone a un cliente que NO manda `X-Yala-Capability-Set`. CONGELADO en 2, a propósito, y no ligado a
 * `GROUP_MANIFEST_VERSION`: hasta el 2026-10-24 ningún iOS mandaba la cabecera en el canal de Grupos, y todos los
 * publicados ya conocían `split_groups.budget_limit_amount` (since 2, g14_01). El que no la conoce habla canon `c1` y
 * su `verifyGroupIntegrity` salta el Merkle por el guard de canon. Cuando entre una columna con `since: 3`, esos
 * teléfonos siguen recibiendo v2 —sin ella—, que es justo lo que entienden.
 */
export const GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER = 2;

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
 * capability-set del cliente de GRUPOS (espejo de `sync/manifest.ts::CapabilitySet`). `columns` ausente = el set
 * completo del manifest; presente = las columnas que el cliente conoce por entidad, y el pull y el Merkle podan el
 * resto (grupo de coherencia entero o nada).
 */
export interface GroupCapabilitySet {
  columns?: Record<string, Set<string>>;
}

/**
 * Resuelve el capability-set de Grupos desde la cabecera `X-Yala-Capability-Set` (o la query `capability_set`).
 *  - AUSENTE → nivel `GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER` (2), congelado: ver su docblock.
 *  - `vN` → las columnas con `since <= N` (ausente = 1); `v0` se lee como v1; `vN` >= este Worker → completo.
 *  - `full`, o un valor ilegible → completo, con el mismo criterio que el canal personal (`resolveCapabilitySet`),
 *    incluido su formato explícito JSON `{entity: [col,...]}`.
 * Medido el 2026-10-24: sin esto, `merkleColumnsGroup` hasheaba TODAS las columnas del manifest y una columna nueva
 * cambiaba la hoja de cada fila (el canon serializa el NULL como `key:null`) ⇒ divergencia falsa en el 100 % de los
 * grupos de cada teléfono que no la conociera. Por eso `budget_limit_amount` tuvo que bumpear `canon_version` a `c2`.
 */
export function resolveGroupCapabilitySet(raw: string | null | undefined): GroupCapabilitySet {
  if (raw === null || raw === undefined || raw === "") return capabilityForLevel(GROUP_CAPABILITY_LEVEL_WITHOUT_HEADER);
  if (raw === "full") return {};
  const version = /^v(\d+)$/.exec(raw);
  if (version) return capabilityForLevel(Number(version[1]));
  // Formato explícito (futuro multi-cliente): JSON {entity: [col,...]}. Best-effort; inválido → completo.
  try {
    const parsed = JSON.parse(raw) as Record<string, string[]>;
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    const columns: Record<string, Set<string>> = {};
    for (const [e, cols] of Object.entries(parsed)) {
      if (Array.isArray(cols)) columns[e] = new Set(cols.map(String));
    }
    return { columns };
  } catch {
    return {};
  }
}

/** capability-set de un nivel: completo si alcanza a este Worker; si no, las columnas con `since <= level`. */
function capabilityForLevel(rawLevel: number): GroupCapabilitySet {
  const level = Math.max(1, rawLevel);
  if (level >= GROUP_MANIFEST_VERSION) return {};
  return { columns: groupColumnsUpTo(level) };
}

/** Columnas de cada entidad de Grupos que existen en la versión `level` del manifest (`since` ausente = 1). */
export function groupColumnsUpTo(level: number): Record<string, Set<string>> {
  const columns: Record<string, Set<string>> = {};
  for (const [entity, spec] of Object.entries(groupManifest.entities)) {
    columns[entity] = new Set(
      Object.entries(spec.columns)
        .filter(([, c]) => (c.since ?? 1) <= level)
        .map(([col]) => col),
    );
  }
  return columns;
}

/**
 * Grupos de coherencia de `entity` que el cliente NO conoce por completo: se podan enteros (columnas + su unidad en
 * `field_hlcs`), para no reintroducir el «número mal convertido». Vacío si el cliente conoce todo.
 */
export function droppedGroupsFor(entity: string, cap: GroupCapabilitySet): Set<string> {
  const dropped = new Set<string>();
  const known = cap.columns?.[entity];
  if (!known) return dropped;
  for (const [g, cols] of Object.entries(groupsOfEntity(entity))) {
    if (!cols.every((c) => known.has(c))) dropped.add(g);
  }
  return dropped;
}

/**
 * Proyecta (poda) una fila del backend al capability-set del cliente: `fields` (columnas de dominio que conoce) +
 * `field_hlcs` (sus unidades). Grupo de coherencia entero o nada. Espejo de `sync/manifest.ts::projectRowToDelta`.
 */
export function projectGroupRowToDelta(
  entity: string,
  row: Record<string, unknown>,
  storedFieldHlcs: Record<string, string>,
  cap: GroupCapabilitySet,
): { fields: Record<string, unknown>; field_hlcs: Record<string, string> } {
  const spec = groupManifest.entities[entity];
  const fields: Record<string, unknown> = {};
  const field_hlcs: Record<string, string> = {};
  if (!spec) return { fields, field_hlcs };
  const known = cap.columns?.[entity]; // undefined = conoce todo
  const dropped = droppedGroupsFor(entity, cap);
  for (const [col, spc] of Object.entries(spec.columns)) {
    if (known && !known.has(col)) continue; // columna fuera del set del cliente
    const unit = spc.group_key ?? col;
    if (dropped.has(unit)) continue; // grupo incompleto → nada
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
