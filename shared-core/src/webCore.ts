/**
 * Las lecturas de Yala web que no son herramientas del conector (lote 2): Estadísticas y Pagos planificados. Usan los
 * mismos cargadores que `toolCore.ts` (zona, divisa preferida, tasas, ajuste de grupos) y los cálculos de
 * `logic/stats.ts` y `logic/schedule.ts`, con paridad contra la app en `mcp/test/golden.test.ts`.
 *
 * No entran en `TOOL_CORES` a propósito: el conector de Claude no las ofrece y su contrato byte a byte
 * (`mcp/test/golden/shared-core-parity.json`) no cambia.
 */
import { COLUMNS, NOT_DELETED } from "./data";
import { addDays, dayInZone, InvalidInputError } from "./logic/dates";
import { monthlyTrend, statsReadFrom, statsSummary, distribution, statsPeriods, type StatsPeriodKind } from "./logic/stats";
import { upcomingPayments, type ScheduleRow } from "./logic/schedule";
import {
  firstWeekday,
  loadGroupAdjustment,
  loadLookup,
  loadPrefs,
  loadRates,
  loadTxInRange,
  resolvePreferredCurrency,
  todayUtcKey,
  zoneOf,
  type ToolContext,
} from "./toolCore";

/** Meses de la pestaña Tendencias. */
export const TREND_MONTHS = 6;
/** Días de «Próximos cobros». */
export const UPCOMING_DAYS = 30;

const KINDS: StatsPeriodKind[] = ["mes_actual", "mes_pasado", "anio_actual"];

export function asStatsKind(raw: unknown): StatsPeriodKind {
  if (raw === undefined || raw === null || raw === "") return "mes_actual";
  if (typeof raw === "string" && (KINDS as string[]).includes(raw)) return raw as StatsPeriodKind;
  throw new InvalidInputError("periodo no válido");
}

/** Resumen, Distribución y Tendencias de un período, con UNA lectura de movimientos. */
export async function estadisticas(ctx: ToolContext, args: Record<string, unknown>) {
  const kind = asStatsKind(args.periodo);
  const prefsP = loadPrefs(ctx);
  prefsP.catch(() => undefined);
  const zone = await zoneOf(ctx, {}, prefsP);
  const tz = zone.tz;
  const today = dayInZone(ctx.now, tz);
  const prefs = await prefsP;
  const from = statsReadFrom(kind, today, TREND_MONTHS);
  const lastKey = addDays(today, 2) > todayUtcKey(ctx) ? addDays(today, 2) : todayUtcKey(ctx);
  const [lookup, rates, txs] = await Promise.all([loadLookup(ctx), loadRates(ctx, addDays(from, -2), lastKey), loadTxInRange(ctx, from, today, tz)]);
  const groups = await loadGroupAdjustment(ctx, txs.rows, lookup, rates);
  const preferred = resolvePreferredCurrency(prefs, txs.rows.map((t) => t.preferred_currency_code));
  const sctx = { today, tz, preferredCurrency: preferred.code, rates, groups };
  const { actual } = statsPeriods(kind, today);
  return {
    periodo: kind,
    zona_horaria: tz,
    resumen: statsSummary(txs.rows, lookup, kind, sctx),
    distribucion: distribution(txs.rows, lookup, actual, sctx),
    tendencias: monthlyTrend(txs.rows, lookup, TREND_MONTHS, sctx),
    incompleto: txs.truncated,
  };
}

/** Próximos cobros (30 días) y suscripciones activas. */
export async function pagos(ctx: ToolContext) {
  const prefsP = loadPrefs(ctx);
  prefsP.catch(() => undefined);
  const zone = await zoneOf(ctx, {}, prefsP);
  const tz = zone.tz;
  const today = dayInZone(ctx.now, tz);
  const todayUtc = todayUtcKey(ctx);
  const [payments, lookup, rates, prefs] = await Promise.all([
    ctx.reader.all<ScheduleRow>("scheduled_payments", [["select", COLUMNS.scheduledCalendar], NOT_DELETED, ["order", "sync_id.asc"]]),
    loadLookup(ctx),
    loadRates(ctx, todayUtc),
    prefsP,
  ]);
  const preferred = resolvePreferredCurrency(prefs, payments.rows.map((p) => p.currency_code));
  return {
    zona_horaria: tz,
    ...upcomingPayments(payments.rows, lookup, {
      today,
      todayUtc,
      tz,
      preferredCurrency: preferred.code,
      rates,
      days: UPCOMING_DAYS,
      firstWeekday: firstWeekday(prefs, {}),
    }),
    incompleto: payments.truncated,
  };
}
