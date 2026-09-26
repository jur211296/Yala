/**
 * Conversión de divisas con la tabla de tasas que el propio usuario sincroniza (`exchange_rates`).
 *
 * Cada fila es un día (`date_key`) con una base (USD en staging) y `rates` = unidades de cada divisa por 1 unidad
 * de la base. La v0 usa SIEMPRE la fila más reciente —igual que `convertWithLatestRate` en el saldo vivo y en los
 * presupuestos—. Donde la app usa la tasa del día del movimiento (flujos históricos que no están ya en divisa
 * preferida), la cifra sale marcada como aproximada. Portar la tasa por día es fase 1.
 */
import { num, type ExchangeRateRow } from "./types";

export interface RateTable {
  base: string;
  /** Día de la fila más reciente. */
  dateKey: string;
  rates: Map<string, number>;
  /** Divisas cuya tasa salió de una fila anterior porque la más reciente no la traía. */
  filledFromOlder: Set<string>;
}

/**
 * Tasas «de hoy»: la fila más reciente, y para cada divisa que esa fila no traiga, la fila anterior más reciente
 * que sí la tenga. Es el escalón de `CurrencyConverter.convertCheckedWithLatestRate`
 * (Yala/Services/CurrencyConverter.swift:294-318): sin él, una fila parcial dejaría una divisa sin convertir y
 * fuera del total. Solo se funden filas de la misma base. La tabla estática de la app no se porta.
 */
export function latestRateTable(rows: ExchangeRateRow[]): RateTable | null {
  const valid = rows
    .filter((r): r is ExchangeRateRow & { date_key: string; base: string; rates: Record<string, number | string> } =>
      Boolean(r.date_key && r.base && r.rates),
    )
    .sort((a, b) => (a.date_key < b.date_key ? 1 : a.date_key > b.date_key ? -1 : 0));
  const newest = valid[0];
  if (!newest) return null;
  const base = newest.base.toUpperCase();
  const rates = new Map<string, number>([[base, 1]]);
  const filledFromOlder = new Set<string>();
  for (const row of valid) {
    if (row.base.toUpperCase() !== base) continue;
    for (const [code, raw] of Object.entries(row.rates)) {
      const c = code.toUpperCase();
      const v = num(raw as number | string);
      if (v === null || v <= 0 || rates.has(c)) continue;
      rates.set(c, v);
      if (row !== newest) filledFromOlder.add(c);
    }
  }
  return { base, dateKey: newest.date_key, rates, filledFromOlder };
}

/** Convierte `amount` de `from` a `to`. `null` si falta alguna de las dos tasas. Conserva el signo. */
export function convert(amount: number, from: string, to: string, table: RateTable | null): number | null {
  const f = from.toUpperCase();
  const t = to.toUpperCase();
  if (f === t) return amount;
  if (!table) return null;
  const rf = table.rates.get(f);
  const rt = table.rates.get(t);
  if (rf === undefined || rt === undefined) return null;
  return (amount / rf) * rt;
}
