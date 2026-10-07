import { baseLang, detectLang } from "./lang";
import type { SuggestionsContext } from "./appRequests";

/**
 * Criterios de acierto por tarea. Cada uno replica primero lo que hace la APP con la respuesta
 * (si la app la rechaza, el usuario no ve nada: fallo), y después compara con la verdad del caso.
 */

export interface Grade {
  pass: boolean;
  /** JSON aceptado por el parser de la app. */
  appParsed: boolean;
  detail: Record<string, unknown>;
}

// ---------- chat.intent ----------

export interface IntentCase {
  id: string;
  locale: string;
  text: string;
  expect: "ask" | "register" | "ambiguous";
  accept?: string[];
}

/** Réplica de `ChatIntentClassifierService.parseClassificationJSON` + el umbral de `classify`. */
export function gradeIntent(content: string, c: IntentCase): Grade {
  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(content);
  } catch {
    return { pass: false, appParsed: false, detail: { error: "json" } };
  }
  const intent = obj?.intent;
  if (intent !== "ask" && intent !== "register" && intent !== "ambiguous") {
    return { pass: false, appParsed: false, detail: { error: "intent", got: intent } };
  }
  const confidence = typeof obj.confidence === "number" ? Math.max(0, Math.min(1, obj.confidence)) : 0;
  const final = intent !== "ambiguous" && confidence < 0.7 ? "ambiguous" : intent;
  const accept = c.accept ?? [c.expect];
  return { pass: accept.includes(final), appParsed: true, detail: { intent, confidence, final } };
}

// ---------- chat.suggestions ----------

const MAX_TEXT = 80;
const MIN_ITEMS = 3;

export interface SuggestionsCase {
  id: string;
  context: SuggestionsContext;
}

/** Réplica de `ChatSuggestionsLLMService.parseSuggestions`. */
export function parseSuggestions(content: string): string[] | null {
  let obj: unknown;
  try {
    obj = JSON.parse(content);
  } catch {
    return null;
  }
  const arr = (obj as { suggestions?: unknown })?.suggestions;
  if (!Array.isArray(arr) || arr.length === 0) return null;
  const out: string[] = [];
  for (const item of arr) {
    const text = (item as { text?: unknown })?.text;
    if (typeof text !== "string") continue;
    const t = text.trim();
    if (!t || [...t].length > MAX_TEXT) continue;
    out.push(t);
  }
  if (out.length < MIN_ITEMS) return null;
  return out.slice(0, 10);
}

function norm(s: string): string {
  return s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
}

export function gradeSuggestions(content: string, c: SuggestionsCase): Grade {
  const items = parseSuggestions(content);
  if (!items) return { pass: false, appParsed: false, detail: { error: "parser de la app" } };
  const ctx = c.context;
  const names = [
    ...ctx.topCategories,
    ...ctx.subcategoryNames,
    ...ctx.merchantNames,
    ...ctx.activeBudgets,
    ...ctx.tagNames,
    ...ctx.recurringPaidNames,
  ];
  const target = baseLang(ctx.language);
  const langs = items.map((t) => detectLang(t, names));
  const inLang = langs.filter((l) => l === target).length / items.length;
  const specific = items.filter((t) => names.some((n) => n && norm(t).includes(norm(n)))).length / items.length;
  const pass = items.length >= 8 && inLang >= 0.9 && specific >= 0.5;
  return {
    pass,
    appParsed: true,
    detail: { n: items.length, inLang: Number(inLang.toFixed(2)), specific: Number(specific.toFixed(2)), langs: langs.join(","), sample: items.slice(0, 3) },
  };
}

// ---------- photo.read ----------

export interface ExpectedTx {
  amount: number;
  date: string | null;
  currency: string | null;
  /** Divisas que también se aceptan (p. ej. ¥ → JPY o CNY). */
  currencyAlt?: (string | null)[];
  merchant?: string;
  /** Importes alternativos aceptables (p. ej. total con o sin propina), con su signo. */
  amountAlt?: number[];
}

export interface PhotoCase {
  id: string;
  file: string;
  today: string;
  kind: string;
  lang: string;
  source: string;
  expect: { imageType: string; transactions: ExpectedTx[] };
}

interface VisionTx {
  amount: number | null;
  date: string | null;
  merchant: string | null;
  note: string | null;
  currency: string | null;
}

