import { checkAccess } from "./access";
import { addDays, dayOf } from "./days";
import type { Env } from "./env";
import { runDaily } from "./cron";
import { renderPage } from "./render";
import { lastRun, readActiveHistory, readRows } from "./store";
import { buildView } from "./view";

/**
 * Panel de Yala — Worker aparte del gateway (decisión 2), para que un fallo aquí no toque el sync de producción.
 *
 *   GET /         la página, detrás de Cloudflare Access (src/access.ts). Lee solo D1.
 *   GET /healthz  vivo, sin datos.
 *   cron diario   06:00 UTC: resume Analytics Engine + la base en D1 (src/cron.ts).
 */
const SECURITY_HEADERS = {
  "content-security-policy":
    "default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  "x-content-type-options": "nosniff",
  "referrer-policy": "no-referrer",
  "cache-control": "private, no-store",
};

export async function handleFetch(request: Request, env: Env, now = new Date()): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname === "/healthz") return new Response("ok", { headers: { "content-type": "text/plain" } });
  if (url.pathname !== "/" || request.method !== "GET") return new Response("no encontrado", { status: 404 });

  const access = await checkAccess(request, env);
  if (!access.ok) return new Response(access.reason, { status: access.status, headers: { "content-type": "text/plain; charset=utf-8" } });

  // 120 días bastan para la semana, la anterior, las ventanas de 30 y las cohortes de 30 días; la serie larga va aparte.
  const [rows, history, run] = await Promise.all([
    readRows(env.PANEL_DB, addDays(dayOf(now), -120)),
    readActiveHistory(env.PANEL_DB),
    lastRun(env.PANEL_DB),
  ]);
  const view = buildView(rows, history);
  const runText = !run
    ? "El resumen aún no ha corrido."
    : run.ok
      ? `Última corrida: ${new Date(run.ran_at).toISOString().slice(0, 16).replace("T", " ")} UTC, bien${run.note ? ` (${run.note})` : ""}.`
      : `Última corrida FALLÓ el ${new Date(run.ran_at).toISOString().slice(0, 16).replace("T", " ")} UTC: ${run.note ?? "sin motivo"}. Las cifras son las de la corrida anterior.`;
  const html = renderPage(view, { throughDay: run?.through_day ?? null, lastRun: runText, generatedAt: now.toISOString().slice(0, 16).replace("T", " ") + " UTC" });
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", ...SECURITY_HEADERS } });
}

export default {
  fetch: (request: Request, env: Env) => handleFetch(request, env),
  scheduled: (_event: ScheduledController, env: Env, ctx: ExecutionContext) => {
    ctx.waitUntil(
      runDaily(env, { now: new Date() }).then(
        (r) => console.log(`[panel-cron] ok hasta ${r.throughDay} (${r.days} días)${r.note ? ` · ${r.note}` : ""}`),
        (e) => console.log(`[panel-cron] falló: ${String(e).slice(0, 300)}`),
      ),
    );
  },
};
