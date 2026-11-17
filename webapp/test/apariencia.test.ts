/**
 * Lote 2 de «Yala web como la app»: el servidor manda el ícono y el color de cuentas, categorías y subcategorías, y la
 * necesidad de cada registro. Ya estaban en la nube; la web los pide con `ToolContext.apariencia`. Las reglas (qué ícono
 * lleva la fila, cuál la cuenta, qué necesidad) se prueban en `mcp/test/apariencia.test.ts`; aquí, que llegan por las
 * rutas de siempre y que la web es la única que pide esas columnas.
 */
import { describe, expect, it } from "vitest";
import { world, type World } from "./fakes";

const ACC = "11111111-1111-4111-8111-111111111111";
const ACC2 = "22222222-2222-4222-8222-222222222222";
const CAT = "33333333-3333-4333-8333-333333333333";
const SUB = "44444444-4444-4444-8444-444444444444";
const SUB_SIN_ICONO = "55555555-5555-4555-8555-555555555555";

function seed(w: World, user: Parameters<World["supabase"]["seed"]>[1]) {
  const now = new Date(w.clock.now * 1000);
  const day = now.toISOString().slice(0, 10);
  const base = { is_archived: false, exclude_from_statistics: false, is_system_account: false, parent_account_id: null };
  w.supabase.seed("accounts", user, [
    { sync_id: ACC, name: "BCP", currency_code: "PEN", type: "Cuenta corriente", icon_name: "building.columns.fill", color_hex: "#22c55e", ...base },
    { sync_id: ACC2, name: "Visa", currency_code: "PEN", type: "Tarjeta de crédito", icon_name: "airplane", color_hex: "url(x)", ...base },
  ]);
  w.supabase.seed("categories", user, [
    { sync_id: CAT, name: "Comida", is_income: false, is_visible: true, sort_order: 1, icon_name: "fork.knife", color_hex: "F59E0B" },
  ]);
  w.supabase.seed("subcategories", user, [
    { sync_id: SUB, name: "Café", category_ref: CAT, nature_raw_value: "opcional", is_visible: true, sort_order: 1, is_system: false, is_default_seed: false, icon_name: "cup.and.saucer.fill", color_hex: null },
    { sync_id: SUB_SIN_ICONO, name: "Mercado", category_ref: CAT, nature_raw_value: "esencial", is_visible: true, sort_order: 2, is_system: false, is_default_seed: false, icon_name: null, color_hex: "#0EA5E9" },
  ]);
  w.supabase.seed("user_preferences", user, [
    { key: "defaultCurrencyCode", value: "PEN" },
    { key: "timeZoneIdentifier", value: "America/Lima" },
  ]);
  const tx = (id: string, sub: string | null, need: string | null, hoursAgo: number) => ({
    sync_id: id,
    date: new Date(now.getTime() - hoursAgo * 3600_000).toISOString(),
    local_day: day,
    amount: -10,
    currency_code: "PEN",
    note: id.slice(-1),
    category_ref: CAT,
    subcategory_ref: sub,
    account_ref: ACC,
    tag_refs: [],
    amount_in_preferred_currency: -10,
    preferred_currency_code: "PEN",
    is_exchange_rate_provisional: false,
    need_override: need,
    scheduled_payment_ref: null,
    balance_adjustment_type: null,
    transfer_pair_id: null,
    split_expense_id: null,
    split_lines_raw: null,
  });
  w.supabase.seed("tx_items", user, [
    tx("aaaaaaaa-0000-4000-8000-000000000001", SUB, null, 1),
    tx("aaaaaaaa-0000-4000-8000-000000000002", SUB_SIN_ICONO, "prioritaria", 2),
    tx("aaaaaaaa-0000-4000-8000-000000000003", null, null, 3),
  ]);
}

async function signedIn() {
  const w = await world();
  const ana = w.supabase.addUser({ email: "ana@yala.test" });
  seed(w, ana);
  await w.socialLogin(ana);
  return w;
}

interface Mov {
  nota: string;
  categoria_id: string | null;
  subcategoria_id: string | null;
  cuenta_id: string | null;
  icono: string | null;
  color: string | null;
  necesidad: string;
}

