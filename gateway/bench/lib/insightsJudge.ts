/**
 * Juez de las cuatro tareas de Insights y Tendencias: lo que el criterio determinista no puede medir.
 *
 *   npx vite-node bench/lib/insightsJudgeCli.ts -- --sample 10                      # elige la muestra para puntuar a mano
 *   npx vite-node bench/lib/insightsJudgeCli.ts -- --task insights.cards --keys <f>  # juzga esas respuestas
 *   npx vite-node bench/lib/insightsJudgeCli.ts -- --task insights.cards --only openai:gpt-6-luna
 *   npx vite-node bench/lib/insightsJudgeCli.ts -- --agreement                       # acuerdo con la muestra a mano
 *   (con `--judges all` juzgan los tres, para medir el acuerdo de cada uno)
 *
 * Pregunta dos cosas y anota una tercera: ¿alguna afirmación CONTRADICE los datos (dirección, atribución, algo que
 * no está, una comparación imposible)?, ¿dice algo ÚTIL y concreto sobre estos datos? y ¿respeta la voz de la app?
 * Veredicto = no contradice y es útil. La voz se anota pero no decide.
 *
 * Reglas: el juez es OTRO modelo, de OTRO proveedor que el candidato (nadie se juzga a sí mismo): de la lista
 * `JUDGES` se toman los dos primeros cuyo proveedor no es el del candidato. Antes de dejarle decidir algo se mide su
 * acuerdo con una muestra puntuada a mano (`insights.hand-scores.json`); si el acuerdo es bajo, no decide.
 * Resultados: `bench/results/<fecha>/<tarea>.judge.jsonl` (una línea por respuesta y juez, con su coste).
 */
import { execFileSync } from "node:child_process";
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { ADAPTERS } from "../../src/ai/providers";
import type { ProviderKeys, Usage } from "../../src/ai/providers/types";
import type { ManagedRoute, ProviderId, ReasoningEffort } from "../../src/ai/routes";
import { CANDIDATES, costUSD } from "../candidates";
import { taskByName } from "../tasks";
import type { BenchCase, Variant } from "../tasks/types";
import { userDataJSON } from "./insightsRequests";

export const INSIGHTS_TASKS = ["insights.cards", "insights.cashflow", "insights.deviation", "trends.summary"] as const;

export interface Judge {
  id: string;
  provider: ProviderId;
  model: string;
  effort?: ReasoningEffort;
  temperature?: number;
}

/**
 * En este orden; cada respuesta la miran los dos primeros de otro proveedor. Sin Anthropic a propósito: la clave del
 * banco se quedó sin crédito a mitad de la criba (2026-10-07, 21:43 UTC) y los jueces tienen que ser los mismos para
 * todas las respuestas que se comparan.
 */
export const JUDGES: Judge[] = [
  { id: "gemini:gemini-3.8-flash", provider: "gemini", model: "gemini-3.8-flash", effort: "low", temperature: 0 },
  { id: "xai:grok-4.3", provider: "xai", model: "grok-4.3", temperature: 0 },
  { id: "workersai:gpt-oss-120b", provider: "workersai", model: "@cf/openai/gpt-oss-120b", effort: "low" },
];

export function judgesFor(candidateProvider: string): Judge[] {
  return JUDGES.filter((j) => j.provider !== candidateProvider).slice(0, 2);
}

const JUDGE_SCHEMA = {
  name: "insights_judge",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["contradice_datos", "util", "voz_ok", "motivo"],
    properties: {
      contradice_datos: { type: "boolean" },
      util: { type: "boolean" },
      voz_ok: { type: "boolean" },
      motivo: { type: "string" },
    },
  },
} as const;

