/**
 * Grupos en la web (lote 3), en LECTURA.
 *
 * De dónde salen las filas: el gateway, por la entrada interna `WebGroupsReader` (service binding `GATEWAY_GROUPS`,
 * `gateway/src/web/groupsReader.ts`). Ocho columnas de Grupos están cifradas y la llave solo vive allí; la web le pasa
 * su token de solo lectura y recibe las filas ya descifradas de los grupos de los que la persona es miembro activa.
 *
 * Cómo se calculan los saldos: con `shared-core/src/logic/groupBalances.ts`, el port de `GroupBalanceService` con su
 * golden de paridad (`mcp/test/groups-parity.test.ts`). Con «una sola moneda», cada deuda se convierte a la divisa del
 * grupo con la tasa de hoy de las filas de la persona (o la tabla estática si no tiene, como una cuenta «solo Grupos»):
 * la app usa la última tasa de su propio almacén, así que una tasa de otro día puede dar otro céntimo (diferencia
 * declarada).
 *
 * Qué grupos salen: los de membresía ACTIVA (el gateway filtra) y sin `is_hidden_for_all`. Los archivados salen con su
 * marca, al final, porque pueden seguir teniendo deudas, pero NO suman al resumen de arriba ni a los pagos por confirmar
 * (como `GroupsViewModel.recalculate`, que los lleva aparte).
 *
 * Nombres: se devuelven tal cual. El de quien borró su cuenta llega como `__deleted_user__` y lo traduce la página
 * (`SplitMember.resolvedDisplayName` en la app).
 */
import {
  globalSummary,
  headerBalance,
  shownBalances,
  shownDebts,
  sortDebts,
  type GroupSource,
  type HeaderBalance,
  type LatestConverter,
} from "../../../shared-core/src/logic/groupBalances";
import { convertOn, type RateBook } from "../../../shared-core/src/logic/fx";

type Row = Record<string, unknown>;

export interface WebGroupRows {
  group_id: string;
  me: string;
  group: Row | null;
  members: Row[];
  expenses: Row[];
  shares: Row[];
  settlements: Row[];
}

export type WebGroupsResult =
  | { ok: true; groups: WebGroupRows[]; truncated: boolean }
  | { ok: false; error: string };

/** El service binding al gateway (entrada `WebGroupsReader`). */
export interface GroupsReaderBinding {
  snapshot(token: string, only?: string): Promise<WebGroupsResult>;
}

export class GroupsUnavailableError extends Error {
  constructor(readonly reason: string) {
    super(`grupos: ${reason}`);
  }
}

function str(v: unknown): string {
  return typeof v === "string" ? v : v == null ? "" : String(v);
}

/** Los importes llegan como texto decimal exacto (escala 4) desde los RPC lectores. Uno ilegible cuenta 0. */
function amount(v: unknown): number {
  const n = typeof v === "number" ? v : Number(str(v));
  return Number.isFinite(n) ? n : 0;
}

function bool(v: unknown): boolean {
  return v === true || v === "true";
}

function code(v: unknown): string {
  return str(v).trim().toUpperCase();
}

export function toSource(g: WebGroupRows): GroupSource {
  const meta = g.group ?? {};
  return {
    expenses: g.expenses.map((e) => ({
      id: str(e.sync_id),
      amount: amount(e.amount),
      currency: code(e.currency_code),
      paidBy: str(e.paid_by_member_key),
      isSettled: bool(e.is_settled),
    })),
    shares: g.shares.map((s) => ({ expenseId: str(s.expense_id), member: str(s.member_key), amount: amount(s.amount) })),
    settlements: g.settlements.map((s) => ({
      from: str(s.from_member_key),
      to: str(s.to_member_key),
      amount: amount(s.amount),
      currency: code(s.currency_code),
      isConfirmed: bool(s.is_confirmed),
    })),
    simplifyDebts: bool(meta.simplify_debts),
    singleCurrency: bool(meta.show_debts_in_single_currency) && code(meta.currency_code) ? code(meta.currency_code) : null,
  };
}

export function converterFor(book: RateBook, todayKey: string): LatestConverter {
  return (value, from, to) => convertOn(value, from, to, todayKey, book)?.value ?? value;
}

function visible(g: WebGroupRows): boolean {
  return !bool(g.group?.is_hidden_for_all);
}

function memberName(g: WebGroupRows, key: string): string {
  const m = g.members.find((r) => str(r.member_key) === key);
  const name = m ? str(m.display_name).trim() : "";
  return name;
}

function moneyList(map: Record<string, number>): { divisa: string; importe: number }[] {
  return Object.entries(map)
    .filter(([, v]) => v > 0.01)
    .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1))
    .map(([divisa, importe]) => ({ divisa, importe }));
}

function band(h: HeaderBalance) {
  return { estado: h.state, teDeben: moneyList(h.owedToMe), debes: moneyList(h.iOwe) };
}

async function snapshot(binding: GroupsReaderBinding | undefined, token: string, only?: string): Promise<{ groups: WebGroupRows[]; truncated: boolean }> {
  if (!binding) throw new GroupsUnavailableError("sin_binding");
  const r = only ? await binding.snapshot(token, only) : await binding.snapshot(token);
  if (!r.ok) throw new GroupsUnavailableError(r.error);
  return { groups: r.groups.filter(visible), truncated: r.truncated };
}

