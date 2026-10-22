import type { AccountRow, BudgetRow, CategoryRow, ScheduledPaymentRow, SubcategoryRow, TagRow, TxRow } from "../src/logic/types";

let seq = 0;
export function uuid(n?: number): string {
  const v = (n ?? ++seq).toString(16).padStart(12, "0");
  return `00000000-0000-4000-8000-${v}`;
}

export function account(p: Partial<AccountRow> & { sync_id: string }): AccountRow {
  return {
    name: "Cuenta",
    currency_code: "PEN",
    type: "checking",
    is_archived: false,
    exclude_from_statistics: false,
    is_system_account: false,
    ...p,
  };
}

export function category(p: Partial<CategoryRow> & { sync_id: string }): CategoryRow {
  return { name: "Cat", is_income: false, is_visible: true, sort_order: 0, ...p };
}

export function subcategory(p: Partial<SubcategoryRow> & { sync_id: string }): SubcategoryRow {
  return { name: "Sub", category_ref: null, nature_raw_value: null, is_visible: true, sort_order: 0, ...p };
}

export function tag(p: Partial<TagRow> & { sync_id: string }): TagRow {
  return { name: "tag", ...p };
}

export function tx(p: Partial<TxRow>): TxRow {
  return {
    sync_id: uuid(),
    date: "2026-09-10T15:00:00Z",
    local_day: null,
    amount: -10,
    currency_code: "PEN",
    note: null,
    category_ref: null,
    subcategory_ref: null,
    account_ref: null,
    tag_refs: null,
    amount_in_preferred_currency: null,
    preferred_currency_code: null,
    is_exchange_rate_provisional: false,
    need_override: null,
    scheduled_payment_ref: null,
    balance_adjustment_type: null,
    transfer_pair_id: null,
    split_expense_id: null,
    ...p,
  };
}

export function budget(p: Partial<BudgetRow> & { sync_id: string }): BudgetRow {
  return {
    name: "Presupuesto",
    currency_code: "PEN",
    limit_amount: 100,
    period_type: "monthly",
    start_date: null,
    end_date: null,
    natures: null,
    subcategory_ids: [],
    account_ids: [],
    tag_refs: [],
    is_active: true,
    include_shared_expenses: true,
    ...p,
  };
}

export function scheduled(p: Partial<ScheduledPaymentRow> & { sync_id: string }): ScheduledPaymentRow {
  return {
    name: "Pago",
    amount: 10,
    currency_code: "PEN",
    transaction_type: "expense",
    is_recurring: true,
    recurrence_type: "monthly",
    recurrence_interval: 1,
    next_due_date: "2026-10-05T12:00:00Z",
    end_date: null,
    payment_category: "subscription",
    is_active: true,
    last_paid_date: null,
    subcategory_ref: null,
    account_ref: null,
    ...p,
  };
}
