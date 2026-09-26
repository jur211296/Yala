/**
 * Estado de los presupuestos en su periodo actual. Cuadra con la pantalla de Presupuestos, que es con la que el
 * usuario va a comparar lo que le diga Claude.
 *
 * - Periodo: port de `InsightsCalculator.currentBudgetInterval`
 *   (Yala/App/Logic/Calculators/InsightsCalculator.swift:565). Semana con el primer día que el usuario eligió
 *   (`firstWeekday`, lunes por defecto), mes, año, o las fechas del presupuesto si es «único».
 * - Gasto: port de `BudgetsViewModel.filterTransactions` + `calculateSpending`
 *   (Yala/App/ViewModels/BudgetsViewModel.swift:540, 615). Igual que esa pantalla, NO quita movimientos futuros
 *   ni de cuentas excluidas o archivadas (el chat de la app sí; la pantalla no). Filtros: cuentas, subcategorías,
 *   etiquetas (basta una en común), naturaleza y gastos compartidos. Solo movimientos con categoría que no sea de
 *   ingreso. Suma de valores absolutos en la divisa del presupuesto, con la tasa más reciente si hace falta.
 * - Estado: port de `FullFinancialContextBuilder.buildBudgets` (líneas 608-656): sin límite / excedido ≥ 100 % /
 *   en riesgo ≥ 75 % / en camino.
 *
 * Un campo nulo vale lo que vale por defecto en el modelo de la app (`Budget.swift`: `isActive = true`,
 * `currencyCode = "USD"`), porque la app aplica el null del wire como «no tocar».
 *
 * Diferencia deliberada: el periodo es por días inclusivos. La app termina en el INICIO del periodo siguiente y
 * `DateInterval.contains` lo incluye (ticket `budget-interval-counts-next-period-midnight`). Aquí no.
 */
import { categoryOf, type Lookup } from "./lookup";
import { convert, type RateTable } from "./fx";
import { addDays, dayInZone, monthEnd, monthStart, txDay, weekStart, yearEnd, yearStart, type Day } from "./dates";
import { num, round2, type BudgetRow, type TxRow } from "./types";

/** Valores crudos de `SubcategoryNeed` (Yala/App/Models/SharedModels.swift:50). Lo que no sea uno de estos no existe para la app. */
const NEED_RAW = new Set(["esencial", "prioritaria", "opcional", "sin_clasificacion"]);

/** `SubcategoryNeed(rawValue:)`: exacto, sin normalizar. */
function strictNeed(raw: string | null | undefined): string | null {
  return raw !== null && raw !== undefined && NEED_RAW.has(raw) ? raw : null;
}

/**
 * `TransactionItem.effectiveNeed` (Yala/Models/TransactionItem.swift:106): si hay override, manda él y, si no se
 * reconoce, es «sin clasificación» (no se mira la subcategoría). Si no hay, la de la subcategoría.
 */
function effectiveNeed(tx: TxRow, lookup: Lookup): string {
  if (tx.need_override !== null) return strictNeed(tx.need_override) ?? "sin_clasificacion";
  const sub = tx.subcategory_ref ? lookup.subcategories.get(tx.subcategory_ref) : undefined;
  return strictNeed(sub?.nature_raw_value) ?? "sin_clasificacion";
}

export interface BudgetStatus {
  id: string;
  nombre: string;
  divisa: string;
  limite: number;
  gastado: number;
  porcentaje: number | null;
  restante: number;
  periodo: { tipo: string; desde: Day; hasta: Day };
  dias_restantes: number;
  estado: "sin_limite" | "excedido" | "en_riesgo" | "en_camino" | "inactivo";
  activo: boolean;
  filtros: { cuentas: number; subcategorias: number; etiquetas: number; naturalezas: string[]; incluye_compartidos: boolean };
  movimientos: number;
  aproximado: boolean;
}

export function isBudgetActive(b: BudgetRow): boolean {
  return b.is_active !== false;
}

export function budgetPeriod(b: BudgetRow, today: Day, tz: string, firstWeekday: 1 | 2): { tipo: string; desde: Day; hasta: Day } {
  const type = b.period_type ?? "monthly";
  switch (type) {
    case "weekly": {
      const start = weekStart(today, firstWeekday);
      return { tipo: "semanal", desde: start, hasta: addDays(start, 6) };
    }
    case "yearly":
      return { tipo: "anual", desde: yearStart(today), hasta: yearEnd(today) };
    case "unique":
      if (b.start_date && b.end_date) {
        return { tipo: "unico", desde: dayInZone(b.start_date, tz), hasta: dayInZone(b.end_date, tz) };
      }
      return { tipo: "unico", desde: monthStart(today), hasta: monthEnd(today) };
    case "monthly":
    default:
      return { tipo: "mensual", desde: monthStart(today), hasta: monthEnd(today) };
  }
}

