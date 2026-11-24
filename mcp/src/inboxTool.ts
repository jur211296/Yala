/**
 * `ver_bandeja` y lo que comparte con `apuntar_movimiento`: qué hay ya en la Bandeja antes de apuntar nada (lote 5 de
 * «Bandeja sin duplicados», `docs/propuestas/bandeja-sin-duplicados/README.md`; decisión de Jürgen del 24-nov).
 *
 * Dos sitios, porque un borrador vive en dos sitios hasta que la persona lo confirma:
 * - **la Bandeja del iPhone** (`inbox_drafts`, en la nube): lo que la app ya recogió y espera confirmación. Se lee con la
 *   sesión de solo lectura y SOLO las columnas que enseña Yala web (`webapp/src/worker/data.ts`, `INBOX_COLUMNS`; el
 *   permiso es `webapp/supabase/web1_01`). Nunca `raw_text`, lo que dictó o fotografió la persona;
 * - **la cola del gateway**: lo que llegó del correo, de Yala web o de una IA y el iPhone aún no recogió
 *   (`ConnectorDrafts.pending`).
 *
 * Grupos y cuentas compartidas quedan fuera (decisión del 24-nov): ni los borradores del puente de Grupos ni los
 * movimientos de cuentas de sistema o con gasto compartido.
 */
import { z } from "zod";
import { NOT_DELETED } from "./data";
import { addDays, dayInZone, txDay } from "./logic/dates";
import { num, type AccountRow, type TxRow } from "./logic/types";
import { loadLookup, loadPrefs, loadTxInRange, zoneNotice, zoneOf, type ToolContext } from "./toolCore";

export const INBOX_TOOL_NAME = "ver_bandeja";
export const INBOX_TOOL_TITLE = "Ver la Bandeja";
export const INBOX_TOOL_DESCRIPTION =
  "Devuelve los borradores de la Bandeja de Yala que el usuario aún no confirmó ni descartó («pendientes»), y los que " +
  "esperan a que la app los recoja («en_cola»: del correo del banco, de Yala web o apuntados por una IA). Ninguno cuenta " +
  "todavía en saldos ni presupuestos. Cada uno trae de dónde vino, importe, divisa, nota, día, cuenta y categoría. No " +
  "incluye los de Grupos ni el texto original de cada captura. Sirve para saber si un gasto ya está apuntado antes de " +
  "usar apuntar_movimiento.";

export const INBOX_TOOL_INPUT = {
  zona_horaria: z
    .string()
    .max(64)
    .optional()
    .describe("Zona horaria IANA del usuario, por ejemplo America/Lima. Decide en qué día cae cada borrador."),
};

/** Lo que el gateway devuelve de su cola (`QueuedDraftView` de `gateway/src/connector/store.ts`). */
export interface QueuedDraftView {
  fuente: "correo" | "web" | "ia";
  ia: string | null;
  kind: "expense" | "income";
  amount: number;
  currency: string | null;
  merchant: string | null;
  date: string | null;
  account_ref: string | null;
  account_name: string | null;
  subcategory_ref: string | null;
  subcategory_name: string | null;
  bank: string | null;
  account_last4: string | null;
  created_at: string;
}

/** Un candidato de la regla de coincidencia del gateway (`MatchCandidate` de `gateway/src/connector/match.ts`). */
export interface MatchCandidate {
  donde: "cola" | "bandeja" | "guardado";
  fuente: string;
  kind: "expense" | "income";
  amount: number;
  currency: string | null;
  day: string | null;
  account_id: string | null;
  account_name: string | null;
  merchant: string | null;
}

/** Las columnas de la Bandeja que enseña Yala web, y las únicas que el rol de lectura puede leer. */
const INBOX_COLUMNS =
  "sync_id,note,amount,date,cached_currency_code,cached_account_name,cached_subcategory_name,source_type_raw,evidence,created_at,needs_user_input";
/** Lo que pide Yala web: la Bandeja de una persona no pasa de unas decenas. */
export const INBOX_LIMIT = 200;

interface InboxRow {
  sync_id: string;
  note: string | null;
  amount: number | string | null;
  date: string | null;
  cached_currency_code: string | null;
  cached_account_name: string | null;
  cached_subcategory_name: string | null;
  source_type_raw: string | null;
  evidence: string | null;
  created_at: string | null;
  needs_user_input: string[] | null;
  /** No se pide: el filtro va en la consulta. Si llega, se respeta igual. */
  status_raw?: string | null;
  deleted?: boolean | null;
}

