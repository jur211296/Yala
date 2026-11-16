/**
 * Calendario de los pagos planificados para Yala web (lote 2): en qué días cobra cada pago.
 *
 * Port de `ScheduledPaymentDateCalculator.paymentDatesInMonth` (Yala/Utils/ScheduledPaymentDateCalculator.swift), el que
 * usan la pantalla de Pagos planificados, el widget y las notificaciones. Trabaja con días civiles en la zona de la
 * persona (la app usa `Calendar.current`):
 *
 * - Pago único: el día de `next_due_date`, si cae en el mes.
 * - Diario: cada `n` días contando desde `next_due_date` (hacia atrás y hacia delante).
 * - Semanal: los días de la semana de `selected_weekdays` (1 = domingo … 7 = sábado); con `n > 1`, solo las semanas
 *   cuyo desfase con la de `next_due_date` es múltiplo de `n`. La semana empieza el `firstWeekday` del teléfono.
 * - Mensual: el `day_of_month` (o el día de `next_due_date`), acotado al largo del mes, en los meses cuyo desfase con
 *   el de `next_due_date` es múltiplo de `n`.
 * - Anual: `yearly_month`/`yearly_day` (o los de `next_due_date`), el 29 de febrero en el 28 si el año no es bisiesto,
 *   en los años cuyo desfase es múltiplo de `n`.
 * - Después: nada antes del día de `created_at` ni después del de `end_date` (inclusivo).
 *
 * Las fechas saltadas (`skipped_dates_raw`) no son del calculador: las quita `upcomingCharges`, como la lista del
 * iPhone (`ScheduledPayment.isDateSkipped`).
 */
import { addDays, addMonths, dayInZone, monthEnd, monthStart, zonedDayStartUtc, type Day } from "./dates";
import { convertOn, type RateBook } from "./fx";
import { monthlyMultiplier } from "./recurring";
import { num, round2, type CategoryRow, type ScheduledPaymentRow, type SubcategoryRow } from "./types";

export interface ScheduleRow extends ScheduledPaymentRow {
  created_at?: string | null;
  day_of_month?: number | null;
  selected_weekdays?: string[] | string | null;
  yearly_month?: number | null;
  yearly_day?: number | null;
  skipped_dates_raw?: string[] | string | null;
}

function parse(day: Day): { y: number; m: number; d: number } {
  return { y: Number(day.slice(0, 4)), m: Number(day.slice(5, 7)), d: Number(day.slice(8, 10)) };
}

