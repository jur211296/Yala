import { describe, expect, it } from "vitest";
import { computeBalances } from "../src/logic/balances";
import { budgetStatuses } from "../src/logic/budgets";
import { convert, latestRateTable } from "../src/logic/fx";
import { buildLookup } from "../src/logic/lookup";
import { canonicalMerchant } from "../src/logic/merchant";
import { listRecurring, monthlyMultiplier } from "../src/logic/recurring";
import { summarize } from "../src/logic/summary";
import { resolvePeriod } from "../src/logic/dates";
import { account, budget, category, scheduled, subcategory, tag, tx, uuid } from "./fixtures";

const RATES = latestRateTable([
  { date_key: "2026-09-01", base: "USD", rates: { PEN: "3.50", EUR: "0.90" } },
  { date_key: "2026-09-09", base: "USD", rates: { PEN: "3.40", EUR: "0.85" } },
]);

describe("divisas", () => {
  it("usa la fila más reciente y convierte pasando por la base", () => {
    expect(RATES?.dateKey).toBe("2026-09-09");
    expect(convert(34, "PEN", "USD", RATES)).toBeCloseTo(10);
    expect(convert(-10, "USD", "PEN", RATES)).toBeCloseTo(-34);
    expect(convert(8.5, "EUR", "PEN", RATES)).toBeCloseTo(34);
    expect(convert(5, "PEN", "PEN", null)).toBe(5);
    expect(convert(5, "JPY", "PEN", RATES)).toBeNull();
  });
});

describe("comercio canónico (port de MerchantCanonicalizer)", () => {
  it("quita prefijos de pasarela, símbolos y espacios de más, y conserva la Ñ", () => {
    expect(canonicalMerchant("DP*Starbucks Coffee #123")).toBe("STARBUCKS COFFEE 123");
    expect(canonicalMerchant("  Panadería   Ñuñoa ")).toBe("PANADERÍA ÑUÑOA");
    expect(canonicalMerchant("***")).toBeNull();
    expect(canonicalMerchant(null)).toBeNull();
  });
});

describe("saldos", () => {
  const pen = uuid(1001);
  const usd = uuid(1002);
  const archived = uuid(1003);
  const excluded = uuid(1004);
  const accounts = [
    account({ sync_id: pen, name: "BCP", currency_code: "PEN" }),
    account({ sync_id: usd, name: "Ahorro USD", currency_code: "USD" }),
    account({ sync_id: archived, name: "Vieja", is_archived: true }),
    account({ sync_id: excluded, name: "Préstamo", exclude_from_statistics: true }),
  ];
  const txs = [
    { account_ref: pen, amount: 1000, currency_code: "PEN" }, // saldo inicial
    { account_ref: pen, amount: -150.5, currency_code: "PEN" },
    { account_ref: usd, amount: 100, currency_code: "USD" },
    { account_ref: archived, amount: 50, currency_code: "PEN" },
    { account_ref: excluded, amount: -999, currency_code: "PEN" },
    { account_ref: pen, amount: null, currency_code: "PEN" }, // fila a medias: no cuenta
  ];

  it("el saldo de cada cuenta es la suma de sus movimientos en su divisa", () => {
    const r = computeBalances(accounts, txs, "PEN", RATES, { incluirArchivadas: true });
    const byName = Object.fromEntries(r.cuentas.map((c) => [c.nombre, c.saldo]));
    expect(byName).toEqual({ BCP: 849.5, "Ahorro USD": 100, Vieja: 50, Préstamo: -999 });
  });

  it("el total deja fuera archivadas y excluidas, y convierte cada divisa con la tasa más reciente", () => {
    const r = computeBalances(accounts, txs, "PEN", RATES, { incluirArchivadas: false });
    expect(r.total.importe).toBeCloseTo(849.5 + 340);
    expect(r.total.aproximado).toBe(true);
    expect(r.cuentas.map((c) => c.nombre)).not.toContain("Vieja");
  });

  it("una divisa sin tasa no se suma y se declara", () => {
    const r = computeBalances(accounts, [...txs, { account_ref: pen, amount: 7, currency_code: "JPY" }], "PEN", RATES, {
      incluirArchivadas: false,
    });
    expect(r.total.sin_convertir).toEqual([{ divisa: "JPY", importe: 7 }]);
  });
});

