import { addDays, dayOf, dayRange } from "./days";
import { type SqlRunner, analyticsEngineRunner, fetchRawData } from "./ae";
import type { Env } from "./env";
import { recordRun, hasAnyDay, replaceDays } from "./store";
import { summarize, supabaseRows } from "./summarize";
import { fetchStatsCounts } from "./supabase";

/** Días que se recalculan cada noche: los avisos que esperaban en la cola de un teléfono sin red llegan tarde. */
export const RECOMPUTE_DAYS = 3;
/** Primer arranque con la D1 vacía: se rellena lo que Analytics Engine aún guarda (90 días, con margen). */
export const BACKFILL_DAYS = 85;

export interface CronDeps {
  now: Date;
  runSql?: SqlRunner;
  fetchCounts?: () => Promise<Record<string, unknown>>;
}

/**
 * El cron diario. Resume hasta AYER (UTC): el día de hoy aún no terminó. Recalcula los últimos días por los avisos que
 * llegan tarde y, con la D1 vacía, rellena hacia atrás. Los conteos de la base son una foto del momento de la corrida y
 * se guardan con el último día resumido; si fallan, el resto se guarda igual y la corrida lo apunta.
 */
export async function runDaily(env: Env, deps: CronDeps): Promise<{ throughDay: string; days: number; note: string | null }> {
  const lastComplete = addDays(dayOf(deps.now), -1);
  const backfill = !(await hasAnyDay(env.PANEL_DB));
  const n = backfill ? BACKFILL_DAYS : RECOMPUTE_DAYS;
  const days = dayRange(addDays(lastComplete, -(n - 1)), lastComplete);
  const ranAt = deps.now.getTime();
  try {
    const run = deps.runSql ?? sqlRunnerFor(env);
    // 30 días de ventana + 36 de cohorte por detrás del primer día que se recalcula.
    const raw = await fetchRawData(
      run,
      { metrics: env.METRICS_DATASET, aiUsage: env.AI_USAGE_DATASET },
      addDays(days[0], -37),
      addDays(lastComplete, 1),
    );
    const rows = summarize(raw, days, lastComplete);

    let note: string | null = null;
    try {
      const counts = deps.fetchCounts ? await deps.fetchCounts() : await countsFor(env);
      if (counts) rows.push(...supabaseRows(lastComplete, counts));
      else note = "sin conteos de la base: falta STATS_ROLE_JWT";
    } catch (e) {
      note = `sin conteos de la base: ${String(e).slice(0, 160)}`;
    }

    await replaceDays(env.PANEL_DB, days, rows);
    await recordRun(env.PANEL_DB, { ranAt, throughDay: lastComplete, days: days.length, ok: true, note });
    return { throughDay: lastComplete, days: days.length, note };
  } catch (e) {
    const note = String(e).slice(0, 300);
    await recordRun(env.PANEL_DB, { ranAt, throughDay: lastComplete, days: days.length, ok: false, note });
    throw e;
  }
}

function sqlRunnerFor(env: Env): SqlRunner {
  if (!env.CF_ANALYTICS_TOKEN) throw new Error("falta CF_ANALYTICS_TOKEN (secret del Worker)");
  return analyticsEngineRunner(env.CF_ACCOUNT_ID, env.CF_ANALYTICS_TOKEN);
}

async function countsFor(env: Env): Promise<Record<string, unknown> | null> {
  if (!env.STATS_ROLE_JWT) return null;
  return fetchStatsCounts(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, env.STATS_ROLE_JWT);
}