const TASK_DESCRIPTION: Record<string, string> = {
  "insights.cards":
    "Análisis del período en la pestaña Insights: un titular (hero), de 3 a 6 tarjetas con un consejo opcional y un dato curioso opcional. " +
    "Campos: total_expense / total_income / net_balance del período; *_variation = variación contra comparison_ref (comparison_label); count = número de movimientos; " +
    "daily_avg = gasto medio diario; top_categories (pct = % del gasto); top_subcategory (pct_of_total); category_tree = categorías y subcategorías existentes (no son importes); " +
    "highest_expense = el gasto más alto; highest_avg_weekday = día con mayor gasto medio; subscriptions / recurring_payments (monthly_total); pending_payments; " +
    "need_split (esencial / prioritario / opcional); budgets_at_risk (spent, limit, usage_pct); year_ago (mismo período del año anterior); active_filters; shared_expenses (gastos compartidos en grupos).",
  "insights.cashflow":
    "Una sola oración (máximo 150 caracteres) sobre la proyección de flujo de caja: saldo inicial, meses proyectados, meses con saldo acumulado negativo, " +
    "neto mensual medio (avgMonthlyNet), el mes en curso, el último mes y el mes con el saldo acumulado más bajo.",
  "insights.deviation":
    "Una sola oración (máximo 150 caracteres) sobre las líneas del plan de gastos donde el usuario gastó más de lo previsto. " +
    "Por línea, promedios mensuales: planned = previsto, actual = real, excess = exceso; totalExcess = suma de excesos.",
  "trends.summary":
    "Una viñeta (máximo 110 caracteres) por cada gráfica presente en la pestaña Tendencias: trend = histórico de períodos COMPLETOS anteriores " +
    "(history_completed_periods), comparison = período actual contra el anterior, cashflow = ingresos contra gastos del período, weekday = gasto medio por día. " +
    "El período actual puede estar en curso: compararlo en bruto con períodos completos es un error.",
};

export const JUDGE_SYSTEM = `Eres un revisor de calidad de una app de finanzas personales. Recibes los DATOS exactos que recibió un asistente, la TAREA que se le pidió y su RESPUESTA tal como la verá el usuario. Evalúa con rigor y sin inventar:

- contradice_datos: true si ALGUNA afirmación de la respuesta es falsa o no se apoya en los datos: dirección equivocada (dice que subió y bajó), atribución equivocada (mezcla una categoría con el presupuesto o el importe de otra), un hecho que no está en los datos (comercios, fechas, días del mes, causas, conteos o nombres inventados), una comparación que los datos no permiten, o una cifra mal calculada. Redondear está bien. Un consejo o sugerencia no es una afirmación sobre los datos, salvo que dé por hecho algo falso.
- util: true si dice algo concreto y relevante sobre ESTOS datos que al usuario le sirve; false si es genérico, vacío, repetitivo o se queda en lo obvio sin aportar.
- voz_ok: false si regaña, culpa, juzga, alarma, hace preguntas o usa "Debes..." / "Tienes que...".

Responde SOLO con JSON: {"contradice_datos": true|false, "util": true|false, "voz_ok": true|false, "motivo": "una frase con lo que decide"}`;

/** El texto que ve el usuario, ordenado como en la pantalla. */
export function renderResponse(task: string, out: unknown): string {
  const o = out as Record<string, unknown>;
  if (task === "insights.cards") {
    const cards = (o.cards as { icon: string; text: string; tip: string | null }[]) ?? [];
    const lines = [`Titular: ${o.hero}`, "Tarjetas:"];
    cards.forEach((c, i) => {
      lines.push(`${i + 1}. ${c.text}`);
      if (c.tip) lines.push(`   Consejo: ${c.tip}`);
    });
    if (o.funFact) lines.push(`Dato curioso: ${o.funFact}`);
    return lines.join("\n");
  }
  if (task === "trends.summary") {
    const b = (o.bullets as { chart: unknown; text: string }[]) ?? [];
    return ["Viñetas:", ...b.map((x) => `- [${String(x.chart)}] ${x.text}`)].join("\n");
  }
  return o.comment === null ? "(sin comentario: la app enseña su texto de reglas)" : `Comentario: ${o.comment}`;
}

