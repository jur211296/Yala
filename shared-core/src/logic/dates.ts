/**
 * Días y periodos en la zona horaria del usuario.
 *
 * Todo el MCP razona en DÍAS (`YYYY-MM-DD`) inclusivos en los dos extremos, no en instantes. Así desaparece la
 * trampa de `DateInterval` cerrado que documenta el CLAUDE.md («Cálculos con fechas»): «septiembre» es del
 * 2026-09-01 al 2026-09-30, y un movimiento del 1 de octubre a medianoche es del 1 de octubre y de nadie más.
 *
 * El día de un movimiento es `local_day` si el teléfono lo mandó —es el día que vio el usuario— y si no, `date`
 * pasado a la zona pedida. Medido el 2026-09-26: `local_day` falta en 1142 de 4465 movimientos de staging.
 */

export type Day = string;

const DAY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

export class InvalidInputError extends Error {}

export function assertTimeZone(tz: string): string {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return tz;
  } catch {
    throw new InvalidInputError(`Zona horaria desconocida: ${tz}`);
  }
}

export function assertDay(day: string, field: string): Day {
  const m = DAY_RE.exec(day);
  if (!m) throw new InvalidInputError(`${field} debe ser una fecha AAAA-MM-DD`);
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  if (toDay(d) !== day) throw new InvalidInputError(`${field} no es una fecha válida`);
  return day;
}

function toDay(d: Date): Day {
  return d.toISOString().slice(0, 10);
}

function parseDay(day: Day): Date {
  const m = DAY_RE.exec(day);
  if (!m) throw new InvalidInputError(`Fecha no válida: ${day}`);
  return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
}

const partsCache = new Map<string, Intl.DateTimeFormat>();
function formatter(tz: string): Intl.DateTimeFormat {
  let f = partsCache.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
    partsCache.set(tz, f);
  }
  return f;
}

function zonedParts(instant: Date, tz: string): { y: number; mo: number; d: number; h: number; mi: number; s: number } {
  const out: Record<string, number> = {};
  for (const p of formatter(tz).formatToParts(instant)) {
    if (p.type !== "literal") out[p.type] = Number(p.value);
  }
  return { y: out.year ?? 0, mo: out.month ?? 0, d: out.day ?? 0, h: out.hour ?? 0, mi: out.minute ?? 0, s: out.second ?? 0 };
}

/** Día civil de un instante en una zona. */
export function dayInZone(instant: Date | string, tz: string): Day {
  const d = typeof instant === "string" ? new Date(instant) : instant;
  const p = zonedParts(d, tz);
  return `${String(p.y).padStart(4, "0")}-${String(p.mo).padStart(2, "0")}-${String(p.d).padStart(2, "0")}`;
}

/** Desfase de la zona en ese instante, en ms (Lima → -5 h). */
function offsetMs(instant: Date, tz: string): number {
  const p = zonedParts(instant, tz);
  const asUtc = Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, p.s);
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

/** Instante en que empieza ese día en esa zona. Corrige una vez por si el cambio de hora cae en medio. */
export function zonedDayStartUtc(day: Day, tz: string): Date {
  const guess = parseDay(day).getTime();
  let t = guess - offsetMs(new Date(guess), tz);
  t = guess - offsetMs(new Date(t), tz);
  // Zonas que adelantan la hora A medianoche (Santiago, Asunción, La Habana…): ese día no tiene 00:00 y el
  // cálculo cae en la última hora del día anterior. El día empieza entonces a la 01:00 local.
  for (let i = 0; i < 3 && dayInZone(new Date(t), tz) < day; i++) t += 3_600_000;
  return new Date(t);
}

export function addDays(day: Day, n: number): Day {
  const d = parseDay(day);
  d.setUTCDate(d.getUTCDate() + n);
  return toDay(d);
}

export function monthStart(day: Day): Day {
  return `${day.slice(0, 7)}-01`;
}

export function monthEnd(day: Day): Day {
  const d = parseDay(monthStart(day));
  d.setUTCMonth(d.getUTCMonth() + 1);
  d.setUTCDate(0);
  return toDay(d);
}

export function addMonths(day: Day, n: number): Day {
  const d = parseDay(monthStart(day));
  d.setUTCMonth(d.getUTCMonth() + n);
  return toDay(d);
}

export function yearStart(day: Day): Day {
  return `${day.slice(0, 4)}-01-01`;
}

export function yearEnd(day: Day): Day {
  return `${day.slice(0, 4)}-12-31`;
}

/**
 * Primer día de la semana que contiene `day`. `firstWeekday` sigue la convención de la app
 * (`userConfiguredCalendar`): 1 = domingo, 2 = lunes; por defecto lunes.
 */
export function weekStart(day: Day, firstWeekday: 1 | 2 = 2): Day {
  const dow = parseDay(day).getUTCDay(); // 0 = domingo
  const first = firstWeekday === 1 ? 0 : 1;
  return addDays(day, -((dow - first + 7) % 7));
}

/** Días entre dos días, contando los dos extremos. */
export function daysInclusive(from: Day, to: Day): number {
  return Math.round((parseDay(to).getTime() - parseDay(from).getTime()) / 86_400_000) + 1;
}

export function minDay(a: Day, b: Day): Day {
  return a <= b ? a : b;
}

/** Día en que cuenta un movimiento: el que vio el usuario si lo tenemos, si no el de `date` en la zona pedida. */
export function txDay(tx: { local_day: string | null; date: string | null }, tz: string): Day | null {
  if (tx.local_day && DAY_RE.test(tx.local_day)) return tx.local_day;
  if (!tx.date) return null;
  const d = new Date(tx.date);
  if (Number.isNaN(d.getTime())) return null;
  return dayInZone(d, tz);
}

export interface Period {
  desde: Day;
  hasta: Day;
  etiqueta: string;
}

export type PeriodKind = "mes_actual" | "mes_pasado" | "semana_actual" | "anio_actual" | "rango";

export function resolvePeriod(
  kind: PeriodKind,
  today: Day,
  opts: { desde?: string; hasta?: string; firstWeekday?: 1 | 2 } = {},
): Period {
  switch (kind) {
    case "mes_actual":
      return { desde: monthStart(today), hasta: today, etiqueta: `mes en curso (${today.slice(0, 7)})` };
    case "mes_pasado": {
      const start = addMonths(today, -1);
      return { desde: start, hasta: monthEnd(start), etiqueta: `mes pasado (${start.slice(0, 7)})` };
    }
    case "semana_actual":
      return { desde: weekStart(today, opts.firstWeekday ?? 2), hasta: today, etiqueta: "semana en curso" };
    case "anio_actual":
      return { desde: yearStart(today), hasta: today, etiqueta: `año en curso (${today.slice(0, 4)})` };
    case "rango": {
      if (!opts.desde || !opts.hasta) throw new InvalidInputError("Con periodo=rango hacen falta desde y hasta");
      const desde = assertDay(opts.desde, "desde");
      const hasta = assertDay(opts.hasta, "hasta");
      if (desde > hasta) throw new InvalidInputError("desde no puede ser posterior a hasta");
      if (daysInclusive(desde, hasta) > 366 * 3) throw new InvalidInputError("El rango máximo es de tres años");
      return { desde, hasta, etiqueta: `del ${desde} al ${hasta}` };
    }
  }
}
