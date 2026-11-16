/**
 * Días en UTC como `AAAA-MM-DD`. Es la misma clave que usa la app para su «uno al día» (`MetricsPingLogic.dayString`) y
 * la que agrupa Analytics Engine, así que un día del panel cuenta lo mismo que el guard del teléfono.
 */
export function dayOf(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function addDays(day: string, n: number): string {
  const t = Date.parse(`${day}T00:00:00Z`) + n * 86_400_000;
  return dayOf(new Date(t));
}

/** Días de `from` a `to`, ambos incluidos. Vacío si `from > to`. */
export function dayRange(from: string, to: string): string[] {
  const out: string[] = [];
  for (let d = from; d <= to; d = addDays(d, 1)) out.push(d);
  return out;
}

/** `true` si `day` cae entre `from` y `to`, ambos incluidos. */
export function within(day: string, from: string, to: string): boolean {
  return day >= from && day <= to;
}
