/**
 * El juez de `chat.answer`, aparte de la pasada del banco (que solo aplica el criterio determinista).
 *
 *   cd gateway
 *   npx vite-node bench/tasks/chat.answer.judge.ts -- sample --n 36            # plantilla de la muestra a mano
 *   (puntuar a mano: `mine` = "pass" | "fail" y `why` en results/<fecha>/chat.answer.handscore.json)
 *   npx vite-node bench/tasks/chat.answer.judge.ts -- agree --judges gemini:gemini-3.8-flash,anthropic:claude-haiku-5-5
 *   npx vite-node bench/tasks/chat.answer.judge.ts -- apply --judges <ids> [--first]   # juzga y reescribe `pass`
 *   npx vite-node bench/tasks/chat.answer.judge.ts -- regrade                  # rehace el determinista con las respuestas guardadas
 *
 * Todo juicio se guarda en `results/<fecha>/chat.answer.judge.jsonl` (con su coste, que cuenta `--spend`) y no se
 * paga dos veces: la clave es caso + hash de la respuesta + juez. `apply` deja el veredicto determinista en
 * `detailOut.det` y escribe `pass = det && jueces`, así que `npm run bench -- --report` rehace la tabla.
 */
import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { agreement, answerHash, JUDGES, judgeMessages, judgesFor, runJudge, type JudgeResult } from "../lib/chatJudge";
import { gradeChatAnswer, type ChatAnswerCase } from "../lib/chatAnswer";
import { materializeTurns, PERSONAS } from "./chat.answer";

/* eslint-disable @typescript-eslint/no-explicit-any */
type Json = any;

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const cmd = process.argv.find((a) => ["sample", "agree", "apply", "regrade"].includes(a));
const date = arg("date") ?? new Date().toISOString().slice(0, 10);
const DIR = new URL(`../results/${date}/`, import.meta.url);
const ROWS = new URL("chat.answer.jsonl", DIR);
const JUDGED = new URL("chat.answer.judge.jsonl", DIR);
const HAND = new URL("chat.answer.handscore.json", DIR);
const CASES: ChatAnswerCase[] = JSON.parse(readFileSync(new URL("../cases/chat.answer.json", import.meta.url), "utf8")).cases;

function caseById(id: string): ChatAnswerCase {
  const c = CASES.find((x) => x.id === id);
  if (!c) throw new Error(`caso desconocido ${id}`);
  return materializeTurns(c);
}

function rowKey(r: Json): string {
  return [r.case, r.candidate, r.effort ?? "-", r.rep].join("|");
}

/** La última línea de cada medida (como `summarize`). */
function latestRows(): Json[] {
  const m = new Map<string, Json>();
  for (const l of readFileSync(ROWS, "utf8").split("\n").filter(Boolean)) {
    const r = JSON.parse(l);
    m.set(rowKey(r), r);
  }
  return [...m.values()];
}

function judged(): Map<string, Json> {
  const m = new Map<string, Json>();
  if (!existsSync(JUDGED)) return m;
  for (const l of readFileSync(JUDGED, "utf8").split("\n").filter(Boolean)) {
    const r = JSON.parse(l);
    if (r.verdict) m.set([r.case, r.answerHash, r.candidate].join("|"), r);
  }
  return m;
}

async function pool<T>(items: T[], n: number, fn: (t: T) => Promise<void>): Promise<void> {
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, items.length) }, async () => { while (i < items.length) await fn(items[i++]); }));
}

/** Juzga (o reusa) una respuesta con un juez; deja la línea en `chat.answer.judge.jsonl`. */
async function judgeOnce(cache: Map<string, Json>, caseId: string, judgedCandidate: string, answer: string, judgeId: string): Promise<Json | null> {
  const hash = answerHash(answer);
  const key = [caseId, hash, judgeId].join("|");
  const hit = cache.get(key);
  if (hit) return hit;
  const c = caseById(caseId);
  const p = PERSONAS.get(c.persona)!;
  const j = JUDGES[judgeId];
  let res: JudgeResult = await runJudge(j, judgeMessages(p, c, answer));
  if (res.verdict === null && res.status !== 200) res = await runJudge(j, judgeMessages(p, c, answer));
  const row = { task: "chat.answer.judge", case: caseId, candidate: judgeId, provider: j.provider, model: j.model, judged: judgedCandidate, answerHash: hash, verdict: res.verdict, reason: res.reason, status: res.status, ms: res.ms, usage: res.usage, cost: res.cost, ...(res.error ? { error: res.error } : {}), at: new Date().toISOString() };
  appendFileSync(JUDGED, `${JSON.stringify(row)}\n`);
  if (row.verdict) cache.set(key, row);
  return row.verdict ? row : null;
}

if (cmd === "sample") {
  // Muestra estratificada de respuestas que pasan el determinista (es donde decide el juez): una por caso y
  // candidato distinto, rotando, hasta `n`. Determinista: mismo orden en cada corrida.
  const n = Number(arg("n") ?? 36);
  const rows = latestRows().filter((r) => r.status === 200 && r.detailOut?.det);
  const byCase = new Map<string, Json[]>();
  for (const r of rows.sort((a, b) => (a.candidate < b.candidate ? -1 : 1))) byCase.set(r.case, [...(byCase.get(r.case) ?? []), r]);
  const picked: Json[] = [];
  const used = new Set<string>();
  for (let round = 0; picked.length < n && round < 50; round++) {
    for (const [, list] of [...byCase.entries()].sort()) {
      const r = list[(round * 7 + list.length) % list.length];
      if (!r || used.has(rowKey(r)) || picked.length >= n) continue;
      used.add(rowKey(r));
      picked.push(r);
    }
  }
  const out = picked.map((r) => ({ key: rowKey(r), case: r.case, candidate: r.candidate, effort: r.effort, rep: r.rep, question: caseById(r.case).question, expected: r.detailOut.expected, answer: r.detailOut.answer, mine: "", why: "" }));
  if (existsSync(HAND)) throw new Error(`ya existe ${HAND.pathname}: no se pisa una muestra puntuada`);
  writeFileSync(HAND, `${JSON.stringify(out, null, 2)}\n`);
  console.log(`muestra de ${out.length} respuestas en ${HAND.pathname}: puntúalas a mano antes de llamar a ningún juez`);
}

