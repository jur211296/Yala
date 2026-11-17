/**
 * Lote 2 de «Yala web como la app»: `ToolContext.apariencia` (solo Yala web) añade ícono, color y necesidad a tres
 * herramientas del núcleo compartido. Aquí se prueba:
 * - que las reglas son las de la app (`RecordRowView.subcategoryIcon`, `displayIconName(for:)`, `effectiveNeed`);
 * - que con `apariencia` las seis herramientas devuelven LO MISMO más los campos nuevos, y piden lo mismo más las dos
 *   columnas: la web ve las cifras del conector. Sin `apariencia`, la paridad byte a byte la fija
 *   `shared-core-parity.test.ts`, que no cambia.
 */
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import goldenJson from "./golden/app-parity.json";
import { TOOL_CORES, accountIcon, effectiveNeed, hexColor, sfSymbol, type ToolContext } from "../../shared-core/src/toolCore";
import { YalaReader, type Fetcher } from "../../shared-core/src/data";
import type { AccountRow, SubcategoryRow } from "../../shared-core/src/logic/types";

interface Scenario {
  id: string;
  now: string;
  rows: Record<string, unknown[]>;
}
const scenarios = (goldenJson as unknown as { scenarios: Scenario[] }).scenarios;

const ENV = { SUPABASE_URL: "https://paridad.supabase.co", SUPABASE_ANON_KEY: "anon", DEFAULT_TIMEZONE: "America/Lima" };

const sub = (nature: string | null): SubcategoryRow => ({
  sync_id: "s",
  name: "S",
  category_ref: "c",
  nature_raw_value: nature,
  is_visible: true,
  sort_order: 0,
});

const account = (type: string | null, icon: string | null): AccountRow & { icon_name: string | null } => ({
  sync_id: "a",
  name: "A",
  currency_code: "PEN",
  type,
  is_archived: false,
  exclude_from_statistics: false,
  is_system_account: false,
  icon_name: icon,
});

describe("reglas de la app", () => {
  it("necesidad = `effectiveNeed`: la puesta a mano gana; si no, la de la subcategoría; lo desconocido, sin clasificar", () => {
    expect(effectiveNeed(null, sub("esencial"))).toBe("esencial");
    expect(effectiveNeed("opcional", sub("esencial"))).toBe("opcional");
    expect(effectiveNeed(null, undefined)).toBe("sin_clasificacion");
    expect(effectiveNeed("prioritaria", undefined)).toBe("prioritaria");
    // Una puesta a mano que la app no reconoce NO cae a la subcategoría: `SubcategoryNeed(rawValue:) ?? .unclassified`.
    expect(effectiveNeed("urgente", sub("esencial"))).toBe("sin_clasificacion");
    expect(effectiveNeed(null, sub("optional"))).toBe("sin_clasificacion");
  });

  it("ícono de cuenta = `displayIconName`: el suyo; el banco por defecto cede al del tipo; sin tipo conocido, el banco", () => {
    expect(accountIcon(account("Efectivo", "airplane"))).toBe("airplane");
    expect(accountIcon(account("Efectivo", "building.columns.fill"))).toBe("banknote.fill");
    expect(accountIcon(account("Tarjeta de crédito", null))).toBe("creditcard.fill");
    expect(accountIcon(account("Cuenta de ahorros", ""))).toBe("banknote");
    expect(accountIcon(account("General", null))).toBe("creditcard");
    expect(accountIcon(account("checking", null))).toBe("building.columns.fill");
    expect(accountIcon(account(null, "no válido!"))).toBe("building.columns.fill");
  });

  it("color: solo hex de 6 cifras, normalizado a «#RRGGBB»", () => {
    expect(hexColor("#22c55e")).toBe("#22C55E");
    expect(hexColor("F59E0B")).toBe("#F59E0B");
    expect(hexColor(" #6366F1 ")).toBe("#6366F1");
    for (const bad of [null, undefined, "", "#FFF", "#6366F1FF", "red", "url(x)", 12]) expect(hexColor(bad)).toBeNull();
  });

  it("ícono: solo la forma de un SF Symbol", () => {
    expect(sfSymbol("cart.fill")).toBe("cart.fill");
    expect(sfSymbol("takeoutbag.and.cup.and.straw.fill")).toBe("takeoutbag.and.cup.and.straw.fill");
    for (const bad of [null, "", "Cart", "cart..fill", "<svg>", "a b", "x".repeat(81)]) expect(sfSymbol(bad)).toBeNull();
  });
});

