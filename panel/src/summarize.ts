import { addDays, within } from "./days";
import type { RawData } from "./ae";
import { PRICED_OUTSIDE_TOKENS, costUSD } from "./prices";

/**
 * Del dato fino de Analytics Engine al resumen diario que guarda D1. Función PURA: sin red, sin reloj.
 *
 * Lo que sale son agregados por día (`day`, `metric`, `dim`) y nada que identifique a nadie: los `install` entran aquí
 * para contar distintos y cruzar el alta con los avisos diarios, y se quedan aquí.
 *
 * Las métricas de ventana (`*7`, `*30`) se guardan con el día en que TERMINA la ventana. Se calculan aquí porque
 * «personas distintas en 7 días» no es la suma de las de cada día.
 *
 * ALTAS (`alta`, dim `local`|`cloud`): personas, no avisos. Medido el 2026-11-06 en la app: un alta con cuenta en la
 * nube manda DOS `register` (`cloud|bornCloud` y, al terminar el onboarding, `local|initial`), y `local|fullActivation`
 * (pasar de solo grupos a Yala completo) y `cloud|migration` (llevar a la nube lo que ya tenías) no son altas. Así que
 * un alta es la PRIMERA vez que una instalación aparece con un `register` que sí lo es, y es `cloud` si esa instalación
 * tiene un `cloud|bornCloud`. La serie `register` se guarda tal cual, por si hace falta el detalle.
 *
 * Cohortes de alta: cohorte C = instalaciones cuya alta cae el día C. Vuelve a los 7 días = abrió la app entre C+7
 * y C+13; a los 30 = entre C+30 y C+36. Solo se escribe una tasa cuando su ventana ya cerró (`lastComplete`).
 */
const NOT_A_SIGNUP = new Set(["local|fullActivation", "cloud|migration"]);

/** La primera alta de cada instalación dentro de lo leído, y si nació en la nube. */
export function signupsByInstall(raw: RawData): Map<string, { day: string; kind: "local" | "cloud" }> {
  const out = new Map<string, { day: string; kind: "local" | "cloud" }>();
  const bornCloud = new Set(raw.registers.filter((r) => r.kind === "cloud" && r.mode === "bornCloud").map((r) => r.install));
  for (const r of raw.registers) {
    if (NOT_A_SIGNUP.has(`${r.kind}|${r.mode}`)) continue;
    const prev = out.get(r.install);
    if (!prev || r.day < prev.day) out.set(r.install, { day: r.day, kind: bornCloud.has(r.install) ? "cloud" : "local" });
  }
  return out;
}
export interface MetricRow {
  day: string;
  metric: string;
  dim: string;
  value: number;
  devices: number | null;
}

function distinct<T>(rows: T[], key: (r: T) => string): number {
  return new Set(rows.map(key)).size;
}

function groupBy<T>(rows: T[], key: (r: T) => string): Map<string, T[]> {
  const m = new Map<string, T[]>();
  for (const r of rows) {
    const k = key(r);
    const list = m.get(k);
    if (list) list.push(r);
    else m.set(k, [r]);
  }
  return m;
}

const sum = <T>(rows: T[], v: (r: T) => number) => rows.reduce((a, r) => a + v(r), 0);

/**
 * `days`: los días a (re)calcular. `lastComplete`: el último día UTC entero (ayer). `raw` tiene que cubrir desde
 * `min(days) - 30` (ventanas) y desde `min(days) - 36` (cohortes) hasta `lastComplete`.
 */
