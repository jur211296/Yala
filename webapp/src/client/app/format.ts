/** Importes, días y tiempos en el idioma de la página. */
import { lang, locale, texts } from "../i18n";

const t = texts();

export function money(amount: number | null | undefined, currency: string | null | undefined, opts: { sign?: boolean } = {}): string {
  if (amount == null || !Number.isFinite(amount)) return "—";
  const code = currency && /^[A-Z]{3}$/.test(currency) ? currency : null;
  const abs = Math.abs(amount);
  let s: string;
  try {
    if (code) {
      // Como en la app: los soles con «S/» en los dos idiomas (en inglés `Intl` escribe «PEN»).
      const parts = new Intl.NumberFormat(locale(), { style: "currency", currency: code, currencyDisplay: "narrowSymbol", minimumFractionDigits: 2, maximumFractionDigits: 2 }).formatToParts(abs);
      s = parts
        .map((p) => (p.type === "currency" && code === "PEN" ? "S/" : p.value))
        .join("")
        .replace(/^S\/(?=\d)/, "S/ ");
    } else {
      s = new Intl.NumberFormat(locale(), { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(abs);
    }
  } catch {
    s = `${abs.toFixed(2)} ${code ?? ""}`.trim();
  }
  if (amount < 0) return `−${s}`;
  return opts.sign && amount > 0 ? `+${s}` : s;
}

function localDay(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function todayKey(): string {
  return localDay(new Date());
}

/** «Hoy», «Ayer» o «lunes 10 de noviembre» para un día `YYYY-MM-DD`. */
export function dayLabel(day: string | null): string {
  if (!day) return "";
  const today = new Date();
  const yesterday = new Date(today.getTime() - 86_400_000);
  if (day === localDay(today)) return t.app.hoy;
  if (day === localDay(yesterday)) return t.app.ayer;
  const [y, m, d] = day.split("-").map(Number);
  const date = new Date(y!, (m ?? 1) - 1, d ?? 1);
  const sameYear = date.getFullYear() === today.getFullYear();
  return new Intl.DateTimeFormat(locale(), { weekday: "long", day: "numeric", month: "long", ...(sameYear ? {} : { year: "numeric" }) }).format(date);
}

export function shortDate(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return new Intl.DateTimeFormat(locale(), { day: "numeric", month: "short" }).format(d);
}

/** «ahora», «hace 3 días». `seconds`: epoch en segundos. */
export function ago(seconds: number): string {
  const diff = Math.max(0, Date.now() / 1000 - seconds);
  if (diff < 120) return t.app.ahora;
  const rtf = new Intl.RelativeTimeFormat(lang(), { numeric: "always", style: "long" });
  const units: [Intl.RelativeTimeFormatUnit, number][] = [
    ["day", 86_400],
    ["hour", 3_600],
    ["minute", 60],
  ];
  for (const [unit, size] of units) {
    if (diff >= size) return rtf.format(-Math.floor(diff / size), unit);
  }
  return t.app.ahora;
}

/** Inicial y color de una categoría, estables por nombre (la app los guarda, pero no viajan a la nube todavía). */
const PALETTE = ["#d97706", "#0891b2", "#6063f1", "#db2777", "#64748b", "#0f7a80", "#e11d48", "#15803d", "#7c3aed", "#b45309"];
export function badge(name: string | null | undefined): { letter: string; color: string } {
  const n = (name ?? "").trim();
  if (!n) return { letter: "·", color: "#8e8e98" };
  let h = 0;
  for (const ch of n) h = (h * 31 + ch.codePointAt(0)!) >>> 0;
  return { letter: [...n][0]!.toLocaleUpperCase(locale()), color: PALETTE[h % PALETTE.length]! };
}

const ACCOUNT_COLORS = ["#1f4fbf", "#0a7a55", "#0b3d91", "#6e2bd9", "#5f5f6c", "#a1356a", "#00727d", "#8a4b08"];
export function accountColor(i: number): string {
  return ACCOUNT_COLORS[i % ACCOUNT_COLORS.length]!;
}
