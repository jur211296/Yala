/**
 * Informe de las cuatro tareas de Insights y Tendencias (sesión 2, trabajador B).
 *
 *   npx vite-node bench/lib/insightsReport.ts -- --regrade            # vuelve a puntuar con el criterio actual
 *   npx vite-node bench/lib/insightsReport.ts -- --table [--since ISO] [--serial-from ISO]
 *   npx vite-node bench/lib/insightsReport.ts -- --spend              # gasto por tarea y proveedor (llamadas + juez)
 *
 * `--regrade` reescribe `detailOut`/`pass` de cada fila desde el texto que la app leyó (`detailOut.out`), que el
 * parser de la app devuelve igual si se le vuelve a dar: así un ajuste del criterio no obliga a volver a llamar a nadie.
 * La latencia de la tabla sale SOLO de las llamadas hechas desde `--serial-from` (la pasada en serie); las de la criba
 * en paralelo no son una medida de latencia.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { CANDIDATES } from "../candidates";
import { taskByName } from "../tasks";
import type { BenchCase, Variant } from "../tasks/types";
import { INSIGHTS_TASKS, judgeRows, judgesFor, latestRows, resultsDir, rowKey, type ResultRow } from "./insightsJudge";

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

function pct(xs: number[], p: number): number {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)];
}

function cases(task: string): Map<string, BenchCase> {
  const t = taskByName(task);
  const f = JSON.parse(readFileSync(new URL(`../cases/${t.casesFile ?? `${task}.json`}`, import.meta.url), "utf8")) as { cases: BenchCase[] };
  return new Map(f.cases.map((c) => [c.id, c]));
}

async function regrade(date: string): Promise<void> {
  for (const task of INSIGHTS_TASKS) {
    const t = taskByName(task);
    const cs = cases(task);
    const file = new URL(`${task}.jsonl`, resultsDir(date));
    const lines = readFileSync(file, "utf8").split("\n").filter(Boolean);
    let changed = 0;
    const out: string[] = [];
    for (const l of lines) {
      const r = JSON.parse(l) as ResultRow;
      const c = cs.get(r.case);
      if (r.status === 200 && r.appParsed && r.detailOut.out && c) {
        const g = await t.grade(JSON.stringify(r.detailOut.out), c, { candidate: CANDIDATES[0] } as Variant);
        if (g.pass !== r.pass) changed++;
        r.pass = g.pass;
        r.detailOut = g.detail;
      }
      out.push(JSON.stringify(r));
    }
    writeFileSync(file, `${out.join("\n")}\n`);
    console.log(`${task}: ${lines.length} filas, ${changed} cambian de veredicto`);
  }
}

interface Judged {
  /** Veredicto de los jueces de otro proveedor (`judgesFor`: uno en Insights, dos en Tendencias): pasa si todos pasan. */
  pass: boolean | null;
  contradice: boolean | null;
}

function judgedMap(task: string, date: string): Map<string, Judged> {
  const by = new Map<string, Map<string, { contradice: boolean; util: boolean }>>();
  for (const j of judgeRows(task, date)) {
    if (!j.verdict) continue;
    const k = rowKey(j);
    by.set(k, (by.get(k) ?? new Map()).set(j.judge, j.verdict));
  }
  const out = new Map<string, Judged>();
  for (const [k, m] of by) {
    const cand = k.split("|")[1];
    const pair = judgesFor(cand.split(":")[0], task).map((j) => m.get(j.id));
    if (pair.some((v) => !v)) continue;
    out.set(k, { pass: pair.every((v) => !v!.contradice && v!.util), contradice: pair.some((v) => v!.contradice) });
  }
  return out;
}

/**
 * Revisión manual de las cifras que el verificador no pudo explicar (`insights.flagged-review.json`), hecha leyendo cada
 * una contra los datos: `derivado` (aritmética correcta de varios pasos o entre bloques: 610.000 + 52.400 = 662.400),
 * `sugerencia` (un importe propuesto como consejo, «fija un tope de S/ 180»: no afirma nada de los datos) e `inventado`
 * (cifra falsa o sin base: una media mal calculada, una fecha futura, un ahorro estimado). Las dos primeras no cuentan
 * como número sin respaldo; la tercera sí.
 */
