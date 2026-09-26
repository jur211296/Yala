import { describe, expect, it } from "vitest";
import { computeBalances } from "../src/logic/balances";
import { budgetStatuses } from "../src/logic/budgets";
import { buildRateBook, convertOn, resolveRates } from "../src/logic/fx";
import { buildGroupAdjustment } from "../src/logic/groups";
import { buildLookup } from "../src/logic/lookup";
import { canonicalMerchant } from "../src/logic/merchant";
import { listRecurring, monthlyMultiplier } from "../src/logic/recurring";
import { summarize } from "../src/logic/summary";
import { resolvePeriod } from "../src/logic/dates";
import { account, budget, category, scheduled, subcategory, tag, tx, uuid } from "./fixtures";

const RATES = buildRateBook([
  { date_key: "2026-09-01", base: "USD", rates: { USD: "1", PEN: "3.50", EUR: "0.90" } },
  { date_key: "2026-09-09", base: "USD", rates: { USD: "1", PEN: "3.40", EUR: "0.85" } },
]);
/** «Hoy» en UTC para las tasas: el día de la última fila, así la tasa de hoy es exacta. */
const TODAY_UTC = "2026-09-09";

describe("divisas (port de CurrencyConverter.resolveRates)", () => {
  it("con la fila del día convierte exacto, pasando por USD", () => {
    expect(convertOn(34, "PEN", "USD", "2026-09-09", RATES)).toEqual({ value: 10, quality: "exact" });
    expect(convertOn(-10, "USD", "PEN", "2026-09-09", RATES)?.value).toBeCloseTo(-34);
    expect(convertOn(8.5, "EUR", "PEN", "2026-09-09", RATES)?.value).toBeCloseTo(34);
    expect(convertOn(5, "pen", "PEN", "2020-01-01", RATES)).toEqual({ value: 5, quality: "exact" });
  });

  it("sin fila ese día usa la anterior más reciente, nunca una posterior", () => {
    expect(convertOn(35, "PEN", "USD", "2026-09-05", RATES)).toEqual({ value: 10, quality: "carried" });
    expect(convertOn(34, "PEN", "USD", "2026-09-26", RATES)).toEqual({ value: 10, quality: "carried" });
  });

  it("antes de la primera fila, o una divisa que ninguna fila trae, sale de la tabla estática", () => {
    expect(convertOn(3.72, "PEN", "USD", "2026-08-01", RATES)).toEqual({ value: 1, quality: "static" });
    expect(convertOn(150, "JPY", "USD", "2026-09-09", RATES)).toEqual({ value: 1, quality: "static" });
  });

  it("una divisa que la app no conoce no se convierte", () => {
    expect(convertOn(5, "XXX", "PEN", "2026-09-09", RATES)).toBeNull();
  });

  it("la ventana hacia atrás es de 30 filas, como la app", () => {
    const rows = [{ date_key: "2026-01-01", base: "USD", rates: { USD: 1, PEN: 3.3, EUR: 0.8 } }];
    for (let d = 1; d <= 30; d++) rows.push({ date_key: `2026-02-${String(d).padStart(2, "0")}`, base: "USD", rates: { USD: 1, PEN: 3.6 } as never });
    const book = buildRateBook(rows);
    // EUR solo está en una fila 31 filas atrás: la app ya no llega y usa la tabla estática.
    expect(resolveRates(book, "2026-03-01", ["EUR", "USD"]).quality).toBe("static");
    expect(resolveRates(book, "2026-02-30", ["EUR", "USD"]).quality).toBe("carried");
  });

  it("la ventana cuenta FILAS: con dos filas por día solo llega a 15 días atrás", () => {
    const rows: { date_key: string; base: string; rates: Record<string, number> }[] = [
      { date_key: "2026-01-10", base: "USD", rates: { USD: 1, JPY: 100 } },
    ];
    for (let d = 1; d <= 20; d++) {
      const key = `2026-02-${String(d).padStart(2, "0")}`;
      rows.push({ date_key: key, base: "USD", rates: { USD: 1, PEN: 3.5 } }, { date_key: key, base: "USD", rates: { USD: 1, PEN: 3.5 } });
    }
    const book = buildRateBook(rows);
    // La app no alcanza la fila del 10-ene (40 filas atrás) y usa la tabla estática: JPY = 150.
    expect(convertOn(10_000, "JPY", "PEN", "2026-02-21", book)).toEqual({ value: (10_000 / 150) * 3.5, quality: "static" });
  });

  it("una tasa se lee como la app: número o texto numérico exacto, y la clave tal cual", () => {
    const book = buildRateBook([
      { date_key: "2026-09-09", base: "USD", rates: { USD: 1, PEN: " 3.4", eur: "0.9", JPY: true as never, GBP: "0.75" } },
    ]);
    const day = book.byDay.get("2026-09-09");
    expect(day?.has("PEN")).toBe(false);
    expect(day?.has("EUR")).toBe(false);
    expect(day?.has("JPY")).toBe(false);
    expect(day?.get("GBP")).toBe(0.75);
  });

  it("varias filas del mismo día se funden: por divisa gana la de timestamp más reciente", () => {
    const book = buildRateBook([
      { sync_id: "b", date_key: "2026-09-09", base: "USD", rates: { USD: "1", PEN: "3.40", EUR: "0.85" }, timestamp: "2026-09-09T10:00:00Z" },
      { sync_id: "a", date_key: "2026-09-09", base: "USD", rates: { USD: "1", PEN: "3.80" }, timestamp: "2026-09-09T12:00:00Z" },
      { sync_id: "c", date_key: "2026-09-09", base: "USD", rates: { USD: "1", PEN: "9.99", GBP: "0.7" }, timestamp: null },
    ]);
    const day = book.byDay.get("2026-09-09");
    expect(day?.get("PEN")).toBe(3.8);
    expect(day?.get("EUR")).toBe(0.85);
    expect(day?.get("GBP")).toBe(0.7);
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
    const r = computeBalances(accounts, txs, "PEN", RATES, { incluirArchivadas: true, todayUtc: TODAY_UTC });
    const byName = Object.fromEntries(r.cuentas.map((c) => [c.nombre, c.saldo]));
    expect(byName).toEqual({ BCP: 849.5, "Ahorro USD": 100, Vieja: 50, Préstamo: -999 });
  });

  it("el total deja fuera archivadas y excluidas, y convierte cada divisa con la tasa de hoy", () => {
    const r = computeBalances(accounts, txs, "PEN", RATES, { incluirArchivadas: false, todayUtc: TODAY_UTC });
    expect(r.total.importe).toBeCloseTo(849.5 + 340);
    expect(r.total.aproximado).toBe(false);
    // Sin fila de hoy se usa la última anterior, y eso es «≈», igual que en la app.
    expect(computeBalances(accounts, txs, "PEN", RATES, { incluirArchivadas: false, todayUtc: "2026-09-26" }).total.aproximado).toBe(true);
    expect(r.cuentas.map((c) => c.nombre)).not.toContain("Vieja");
  });

  it("una divisa que la app no conoce no se suma y se declara", () => {
    const r = computeBalances(accounts, [...txs, { account_ref: pen, amount: 7, currency_code: "XXX" }], "PEN", RATES, {
      incluirArchivadas: false,
      todayUtc: TODAY_UTC,
    });
    expect(r.total.sin_convertir).toEqual([{ divisa: "XXX", importe: 7 }]);
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
    // Otra divisa guardada con otra preferida: se reconvierte con la tasa de SU día (10-sep, sin fila → la del 9) → ≈.
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
    expect(r.aproximado_detalle).toEqual({ ingresos: false, gastos: true, neto: false });
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

  it("un gasto de grupo que pagaste tú cuenta por tu parte, y su pata de préstamo no es ingreso", () => {
    const groupsAcc = uuid(2003);
    const loanCat = uuid(2103);
    const lk = buildLookup({
      accounts: [account({ sync_id: acc }), account({ sync_id: groupsAcc, name: "Grupos", is_system_account: true })],
      categories: [category({ sync_id: food, name: "Comida" }), category({ sync_id: loanCat, name: "Cobros de grupos", is_income: true })],
    });
    const legs = [
      tx({ ...base, category_ref: food, amount: -300, amount_in_preferred_currency: -300, split_expense_id: "s1" }),
      tx({ ...base, account_ref: groupsAcc, category_ref: loanCat, amount: 200, amount_in_preferred_currency: 200, split_expense_id: "s1" }),
    ];
    const groups = buildGroupAdjustment(legs, lk.accounts, lk.subcategories);
    const r = summarize(legs, lk, period, { ...ctx, groups });
    expect(r.gastos).toBe(100);
    expect(r.ingresos).toBe(0);
    expect(r.avisos.join(" ")).not.toMatch(/grupo|tasa/);
  });

  it("sin categoría también cuenta tu parte, y una pata de préstamo suprimida no entra aunque su categoría no resuelva", () => {
    const groupsAcc = uuid(2004);
    const lk = buildLookup({ accounts: [account({ sync_id: acc }), account({ sync_id: groupsAcc, is_system_account: true })] });
    const legs = [
      // La app deja sin categoría la pata real cuando falla el auto-match de subcategoría.
      tx({ ...base, amount: -300, amount_in_preferred_currency: -300, split_expense_id: "s2" }),
      tx({ ...base, account_ref: groupsAcc, category_ref: uuid(2999), amount: 200, amount_in_preferred_currency: 200, split_expense_id: "s2" }),
    ];
    const groups = buildGroupAdjustment(legs, lk.accounts, lk.subcategories);
    const r = summarize(legs, lk, period, { ...ctx, groups });
    expect(r.sin_categoria).toEqual({ movimientos: 1, importe_absoluto: 100 });
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
  const ctx = { today: "2026-09-26", todayUtc: TODAY_UTC, tz: "America/Lima", rates: RATES, firstWeekday: 2 as const, soloActivos: true };
  const e = (p: Parameters<typeof tx>[0]) => tx({ account_ref: acc1, category_ref: food, subcategory_ref: super_, ...p });

  const txs = [
    e({ amount: -40 }),
    e({ amount: -60, subcategory_ref: cinema }),
    e({ amount: -25, account_ref: acc2, tag_refs: [trip] }),
    e({ amount: -10, split_expense_id: "g1" }),
    e({ amount: 500, category_ref: salary }), // ingreso: nunca cuenta
    e({ amount: -999, date: "2026-08-31T15:00:00Z" }), // mes anterior
    e({ amount: -999, date: "2026-10-01T05:00:00Z" }), // 1 de octubre en Lima: ni futuro ni de septiembre
    e({ amount: -10, currency_code: "USD" }), // 34 PEN con la tasa de hoy
  ];

  it("sin filtros suma el valor absoluto de todos los gastos del periodo", () => {
    const r = budgetStatuses([budget({ sync_id: uuid(), limit_amount: 200 })], txs, lookup, ctx);
    const b = r.presupuestos[0]!;
    expect(b.gastado).toBeCloseTo(40 + 60 + 25 + 10 + 34);
    expect(b.periodo).toEqual({ tipo: "mensual", desde: "2026-09-01", hasta: "2026-09-30" });
    expect(b.dias_restantes).toBe(4);
    expect(b.estado).toBe("en_riesgo");
    // La tasa salió de la fila de hoy: exacta.
    expect(b.aproximado).toBe(false);
  });

  it("una tasa que falta en la fila de hoy se toma de la anterior y marca aproximado", () => {
    const rates = buildRateBook([
      { date_key: "2026-09-09", base: "USD", rates: { USD: "1", PEN: "3.40" } },
      { date_key: "2026-09-01", base: "USD", rates: { USD: "1", PEN: "3.50", EUR: "0.85" } },
    ]);
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
      { today: "2026-09-26", todayUtc: TODAY_UTC, tz: "America/Lima", preferredCurrency: "PEN", rates: RATES, soloActivos: true },
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
