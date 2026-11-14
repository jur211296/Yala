/**
 * Lote 2b: Presupuestos, «Ya pagado» en los próximos cobros y las páginas de 200 para exportar a CSV. Las cifras de
 * Presupuestos son las de `estado_presupuestos` (paridad con la app en `mcp/test/golden.test.ts`); aquí, que la ruta las
 * sirve con la sesión de la web, y la regla de «pagado» de la lista del iPhone (`src/worker/paid.ts`).
 *
 * El reloj de las pruebas está en 2027-01-15 08:00 UTC (03:00 en Lima): hoy es el 15 de enero y los próximos 30 días
 * llegan al 13 de febrero.
 */
import { describe, expect, it } from "vitest";
import { world, type World } from "./fakes";
import { paidCharges, chargeKey, type LinkedTx } from "../src/worker/paid";
import { buildCsv, csvEscaped, type CsvRow } from "../src/client/app/csv";
import type { ScheduleRow } from "../../shared-core/src/logic/schedule";

const ACC = "11111111-1111-4111-8111-111111111111";
const CAT = "33333333-3333-4333-8333-333333333333";
const PAY = "55555555-5555-4555-8555-555555555555";
const WEEKLY = "66666666-6666-4666-8666-666666666666";
const TZ = "America/Lima";

function payment(over: Partial<ScheduleRow> & { sync_id: string }): ScheduleRow {
  return {
    name: "Netflix",
    amount: 44.9,
    currency_code: "PEN",
    transaction_type: "expense",
    is_recurring: true,
    recurrence_type: "monthly",
    recurrence_interval: 1,
    next_due_date: "2027-01-20T17:00:00Z",
    end_date: null,
    payment_category: "subscription",
    is_active: true,
    last_paid_date: null,
    subcategory_ref: null,
    account_ref: ACC,
    created_at: "2026-01-01T12:00:00Z",
    day_of_month: 20,
    selected_weekdays: null,
    yearly_month: null,
    yearly_day: null,
    skipped_dates_raw: [],
    ...over,
  } as ScheduleRow;
}

/** Una fila de `scheduled_payments` tal como la siembra el fake de PostgREST. */
function row(p: ScheduleRow): Record<string, unknown> {
  return { ...p };
}

function linked(id: string, day: string): LinkedTx {
  return { scheduled_payment_ref: id, date: `${day}T17:00:00Z`, local_day: null };
}

function tx(id: string, amount: number, over: Record<string, unknown> = {}) {
  return {
    sync_id: id,
    date: "2027-01-10T17:00:00Z",
    local_day: null,
    amount,
    currency_code: "PEN",
    note: null,
    category_ref: CAT,
    subcategory_ref: null,
    account_ref: ACC,
    tag_refs: [],
    amount_in_preferred_currency: amount,
    preferred_currency_code: "PEN",
    is_exchange_rate_provisional: false,
    need_override: null,
    scheduled_payment_ref: null,
    balance_adjustment_type: null,
    transfer_pair_id: null,
    split_expense_id: null,
    split_lines_raw: null,
    ...over,
  };
}

function seedBase(w: World, user: Parameters<World["supabase"]["seed"]>[1]) {
  w.supabase.seed("accounts", user, [
    { sync_id: ACC, name: "BCP", currency_code: "PEN", type: "bank", is_archived: false, exclude_from_statistics: false, is_system_account: false, parent_account_id: null },
  ]);
  w.supabase.seed("categories", user, [{ sync_id: CAT, name: "Comida", is_income: false, is_visible: true, sort_order: 1 }]);
  w.supabase.seed("user_preferences", user, [
    { key: "defaultCurrencyCode", value: "PEN" },
    { key: "timeZoneIdentifier", value: TZ },
  ]);
}

