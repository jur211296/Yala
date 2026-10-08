import { dateContext } from "../lib/appRequests";
import { interpolate, readRepoFile, swiftMultilineAfter } from "../lib/swift";
import { merchantPresent } from "./metrics";

/**
 * La lectura de la nota, igual que la hace la app hoy (`TranscriptionParserService.parseMultiple`): el prompt
 * de sistema LEÍDO del Swift, las subcategorías semilla de la app en el idioma de la persona (las que tendría un
 * usuario recién llegado, leídas de `CategorySeed.swift` + `L10n.swift` + `Localizable.strings`), el mismo
 * modelo (`gpt-4.1-mini`) y la misma temperatura (0.1), con el cuerpo que serializa el SDK MacPaw.
 * Después, la decodificación de la app (`parseMultipleResponse`): si la app la rechazaría, es fallo.
 */

const PATHS = {
  parser: "Yala/Services/TranscriptionParserService.swift",
  seed: "Yala/Seed/CategorySeed.swift",
  l10n: "Yala/Utils/L10n.swift",
};

export const PARSER_MODEL = "gpt-4.1-mini";
export const PARSER_TEMPERATURE = 0.1;
/** USD por 1M tokens (developers.openai.com/api/docs/pricing, 2026-10-07). */
export const PARSER_PRICE = { input: 0.4, cachedInput: 0.1, output: 1.6 };

// ---------- subcategorías semilla, en el idioma de la persona ----------

let seedKeys: { expense: string[]; income: string[] } | null = null;

function seedSubcategoryKeys(): { expense: string[]; income: string[] } {
  if (seedKeys) return seedKeys;
  const l10n = readRepoFile(PATHS.l10n);
  const start = l10n.indexOf("    enum Subcategory {");
  const block = l10n.slice(start, l10n.indexOf("        enum System {", start));
  const keyOf = new Map<string, string>();
  for (const m of block.matchAll(/static var (\w+): String \{\s*ls\("([^"]+)"/g)) keyOf.set(m[1], m[2]);
  const seed = readRepoFile(PATHS.seed);
  // Solo la semilla del usuario (antes de las categorías de sistema de Grupos).
  const body = seed.slice(0, seed.indexOf("L10n.Category.System"));
  const expense: string[] = [];
  const income: string[] = [];
  let isIncome = false;
  for (const m of body.matchAll(/isIncome: (true|false)|L10n\.Subcategory\.(\w+)/g)) {
    if (m[1]) isIncome = m[1] === "true";
    else {
      const key = keyOf.get(m[2]);
      if (!key) throw new Error(`parse: sin clave L10n para Subcategory.${m[2]}`);
      (isIncome ? income : expense).push(key);
    }
  }
  if (expense.length < 20 || income.length < 5) throw new Error(`parse: semilla rara (${expense.length}/${income.length})`);
  seedKeys = { expense, income };
  return seedKeys;
}

const stringsCache = new Map<string, Map<string, string>>();

function strings(lproj: string): Map<string, string> {
  if (!stringsCache.has(lproj)) {
    const m = new Map<string, string>();
    let src = "";
    try {
      src = readRepoFile(`Yala/Resources/${lproj}.lproj/Localizable.strings`);
    } catch {
      src = "";
    }
    for (const x of src.matchAll(/^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";/gm)) m.set(x[1], x[2].replace(/\\"/g, '"'));
    stringsCache.set(lproj, m);
  }
  return stringsCache.get(lproj)!;
}

/** Nombres de subcategorías semilla en ese idioma, con la cadena de respaldo de `lproj` (p. ej. es-AR → es-419 → es). */
export function seedSubcategories(lprojChain: string[]): { expense: string[]; income: string[] } {
  const { expense, income } = seedSubcategoryKeys();
  const name = (k: string) => {
    for (const l of lprojChain) {
      const v = strings(l).get(k);
      if (v) return v;
    }
    throw new Error(`parse: «${k}» sin traducción en ${lprojChain.join(",")}`);
  };
  return { expense: expense.map(name), income: income.map(name) };
}

// ---------- cuerpo de la petición ----------

const FEW_SHOT_DATE = "\\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))";

export function parserSystemPrompt(todayIso: string, sub: { expense: string[]; income: string[] }): string {
  const src = readRepoFile(PATHS.parser);
  let tpl = swiftMultilineAfter(src, "private func buildSystemPrompt(expenseSubcategories: [String], incomeSubcategories: [String]) -> String {");
  if (!tpl.includes(FEW_SHOT_DATE)) throw new Error("parse: el prompt ya no lleva la fecha de los ejemplos como se esperaba");
  tpl = tpl.split(FEW_SHOT_DATE).join(todayIso);
  return interpolate(tpl, {
    dateContext: dateContext(todayIso),
    expenseList: sub.expense.length ? sub.expense.join(", ") : "No hay subcategorías de gasto definidas",
    incomeList: sub.income.length ? sub.income.join(", ") : "No hay subcategorías de ingreso definidas",
  });
}

/** Cuerpo de Chat Completions que manda la app (MacPaw 0.4.7: `stream` siempre presente). */
export function parserBody(systemPrompt: string, transcript: string): Record<string, unknown> {
  return {
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: transcript.trim() },
    ],
    model: PARSER_MODEL,
    temperature: PARSER_TEMPERATURE,
    stream: false,
  };
}

