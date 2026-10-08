import { lprojFor, seedSubcategoryNames, subcategoryName } from "./appCatalog";
import { dateContext } from "./appRequests";
import type { Grade } from "./grading";
import { interpolate, readRepoFile, swiftMultilineAfter } from "./swift";

/**
 * `text.parse` — `TranscriptionParserService.parseMultiple`: convierte una frase (dictada y transcrita, escrita
 * en el chat o dicha a Siri) en movimientos. Hoy `gpt-4.1-mini`, temperatura 0.1, SIN `response_format` (el
 * prompt pide JSON y la app quita las vallas ```json). Sin corte propio: hereda el `timeoutInterval` de 20 s del
 * cliente HTTP.
 *
 * Qué hace la app con la respuesta (replicado aquí, en este orden):
 * 1. `parseMultipleResponse`: quita ```json / ``` y decodifica con `JSONDecoder` estricto. `note` e `isExpense`
 *    son obligatorios, `confidence` con sus cinco números también; un tipo incorrecto en cualquier movimiento
 *    tumba la respuesta entera (el chat enseña «no pude entenderlo»).
 * 2. Fecha: `yyyy-MM-dd` o nada (y entonces `DraftBuilder.build` pone hoy).
 * 3. Importe: el chat descarta los movimientos sin importe, no finitos, ≤ 0 o ≥ 1 000 000 (`runRegisterFlow`).
 * 4. Divisa: `currencyHint` en mayúsculas o, sin ella, la principal del usuario.
 * 5. Subcategoría: `DraftBuilder.matchSubcategoryByHint` (exacta → parcial → inversa, sin tildes ni mayúsculas,
 *    solo las de la naturaleza del movimiento; ambigua = ninguna).
 */

const SWIFT = "Yala/Services/TranscriptionParserService.swift";
const DATE_EXPR = "\\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))";

function emptyListText(which: "expense" | "income"): string {
  const src = readRepoFile(SWIFT);
  const m = src.match(new RegExp(`${which}Subcategories\\.isEmpty \\? "([^"]+)"`));
  if (!m) throw new Error(`textParse: no encuentro el texto de lista vacía (${which})`);
  return m[1];
}

export function textParseSystemPrompt(todayIso: string, expense: string[], income: string[]): string {
  const tpl = swiftMultilineAfter(readRepoFile(SWIFT), "private func buildSystemPrompt(expenseSubcategories:");
  if (!tpl.includes(DATE_EXPR)) throw new Error("textParse: cambió la fecha de los ejemplos del prompt");
  return interpolate(tpl.split(DATE_EXPR).join(todayIso), {
    dateContext: dateContext(todayIso),
    expenseList: expense.length ? expense.join(", ") : emptyListText("expense"),
    incomeList: income.length ? income.join(", ") : emptyListText("income"),
  });
}

export interface ExpectedNoteTx {
  amount: number;
  isExpense: boolean;
  /** Fecha ISO, o varias aceptables. */
  date: string | string[];
  currency: string;
  /** Subcategorías aceptables: claves del seed o `custom:Nombre`. Vacío = ninguna encaja (debe quedar sin subcategoría). */
  sub: string[];
  merchant?: string;
  tags?: string[];
}

export interface TextParseCase {
  id: string;
  locale: string;
  today: string;
  defaultCurrency: string;
  text: string;
  /** Subcategorías creadas por el usuario además de las del seed. */
  extraExpense?: string[];
  extraIncome?: string[];
  expect: ExpectedNoteTx[];
  note?: string;
}

export function caseSubcategories(c: TextParseCase): { expense: string[]; income: string[] } {
  const seed = seedSubcategoryNames(lprojFor(c.locale));
  return { expense: [...seed.expense, ...(c.extraExpense ?? [])], income: [...seed.income, ...(c.extraIncome ?? [])] };
}

export function textParseBody(c: TextParseCase): Record<string, unknown> {
  const subs = caseSubcategories(c);
  return {
    messages: [
      { role: "system", content: textParseSystemPrompt(c.today, subs.expense, subs.income) },
      { role: "user", content: c.text.trim() },
    ],
    model: "gpt-4.1-mini",
    temperature: 0.1,
    stream: false,
  };
}

// ---------- réplica del parser de la app ----------