export function judgeUserMessage(task: string, locale: string, data: string, response: string): string {
  return `TAREA: ${TASK_DESCRIPTION[task]}\nIDIOMA DEL USUARIO: ${locale}\n\nDATOS:\n${data}\n\nRESPUESTA:\n${response}`;
}

export interface Verdict {
  contradice: boolean;
  util: boolean;
  voz: boolean;
  motivo: string;
}

export function parseVerdict(content: string): Verdict | null {
  try {
    const o = JSON.parse(content) as Record<string, unknown>;
    if (typeof o.contradice_datos !== "boolean" || typeof o.util !== "boolean") return null;
    return { contradice: o.contradice_datos, util: o.util, voz: o.voz_ok !== false, motivo: String(o.motivo ?? "") };
  } catch {
    return null;
  }
}

export const verdictPass = (v: { contradice: boolean; util: boolean }): boolean => !v.contradice && v.util;

// ---------- acuerdo ----------

/** Cohen's κ para dos listas de booleanos. */
export function cohenKappa(a: boolean[], b: boolean[]): number {
  const n = a.length;
  if (!n) return NaN;
  let agree = 0;
  let a1 = 0;
  let b1 = 0;
  for (let i = 0; i < n; i++) {
    if (a[i] === b[i]) agree++;
    if (a[i]) a1++;
    if (b[i]) b1++;
  }
  const po = agree / n;
  const pe = (a1 / n) * (b1 / n) + ((n - a1) / n) * ((n - b1) / n);
  return pe === 1 ? 1 : (po - pe) / (1 - pe);
}

/** Un juez decide si su acuerdo con la muestra a mano es alto: κ ≥ 0,6 y ≥ 85 % de coincidencia. */
export const JUDGE_MIN_KAPPA = 0.6;
export const JUDGE_MIN_AGREEMENT = 0.85;

// ---------- filas ----------

export interface ResultRow {
  task: string;
  case: string;
  candidate: string;
  provider: string;
  model: string;
  effort: string | null;
  rep: number;
  status: number;
  ms: number;
  pass: boolean;
  appParsed: boolean;
  usage: Usage | null;
  cost: number | null;
  detailOut: Record<string, unknown>;
  at: string;
}

export interface JudgeRow {
  task: string;
  case: string;
  candidate: string;
  effort: string | null;
  rep: number;
  judge: string;
  provider: string;
  status: number;
  ms: number;
  verdict: Verdict | null;
  pass: boolean | null;
  usage: Usage | null;
  cost: number | null;
  error?: string;
  at: string;
}

export const rowKey = (r: { case: string; candidate: string; effort: string | null; rep: number }): string => [r.case, r.candidate, r.effort ?? "-", r.rep].join("|");

export function resultsDir(date: string): URL {
  return new URL(`../results/${date}/`, import.meta.url);
}

/** Última línea de cada llamada (las reanudadas dejan varias). */
export function latestRows(task: string, date: string): ResultRow[] {
  const f = new URL(`${task}.jsonl`, resultsDir(date));
  if (!existsSync(f)) return [];
  const m = new Map<string, ResultRow>();
  for (const l of readFileSync(f, "utf8").split("\n").filter(Boolean)) {
    const r = JSON.parse(l) as ResultRow;
    m.set(rowKey(r), r);
  }
  return [...m.values()];
}

export function judgeRows(task: string, date: string): JudgeRow[] {
  const f = new URL(`${task}.judge.jsonl`, resultsDir(date));
  if (!existsSync(f)) return [];
  const m = new Map<string, JudgeRow>();
  for (const l of readFileSync(f, "utf8").split("\n").filter(Boolean)) {
    const r = JSON.parse(l) as JudgeRow;
    m.set(`${rowKey(r)}|${r.judge}`, r);
  }
  return [...m.values()];
}

// ---------- llamadas ----------

function readKey(name: string): string | undefined {
  const p = `${homedir()}/Secrets/yala-ai-bench/${name}.key`;
  return existsSync(p) ? readFileSync(p, "utf8").trim() : undefined;
}

