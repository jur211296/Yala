/**
 * Lectura de PostgREST con el token del USUARIO: la sesión de Supabase de solo lectura que el Worker guarda cifrada
 * (nunca la de Claude, que no es un token de Supabase). Nunca `service_role`: el filtro por usuario lo pone RLS, y
 * con `role = yala_mcp_reader` PostgREST no deja hacer nada que no sea SELECT.
 *
 * Solo hay GET, y además todo sale por la lista cerrada de `egress.ts`. Este módulo no tiene ninguna forma de
 * escribir, a propósito: la herramienta que escriba (fase 3) irá en otro módulo y en otra herramienta, como pide la
 * revisión de Anthropic.
 */
import type { Env } from "./env";
import { defaultFetch, guardSupabase, type Fetcher } from "./egress";

export type { Fetcher } from "./egress";

export class UpstreamError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/** Tope de filas por consulta. Protege la latencia del Worker; si se alcanza, se avisa en la respuesta. */
export const MAX_ROWS = 20_000;
const PAGE = 1000;

export interface ReadResult<T> {
  rows: T[];
  truncated: boolean;
}

export class YalaReader {
  private readonly fetcher: Fetcher;

  constructor(
    private readonly env: Env,
    private readonly token: string,
    fetcher: Fetcher = defaultFetch,
  ) {
    this.fetcher = guardSupabase(env, fetcher);
  }

  private url(table: string, params: [string, string][]): string {
    const u = new URL(`${this.env.SUPABASE_URL.replace(/\/+$/, "")}/rest/v1/${table}`);
    for (const [k, v] of params) u.searchParams.append(k, v);
    return u.toString();
  }

  private async page<T>(table: string, params: [string, string][], offset: number, limit: number): Promise<T[]> {
    const res = await this.fetcher(this.url(table, [...params, ["limit", String(limit)], ["offset", String(offset)]]), {
      method: "GET",
      headers: {
        apikey: this.env.SUPABASE_ANON_KEY,
        Authorization: `Bearer ${this.token}`,
        Accept: "application/json",
      },
    });
    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new UpstreamError(res.status, `PostgREST ${table} ${res.status}: ${body.slice(0, 200)}`);
    }
    return (await res.json()) as T[];
  }

  /**
   * Lee todas las filas que casan, por páginas, hasta `max`. Para solo cuando una página llega VACÍA: si el
   * proyecto tuviera un `max_rows` por debajo de `PAGE`, una página corta no significa «ya no hay más».
   */
  async all<T>(table: string, params: [string, string][], max = MAX_ROWS): Promise<ReadResult<T>> {
    const rows: T[] = [];
    while (rows.length < max) {
      const batch = await this.page<T>(table, params, rows.length, Math.min(PAGE, max - rows.length));
      if (batch.length === 0) return { rows, truncated: false };
      rows.push(...batch);
    }
    return { rows, truncated: true };
  }

  /** Una sola página, para listados paginados por cursor. */
  async one<T>(table: string, params: [string, string][], limit: number): Promise<T[]> {
    return this.page<T>(table, params, 0, limit);
  }
}

export const COLUMNS = {
  accounts: "sync_id,name,currency_code,type,is_archived,exclude_from_statistics,is_system_account",
  categories: "sync_id,name,is_income,is_visible,sort_order",
  subcategories: "sync_id,name,category_ref,nature_raw_value,is_visible,sort_order,is_system,is_default_seed",
  tags: "sync_id,name",
  tx:
    "sync_id,date,local_day,amount,currency_code,note,category_ref,subcategory_ref,account_ref,tag_refs," +
    "amount_in_preferred_currency,preferred_currency_code,is_exchange_rate_provisional,need_override," +
    "scheduled_payment_ref,balance_adjustment_type,transfer_pair_id,split_expense_id",
  txBalance: "account_ref,amount,currency_code",
  budgets:
    "sync_id,name,currency_code,limit_amount,period_type,start_date,end_date,natures,subcategory_ids,account_ids,tag_refs," +
    "is_active,include_shared_expenses",
  scheduled:
    "sync_id,name,amount,currency_code,transaction_type,is_recurring,recurrence_type,recurrence_interval,next_due_date,end_date," +
    "payment_category,is_active,last_paid_date,subcategory_ref,account_ref",
  rates: "sync_id,date_key,base,rates,timestamp",
  prefs: "key,value",
} as const;

/** Filtro común: las filas borradas son lápidas del sync (`deleted = true`), no datos. */
export const NOT_DELETED: [string, string] = ["deleted", "is.false"];
