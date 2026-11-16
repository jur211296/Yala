/**
 * Escribir en Grupos desde la web (lote 3, opción A de Jürgen del 14-nov; solo staging): añadir un gasto con reparto
 * igual, apuntar un pago y crear un enlace de invitación.
 *
 * Quién escribe de verdad: el gateway, por la entrada interna `WebGroupsWriter` (service binding
 * `GATEWAY_GROUPS_WRITER`, `gateway/src/web/groupsWriter.ts`). Allí viven la llave de Grupos, la lista cerrada de
 * operaciones, las reglas de la app (reparto igual, quién confirma un pago) y el límite por cuenta. La web solo traduce
 * el formulario y su respuesta; nunca manda un delta.
 *
 * El token que pasa es el de la sesión, con el rol propio de la web (`yala_web`, web3_02). Uno emitido antes de web3_02
 * lleva el rol de solo lectura: el gateway responde `role` y la ruta lo renueva una vez y repite (`app.ts`).
 */
export type WebWriteError =
  | "disabled"
  | "token"
  | "role"
  | "groups_off"
  | "no_key"
  | "rate"
  | "not_found"
  | "not_allowed"
  | "invalid"
  | "upstream";

export type WebWriteResult = { ok: true; status: "applied" | "already" } | { ok: false; error: WebWriteError; detail?: string };
export type WebInviteResult = { ok: true; url: string; expiresAt: string } | { ok: false; error: WebWriteError; detail?: string };

export interface WebExpenseInput {
  groupId: string;
  id: string;
  description: string;
  amount: number;
  currency: string;
  paidBy: string;
  date: string;
  participants: string[];
}

export interface WebSettlementInput {
  groupId: string;
  id: string;
  from: string;
  to: string;
  amount: number;
  currency: string;
  date: string;
  note?: string;
}

/** El service binding al gateway (entrada `WebGroupsWriter`). */
export interface GroupsWriterBinding {
  addExpense(token: string, input: WebExpenseInput): Promise<WebWriteResult>;
  addSettlement(token: string, input: WebSettlementInput): Promise<WebWriteResult>;
  createInvite(token: string, groupId: string): Promise<WebInviteResult>;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const GROUP_ID_RE = /^[A-Za-z0-9._:-]{1,120}$/;
const KEY_RE = /^[^\s]{1,120}$/;

const s = (v: unknown) => (typeof v === "string" ? v : "");
const n = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : NaN);

export type Parsed<T> = { ok: true; value: T } | { ok: false; campo: string };

/** El formulario de «Nuevo gasto». La validación de fondo (miembros, divisas, céntimos) la hace el gateway. */
export function parseExpense(body: unknown): Parsed<WebExpenseInput> {
  const b = (body ?? {}) as Record<string, unknown>;
  const groupId = s(b.grupo);
  if (!GROUP_ID_RE.test(groupId)) return { ok: false, campo: "grupo" };
  const id = s(b.id).toLowerCase();
  if (!UUID_RE.test(id)) return { ok: false, campo: "id" };
  const description = s(b.descripcion).trim();
  if (!description || description.length > 120) return { ok: false, campo: "descripcion" };
  const amount = n(b.importe);
  if (!(amount > 0)) return { ok: false, campo: "importe" };
  const currency = s(b.divisa);
  if (!/^[A-Z]{3}$/.test(currency)) return { ok: false, campo: "divisa" };
  const paidBy = s(b.pagadoPor);
  if (!KEY_RE.test(paidBy)) return { ok: false, campo: "pagadoPor" };
  const date = s(b.fecha);
  if (!date || !Number.isFinite(Date.parse(date))) return { ok: false, campo: "fecha" };
  const participants = Array.isArray(b.participantes) ? b.participantes.map(s) : [];
  if (participants.length === 0 || participants.length > 50 || participants.some((p) => !KEY_RE.test(p))) return { ok: false, campo: "participantes" };
  return { ok: true, value: { groupId, id, description, amount, currency, paidBy, date, participants } };
}

/** El formulario de «Saldar». */
export function parseSettlement(body: unknown): Parsed<WebSettlementInput> {
  const b = (body ?? {}) as Record<string, unknown>;
  const groupId = s(b.grupo);
  if (!GROUP_ID_RE.test(groupId)) return { ok: false, campo: "grupo" };
  const id = s(b.id).toLowerCase();
  if (!UUID_RE.test(id)) return { ok: false, campo: "id" };
  const from = s(b.de);
  const to = s(b.a);
  if (!KEY_RE.test(from) || !KEY_RE.test(to) || from === to) return { ok: false, campo: "personas" };
  const amount = n(b.importe);
  if (!(amount > 0)) return { ok: false, campo: "importe" };
  const currency = s(b.divisa);
  if (!/^[A-Z]{3}$/.test(currency)) return { ok: false, campo: "divisa" };
  const date = s(b.fecha);
  if (!date || !Number.isFinite(Date.parse(date))) return { ok: false, campo: "fecha" };
  const note = s(b.nota).trim();
  if (note.length > 300) return { ok: false, campo: "nota" };
  return { ok: true, value: { groupId, id, from, to, amount, currency, date, ...(note ? { note } : {}) } };
}

/** Del error del gateway a la respuesta de la web: estado HTTP y cuerpo. `campo` traduce el detalle del gateway. */
export function writeErrorResponse(r: { error: WebWriteError; detail?: string }): { status: number; body: Record<string, unknown> } {
  const campo: Record<string, string> = {
    description: "descripcion",
    amount: "importe",
    currency: "divisa",
    paidBy: "pagadoPor",
    participants: "participantes",
    members: "personas",
    date: "fecha",
    note: "nota",
    id: "id",
    group: "grupo",
  };
  switch (r.error) {
    case "invalid":
      return { status: 400, body: { error: "entrada", campo: campo[r.detail ?? ""] ?? "otro" } };
    case "not_found":
      return { status: 404, body: { error: "no_existe" } };
    case "not_allowed":
      return { status: 403, body: { error: "no_permitido", motivo: r.detail === "archived" ? "archivado" : r.detail === "invite" ? "invitar" : "miembro" } };
    case "rate":
      return { status: 429, body: { error: "limite" } };
    case "disabled":
    case "groups_off":
      return { status: 409, body: { error: "escritura_apagada" } };
    default:
      return { status: 503, body: { error: "grupos_no_disponible", motivo: r.error } };
  }
}
