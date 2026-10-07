/**
 * Banco de calidad de modelos de IA de Yala.
 *
 *   cd gateway && npm run bench -- --task chat.intent
 *   npm run bench -- --task photo.read --only openai:gpt-6-luna --edges 0,2048,1024 --details low,high
 *   npm run bench -- --task all                     # revisión periódica: todo, con los candidatos de hoy
 *   npm run bench -- --report                       # solo rehace los resúmenes desde los .jsonl
 *
 * Cada caso se manda con el MISMO cuerpo que manda la app (prompts leídos de Swift) y a través del MISMO
 * adaptador que usa el gateway. Se puntúa con el criterio explícito de la tarea (lib/grading.ts) y se
 * guarda una línea por llamada en `bench/results/<fecha>/<tarea>.jsonl` (sin contenido del usuario: los
 * casos son públicos y van en el repo). Reanudable: lo ya medido en ese fichero no se repite.
 *
 * Claves: `~/Secrets/yala-ai-bench/{openai,gemini,anthropic}.key` (nunca las del Worker). Workers AI usa
 * el login de wrangler (`npx wrangler whoami` lo refresca).
 */
import { execFileSync } from "node:child_process";
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { ADAPTERS } from "../src/ai/providers";
import type { ProviderKeys, Usage } from "../src/ai/providers/types";
import type { ChatParams, ImageDetail, ManagedRoute, ReasoningEffort } from "../src/ai/routes";
import { CANDIDATES, CHECKED, costUSD } from "./candidates";
import type { Grade } from "./lib/grading";
import { TASK_REGISTRY, taskByName } from "./tasks";
import type { BenchCase, BenchTask, Variant } from "./tasks/types";

type TaskName = string;
const TASKS: TaskName[] = TASK_REGISTRY.map((t) => t.name);

const BENCH = new URL("./", import.meta.url);
const CASES = new URL("cases/", BENCH);

// ---------- argumentos ----------

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const flag = (name: string) => process.argv.includes(`--${name}`);

const date = arg("date") ?? new Date().toISOString().slice(0, 10);
const RESULTS = new URL(`results/${date}/`, BENCH);

// ---------- claves ----------

function readKey(name: string): string | undefined {
  const p = `${homedir()}/Secrets/yala-ai-bench/${name}.key`;
  return existsSync(p) ? readFileSync(p, "utf8").trim() : undefined;
}

function workersAIKeys(): ProviderKeys["workersai"] {
  const cfg = `${homedir()}/Library/Preferences/.wrangler/config/default.toml`;
  if (!existsSync(cfg)) return undefined;
  let toml = readFileSync(cfg, "utf8");
  // El token OAuth de wrangler dura una hora; `wrangler whoami` lo renueva. Margen: 20 min (una tanda larga).
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
  return { openai: readKey("openai"), gemini: readKey("gemini"), anthropic: readKey("anthropic"), xai: readKey("xai"), workersai: workersAIKeys() };
}

// ---------- variantes ----------

function variantKey(v: Variant): string {
  return [v.candidate.id, v.effort ?? "-", v.detail ?? "-", v.edge ?? "-"].join("|");
}

function routeFor(task: BenchTask, v: Variant): ManagedRoute {
  const base = task.baseParams;
  const params: ChatParams = {
    ...base,
    temperature: v.candidate.temperature ? base.temperature : undefined,
    reasoningEffort: v.effort,
    image: task.image ? { detail: v.detail ?? "auto", maxEdge: v.edge || null } : undefined,
  };
  return { mode: "managed", provider: v.candidate.provider, model: v.candidate.model, params, retries: 0 };
}

function variants(task: BenchTask, only: string[] | null): Variant[] {
  const edges = (arg("edges") ?? "0").split(",").map(Number);
  const detailsArg = arg("details")?.split(",") as ImageDetail[] | undefined;
  const effortsArg = arg("efforts")?.split(",") as ReasoningEffort[] | undefined;
  const out: Variant[] = [];
  for (const c of CANDIDATES) {
    if (only && !only.some((o) => c.id === o || c.id.startsWith(`${o}:`) || c.provider === o)) continue;
    if (task.image && !c.vision) continue;
    const efforts: (ReasoningEffort | undefined)[] = (effortsArg ?? c.efforts ?? [undefined]).filter((e) => !c.efforts || !e || c.efforts.includes(e));
    for (const effort of efforts.length ? efforts : [undefined]) {
      if (!task.image) {
        out.push({ candidate: c, effort });
        continue;
      }
      const details = (detailsArg ?? c.details ?? ["auto"]).filter((d) => !c.details || c.details.includes(d));
      for (const detail of details.length ? details : (c.details ?? ["auto"])) for (const edge of edges) out.push({ candidate: c, effort, detail, edge });
    }
  }
  return out;
}