// ---------- decodificación de la app ----------

export interface ParsedTx {
  amount: number | null;
  date: string | null;
  note: string;
  isExpense: boolean;
  currencyHint: string | null;
}

/** Réplica de `parseMultipleResponse` + `JSONDecoder` sobre `LLMMultipleResponse`. null = la app lo rechaza. */
export function decodeAppParse(content: string): ParsedTx[] | null {
  let s = content.trim();
  if (s.startsWith("```json")) s = s.slice(7);
  if (s.startsWith("```")) s = s.slice(3);
  if (s.endsWith("```")) s = s.slice(0, -3);
  s = s.trim();
  let obj: unknown;
  try {
    obj = JSON.parse(s);
  } catch {
    return null;
  }
  const txs = (obj as { transactions?: unknown })?.transactions;
  if (!Array.isArray(txs)) return null;
  const out: ParsedTx[] = [];
  const optional = (v: unknown, type: string) => v === undefined || v === null || typeof v === type;
  for (const t of txs as Record<string, unknown>[]) {
    if (!t || typeof t !== "object") return null;
    if (typeof t.note !== "string" || typeof t.isExpense !== "boolean") return null;
    if (!optional(t.amount, "number") || !optional(t.date, "string") || !optional(t.subcategoryHint, "string") || !optional(t.currencyHint, "string")) return null;
    if (t.tagHints !== undefined && t.tagHints !== null && (!Array.isArray(t.tagHints) || t.tagHints.some((x) => typeof x !== "string"))) return null;
    const c = t.confidence as Record<string, unknown> | undefined;
    if (!c || typeof c !== "object" || ["amount", "date", "merchant", "subcategory", "tags"].some((k) => typeof c[k] !== "number")) return null;
    out.push({
      amount: (t.amount as number | null | undefined) ?? null,
      // La app: "yyyy-MM-dd" estricto; si no casa, la fecha queda nil (y el borrador lleva la de hoy).
      date: typeof t.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(t.date) ? t.date : null,
      note: t.note,
      isExpense: t.isExpense,
      currencyHint: (t.currencyHint as string | null | undefined) ?? null,
    });
  }
  return out;
}

// ---------- puntuación de la nota ----------

export interface ExpectedTx {
  amount: number;
  date: string;
  dateAlt?: (string | null)[];
  currency: string | null;
  currencyAlt?: (string | null)[];
  merchant?: string;
  merchantAlt?: string[];
  /** Cómo se dijo el importe (para aceptarlo en letra en la transcripción). */
  spoken?: string;
}