type ReviewVerdict = "derivado" | "sugerencia" | "inventado";

function reviews(date: string): Map<string, ReviewVerdict> {
  const m = new Map<string, ReviewVerdict>();
  try {
    const f = JSON.parse(readFileSync(new URL("insights.flagged-review.json", resultsDir(date)), "utf8")) as { items: { task: string; key: string; number: string; verdict: ReviewVerdict }[] };
    for (const i of f.items) m.set(`${i.task}|${i.key}|${i.number}`, i.verdict);
  } catch {
    // sin revisión todavía
  }
  return m;
}

/** Fallos de la fila tras aplicar la revisión manual de cifras. `null` en la cifra = sin revisar. */
export function reviewedFailures(task: string, r: ResultRow, rev: Map<string, ReviewVerdict>): { failures: string[]; invented: number; unreviewed: number } {
  const failures = [...((r.detailOut.failures as string[] | undefined) ?? [])];
  const unverified = (r.detailOut.unverified as string[] | undefined) ?? [];
  let invented = 0;
  let unreviewed = 0;
  for (const n of unverified) {
    const v = rev.get(`${task}|${rowKey(r)}|${n}`);
    if (v === "inventado") invented++;
    else if (!v) unreviewed++;
  }
  const i = failures.indexOf("número sin respaldo");
  if (i >= 0 && invented === 0 && unreviewed === 0) failures.splice(i, 1);
  return { failures, invented, unreviewed };
}

function table(date: string, serialFrom: string | undefined, judgeDecides: boolean): void {
  const rev = reviews(date);
  for (const task of INSIGHTS_TASKS) {
    const rows = latestRows(task, date);
    if (!rows.length) continue;
    const judged = judgedMap(task, date);
    const groups = new Map<string, ResultRow[]>();
    for (const r of rows) groups.set(`${r.candidate}|${r.effort ?? "-"}`, [...(groups.get(`${r.candidate}|${r.effort ?? "-"}`) ?? []), r]);
    const stats = [...groups.entries()].map(([k, rs]) => {
      const ok = rs.filter((r) => r.status === 200);
      const parsed = rs.filter((r) => r.appParsed);
      const failures = (r: ResultRow) => (r.detailOut.failures as string[] | undefined) ?? [];
      const has = (r: ResultRow, f: string) => failures(r).some((x) => x.startsWith(f));
      const js = rs.map((r) => judged.get(rowKey(r)));
      const judgedN = js.filter((j) => j && j.pass !== null).length;
      const reviewed = rs.map((r) => (r.appParsed ? reviewedFailures(task, r, rev) : { failures: ["parser"], invented: 0, unreviewed: 0 }));
      const detPass = (i: number) => rs[i].status === 200 && reviewed[i].failures.length === 0;
      const finalPass = rs.filter((_, i) => detPass(i) && (!judgeDecides || js[i]?.pass === true)).length;
      const noLang = rs.filter((_, i) => rs[i].status === 200 && reviewed[i].failures.every((f) => f.startsWith("idioma")) && (!judgeDecides || js[i]?.pass === true)).length;
      const serial = serialFrom ? ok.filter((r) => r.at >= serialFrom) : [];
      const costs = ok.map((r) => r.cost ?? 0);
      const outs = ok.map((r) => r.usage?.outputTokens ?? 0);
      return {
        k,
        n: rs.length,
        acc: rs.filter((r) => r.pass).length / rs.length,
        final: finalPass / rs.length,
        noLang: noLang / rs.length,
        inventedRows: reviewed.filter((x) => x.invented > 0).length,
        unreviewedRows: reviewed.filter((x) => x.unreviewed > 0).length,
        judgedN,
        judgePass: js.filter((j) => j?.pass === true).length,
        contradice: js.filter((j) => j?.contradice === true).length,
        parsed: parsed.length / rs.length,
        invented: parsed.filter((r) => has(r, "número sin respaldo")).length,
        lang: parsed.filter((r) => has(r, "idioma")).length,
        after: parsed.filter((r) => has(r, "divisa detrás")).length,
        long: parsed.filter((r) => has(r, "largo")).length,
        shape: parsed.filter((r) => failures(r).some((f) => /^(tarjetas|icono|charts|chart|viñeta sin cifra|hero sin cifra|comment null|tarjeta vacía|comentario vacío)/.test(f))).length,
        errors: rs.length - ok.length,
        p50: pct(serial.map((r) => r.ms), 50),
        p95: pct(serial.map((r) => r.ms), 95),
        p95all: pct(ok.map((r) => r.ms), 95),
        serialN: serial.length,
        tin: ok.reduce((a, r) => a + (r.usage?.inputTokens ?? 0), 0) / (ok.length || 1),
        tout: outs.reduce((a, b) => a + b, 0) / (ok.length || 1),
        p99out: pct(outs, 99),
        cost: costs.length ? costs.reduce((a, b) => a + b, 0) / costs.length : NaN,
      };
    });
    stats.sort((a, b) => b.final - a.final || b.noLang - a.noLang || a.cost - b.cost);
    const head =
      "| Candidato | Esfuerzo | Llamadas | Acierto | Acierto sin idioma | Acierto determinista (sin revisar) | Juez: pasa / juzgadas | Contradice (juez) | JSON aceptado | Cifra marcada | Inventada (revisada) | Sin revisar | Idioma mal | Divisa detrás | Forma | Largo | Errores | p50 / p95 ms (serie) | p95 ms (criba) | Tokens entrada / salida | p99 salida | USD por 1 000 |";
    const lines = [`### ${task}`, "", head, `|${"---|".repeat(22)}`];
    for (const s of stats) {
      const [cand, effort] = s.k.split("|");
      lines.push(
        `| \`${cand}\` | ${effort} | ${s.n} | ${(s.final * 100).toFixed(1)} % | ${(s.noLang * 100).toFixed(1)} % | ${(s.acc * 100).toFixed(1)} % | ${s.judgedN ? `${s.judgePass}/${s.judgedN}` : "—"} | ${s.judgedN ? s.contradice : "—"} | ${(s.parsed * 100).toFixed(0)} % | ${s.invented} | ${s.inventedRows} | ${s.unreviewedRows} | ${s.lang} | ${s.after} | ${s.shape} | ${s.long} | ${s.errors} | ${s.serialN ? `${s.p50} / ${s.p95}` : "—"} | ${Number.isNaN(s.p95all) ? "—" : s.p95all} | ${Math.round(s.tin)} / ${Math.round(s.tout)} | ${Number.isNaN(s.p99out) ? "—" : s.p99out} | ${(s.cost * 1000).toFixed(3)} |`,
      );
    }
    console.log(`${lines.join("\n")}\n`);
  }
}

