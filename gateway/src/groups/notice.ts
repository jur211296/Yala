/**
 * Texto del aviso de actividad de un grupo (card sztn, 2026-10-30).
 *
 * Hasta hoy el fan-out mandaba a todos «Novedades en tus grupos» porque el servidor no puede leer lo que
 * guarda: nombre del grupo, concepto, importe y nombre del miembro están cifrados at-rest (bytea †). Pero
 * QUIEN SUBE sí los conoce, y en el momento de subir. El cliente adjunta al `POST /groups/push` una
 * `notice` con esos textos en claro —solo los de lo que sube—, y aquí se combinan con lo que el servidor sí
 * sabe de cada delta APLICADO: si es alta (`outcome.inserted`), edición o borrado, y de qué tabla.
 *
 * Nada de esto se guarda: viaja del cliente al payload de APNs y muere ahí. El cifrado at-rest no cambia.
 *
 * Lo resuelve iOS con `loc-key` + `loc-args` contra el `Localizable.strings` del bundle, así que cada
 * destinatario lo lee en el idioma de su iPhone. El título es el nombre del grupo, tal cual.
 *
 * Sin `notice` (un cliente anterior) o sin quién/grupo, el aviso cae al genérico de siempre: es lo único que
 * el servidor puede afirmar. Un importe ya viene formateado por el autor («S/ 40.60»): el servidor no
 * formatea dinero.
 */
import type { GroupSyncDelta } from "./types";
import type { SyncDeltaResult } from "../sync/types";

/** Lo que el cliente adjunta. Todo opcional: un campo que falta degrada el texto, nunca lo rompe. */
export interface GroupPushNotice {
  /** Nombre visible de quien sube, por `group_id` (puede usar un nombre distinto en cada grupo). */
  actors?: Record<string, string>;
  /** Nombre del grupo, por `group_id`. */
  groups?: Record<string, string>;
  /** Por `sync_id` (minúsculas) de gasto, cuota o pago. */
  rows?: Record<string, GroupPushNoticeRow>;
}

export interface GroupPushNoticeRow {
  /** Concepto del gasto. Vacío o ausente → variante sin concepto. */
  concept?: string;
  /** Importe ya formateado con su moneda. */
  amount?: string;
  /** Saldo inicial: texto propio. */
  opening?: boolean;
  /** De una cuota (`split_shares`): el `sync_id` del gasto al que pertenece. */
  parent?: string;
  /** De un pago: quién paga y quién recibe. */
  from?: string;
  to?: string;
}

/** El aviso de un grupo, listo para el `aps.alert`. */
export interface GroupNoticeAlert {
  title: string;
  locKey: string;
  locArgs: string[];
}

/**
 * Las `loc-key` que puede emitir este módulo, con cuántos `loc-args` lleva cada una. Contrato con los
 * `.lproj` de la app: `GroupPushNoticeKeysTests` lee este bloque y exige la clave en los 16 idiomas con
 * ese número de huecos.
 */
export const GROUP_NOTICE_LOC_KEYS: Record<string, number> = {
  "notifications.groups.push.expenseAdded": 3,
  "notifications.groups.push.expenseAddedNoConcept": 2,
  "notifications.groups.push.expenseEdited": 3,
  "notifications.groups.push.expenseEditedNoConcept": 2,
  "notifications.groups.push.expenseDeleted": 1,
  "notifications.groups.push.openingAdded": 2,
  "notifications.groups.push.openingEdited": 2,
  "notifications.groups.push.settlementAdded": 4,
  "notifications.groups.push.settlementEdited": 4,
  "notifications.groups.push.settlementDeleted": 1,
  "notifications.groups.push.groupUpdated": 1,
  "notifications.groups.push.several": 2,
};

type EventKind =
  | "expenseAdded"
  | "expenseEdited"
  | "expenseDeleted"
  | "openingAdded"
  | "openingEdited"
  | "settlementAdded"
  | "settlementEdited"
  | "settlementDeleted"
  | "groupUpdated";

interface NoticeEvent {
  kind: EventKind;
  /** La fila de la que habla (para fundir un gasto con sus cuotas). `group` para los ajustes. */
  key: string;
}

/** Lo que una cuota dice de su gasto. Se decide en `groupEvents`, cuando se sabe si el gasto subió en el mismo lote. */
interface ShareSignal {
  parent: string;
  inserted: boolean;
  opening: boolean;
}

/**
 * Unidades que, solas, no son noticia: marcar un gasto como saldado o una cuota como pagada lo hace el flujo
 * de liquidar, y de eso ya avisa el pago.
 */