describe("lote 2b: «Ya pagado» con la regla del iPhone", () => {
  // Semanal los lunes: en enero de 2027 cobra los días 4, 11, 18 y 25.
  const weekly = payment({ sync_id: WEEKLY, recurrence_type: "weekly", selected_weekdays: ["2"], day_of_month: null, next_due_date: "2027-01-04T17:00:00Z" });

  it("N movimientos enlazados en el mes pagan las N primeras fechas del mes, aunque una ya pasó", () => {
    const paid = paidCharges([weekly], [linked(WEEKLY, "2027-01-04"), linked(WEEKLY, "2027-01-11"), linked(WEEKLY, "2027-01-14")], ["2027-01-01"], TZ, 2);
    expect([...paid].sort()).toEqual([chargeKey(WEEKLY, "2027-01-04"), chargeKey(WEEKLY, "2027-01-11"), chargeKey(WEEKLY, "2027-01-18")]);
  });

  it("una fecha saltada no gasta ningún pago", () => {
    const skipping = { ...weekly, skipped_dates_raw: ["2027-01-11"] } as ScheduleRow;
    const paid = paidCharges([skipping], [linked(WEEKLY, "2027-01-04"), linked(WEEKLY, "2027-01-12")], ["2027-01-01"], TZ, 2);
    expect([...paid].sort()).toEqual([chargeKey(WEEKLY, "2027-01-04"), chargeKey(WEEKLY, "2027-01-18")]);
  });

  it("dos movimientos del mismo día cuentan dos veces, como en el iPhone; los de otro mes o de otro pago, no", () => {
    const paid = paidCharges(
      [weekly],
      [linked(WEEKLY, "2027-01-04"), linked(WEEKLY, "2027-01-04"), linked(WEEKLY, "2026-12-28"), linked(PAY, "2027-01-05")],
      ["2027-01-01", "2027-02-01"],
      TZ,
      2,
    );
    expect([...paid].sort()).toEqual([chargeKey(WEEKLY, "2027-01-04"), chargeKey(WEEKLY, "2027-01-11")]);
  });

  it("/api/pagos marca el cobro pagado por adelantado y lo saca de «Por pagar»; el pago de un cobro ya pasado no marca el del mes siguiente", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedBase(w, ana);
    const LUZ = "77777777-7777-4777-8777-777777777777";
    w.supabase.seed("scheduled_payments", ana, [
      row(payment({ sync_id: PAY })),
      row(payment({ sync_id: LUZ, name: "Luz", amount: 80, payment_category: "recurring", day_of_month: 8, next_due_date: "2027-02-08T17:00:00Z" })),
    ]);
    w.supabase.seed("tx_items", ana, [
      // Netflix, pagado el 10 de enero, antes de su fecha del 20.
      tx("aaaaaaaa-0000-4000-8000-000000000001", -44.9, { scheduled_payment_ref: PAY }),
      // Luz: el del 8 de enero, pagado ese día. El del 8 de febrero sigue por pagar.
      tx("aaaaaaaa-0000-4000-8000-000000000002", -80, { scheduled_payment_ref: LUZ, date: "2027-01-08T17:00:00Z" }),
    ]);
    await w.socialLogin(ana);
    const res = await w.browser.request("/api/pagos");
    expect(res.status).toBe(200);
    const body = (await res.json()) as { proximos: { nombre: string; dia: string; pagado: boolean }[]; total_gastos: number; pagados: number };
    expect(body.proximos.map((c) => [c.nombre, c.dia, c.pagado])).toEqual([
      ["Netflix", "2027-01-20", true],
      ["Luz", "2027-02-08", false],
    ]);
    expect(body.total_gastos).toBe(80);
    expect(body.pagados).toBe(1);
  });

  it("/api/pagos sin nada pagado deja «Por pagar» como estaba", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedBase(w, ana);
    w.supabase.seed("scheduled_payments", ana, [row(payment({ sync_id: PAY }))]);
    w.supabase.seed("tx_items", ana, [tx("aaaaaaaa-0000-4000-8000-000000000001", -12)]);
    await w.socialLogin(ana);
    const body = (await (await w.browser.request("/api/pagos")).json()) as { proximos: { pagado: boolean }[]; total_gastos: number; pagados: number };
    expect(body.proximos.every((c) => c.pagado === false)).toBe(true);
    expect(body.total_gastos).toBe(44.9);
    expect(body.pagados).toBe(0);
  });
});

