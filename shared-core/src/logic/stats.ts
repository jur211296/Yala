/**
 * Estadísticas de la app para Yala web (lote 2): Resumen, Distribución y Tendencias, con las reglas de las pantallas del
 * iPhone. Cada cifra se prueba contra el código de producción de la app en `mcp/test/golden.test.ts` (bloque
 * `estadisticas` del golden que escribe `YalaTests/MCP/MCPAppParityGoldenTests.swift`).
 *
 * - Resumen = `InsightsCalculator.calculate` (Yala/App/Logic/Calculators/InsightsCalculator.swift):
 *   - ingresos, gastos y neto: `CashFlowCalculator`, el mismo que porta `summarize` (summary.ts);
 *   - variación: `PreviousPeriodHelper.calculateVariation`, `(actual − anterior) / |anterior| × 100`, sin variación si
 *     el anterior es 0. El período anterior se ALINEA como `DateAlignmentHelper.alignedPreviousInterval`: el mes en
 *     curso contra los mismos días del mes anterior (acotado a su largo) y el año en curso contra el mismo tramo del
 *     año anterior; el mes pasado, contra el mes entero anterior;
 *   - gasto medio diario: `totalExpense / max(1, DateIntervalDayCount.days(in: intervalo))`. A diferencia del chat
 *     (`summarize.gasto_medio_diario`), el día de hoy SÍ cuenta: el período en curso cierra hoy a las 23:59:59;
 *   - gasto más alto: `findHighestExpense`, el gasto (no ingreso, no ajuste) de mayor MAGNITUD en la divisa preferida.
 * - Distribución = `TopSpendingCategoriesCalculator.calculateTopSpending` con los filtros por defecto (solo gasto):
 *   importe con signo por categoría, «Sin categoría» como trozo propio (suma de magnitudes de cada lado), porcentaje
 *   sobre el valor absoluto del gasto NETO con signo (no sobre la suma de magnitudes), orden por magnitud y, a igual
 *   importe, «Sin categoría» detrás. Sin agrupar en «Otros».
 * - Tendencias › Entradas y salidas = `CashFlowCalculator` mes a mes.
 *
 * Las tres pantallas pasan antes por `FilterService.filterForTrends`, que deja fuera, además de las cuentas excluidas de
 * estadísticas, los movimientos SIN cuenta (o con una que no resuelve). El chat y el conector sí los cuentan
 * (`summarize`): por eso aquí se filtran antes (`onScreen`). Lo cazó la paridad.
 */
import { categoryOf, type Lookup } from "./lookup";
import { convertOn, utcDateKey, type RateBook } from "./fx";
import { NO_GROUP_ADJUSTMENT, type GroupAdjustment } from "./groups";
import { addDays, addMonths, daysInclusive, monthEnd, monthStart, type Day, type Period } from "./dates";
import { eligibleForStats, isIncomeOf, preferredAmount, summarize, type SummaryResult } from "./summary";
import { num, round2, type TxRow } from "./types";

/** Lo que llega a las pantallas de Estadísticas: solo movimientos con una cuenta que existe (`filterForTrends`). */
export function onScreen(txs: TxRow[], lookup: Lookup): TxRow[] {
  return txs.filter((t) => !!t.account_ref && lookup.accounts.has(t.account_ref));
}

export type StatsPeriodKind = "mes_actual" | "mes_pasado" | "anio_actual";

export interface StatsContext {
  today: Day;
  tz: string;
  preferredCurrency: string;
  rates: RateBook;
  groups?: GroupAdjustment;
}