if (cmd === "agree") {
  const ids = (arg("judges") ?? "").split(",").filter(Boolean);
  const hand = JSON.parse(readFileSync(HAND, "utf8")) as Json[];
  if (hand.some((h) => h.mine !== "pass" && h.mine !== "fail")) throw new Error("la muestra no está puntuada entera: el juez no se mira antes");
  const cache = judged();
  const results = new Map<string, Map<string, boolean | null>>();
  const jobs = hand.flatMap((h) => ids.map((id) => ({ h, id })));
  await pool(jobs, 4, async ({ h, id }) => {
    const provider = id.split(":")[0];
    if (h.candidate.split(":")[0] === provider) return; // nadie se juzga a sí mismo
    const row = await judgeOnce(cache, h.case, h.candidate, h.answer, id);
    if (!results.has(id)) results.set(id, new Map());
    results.get(id)!.set(h.key, row ? row.verdict === "pass" : null);
  });
  const lines = ["| Juez | Respuestas | Acuerdo | κ de Cohen | Juez pass / yo fail | Juez fail / yo pass |", "|---|---|---|---|---|---|"];
  for (const id of ids) {
    const m = results.get(id) ?? new Map();
    const pairs = hand.filter((h) => m.get(h.key) !== undefined && m.get(h.key) !== null);
    const a = agreement(pairs.map((h) => h.mine === "pass"), pairs.map((h) => m.get(h.key) as boolean));
    lines.push(`| \`${id}\` | ${a.n} | ${(a.accuracy * 100).toFixed(1)} % | ${a.kappa.toFixed(2)} | ${a.fp} | ${a.fn} |`);
    for (const h of pairs) if ((h.mine === "pass") !== m.get(h.key)) console.log(`  desacuerdo ${id} en ${h.key}: yo ${h.mine} · juez ${m.get(h.key) ? "pass" : "fail"} — ${cache.get([h.case, answerHash(h.answer), id].join("|"))?.reason ?? ""}`);
  }
  console.log(lines.join("\n"));
}

if (cmd === "apply") {
  const ids = (arg("judges") ?? "").split(",").filter(Boolean);
  const all = readFileSync(ROWS, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const cache = judged();
  const todo = all.filter((r) => r.status === 200 && r.detailOut?.det === true);
  let done = 0;
  await pool(todo, 4, async (r) => {
    const verdicts: Record<string, string | null> = {};
    // `--first`: solo el primer juez de la lista que pueda juzgar a ese candidato (el resto es el relevo para su
    // propio proveedor). Sin él, todos los aplicables, y basta un «fail» para suspender.
    const applicable = judgesFor(r.provider, ids);
    for (const j of process.argv.includes("--first") ? applicable.slice(0, 1) : applicable) {
      const row = await judgeOnce(cache, r.case, r.candidate, r.detailOut.answer, j.id);
      verdicts[j.id] = row?.verdict ?? null;
    }
    r.detailOut.judge = verdicts;
    if (++done % 25 === 0) console.log(`  ${done}/${todo.length}`);
  });
  for (const r of all) {
    if (r.status !== 200 || !r.detailOut) continue;
    if (r.detailOut.det === undefined) r.detailOut.det = r.pass;
    const v = Object.values((r.detailOut.judge ?? {}) as Record<string, string | null>);
    // Sin veredicto de ningún juez (fallo de red del juez), la medida queda con el determinista y se dice.
    r.pass = r.detailOut.det === true && v.every((x) => x !== "fail");
    if (r.detailOut.det === true && v.some((x) => x === null)) r.detailOut.judgeMissing = true;
  }
  writeFileSync(ROWS, `${all.map((r) => JSON.stringify(r)).join("\n")}\n`);
  console.log(`juzgadas ${todo.length} respuestas con ${ids.join(", ")}; rehaz la tabla con npm run bench -- --report --task chat.answer`);
}

if (cmd === "regrade") {
  // El criterio determinista cambió: se vuelve a aplicar a la respuesta guardada, sin llamar a nadie. Conserva los
  // veredictos de los jueces que ya hubiera.
  const all = readFileSync(ROWS, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  let changed = 0;
  for (const r of all) {
    if (r.status !== 200 || typeof r.detailOut?.answer !== "string") continue;
    const c = caseById(r.case);
    const g = gradeChatAnswer(r.detailOut.answer, c, PERSONAS.get(c.persona)!);
    const judge = r.detailOut.judge;
    if (g.pass !== r.detailOut.det) changed++;
    r.detailOut = { ...g.detail, ...(judge ? { judge } : {}) };
    const v = Object.values((judge ?? {}) as Record<string, string | null>);
    r.pass = g.pass && v.every((x) => x !== "fail");
    r.appParsed = g.appParsed;
  }
  writeFileSync(ROWS, `${all.map((r) => JSON.stringify(r)).join("\n")}\n`);
  console.log(`re-puntuadas ${all.length} filas; ${changed} cambian de veredicto determinista`);
}