export function budgetStatuses(
  budgets: BudgetRow[],
  txs: TxRow[],
  lookup: Lookup,
  ctx: { today: Day; tz: string; rates: RateTable | null; firstWeekday: 1 | 2; soloActivos: boolean },
): { presupuestos: BudgetStatus[]; avisos: string[] } {
  const avisos: string[] = [];
  let groupTx = 0;
  let unconvertible = 0;
  let unknownNatures = 0;

  // Elegibles como en la pantalla: todo menos los ajustes de saldo, y lo que no se puede situar.
  const eligible: { tx: TxRow; day: Day }[] = [];
  for (const tx of txs) {
    if (tx.balance_adjustment_type) continue;
    if (num(tx.amount) === null) continue;
    const day = txDay(tx, ctx.tz);
    if (day) eligible.push({ tx, day });
  }

  const out: BudgetStatus[] = [];
  for (const b of budgets) {
    const active = isBudgetActive(b);
    if (ctx.soloActivos && !active) continue;
    const currency = (b.currency_code ?? "USD").toUpperCase();
    const limit = num(b.limit_amount) ?? 0;
    const period = budgetPeriod(b, ctx.today, ctx.tz, ctx.firstWeekday);
    const accounts = new Set(b.account_ids ?? []);
    const subs = new Set(b.subcategory_ids ?? []);
    const tags = new Set(b.tag_refs ?? []);
    const rawNatures = (b.natures ?? []).map((n) => n.trim()).filter((n) => n.length > 0);
    // Como `compactMap { SubcategoryNeed(rawValue:) }`: lo que no se reconoce se cae. Si se caen TODAS, el filtro
    // sigue puesto y no deja pasar nada — la app enseña 0 y aquí también.
    const natures = rawNatures.map(strictNeed).filter((n): n is string => n !== null);
    if (rawNatures.length > natures.length) unknownNatures += 1;
    const includeShared = b.include_shared_expenses !== false;

    let spent = 0;
    let movements = 0;
    let approximate = false;
    for (const { tx, day } of eligible) {
      if (day < period.desde || day > period.hasta) continue;
      const category = categoryOf(lookup, tx);
      if (!category || category.is_income === true) continue;
      if (accounts.size > 0 && !(tx.account_ref && accounts.has(tx.account_ref))) continue;
      if (subs.size > 0 && !(tx.subcategory_ref && subs.has(tx.subcategory_ref))) continue;
      if (tags.size > 0 && !(tx.tag_refs ?? []).some((t) => tags.has(t))) continue;
      if (rawNatures.length > 0 && !natures.includes(effectiveNeed(tx, lookup))) continue;
      if (!includeShared && tx.split_expense_id) continue;

      const native = num(tx.amount) ?? 0;
      const from = (tx.currency_code ?? "USD").toUpperCase();
      const value = convert(native, from, currency, ctx.rates);
      if (value === null) {
        unconvertible += 1;
        continue;
      }
      if (from !== currency && ctx.rates?.filledFromOlder.has(from)) approximate = true;
      if (tx.split_expense_id) groupTx += 1;
      spent += Math.abs(value);
      movements += 1;
    }

    const pct = limit > 0 ? (spent / limit) * 100 : null;
    let estado: BudgetStatus["estado"];
    if (!active) estado = "inactivo";
    else if (limit <= 0) estado = "sin_limite";
    else if ((pct ?? 0) >= 100) estado = "excedido";
    else if ((pct ?? 0) >= 75) estado = "en_riesgo";
    else estado = "en_camino";

    const daysLeft = period.hasta >= ctx.today ? Math.max(0, Math.round((Date.parse(period.hasta) - Date.parse(ctx.today)) / 86_400_000)) : 0;

    out.push({
      id: b.sync_id,
      nombre: b.name ?? "(sin nombre)",
      divisa: currency,
      limite: round2(limit),
      gastado: round2(spent),
      porcentaje: pct === null ? null : round2(pct),
      restante: round2(limit - spent),
      periodo: period,
      dias_restantes: daysLeft,
      estado,
      activo: active,
      filtros: {
        cuentas: accounts.size,
        subcategorias: subs.size,
        etiquetas: tags.size,
        naturalezas: natures,
        incluye_compartidos: includeShared,
      },
      movimientos: movements,
      aproximado: approximate,
    });
  }

  if (groupTx > 0) {
    avisos.push(`${groupTx} gasto(s) de grupo cuentan por su importe entero, no por tu parte. La app los ajusta; esta versión todavía no.`);
  }
  if (unconvertible > 0) avisos.push(`${unconvertible} movimiento(s) en otra divisa no se pudieron convertir y no están sumados.`);
  if (unknownNatures > 0) {
    avisos.push(`${unknownNatures} presupuesto(s) filtran por una naturaleza que la app no reconoce; esa parte del filtro no deja pasar nada, igual que en la app.`);
  }
  out.sort((a, b) => (b.porcentaje ?? -1) - (a.porcentaje ?? -1));
  return { presupuestos: out, avisos };
}