/** Los orígenes del puente de Grupos (`DraftSourceType.isFromGroup` y el pago planificado de grupo). Fuera de esta tanda. */
const GROUP_SOURCES = new Set(["groupExpense", "groupSettlement", "groupScheduledExpense"]);

/** De dónde vino un borrador, en palabras (molde de `InboxDraft.sourceDisplayName` de la app). */
export function inboxSourceLabel(raw: string | null, evidence: string | null): string {
  switch (raw) {
    case "voice":
      return "Voz";
    case "receiptPhoto":
      return "Foto de recibo";
    case "screenshotList":
    case "screenshotSingle":
      return "Captura de pantalla";
    case "emailAlert":
      return "Correo del banco";
    case "scheduledPayment":
      return "Pago planificado";
    case "subscription":
      return "Suscripción";
    case "applePay":
      return "Apple Pay";
    case "automation":
      return "Aviso del banco o automatización";
    case "siri":
      return "Siri";
    case "manual":
      return "A mano";
    case "aiConnector":
      return evidence?.trim() || "Tu IA";
    default:
      return "Yala";
  }
}

/** La fuente en la regla de coincidencia: la IA es `ai:<IA>`, como en la cola del gateway. */
export function inboxFuente(raw: string | null, evidence: string | null): string {
  if (raw === "aiConnector") return `ai:${evidence?.trim() ?? ""}`;
  return raw ?? "voice";
}

const NEEDS: Record<string, string> = { account: "cuenta", subcategory: "categoría", amount: "importe", date: "fecha" };

async function readInbox(ctx: ToolContext): Promise<InboxRow[]> {
  const rows = await ctx.reader.one<InboxRow>(
    "inbox_drafts",
    [["select", INBOX_COLUMNS], NOT_DELETED, ["status_raw", "eq.pending"], ["order", "created_at.desc,sync_id.asc"]],
    INBOX_LIMIT,
  );
  return rows.filter(
    (r) => r.deleted !== true && (r.status_raw ?? "pending") === "pending" && !GROUP_SOURCES.has(r.source_type_raw ?? ""),
  );
}