describe("lote 2b: Presupuestos", () => {
  it("todos los presupuestos, activos e inactivos, con las cifras del núcleo", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedBase(w, ana);
    const budget = (id: string, name: string, limit: number, active: boolean) => ({
      sync_id: id,
      name,
      currency_code: "PEN",
      limit_amount: limit,
      period_type: "monthly",
      start_date: null,
      end_date: null,
      natures: [],
      subcategory_ids: [],
      account_ids: [],
      tag_refs: [],
      is_active: active,
      include_shared_expenses: true,
    });
    w.supabase.seed("budgets", ana, [
      budget("bbbbbbbb-0000-4000-8000-000000000001", "Comida", 50, true),
      budget("bbbbbbbb-0000-4000-8000-000000000002", "Viajes", 100, false),
    ]);
    w.supabase.seed("tx_items", ana, [tx("aaaaaaaa-0000-4000-8000-000000000001", -40)]);
    await w.socialLogin(ana);
    const res = await w.browser.request("/api/presupuestos");
    expect(res.status).toBe(200);
    const body = (await res.json()) as { presupuestos: { nombre: string; gastado: number; porcentaje: number; estado: string; activo: boolean; periodo: { desde: string; hasta: string } }[] };
    expect(body.presupuestos).toEqual([
      expect.objectContaining({ nombre: "Comida", gastado: 40, porcentaje: 80, estado: "en_riesgo", activo: true, periodo: expect.objectContaining({ desde: "2027-01-01", hasta: "2027-01-31" }) }),
      expect.objectContaining({ nombre: "Viajes", estado: "inactivo", activo: false }),
    ]);
  });

  it("sin sesión, 401; una cuenta «solo Grupos», 409", async () => {
    const w = await world();
    expect((await w.browser.request("/api/presupuestos")).status).toBe(401);
    const beto = w.supabase.addUser({ email: "beto@yala.test", kind: "groups_only" });
    await w.socialLogin(beto);
    const res = await w.browser.request("/api/presupuestos");
    expect(res.status).toBe(409);
    expect(await res.json()).toEqual({ error: "solo_grupos" });
  });
});

describe("lote 2b: exportar a CSV", () => {
  it("Registros da páginas de 200 si se piden; cualquier otro tamaño se queda en 50", async () => {
    const w = await world();
    const ana = w.supabase.addUser({ email: "ana@yala.test" });
    seedBase(w, ana);
    await w.socialLogin(ana);
    const limits = async (q: string) => {
      w.supabase.calls.length = 0;
      expect((await w.browser.request(`/api/registros${q}`)).status).toBe(200);
      return w.supabase.calls.filter((c) => c.path === "/rest/v1/tx_items").map((c) => new URLSearchParams(c.search).get("limit"));
    };
    expect(await limits("?limite=200")).toEqual(["201"]);
    expect(await limits("?limite=5000")).toEqual(["51"]);
    expect(await limits("")).toEqual(["51"]);
  });

  const mov = (over: Partial<CsvRow>): CsvRow => ({
    fecha: "2027-01-10",
    importe: -12.5,
    divisa: "PEN",
    nota: null,
    categoria: "Comida",
    subcategoria: null,
    cuenta: "BCP",
    etiquetas: [],
    ...over,
  });

  it("el archivo es el del iPhone: BOM, cabeceras de la app, punto decimal y etiquetas con «;»", () => {
    const csv = buildCsv([
      mov({ nota: 'Café "La Plaza", Miraflores', etiquetas: ["trabajo", "viaje"], subcategoria: "Cafetería" }),
      mov({ importe: 1200, categoria: null, cuenta: null, nota: "Sueldo\nnoviembre", divisa: "usd" }),
      mov({ importe: -0.001 }),
    ]);
    expect(csv.startsWith("﻿")).toBe(true);
    const lines = csv.slice(1).split("\n");
    expect(lines[0]).toBe("date,amount,currency,account,category,subcategory,tags,note");
    expect(lines[1]).toBe('2027-01-10,-12.50,PEN,BCP,Comida,Cafetería,trabajo;viaje,"Café ""La Plaza"", Miraflores"');
    expect(lines[2]).toBe('2027-01-10,1200.00,USD,,,,,"Sueldo');
    expect(lines[3]).toBe('noviembre"');
    expect(lines[4]).toBe("2027-01-10,0.00,PEN,BCP,Comida,,,");
  });

  it("las comillas, como `csvEscaped` de la app", () => {
    expect(csvEscaped("")).toBe("");
    expect(csvEscaped("simple")).toBe("simple");
    expect(csvEscaped('dice "hola"')).toBe('"dice ""hola"""');
    expect(csvEscaped("a,b")).toBe('"a,b"');
    expect(csvEscaped("=SUMA(A1)")).toBe("=SUMA(A1)");
  });
});