/**
 * Réplica de la decodificación de `VisionResponse` (Swift `JSONDecoder`): `imageType` string,
 * `transactions` array de objetos con campos opcionales, `confidence` con `overall` e `imageType`
 * numéricos. Si falta algo obligatorio, la app enseña «respuesta inválida».
 */
export function parseVision(content: string): { imageType: string; transactions: VisionTx[] } | null {
  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(content);
  } catch {
    return null;
  }
  if (typeof obj?.imageType !== "string" || !Array.isArray(obj.transactions)) return null;
  const conf = obj.confidence as Record<string, unknown> | undefined;
  if (!conf || typeof conf.overall !== "number" || typeof conf.imageType !== "number") return null;
  const txs: VisionTx[] = [];
  for (const t of obj.transactions as Record<string, unknown>[]) {
    if (!t || typeof t !== "object") return null;
    const pick = <T>(v: unknown, type: string): T | null => (v === undefined || v === null ? null : typeof v === type ? (v as T) : (undefined as never));
    const amount = pick<number>(t.amount, "number");
    const date = pick<string>(t.date, "string");
    const merchant = pick<string>(t.merchant, "string");
    const note = pick<string>(t.note, "string");
    const currency = pick<string>(t.currency, "string");
    if ([amount, date, merchant, note, currency].some((v) => v === undefined)) return null; // tipo incorrecto → decode falla
    txs.push({ amount, date, merchant, note, currency });
  }
  return { imageType: obj.imageType, transactions: txs };
}

function amountOk(got: number | null, e: ExpectedTx): boolean {
  if (got === null) return false;
  return [e.amount, ...(e.amountAlt ?? [])].some((a) => Math.abs(got - a) < 0.011);
}

function merchantOk(got: VisionTx, e: ExpectedTx): boolean {
  if (!e.merchant) return true;
  const hay = norm(`${got.merchant ?? ""} ${got.note ?? ""}`);
  const want = norm(e.merchant);
  const tokens = want.split(/[^a-z0-9À-￿]+/).filter((w) => w.length >= 3);
  if (hay.includes(want)) return true;
  if (tokens.length === 0) return false;
  return tokens.filter((w) => hay.includes(w)).length / tokens.length >= 0.5;
}

/**
 * Acierta si la foto produce EXACTAMENTE los movimientos esperados: mismo número de movimientos con
 * importe (los de importe nulo los descarta el usuario en la revisión y no cuentan), y cada esperado
 * emparejado con uno recibido por importe y signo, fecha y divisa. El comercio se mide aparte (métrica
 * secundaria): un comercio mal leído se corrige en la revisión; un importe o una fecha mal leídos se
 * cuelan.
 */
export function gradePhoto(content: string, c: PhotoCase): Grade {
  const parsed = parseVision(content);
  if (!parsed) return { pass: false, appParsed: false, detail: { error: "decode de la app" } };
  const got = parsed.transactions.filter((t) => t.amount !== null);
  const expected = c.expect.transactions;
  const used = new Set<number>();
  let amountHits = 0;
  let fullHits = 0;
  let merchantHits = 0;
  const misses: string[] = [];
  for (const e of expected) {
    // Primero el emparejamiento completo; si no, al menos por importe (para las métricas por campo).
    let idx = got.findIndex(
      (g, i) =>
        !used.has(i) &&
        amountOk(g.amount, e) &&
        g.date === e.date &&
        [e.currency, ...(e.currencyAlt ?? [])].includes(g.currency),
    );
    const full = idx >= 0;
    if (!full) idx = got.findIndex((g, i) => !used.has(i) && amountOk(g.amount, e));
    if (idx >= 0) {
      used.add(idx);
      amountHits++;
      if (full) fullHits++;
      else misses.push(`${e.amount}: fecha ${got[idx].date} (esp. ${e.date}) divisa ${got[idx].currency} (esp. ${e.currency})`);
      if (merchantOk(got[idx], e)) merchantHits++;
    } else {
      misses.push(`${e.amount}: no leído`);
    }
  }
  const extra = got.length - used.size;
  const pass = fullHits === expected.length && extra === 0;
  return {
    pass,
    appParsed: true,
    detail: {
      imageType: parsed.imageType,
      expected: expected.length,
      got: got.length,
      fullHits,
      amountHits,
      merchantHits,
      extra,
      ...(misses.length ? { misses: misses.slice(0, 6) } : {}),
    },
  };
}
