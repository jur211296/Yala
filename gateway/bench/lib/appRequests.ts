import { interpolate, readRepoFile, swiftMultilineAfter } from "./swift";

/**
 * Cuerpos de Chat Completions IDÉNTICOS a los que manda la app hoy para las tres tareas de
 * gpt-4.1-nano, construidos desde su código Swift (prompts) y la forma que serializa el SDK MacPaw 0.4.7
 * (`stream` siempre presente, `content` de sistema como string, imagen como data URL `image/jpeg`).
 *
 * Los usan el banco (para medir lo que la app pide de verdad) y los tests del gateway (para deducir la
 * tarea con cuerpos reales).
 */

const PATHS = {
  vision: "Yala/App/Services/ImageVision/ImageVisionService.swift",
  dateContext: "Yala/App/Services/DateContextProvider.swift",
  intent: "Yala/Services/Chat/ChatIntentClassifierService.swift",
  suggestions: "Yala/App/Services/ChatSuggestionsLLMService.swift",
} as const;

const DAY_EN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const DAY_ES = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];

function iso(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function addDays(d: Date, n: number): Date {
  return new Date(d.getTime() + n * 86_400_000);
}

/** Réplica de `DateContextProvider.buildDateContext(now:)` con la semana empezando en lunes (default). */
export function dateContext(todayIso: string): string {
  const now = new Date(`${todayIso}T12:00:00Z`);
  const wd = now.getUTCDay(); // 0 = domingo
  const ordered = [1, 2, 3, 4, 5, 6, 0];
  const lookup = ordered
    .map((target) => {
      let back = (wd - target + 7) % 7;
      if (back === 0) back = 7;
      return `- "el ${DAY_ES[target]}" / "${DAY_EN[target]}" → ${iso(addDays(now, -back))}`;
    })
    .join("\n");
  const mondayThisWeek = addDays(now, -((wd + 6) % 7));
  const lastMonday = addDays(mondayThisWeek, -7);
  const lastWeekRange = `${iso(lastMonday)} a ${iso(addDays(lastMonday, 6))}`;
  const year = now.getUTCFullYear();
  const tpl = swiftMultilineAfter(readRepoFile(PATHS.dateContext), "static func buildDateContext");
  return interpolate(tpl, {
    todayDayEN: DAY_EN[wd],
    todayDayES: DAY_ES[wd],
    today: todayIso,
    yesterday: iso(addDays(now, -1)),
    dayBefore: iso(addDays(now, -2)),
    weekdayLookup: lookup,
    lastWeekRange,
    currentYear: String(year),
    "currentYear - 1": String(year - 1),
  });
}

export function photoSystemPrompt(todayIso: string): string {
  const tpl = swiftMultilineAfter(readRepoFile(PATHS.vision), "private var systemPrompt: String {");
  return interpolate(tpl, { dateContext: dateContext(todayIso) });
}

/** `currencyContext`: la divisa principal y las de las cuentas del usuario, como las manda la app (sesión 2, D9). */
export function photoReadBody(jpegBase64: string, todayIso: string, _currencyContext?: string): Record<string, unknown> {
  const wd = new Date(`${todayIso}T12:00:00Z`).getUTCDay();
  return {
    messages: [
      { role: "system", content: photoSystemPrompt(todayIso) },
      {
        role: "user",
        content: [
          { type: "text", text: `Extract transactions from this image. Today is ${DAY_EN[wd]}, ${todayIso}.` },
          { type: "image_url", image_url: { url: `data:image/jpeg;base64,${jpegBase64}`, detail: "auto" } },
        ],
      },
    ],
    model: "gpt-4.1-nano",
    response_format: { type: "json_object" },
    stream: false,
  };
}

export function intentSystemPrompt(): string {
  return swiftMultilineAfter(readRepoFile(PATHS.intent), "private static func buildSystemPrompt() -> String {");
}

export function intentBody(text: string): Record<string, unknown> {
  return {
    messages: [
      { role: "system", content: intentSystemPrompt() },
      { role: "user", content: `Texto del usuario: "${text}"\n\nResponde SOLO con el JSON.` },
    ],
    model: "gpt-4.1-nano",
    response_format: { type: "json_object" },
    temperature: 0,
    stream: false,
  };
}

export interface SuggestionsContext {
  /** `AppLocale.current.identifier`, p. ej. `es-PE`, `pt-BR`, `zh-Hans`. */
  language: string;
  topCategories: string[];
  subcategoryNames: string[];
  merchantNames: string[];
  activeBudgets: string[];
  tagNames: string[];
  recurringPaidNames: string[];
  totalIncome: number;
  totalExpense: number;
}

export function suggestionsSystemPrompt(language: string): string {
  const src = readRepoFile(PATHS.suggestions);
  const marker = "private func buildSystemPrompt(language: String) -> String {";
  // Mismo criterio que la app: `SupportedLocale.from(language)?.code.hasPrefix("es") ?? language.hasPrefix("es")`.
  const isSpanish = language.startsWith("es");
  const example = swiftMultilineAfter(src, marker, isSpanish ? 0 : 1);
  return interpolate(swiftMultilineAfter(src, marker, 2), { language, example });
}

/** Réplica de `buildUserPrompt(context:)` (etiquetas en inglés a propósito, ver el Swift). */
export function suggestionsUserPrompt(ctx: SuggestionsContext): string {
  const parts: string[] = [];
  if (ctx.topCategories.length) parts.push(`Top categories: ${ctx.topCategories.join(", ")}`);
  if (ctx.subcategoryNames.length) parts.push(`Subcategories: ${ctx.subcategoryNames.slice(0, 20).join(", ")}`);
  if (ctx.merchantNames.length) parts.push(`Frequent merchants: ${ctx.merchantNames.join(", ")}`);
  if (ctx.activeBudgets.length) parts.push(`Active budgets: ${ctx.activeBudgets.join(", ")}`);
  if (ctx.tagNames.length) parts.push(`Tags: ${ctx.tagNames.join(", ")}`);
  if (ctx.recurringPaidNames.length) parts.push(`Recurring paid this month: ${ctx.recurringPaidNames.join(", ")}`);
  parts.push(`Month income: ${Math.trunc(ctx.totalIncome)}`);
  parts.push(`Month expenses: ${Math.trunc(ctx.totalExpense)}`);
  parts.push(`Remember: write ALL 10 suggestions in ${ctx.language}.`);
  return parts.join("\n");
}

export function suggestionsBody(ctx: SuggestionsContext): Record<string, unknown> {
  return {
    messages: [
      { role: "system", content: suggestionsSystemPrompt(ctx.language) },
      { role: "user", content: suggestionsUserPrompt(ctx) },
    ],
    model: "gpt-4.1-nano",
    response_format: { type: "json_object" },
    temperature: 0.7,
    stream: false,
  };
}