export interface ParsedNoteTx {
  amount: number | null;
  date: string | null;
  note: string;
  isExpense: boolean;
  subcategoryHint: string | null;
  tagHints: string[];
  currencyHint: string | null;
}

/** `parseMultipleResponse` + la decodificación de `LLMMultipleResponse`. `null` = la app lanza `parsingFailed`. */
export function parseNoteResponse(content: string): ParsedNoteTx[] | null {
  let s = content.trim();
  if (s.startsWith("```json")) s = s.slice(7);
  if (s.startsWith("```")) s = s.slice(3);
  if (s.endsWith("```")) s = s.slice(0, -3);
  s = s.trim();
  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(s);
  } catch {
    return null;
  }
  if (!obj || typeof obj !== "object" || !Array.isArray(obj.transactions)) return null;
  const out: ParsedNoteTx[] = [];
  const opt = (v: unknown, type: string) => v === undefined || v === null || typeof v === type;
  for (const raw of obj.transactions as unknown[]) {
    if (!raw || typeof raw !== "object") return null;
    const t = raw as Record<string, unknown>;
    if (!opt(t.amount, "number") || !opt(t.date, "string") || !opt(t.subcategoryHint, "string") || !opt(t.currencyHint, "string")) return null;
    if (typeof t.note !== "string" || typeof t.isExpense !== "boolean") return null;
    if (t.tagHints !== undefined && t.tagHints !== null && (!Array.isArray(t.tagHints) || t.tagHints.some((x) => typeof x !== "string"))) return null;
    const conf = t.confidence as Record<string, unknown> | undefined;
    if (!conf || typeof conf !== "object" || ["amount", "date", "merchant", "subcategory", "tags"].some((k) => typeof conf[k] !== "number")) return null;
    out.push({
      amount: (t.amount as number | null | undefined) ?? null,
      date: (t.date as string | null | undefined) ?? null,
      note: t.note,
      isExpense: t.isExpense,
      subcategoryHint: (t.subcategoryHint as string | null | undefined) ?? null,
      tagHints: (t.tagHints as string[] | null | undefined) ?? [],
      currencyHint: (t.currencyHint as string | null | undefined) ?? null,
    });
  }
  return out;
}

function normalize(s: string): string {
  return s.toLowerCase().trim().normalize("NFD").replace(/\p{M}/gu, "");
}

/** `DraftBuilder.matchSubcategoryByHint`, sobre los nombres (las listas ya vienen separadas por naturaleza). */
export function matchSubcategory(hint: string | null, candidates: string[]): string | null {
  if (!hint) return null;
  const h = normalize(hint);
  if (!h) return null;
  const exact = candidates.filter((n) => normalize(n) === h);
  if (exact.length === 1) return exact[0];
  if (exact.length > 1) return null;
  const partial = candidates.filter((n) => normalize(n).includes(h));
  if (partial.length === 1) return partial[0];
  if (partial.length > 1) return null;
  const reverse = candidates.filter((n) => h.includes(normalize(n)));
  return reverse.length === 1 ? reverse[0] : null;
}

/** `yyyy-MM-dd` con `DateFormatter` estricto; si no casa, la app usa hoy. */
function effectiveDate(date: string | null, today: string): string {
  if (!date) return today;
  const m = date.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (!m) return today;
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  if (d.getUTCMonth() !== Number(m[2]) - 1) return today;
  return d.toISOString().slice(0, 10);
}

function merchantOk(note: string, want: string): boolean {
  const hay = normalize(note);
  const w = normalize(want);
  if (hay.includes(w)) return true;
  const tokens = w.split(/[^\p{L}\p{N}]+/u).filter((x) => x.length >= 3);
  return tokens.length > 0 && tokens.filter((x) => hay.includes(x)).length / tokens.length >= 0.5;
}

export function expectedSubNames(c: TextParseCase, e: ExpectedNoteTx): string[] {
  const lproj = lprojFor(c.locale);
  return e.sub.map((k) => (k.startsWith("custom:") ? k.slice(7) : subcategoryName(lproj, k)));
}

/**
 * Pasa si la frase produce EXACTAMENTE los movimientos esperados, tal como los guardaría la app: mismo número de
 * movimientos válidos y cada esperado emparejado con uno por importe, tipo (gasto/ingreso), fecha, divisa y
 * subcategoría resuelta. El comercio/nota y las etiquetas se miden aparte: se corrigen en la tarjeta del borrador,
 * mientras que un importe, una fecha o una divisa mal leídos se cuelan.
 */