function inboxDay(row: InboxRow, tz: string): string | null {
  const when = row.date ?? row.created_at;
  if (!when) return null;
  const d = new Date(when);
  return Number.isNaN(d.getTime()) ? null : dayInZone(d, tz);
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Los pendientes de la Bandeja como candidatos de la regla. Sin importe no se pueden comparar. */
export function inboxCandidates(rows: InboxRow[], tz: string): MatchCandidate[] {
  const out: MatchCandidate[] = [];
  for (const r of rows) {
    const amount = num(r.amount);
    if (amount === null || amount === 0) continue;
    out.push({
      donde: "bandeja",
      fuente: inboxFuente(r.source_type_raw, r.evidence),
      kind: amount < 0 ? "expense" : "income",
      amount: round2(Math.abs(amount)),
      currency: r.cached_currency_code?.toUpperCase() ?? null,
      day: inboxDay(r, tz),
      account_id: null,
      account_name: r.cached_account_name ?? null,
      merchant: r.note?.trim() ? r.note.trim().slice(0, 80) : null,
    });
  }
  return out;
}

/** Los movimientos guardados como candidatos. Sin transferencias, ajustes de saldo ni nada de Grupos. */
export function savedCandidates(rows: TxRow[], accounts: Map<string, AccountRow>, tz: string): MatchCandidate[] {
  const out: MatchCandidate[] = [];
  for (const t of rows) {
    if (t.transfer_pair_id || t.balance_adjustment_type || t.split_expense_id) continue;
    if (t.account_ref && accounts.get(t.account_ref)?.is_system_account === true) continue;
    const amount = num(t.amount);
    if (amount === null || amount === 0) continue;
    out.push({
      donde: "guardado",
      fuente: "guardado",
      kind: amount < 0 ? "expense" : "income",
      amount: round2(Math.abs(amount)),
      currency: t.currency_code?.toUpperCase() ?? null,
      day: txDay(t, tz),
      account_id: t.account_ref,
      account_name: t.account_ref ? (accounts.get(t.account_ref)?.name ?? null) : null,
      merchant: t.note?.trim() ? t.note.trim().slice(0, 80) : null,
    });
  }
  return out;
}

/** Los días alrededor del movimiento que se miran entre lo guardado: el margen dudoso de la regla (±3). */
export const SAVED_WINDOW_DAYS = 3;

/**
 * Lo que el gateway necesita para comparar y no puede leer él (no tiene la sesión de la persona): los pendientes de la
 * Bandeja y los movimientos guardados de ±3 días alrededor del día del movimiento.
 */
export async function loadMatchCandidates(
  ctx: ToolContext,
  accounts: Map<string, AccountRow>,
  day: string,
  tz: string,
): Promise<MatchCandidate[]> {
  const [inbox, saved] = await Promise.all([
    readInbox(ctx),
    loadTxInRange(ctx, addDays(day, -SAVED_WINDOW_DAYS), addDays(day, SAVED_WINDOW_DAYS), tz),
  ]);
  const savedInWindow = savedCandidates(saved.rows, accounts, tz).filter((c) => {
    if (!c.day) return false;
    return c.day >= addDays(day, -SAVED_WINDOW_DAYS) && c.day <= addDays(day, SAVED_WINDOW_DAYS);
  });
  return [...inboxCandidates(inbox, tz), ...savedInWindow];
}

/** El binding de la cola, para leer lo que espera. */
export interface QueueReader {
  pending(userId: string): Promise<QueuedDraftView[] | null>;
}

export async function runInboxTool(ctx: ToolContext, deps: { queue: QueueReader; sub: string }, args: Record<string, unknown>) {
  const prefsP = loadPrefs(ctx);
  prefsP.catch(() => undefined); // si la zona falla antes de esperarla, que su rechazo no quede suelto
  const zone = await zoneOf(ctx, args, prefsP);
  const [rows, queued, lookup] = await Promise.all([readInbox(ctx), deps.queue.pending(deps.sub), loadLookup(ctx)]);

  const pendientes = rows.map((r) => {
    const amount = num(r.amount);
    return {
      fuente: inboxSourceLabel(r.source_type_raw, r.evidence),
      detalle: r.evidence?.trim() || null,
      tipo: amount === null ? null : amount < 0 ? "gasto" : "ingreso",
      importe: amount === null ? null : round2(Math.abs(amount)),
      divisa: r.cached_currency_code?.toUpperCase() ?? null,
      nota: r.note?.trim() || null,
      fecha: inboxDay(r, zone.tz),
      cuenta: r.cached_account_name ?? null,
      categoria: r.cached_subcategory_name ?? null,
      falta: (r.needs_user_input ?? []).map((n) => NEEDS[n] ?? n),
      llego: r.created_at,
    };
  });

  const nameOf = (id: string | null, map: Map<string, { name: string | null }>) => (id ? (map.get(id)?.name ?? null) : null);
  const enCola = (queued ?? []).map((q) => ({
    fuente: q.fuente === "ia" ? (q.ia ?? "Tu IA") : q.fuente === "web" ? "Yala web" : "Correo del banco",
    detalle: [q.bank, q.account_last4 ? `****${q.account_last4}` : null].filter(Boolean).join(" · ") || null,
    tipo: q.kind === "income" ? "ingreso" : "gasto",
    importe: q.amount,
    divisa: q.currency,
    nota: q.merchant,
    fecha: q.date ?? dayInZone(new Date(q.created_at), zone.tz),
    cuenta: q.account_name ?? nameOf(q.account_ref, lookup.accounts),
    categoria: q.subcategory_name ?? nameOf(q.subcategory_ref, lookup.subcategories),
    llego: q.created_at,
  }));

  const avisos = [
    "Nada de esto cuenta todavía en saldos ni presupuestos: el usuario lo confirma o lo descarta en la Bandeja de la app.",
    ...(rows.length >= INBOX_LIMIT ? [`Se muestran los ${INBOX_LIMIT} pendientes más recientes.`] : []),
    ...(queued === null ? ["No se pudo leer lo que espera a que la app lo recoja."] : []),
    ...zoneNotice(zone),
  ];
  return { pendientes, en_cola: enCola, avisos };
}