export function summarize(raw: RawData, days: string[], lastComplete: string): MetricRow[] {
  const out: MetricRow[] = [];
  const signups = signupsByInstall(raw);
  const push = (day: string, metric: string, dim: string, value: number, devices: number | null = null) =>
    out.push({ day, metric, dim, value, devices });

  for (const D of days) {
    const from7 = addDays(D, -6);
    const from30 = addDays(D, -29);

    // --- Uso: activos (avisos diarios por instalación) ---
    const pingsDay = raw.pings.filter((r) => r.day === D);
    const pings7 = raw.pings.filter((r) => within(r.day, from7, D));
    const pings30 = raw.pings.filter((r) => within(r.day, from30, D));
    push(D, "active", "", distinct(pingsDay, (r) => r.install));
    push(D, "active7", "", distinct(pings7, (r) => r.install));
    push(D, "active30", "", distinct(pings30, (r) => r.install));

    // Versión en uso: la última versión con la que abrió cada instalación en la semana.
    const latest = new Map<string, { day: string; app: string }>();
    for (const r of pings7) {
      const prev = latest.get(r.install);
      if (!prev || r.day >= prev.day) latest.set(r.install, { day: r.day, app: r.app });
    }
    for (const [app, list] of groupBy([...latest.values()], (v) => v.app || "?")) push(D, "version7", app, list.length);

    // --- Registro: los avisos tal cual y las altas por persona ---
    for (const [dim, list] of groupBy(raw.registers.filter((r) => r.day === D), (r) => `${r.kind}|${r.mode}`)) {
      push(D, "register", dim, sum(list, (r) => r.n), distinct(list, (r) => r.install));
    }
    for (const kind of ["local", "cloud"] as const) {
      const n = [...signups.values()].filter((s) => s.day === D && s.kind === kind).length;
      if (n > 0) push(D, "alta", kind, n, n);
    }

    // --- Funciones usadas ---
    for (const [fn, list] of groupBy(raw.uses.filter((r) => r.day === D), (r) => r.fn)) {
      push(D, "use", fn, distinct(list, (r) => r.install), distinct(list, (r) => r.install));
    }
    for (const [fn, list] of groupBy(raw.uses.filter((r) => within(r.day, from7, D)), (r) => r.fn)) {
      push(D, "use7", fn, distinct(list, (r) => r.install), distinct(list, (r) => r.install));
    }

    // --- Canarios de la app: veces y aparatos, del día y de las ventanas ---
    for (const [name, list] of groupBy(raw.canaries.filter((r) => r.day === D), (r) => r.name)) {
      push(D, "canary", name, sum(list, (r) => r.n), distinct(list, (r) => r.install));
    }
    for (const [name, list] of groupBy(raw.canaries.filter((r) => within(r.day, from7, D)), (r) => r.name)) {
      push(D, "canary7", name, sum(list, (r) => r.n), distinct(list, (r) => r.install));
    }
    for (const [name, list] of groupBy(raw.canaries.filter((r) => within(r.day, from30, D)), (r) => r.name)) {
      push(D, "canary30", name, sum(list, (r) => r.n), distinct(list, (r) => r.install));
    }

    // --- Canarios y eventos del gateway (no llevan instalación) ---
    for (const [name, list] of groupBy(raw.gatewayCanaries.filter((r) => r.day === D), (r) => r.name)) {
      push(D, "gw_canary", name, sum(list, (r) => r.x));
    }
    for (const [dim, list] of groupBy(raw.serverEvents.filter((r) => r.day === D), (r) => `${r.name}|${r.detail}`)) {
      push(D, "server", dim, sum(list, (r) => r.n));
    }

    // --- IA: llamadas, tokens y costo ---
    for (const [dim, list] of groupBy(raw.ai.filter((r) => r.day === D), (r) => `${r.task}|${r.provider}|${r.model}|${r.ok ? "ok" : "err"}`)) {
      push(D, "ai_calls", dim, sum(list, (r) => r.n));
      const usage = {
        inputTokens: sum(list, (r) => r.inputTokens),
        cachedTokens: sum(list, (r) => r.cachedTokens),
        outputTokens: sum(list, (r) => r.outputTokens),
      };
      const model = list[0]?.model ?? "";
      const cost = costUSD(model, usage);
      if (cost != null) push(D, "ai_cost_usd", dim, cost);
      else if (!PRICED_OUTSIDE_TOKENS.has(model)) push(D, "ai_unpriced", dim, sum(list, (r) => r.n));
    }
  }

  // --- Cohortes: una fila por día de alta; las tasas, cuando su ventana cerró ---
  const pingDaysByInstall = groupBy(raw.pings, (r) => r.install);
  const cohortDays = new Set<string>();
  for (const D of days) {
    for (let k = 0; k <= 36; k++) cohortDays.add(addDays(D, -k));
  }
  for (const C of cohortDays) {
    const cohort = new Set([...signups.entries()].filter(([, s]) => s.day === C).map(([install]) => install));
    if (cohort.size === 0) continue;
    const back = (from: number, to: number) => {
      let n = 0;
      for (const install of cohort) {
        const seen = pingDaysByInstall.get(install) ?? [];
        if (seen.some((p) => within(p.day, addDays(C, from), addDays(C, to)))) n++;
      }
      return n;
    };
    push(C, "cohort_size", "", cohort.size, cohort.size);
    if (addDays(C, 13) <= lastComplete) push(C, "cohort_r7", "", back(7, 13), cohort.size);
    if (addDays(C, 36) <= lastComplete) push(C, "cohort_r30", "", back(30, 36), cohort.size);
  }
  return out;
}

/** Los conteos de la base (Supabase) se guardan como `sb` del día en que se tomaron. */
export function supabaseRows(day: string, counts: Record<string, unknown>): MetricRow[] {
  return Object.entries(counts)
    .filter(([, v]) => typeof v === "number" && Number.isFinite(v))
    .map(([k, v]) => ({ day, metric: "sb", dim: k, value: v as number, devices: null }));
}
