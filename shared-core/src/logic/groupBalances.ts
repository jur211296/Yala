/**
 * Saldos y deudas de un grupo: port de `GroupBalanceService` y `DebtSimplificationService`
 * (`Yala/Services/Groups/`), sin cambios de regla. Yala web, lote 3.
 *
 * - Una deuda por cada reparto de un gasto NO saldado (`is_settled = false`) cuyo miembro no es quien pagó y cuyo
 *   importe pasa de 0,01; cada pago CONFIRMADO entra como deuda inversa.
 * - Sin «Menos pagos entre ustedes», las deudas del mismo par y divisa se netean (`consolidate`). Con él, el flujo
 *   mínimo por divisa (`simplify`): empareja al mayor acreedor con el mayor deudor hasta dejar todo a menos de 0,01.
 * - Con «una sola moneda» (`show_debts_in_single_currency`) y alguna deuda en otra divisa, cada deuda se convierte a
 *   la del grupo con la última tasa y se vuelve a netear (`consolidatedDebts`).
 * - La banda del detalle (`headerBalance`) netea por divisa lo que te deben menos lo que debes.
 * - El resumen de la lista (`globalSummary`) suma, grupo a grupo y con las opciones de cada uno, lo que te deben y lo
 *   que debes por divisa.
 *
 * Redondeo: el de la app, `(x * 100).rounded() / 100`, que redondea las mitades ALEJÁNDOSE de cero (`Math.round` las
 * sube hacia +∞ y daría otro céntimo en los negativos).
 *
 * Una diferencia declarada: con dos acreedores (o dos deudores) empatados, la app elige el primero que devuelve su
 * diccionario, que no tiene orden; aquí desempata el `member_key` menor. Lo que cada persona debe o le deben en total
 * no cambia con el desempate; solo QUIÉN le paga a quién. El golden de paridad no tiene empates.
 */

const EPSILON = 0.01;

export interface Debt {
  from: string;
  to: string;
  amount: number;
  currency: string;
}

export interface GroupExpenseInput {
  id: string;
  amount: number;
  currency: string;
  paidBy: string;
  isSettled: boolean;
}

export interface GroupShareInput {
  expenseId: string;
  member: string;
  amount: number;
}

export interface GroupSettlementInput {
  from: string;
  to: string;
  amount: number;
  currency: string;
  isConfirmed: boolean;
}

export interface GroupSource {
  expenses: GroupExpenseInput[];
  shares: GroupShareInput[];
  settlements: GroupSettlementInput[];
  /** «Menos pagos entre ustedes» (`simplify_debts`). */
  simplifyDebts: boolean;
  /** La divisa del grupo si tiene «una sola moneda»; `null` si no. */
  singleCurrency: string | null;
}

/** Convierte con la ÚLTIMA tasa conocida (`convertWithLatestRate` de la app). */
export type LatestConverter = (amount: number, from: string, to: string) => number;

export interface MemberBalance {
  member: string;
  currency: string;
  totalPaid: number;
  totalOwes: number;
  net: number;
}

export type HeaderState = "theyOweMe" | "iOwe" | "mixed" | "settled";

export interface HeaderBalance {
  state: HeaderState;
  owedToMe: Record<string, number>;
  iOwe: Record<string, number>;
}

export interface GlobalSummary {
  owedToMe: Record<string, number>;
  iOwe: Record<string, number>;
  pendingSettlements: number;
}

/** `(x * 100).rounded() / 100` de Swift: mitades lejos de cero. */
export function round2(value: number): number {
  const scaled = value * 100;
  const r = Math.sign(scaled) * Math.round(Math.abs(scaled));
  const out = r / 100;
  return out === 0 ? 0 : out; // sin «-0»
}

function activeExpenses(expenses: GroupExpenseInput[]): GroupExpenseInput[] {
  // Como la app: un id repetido cuenta una vez, y lo saldado no entra.
  const seen = new Set<string>();
  const out: GroupExpenseInput[] = [];
  for (const e of expenses) {
    if (seen.has(e.id)) continue;
    seen.add(e.id);
    if (!e.isSettled) out.push(e);
  }
  return out;
}

function sharesByExpense(shares: GroupShareInput[]): Map<string, GroupShareInput[]> {
  const map = new Map<string, GroupShareInput[]>();
  for (const s of shares) {
    const list = map.get(s.expenseId);
    if (list) list.push(s);
    else map.set(s.expenseId, [s]);
  }
  return map;
}