describe("apariencia: ícono, color y necesidad desde la nube", () => {
  it("cada registro trae el ícono y el color de su fila en la app, sus ids y su necesidad", async () => {
    const w = await signedIn();
    const res = await w.browser.request("/api/registros");
    expect(res.status).toBe(200);
    const { movimientos } = (await res.json()) as { movimientos: Mov[] };
    const by = new Map(movimientos.map((m) => [m.nota, m]));
    // Con subcategoría con ícono: el de la subcategoría, con el color de la CATEGORÍA (normalizado).
    expect(by.get("1")).toMatchObject({ icono: "cup.and.saucer.fill", color: "#F59E0B", necesidad: "opcional", categoria_id: CAT, subcategoria_id: SUB, cuenta_id: ACC });
    // Subcategoría sin ícono: el de la categoría; la necesidad puesta a mano gana a la de la subcategoría.
    expect(by.get("2")).toMatchObject({ icono: "fork.knife", color: "#F59E0B", necesidad: "prioritaria", subcategoria_id: SUB_SIN_ICONO });
    // Sin subcategoría: «sin clasificación», como `effectiveNeed`.
    expect(by.get("3")).toMatchObject({ icono: "fork.knife", necesidad: "sin_clasificacion", subcategoria_id: null });
  });

  it("el Panel trae los mismos campos en los últimos registros y el ícono y color de cada cuenta", async () => {
    const w = await signedIn();
    const body = (await (await w.browser.request("/api/panel")).json()) as {
      cuentas: { cuentas: { id: string; icono: string; color: string | null }[] };
      ultimos: { movimientos: Mov[] };
    };
    const cuentas = new Map(body.cuentas.cuentas.map((c) => [c.id, c]));
    // «building.columns.fill» es el «sin elegir» de la app: manda el tipo. Y el color se normaliza.
    expect(cuentas.get(ACC)).toMatchObject({ icono: "building.columns.fill", color: "#22C55E" });
    // Un color que no es hex no sale.
    expect(cuentas.get(ACC2)).toMatchObject({ icono: "airplane", color: null });
    expect(body.ultimos.movimientos[0]).toMatchObject({ icono: "cup.and.saucer.fill", necesidad: "opcional" });
  });

  it("las categorías y subcategorías traen su ícono y color guardados, sin heredar", async () => {
    const w = await signedIn();
    const { categorias } = (await (await w.browser.request("/api/categorias")).json()) as {
      categorias: { id: string; icono: string | null; color: string | null; subcategorias: { id: string; icono: string | null; color: string | null }[] }[];
    };
    expect(categorias[0]).toMatchObject({ id: CAT, icono: "fork.knife", color: "#F59E0B" });
    expect(categorias[0]!.subcategorias).toEqual([
      expect.objectContaining({ id: SUB, icono: "cup.and.saucer.fill", color: null }),
      expect.objectContaining({ id: SUB_SIN_ICONO, icono: null, color: "#0EA5E9" }),
    ]);
  });

  it("la web pide `icon_name` y `color_hex` de cuentas, categorías y subcategorías", async () => {
    const w = await signedIn();
    w.supabase.calls.length = 0;
    await w.browser.request("/api/registros");
    const reads = w.supabase.calls.filter((c) => /\/rest\/v1\/(accounts|categories|subcategories)$/.test(c.path));
    // Cada tabla se lee por páginas hasta una vacía: dos peticiones por tabla, las tres con las columnas nuevas.
    expect(new Set(reads.map((c) => c.path)).size).toBe(3);
    const selects = reads.map((c) => new URLSearchParams(c.search).get("select") ?? "");
    for (const s of selects) expect(s.split(",")).toEqual(expect.arrayContaining(["icon_name", "color_hex"]));
  });

  it("las direcciones de hoy siguen respondiendo", async () => {
    const w = await signedIn();
    for (const p of ["/api/panel", "/api/registros", "/api/categorias", "/api/presupuestos", "/api/pagos", "/api/estadisticas"]) {
      expect((await w.browser.request(p)).status, p).toBe(200);
    }
  });
});