describe("resumen de periodo (port de CashFlowCalculator)", () => {
  const acc = uuid(2001);
  const excludedAcc = uuid(2002);
  const food = uuid(2101);
  const salary = uuid(2102);
  const lookup = buildLookup({
    accounts: [account({ sync_id: acc }), account({ sync_id: excludedAcc, exclude_from_statistics: true })],
    categories: [category({ sync_id: food, name: "Comida" }), category({ sync_id: salary, name: "Sueldo", is_income: true })],
  });
  const period = resolvePeriod("mes_actual", "2026-09-26");
  const ctx = { today: "2026-09-26", tz: "America/Lima", preferredCurrency: "PEN", rates: RATES, top: 5 };
  const base = { account_ref: acc, preferred_currency_code: "PEN" };

  const txs = [
    tx({ ...base, category_ref: salary, amount: 3000, amount_in_preferred_currency: 3000, note: "Planilla" }),
    tx({ ...base, category_ref: food, amount: -100, amount_in_preferred_currency: -100, note: "DP*Tambo" }),
    tx({ ...base, category_ref: food, amount: -50, amount_in_preferred_currency: -50, note: "Tambo" }),
    // Reembolso: gasto positivo, RESTA del gasto (acumulación con signo, no abs).
    tx({ ...base, category_ref: food, amount: 20, amount_in_preferred_currency: 20, note: "Devolución" }),
    // Fuera: ajuste de saldo, cuenta excluida, futuro, sin categoría, transferencia, fila a medias.
    tx({ ...base, category_ref: food, amount: -999, amount_in_preferred_currency: -999, balance_adjustment_type: "initial_balance" }),
    tx({ ...base, account_ref: excludedAcc, category_ref: food, amount: -999, amount_in_preferred_currency: -999 }),
    tx({ ...base, category_ref: food, date: "2026-09-28T15:00:00Z", amount: -999, amount_in_preferred_currency: -999 }),
    tx({ ...base, amount: -30 }),
    tx({ ...base, amount: -500, transfer_pair_id: "t1" }),
    tx({ ...base, category_ref: food, amount: null }),
    // Del mes anterior, aunque `date` UTC caiga en septiembre: local_day manda.
    tx({ ...base, category_ref: food, date: "2026-09-01T02:00:00Z", local_day: "2026-08-31", amount: -999, amount_in_preferred_currency: -999 }),
    // Otra divisa guardada con otra preferida: se reconvierte con la tasa más reciente → aproximado.
    tx({ ...base, category_ref: food, currency_code: "USD", amount: -10, amount_in_preferred_currency: -10, preferred_currency_code: "USD" }),
  ];

  it("clasifica por categoría, acumula con signo y aplica el filtro de elegibilidad del chat", () => {
    const r = summarize(txs, lookup, period, ctx);
    expect(r.ingresos).toBe(3000);
    expect(r.gastos).toBeCloseTo(100 + 50 - 20 + 34);
    expect(r.neto).toBeCloseTo(3000 - 164);
    expect(r.movimientos).toBe(5);
    expect(r.sin_categoria).toEqual({ movimientos: 1, importe_absoluto: 30 });
    expect(r.aproximado).toBe(true);
    // Periodo en curso: el día de hoy no cuenta en el denominador, como `DateIntervalDayCount` hasta `now`.
    expect(r.gasto_medio_diario).toBeCloseTo(164 / 25, 2);
    // Periodo cerrado: cuentan todos sus días.
    const agosto = summarize(
      [tx({ ...base, category_ref: food, date: "2026-08-10T15:00:00Z", amount: -310, amount_in_preferred_currency: -310 })],
      lookup,
      resolvePeriod("mes_pasado", "2026-09-26"),
      ctx,
    );
    expect(agosto.gasto_medio_diario).toBe(10);
  });

  it("agrupa comercios por nota canónica y ordena el top por gasto", () => {
    const r = summarize(txs, lookup, period, ctx);
    expect(r.top_comercios_gasto[0]).toEqual({ comercio: "TAMBO", importe: 150, movimientos: 2 });
    expect(r.top_categorias_gasto[0]?.categoria).toBe("Comida");
  });

  it("avisa de los gastos de grupo, que la v0 no ajusta a «tu parte»", () => {
    const r = summarize([tx({ ...base, category_ref: food, amount: -300, amount_in_preferred_currency: -300, split_expense_id: "s1" })], lookup, period, ctx);
    expect(r.gastos).toBe(300);
    expect(r.avisos.join(" ")).toMatch(/gastos de grupo/);
  });
});