/** Lo que pagó y lo que le toca a cada miembro, por divisa (`calculateBalances`). */
export function calculateBalances(
  expenses: GroupExpenseInput[],
  shares: GroupShareInput[],
  settlements: GroupSettlementInput[],
): MemberBalance[] {
  const byExpense = sharesByExpense(shares);
  const paid = new Map<string, number>();
  const owes = new Map<string, number>();
  const key = (m: string, c: string) => `${m}\u0000${c}`;
  const add = (map: Map<string, number>, k: string, v: number) => map.set(k, (map.get(k) ?? 0) + v);

  for (const e of activeExpenses(expenses)) {
    add(paid, key(e.paidBy, e.currency), e.amount);
    for (const s of byExpense.get(e.id) ?? []) add(owes, key(s.member, e.currency), s.amount);
  }
  for (const s of settlements) {
    if (!s.isConfirmed) continue;
    add(paid, key(s.from, s.currency), s.amount);
    add(owes, key(s.to, s.currency), s.amount);
  }

  const keys = new Set<string>([...paid.keys(), ...owes.keys()]);
  const out: MemberBalance[] = [];
  for (const k of keys) {
    const [member = "", currency = ""] = k.split("\u0000");
    const totalPaid = round2(paid.get(k) ?? 0);
    const totalOwes = round2(owes.get(k) ?? 0);
    out.push({ member, currency, totalPaid, totalOwes, net: round2(totalPaid - totalOwes) });
  }
  return out.sort((a, b) => cmp(a.member, b.member) || cmp(a.currency, b.currency));
}

