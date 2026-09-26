/**
 * Las seis herramientas contra datos REALES de staging, sin pasar por OAuth.
 *
 * Nació cuando el servidor OAuth de staging aún estaba apagado, y se queda porque aísla la otra mitad: ejercita
 * todo lo que va por debajo del verificador, sin depender del baile OAuth: las consultas a PostgREST (filtros, `and=(or(…))`, cursor, `ilike`), los cálculos y el aislamiento
 * por RLS, con la sesión normal de A y de B (role = authenticated).
 *
 * Lo que NO prueba: el rol yala_mcp_reader en un token real ni el baile OAuth. Eso es oauth.e2e.test.ts.
 *
 *   set -a; . ~/Secrets/yala-supabase-test/test-users.env; set +a
 *   npm run test:e2e -- tools
 */
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { YalaReader } from "../../src/data";
import type { Env } from "../../src/env";
import { TOOLS } from "../../src/tools";

const ENV: Env = {
  ENVIRONMENT: "staging",
  SUPABASE_URL: "https://fostjbbwstyuunmmefuk.supabase.co",
  SUPABASE_ANON_KEY:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZvc3RqYmJ3c3R5dXVubW1lZnVrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0NTAxNTMsImV4cCI6MjA5OTAyNjE1M30.gTWg5a8NKNuL_RhOmaaSGhnJpdV6iMXhwYwZVJb-FKg",
  DEFAULT_TIMEZONE: "America/Lima",
};

const A = { email: process.env.USER_A_EMAIL ?? "", pass: process.env.USER_A_PASS ?? "" };
const B = { email: process.env.USER_B_EMAIL ?? "", pass: process.env.USER_B_PASS ?? "" };