describe("presupuestos (port de BudgetsViewModel.calculateSpending)", () => {
  const acc1 = uuid(3001);
  const acc2 = uuid(3002);
  const food = uuid(3101);
  const salary = uuid(3102);
  const super_ = uuid(3201);
  const cinema = uuid(3202);
  const trip = uuid(3301);
  const lookup = buildLookup({
    accounts: [account({ sync_id: acc1 }), account({ sync_id: acc2 })],
    categories: [category({ sync_id: food, name: "Comida" }), category({ sync_id: salary, is_income: true })],
    subcategories: [
      subcategory({ sync_id: super_, category_ref: food, nature_raw_value: "esencial" }),
      subcategory({ sync_id: cinema, category_ref: food, nature_raw_value: "opcional" }),
    ],
    tags: [tag({ sync_id: trip, name: "viaje" })],
  });
  const ctx = { today: "2026-09-26", tz: "America/Lima", rates: RATES, firstWeekday: 2 as const, soloActivos: true };
  const e = (p: Parameters<typeof tx>[0]) => tx({ account_ref: acc1, category_ref: food, subcategory_ref: super_, ...p });

  const txs = [
    e({ amount: -40 }),
    e({ amount: -60, subcategory_ref: cinema }),
    e({ amount: -25, account_ref: acc2, tag_refs: [trip] }),
    e({ amount: -10, split_expense_id: "g1" }),
    e({ amount: 500, category_ref: salary }), // ingreso: nunca cuenta
    e({ amount: -999, date: "2026-08-31T15:00:00Z" }), // mes anterior
    e({ amount: -999, date: "2026-10-01T05:00:00Z" }), // 1 de octubre en Lima: ni futuro ni de septiembre
    e({ amount: -10, currency_code: "USD" }), // 34 PEN con la tasa más reciente
  ];

  it("sin filtros suma el valor absoluto de todos los gastos del periodo", () => {
    const r = budgetStatuses([budget({ sync_id: uuid(), limit_amount: 200 })], txs, lookup, ctx);
    const b = r.presupuestos[0]!;
    expect(b.gastado).toBeCloseTo(40 + 60 + 25 + 10 + 34);
    expect(b.periodo).toEqual({ tipo: "mensual", desde: "2026-09-01", hasta: "2026-09-30" });
    expect(b.dias_restantes).toBe(4);
    expect(b.estado).toBe("en_riesgo");
    // La tasa salió de la fila más reciente: igual que la app, no se marca aproximado.
    expect(b.aproximado).toBe(false);
  });

  it("una tasa que falta en la fila más reciente se toma de la anterior y marca aproximado", () => {
    const rates = latestRateTable([
      { date_key: "2026-09-09", base: "USD", rates: { PEN: "3.40" } },
      { date_key: "2026-09-01", base: "USD", rates: { PEN: "3.50", EUR: "0.85" } },
    ]);
    expect(rates?.filledFromOlder.has("EUR")).toBe(true);
    const r = budgetStatuses(
      [budget({ sync_id: uuid(3450) })],
      [e({ amount: -8.5, currency_code: "EUR" })],
      lookup,
      { ...ctx, rates },
    ).presupuestos[0]!;
    expect(r.gastado).toBeCloseTo(34);
    expect(r.aproximado).toBe(true);
  });

  it("filtra por cuenta, subcategoría, etiqueta, naturaleza y gastos compartidos", () => {
    const [byAccount, bySub, byTag, byNature, noShared] = budgetStatuses(
      [
        budget({ sync_id: uuid(3401), account_ids: [acc2] }),
        budget({ sync_id: uuid(3402), subcategory_ids: [cinema] }),
        budget({ sync_id: uuid(3403), tag_refs: [trip] }),
        budget({ sync_id: uuid(3404), natures: ["esencial"] }),
        budget({ sync_id: uuid(3405), include_shared_expenses: false }),
      ],
      txs,
      lookup,
      ctx,
    ).presupuestos.sort((a, b) => a.id.localeCompare(b.id));
    expect(byAccount?.gastado).toBe(25);
    expect(bySub?.gastado).toBe(60);
    expect(byTag?.gastado).toBe(25);
    expect(byNature?.gastado).toBeCloseTo(40 + 25 + 10 + 34);
    expect(noShared?.gastado).toBeCloseTo(40 + 60 + 25 + 34);
  });

  it("naturalezas como la app: valores no reconocidos (el inglés de staging) dejan el presupuesto en 0", () => {
    const r = budgetStatuses([budget({ sync_id: uuid(3460), natures: ["essential", "priority"] })], txs, lookup, ctx);
    expect(r.presupuestos[0]?.gastado).toBe(0);
    expect(r.avisos.join(" ")).toMatch(/naturaleza que la app no reconoce/);
  });

  it("un override de naturaleza no reconocido es «sin clasificación» y no mira la subcategoría", () => {
    const r = budgetStatuses(
      [budget({ sync_id: uuid(3470), natures: ["esencial"] }), budget({ sync_id: uuid(3471), natures: ["sin_clasificacion"] })],
      [e({ amount: -5, need_override: "essential" })],
      lookup,
      ctx,
    ).presupuestos;
    const byId = Object.fromEntries(r.map((b) => [b.id, b.gastado]));
    expect(byId[uuid(3470)]).toBe(0);
    expect(byId[uuid(3471)]).toBe(5);
  });

  it("un null del wire vale el default del modelo: activo, y categoría con is_income nulo cuenta como gasto", () => {
    const nullIncome = uuid(3480);
    const lk = buildLookup({
      accounts: [account({ sync_id: acc1 })],
      categories: [category({ sync_id: nullIncome, is_income: null })],
    });
    const r = budgetStatuses([budget({ sync_id: uuid(3481), is_active: null })], [tx({ account_ref: acc1, category_ref: nullIncome, amount: -7 })], lk, ctx);
    expect(r.presupuestos[0]).toMatchObject({ activo: true, gastado: 7 });
  });

  it("estado: excedido, sin límite e inactivo", () => {
    const r = budgetStatuses(
      [
        budget({ sync_id: uuid(3501), limit_amount: 50 }),
        budget({ sync_id: uuid(3502), limit_amount: 0 }),
        budget({ sync_id: uuid(3503), is_active: false }),
      ],
      txs,
      lookup,
      { ...ctx, soloActivos: false },
    ).presupuestos;
    const byId = Object.fromEntries(r.map((b) => [b.id, b.estado]));
    expect(byId[uuid(3501)]).toBe("excedido");
    expect(byId[uuid(3502)]).toBe("sin_limite");
    expect(byId[uuid(3503)]).toBe("inactivo");
  });

  it("semanal empieza el lunes por defecto; único usa sus fechas", () => {
    const r = budgetStatuses(
      [
        budget({ sync_id: uuid(3601), period_type: "weekly" }),
        budget({ sync_id: uuid(3602), period_type: "unique", start_date: "2026-09-05T05:00:00Z", end_date: "2026-09-20T05:00:00Z" }),
      ],
      txs,
      lookup,
      ctx,
    ).presupuestos;
    const byId = Object.fromEntries(r.map((b) => [b.id, b.periodo]));
    expect(byId[uuid(3601)]).toEqual({ tipo: "semanal", desde: "2026-09-21", hasta: "2026-09-27" });
    expect(byId[uuid(3602)]).toEqual({ tipo: "unico", desde: "2026-09-05", hasta: "2026-09-20" });
  });
});