// ---------- casos ----------

interface CaseFile<C> {
  task: string;
  criterion: string;
  cases: C[];
}

function loadCases<C>(task: BenchTask): CaseFile<C> {
  return JSON.parse(readFileSync(new URL(task.casesFile ?? `${task.name}.json`, CASES), "utf8"));
}

// ---------- ejecución ----------

interface Row {
  task: TaskName;
  case: string;
  candidate: string;
  provider: string;
  model: string;
  effort: string | null;
  detail: string | null;
  edge: number | null;
  rep: number;
  status: number;
  ms: number;
  pass: boolean;
  appParsed: boolean;
  usage: Usage | null;
  cost: number | null;
  detailOut: Record<string, unknown>;
  error?: string;
  at: string;
}

async function pool<T>(items: T[], n: number, fn: (t: T) => Promise<void>): Promise<void> {
  let i = 0;
  await Promise.all(
    Array.from({ length: Math.min(n, items.length) }, async () => {
      while (i < items.length) await fn(items[i++]);
    }),
  );
}

async function runTask(name: TaskName): Promise<void> {
  const task = taskByName(name);
  const file = loadCases<BenchCase>(task);
  const limit = Number(arg("limit") ?? 0);
  const caseFilter = arg("cases")?.split(",");
  const cases = file.cases.filter((c) => !caseFilter || caseFilter.includes(c.id)).slice(0, limit || undefined);
  const only = arg("only")?.split(",") ?? null;
  const reps = Number(arg("reps") ?? 1);
  const k = keys();
  mkdirSync(RESULTS, { recursive: true });
  const out = new URL(`${name}.jsonl`, RESULTS);
  const done = new Set<string>();
  if (existsSync(out)) {
    for (const line of readFileSync(out, "utf8").split("\n").filter(Boolean)) {
      const r = JSON.parse(line) as Row;
      // Un fallo de transporte (red, 429, 5xx) no es una medida: se repite al reanudar.
      if (r.status === 200 || (r.status >= 400 && r.status < 500 && r.status !== 429)) {
        done.add([r.case, r.candidate, r.effort ?? "-", r.detail ?? "-", r.edge ?? "-", r.rep].join("|"));
      }
    }
  }
  const vs = variants(task, only);
  const jobs: { c: BenchCase; v: Variant; rep: number }[] = [];
  for (const v of vs) {
    const providerKey = k[v.candidate.provider];
    if (!providerKey) {
      console.log(`· ${v.candidate.id}: sin clave, se salta`);
      continue;
    }
    for (const c of cases) for (let rep = 0; rep < reps; rep++) {
      const key = [c.id, ...variantKey(v).split("|"), rep].join("|");
      if (!done.has(key)) jobs.push({ c, v, rep });
    }
  }
  console.log(`${name}: ${jobs.length} llamadas pendientes (${vs.length} variantes × ${cases.length} casos)`);
  let n = 0;
  await pool(jobs, Number(arg("concurrency") ?? 4), async ({ c, v, rep }) => {
    const route = routeFor(task, v);
    const body = task.body(c, v);
    const started = performance.now();
    const res = await ADAPTERS[route.provider].send(body as never, route, { keys: k });
    const ms = Math.round(performance.now() - started);
    let g: Grade = { pass: false, appParsed: false, detail: { error: res.error ?? `status ${res.status}` } };
    if (res.status === 200) {
      const content = (JSON.parse(res.body) as { choices?: { message?: { content?: string } }[] }).choices?.[0]?.message?.content ?? "";
      try {
        g = await task.grade(content, c, v);
      } catch (e) {
        // Un fallo del criterio (p. ej. el juez sin red) no es un fallo del candidato: se repite al reanudar.
        console.log(`  criterio de ${name} falló en ${c.id}: ${String(e).slice(0, 160)}`);
        return;
      }
      // Si la app la rechazaría, se guarda el principio para diagnosticar (los casos son públicos).
      if (!g.appParsed) g.detail.raw = content.slice(0, 400);
    }
    const row: Row = {
      task: name,
      case: c.id,
      candidate: v.candidate.id,
      provider: v.candidate.provider,
      model: v.candidate.model,
      effort: v.effort ?? null,
      detail: v.detail ?? null,
      edge: v.edge ?? null,
      rep,
      status: res.status,
      ms,
      pass: g.pass,
      appParsed: g.appParsed,
      usage: res.usage,
      cost: costUSD(v.candidate.price, res.usage),
      detailOut: g.detail,
      ...(res.error ? { error: res.error.slice(0, 300) } : {}),
      at: new Date().toISOString(),
    };
    appendFileSync(out, `${JSON.stringify(row)}\n`);
    n++;
    if (n % 20 === 0 || res.status !== 200) console.log(`  ${n}/${jobs.length} ${v.candidate.id} ${v.effort ?? ""} ${v.detail ?? ""} ${v.edge ?? ""} ${c.id} → ${res.status}${res.error ? ` ${res.error.slice(0, 120)}` : ""}`);
  });
}