function cmp(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/** Deudas crudas: una por reparto, menos los pagos confirmados como deuda inversa (`rawDebts`). */
export function rawDebts(
  expenses: GroupExpenseInput[],
  shares: GroupShareInput[],
  settlements: GroupSettlementInput[],
): Debt[] {
  const byExpense = sharesByExpense(shares);
  const debts: Debt[] = [];
  for (const e of activeExpenses(expenses)) {
    for (const s of byExpense.get(e.id) ?? []) {
      if (s.member === e.paidBy) continue;
      if (!(s.amount > EPSILON)) continue;
      debts.push({ from: s.member, to: e.paidBy, amount: s.amount, currency: e.currency });
    }
  }
  for (const s of settlements) {
    if (!s.isConfirmed || !(s.amount > EPSILON)) continue;
    debts.push({ from: s.to, to: s.from, amount: s.amount, currency: s.currency });
  }
  return debts;
}

/** Netea el mismo par y divisa en las dos direcciones (`consolidateDebts`). */
export function consolidate(debts: Debt[]): Debt[] {
  const net = new Map<string, { a: string; b: string; currency: string; amount: number }>();
  for (const d of debts) {
    const forward = d.from <= d.to;
    const a = forward ? d.from : d.to;
    const b = forward ? d.to : d.from;
    const k = `${a}\u0000${b}\u0000${d.currency}`;
    const cur = net.get(k) ?? { a, b, currency: d.currency, amount: 0 };
    cur.amount += forward ? d.amount : -d.amount;
    net.set(k, cur);
  }
  const out: Debt[] = [];
  for (const { a, b, currency, amount } of net.values()) {
    if (!(Math.abs(amount) > EPSILON)) continue;
    if (amount > 0) out.push({ from: a, to: b, amount: round2(amount), currency });
    else out.push({ from: b, to: a, amount: round2(Math.abs(amount)), currency });
  }
  return sortDebts(out);
}

/** Flujo mínimo por divisa (`DebtSimplificationService.simplify`). */
export function simplify(debts: Debt[]): Debt[] {
  const byCurrency = new Map<string, Debt[]>();
  for (const d of debts) {
    const list = byCurrency.get(d.currency);
    if (list) list.push(d);
    else byCurrency.set(d.currency, [d]);
  }
  const out: Debt[] = [];
  for (const [currency, list] of byCurrency) out.push(...simplifyForCurrency(list, currency));
  return sortDebts(out);
}

function simplifyForCurrency(debts: Debt[], currency: string): Debt[] {
  const net = new Map<string, number>();
  for (const d of debts) {
    net.set(d.from, (net.get(d.from) ?? 0) - d.amount);
    net.set(d.to, (net.get(d.to) ?? 0) + d.amount);
  }
  for (const [k, v] of [...net]) if (!(Math.abs(v) > EPSILON)) net.delete(k);

  const out: Debt[] = [];
  for (;;) {
    let creditor: [string, number] | null = null;
    let debtor: [string, number] | null = null;
    for (const entry of [...net].sort((x, y) => cmp(x[0], y[0]))) {
      if (!creditor || entry[1] > creditor[1]) creditor = entry;
      if (!debtor || entry[1] < debtor[1]) debtor = entry;
    }
    if (!creditor || !(creditor[1] > EPSILON) || !debtor || !(debtor[1] < -EPSILON)) break;
    const transfer = Math.min(creditor[1], Math.abs(debtor[1]));
    const rounded = round2(transfer);
    if (rounded > 0) out.push({ from: debtor[0], to: creditor[0], amount: rounded, currency });
    net.set(debtor[0], (net.get(debtor[0]) ?? 0) + transfer);
    net.set(creditor[0], (net.get(creditor[0]) ?? 0) - transfer);
    if (Math.abs(net.get(debtor[0]) ?? 0) <= EPSILON) net.delete(debtor[0]);
    if (Math.abs(net.get(creditor[0]) ?? 0) <= EPSILON) net.delete(creditor[0]);
  }
  return out;
}

/**
 * Saldos por persona en la divisa del grupo (`consolidatedBalances`): con «una sola moneda», cada divisa de cada persona
 * se convierte con la última tasa y se suma. Ordenados por clave de miembro, como la app.
 */
export function consolidatedBalances(balances: MemberBalance[], target: string, convert: LatestConverter): MemberBalance[] {
  const byMember = new Map<string, MemberBalance[]>();
  for (const b of balances) byMember.set(b.member, [...(byMember.get(b.member) ?? []), b]);
  const out: MemberBalance[] = [];
  for (const [member, list] of byMember) {
    let paid = 0;
    let owes = 0;
    for (const b of list) {
      if (b.currency === target) {
        paid += b.totalPaid;
        owes += b.totalOwes;
      } else {
        paid += convert(Number.isFinite(b.totalPaid) ? b.totalPaid : 0, b.currency, target);
        owes += convert(Number.isFinite(b.totalOwes) ? b.totalOwes : 0, b.currency, target);
      }
    }
    out.push({ member, currency: target, totalPaid: round2(paid), totalOwes: round2(owes), net: round2(paid - owes) });
  }
  return out.sort((x, y) => cmp(x.member, y.member));
}

/** Los saldos por persona como los enseña Saldos: con «una sola moneda», consolidados en la divisa del grupo. */
export function shownBalances(source: GroupSource, convert: LatestConverter): MemberBalance[] {
  const balances = calculateBalances(source.expenses, source.shares, source.settlements);
  return source.singleCurrency ? consolidatedBalances(balances, source.singleCurrency, convert) : balances;
}

/** Deudas consolidadas en la divisa del grupo (`consolidatedDebts`). */
export function consolidatedDebts(debts: Debt[], target: string, convert: LatestConverter): Debt[] {
  const converted = debts.map((d) =>
    d.currency === target ? d : { ...d, amount: convert(Number.isFinite(d.amount) ? d.amount : 0, d.currency, target), currency: target },
  );
  return consolidate(converted);
}

/** Las deudas de UN grupo como las enseña la app (`shownDebts`). */
export function shownDebts(source: GroupSource, convert: LatestConverter): Debt[] {
  const raw = rawDebts(source.expenses, source.shares, source.settlements);
  const debts = source.simplifyDebts ? simplify(raw) : consolidate(raw);
  const target = source.singleCurrency;
  if (!target || !debts.some((d) => d.currency !== target)) return debts;
  return consolidatedDebts(debts, target, convert);
}

/** La banda del detalle: lo que te deben menos lo que debes, por divisa (`computeGroupHeaderBalance`). */
export function headerBalance(debts: Debt[], me: string): HeaderBalance {
  const net = new Map<string, number>();
  for (const d of debts) {
    if (d.to === me) net.set(d.currency, (net.get(d.currency) ?? 0) + d.amount);
    if (d.from === me) net.set(d.currency, (net.get(d.currency) ?? 0) - d.amount);
  }
  const owedToMe: Record<string, number> = {};
  const iOwe: Record<string, number> = {};
  for (const [currency, raw] of net) {
    const v = round2(raw);
    if (v > EPSILON) owedToMe[currency] = v;
    else if (v < -EPSILON) iOwe[currency] = -v;
  }
  const hasOwed = Object.keys(owedToMe).length > 0;
  const hasOwe = Object.keys(iOwe).length > 0;
  const state: HeaderState = hasOwed && hasOwe ? "mixed" : hasOwed ? "theyOweMe" : hasOwe ? "iOwe" : "settled";
  return { state, owedToMe, iOwe };
}

/** El resumen de la lista: cada grupo aparte y con sus opciones (`globalSummary`). */
export function globalSummary(groups: { source: GroupSource; me: Set<string> }[], convert: LatestConverter): GlobalSummary {
  const owedToMe: Record<string, number> = {};
  const iOwe: Record<string, number> = {};
  let pending = 0;
  for (const { source, me } of groups) {
    for (const d of shownDebts(source, convert)) {
      if (me.has(d.to)) owedToMe[d.currency] = (owedToMe[d.currency] ?? 0) + d.amount;
      if (me.has(d.from)) iOwe[d.currency] = (iOwe[d.currency] ?? 0) + d.amount;
    }
    pending += source.settlements.filter((s) => !s.isConfirmed).length;
  }
  for (const [k, v] of Object.entries(owedToMe)) owedToMe[k] = round2(v);
  for (const [k, v] of Object.entries(iOwe)) iOwe[k] = round2(v);
  return { owedToMe, iOwe, pendingSettlements: pending };
}

export function sortDebts(debts: Debt[]): Debt[] {
  return [...debts].sort((a, b) => cmp(a.currency, b.currency) || cmp(a.from, b.from) || cmp(a.to, b.to));
}