describe("recurrentes (port de monthlyMultiplier y monthlyTotal)", () => {
  it("equivalente mensual por frecuencia", () => {
    expect(monthlyMultiplier({ is_recurring: true, recurrence_type: "daily", recurrence_interval: 1 })).toBe(30);
    expect(monthlyMultiplier({ is_recurring: true, recurrence_type: "weekly", recurrence_interval: 2 })).toBeCloseTo(2.165);
    expect(monthlyMultiplier({ is_recurring: true, recurrence_type: "monthly", recurrence_interval: 3 })).toBeCloseTo(1 / 3);
    expect(monthlyMultiplier({ is_recurring: true, recurrence_type: "yearly", recurrence_interval: 1 })).toBeCloseTo(1 / 12);
    expect(monthlyMultiplier({ is_recurring: false, recurrence_type: "yearly", recurrence_interval: 1 })).toBe(1);
  });

  it("totales solo de gastos activos, y marca lo que conviene revisar sin decir «sin usar»", () => {
    const netflix = uuid(4001);
    const gym = uuid(4002);
    const rent = uuid(4003);
    const salary = uuid(4004);
    const old = uuid(4005);
    const lastLinked = new Map([
      [netflix, "2026-09-05"],
      [gym, "2026-06-01"],
    ]);
    const r = listRecurring(
      [
        scheduled({ sync_id: netflix, name: "Netflix", amount: -44.9, payment_category: "subscription" }),
        scheduled({ sync_id: gym, name: "Gimnasio", amount: 120, payment_category: "subscription", next_due_date: "2026-09-01T12:00:00Z" }),
        scheduled({ sync_id: rent, name: "Alquiler", amount: 1500, payment_category: "recurring", currency_code: "PEN" }),
        scheduled({ sync_id: salary, name: "Sueldo", amount: 5000, transaction_type: "income", payment_category: "recurring" }),
        scheduled({ sync_id: old, name: "Antiguo", amount: 10, is_active: false }),
      ],
      lastLinked,
      { subcategories: new Map(), categories: new Map() },
      { today: "2026-09-26", tz: "America/Lima", preferredCurrency: "PEN", rates: RATES, soloActivos: true },
    );
    expect(r.pagos.map((p) => p.nombre)).not.toContain("Antiguo");
    expect(r.totales_gasto.suscripciones_mensual).toBeCloseTo(164.9);
    expect(r.totales_gasto.recurrentes_mensual).toBe(1500);
    expect(r.totales_gasto.total_anual).toBeCloseTo((164.9 + 1500) * 12);
    const flags = Object.fromEntries(r.pagos.map((p) => [p.nombre, p.revisar]));
    expect(flags.Netflix).toEqual([]);
    expect(flags.Gimnasio).toEqual(["sin_movimiento_reciente", "proximo_cobro_vencido"]);
    expect(flags.Alquiler).toEqual(["sin_movimiento_reciente"]);
    expect(flags.Sueldo).toEqual([]);
    expect(r.a_revisar).toBe(2);
    expect(JSON.stringify(r)).not.toMatch(/sin usar/i);
  });
});