const SILENT_UNITS: Record<string, ReadonlySet<string>> = {
  split_expenses: new Set(["is_settled"]),
  split_shares: new Set(["is_paid"]),
};

function appliedUnits(result: SyncDeltaResult): string[] | null {
  const o = result.outcome as { applied_units?: unknown } | undefined;
  if (!Array.isArray(o?.applied_units)) return null;
  return (o.applied_units as unknown[]).filter((u): u is string => typeof u === "string");
}

function inserted(result: SyncDeltaResult): boolean {
  return (result.outcome as { inserted?: unknown } | undefined)?.inserted === true;
}

/** ¿Solo cambió algo que no es noticia? Sin `applied_units` legibles se trata como noticia (avisar de más). */
function onlySilentUnits(table: string, result: SyncDeltaResult): boolean {
  const silent = SILENT_UNITS[table];
  const units = appliedUnits(result);
  if (!silent || !units || units.length === 0) return false;
  return units.every((u) => silent.has(u));
}

function eventFor(delta: GroupSyncDelta, result: SyncDeltaResult, notice: GroupPushNotice | undefined): NoticeEvent | null {
  const id = typeof delta.sync_id === "string" ? delta.sync_id.toLowerCase() : "";
  const row = id ? notice?.rows?.[id] : undefined;
  const isTombstone = delta.op === "tombstone";
  const isNew = !isTombstone && inserted(result);
  switch (delta.entity_type) {
    case "split_expenses": {
      if (isTombstone) return { kind: "expenseDeleted", key: id };
      if (!isNew && onlySilentUnits("split_expenses", result)) return null;
      const opening = row?.opening === true || delta.fields?.is_opening_balance === true;
      if (opening) return { kind: isNew ? "openingAdded" : "openingEdited", key: id };
      return { kind: isNew ? "expenseAdded" : "expenseEdited", key: id };
    }
    case "split_shares":
      // Las cuotas se resuelven aparte (`shareSignal`): solas no dicen si el gasto es nuevo o se editó.
      return null;
    case "split_settlements": {
      if (isTombstone) return { kind: "settlementDeleted", key: id };
      return { kind: isNew ? "settlementAdded" : "settlementEdited", key: id };
    }
    case "split_groups":
      return { kind: "groupUpdated", key: "group" };
    default:
      return null;
  }
}

/**
 * Una cuota habla de su gasto. Las BORRADAS no traen padre (el cliente ya no tiene la fila) y no cuentan solas: solo
 * sirven para saber que el reparto cambió. Las que solo marcan «pagada» no son noticia.
 */
function shareSignal(delta: GroupSyncDelta, result: SyncDeltaResult, notice: GroupPushNotice | undefined): ShareSignal | null {
  if (delta.entity_type !== "split_shares" || delta.op === "tombstone") return null;
  if (onlySilentUnits("split_shares", result)) return null;
  const id = typeof delta.sync_id === "string" ? delta.sync_id.toLowerCase() : "";
  const row = id ? notice?.rows?.[id] : undefined;
  const fromFields = typeof delta.fields?.expense_id === "string" ? (delta.fields.expense_id as string) : "";
  const parent = (row?.parent ?? fromFields).toLowerCase();
  if (!parent) return null;
  return { parent, inserted: inserted(result), opening: notice?.rows?.[parent]?.opening === true };
}

/** Precedencia al fundir varios eventos de la MISMA fila: alta > borrado > edición. */
const RANK: Record<EventKind, number> = {
  expenseAdded: 3,
  openingAdded: 3,
  settlementAdded: 3,
  expenseDeleted: 2,
  settlementDeleted: 2,
  expenseEdited: 1,
  openingEdited: 1,
  settlementEdited: 1,
  groupUpdated: 1,
};

