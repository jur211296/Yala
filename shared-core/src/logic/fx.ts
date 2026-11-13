/**
 * Conversión de divisas con la tabla de tasas que el propio usuario sincroniza (`exchange_rates`), con las mismas
 * reglas que `CurrencyConverter` de la app (Yala/Services/CurrencyConverter.swift).
 *
 * Cada fila es un día (`date_key`, día UTC) con `rates` = unidades de cada divisa por 1 USD. La app IGNORA la columna
 * `base` y trata todas las filas como relativas a USD (`performConversion`); aquí también.
 *
 * - Tasa de un día: port de `resolveRates(for:needing:)`. La fila de ese día; lo que le falte, de las 30 filas
 *   ESTRICTAMENTE anteriores, de la más reciente hacia atrás; y lo que siga faltando, de la tabla estática
 *   `CurrencyCode.fallbackRates`. Nunca se mira una fila posterior.
 * - La clave del día es el día UTC del instante (`date`), no el día local: la app formatea `tx.date` con un
 *   `DateFormatter` en UTC.
 * - «Tasa de hoy» (saldos, presupuestos, recurrentes) es la misma función con el día UTC de ahora, que es lo que
 *   resuelven `convertCheckedWithLatestRate` y `convert(on: now)`.
 * - Calidad: `exact` si todo salió de la fila del día, `carried` si algo vino de una anterior, `static` si algo vino
 *   de la tabla estática. Todo lo que no es `exact` es aproximado, igual que el «≈» de la app.
 *
 * Diferencia deliberada: un código de divisa que no es uno de los 54 de la app NO se convierte (la app lo colapsa a
 * USD en `normalizeCurrencyCode`, y eso tiene su ticket: `fx-unknown-currency-code-collapses-to-usd`). Aquí la cifra
 * queda fuera y se avisa, en vez de sumar un importe con la divisa equivocada.
 *
 * Filas duplicadas para un mismo día (medido en staging: cientos de días con dos o tres filas, una por dispositivo,
 * con valores distintos): la app coge la primera que le devuelve SwiftData, sin orden, así que no hay una cifra de la
 * app que copiar. Aquí se funden en una, divisa por divisa, con una regla determinista (ver `buildRateBook`).
 */
import type { ExchangeRateRow } from "./types";
import { STATIC_RATES_PER_USD } from "./fx-static";

export type RateQuality = "exact" | "carried" | "static";

/** Filas de tasas ya fundidas: una por día, solo con tasas utilizables. */
export interface RateBook {
  /** Días con fila, de más antiguo a más reciente. */
  days: string[];
  byDay: Map<string, Map<string, number>>;
  /**
   * Cuántas filas hay de cada día. La ventana hacia atrás de la app es de 30 FILAS, no de 30 días: con dos filas por
   * día (una por dispositivo) llega solo a 15 días.
   */
  rowsPerDay: Map<string, number>;
}

/** Cuántas filas anteriores mira como mucho la app al completar un día (`carryForwardLookback`). */
export const CARRY_FORWARD_LOOKBACK = 30;

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

/** `CurrencyConverter.isUsableRate`: finita y estrictamente positiva. */
function usable(v: number | null): v is number {
  return v !== null && Number.isFinite(v) && v > 0;
}

/**
 * Una tasa como la lee `ExchangeRate.decodedRates`: un número JSON (no un booleano) o un texto que `Double(_:)` de
 * Swift acepte entero —sin espacios ni otros restos—. Cualquier otra cosa no es una tasa.
 */
function parseRate(raw: unknown): number | null {
  if (typeof raw === "number") return raw;
  if (typeof raw === "string" && /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(raw)) return Number(raw);
  return null;
}

/**
 * Los 54 códigos que la app conoce. Otro código no se convierte (ver cabecera). Tampoco los alias que la app acepta
 * al normalizar («S/.», «SOLES», «US$»…): el wire trae el código ya normalizado, y si algún día trae otra cosa, la
 * cifra queda fuera y se avisa en vez de adivinar.
 */
export function normalizeCode(raw: string | null | undefined): string | null {
  if (raw === null || raw === undefined) return null;
  const c = raw.trim().toUpperCase();
  return STATIC_RATES_PER_USD[c] !== undefined ? c : null;
}

/**
 * Funde las filas en una por día. Si dos filas del mismo día traen la misma divisa, gana la de `timestamp` más
 * reciente (sin `timestamp` = la más vieja); a igualdad, la que trae más divisas; y a igualdad, el `sync_id` mayor.
 */