/** PostgREST falso: la tabla entera, con ícono y color añadidos a lo que haya, y el registro de lo pedido. */
function fakeRest(rows: Record<string, unknown[]>, log: string[]): Fetcher {
  return async (input) => {
    const url = new URL(input instanceof Request ? input.url : String(input));
    const table = url.pathname.replace("/rest/v1/", "");
    const params = [...url.searchParams.entries()].filter(([k]) => k !== "offset" && k !== "limit");
    const offset = Number(url.searchParams.get("offset") ?? 0);
    const limit = Number(url.searchParams.get("limit") ?? 1000);
    log.push(`${table}?${new URLSearchParams(params).toString()}`);
    const look = ["accounts", "categories", "subcategories"].includes(table);
    const all = table === "user_preferences" ? [{ key: "defaultCurrencyCode", value: "PEN" }] : (rows[table] ?? []);
    const withLook = look ? all.map((r) => ({ icon_name: "cart.fill", color_hex: "#22c55e", ...(r as object) })) : all;
    return Response.json(withLook.slice(offset, offset + limit));
  };
}

const CALLS: Record<string, Record<string, unknown>[]> = {
  listar_cuentas: [{}, { incluir_archivadas: true }],
  listar_categorias: [{}, { incluir_ocultas: true }],
  buscar_movimientos: [{}, { limite: 3 }],
  resumen_periodo: [{ periodo: "mes_actual" }, { periodo: "anio_actual" }],
  estado_presupuestos: [{ solo_activos: false }],
  listar_recurrentes: [{ solo_activos: false }],
};

const ADDED = {
  cuenta: ["icono", "color"],
  categoria: ["icono", "color"],
  movimiento: ["categoria_id", "subcategoria_id", "cuenta_id", "icono", "color", "necesidad"],
};

/** Quita lo que añade `apariencia`, para comparar con la respuesta del conector. */
function strip(name: string, result: unknown): unknown {
  const omit = (o: Record<string, unknown>, keys: string[]) => Object.fromEntries(Object.entries(o).filter(([k]) => !keys.includes(k)));
  const r = result as Record<string, unknown>;
  if (name === "listar_cuentas" && Array.isArray(r.cuentas)) return { ...r, cuentas: r.cuentas.map((c) => omit(c, ADDED.cuenta)) };
  if (name === "listar_categorias" && Array.isArray(r.categorias)) {
    return {
      ...r,
      categorias: r.categorias.map((c) => {
        const cat = omit(c, ADDED.categoria) as { subcategorias: Record<string, unknown>[] };
        return { ...cat, subcategorias: cat.subcategorias.map((s) => omit(s, ADDED.categoria)) };
      }),
    };
  }
  if (name === "buscar_movimientos" && Array.isArray(r.movimientos)) return { ...r, movimientos: r.movimientos.map((m) => omit(m, ADDED.movimiento)) };
  return result;
}

async function run(apariencia: boolean, s: Scenario, name: string, args: Record<string, unknown>) {
  const core = TOOL_CORES.find((c) => c.name === name)!;
  const log: string[] = [];
  const ctx: ToolContext = { reader: new YalaReader(ENV, "token", fakeRest(s.rows, log)), env: ENV, now: new Date(s.now), ...(apariencia ? { apariencia } : {}) };
  let result: unknown;
  try {
    result = await core.run(ctx, args);
  } catch (err) {
    result = { lanzo: String(err) };
  }
  return { log, result };
}

