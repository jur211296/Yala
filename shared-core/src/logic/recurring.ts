/**
 * Pagos recurrentes y programados, con su equivalente mensual y anual, y lo que conviene revisar.
 *
 * - Equivalente mensual: port de `FullFinancialContextBuilder.monthlyMultiplier` (línea 770): diario × 30/n,
 *   semanal × 4,33/n, mensual × 1/n, anual × 1/(12·n); un pago único cuenta una vez.
 * - Totales: port de `monthlyTotal` (línea 749): solo GASTOS, separados en suscripciones y recurrentes, convertidos
 *   con la tasa de HOY (`convert(on: now)`: el día UTC de ahora).
 *
 * «Recurrentes a revisar» (decisión de Jürgen, 2026-09-26): Yala no sabe si usas un servicio, solo si lo pagas. Así
 * que aquí no hay «sin usar». Hay dos hechos medibles, y se dicen tal cual:
 * - `sin_movimiento_reciente`: el último movimiento enlazado a este pago (`tx_items.scheduled_payment_ref`) tiene
 *   más de dos ciclos, o no hay ninguno.
 * - `proximo_cobro_vencido`: la fecha del próximo cobro ya pasó y la app no la ha adelantado.
 */
import { convertOn, type RateBook } from "./fx";
import { dayInZone, daysInclusive, type Day } from "./dates";
import { num, round2, type ScheduledPaymentRow, type SubcategoryRow, type CategoryRow } from "./types";

export function monthlyMultiplier(p: Pick<ScheduledPaymentRow, "is_recurring" | "recurrence_type" | "recurrence_interval">): number {
  if (p.is_recurring === false) return 1;
  const n = Math.max(1, p.recurrence_interval ?? 1);
  switch (p.recurrence_type) {
    case "daily":
      return 30 / n;
    case "weekly":
      return 4.33 / n;
    case "yearly":
      return 1 / (12 * n);
    case "monthly":
    default:
      return 1 / n;
  }
}

/** Duración aproximada de un ciclo en días, para decidir si «hace mucho» del último cobro. */
export function cycleDays(p: Pick<ScheduledPaymentRow, "is_recurring" | "recurrence_type" | "recurrence_interval">): number | null {
  if (p.is_recurring === false) return null;
  const n = Math.max(1, p.recurrence_interval ?? 1);
  switch (p.recurrence_type) {
    case "daily":
      return n;
    case "weekly":
      return 7 * n;
    case "yearly":
      return 365 * n;
    case "monthly":
    default:
      return 30 * n;
  }
}

const FREQ_LABEL: Record<string, string> = { daily: "diaria", weekly: "semanal", monthly: "mensual", yearly: "anual" };
const KIND_LABEL: Record<string, string> = { subscription: "suscripcion", recurring: "recurrente" };

export interface RecurringItem {
  id: string;
  nombre: string;
  tipo: string;
  movimiento: "gasto" | "ingreso";
  importe: number;
  divisa: string;
  frecuencia: string;
  cada: number;
  activo: boolean;
  proximo_cobro: Day | null;
  ultimo_pago_marcado: Day | null;
  ultimo_movimiento_enlazado: Day | null;
  equivalente_mensual: number;
  equivalente_anual: number;
  equivalente_mensual_en_divisa_preferida: number | null;
  categoria: string | null;
  subcategoria: string | null;
  revisar: ("sin_movimiento_reciente" | "proximo_cobro_vencido")[];
}

export interface RecurringResult {
  divisa_preferida: string;
  pagos: RecurringItem[];
  totales_gasto: {
    suscripciones_mensual: number;
    recurrentes_mensual: number;
    total_mensual: number;
    total_anual: number;
  };
  a_revisar: number;
  aproximado: boolean;
  avisos: string[];
}

