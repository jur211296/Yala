import type { MetricRow } from "./summarize";

/**
 * D1 del panel. Escribir = reemplazar el día entero de las métricas que se recalculan: un canario que ayer tenía dos
 * cortes y hoy, al recalcular, uno, no puede dejar el viejo vivo.
 */
const BATCH = 80;

export async function replaceDays(db: D1Database, days: string[], rows: MetricRow[], keepMetrics: string[] = ["sb"]): Promise<void> {
  const keep = keepMetrics.map(() => "?").join(", ");
  const stmts: D1PreparedStatement[] = [];
  for (const day of days) {
    stmts.push(
      keepMetrics.length > 0
        ? db.prepare(`DELETE FROM daily WHERE day = ? AND metric NOT IN (${keep}) AND metric NOT LIKE 'cohort_%'`).bind(day, ...keepMetrics)
        : db.prepare(`DELETE FROM daily WHERE day = ? AND metric NOT LIKE 'cohort_%'`).bind(day),
    );
  }
  for (const r of rows) {
    stmts.push(
      db
        .prepare("INSERT OR REPLACE INTO daily (day, metric, dim, value, devices) VALUES (?, ?, ?, ?, ?)")
        .bind(r.day, r.metric, r.dim, r.value, r.devices),
    );
  }
  for (let i = 0; i < stmts.length; i += BATCH) await db.batch(stmts.slice(i, i + BATCH));
}

export async function recordRun(db: D1Database, run: { ranAt: number; throughDay: string; days: number; ok: boolean; note: string | null }) {
  await db
    .prepare("INSERT OR REPLACE INTO runs (ran_at, through_day, days, ok, note) VALUES (?, ?, ?, ?, ?)")
    .bind(run.ranAt, run.throughDay, run.days, run.ok ? 1 : 0, run.note)
    .run();
}

export async function hasAnyDay(db: D1Database): Promise<boolean> {
  const row = await db.prepare("SELECT 1 AS x FROM daily LIMIT 1").first<{ x: number }>();
  return row != null;
}

export async function readRows(db: D1Database, from: string): Promise<MetricRow[]> {
  const { results } = await db
    .prepare("SELECT day, metric, dim, value, devices FROM daily WHERE day >= ? ORDER BY day")
    .bind(from)
    .all<MetricRow>();
  return results ?? [];
}

/** La serie larga del hero de Uso: activos por día desde el principio (una fila por día, barata). */
export async function readActiveHistory(db: D1Database): Promise<{ day: string; value: number }[]> {
  const { results } = await db
    .prepare("SELECT day, value FROM daily WHERE metric = 'active' AND dim = '' ORDER BY day")
    .all<{ day: string; value: number }>();
  return results ?? [];
}

export async function lastRun(db: D1Database): Promise<{ ran_at: number; through_day: string; ok: number; note: string | null } | null> {
  return db.prepare("SELECT ran_at, through_day, ok, note FROM runs ORDER BY ran_at DESC LIMIT 1").first();
}
