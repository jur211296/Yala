/**
 * «Comercios en común» — las reglas puras (variante B de la propuesta del 2026-11-22, elegida por Jürgen).
 *
 * Un comercio entra en la lista común cuando varios teléfonos distintos dicen lo mismo:
 * - **Nuevo**: 3 teléfonos o más en el tipo más votado, ese tipo con ≥75 % de los votos y 2 votos de ventaja sobre el
 *   segundo.
 * - **Cambiar uno ya publicado**: lo mismo, pero con 5 teléfonos. Corregir un error cuesta más que cometerlo: frena a
 *   quien quiera envenenar la lista.
 * Los votos que coinciden con lo ya publicado no se guardan (no hacen falta para nada), así que lo pendiente de un
 * comercio publicado son siempre los que proponen otra cosa.
 */
import { PHOTO_MERCHANT_KINDS } from "../ai/routes";

export const MIN_DEVICES_NEW = 3;
export const MIN_DEVICES_CHANGE = 5;
export const MIN_SHARE = 0.75;
export const MIN_LEAD = 2;
/** Aportes por teléfono y semana. Lo que pase de aquí se descarta sin error. */
export const WEEKLY_CAP = 30;
/** Un teléfono aporta solo con 7 días o más desde que se atestó por primera vez. */
export const MIN_DEVICE_AGE_MS = 7 * 24 * 60 * 60 * 1000;
/** Los votos pendientes y los contadores se borran pasadas 13 semanas (~90 días). */
export const RETENTION_WEEKS = 13;
export const MAX_MERCHANT_LENGTH = 40;

/** Tipos que nunca se comparten: alquiler e impuestos dicen demasiado de una persona (a quién le paga). */
const EXCLUDED_KINDS = new Set(["rent", "taxes"]);
export const SHAREABLE_KINDS: ReadonlySet<string> = new Set(
  PHOTO_MERCHANT_KINDS.filter((k) => !EXCLUDED_KINDS.has(k)),
);

/**
 * El comercio tal como se guarda: mayúsculas, espacios colapsados, solo letras, números y espacios. La app ya lo manda
 * limpio (sin sucursal ni razón social); esto es el cinturón del servidor. `null` si no vale (vacío, sin letras, largo).
 */
export function normalizeMerchant(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const text = raw
    .normalize("NFC")
    .toUpperCase()
    .replace(/[^\p{L}\p{N} ]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (text.length < 2 || text.length > MAX_MERCHANT_LENGTH) return null;
  if (!/\p{L}/u.test(text)) return null;
  return text;
}

export function normalizeKind(raw: unknown): string | null {
  return typeof raw === "string" && SHAREABLE_KINDS.has(raw) ? raw : null;
}

/** La semana ISO 8601 de un instante, en UTC: «2026-W47». Ordena bien como texto. */
export function isoWeek(ms: number): string {
  const d = new Date(ms);
  const day = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const weekday = day.getUTCDay() || 7; // lunes = 1 … domingo = 7
  day.setUTCDate(day.getUTCDate() + 4 - weekday); // el jueves de esa semana decide el año
  const yearStart = Date.UTC(day.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((day.getTime() - yearStart) / 86_400_000 + 1) / 7);
  return `${day.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

/** La semana más vieja que se conserva: lo de antes se borra. */
export function retentionCutoffWeek(nowMs: number): string {
  return isoWeek(nowMs - RETENTION_WEEKS * 7 * 86_400_000);
}

/** El día UTC («2026-11-22») con el que se decide si la lista ya se recalculó hoy. */
export function utcDay(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

/**
 * Qué tipo publica un comercio con sus votos pendientes, o `null` si todavía no.
 * @param counts teléfonos por tipo (pendientes).
 * @param publishedKind lo que la lista dice hoy de ese comercio, si lo dice.
 */
export function decide(counts: ReadonlyMap<string, number>, publishedKind: string | null): string | null {
  const ranked = [...counts.entries()].filter(([, n]) => n > 0).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  if (ranked.length === 0) return null;
  const [topKind, topCount] = ranked[0];
  if (topKind === publishedKind) return null;
  const total = ranked.reduce((sum, [, n]) => sum + n, 0);
  const second = ranked[1]?.[1] ?? 0;
  const needed = publishedKind ? MIN_DEVICES_CHANGE : MIN_DEVICES_NEW;
  if (topCount < needed) return null;
  if (topCount / total < MIN_SHARE) return null;
  if (topCount - second < MIN_LEAD) return null;
  return topKind;
}