async function login(user: { email: string; pass: string }): Promise<string> {
  const res = await fetch(`${ENV.SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: ENV.SUPABASE_ANON_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.pass }),
  });
  const body = (await res.json()) as { access_token?: string };
  expect(res.status, JSON.stringify(body)).toBe(200);
  return body.access_token!;
}

async function logout(token: string) {
  await fetch(`${ENV.SUPABASE_URL}/auth/v1/logout?scope=local`, {
    method: "POST",
    headers: { apikey: ENV.SUPABASE_ANON_KEY, Authorization: `Bearer ${token}` },
  });
}

function run(token: string, name: string, args: Record<string, unknown> = {}): Promise<any> {
  const def = TOOLS.find((t) => t.name === name)!;
  return def.run({ reader: new YalaReader(ENV, token), env: ENV, now: new Date() }, args);
}

describe.skipIf(!A.pass || !B.pass)("herramientas contra staging (sesión normal, sin OAuth)", () => {
  let ta: string;
  let tb: string;
  const timings: Record<string, number> = {};

  beforeAll(async () => {
    [ta, tb] = await Promise.all([login(A), login(B)]);
  });
  afterAll(async () => {
    console.log("MEDIDA latencias (ms):", JSON.stringify(timings));
    await Promise.all([logout(ta), logout(tb)]);
  });

  async function timed(name: string, token: string, args: Record<string, unknown> = {}) {
    const t = Date.now();
    const r = await run(token, name, args);
    timings[`${name}`] = Date.now() - t;
    return r;
  }

  it("listar_cuentas de A: cuentas con saldo y total", async () => {
    const r = await timed("listar_cuentas", ta);
    expect(r.cuentas.length).toBeGreaterThan(0);
    expect(typeof r.total.importe).toBe("number");
    console.log("MEDIDA listar_cuentas A:", JSON.stringify({ cuentas: r.cuentas.length, total: r.total, avisos: r.avisos }));
  });

  it("listar_categorias de A", async () => {
    const r = await timed("listar_categorias", ta, { incluir_ocultas: true });
    expect(r.total).toBeGreaterThan(0);
  });

  it("buscar_movimientos de A pagina con cursor sin repetir ni saltar", async () => {
    const p1 = await timed("buscar_movimientos", ta, { limite: 25 });
    expect(p1.movimientos).toHaveLength(25);
    expect(p1.siguiente_cursor).toBeTruthy();
    const p2 = await run(ta, "buscar_movimientos", { limite: 25, cursor: p1.siguiente_cursor });
    const ids1 = new Set(p1.movimientos.map((m: any) => m.id));
    for (const m of p2.movimientos) expect(ids1.has(m.id)).toBe(false);
    const both = await run(ta, "buscar_movimientos", { limite: 50 });
    expect(both.movimientos.map((m: any) => m.id)).toEqual([...p1.movimientos, ...p2.movimientos].map((m: any) => m.id));
  });

  it("buscar_movimientos con texto, fechas y un nombre que no existe", async () => {
    const r = await run(ta, "buscar_movimientos", { texto: "cafe", desde: "2026-01-01", hasta: "2026-12-31", limite: 10 });
    for (const m of r.movimientos) expect(String(m.nota).toLowerCase()).toContain("cafe");
    const none = await run(ta, "buscar_movimientos", { cuenta: "cuenta-que-no-existe-xyz" });
    expect(none.movimientos).toEqual([]);
    expect(none.avisos[0]).toMatch(/No hay ninguna cuenta/);
  });

  it("buscar_movimientos por categoría usa and=(or(…)) sin romper PostgREST", async () => {
    const cats = await run(ta, "listar_categorias", { incluir_ocultas: true });
    const name = cats.categorias[0].nombre as string;
    const r = await run(ta, "buscar_movimientos", { categoria: name, limite: 5 });
    expect(Array.isArray(r.movimientos)).toBe(true);
  });

  it("resumen_periodo, estado_presupuestos y listar_recurrentes de A", async () => {
    const resumen = await timed("resumen_periodo", ta, { periodo: "rango", desde: "2025-01-01", hasta: "2026-09-26" });
    const mes = await run(ta, "resumen_periodo", { periodo: "mes_actual" });
    const presupuestos = await timed("estado_presupuestos", ta);
    const recurrentes = await timed("listar_recurrentes", ta);
    expect(resumen.periodo.desde).toBe("2025-01-01");
    expect(Array.isArray(presupuestos.presupuestos)).toBe(true);
    expect(Array.isArray(recurrentes.pagos)).toBe(true);
    console.log(
      "MEDIDA A:",
      JSON.stringify({
        resumen_rango: { ingresos: resumen.ingresos, gastos: resumen.gastos, movimientos: resumen.movimientos, avisos: resumen.avisos },
        mes_actual: { movimientos: mes.movimientos },
        presupuestos: presupuestos.presupuestos.length,
        en_riesgo_o_excedidos: presupuestos.presupuestos.filter((p: any) => ["en_riesgo", "excedido"].includes(p.estado)).length,
        recurrentes: recurrentes.pagos.length,
        a_revisar: recurrentes.a_revisar,
        totales: recurrentes.totales_gasto,
      }),
    );
  });

  it("aislamiento: B no ve ninguna cuenta ni movimiento de A", async () => {
    const aCuentas = new Set((await run(ta, "listar_cuentas", { incluir_archivadas: true })).cuentas.map((c: any) => c.id));
    const aMovs = new Set((await run(ta, "buscar_movimientos", { limite: 200 })).movimientos.map((m: any) => m.id));
    const bCuentas = await run(tb, "listar_cuentas", { incluir_archivadas: true });
    const bMovs = await run(tb, "buscar_movimientos", { limite: 200 });
    for (const c of bCuentas.cuentas) expect(aCuentas.has(c.id)).toBe(false);
    for (const m of bMovs.movimientos) expect(aMovs.has(m.id)).toBe(false);
    expect(aCuentas.size).toBeGreaterThan(0);
    console.log("MEDIDA B:", JSON.stringify({ cuentas: bCuentas.cuentas.length, movimientos: bMovs.movimientos.length }));
  });
});
