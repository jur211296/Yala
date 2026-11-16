/**
 * Pinta el panel en un HTML local, sin desplegar nada.
 *
 *   npm run preview -- <salida.html>            datos reales: lee Analytics Engine con el token de solo lectura
 *                                               (~/Secrets/yala-cloudflare/analytics-read.token o $CF_ANALYTICS_TOKEN)
 *   npm run preview -- <salida.html> --vacio    la página sin ningún día resumido
 *
 * Corre el mismo resumen que el cron (85 días hasta ayer) en memoria: no escribe en ninguna D1. Los conteos de la base
 * no se piden (necesitan el JWT de máquina), así que esas tarjetas salen «sin datos aún».
 */
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { addDays, dayOf, dayRange } from "../src/days";
import { analyticsEngineRunner, fetchRawData } from "../src/ae";
import { BACKFILL_DAYS } from "../src/cron";
import { renderPage } from "../src/render";
import { summarize } from "../src/summarize";
import { buildView } from "../src/view";

const out = process.argv[2];
if (!out) {
  process.stdout.write("uso: npm run preview -- <salida.html> [--vacio]\n");
  process.exit(1);
}
const now = new Date();
const generatedAt = now.toISOString().slice(0, 16).replace("T", " ") + " UTC";

if (process.argv.includes("--vacio")) {
  writeFileSync(out, renderPage(buildView([], []), { throughDay: null, lastRun: "El resumen aún no ha corrido.", generatedAt }));
  process.exit(0);
}

const tokenPath = `${homedir()}/Secrets/yala-cloudflare/analytics-read.token`;
const token = process.env.CF_ANALYTICS_TOKEN ?? (existsSync(tokenPath) ? readFileSync(tokenPath, "utf8").trim() : "");
if (!token) {
  process.stdout.write("falta el token de Analytics Engine (CF_ANALYTICS_TOKEN o ~/Secrets/yala-cloudflare/analytics-read.token)\n");
  process.exit(1);
}
const lastComplete = addDays(dayOf(now), -1);
const days = dayRange(addDays(lastComplete, -(BACKFILL_DAYS - 1)), lastComplete);
const run = analyticsEngineRunner("86c270a7776be98639700bd5959b303b", token);
const raw = await fetchRawData(run, { metrics: "yala_metrics", aiUsage: "yala_ai_usage" }, addDays(days[0], -37), addDays(lastComplete, 1));
const rows = summarize(raw, days, lastComplete);
const history = rows.filter((r) => r.metric === "active" && r.dim === "").map((r) => ({ day: r.day, value: r.value }));
const html = renderPage(buildView(rows, history), {
  throughDay: lastComplete,
  lastRun: `Vista previa local con datos reales de Analytics Engine (${days.length} días); sin conteos de la base.`,
  generatedAt,
});
writeFileSync(out, html);
process.stdout.write(`${out}: ${rows.length} filas resumidas hasta ${lastComplete}\n`);
