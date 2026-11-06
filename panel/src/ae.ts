/**
 * Lectura de Workers Analytics Engine por su API SQL (la de `qa/cloud/README.md` § Telemetría propia).
 *
 * El panel pide filas FINAS (por día y por instalación) y cuenta en memoria: los distintos de una semana no se pueden
 * sumar a partir de los de cada día, y la retención cruza el alta con los avisos diarios por instalación. Los `install`
 * viven solo durante el cron: nunca se guardan en D1 (ver summarize.ts).
 *
 * Analytics Engine MUESTREA: toda suma va con `_sample_interval`, nunca `count()` a secas.
 */

export type SqlRunner = (sql: string) => Promise<Record<string, unknown>[]>;

/** Tope de filas por consulta. Si una lo alcanza, el resumen se aborta: un conteo truncado sería un número falso. */
export const ROW_LIMIT = 200_000;

export function analyticsEngineRunner(accountId: string, token: string): SqlRunner {
  return async (sql) => {
    const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${accountId}/analytics_engine/sql`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
      body: `${sql} FORMAT JSON`,
    });
    if (!res.ok) throw new Error(`analytics engine ${res.status}: ${(await res.text()).slice(0, 200)}`);
    const body = (await res.json()) as { data?: Record<string, unknown>[] };
    const rows = body.data ?? [];
    if (rows.length >= ROW_LIMIT) throw new Error(`analytics engine: consulta truncada en ${ROW_LIMIT} filas`);
    return rows;
  };
}

export interface PingRow { day: string; install: string; app: string }
export interface RegisterRow { day: string; install: string; kind: string; mode: string; n: number }
export interface UseRow { day: string; install: string; fn: string }
export interface CanaryRow { day: string; install: string; name: string; n: number }
export interface GatewayCanaryRow { day: string; name: string; x: number }
export interface ServerEventRow { day: string; name: string; detail: string; n: number }
export interface AIRow {
  day: string;
  task: string;
  provider: string;
  model: string;
  ok: boolean;
  n: number;
  inputTokens: number;
  cachedTokens: number;
  outputTokens: number;
}

export interface RawData {
  pings: PingRow[];
  registers: RegisterRow[];
  uses: UseRow[];
  canaries: CanaryRow[];
  gatewayCanaries: GatewayCanaryRow[];
  serverEvents: ServerEventRow[];
  ai: AIRow[];
}

const DAY = "formatDateTime(timestamp, '%Y-%m-%d') AS day";
const str = (v: unknown) => (typeof v === "string" ? v : v == null ? "" : String(v));
const num = (v: unknown) => {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : 0;
};

/** Desde `from` (día UTC, incluido) hasta `toExclusive` (día UTC, excluido). */
export async function fetchRawData(
  run: SqlRunner,
  datasets: { metrics: string; aiUsage: string },
  from: string,
  toExclusive: string,
): Promise<RawData> {
  const m = datasets.metrics;
  const span = `timestamp >= toDateTime('${from} 00:00:00') AND timestamp < toDateTime('${toExclusive} 00:00:00')`;
  const L = `LIMIT ${ROW_LIMIT}`;
  const [pings, registers, uses, canaries, gatewayCanaries, serverEvents, ai] = await Promise.all([
    run(`SELECT ${DAY}, blob5 AS install, blob4 AS app FROM ${m} WHERE blob1 = 'ping' AND ${span} GROUP BY day, install, app ${L}`),
    run(`SELECT ${DAY}, blob5 AS install, blob2 AS kind, blob3 AS mode, sum(_sample_interval) AS n FROM ${m} WHERE blob1 = 'register' AND ${span} GROUP BY day, install, kind, mode ${L}`),
    run(`SELECT ${DAY}, blob5 AS install, blob2 AS fn FROM ${m} WHERE blob1 = 'use' AND ${span} GROUP BY day, install, fn ${L}`),
    run(`SELECT ${DAY}, blob5 AS install, blob2 AS name, sum(_sample_interval) AS n FROM ${m} WHERE blob1 = 'canary' AND blob4 != 'gateway' AND ${span} GROUP BY day, install, name ${L}`),
    run(`SELECT ${DAY}, blob2 AS name, sum(_sample_interval * double1) AS x FROM ${m} WHERE blob1 = 'canary' AND blob4 = 'gateway' AND ${span} GROUP BY day, name ${L}`),
    run(`SELECT ${DAY}, blob2 AS name, blob3 AS detail, sum(_sample_interval) AS n FROM ${m} WHERE blob1 = 'server' AND ${span} GROUP BY day, name, detail ${L}`),
    run(
      `SELECT ${DAY}, blob1 AS task, blob3 AS provider, blob4 AS model, if(double1 < 400, 1, 0) AS ok, sum(_sample_interval) AS n, ` +
        `sum(_sample_interval * double2) AS inT, sum(_sample_interval * double3) AS cachedT, sum(_sample_interval * double4) AS outT ` +
        `FROM ${datasets.aiUsage} WHERE ${span} GROUP BY day, task, provider, model, ok ${L}`,
    ),
  ]);
  return {
    pings: pings.map((r) => ({ day: str(r.day), install: str(r.install), app: str(r.app) })),
    registers: registers.map((r) => ({ day: str(r.day), install: str(r.install), kind: str(r.kind), mode: str(r.mode), n: num(r.n) })),
    uses: uses.map((r) => ({ day: str(r.day), install: str(r.install), fn: str(r.fn) })),
    canaries: canaries.map((r) => ({ day: str(r.day), install: str(r.install), name: str(r.name), n: num(r.n) })),
    gatewayCanaries: gatewayCanaries.map((r) => ({ day: str(r.day), name: str(r.name), x: num(r.x) })),
    serverEvents: serverEvents.map((r) => ({ day: str(r.day), name: str(r.name), detail: str(r.detail), n: num(r.n) })),
    ai: ai.map((r) => ({
      day: str(r.day),
      task: str(r.task),
      provider: str(r.provider),
      model: str(r.model),
      ok: num(r.ok) === 1,
      n: num(r.n),
      inputTokens: num(r.inT),
      cachedTokens: num(r.cachedT),
      outputTokens: num(r.outT),
    })),
  };
}
