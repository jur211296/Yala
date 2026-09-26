/**
 * Resumen de un periodo: ingresos, gastos, neto, top de categorías y de comercios.
 *
 * Port de `CashFlowCalculator.calculateCashFlow` (Yala/App/Logic/Calculators/CashFlowCalculator.swift:65) con el
 * filtro de elegibilidad del chat (`FullFinancialContextBuilder.buildFromArrays`, líneas 109-114):
 *
 * - Fuera: ajustes de saldo, movimientos de cuentas excluidas de estadísticas o archivadas, y los futuros.
 * - Solo cuentan los movimientos CON categoría (así caen las transferencias). Ingreso o gasto lo decide
 *   `category.is_income`, no el signo.
 * - Acumulación CON SIGNO: un reembolso (gasto positivo) resta del gasto; no se usa el valor absoluto.
 * - Gastos de grupo: la pata real cuenta por «tu parte» y la de préstamo no cuenta (`GroupBridgeStatsAdjustment`,
 *   ver groups.ts).
 * - Importe en divisa preferida: el `amount_in_preferred_currency` guardado (ajustado) si el movimiento se guardó en
 *   la misma preferida; si no, se reconvierte desde el nativo ajustado con la tasa DEL DÍA del movimiento.
 * - «≈» por lado y en el neto, con el umbral de la app (`ApproximateMarkThreshold`, ver approx.ts).
 */
import { categoryOf, type Lookup } from "./lookup";
import { convertOn, utcDateKey, type RateBook } from "./fx";
import { marksApproximate } from "./approx";
import { NO_GROUP_ADJUSTMENT, type GroupAdjustment } from "./groups";
import { canonicalMerchant } from "./merchant";
import { daysInclusive, minDay, txDay, type Period } from "./dates";
import { num, round2, type TxRow } from "./types";

export interface SummaryResult {
  periodo: { desde: string; hasta: string; descripcion: string; zona_horaria: string };
  divisa: string;
  ingresos: number;
  gastos: number;
  neto: number;
  tasa_de_ahorro_pct: number | null;
  gasto_medio_diario: number;
  movimientos: number;
  top_categorias_gasto: { categoria: string; importe: number; movimientos: number }[];
  top_comercios_gasto: { comercio: string; importe: number; movimientos: number }[];
  sin_categoria: { movimientos: number; importe_absoluto: number };
  /** true si alguna de las tres cifras lleva «≈» en la app. */
  aproximado: boolean;
  aproximado_detalle: { ingresos: boolean; gastos: boolean; neto: boolean };
  avisos: string[];
}

export function eligibleForStats(tx: TxRow, lookup: Lookup, today: string, tz: string): string | null {
  if (tx.balance_adjustment_type) return null;
  if (tx.account_ref) {
    const acc = lookup.accounts.get(tx.account_ref);
    if (acc?.exclude_from_statistics === true || acc?.is_archived === true) return null;
  }
  const day = txDay(tx, tz);
  if (!day || day > today) return null;
  if (num(tx.amount) === null) return null;
  return day;
}

/**
 * Importe con signo en la divisa preferida, como lo cuenta `CashFlowCalculator`, y cuánta magnitud dudosa hay detrás
 * (el numerador del «≈»). `null` si la divisa no se puede convertir.
 */
export function preferredAmount(
  tx: TxRow,
  preferredCurrency: string,
  rates: RateBook,
  groups: GroupAdjustment = NO_GROUP_ADJUSTMENT,
): { value: number; approximate: number } | null {
  // Un null del wire vale el default del modelo: `preferredCurrencyCode = "PEN"`, `amountInPreferredCurrency = 0`.
  if ((tx.preferred_currency_code ?? "PEN").toUpperCase() === preferredCurrency.toUpperCase()) {
    const stored = groups.amountInPreferred(tx) ?? 0;
    return { value: stored, approximate: groups.approximateMagnitude(tx, Math.abs(stored)) };
  }
  const native = groups.amount(tx);
  if (native === null) return null;
  // Un null del wire vale el default del modelo (`TransactionItem.currencyCode = "USD"`).
  const from = tx.currency_code ?? "USD";
  const key = (tx.date ? utcDateKey(tx.date) : null) ?? tx.local_day;
  if (!key) return null;
  const out = convertOn(Math.abs(native), from, preferredCurrency, key, rates);
  if (!out) return null;
  const magnitude = Math.abs(out.value);
  return { value: native < 0 ? -magnitude : magnitude, approximate: out.quality === "exact" ? 0 : magnitude };
}

/**
 * Magnitud en divisa preferida como la cuenta el chat para lo que no tiene categoría: port de
 * `FullFinancialContextBuilder.convertAmount` + `TransactionItem.chatAmount`. Si el ajuste de grupos cambió el
 * importe, «tu parte»; si no, el nativo cuando ya está en la divisa preferida, luego el guardado, y si no, convertido
 * con la tasa de su día.
 */
function chatMagnitude(tx: TxRow, preferredCurrency: string, rates: RateBook, groups: GroupAdjustment): number | null {
  if (groups.isAdjusted(tx)) return Math.abs(groups.amountInPreferred(tx) ?? 0);
  const pref = preferredCurrency.toUpperCase();
  const native = num(tx.amount) ?? 0;
  if ((tx.currency_code ?? "USD").toUpperCase() === pref) return Math.abs(native);
  if ((tx.preferred_currency_code ?? "PEN").toUpperCase() === pref) return Math.abs(num(tx.amount_in_preferred_currency) ?? 0);
  const key = (tx.date ? utcDateKey(tx.date) : null) ?? tx.local_day;
  if (!key) return null;
  const out = convertOn(Math.abs(native), tx.currency_code ?? "USD", preferredCurrency, key, rates);
  return out ? Math.abs(out.value) : null;
}

