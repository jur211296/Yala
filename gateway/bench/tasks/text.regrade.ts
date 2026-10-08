/**
 * Vuelve a puntuar `text.parse` o `chat.rewrite` con el criterio de hoy sobre la respuesta GUARDADA, sin llamar a
 * ningún modelo (para cuando el criterio se corrige después de medir; el informe dice cuándo se usó).
 *
 *   cd gateway && npx vite-node bench/tasks/text.regrade.ts -- --task text.parse [--date AAAA-MM-DD]
 *
 * `text.parse` guarda la respuesta entera en `detailOut.content` y `chat.rewrite` las frases en `detailOut.items`.
 * Una fila de `text.parse` medida antes de que se guardara la respuesta no se puede re-puntuar: se lista y se
 * borra con `--drop-unregradable`, para que `npm run bench` la repita.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { gradeRewrite, type RewriteCase } from "../lib/chatRewrite";
import { gradeTextParse, type TextParseCase } from "../lib/textParse";

/* eslint-disable @typescript-eslint/no-explicit-any */
type Json = any;

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const task = arg("task");
if (task !== "text.parse" && task !== "chat.rewrite") throw new Error("--task text.parse | chat.rewrite");
const date = arg("date") ?? new Date().toISOString().slice(0, 10);
const file = new URL(`../results/${date}/${task}.jsonl`, import.meta.url);
const cases: Json[] = JSON.parse(readFileSync(new URL(`../cases/${task}.json`, import.meta.url), "utf8")).cases;
const rows: Json[] = readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const keep: Json[] = [];
let changed = 0;
const cannot: string[] = [];
for (const r of rows) {
  const c = cases.find((x) => x.id === r.case);
  if (r.status !== 200 || !r.appParsed || !c) { keep.push(r); continue; }
  const content = task === "text.parse" ? r.detailOut?.content : r.detailOut?.items ? JSON.stringify({ suggestions: r.detailOut.items }) : undefined;
  if (typeof content !== "string") {
    cannot.push(`${r.case} ${r.candidate} ${r.effort ?? ""}`);
    if (!process.argv.includes("--drop-unregradable")) keep.push(r);
    continue;
  }
  const g = task === "text.parse" ? gradeTextParse(content, c as TextParseCase) : gradeRewrite(content, c as RewriteCase);
  if (g.pass !== r.pass) changed++;
  keep.push({ ...r, pass: g.pass, appParsed: g.appParsed, detailOut: g.detail });
}
writeFileSync(file, `${keep.map((r) => JSON.stringify(r)).join("\n")}\n`);
console.log(`${task}: ${rows.length} filas, ${changed} cambian de veredicto; ${cannot.length} sin respuesta guardada${process.argv.includes("--drop-unregradable") ? " (borradas para repetirlas)" : ""}`);