/** El período de la pantalla y el anterior con el que se compara (alineado como el iPhone). */
export function statsPeriods(kind: StatsPeriodKind, today: Day): { actual: Period; anterior: Period } {
  switch (kind) {
    case "mes_actual": {
      const start = monthStart(today);
      const prevStart = addMonths(today, -1);
      // `.dayOfMonth`: el día equivalente del mes anterior, incluido entero, sin pasar de su último día.
      const dayOfMonth = Number(today.slice(8, 10));
      const equivalent = addDays(prevStart, dayOfMonth - 1);
      const prevEnd = monthEnd(prevStart);
      return {
        actual: { desde: start, hasta: today, etiqueta: "mes en curso" },
        anterior: { desde: prevStart, hasta: equivalent < prevEnd ? equivalent : prevEnd, etiqueta: "mismos días del mes anterior" },
      };
    }
    case "mes_pasado": {
      const start = addMonths(today, -1);
      const prevStart = addMonths(today, -2);
      return {
        actual: { desde: start, hasta: monthEnd(start), etiqueta: "mes pasado" },
        anterior: { desde: prevStart, hasta: monthEnd(prevStart), etiqueta: "mes anterior" },
      };
    }
    case "anio_actual": {
      const year = Number(today.slice(0, 4));
      const prevYear = String(year - 1).padStart(4, "0");
      // `sameIntervalPreviousYear`: el mismo tramo un año antes. El 29 de febrero cae en el 28 (Calendar suma -1 año).
      let prevToday = `${prevYear}${today.slice(4)}`;
      if (today.slice(5) === "02-29") prevToday = `${prevYear}-02-28`;
      return {
        actual: { desde: `${today.slice(0, 4)}-01-01`, hasta: today, etiqueta: "año en curso" },
        anterior: { desde: `${prevYear}-01-01`, hasta: prevToday, etiqueta: "mismo tramo del año anterior" },
      };
    }
  }
}

/** `PreviousPeriodHelper.calculateVariation`. */
export function variationPct(actual: number, previous: number): number | null {
  if (previous === 0) return null;
  return round2(((actual - previous) / Math.abs(previous)) * 100);
}

function cashFlow(txs: TxRow[], lookup: Lookup, period: Period, ctx: StatsContext): SummaryResult {
  return summarize(onScreen(txs, lookup), lookup, period, { ...ctx, top: 5, groups: ctx.groups ?? NO_GROUP_ADJUSTMENT });
}

// ─── Distribución ───────────────────────────────────────────────────────────────────────────────────────────────

export interface DistributionEntry {
  /** `null` = «Sin categoría». */
  id: string | null;
  categoria: string | null;
  importe: number;
  porcentaje: number;
  movimientos: number;
}

export interface DistributionResult {
  divisa: string;
  /** Valor absoluto del gasto neto (el denominador de los porcentajes). */
  total: number;
  categorias: DistributionEntry[];
  sin_convertir: number;
}