describe("con `apariencia`, lo mismo que el conector más los campos nuevos", () => {
  beforeAll(() => vi.useFakeTimers({ toFake: ["Date"] }));
  afterAll(() => vi.useRealTimers());

  it("en las seis herramientas y todos los escenarios del golden de la app", async () => {
    expect(scenarios.length).toBeGreaterThanOrEqual(3);
    let added = 0;
    for (const s of scenarios) {
      vi.setSystemTime(new Date(s.now));
      for (const [name, calls] of Object.entries(CALLS)) {
        for (const args of calls) {
          const plain = await run(false, s, name, args);
          const web = await run(true, s, name, args);
          const label = `${s.id} · ${name} · ${JSON.stringify(args)}`;
          expect(strip(name, web.result), label).toEqual(plain.result);
          // Las consultas: las mismas, salvo las dos columnas en las tres tablas de referencia.
          expect(web.log.map((q) => q.replace(/%2Cicon_name%2Ccolor_hex/, "")), label).toEqual(plain.log);
          expect(plain.log.some((q) => q.includes("icon_name")), label).toBe(false);
          if (JSON.stringify(web.result) !== JSON.stringify(plain.result)) added++;
        }
      }
    }
    expect(added).toBeGreaterThan(0); // control: los campos nuevos de verdad salen en algún caso
  });

  it("la fila de un registro: ícono de la subcategoría, si no de la categoría; color de la categoría", async () => {
    const CAT = "c0000000-0000-4000-8000-000000000001";
    const SUB_A = "c0000000-0000-4000-8000-000000000002";
    const SUB_B = "c0000000-0000-4000-8000-000000000003";
    const rows: Record<string, unknown[]> = {
      accounts: [],
      categories: [{ sync_id: CAT, name: "Comida", is_income: false, is_visible: true, sort_order: 0, icon_name: "fork.knife", color_hex: "#f59e0b" }],
      subcategories: [
        { sync_id: SUB_A, name: "Café", category_ref: CAT, nature_raw_value: "opcional", is_visible: true, sort_order: 0, icon_name: "mug.fill", color_hex: "#000000" },
        { sync_id: SUB_B, name: "Mercado", category_ref: CAT, nature_raw_value: "esencial", is_visible: true, sort_order: 1, icon_name: null, color_hex: null },
      ],
      tags: [],
      tx_items: [
        { sync_id: "d0000000-0000-4000-8000-000000000002", date: "2026-11-10T12:00:00Z", local_day: "2026-11-10", amount: -5, currency_code: "PEN", note: "a", category_ref: CAT, subcategory_ref: SUB_A, account_ref: null, tag_refs: [], need_override: null, split_expense_id: null, balance_adjustment_type: null },
        { sync_id: "d0000000-0000-4000-8000-000000000001", date: "2026-11-09T12:00:00Z", local_day: "2026-11-09", amount: -5, currency_code: "PEN", note: "b", category_ref: CAT, subcategory_ref: SUB_B, account_ref: null, tag_refs: [], need_override: null, split_expense_id: null, balance_adjustment_type: null },
        { sync_id: "d0000000-0000-4000-8000-000000000000", date: "2026-11-08T12:00:00Z", local_day: "2026-11-08", amount: -5, currency_code: "PEN", note: "c", category_ref: null, subcategory_ref: null, account_ref: null, tag_refs: [], need_override: null, split_expense_id: null, balance_adjustment_type: null },
      ],
    };
    // Sin el `fakeRest` de arriba, que rellena ícono y color: aquí las filas dicen exactamente lo que hay.
    const fetcher: Fetcher = async (input) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      const table = url.pathname.replace("/rest/v1/", "");
      const offset = Number(url.searchParams.get("offset") ?? 0);
      const all = table === "user_preferences" ? [] : (rows[table] ?? []);
      return Response.json(offset > 0 ? [] : all);
    };
    const ctx: ToolContext = { reader: new YalaReader(ENV, "t", fetcher), env: ENV, now: new Date("2026-11-16T15:00:00Z"), apariencia: true };
    const core = TOOL_CORES.find((c) => c.name === "buscar_movimientos")!;
    const { movimientos } = (await core.run(ctx, {})) as { movimientos: Record<string, unknown>[] };
    expect(movimientos.map((m) => [m.nota, m.icono, m.color, m.necesidad])).toEqual([
      ["a", "mug.fill", "#F59E0B", "opcional"],
      ["b", "fork.knife", "#F59E0B", "esencial"],
      ["c", null, null, "sin_clasificacion"],
    ]);
  });
});