/** Workers AI por el login de wrangler, como `run.ts` (su token OAuth dura una hora; `wrangler whoami` lo renueva). */
function workersAIKeys(): ProviderKeys["workersai"] {
  const cfg = `${homedir()}/Library/Preferences/.wrangler/config/default.toml`;
  if (!existsSync(cfg)) return undefined;
  let toml = readFileSync(cfg, "utf8");
  const exp = Date.parse(toml.match(/expiration_time = "([^"]+)"/)?.[1] ?? "");
  if (!(exp > Date.now() + 20 * 60_000)) {
    execFileSync("npx", ["wrangler", "whoami"], { stdio: "ignore" });
    toml = readFileSync(cfg, "utf8");
  }
  const token = toml.match(/oauth_token = "([^"]+)"/)?.[1];
  const accountId = process.env.CF_ACCOUNT_ID ?? "86c270a7776be98639700bd5959b303b";
  return token ? { accountId, token } : undefined;
}

function keys(): ProviderKeys {
  return { anthropic: readKey("anthropic"), gemini: readKey("gemini"), xai: readKey("xai"), openai: readKey("openai"), workersai: workersAIKeys() };
}

interface CaseLike extends BenchCase {
  locale?: string;
  input?: { locale?: string };
}

function caseMap(task: string): Map<string, CaseLike> {
  const t = taskByName(task);
  const file = JSON.parse(readFileSync(new URL(`../cases/${t.casesFile ?? `${task}.json`}`, import.meta.url), "utf8")) as { cases: CaseLike[] };
  return new Map(file.cases.map((c) => [c.id, c]));
}

export async function judgeOne(task: string, c: CaseLike, row: ResultRow, judge: Judge, k: ProviderKeys): Promise<JudgeRow> {
  const t = taskByName(task);
  const body = t.body(c, { candidate: CANDIDATES[0] } as Variant);
  const locale = c.locale ?? c.input?.locale ?? "?";
  const user = judgeUserMessage(task, locale, userDataJSON(body), renderResponse(task, row.detailOut.out));
  const route: ManagedRoute = {
    mode: "managed",
    provider: judge.provider,
    model: judge.model,
    params: { temperature: judge.temperature, reasoningEffort: judge.effort, responseFormat: "json_object", jsonSchema: JUDGE_SCHEMA },
    retries: 1,
  };
  const started = performance.now();
  const res = await ADAPTERS[judge.provider].send({ messages: [{ role: "system", content: JUDGE_SYSTEM }, { role: "user", content: user }] }, route, { keys: k });
  const ms = Math.round(performance.now() - started);
  let verdict: Verdict | null = null;
  if (res.status === 200) {
    const content = (JSON.parse(res.body) as { choices?: { message?: { content?: string } }[] }).choices?.[0]?.message?.content ?? "";
    verdict = parseVerdict(content);
  }
  const price = CANDIDATES.find((x) => x.id === judge.id)?.price;
  return {
    task,
    case: row.case,
    candidate: row.candidate,
    effort: row.effort,
    rep: row.rep,
    judge: judge.id,
    provider: judge.provider,
    status: res.status,
    ms,
    verdict,
    pass: verdict ? verdictPass(verdict) : null,
    usage: res.usage,
    cost: price ? costUSD(price, res.usage) : null,
    ...(res.error ? { error: res.error.slice(0, 300) } : {}),
    at: new Date().toISOString(),
  };
}

async function pool<T>(items: T[], n: number, fn: (t: T) => Promise<void>): Promise<void> {
  let i = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, items.length) }, async () => {
      while (i < items.length) await fn(items[i++]);
    }),
  );
}

// ---------- CLI ----------

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const HAND_FILE = "insights.hand-scores.json";

interface HandScores {
  scorer: string;
  rubric: string;
  items: { task: string; key: string; contradice: boolean | null; util: boolean | null; voz: boolean | null; nota: string }[];
}