export function gradeTextParse(content: string, c: TextParseCase): Grade {
  const parsed = parseNoteResponse(content);
  if (!parsed) return { pass: false, appParsed: false, detail: { error: "decode de la app" } };
  const subs = caseSubcategories(c);
  const got = parsed
    .filter((t) => t.amount !== null && Number.isFinite(t.amount) && t.amount > 0 && t.amount < 1_000_000)
    .map((t) => ({
      ...t,
      eDate: effectiveDate(t.date, c.today),
      eCurrency: (t.currencyHint ?? c.defaultCurrency).toUpperCase(),
      eSub: matchSubcategory(t.subcategoryHint, t.isExpense ? subs.expense : subs.income),
    }));
  const used = new Set<number>();
  let full = 0;
  let amountHits = 0;
  let merchantHits = 0;
  let merchantWanted = 0;
  let tagHits = 0;
  let tagWanted = 0;
  const field = { type: 0, date: 0, currency: 0, sub: 0 };
  const misses: string[] = [];
  for (const e of c.expect) {
    const dates = Array.isArray(e.date) ? e.date : [e.date];
    const subNames = expectedSubNames(c, e);
    const okType = (g: (typeof got)[number]) => g.isExpense === e.isExpense;
    const okDate = (g: (typeof got)[number]) => dates.includes(g.eDate);
    const okCur = (g: (typeof got)[number]) => g.eCurrency === e.currency;
    const okSub = (g: (typeof got)[number]) => (subNames.length === 0 ? g.eSub === null : g.eSub !== null && subNames.includes(g.eSub));
    const amountOk = (g: (typeof got)[number]) => Math.abs((g.amount as number) - e.amount) < 0.011;
    let idx = got.findIndex((g, i) => !used.has(i) && amountOk(g) && okType(g) && okDate(g) && okCur(g) && okSub(g));
    const isFull = idx >= 0;
    if (!isFull) idx = got.findIndex((g, i) => !used.has(i) && amountOk(g));
    if (idx < 0) {
      misses.push(`${e.amount}: no leído`);
      continue;
    }
    used.add(idx);
    const g = got[idx];
    amountHits++;
    if (isFull) full++;
    if (okType(g)) field.type++;
    if (okDate(g)) field.date++;
    if (okCur(g)) field.currency++;
    if (okSub(g)) field.sub++;
    if (!isFull) {
      const why = [!okType(g) && `tipo ${g.isExpense ? "gasto" : "ingreso"}`, !okDate(g) && `fecha ${g.eDate} (esp. ${dates.join("|")})`, !okCur(g) && `divisa ${g.eCurrency} (esp. ${e.currency})`, !okSub(g) && `subcat ${g.eSub ?? "—"} [pista ${g.subcategoryHint ?? "—"}] (esp. ${subNames.join("|") || "ninguna"})`].filter(Boolean);
      misses.push(`${e.amount}: ${why.join(", ")}`);
    }
    if (e.merchant) {
      merchantWanted++;
      if (merchantOk(g.note, e.merchant)) merchantHits++;
    }
    if (e.tags?.length) {
      tagWanted++;
      const hints = g.tagHints.map((x) => x.trim().toLowerCase());
      if (e.tags.every((t) => hints.includes(t.toLowerCase()))) tagHits++;
    }
  }
  const extra = got.length - used.size;
  const pass = full === c.expect.length && extra === 0;
  return {
    pass,
    appParsed: true,
    detail: {
      expected: c.expect.length,
      got: got.length,
      dropped: parsed.length - got.length,
      fullHits: full,
      amountHits,
      field,
      merchantHits,
      merchantWanted,
      tagHits,
      tagWanted,
      extra,
      ...(misses.length ? { misses } : {}),
      // La respuesta entera (los casos son públicos): permite volver a puntuar sin volver a pagar.
      content: content.slice(0, 4000),
      ...(extra > 0 ? { extras: got.filter((_, i) => !used.has(i)).map((g) => `${g.amount} ${g.eCurrency} ${g.eDate} ${g.eSub ?? "—"}`) } : {}),
    },
  };
}