export function distribution(txs: TxRow[], lookup: Lookup, period: Period, ctx: StatsContext): DistributionResult {
  const groups = ctx.groups ?? NO_GROUP_ADJUSTMENT;
  const byCategory = new Map<string, { nombre: string; signed: number; movimientos: number }>();
  // La app separa «Sin categoría» por lado; con el filtro por defecto (solo gasto) el de ingresos queda en 0.
  const uncategorizedIncome = 0;
  let uncategorizedExpense = 0;
  let uncategorizedCount = 0;
  let unconvertible = 0;

  for (const tx of onScreen(txs, lookup)) {
    const day = eligibleForStats(tx, lookup, ctx.today, ctx.tz);
    if (!day || day < period.desde || day > period.hasta) continue;
    if (groups.isSuppressed(tx)) continue;
    const category = categoryOf(lookup, tx);
    if (isIncomeOf(category, tx)) continue; // por defecto, solo gasto
    const conv = preferredAmount(tx, ctx.preferredCurrency, ctx.rates, groups);
    if (!conv) {
      unconvertible += 1;
      continue;
    }
    if (!category) {
      // Un gasto sin categoría tiene el signo negativo (si no, sería ingreso): cae siempre en el lado de gasto.
      uncategorizedExpense += conv.value;
      uncategorizedCount += 1;
      continue;
    }
    const c = byCategory.get(category.sync_id) ?? { nombre: category.name ?? "(sin nombre)", signed: 0, movimientos: 0 };
    c.signed += conv.value;
    c.movimientos += 1;
    byCategory.set(category.sync_id, c);
  }

  const entries: { id: string | null; nombre: string | null; signed: number; magnitude: number; movimientos: number }[] = [
    ...[...byCategory.entries()].map(([id, v]) => ({ id, nombre: v.nombre, signed: v.signed, magnitude: Math.abs(v.signed), movimientos: v.movimientos })),
  ];
  if (uncategorizedIncome !== 0 || uncategorizedExpense !== 0) {
    entries.push({
      id: null,
      nombre: null,
      signed: uncategorizedIncome + uncategorizedExpense,
      magnitude: Math.abs(uncategorizedIncome) + Math.abs(uncategorizedExpense),
      movimientos: uncategorizedCount,
    });
  }
  const total = Math.abs(entries.reduce((s, e) => s + e.signed, 0));
  entries.sort((a, b) => {
    if (a.magnitude !== b.magnitude) return b.magnitude - a.magnitude;
    if (a.id === null && b.id !== null) return 1;
    if (a.id !== null && b.id === null) return -1;
    // Orden estable entre empates: por nombre, para que la web no baile entre cargas (la app usa el de su diccionario).
    return (a.nombre ?? "").localeCompare(b.nombre ?? "", "es");
  });

  return {
    divisa: ctx.preferredCurrency,
    total: round2(total),
    categorias: entries.map((e) => ({
      id: e.id,
      categoria: e.nombre,
      importe: round2(e.magnitude),
      porcentaje: total > 0 ? round2((e.magnitude / total) * 100) : 0,
      movimientos: e.movimientos,
    })),
    sin_convertir: unconvertible,
  };
}

// ─── Resumen ────────────────────────────────────────────────────────────────────────────────────────────────────

export interface HighestExpense {
  importe: number;
  nota: string | null;
  categoria: string | null;
  dia: Day;
}

/**
 * `findHighestExpense`: el gasto de mayor magnitud en la divisa preferida. Con la divisa del movimiento igual a la
 * preferida, el nativo («tu parte» en los gastos de grupo); si no, el guardado cuando el movimiento se guardó en la
 * misma preferida (y no es un 0 sin convertir), y si no, convertido con la tasa de su día. Empate: gana el primero.
 */
export function highestExpense(txs: TxRow[], lookup: Lookup, period: Period, ctx: StatsContext): HighestExpense | null {
  const groups = ctx.groups ?? NO_GROUP_ADJUSTMENT;
  const pref = ctx.preferredCurrency.toUpperCase();
  let best: HighestExpense | null = null;
  for (const tx of onScreen(txs, lookup)) {
    const day = eligibleForStats(tx, lookup, ctx.today, ctx.tz);
    if (!day || day < period.desde || day > period.hasta) continue;
    if (groups.isSuppressed(tx)) continue;
    const category = categoryOf(lookup, tx);
    if (isIncomeOf(category, tx)) continue;
    let magnitude: number | null;
    const native = groups.amount(tx);
    if (native === null) continue;
    if ((tx.currency_code ?? "USD").toUpperCase() === pref) {
      magnitude = Math.abs(native);
    } else if (
      (tx.preferred_currency_code ?? "PEN").toUpperCase() === pref &&
      (groups.isAdjusted(tx) || !((num(tx.amount_in_preferred_currency) ?? 0) === 0 && (num(tx.amount) ?? 0) !== 0))
    ) {
      magnitude = Math.abs(groups.amountInPreferred(tx) ?? 0);
    } else {
      const key = (tx.date ? utcDateKey(tx.date) : null) ?? tx.local_day;
      const out = key ? convertOn(Math.abs(native), tx.currency_code ?? "USD", pref, key, ctx.rates) : null;
      magnitude = out ? Math.abs(out.value) : null;
    }
    if (magnitude === null) continue;
    if (!best || magnitude > best.importe) {
      const sub = tx.subcategory_ref ? lookup.subcategories.get(tx.subcategory_ref) : undefined;
      const label = sub?.name ?? category?.name ?? null;
      best = { importe: magnitude, nota: tx.note ?? label, categoria: label, dia: day };
    }
  }
  return best ? { ...best, importe: round2(best.importe) } : null;
}

