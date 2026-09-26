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
 * - Importe en divisa preferida: el `amount_in_preferred_currency` guardado si el movimiento se guardó en la misma
 *   preferida; si no, se reconvierte desde el nativo (aquí con la tasa más reciente → marcado aproximado).
 *
 * Lo que la v0 NO porta, y lo declara en `avisos`: `GroupBridgeStatsAdjustment` (un gasto de grupo pagado por ti
 * cuenta entero, no «tu parte») y la tasa del día de cada movimiento.
 */
import { categoryOf, type Lookup } from "./lookup";
import { convert, type RateTable } from "./fx";
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
  aproximado: boolean;
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

/** Importe con signo en la divisa preferida, y si hubo que reconvertir. `null` si no hay forma de convertir. */
export function preferredAmount(
  tx: TxRow,
  preferredCurrency: string,
  rates: RateTable | null,
): { value: number; approximate: boolean } | null {
  const stored = num(tx.amount_in_preferred_currency);
  if (tx.preferred_currency_code?.toUpperCase() === preferredCurrency.toUpperCase() && stored !== null) {
    return { value: stored, approximate: tx.is_exchange_rate_provisional === true };
  }
  const native = num(tx.amount);
  if (native === null) return null;
  // Un null del wire vale el default del modelo (`TransactionItem.currencyCode = "USD"`).
  const from = (tx.currency_code ?? "USD").toUpperCase();
  if (from === preferredCurrency.toUpperCase()) return { value: native, approximate: false };
  const converted = convert(Math.abs(native), from, preferredCurrency, rates);
  if (converted === null) return null;
  return { value: native < 0 ? -converted : converted, approximate: true };
}

export function summarize(
  txs: TxRow[],
  lookup: Lookup,
  period: Period,
  ctx: { today: string; tz: string; preferredCurrency: string; rates: RateTable | null; top: number },
): SummaryResult {
  let income = 0;
  let expense = 0;
  let count = 0;
  let approximate = false;
  let groupTx = 0;
  let unconvertible = 0;
  // Por identidad de categoría, no por nombre: dos categorías que se llamen igual son dos filas en la app.
  const byCategory = new Map<string, { nombre: string; importe: number; movimientos: number }>();
  const byMerchant = new Map<string, { importe: number; movimientos: number }>();
  let uncategorizedCount = 0;
  let uncategorizedAbs = 0;

  for (const tx of txs) {
    const day = eligibleForStats(tx, lookup, ctx.today, ctx.tz);
    if (!day || day < period.desde || day > period.hasta) continue;

    const category = categoryOf(lookup, tx);
    if (!category) {
      if (!tx.transfer_pair_id) {
        uncategorizedCount += 1;
        uncategorizedAbs += Math.abs(num(tx.amount) ?? 0);
      }
      continue;
    }
    const conv = preferredAmount(tx, ctx.preferredCurrency, ctx.rates);
    if (!conv) {
      unconvertible += 1;
      continue;
    }
    if (tx.split_expense_id) groupTx += 1;
    approximate ||= conv.approximate;
    count += 1;

    if (category.is_income === true) {
      income += conv.value;
    } else {
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

  const avisos: string[] = [];
  if (groupTx > 0) {
    avisos.push(
      `${groupTx} movimiento(s) son gastos de grupo y cuentan por su importe entero, no por tu parte. La app los ajusta; esta versión todavía no.`,
    );
  }
  if (unconvertible > 0) {
    avisos.push(`${unconvertible} movimiento(s) en otra divisa no se pudieron convertir por falta de tasa y no están sumados.`);
  }
  if (approximate) avisos.push("Hay importes convertidos con la tasa más reciente o marcados como provisionales: las cifras son aproximadas.");
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
    avisos,
  };
}