export function buildRateBook(rows: ExchangeRateRow[]): RateBook {
  const tsOf = (r: ExchangeRateRow) => {
    const t = r.timestamp ? Date.parse(r.timestamp) : Number.NaN;
    return Number.isNaN(t) ? Number.NEGATIVE_INFINITY : t;
  };
  const sizeOf = (r: ExchangeRateRow) => (r.rates ? Object.keys(r.rates).length : 0);
  // De menos a más prioritaria: la última escritura gana.
  const ordered = rows
    .filter((r) => r.date_key && DAY_RE.test(r.date_key) && r.rates && typeof r.rates === "object")
    .sort((a, b) => tsOf(a) - tsOf(b) || sizeOf(a) - sizeOf(b) || (a.sync_id ?? "").localeCompare(b.sync_id ?? ""));
  const byDay = new Map<string, Map<string, number>>();
  const rowsPerDay = new Map<string, number>();
  // Una fila con `rates` vacío o ilegible también ocupa hueco en las 30 filas de la app.
  for (const r of rows) {
    if (r.date_key && DAY_RE.test(r.date_key)) rowsPerDay.set(r.date_key, (rowsPerDay.get(r.date_key) ?? 0) + 1);
  }
  for (const r of ordered) {
    const day = r.date_key as string;
    const m = byDay.get(day) ?? new Map<string, number>();
    // La clave tal cual: la app busca `rates["EUR"]` literal, y una «eur» no la encuentra.
    for (const [code, raw] of Object.entries(r.rates as Record<string, unknown>)) {
      const v = parseRate(raw);
      if (usable(v)) m.set(code, v);
    }
    byDay.set(day, m);
  }
  for (const day of rowsPerDay.keys()) if (!byDay.has(day)) byDay.set(day, new Map());
  return { days: [...byDay.keys()].sort(), byDay, rowsPerDay };
}

export interface ResolvedRates {
  rates: Map<string, number>;
  quality: RateQuality;
}

/** Port de `CurrencyConverter.resolveRates(for:needing:context:)`. */
export function resolveRates(book: RateBook, dateKey: string, needing: string[]): ResolvedRates {
  const merged = new Map(book.byDay.get(dateKey) ?? []);
  const missing = () => needing.filter((c) => !merged.has(c));

  if (merged.size > 0 && missing().length === 0) return { rates: merged, quality: "exact" };

  let carried = false;
  if (missing().length > 0) {
    // Días estrictamente anteriores, del más reciente hacia atrás, hasta completar 30 FILAS (`fetchLimit = 30`).
    const before = book.days.filter((d) => d < dateKey);
    for (let i = before.length - 1, seen = 0; i >= 0 && seen < CARRY_FORWARD_LOOKBACK; i--) {
      seen += book.rowsPerDay.get(before[i] as string) ?? 1;
      const prev = book.byDay.get(before[i] as string);
      if (!prev) continue;
      for (const code of missing()) {
        const v = prev.get(code);
        if (v === undefined) continue;
        merged.set(code, v);
        carried = true;
      }
      if (missing().length === 0) break;
    }
  }

  let usedStatic = false;
  for (const code of missing()) {
    const v = STATIC_RATES_PER_USD[code];
    if (v !== undefined && usable(v)) {
      merged.set(code, v);
      usedStatic = true;
    }
  }

  if (merged.size === 0) return { rates: new Map(Object.entries(STATIC_RATES_PER_USD)), quality: "static" };
  if (usedStatic) return { rates: merged, quality: "static" };
  if (carried) return { rates: merged, quality: "carried" };
  return { rates: merged, quality: "exact" };
}

export interface Converted {
  value: number;
  quality: RateQuality;
}

/**
 * Convierte `amount` de `from` a `to` con las tasas del día `dateKey` (día UTC). Conserva el signo. `null` si alguna
 * de las dos divisas no es una de las que la app conoce.
 */
export function convertOn(amount: number, from: string | null, to: string | null, dateKey: string, book: RateBook): Converted | null {
  const f = normalizeCode(from);
  const t = normalizeCode(to);
  if (!f || !t) return null;
  if (f === t) return { value: amount, quality: "exact" };
  const { rates, quality } = resolveRates(book, dateKey, [f, t]);
  const rf = rates.get(f);
  const rt = rates.get(t);
  // `performConversion` devuelve el importe crudo si falta una tasa; con la tabla estática no puede faltar.
  if (!usable(rf ?? null) || !usable(rt ?? null)) return null;
  const rfv = rf as number;
  const rtv = rt as number;
  let value: number;
  if (f === "USD") value = amount * rtv;
  else if (t === "USD") value = amount / rfv;
  else value = (amount / rfv) * rtv;
  return { value, quality };
}

/** Día UTC de un instante ISO, que es la clave con la que la app busca la fila de tasas. */
export function utcDateKey(instant: string | Date): string | null {
  const d = typeof instant === "string" ? new Date(instant) : instant;
  return Number.isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}