export interface StatsSummaryResult {
  divisa: string;
  periodo: { desde: Day; hasta: Day };
  anterior: { desde: Day; hasta: Day };
  ingresos: number;
  gastos: number;
  neto: number;
  movimientos: number;
  variacion: { ingresos: number | null; gastos: number | null; neto: number | null; gasto_medio_diario: number | null };
  gasto_medio_diario: number;
  dias: number;
  top_categorias: DistributionEntry[];
  gasto_mas_alto: HighestExpense | null;
  aproximado: { ingresos: boolean; gastos: boolean; neto: boolean };
  sin_categoria: number;
}

/** Días del intervalo contando los dos extremos (`DateIntervalDayCount.days(in:)` sobre un cierre a las 23:59:59). */
export function periodDays(p: Period): number {
  return Math.max(1, daysInclusive(p.desde, p.hasta));
}

export function statsSummary(txs: TxRow[], lookup: Lookup, kind: StatsPeriodKind, ctx: StatsContext): StatsSummaryResult {
  const { actual, anterior } = statsPeriods(kind, ctx.today);
  const now = cashFlow(txs, lookup, actual, ctx);
  const prev = cashFlow(txs, lookup, anterior, ctx);
  const days = periodDays(actual);
  const prevDays = periodDays(anterior);
  // El gasto con el redondeo de la app: sin redondear antes de dividir.
  const avg = now.gastos / days;
  const prevAvg = prev.gastos / prevDays;
  return {
    divisa: ctx.preferredCurrency,
    periodo: { desde: actual.desde, hasta: actual.hasta },
    anterior: { desde: anterior.desde, hasta: anterior.hasta },
    ingresos: now.ingresos,
    gastos: now.gastos,
    neto: now.neto,
    movimientos: now.movimientos,
    variacion: {
      ingresos: variationPct(now.ingresos, prev.ingresos),
      gastos: variationPct(now.gastos, prev.gastos),
      neto: variationPct(now.neto, prev.neto),
      gasto_medio_diario: variationPct(avg, prevAvg),
    },
    gasto_medio_diario: round2(avg),
    dias: days,
    top_categorias: distribution(txs, lookup, actual, ctx).categorias.slice(0, 5),
    gasto_mas_alto: highestExpense(txs, lookup, actual, ctx),
    aproximado: now.aproximado_detalle,
    sin_categoria: now.sin_categoria.movimientos,
  };
}

// ─── Tendencias ─────────────────────────────────────────────────────────────────────────────────────────────────

export interface TrendMonth {
  mes: string;
  desde: Day;
  hasta: Day;
  ingresos: number;
  gastos: number;
  neto: number;
}

/** Entradas y salidas de los últimos `months` meses, del más antiguo al actual (este, hasta hoy). */
export function monthlyTrend(txs: TxRow[], lookup: Lookup, months: number, ctx: StatsContext): TrendMonth[] {
  const out: TrendMonth[] = [];
  for (let i = months - 1; i >= 0; i--) {
    const start = addMonths(ctx.today, -i);
    const end = i === 0 ? ctx.today : monthEnd(start);
    const s = cashFlow(txs, lookup, { desde: start, hasta: end, etiqueta: start.slice(0, 7) }, ctx);
    out.push({ mes: start.slice(0, 7), desde: start, hasta: end, ingresos: s.ingresos, gastos: s.gastos, neto: s.neto });
  }
  return out;
}

/** El primer día que necesita leer cada pestaña, para pedir los movimientos una sola vez. */
export function statsReadFrom(kind: StatsPeriodKind, today: Day, trendMonths: number): Day {
  const { anterior } = statsPeriods(kind, today);
  const trendStart = addMonths(today, -(trendMonths - 1));
  return anterior.desde < trendStart ? anterior.desde : trendStart;
}