export interface NoteGrade {
  appParsed: boolean;
  core: boolean;
  /** Núcleo + el comercio en la nota (lo que depende de la transcripción; la divisa depende sobre todo del prompt). */
  withMerchant: boolean;
  strict: boolean;
  expected: number;
  got: number;
  coreHits: number;
  strictHits: number;
  misses?: string[];
}

/**
 * Acierta si la nota produce EXACTAMENTE los movimientos esperados (los de importe nulo los descarta la app, como
 * hace `processAudio`). Núcleo: importe, signo (gasto/ingreso) y fecha (nil = hoy, que es lo que guarda la app).
 * Con comercio: además el comercio en la nota (que es donde la app lo enseña). Estricto: además la divisa (si se
 * dijo, la que se dijo; si no, null o la de la variante). La divisa depende sobre todo del prompt de la app, que
 * solo enseña seis (USD, EUR, PEN, MXN, COP, BRL): por eso el estricto no separa motores.
 */
export function gradeNote(content: string, expected: ExpectedTx[], todayIso: string): NoteGrade {
  const parsed = decodeAppParse(content);
  if (!parsed) return { appParsed: false, core: false, withMerchant: false, strict: false, expected: expected.length, got: 0, coreHits: 0, strictHits: 0 };
  const got = parsed.filter((t) => t.amount !== null);
  const coreOk = (g: ParsedTx, e: ExpectedTx) =>
    g.amount !== null &&
    Math.abs(Math.abs(g.amount) - Math.abs(e.amount)) < 0.011 &&
    g.isExpense === e.amount < 0 &&
    [e.date, ...(e.dateAlt ?? []).map((d) => d ?? todayIso)].includes(g.date ?? todayIso);
  const merchantOk = (g: ParsedTx, e: ExpectedTx) => coreOk(g, e) && (!e.merchant || merchantPresent(g.note, [e.merchant, ...(e.merchantAlt ?? [])]));
  const strictOk = (g: ParsedTx, e: ExpectedTx) =>
    merchantOk(g, e) && [e.currency, ...(e.currencyAlt ?? [])].includes(g.currencyHint ? g.currencyHint.toUpperCase() : null);
  const hits = (ok: (g: ParsedTx, e: ExpectedTx) => boolean) => {
    const used = new Set<number>();
    let n = 0;
    for (const e of expected) {
      const i = got.findIndex((g, k) => !used.has(k) && ok(g, e));
      if (i >= 0) {
        used.add(i);
        n++;
      }
    }
    return n;
  };
  const coreHits = hits(coreOk);
  const merchantHits = hits(merchantOk);
  const strictHits = hits(strictOk);
  const sameCount = got.length === expected.length;
  const misses: string[] = [];
  if (!sameCount) misses.push(`movimientos ${got.length} (esp. ${expected.length})`);
  for (const e of expected) {
    if (!got.some((g) => coreOk(g, e))) {
      const g = got.find((x) => x.amount !== null && Math.abs(Math.abs(x.amount) - Math.abs(e.amount)) < 0.011);
      misses.push(g ? `${e.amount}: fecha ${g.date} signo ${g.isExpense ? "-" : "+"}` : `${e.amount}: no leído`);
    } else if (!got.some((g) => strictOk(g, e))) {
      const g = got.find((x) => coreOk(x, e))!;
      misses.push(`${e.amount}: divisa ${g.currencyHint} nota «${g.note.slice(0, 30)}»`);
    }
  }
  return {
    appParsed: true,
    core: sameCount && coreHits === expected.length,
    withMerchant: sameCount && merchantHits === expected.length,
    strict: sameCount && strictHits === expected.length,
    expected: expected.length,
    got: got.length,
    coreHits,
    strictHits,
    ...(misses.length ? { misses } : {}),
  };
}