function makeDay(y: number, m: number, d: number): Day {
  return `${String(y).padStart(4, "0")}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

function daysInMonth(y: number, m: number): number {
  return Number(monthEnd(makeDay(y, m, 1)).slice(8, 10));
}

/** 1 = domingo … 7 = sábado, como `Calendar.component(.weekday)`. */
function weekdayOf(day: Day): number {
  return new Date(`${day}T00:00:00Z`).getUTCDay() + 1;
}

function weekStartOf(day: Day, firstWeekday: number): Day {
  return addDays(day, -((weekdayOf(day) - firstWeekday + 7) % 7));
}

function dayDiff(from: Day, to: Day): number {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
}

function csv(raw: string[] | string | null | undefined): string[] {
  if (Array.isArray(raw)) return raw.map(String);
  if (typeof raw === "string" && raw) return raw.split(",");
  return [];
}

export function parseWeekdays(raw: string[] | string | null | undefined): Set<number> {
  return new Set(csv(raw).map((v) => Number(v)).filter((n) => Number.isInteger(n)));
}

/** Los días de cobro de `p` en el mes de `month` (YYYY-MM-DD de cualquier día del mes), ordenados. */
export function paymentDatesInMonth(p: ScheduleRow, month: Day, tz: string, firstWeekday: 1 | 2 = 2): Day[] {
  if (!p.next_due_date) return [];
  const anchor = dayInZone(p.next_due_date, tz);
  const mStart = monthStart(month);
  const mEnd = monthEnd(month);
  const { y, m } = parse(mStart);
  let dates: Day[] = [];

  if (p.is_recurring === false) {
    if (anchor >= mStart && anchor <= mEnd) dates.push(anchor);
    return postFilter(dates, p, tz);
  }

  const interval = Math.max(1, p.recurrence_interval ?? 1);
  switch (p.recurrence_type ?? "monthly") {
    case "daily": {
      let d = anchor;
      let safety = 0;
      while (d > mStart && safety < 400) {
        d = addDays(d, -interval);
        safety++;
      }
      while (d <= mEnd) {
        if (d >= mStart) dates.push(d);
        d = addDays(d, interval);
      }
      break;
    }
    case "weekly": {
      const weekdays = parseWeekdays(p.selected_weekdays);
      if (weekdays.size === 0) break;
      const anchorWeek = weekStartOf(anchor, firstWeekday);
      for (let d = mStart; d <= mEnd; d = addDays(d, 1)) {
        if (!weekdays.has(weekdayOf(d))) continue;
        if (interval === 1) dates.push(d);
        else {
          // `Int` de Swift trunca hacia cero: un desfase negativo de -1 semana da -1 % 2 = -1, no 1.
          const weekOffset = Math.trunc(dayDiff(anchorWeek, weekStartOf(d, firstWeekday)) / 7);
          if (weekOffset % interval === 0) dates.push(d);
        }
      }
      break;
    }
    case "monthly": {
      const a = parse(anchor);
      const dom = p.day_of_month ?? a.d;
      const monthsBetween = (y - a.y) * 12 + (m - a.m);
      if (monthsBetween % interval !== 0) break;
      // `min(dayOfMonth, maxDay)` sin suelo: un día < 1 cae en el mes anterior y no sale.
      if (dom < 1) break;
      dates = [makeDay(y, m, Math.min(dom, daysInMonth(y, m)))];
      break;
    }
    case "yearly": {
      const a = parse(anchor);
      const targetMonth = p.yearly_month ?? a.m;
      const targetDay = p.yearly_day ?? a.d;
      if (m !== targetMonth) break;
      if ((y - a.y) % interval !== 0) break;
      dates = [makeDay(y, m, Math.min(Math.max(targetDay, 1), daysInMonth(y, m)))];
      break;
    }
    default:
      return [];
  }
  return postFilter(dates, p, tz);
}

function postFilter(dates: Day[], p: ScheduleRow, tz: string): Day[] {
  let out = dates;
  if (p.created_at) {
    const created = dayInZone(p.created_at, tz);
    out = out.filter((d) => d >= created);
  }
  if (p.end_date) {
    const end = dayInZone(p.end_date, tz);
    out = out.filter((d) => d <= end);
  }
  return out;
}

/**
 * Las claves de las fechas saltadas, tal cual (`ScheduledPayment.skippedDatesRaw`). Cada clave es la fecha UTC de la
 * medianoche LOCAL del día saltado (`ISO8601DateFormatter` con `.withFullDate` formatea en GMT): en Lima coincide con el
 * día civil; en una zona por delante de UTC es el día anterior. Por eso se compara con `skipKey`, no con el día.
 */
export function skippedKeys(p: ScheduleRow): Set<string> {
  return new Set(csv(p.skipped_dates_raw).map((v) => v.trim()).filter(Boolean));
}

/** La clave con la que la app guarda un día saltado (`ScheduledPayment.dateKey`). */
export function skipKey(day: Day, tz: string): string {
  return zonedDayStartUtc(day, tz).toISOString().slice(0, 10);
}

// ─── Lo que enseña la web ───────────────────────────────────────────────────────────────────────────────────────

export interface UpcomingCharge {
  id: string;
  nombre: string;
  dia: Day;
  /** Días desde hoy: 0 = hoy, 1 = mañana. */
  en_dias: number;
  importe: number;
  divisa: string;
  importe_en_divisa_preferida: number | null;
  movimiento: "gasto" | "ingreso";
  tipo: "suscripcion" | "recurrente" | "unico";
  frecuencia: string;
  cada: number;
  categoria: string | null;
}

export interface SubscriptionItem {
  id: string;
  nombre: string;
  importe: number;
  divisa: string;
  frecuencia: string;
  cada: number;
  proximo_cobro: Day | null;
  equivalente_mensual_en_divisa_preferida: number | null;
  categoria: string | null;
}

export interface PaymentsResult {
  divisa: string;
  desde: Day;
  hasta: Day;
  proximos: UpcomingCharge[];
  /** Suma de los GASTOS de `proximos` en la divisa preferida (tasa de hoy). */
  total_gastos: number;
  suscripciones: SubscriptionItem[];
  suscripciones_mensual: number;
  aproximado: boolean;
}

const FREQ: Record<string, string> = { daily: "diaria", weekly: "semanal", monthly: "mensual", yearly: "anual" };

/**
 * Próximos cobros de `days` días desde hoy (incluido) y las suscripciones activas. Solo pagos activos; las fechas
 * saltadas no salen. El equivalente mensual de una suscripción es el de `listar_recurrentes` (recurring.ts).
 */
export function upcomingPayments(
  payments: ScheduleRow[],
  refs: { subcategories: Map<string, SubcategoryRow>; categories: Map<string, CategoryRow> },
  ctx: { today: Day; todayUtc: string; tz: string; preferredCurrency: string; rates: RateBook; days: number; firstWeekday?: 1 | 2 },
): PaymentsResult {
  const until = addDays(ctx.today, ctx.days - 1);
  const months: Day[] = [];
  for (let mo = monthStart(ctx.today); mo <= until; mo = addMonths(mo, 1)) months.push(mo);
  const proximos: UpcomingCharge[] = [];
  const suscripciones: SubscriptionItem[] = [];
  let total = 0;
  let subsMonthly = 0;
  let approximate = false;

  for (const p of payments) {
    if (p.is_active === false) continue;
    const amount = Math.abs(num(p.amount) ?? 0);
    const currency = (p.currency_code ?? "USD").toUpperCase();
    const isExpense = (p.transaction_type ?? "expense") === "expense";
    const kind = p.is_recurring === false ? "unico" : p.payment_category === "subscription" ? "suscripcion" : "recurrente";
    const sub = p.subcategory_ref ? refs.subcategories.get(p.subcategory_ref) : undefined;
    const cat = sub?.category_ref ? refs.categories.get(sub.category_ref) : undefined;
    const label = sub?.name ?? cat?.name ?? null;
    const freq = p.is_recurring === false ? "una_vez" : (FREQ[p.recurrence_type ?? "monthly"] ?? "mensual");
    const every = Math.max(1, p.recurrence_interval ?? 1);
    const converted = convertOn(amount, currency, ctx.preferredCurrency, ctx.todayUtc, ctx.rates);
    if (converted && converted.quality !== "exact") approximate = true;

    const skipped = skippedKeys(p);
    let first: Day | null = null;
    for (const mo of months) {
      for (const d of paymentDatesInMonth(p, mo, ctx.tz, ctx.firstWeekday ?? 2)) {
        if (d < ctx.today || d > until || skipped.has(skipKey(d, ctx.tz))) continue;
        if (!first) first = d;
        proximos.push({
          id: p.sync_id,
          nombre: p.name ?? "(sin nombre)",
          dia: d,
          en_dias: dayDiff(ctx.today, d),
          importe: round2(amount),
          divisa: currency,
          importe_en_divisa_preferida: converted ? round2(converted.value) : null,
          movimiento: isExpense ? "gasto" : "ingreso",
          tipo: kind,
          frecuencia: freq,
          cada: every,
          categoria: label,
        });
        if (isExpense && converted) total += converted.value;
      }
    }

    if (kind === "suscripcion" && isExpense) {
      const monthly = convertOn(amount * monthlyMultiplier(p), currency, ctx.preferredCurrency, ctx.todayUtc, ctx.rates);
      if (monthly) subsMonthly += monthly.value;
      suscripciones.push({
        id: p.sync_id,
        nombre: p.name ?? "(sin nombre)",
        importe: round2(amount),
        divisa: currency,
        frecuencia: freq,
        cada: every,
        proximo_cobro: first ?? (p.next_due_date ? dayInZone(p.next_due_date, ctx.tz) : null),
        equivalente_mensual_en_divisa_preferida: monthly ? round2(monthly.value) : null,
        categoria: label,
      });
    }
  }

  proximos.sort((a, b) => (a.dia === b.dia ? a.nombre.localeCompare(b.nombre, "es") : a.dia < b.dia ? -1 : 1));
  suscripciones.sort(
    (a, b) => (b.equivalente_mensual_en_divisa_preferida ?? 0) - (a.equivalente_mensual_en_divisa_preferida ?? 0) || a.nombre.localeCompare(b.nombre, "es"),
  );
  return {
    divisa: ctx.preferredCurrency,
    desde: ctx.today,
    hasta: until,
    proximos,
    total_gastos: round2(total),
    suscripciones,
    suscripciones_mensual: round2(subsMonthly),
    aproximado: approximate,
  };
}