export function summarize(
  txs: TxRow[],
  lookup: Lookup,
  period: Period,
  ctx: { today: string; tz: string; preferredCurrency: string; rates: RateBook; top: number; groups?: GroupAdjustment },
): SummaryResult {
  const groups = ctx.groups ?? NO_GROUP_ADJUSTMENT;
  let income = 0;
  let expense = 0;
  let count = 0;
  // Numerador y denominador del «≈», en magnitudes y por lado, como `CashFlowCalculator`.
  let incomeApprox = 0;
  let incomeTotal = 0;
  let expenseApprox = 0;
  let expenseTotal = 0;
  let unconvertible = 0;
  // Por identidad de categoría, no por nombre: dos categorías que se llamen igual son dos filas en la app.
  const byCategory = new Map<string, { nombre: string; importe: number; movimientos: number }>();
  const byMerchant = new Map<string, { importe: number; movimientos: number }>();
  let uncategorizedCount = 0;
  let uncategorizedAbs = 0;

  for (const tx of txs) {
    const day = eligibleForStats(tx, lookup, ctx.today, ctx.tz);
    if (!day || day < period.desde || day > period.hasta) continue;

    // La pata de préstamo de un gasto de grupo no es ingreso ni gasto tuyo, ni «sin categoría» aunque su categoría
    // no resuelva (`buildUncategorized` la excluye igual).
    if (groups.isSuppressed(tx)) continue;
    const category = categoryOf(lookup, tx);
    if (!category) {
      if (!tx.transfer_pair_id) {
        uncategorizedCount += 1;
        uncategorizedAbs += chatMagnitude(tx, ctx.preferredCurrency, ctx.rates, groups) ?? 0;
      }
      continue;
    }
    const conv = preferredAmount(tx, ctx.preferredCurrency, ctx.rates, groups);
    if (!conv) {
      unconvertible += 1;
      continue;
    }
    count += 1;

    if (category.is_income === true) {
      income += conv.value;
      incomeTotal += Math.abs(conv.value);
      incomeApprox += conv.approximate;
    } else {
      expenseTotal += Math.abs(conv.value);
      expenseApprox += conv.approximate;
      expense -= conv.value;
      const c = byCategory.get(category.sync_id) ?? { nombre: category.name ?? "(sin nombre)", importe: 0, movimientos: 0 };
      c.importe -= conv.value;
      c.movimientos += 1;
      byCategory.set(category.sync_id, c);
      const merchant = canonicalMerchant(tx.note);
      if (merchant) {
        const m = byMerchant.get(merchant) ?? { importe: 0, movimientos: 0 };
        m.importe -= conv.value;
        m.movimientos += 1;
        byMerchant.set(merchant, m);
      }
    }
  }

  // Denominador del gasto medio: como `DateIntervalDayCount.days(from: start, to: min(end, now))`
  // (FullFinancialContextBuilder.swift:398). En un periodo que llega a hoy, el día en curso NO cuenta (trunca);
  // en uno cerrado cuentan todos.
  const inProgress = period.hasta >= ctx.today;
  const effectiveEnd = minDay(period.hasta, ctx.today);
  const days =
    effectiveEnd < period.desde ? 1 : Math.max(1, daysInclusive(period.desde, effectiveEnd) - (inProgress ? 1 : 0));
  // Orden por magnitud, como `TopSpendingCategoriesCalculator`: una categoría con más reembolsos que gastos
  // (neto negativo) también es de las que más mueven.
  const top = <K extends string>(entries: [string, { importe: number; movimientos: number }][], key: K) =>
    entries
      .sort((a, b) => Math.abs(b[1].importe) - Math.abs(a[1].importe))
      .slice(0, ctx.top)
      .map(([name, v]) => ({ [key]: name, importe: round2(v.importe), movimientos: v.movimientos }) as Record<K, string> & {
        importe: number;
        movimientos: number;
      });

  const flags = {
    ingresos: marksApproximate(incomeApprox, incomeTotal),
    gastos: marksApproximate(expenseApprox, expenseTotal),
    neto: marksApproximate(incomeApprox + expenseApprox, income - expense),
  };
  const approximate = flags.ingresos || flags.gastos || flags.neto;
  const avisos: string[] = [];
  if (unconvertible > 0) {
    avisos.push(`${unconvertible} movimiento(s) en una divisa que la app no reconoce no están sumados.`);
  }
  if (approximate) {
    avisos.push("Parte de estas cifras se convirtió sin la cotización exacta de su día: son aproximadas, y la app las marca igual, con «≈».");
  }
  if (uncategorizedCount > 0) {
    avisos.push(`${uncategorizedCount} movimiento(s) no tienen categoría y no cuentan ni como ingreso ni como gasto.`);
  }

  return {
    periodo: { desde: period.desde, hasta: period.hasta, descripcion: period.etiqueta, zona_horaria: ctx.tz },
    divisa: ctx.preferredCurrency,
    ingresos: round2(income),
    gastos: round2(expense),
    neto: round2(income - expense),
    tasa_de_ahorro_pct: income > 0 ? round2(((income - expense) / income) * 100) : null,
    gasto_medio_diario: round2(expense / days),
    movimientos: count,
    top_categorias_gasto: top(
      [...byCategory.values()].map((v) => [v.nombre, v] as [string, { importe: number; movimientos: number }]),
      "categoria",
    ),
    top_comercios_gasto: top([...byMerchant.entries()], "comercio"),
    sin_categoria: { movimientos: uncategorizedCount, importe_absoluto: round2(uncategorizedAbs) },
    aproximado: approximate,
    aproximado_detalle: flags,
    avisos,
  };
}