/** Muestra estratificada para puntuar a mano: por tarea, `n` respuestas de candidatos distintos (fuertes y flojos). */
function sample(date: string, n: number): void {
  const items: HandScores["items"] = [];
  const lines: string[] = [];
  for (const task of INSIGHTS_TASKS) {
    const rows = latestRows(task, date).filter((r) => r.status === 200 && r.appParsed && r.detailOut.out);
    // Orden determinista que reparte candidatos y casos: por candidato, el caso que toca en su turno.
    const byCand = new Map<string, ResultRow[]>();
    for (const r of rows.sort((a, b) => rowKey(a).localeCompare(rowKey(b)))) byCand.set(`${r.candidate}|${r.effort}`, [...(byCand.get(`${r.candidate}|${r.effort}`) ?? []), r]);
    const cands = [...byCand.keys()].sort();
    const picked: ResultRow[] = [];
    const usedCases = new Map<string, number>();
    for (let i = 0; picked.length < n && i < cands.length * 4; i++) {
      const cand = cands[(i * 7) % cands.length];
      const pool = (byCand.get(cand) ?? []).filter((r) => !picked.includes(r));
      pool.sort((a, b) => (usedCases.get(a.case) ?? 0) - (usedCases.get(b.case) ?? 0));
      const r = pool[0];
      if (!r) continue;
      picked.push(r);
      usedCases.set(r.case, (usedCases.get(r.case) ?? 0) + 1);
    }
    const cases = caseMap(task);
    for (const r of picked) {
      const c = cases.get(r.case);
      if (!c) continue;
      const body = taskByName(task).body(c, { candidate: CANDIDATES[0] } as Variant);
      items.push({ task, key: rowKey(r), contradice: null, util: null, voz: null, nota: "" });
      lines.push(`\n######## ${task} · ${rowKey(r)} · determinista=${r.pass ? "pasa" : "falla"} ${JSON.stringify((r.detailOut.failures as string[]) ?? [])}`);
      lines.push(`IDIOMA: ${c.locale ?? c.input?.locale}`);
      lines.push(`DATOS: ${userDataJSON(body)}`);
      lines.push(renderResponse(task, r.detailOut.out));
    }
  }
  const out = new URL(HAND_FILE, resultsDir(date));
  if (!existsSync(out)) {
    const skeleton: HandScores = {
      scorer: "Frank (sesión 2, trabajador B), leyendo cada respuesta ANTES de ver al juez",
      rubric: "contradice = alguna afirmación falsa o sin apoyo en los datos; util = dice algo concreto y relevante sobre estos datos; voz = no regaña, no pregunta. Pasa = !contradice && util.",
      items,
    };
    writeFileSync(out, `${JSON.stringify(skeleton, null, 1)}\n`);
  }
  console.log(lines.join("\n"));
}

