/**
 * Filas tal como las devuelve PostgREST. Casi todo es anulable: el sync es por campo (field-level HLC), y una fila
 * puede llegar a medias. Medido en staging el 2026-09-26: hay movimientos sin `date`, sin `amount` y sin divisa.
 * La lógica salta lo que no puede situar en vez de inventarlo, y lo cuenta.
 *
 * NUMERIC llega como número en JSON (PostgREST lo serializa como número), pero se normaliza con `num()` por si una
 * versión futura lo manda como texto.
 */

export interface AccountRow {
  sync_id: string;
  name: string | null;
  currency_code: string | null;
  type: string | null;
  is_archived: boolean | null;
  exclude_from_statistics: boolean | null;
  is_system_account: boolean | null;
}

export interface CategoryRow {
  sync_id: string;
  name: string | null;
  is_income: boolean | null;
  is_visible: boolean | null;
  sort_order: number | null;
}

export interface SubcategoryRow {
  sync_id: string;
  name: string | null;
  category_ref: string | null;
  nature_raw_value: string | null;
  is_visible: boolean | null;
  sort_order: number | null;
}

export interface TagRow {
  sync_id: string;
  name: string | null;
}

export interface TxRow {
  sync_id: string;
  date: string | null;
  local_day: string | null;
  amount: number | string | null;
  currency_code: string | null;
  note: string | null;
  category_ref: string | null;
  subcategory_ref: string | null;
  account_ref: string | null;
  tag_refs: string[] | null;
  amount_in_preferred_currency: number | string | null;
  preferred_currency_code: string | null;
  is_exchange_rate_provisional: boolean | null;
  need_override: string | null;
  scheduled_payment_ref: string | null;
  balance_adjustment_type: string | null;
  transfer_pair_id: string | null;
  split_expense_id: string | null;
}

export interface BudgetRow {
  sync_id: string;
  name: string | null;
  currency_code: string | null;
  limit_amount: number | string | null;
  period_type: string | null;
  start_date: string | null;
  end_date: string | null;
  natures: string[] | null;
  subcategory_ids: string[] | null;
  account_ids: string[] | null;
  tag_refs: string[] | null;
  is_active: boolean | null;
  include_shared_expenses: boolean | null;
}

export interface ScheduledPaymentRow {
  sync_id: string;
  name: string | null;
  amount: number | string | null;
  currency_code: string | null;
  transaction_type: string | null;
  is_recurring: boolean | null;
  recurrence_type: string | null;
  recurrence_interval: number | null;
  next_due_date: string | null;
  end_date: string | null;
  payment_category: string | null;
  is_active: boolean | null;
  last_paid_date: string | null;
  subcategory_ref: string | null;
  account_ref: string | null;
}

export interface ExchangeRateRow {
  date_key: string | null;
  base: string | null;
  rates: Record<string, number | string> | null;
}

export interface PreferenceRow {
  key: string;
  value: string | null;
}

export function num(v: number | string | null | undefined): number | null {
  if (v === null || v === undefined) return null;
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

/** Redondeo para la salida: la app pinta con 2 decimales; aquí no se inventa precisión. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}