export function listRecurring(
  payments: ScheduledPaymentRow[],
  lastLinkedTxDay: Map<string, Day>,
  refs: { subcategories: Map<string, SubcategoryRow>; categories: Map<string, CategoryRow> },
  ctx: { today: Day; todayUtc: string; tz: string; preferredCurrency: string; rates: RateBook; soloActivos: boolean },
): RecurringResult {
  const avisos: string[] = [];
  let approximate = false;
  let unconvertible = 0;
  const totals = { subscription: 0, recurring: 0 };
  const items: RecurringItem[] = [];

  for (const p of payments) {
    // Null = default del modelo (`ScheduledPayment.swift`: isActive = true, isRecurring = true,
    // paymentCategory = "recurring", currencyCode = "USD", transactionType = "expense").
    const active = p.is_active !== false;
    const recurring = p.is_recurring !== false;
    const kind = p.payment_category ?? "recurring";
    if (ctx.soloActivos && !active) continue;
    const amount = Math.abs(num(p.amount) ?? 0);
    const currency = (p.currency_code ?? "USD").toUpperCase();
    const mult = monthlyMultiplier(p);
    const monthly = amount * mult;
    const converted = convertOn(monthly, currency, ctx.preferredCurrency, ctx.todayUtc, ctx.rates);
    const monthlyPref = converted?.value ?? null;
    if (converted === null) unconvertible += 1;
    else if (converted.quality !== "exact") approximate = true;

    const isExpense = (p.transaction_type ?? "expense") === "expense";
    if (active && isExpense && monthlyPref !== null) {
      if (kind === "subscription") totals.subscription += monthlyPref;
      else if (kind === "recurring") totals.recurring += monthlyPref;
    }

    const next = p.next_due_date ? dayInZone(p.next_due_date, ctx.tz) : null;
    const lastLinked = lastLinkedTxDay.get(p.sync_id) ?? null;
    const cycle = cycleDays(p);
    const revisar: RecurringItem["revisar"] = [];
    if (active && isExpense && cycle !== null) {
      if (!lastLinked || daysInclusive(lastLinked, ctx.today) - 1 > 2 * cycle) revisar.push("sin_movimiento_reciente");
    }
    if (active && next && next < ctx.today) revisar.push("proximo_cobro_vencido");

    const sub = p.subcategory_ref ? refs.subcategories.get(p.subcategory_ref) : undefined;
    const cat = sub?.category_ref ? refs.categories.get(sub.category_ref) : undefined;

    items.push({
      id: p.sync_id,
      nombre: p.name ?? "(sin nombre)",
      tipo: recurring ? (KIND_LABEL[kind] ?? kind) : "unico",
      movimiento: isExpense ? "gasto" : "ingreso",
      importe: round2(amount),
      divisa: currency,
      frecuencia: recurring ? (FREQ_LABEL[p.recurrence_type ?? "monthly"] ?? "mensual") : "una_vez",
      cada: Math.max(1, p.recurrence_interval ?? 1),
      activo: active,
      proximo_cobro: next,
      ultimo_pago_marcado: p.last_paid_date ? dayInZone(p.last_paid_date, ctx.tz) : null,
      ultimo_movimiento_enlazado: lastLinked,
      equivalente_mensual: round2(monthly),
      equivalente_anual: round2(recurring ? monthly * 12 : amount),
      equivalente_mensual_en_divisa_preferida: monthlyPref === null ? null : round2(monthlyPref),
      categoria: cat?.name ?? null,
      subcategoria: sub?.name ?? null,
      revisar,
    });
  }

  items.sort((a, b) => (b.equivalente_mensual_en_divisa_preferida ?? 0) - (a.equivalente_mensual_en_divisa_preferida ?? 0));
  if (approximate) avisos.push("Algún equivalente en tu divisa se convirtió sin la cotización exacta de hoy: es aproximado.");
  if (unconvertible > 0) avisos.push(`${unconvertible} pago(s) en una divisa que la app no reconoce no están en los totales.`);
  avisos.push(
    "«A revisar» solo dice si hay movimientos recientes enlazados al pago o si su fecha pasó. Yala no sabe si usas el servicio.",
  );

  const total = totals.subscription + totals.recurring;
  return {
    divisa_preferida: ctx.preferredCurrency,
    pagos: items,
    totales_gasto: {
      suscripciones_mensual: round2(totals.subscription),
      recurrentes_mensual: round2(totals.recurring),
      total_mensual: round2(total),
      total_anual: round2(total * 12),
    },
    a_revisar: items.filter((i) => i.revisar.length > 0).length,
    aproximado: approximate,
    avisos,
  };
}