/** La lista: el resumen de arriba (lo que te deben y lo que debes, por divisa) y una tarjeta por grupo. */
export async function groupsList(binding: GroupsReaderBinding | undefined, token: string, convert: LatestConverter) {
  const { groups, truncated } = await snapshot(binding, token);
  const all = groups.map((g) => ({ g, source: toSource(g) }));
  const active = all.filter(({ g }) => !bool(g.group?.is_archived));
  const summary = globalSummary(active.map(({ g, source }) => ({ source, me: new Set([g.me]) })), convert);
  const grupos = all
    .map(({ g, source }) => {
      const debts = sortDebts(shownDebts(source, convert));
      const meta = g.group ?? {};
      const personas = debts
        .filter((d) => d.from === g.me || d.to === g.me)
        .map((d) => ({
          nombre: memberName(g, d.from === g.me ? d.to : d.from),
          sentido: d.from === g.me ? ("debes" as const) : ("teDebe" as const),
          importe: d.amount,
          divisa: d.currency,
        }))
        .sort((a, b) => (a.sentido === b.sentido ? b.importe - a.importe : a.sentido === "debes" ? -1 : 1));
      return {
        id: g.group_id,
        nombre: str(meta.name).trim(),
        icono: str(meta.icon_name) || null,
        color: str(meta.color_hex) || null,
        divisa: code(meta.currency_code) || null,
        archivado: bool(meta.is_archived),
        miembros: g.members.filter((m) => str(m.status) === "active").length,
        gastos: g.expenses.length,
        banda: band(headerBalance(debts, g.me)),
        personas,
      };
    })
    // Primero lo que tiene algo pendiente contigo; después, en el orden del gateway (te uniste más reciente primero). Los
    // archivados, al final. `sort` es estable: dentro de cada bloque se conserva ese orden.
    .sort((a, b) => Number(a.archivado) - Number(b.archivado) || Number(a.banda.estado === "settled") - Number(b.banda.estado === "settled"));
  return {
    resumen: { teDeben: moneyList(summary.owedToMe), debes: moneyList(summary.iOwe), pagosPorConfirmar: summary.pendingSettlements },
    grupos,
    incompleto: truncated,
  };
}

/** El detalle de un grupo: banda, quién le debe a quién, saldos por persona, gastos y pagos. `null` si no es suyo. */
export async function groupDetail(binding: GroupsReaderBinding | undefined, token: string, id: string, convert: LatestConverter) {
  const { groups, truncated } = await snapshot(binding, token, id);
  const g = groups.find((x) => x.group_id === id);
  if (!g) return null;
  const meta = g.group ?? {};
  const source = toSource(g);
  const debts = sortDebts(shownDebts(source, convert));
  const name = (k: string) => memberName(g, k);
  const sharesByExpense = new Map<string, Row[]>();
  for (const s of g.shares) {
    const k = str(s.expense_id);
    sharesByExpense.set(k, [...(sharesByExpense.get(k) ?? []), s]);
  }
  const gastos = g.expenses
    .map((e) => {
      const mine = (sharesByExpense.get(str(e.sync_id)) ?? []).find((s) => str(s.member_key) === g.me);
      return {
        id: str(e.sync_id),
        descripcion: str(e.expense_description).trim(),
        nota: str(e.note).trim() || null,
        importe: amount(e.amount),
        divisa: code(e.currency_code),
        fecha: str(e.date) || null,
        pagadoPor: name(str(e.paid_by_member_key)),
        pagasteTu: str(e.paid_by_member_key) === g.me,
        tuParte: mine ? amount(mine.amount) : null,
        categoria: str(e.subcategory_name).trim() || null,
        saldoInicial: bool(e.is_opening_balance),
        saldado: bool(e.is_settled),
      };
    })
    .sort((a, b) => str(b.fecha).localeCompare(str(a.fecha)) || a.id.localeCompare(b.id));
  const pagos = g.settlements
    .map((s) => ({
      id: str(s.sync_id),
      de: name(str(s.from_member_key)),
      a: name(str(s.to_member_key)),
      deTi: str(s.from_member_key) === g.me,
      aTi: str(s.to_member_key) === g.me,
      importe: amount(s.amount),
      divisa: code(s.currency_code),
      fecha: str(s.date) || null,
      confirmado: bool(s.is_confirmed),
      nota: str(s.note).trim() || null,
    }))
    .sort((a, b) => str(b.fecha).localeCompare(str(a.fecha)) || a.id.localeCompare(b.id));
  const saldos = shownBalances(source, convert).map((b) => ({
    nombre: name(b.member),
    esTu: b.member === g.me,
    divisa: b.currency,
    pago: b.totalPaid,
    leToca: b.totalOwes,
    neto: b.net,
  }));
  return {
    id: g.group_id,
    nombre: str(meta.name).trim(),
    divisa: code(meta.currency_code) || null,
    archivado: bool(meta.is_archived),
    incompleto: truncated,
    menosPagos: source.simplifyDebts,
    unaSolaMoneda: source.singleCurrency,
    miembros: g.members
      .filter((m) => str(m.status) === "active")
      .map((m) => ({ nombre: str(m.display_name).trim(), rol: str(m.role) || "member", esTu: str(m.member_key) === g.me }))
      .sort((a, b) => Number(b.esTu) - Number(a.esTu) || a.nombre.localeCompare(b.nombre, "es")),
    banda: band(headerBalance(debts, g.me)),
    deudas: debts.map((d) => ({ de: name(d.from), a: name(d.to), deTi: d.from === g.me, aTi: d.to === g.me, importe: d.amount, divisa: d.currency })),
    saldos,
    gastos,
    pagos,
  };
}
