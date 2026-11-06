/**
 * Números y frases en español, sin `Intl` (el redondeo y la separación tienen que salir iguales en el Worker y en los
 * tests): miles con punto, decimales con coma — «3.050», «15,3».
 *
 * PRIVACIDAD (propuesta §4): un corte de 1 o 2 personas no se pinta con su cifra, se dice «menos de 3». `people()` es
 * la única forma de escribir un conteo de personas o aparatos en el panel.
 */
export function int(n: number): string {
  const r = Math.round(n);
  const s = String(Math.abs(r)).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return r < 0 ? `-${s}` : s;
}

export function dec(n: number, digits = 1): string {
  const fixed = Math.abs(n).toFixed(digits);
  const [i, d] = fixed.split(".");
  const body = d && Number(d) !== 0 ? `${int(Number(i))},${d}` : int(Number(i));
  return n < 0 && Number(fixed) !== 0 ? `-${body}` : body;
}

export function usd(n: number): string {
  if (n > 0 && n < 0.01) return "menos de 1 centavo";
  const [i, d] = Math.abs(n).toFixed(2).split(".");
  return `US$ ${int(Number(i))},${d}`;
}

/** Conteo de personas/aparatos con su sustantivo. 0 → «0 personas»; 1-2 → «menos de 3 personas». */
export function people(n: number, singular: string, plural: string): string {
  if (n <= 0) return `0 ${plural}`;
  if (n < 3) return `menos de 3 ${plural}`;
  return `${int(n)} ${n === 1 ? singular : plural}`;
}

/** La cifra sola, con la misma regla de privacidad (para las tarjetas grandes). */
export function peopleNum(n: number): string {
  if (n > 0 && n < 3) return "< 3";
  return int(n);
}

/** La cifra en una frase, con la regla de privacidad: 1-2 → «menos de 3». */
export function peopleText(n: number): string {
  return n > 0 && n < 3 ? "menos de 3" : int(n);
}

/** «2 más que la semana pasada» / «3 menos que…» / «igual que…». */
export function vsLastWeek(cur: number, prev: number, unit = ""): string {
  const d = Math.round(cur) - Math.round(prev);
  const u = unit ? ` ${unit}` : "";
  if (d === 0) return "igual que la semana pasada";
  return d > 0 ? `${int(d)}${u} más que la semana pasada` : `${int(-d)}${u} menos que la semana pasada`;
}

/** «6 de cada 10». */
export function outOfTen(part: number, whole: number): string {
  if (whole <= 0) return "—";
  return `${Math.round((part / whole) * 10)} de cada 10`;
}

export function pct(part: number, whole: number): string {
  if (whole <= 0) return "—";
  const p = (part / whole) * 100;
  return `${p >= 99.5 && part < whole ? "99" : Math.round(p)} %`;
}

const WEEKDAYS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
const MONTHS = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];

/** «jueves 30 de octubre». */
export function longDay(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  return `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} de ${MONTHS[d.getUTCMonth()]}`;
}

/** «30 de oct». */
export function shortDay(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  return `${d.getUTCDate()} de ${MONTHS[d.getUTCMonth()].slice(0, 3)}`;
}

/** «del 30 de oct al 5 de nov de 2026». */
export function weekLabel(from: string, to: string): string {
  return `del ${shortDay(from)} al ${shortDay(to)} de ${to.slice(0, 4)}`;
}

export function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
