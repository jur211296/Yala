import { describe, expect, it } from "vitest";
import type { SqlRunner } from "../src/ae";
import { BACKFILL_DAYS, RECOMPUTE_DAYS, runDaily } from "../src/cron";
import type { Env } from "../src/env";
import { handleFetch } from "../src/index";
import { lastRun, readRows } from "../src/store";
import { fakeD1 } from "./fakeD1";

/** Analytics Engine de mentira: responde según el evento que pida la consulta. */
function fakeAE(log: string[]): SqlRunner {
  return async (sql) => {
    log.push(sql);
    if (sql.includes("blob1 = 'ping'")) return [
      { day: "2026-11-05", install: "A", app: "2.1" },
      { day: "2026-11-05", install: "B", app: "2.1" },
      { day: "2026-11-04", install: "A", app: "2.1" },
    ];
    if (sql.includes("blob1 = 'register'")) return [{ day: "2026-11-05", install: "B", kind: "local", mode: "full", n: "1" }];
    return [];
  };
}

const baseEnv = () => ({ PANEL_DB: fakeD1(), ENVIRONMENT: "local", METRICS_DATASET: "yala_metrics", AI_USAGE_DATASET: "yala_ai_usage", ALLOWED_EMAILS: "" }) as unknown as Env;
const now = new Date("2026-11-06T06:00:00Z");

describe("cron diario", () => {
  it("D1 vacía: rellena 85 días hasta AYER; luego solo recalcula 3", async () => {
    const env = baseEnv();
    const log: string[] = [];
    const first = await runDaily(env, { now, runSql: fakeAE(log), fetchCounts: async () => ({ groups_total: 4 }) });
    expect(first).toEqual({ throughDay: "2026-11-05", days: BACKFILL_DAYS, note: null });
    // Desde 37 días antes del primer día recalculado (ventanas de 30 + cohortes de 36), hasta hoy excluido.
    expect(log[0]).toContain("timestamp >= toDateTime('2026-07-07 00:00:00')");
    expect(log[0]).toContain("timestamp < toDateTime('2026-11-06 00:00:00')");
    const second = await runDaily(env, { now, runSql: fakeAE([]), fetchCounts: async () => ({}) });
    expect(second.days).toBe(RECOMPUTE_DAYS);
  });

  it("guarda agregados (sin installs), la foto de la base y la corrida", async () => {
    const env = baseEnv();
    await runDaily(env, { now, runSql: fakeAE([]), fetchCounts: async () => ({ groups_total: 4 }) });
    const rows = await readRows(env.PANEL_DB, "2026-11-01");
    expect(rows.find((r) => r.metric === "active" && r.day === "2026-11-05")?.value).toBe(2);
    expect(rows.find((r) => r.metric === "sb" && r.dim === "groups_total")).toMatchObject({ day: "2026-11-05", value: 4 });
    expect(JSON.stringify(rows)).not.toMatch(/"A"|"B"/);
    expect(await lastRun(env.PANEL_DB)).toMatchObject({ through_day: "2026-11-05", ok: 1, note: null });
  });

  it("recalcular reemplaza el día: un corte que desaparece no se queda vivo", async () => {
    const env = baseEnv();
    await runDaily(env, { now, runSql: fakeAE([]), fetchCounts: async () => ({}) });
    const sinAltas: SqlRunner = async (sql) => (sql.includes("blob1 = 'register'") ? [] : fakeAE([])(sql));
    await runDaily(env, { now, runSql: sinAltas, fetchCounts: async () => ({}) });
    const rows = await readRows(env.PANEL_DB, "2026-11-05");
    expect(rows.some((r) => r.metric === "register")).toBe(false);
  });

  it("si la base falla, el resto se guarda y la corrida lo apunta", async () => {
    const env = baseEnv();
    const r = await runDaily(env, { now, runSql: fakeAE([]), fetchCounts: async () => { throw new Error("supabase 401"); } });
    expect(r.note).toContain("sin conteos de la base");
    expect((await readRows(env.PANEL_DB, "2026-11-05")).some((x) => x.metric === "active")).toBe(true);
  });

  it("si Analytics Engine falla, no escribe nada y la corrida queda como fallida (y la página lo dice)", async () => {
    const env = baseEnv();
    await expect(runDaily(env, { now, runSql: async () => { throw new Error("analytics engine 500"); } })).rejects.toThrow();
    expect(await readRows(env.PANEL_DB, "2026-01-01")).toEqual([]);
    expect(await lastRun(env.PANEL_DB)).toMatchObject({ ok: 0 });
    const html = await (await handleFetch(new Request("https://x/"), env, now)).text();
    expect(html).toContain("Última corrida FALLÓ");
  });

  it("sin el token de Analytics Engine, falla con un motivo legible", async () => {
    const env = baseEnv();
    await expect(runDaily(env, { now })).rejects.toThrow("falta CF_ANALYTICS_TOKEN");
  });
});