/** Los eventos de un grupo en una subida: uno por fila (el alta de un gasto llega con sus cuotas y es UN gasto). */
export function groupEvents(
  groupId: string,
  deltas: GroupSyncDelta[],
  results: SyncDeltaResult[],
  notice: GroupPushNotice | undefined,
): NoticeEvent[] {
  const byKey = new Map<string, NoticeEvent>();
  const shares = new Map<string, ShareSignal[]>();
  let shareTombstones = false;
  for (let i = 0; i < deltas.length; i++) {
    const d = deltas[i];
    const r = results[i];
    if (!d || !r || r.status !== "applied" || d.group_id !== groupId) continue;
    if (d.entity_type === "split_shares") {
      if (d.op === "tombstone") shareTombstones = true;
      const sig = shareSignal(d, r, notice);
      if (sig) shares.set(sig.parent, [...(shares.get(sig.parent) ?? []), sig]);
      continue;
    }
    const ev = eventFor(d, r, notice);
    if (!ev) continue;
    const known = byKey.get(ev.key);
    if (!known || RANK[ev.kind] > RANK[known.kind]) byKey.set(ev.key, ev);
  }
  // Cuotas cuyo gasto NO subió en este lote. Editar un reparto borra las cuotas viejas y crea otras (las borradas no
  // traen padre), así que: alguna actualizada, o cuotas borradas en el lote ⇒ se editó el gasto. Todas nuevas y sin
  // borradas ⇒ es el alta de un gasto partida entre dos subidas (`pushChunkSize`): su «agregó» lo da la otra subida, y
  // aquí no se repite como «editó».
  for (const [parent, sigs] of shares) {
    if (byKey.has(parent)) continue;
    const edited = shareTombstones || sigs.some((s) => !s.inserted);
    if (!edited) continue;
    byKey.set(parent, { kind: sigs.some((s) => s.opening) ? "openingEdited" : "expenseEdited", key: parent });
  }
  return Array.from(byKey.values());
}

function clean(s: string | undefined): string {
  // Por puntos de código, no por unidades UTF-16: cortar a mitad de un emoji deja medio carácter.
  return typeof s === "string" ? Array.from(s.trim()).slice(0, 120).join("") : "";
}

/**
 * El aviso de un grupo, o `null` si no hay nada que contar o falta lo mínimo (quién y qué grupo): entonces
 * el llamador manda el genérico.
 */
export function composeGroupNotice(
  groupId: string,
  deltas: GroupSyncDelta[],
  results: SyncDeltaResult[],
  notice: GroupPushNotice | undefined,
): GroupNoticeAlert | null {
  const actor = clean(notice?.actors?.[groupId]);
  const title = clean(notice?.groups?.[groupId]);
  if (!actor || !title) return null;
  const events = groupEvents(groupId, deltas, results, notice);
  if (events.length === 0) return null;
  if (events.length > 1) {
    return { title, locKey: "notifications.groups.push.several", locArgs: [actor, String(events.length)] };
  }
  const ev = events[0];
  const row = notice?.rows?.[ev.key] ?? {};
  const concept = clean(row.concept);
  const amount = clean(row.amount) || "—";
  const k = (name: string) => `notifications.groups.push.${name}`;
  switch (ev.kind) {
    case "expenseAdded":
    case "expenseEdited":
      return concept
        ? { title, locKey: k(ev.kind), locArgs: [actor, concept, amount] }
        : { title, locKey: k(`${ev.kind}NoConcept`), locArgs: [actor, amount] };
    case "openingAdded":
    case "openingEdited":
      return { title, locKey: k(ev.kind), locArgs: [actor, amount] };
    case "settlementAdded":
    case "settlementEdited":
      return { title, locKey: k(ev.kind), locArgs: [actor, clean(row.from) || "—", clean(row.to) || "—", amount] };
    case "expenseDeleted":
    case "settlementDeleted":
    case "groupUpdated":
      return { title, locKey: k(ev.kind), locArgs: [actor] };
  }
}

/** Lee la `notice` del body sin confiar en su forma: lo que no sea string se descarta. */
export function parseGroupPushNotice(raw: unknown): GroupPushNotice | undefined {
  if (!raw || typeof raw !== "object") return undefined;
  const r = raw as Record<string, unknown>;
  const strMap = (v: unknown): Record<string, string> | undefined => {
    if (!v || typeof v !== "object") return undefined;
    const out: Record<string, string> = {};
    for (const [key, val] of Object.entries(v as Record<string, unknown>)) {
      if (typeof val === "string") out[key] = val;
    }
    return out;
  };
  const rows: Record<string, GroupPushNoticeRow> = {};
  if (r.rows && typeof r.rows === "object") {
    for (const [key, val] of Object.entries(r.rows as Record<string, unknown>)) {
      if (!val || typeof val !== "object") continue;
      const v = val as Record<string, unknown>;
      const row: GroupPushNoticeRow = {};
      for (const f of ["concept", "amount", "parent", "from", "to"] as const) {
        if (typeof v[f] === "string") row[f] = v[f] as string;
      }
      if (v.opening === true) row.opening = true;
      rows[key.toLowerCase()] = row;
    }
  }
  return { actors: strMap(r.actors), groups: strMap(r.groups), rows };
}