function spend(date: string): void {
  const tot: Record<string, number> = {};
  for (const task of INSIGHTS_TASKS) {
    for (const suffix of ["", ".judge"]) {
      let text = "";
      try {
        text = readFileSync(new URL(`${task}${suffix}.jsonl`, resultsDir(date)), "utf8");
      } catch {
        continue;
      }
      for (const l of text.split("\n").filter(Boolean)) {
        const r = JSON.parse(l) as { provider: string; cost: number | null };
        const k = `${task}${suffix ? " (juez)" : ""} · ${r.provider}`;
        tot[k] = (tot[k] ?? 0) + (r.cost ?? 0);
      }
    }
  }
  const byProvider: Record<string, number> = {};
  for (const [k, v] of Object.entries(tot)) {
    console.log(`${k}: ${v.toFixed(3)} USD`);
    const p = k.split(" · ")[1];
    byProvider[p] = (byProvider[p] ?? 0) + v;
  }
  console.log("\nPor proveedor:", Object.entries(byProvider).map(([p, v]) => `${p} ${v.toFixed(3)}`).join(" · "));
  console.log(`Total: ${Object.values(tot).reduce((a, b) => a + b, 0).toFixed(3)} USD`);
}

const date = arg("date") ?? new Date().toISOString().slice(0, 10);
if (process.argv.includes("--regrade")) await regrade(date);
if (process.argv.includes("--table")) table(date, arg("serial-from"), process.argv.includes("--judge-decides"));
if (process.argv.includes("--spend")) spend(date);