function agreement(date: string): void {
  const hand = JSON.parse(readFileSync(new URL(HAND_FILE, resultsDir(date)), "utf8")) as HandScores;
  const scored = hand.items.filter((i) => i.contradice !== null && i.util !== null);
  const judged = new Map<string, JudgeRow>();
  for (const task of INSIGHTS_TASKS) for (const j of judgeRows(task, date)) judged.set(`${task}|${rowKey(j)}|${j.judge}`, j);
  const lines = ["| Juez | Respuestas | Coinciden | Acuerdo | κ de Cohen | Contradice: coincide | Útil: coincide |", "|---|---|---|---|---|---|---|"];
  const ids = [...JUDGES.map((j) => j.id), "par (los dos de otro proveedor, ambos «pasa»)"];
  for (const id of ids) {
    const a: boolean[] = [];
    const b: boolean[] = [];
    let cAgree = 0;
    let uAgree = 0;
    for (const it of scored) {
      const handPass = !it.contradice && !!it.util;
      let v: { contradice: boolean; util: boolean } | null = null;
      if (id.startsWith("par")) {
        const cand = it.key.split("|")[1];
        const pair = judgesFor(cand.split(":")[0]).map((j) => judged.get(`${it.task}|${it.key}|${j.id}`)?.verdict);
        if (pair.length < 2 || pair.some((x) => !x)) continue;
        v = { contradice: pair.some((x) => x!.contradice), util: pair.every((x) => x!.util) };
      } else {
        // Nadie se juzga a sí mismo, tampoco al medir el acuerdo: fuera las respuestas de su propio proveedor.
        if (it.key.split("|")[1].split(":")[0] === id.split(":")[0]) continue;
        const j = judged.get(`${it.task}|${it.key}|${id}`)?.verdict;
        if (!j) continue;
        v = j;
      }
      a.push(handPass);
      b.push(verdictPass(v));
      if (v.contradice === it.contradice) cAgree++;
      if (v.util === it.util) uAgree++;
    }
    const agree = a.filter((x, i) => x === b[i]).length;
    lines.push(`| ${id} | ${a.length} | ${agree} | ${a.length ? ((agree / a.length) * 100).toFixed(0) : "-"} % | ${cohenKappa(a, b).toFixed(2)} | ${a.length ? ((cAgree / a.length) * 100).toFixed(0) : "-"} % | ${a.length ? ((uAgree / a.length) * 100).toFixed(0) : "-"} % |`);
  }
  const handPassRate = scored.filter((i) => !i.contradice && i.util).length;
  console.log(`Muestra a mano: ${scored.length} respuestas (${handPassRate} pasan). Un juez decide si κ ≥ ${JUDGE_MIN_KAPPA} y acuerdo ≥ ${JUDGE_MIN_AGREEMENT * 100} %.\n`);
  console.log(lines.join("\n"));
}

export async function main(): Promise<void> {
  const date = arg("date") ?? new Date().toISOString().slice(0, 10);
  if (arg("sample")) return sample(date, Number(arg("sample")));
  if (process.argv.includes("--agreement")) return agreement(date);
  const tasks = (arg("task") ?? INSIGHTS_TASKS.join(",")).split(",");
  const only = arg("only")?.split(",") ?? null;
  const keyFilter = arg("keys") ? new Set((JSON.parse(readFileSync(arg("keys")!, "utf8")) as { items: { task: string; key: string }[] }).items.map((i) => `${i.task}|${i.key}`)) : null;
  const judgeFilter = arg("judges");
  const k = keys();
  for (const task of tasks) {
    const cases = caseMap(task);
    const done = new Set(judgeRows(task, date).filter((j) => j.status === 200 && j.verdict).map((j) => `${rowKey(j)}|${j.judge}`));
    const jobs: { row: ResultRow; judge: Judge }[] = [];
    for (const row of latestRows(task, date)) {
      if (row.status !== 200 || !row.appParsed || !row.detailOut.out) continue;
      if (only && !only.some((o) => row.candidate === o || row.candidate.startsWith(`${o}:`) || `${row.candidate}|${row.effort ?? "-"}` === o)) continue;
      if (keyFilter && !keyFilter.has(`${task}|${rowKey(row)}`)) continue;
      const js = judgeFilter === "all" ? JUDGES : judgesFor(row.provider);
      for (const judge of js) if (!done.has(`${rowKey(row)}|${judge.id}`)) jobs.push({ row, judge });
    }
    console.log(`${task}: ${jobs.length} juicios pendientes`);
    const out = new URL(`${task}.judge.jsonl`, resultsDir(date));
    let n = 0;
    await pool(jobs, Number(arg("concurrency") ?? 6), async ({ row, judge }) => {
      const c = cases.get(row.case);
      if (!c) return;
      const jr = await judgeOne(task, c, row, judge, k);
      appendFileSync(out, `${JSON.stringify(jr)}\n`);
      n++;
      if (jr.status !== 200 || !jr.verdict) console.log(`  ${judge.id} ${rowKey(row)} → ${jr.status} ${jr.error ?? "veredicto ilegible"}`);
      else if (n % 25 === 0) console.log(`  ${n}/${jobs.length}`);
    });
  }
}

