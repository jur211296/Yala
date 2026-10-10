import { baseLang, detectLang } from "./lang";
import type { SuggestionsContext } from "./appRequests";
import { isValidSuggestion } from "./chatRewrite";
import { rawNote } from "./noteCleaner";

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
  // Aparte del acierto: cuántas conserva la app sin reescribir (`SuggestionsRewriterService.isValid` con el whitelist
  // que arma `ChatSuggestionsLLMService`, sin los pagos recurrentes). Las demás van a `chat.rewrite`.
  const whitelist = {
    categories: ctx.topCategories,
    subcategories: ctx.subcategoryNames,
    budgets: ctx.activeBudgets,
    tags: ctx.tagNames,
    merchants: ctx.merchantNames,
  };
  const toRewrite = items.filter((t) => !isValidSuggestion(t, whitelist, ctx.language));
  return {
    pass,
    appParsed: true,
    detail: {
      n: items.length,
      inLang: Number(inLang.toFixed(2)),
      specific: Number(specific.toFixed(2)),
      langs: langs.join(","),
      appValid: items.length - toRewrite.length,
      ...(toRewrite.length ? { toRewrite } : {}),
      items,
    },
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
  /**
   * Lo que la NOTA final tiene que nombrar (todas sus palabras de 3+ letras), sin plantilla de banco ni códigos.
   * Sin él, la nota se mide contra `merchant` con la regla de `merchantOk` (la mitad de sus palabras).
   */
  noteWant?: string;
}

export interface PhotoCase {
  id: string;
  file: string;
  today: string;
  kind: string;
  lang: string;
  source: string;
  /** Divisas del usuario que la app pasa al prompt (sesión 2): p. ej. MXN decide un «$» mexicano. */
  currencyContext?: { main: string | null; accounts: string[] };
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

// ---------- nota (ticket image-note-uses-bank-template-instead-of-merchant) ----------

/** Palabras de plantilla de banco que nunca deben llegar a la nota (comparadas sin tildes, palabra entera). */
const NOTE_FORBIDDEN = new Set([
  "consumo", "compra", "compras", "tarjeta", "credito", "debito", "pago", "pagaste", "operacion", "purchase", "card",
  "payment", "transaction", "yapeaste", "bcp", "interbank", "bbva", "scotiabank", "yape", "plin", "nro", "op", "ref",
  "autorizacion", "approved", "aprobado", "realizaste",
]);

function words(s: string): string[] {
  return norm(s).split(/[^a-z0-9]+/).filter(Boolean);
}

/**
 * La nota es buena si nombra lo esperado y no trae plantilla de banco (salvo palabras que el propio comercio lleve),
 * números de 4+ cifras ni asteriscos.
 */
export function noteOk(text: string, e: ExpectedTx): boolean {
  const ws = words(text);
  // Lo que el comercio esperado ya trae (p. ej. «PAGO TARJETA» en un extracto) no cuenta como plantilla colada…
  const allowed = new Set(words(e.noteWant ?? e.merchant ?? ""));
  // …pero tampoco se exige: se exige el nombre, no la plantilla que lo rodeaba («TRANSF. RECIBIDA M. QUISPE»).
  const want = [...allowed].filter((w) => w.length >= 3 && !NOTE_TEMPLATE.has(w));
  if (/\*/.test(text) || /\d{4,}/.test(text)) return false;
  if (ws.some((w) => NOTE_FORBIDDEN.has(w) && !allowed.has(w))) return false;
  if (want.length === 0) return text.trim().length > 0;
  const hits = want.filter((w) => ws.includes(w) || norm(text).includes(w)).length;
  return e.noteWant ? hits === want.length : hits / want.length >= 0.5;
}

/** Plantilla que un comercio esperado de extracto puede traer y que la nota limpia no tiene por qué repetir. */
const NOTE_TEMPLATE = new Set([
  ...NOTE_FORBIDDEN, "transf", "transferencia", "transfer", "recibida", "recibido", "zelle", "online", "from", "movil",
  "suscripcion", "devolucion",
]);

/**
 * Acierta si la foto produce EXACTAMENTE los movimientos esperados: mismo número de movimientos con
 * importe (los de importe nulo los descarta el usuario en la revisión y no cuentan), y cada esperado
 * emparejado con uno recibido por importe y signo, fecha y divisa. El comercio se mide aparte (métrica
 * secundaria): un comercio mal leído se corrige en la revisión; un importe o una fecha mal leídos se
 * cuelan.
 */
export function gradePhoto(
  content: string,
  c: PhotoCase,
  /** La limpieza de la app (`cleanNotes`, que compila el Swift). Sin ella, solo se mide la nota cruda: así los tests y
   * el CI de Ubuntu no necesitan `swiftc`. */
  cleanNotes?: (pairs: [string | null, string | null][]) => string[],
): Grade {
  const parsed = parseVision(content);
  if (!parsed) return { pass: false, appParsed: false, detail: { error: "decode de la app" } };
  const got = parsed.transactions.filter((t) => t.amount !== null);
  const expected = c.expect.transactions;
  const used = new Set<number>();
  let amountHits = 0;
  let fullHits = 0;
  let merchantHits = 0;
  const misses: string[] = [];
  const notePairs: { e: ExpectedTx; raw: string; pair: [string | null, string | null] }[] = [];
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
      notePairs.push({ e, raw: rawNote(got[idx].merchant, got[idx].note), pair: [got[idx].merchant, got[idx].note] });
    } else {
      misses.push(`${e.amount}: no leído`);
    }
  }
  const extra = got.length - used.size;
  const pass = fullHits === expected.length && extra === 0;
  // La nota: cruda (como la armaba la app antes) y con la limpieza real de la app (`VisionNoteCleaner`).
  const cleaned = cleanNotes?.(notePairs.map((n) => n.pair));
  const notes = notePairs.map((n, i) => ({
    raw: n.raw,
    clean: cleaned?.[i] ?? null,
    rawOk: noteOk(n.raw, n.e),
    cleanOk: cleaned ? noteOk(cleaned[i], n.e) : false,
  }));
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
      noteRawHits: notes.filter((n) => n.rawOk).length,
      ...(cleaned ? { noteCleanHits: notes.filter((n) => n.cleanOk).length } : {}),
      notes: notes.map(({ raw, clean }, i) => ({ raw, clean, pair: notePairs[i].pair, expected: expected.indexOf(notePairs[i].e) })),
      extra,
      ...(misses.length ? { misses: misses.slice(0, 6) } : {}),
    },
  };
}