// ---------- resumen ----------

function pct(xs: number[], p: number): number {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)];
}

export function summarize(task: TaskName): string | null {
  const file = new URL(`${task}.jsonl`, RESULTS);
  if (!existsSync(file)) return null;
  // Un caso reanudado deja varias líneas: cuenta la última (el fallo de transporte viejo no es una medida).
  const latest = new Map<string, Row>();
  for (const l of readFileSync(file, "utf8").split("\n").filter(Boolean)) {
    const r = JSON.parse(l) as Row;
    latest.set([r.case, r.candidate, r.effort ?? "-", r.detail ?? "-", r.edge ?? "-", r.rep].join("|"), r);
  }
  const rows = [...latest.values()];
  const groups = new Map<string, Row[]>();
  for (const r of rows) {
    const k = [r.candidate, r.effort ?? "-", r.detail ?? "-", r.edge ?? "-"].join("|");
    groups.set(k, [...(groups.get(k) ?? []), r]);
  }
  const lines = [
    `| Candidato | Proveedor | Esfuerzo | Detalle | Lado mayor | Casos | Acierto | JSON válido | Errores | p50 ms | p95 ms | Tokens entrada (media) | Tokens salida (media) | Coste medio (USD) | Coste por 1 000 |`,
    `|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|`,
  ];
  const stats = [...groups.entries()].map(([k, rs]) => {
    const ok = rs.filter((r) => r.status === 200);
    const costs = ok.map((r) => r.cost ?? 0);
    const meanCost = costs.length ? costs.reduce((a, b) => a + b, 0) / costs.length : NaN;
    return {
      k,
      rs,
      acc: rs.filter((r) => r.pass).length / rs.length,
      parsed: rs.filter((r) => r.appParsed).length / rs.length,
      errors: rs.length - ok.length,
      p50: pct(ok.map((r) => r.ms), 50),
      p95: pct(ok.map((r) => r.ms), 95),
      tin: ok.reduce((a, r) => a + (r.usage?.inputTokens ?? 0), 0) / (ok.length || 1),
      tout: ok.reduce((a, r) => a + (r.usage?.outputTokens ?? 0), 0) / (ok.length || 1),
      meanCost,
    };
  });
  stats.sort((a, b) => b.acc - a.acc || a.meanCost - b.meanCost);
  for (const s of stats) {
    const [cand, effort, detail, edge] = s.k.split("|");
    const r0 = s.rs[0];
    lines.push(
      `| \`${cand.split(":").slice(1).join(":")}\` | ${r0.provider} | ${effort} | ${detail} | ${edge === "0" ? "original" : edge} | ${s.rs.length} | ${(s.acc * 100).toFixed(1)} % | ${(s.parsed * 100).toFixed(0)} % | ${s.errors} | ${s.p50} | ${s.p95} | ${Math.round(s.tin)} | ${Math.round(s.tout)} | ${s.meanCost.toFixed(6)} | ${(s.meanCost * 1000).toFixed(3)} |`,
    );
  }
  const md = `# ${task} — banco del ${date}\n\nPrecios comprobados el ${CHECKED}. Generado por \`npm run bench -- --report\`.\n\n${lines.join("\n")}\n`;
  writeFileSync(new URL(`${task}.md`, RESULTS), md);
  return md;
}

// ---------- main ----------

/** Gasto acumulado de la corrida (por proveedor), desde los .jsonl: para no pasarse del presupuesto. */
function spend(): void {
  const total: Record<string, { calls: number; usd: number }> = {};
  for (const t of TASKS) {
    const f = new URL(`${t}.jsonl`, RESULTS);
    if (!existsSync(f)) continue;
    for (const line of readFileSync(f, "utf8").split("\n").filter(Boolean)) {
      const r = JSON.parse(line) as Row;
      const k = r.provider;
      total[k] = { calls: (total[k]?.calls ?? 0) + 1, usd: (total[k]?.usd ?? 0) + (r.cost ?? 0) };
    }
  }
  for (const [k, v] of Object.entries(total)) console.log(`${k}: ${v.calls} llamadas, ${v.usd.toFixed(3)} USD (estimado con los precios de candidates.ts)`);
}

if (flag("spend")) {
  spend();
  process.exit(0);
}

const taskArg = arg("task") ?? "all";
const tasks = taskArg === "all" ? TASKS : (taskArg.split(",") as TaskName[]);
if (!flag("report")) for (const t of tasks) await runTask(t);
for (const t of tasks) {
  const md = summarize(t);
  if (md) console.log(md);
}
