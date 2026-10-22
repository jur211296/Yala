import { categoryName, seedCategories, subcategoryName } from "./appCatalog";
import { dateContext } from "./appRequests";
import { buildContext, canonicalMerchant, type BuiltContext, type Json, type Persona } from "./chatContext";
import { baseLang, detectLang } from "./lang";
import { informalRegister } from "./insightsRequests";
import { interpolate, readRepoFile, swiftMultilineAfter } from "./swift";
import type { Grade } from "./grading";

/**
 * `chat.answer`: la respuesta del asistente del chat (`ChatAssistantService.runAskFlow`), con el contexto
 * financiero entero en el prompt de sistema.
 *
 * El cuerpo es el de la app: prompt de sistema = parte estática + "\n\n" + parte dinámica (JSON + fechas),
 * los turnos del día como pares user/assistant y la pregunta al final; `gpt-4.1-mini`, temperatura 0.4,
 * `stream: false`, sin `response_format` (texto libre).
 */

const SWIFT = {
  chat: "Yala/Services/ChatAssistantService.swift",
  locales: "Yala/Utils/SupportedLocale.swift",
  anomaly: "Yala/Services/Chat/AnomalyKeywords.swift",
} as const;

// ---------- prompt ----------

/** `SupportedLocale.from(language)?.code ?? String(language.prefix(2))`, con los casos leídos del Swift. */
function baseLanguageCode(language: string): string {
  const codes = [...readRepoFile(SWIFT.locales).matchAll(/^\s*case \w+ = "([^"]+)"/gm)].map((m) => m[1]);
  if (codes.includes(language)) return language;
  const base = language.slice(0, 2);
  return codes.includes(base) ? base : base;
}

/**
 * El registro que la app pide según el idioma: el chat calcula su código base y lo busca en la tabla de
 * `AIPromptLanguage.informalRegister(forBaseLanguage:)`, que comparte con Insights desde el 2026-10-07.
 */
export function chatRegister(language: string): string {
  const src = readRepoFile(SWIFT.chat);
  const fn = src.slice(src.indexOf("private func buildSystemPromptStatic("));
  if (!fn.includes("AIPromptLanguage.informalRegister(forBaseLanguage: baseLanguage)")) {
    throw new Error("chatAnswer: el chat ya no pide el trato a AIPromptLanguage con su código base");
  }
  return informalRegister(baseLanguageCode(language));
}

const TONE_KEY = 'toneInstruction.isEmpty ? "" : "16. Tono: \\(toneInstruction)"';
const FOCUS_KEY = 'focusInstruction.isEmpty ? "" : "17. Enfoque: \\(focusInstruction)"';

/** Parte estática con tono y enfoque por defecto (`InsightTone.normal`, `InsightFocus.balanced`: sin línea 16/17). */
export function chatStaticPrompt(language: string, currencyDisplay: string): string {
  const tpl = swiftMultilineAfter(readRepoFile(SWIFT.chat), "private func buildSystemPromptStatic(");
  return interpolate(tpl, { language, currencyDisplay, register: chatRegister(language), [TONE_KEY]: "", [FOCUS_KEY]: "" });
}

export function chatDynamicPrompt(contextJSON: string, todayIso: string): string {
  const tpl = swiftMultilineAfter(readRepoFile(SWIFT.chat), "private func buildSystemPromptDynamic(");
  return interpolate(tpl, { "context.toJSONString()": contextJSON, dateContext: dateContext(todayIso) });
}

export interface ChatTurn {
  q: string;
  a: string;
}

export interface ChatAnswerCase {
  id: string;
  persona: string;
  question: string;
  turns?: ChatTurn[];
  /** `data`: la respuesta está en el contexto. `nodata`: no lo está (hay que decirlo). `offtopic`: no es de finanzas. */
  kind: "data" | "nodata" | "offtopic";
  /** Alguna de las cifras, y alguno de los nombres (si los hay), tiene que aparecer en la respuesta. */
  expect?: { numbers?: Ref[]; names?: Ref[] };
  /** Cifras con las que tiene sentido operar para esta pregunta (sumas, diferencias, porcentajes). */
  operands?: Ref[];
  note?: string;
}

const builtCache = new Map<string, BuiltContext>();

export function personaContext(p: Persona): BuiltContext {
  const hit = builtCache.get(p.id);
  if (hit) return hit;
  const b = buildContext(p);
  builtCache.set(p.id, b);
  return b;
}

export function chatSystemPrompt(p: Persona): string {
  const b = personaContext(p);
  return `${chatStaticPrompt(p.language, b.context.metadata.currency_display)}\n\n${chatDynamicPrompt(b.json, p.today)}`;
}

export function chatAnswerBody(p: Persona, c: ChatAnswerCase): Record<string, unknown> {
  const messages: { role: string; content: string }[] = [{ role: "system", content: chatSystemPrompt(p) }];
  for (const t of c.turns ?? []) messages.push({ role: "user", content: t.q }, { role: "assistant", content: t.a });
  messages.push({ role: "user", content: c.question });
  return { messages, model: "gpt-4.1-mini", temperature: 0.4, stream: false };
}

/** `AnomalyKeywords.matches`: si la pregunta los tiene, la app añade `anomalies` al contexto (no replicado). */
export function triggersAnomalies(question: string): boolean {
  const src = readRepoFile(SWIFT.anomaly);
  const list = src.slice(src.indexOf("private static let keywords"));
  const keywords = [...list.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  const folded = fold(question);
  return keywords.some((k) => folded.includes(k));
}

// ---------- referencias a cifras del contexto ----------

/**
 * Una cifra o un nombre del contexto, por ruta: `periods.current_month.expense`,
 * `categories[name=@food].subcategories[name=@restaurants].total_last_month`, `merchants_top_20[0].name`,
 * `sum:recurring.paid_this_month[*].amount`. `@clave` es el nombre localizado de una categoría o
 * subcategoría del seed. `=texto` es un literal. O una operación simple entre dos referencias.
 */
export type Ref = string | { op: "sub" | "add" | "pct" | "pctchange" | "div" | "avg"; a: Ref; b: Ref };

function localizedSeed(lproj: string, key: string): string {
  if (seedCategories().some((c) => c.key === key)) return categoryName(lproj, key);
  return subcategoryName(lproj, key);
}

function walk(ctx: Json, path: string, lproj: string): Json {
  let cur: Json[] = [ctx];
  let many = false;
  for (const seg of path.split(/\.(?![^[]*\])/)) {
    const m = seg.match(/^([\w]+)(?:\[([^\]]+)\])?$/);
    if (!m) throw new Error(`ref: segmento inválido «${seg}» en ${path}`);
    const next: Json[] = [];
    for (const node of cur) {
      const v = node?.[m[1]];
      if (m[2] === undefined) next.push(v);
      else if (m[2] === "*") { many = true; next.push(...(v ?? [])); }
      else if (/^\d+$/.test(m[2])) next.push(v?.[Number(m[2])]);
      else {
        const [field, raw] = m[2].split("=");
        const want = raw.startsWith("@") ? localizedSeed(lproj, raw.slice(1)) : raw;
        next.push((v ?? []).find((x: Json) => x?.[field] === want));
      }
    }
    cur = next;
  }
  if (cur.some((x) => x === undefined)) throw new Error(`ref: ${path} no existe en el contexto`);
  return many ? cur : cur[0];
}

export function resolveRef(ctx: Json, ref: Ref, lproj: string): number | string {
  if (typeof ref !== "string") {
    const a = Number(resolveRef(ctx, ref.a, lproj));
    const b = Number(resolveRef(ctx, ref.b, lproj));
    switch (ref.op) {
      case "sub": return Math.abs(a - b);
      case "add": return a + b;
      case "pct": return (a / b) * 100;
      case "pctchange": return Math.abs(((a - b) / b) * 100);
      case "div": return a / b;
      case "avg": return (a + b) / 2;
    }
  }
  if (ref.startsWith("=")) return ref.slice(1);
  if (ref.startsWith("@")) return localizedSeed(lproj, ref.slice(1));
  const [fn, path] = ref.includes(":") ? ref.split(":") : [null, ref];
  if (fn === "maxnot") {
    // `maxnot:<lista>|<campo de orden>|<campo que se devuelve>|<lista de exclusión>|<campo excluido>`: el mayor
    // cuyo nombre (canónico, como los comercios) no está en la otra lista. P. ej. el comercio con más gasto
    // que no es un pago programado (la app registra «Alquiler» con su nombre como nota).
    const [list, by, ret, exList, exField] = path.split("|");
    const excluded = new Set((walk(ctx, `${exList}[*]`, lproj) as Json[]).map((x) => canonicalMerchant(String(x[exField]))));
    const items = (walk(ctx, `${list}[*]`, lproj) as Json[]).filter((x) => !excluded.has(canonicalMerchant(String(x.name))));
    const top = items.reduce((a, x) => (x[by] > a[by] ? x : a), items[0]);
    return top[ret];
  }
  if (fn === "maxby") {
    // `maxby:<lista>|<campo por el que se ordena>|<campo que se devuelve>`
    const [list, by, ret] = path.split("|");
    const items = walk(ctx, list, lproj) as Json[];
    const top = items.reduce((a, x) => (x[by] > a[by] ? x : a), items[0]);
    return top[ret];
  }
  const v = walk(ctx, path, lproj);
  if (fn === "sum") return (v as number[]).reduce((a, x) => a + x, 0);
  if (fn === "count") return (v as unknown[]).length;
  if (fn) throw new Error(`ref: función desconocida ${fn}`);
  return v;
}

// ---------- números de la respuesta ----------

export function fold(s: string): string {
  return s.toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
}

export interface NumberToken {
  raw: string;
  /** Lecturas posibles (cada una, una lista de valores que tienen que estar todos explicados). */
  readings: { values: number[]; decimals: number }[];
}

/**
 * Lee las cifras de un texto sin saber qué convención usó el modelo: «1.234» puede ser mil doscientos o uno
 * coma dos (en es-PE el punto es decimal; en es-ES, de miles), así que se guardan las dos lecturas y vale
 * la que el contexto explique. Entiende «万», «mil», «k» y los espacios finos de miles (fr, pl).
 */
export function extractNumbers(text: string): NumberToken[] {
  let t = text.replace(/\*\*/g, " ");
  const out: NumberToken[] = [];
  const push = (raw: string, readings: NumberToken["readings"]) => out.push({ raw, readings });
  // Multiplicadores (se consumen antes de la lectura genérica).
  t = t.replace(/(\d+(?:[.,]\d+)?)\s*(万|萬|亿|億)(?:\s*(\d)\s*千|\s*(\d{1,4}))?/g, (whole, a: string, unit: string, k?: string, rest?: string) => {
    const base = Number(a.replace(",", ".")) * (unit === "万" || unit === "萬" ? 10_000 : 100_000_000);
    const v = base + (k ? Number(k) * 1000 : 0) + (rest ? Number(rest) : 0);
    push(whole, [{ values: [v], decimals: 0 }]);
    return " ";
  });
  t = t.replace(/(\d+(?:[.,]\d+)?)\s?(mil\b|k\b|K\b|millones|millón|milhões|milhão|million|millions)/g, (whole, a: string, unit: string) => {
    const mult = /^(mil|k|K)$/.test(unit) ? 1000 : 1_000_000;
    const vals = a.includes(",") || a.includes(".") ? [Number(a.replace(",", ".")) * mult] : [Number(a) * mult];
    push(whole, [{ values: vals, decimals: 0 }]);
    return " ";
  });
  const re = /\d{1,3}(?:[   .,'’]\d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)?/g;
  for (const m of t.matchAll(re)) {
    const raw = m[0];
    const readings: NumberToken["readings"] = [];
    const spaced = /[   '’]/.test(raw);
    let s = raw.replace(/[  '’]/g, " ");
    if (spaced) {
      // Grupos con espacio: miles («2 350,50»), o dos cifras seguidas («día 15 200»).
      readings.push({ values: s.split(" ").map((x) => Number(x.replace(",", "."))), decimals: 0 });
      s = s.replace(/ /g, "");
    }
    const dots = (s.match(/\./g) ?? []).length;
    const commas = (s.match(/,/g) ?? []).length;
    if (dots && commas) {
      const dec = s.lastIndexOf(".") > s.lastIndexOf(",") ? "." : ",";
      const th = dec === "." ? "," : ".";
      const norm = s.split(th).join("").replace(dec, ".");
      readings.push({ values: [Number(norm)], decimals: norm.split(".")[1]?.length ?? 0 });
    } else if (dots + commas === 0) {
      readings.push({ values: [Number(s)], decimals: 0 });
    } else {
      const sep = dots ? "." : ",";
      const parts = s.split(sep);
      if (parts.length > 2) readings.push({ values: [Number(parts.join(""))], decimals: 0 });
      else {
        const after = parts[1];
        if (after.length === 3) readings.push({ values: [Number(parts.join(""))], decimals: 0 });
        readings.push({ values: [Number(`${parts[0]}.${after}`)], decimals: after.length });
      }
    }
    push(raw, readings);
  }
  return out;
}

/** ¿`x` (escrito con `decimals` decimales) es `v` redondeado, truncado o aproximado como lo haría una persona? */
export function matchesValue(x: number, decimals: number, v: number): boolean {
  const a = Math.abs(v);
  let tol = decimals === 0 ? 1 - 1e-9 : 10 ** -decimals + 1e-9;
  if (decimals === 0 && x >= 100) {
    const tz = String(Math.round(x)).match(/0+$/)?.[0].length ?? 0;
    if (tz > 0) tol = Math.max(tol, Math.min(10 ** tz / 2, 0.05 * x));
  }
  return Math.abs(x - a) <= tol;
}

// ---------- cifras que el contexto explica ----------

function numbersIn(value: Json, out: number[]): void {
  if (typeof value === "number") out.push(Math.abs(value));
  else if (typeof value === "string") for (const tk of extractNumbers(value)) for (const r of tk.readings) out.push(...r.values);
  else if (Array.isArray(value)) for (const v of value) numbersIn(v, out);
  else if (value && typeof value === "object") for (const v of Object.values(value)) numbersIn(v, out);
}

const pairOps = (a: number, b: number): number[] => {
  const out = [a + b, Math.abs(a - b), (a + b) / 2];
  if (b) out.push((a / b) * 100, Math.abs(((a - b) / b) * 100), a / b);
  if (a) out.push((b / a) * 100, Math.abs(((b - a) / a) * 100), b / a);
  return out;
};

/**
 * Las operaciones documentadas que se aceptan como «salen del contexto», además de toda cifra del JSON:
 * - en cada objeto con totales de este mes / el pasado / hace dos: sumas, diferencias, medias y variaciones %;
 * - presupuestos: lo que queda (límite − gastado), lo que queda por día, el % usado y el % que queda;
 * - períodos: diferencias y variaciones % entre meses y entre semanas, gasto/ingreso en %;
 * - recurrentes: la suma de lo pagado y de lo pendiente, de dos en dos, por tipo y por fecha; patrones: el gasto
 *   medio por movimiento del día;
 * - cuentas: la suma de los saldos positivos y de los negativos; necesidades: su % del total;
 * - categorías: su % del gasto del mes;
 * - las cifras del caso (`operands`, `expect.numbers`): sumas, diferencias, medias, cocientes y %.
 */
export function explainedValues(ctx: Json, extraOperands: number[]): number[] {
  const vals: number[] = [];
  numbersIn(ctx, vals);
  const visit = (o: Json) => {
    if (Array.isArray(o)) return o.forEach(visit);
    if (!o || typeof o !== "object") return;
    if (typeof o.total_current_month === "number" && typeof o.total_last_month === "number") {
      vals.push(...pairOps(o.total_current_month, o.total_last_month));
      if (typeof o.total_two_months_ago === "number") {
        vals.push(...pairOps(o.total_last_month, o.total_two_months_ago), ...pairOps(o.total_current_month, o.total_two_months_ago));
        vals.push(o.total_current_month + o.total_last_month + o.total_two_months_ago, (o.total_current_month + o.total_last_month + o.total_two_months_ago) / 3);
      }
    }
    Object.values(o).forEach(visit);
  };
  visit(ctx);
  for (const b of ctx.budgets ?? []) {
    const left = b.limit - b.spent;
    vals.push(Math.abs(left), 100 - (b.usage_percent ?? 0));
    if (b.days_left > 0) vals.push(Math.abs(left) / b.days_left, Math.abs(left) / (b.days_left + 1));
  }
  const P = ctx.periods;
  const months = [P.current_month, P.last_month, P.two_months_ago, P.three_months_ago];
  for (const k of ["expense", "income", "balance"]) {
    for (let i = 0; i < months.length; i++) for (let j = i + 1; j < months.length; j++) vals.push(...pairOps(months[i][k], months[j][k]));
    vals.push(...pairOps(P.current_week[k], P.last_week[k]), ...pairOps(P.today[k], P.current_week[k]));
  }
  for (const p of [...months, P.current_week, P.last_week, P.current_year]) if (p.income) vals.push((p.expense / p.income) * 100, 100 - (p.savings_rate_percent ?? 0));
  vals.push(...pairOps(P.last_4_weeks.reduce((a: number, w: Json) => a + w.expense, 0), 4));
  const paid = (ctx.recurring.paid_this_month as Json[]).reduce((a, x) => a + x.amount, 0);
  const pending = (ctx.recurring.pending_next_30_days as Json[]).reduce((a, x) => a + x.amount, 0);
  vals.push(paid, pending, paid + pending, ctx.recurring.totals.subscriptions_monthly + ctx.recurring.totals.recurring_monthly);
  // Sumas parciales de los pagos programados: de dos en dos, por tipo (suscripción / recurrente) y por fecha.
  for (const list of [ctx.recurring.paid_this_month, ctx.recurring.pending_next_30_days] as Json[][]) {
    for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) vals.push(list[i].amount + list[j].amount);
    const groups = new Map<string, number>();
    for (const x of list) for (const k of [`t:${x.type}`, `d:${x.date ?? x.due_date}`]) groups.set(k, (groups.get(k) ?? 0) + x.amount);
    vals.push(...groups.values());
  }
  for (const w of ctx.patterns.weekday_pattern_30_days) if (w.sample_size) vals.push(w.total / w.sample_size);
  const bal = (ctx.balances.accounts as Json[]).map((a) => a.balance as number);
  vals.push(bal.filter((x) => x > 0).reduce((a, x) => a + x, 0), Math.abs(bal.filter((x) => x < 0).reduce((a, x) => a + x, 0)));
  const nb = ctx.patterns.needs_breakdown_current_month;
  if (nb.total) for (const k of ["essential", "priority", "optional", "unclassified"]) vals.push((nb[k] / nb.total) * 100);
  if (P.current_month.expense) for (const c of ctx.categories) vals.push((c.total_current_month / P.current_month.expense) * 100);
  for (let i = 0; i < extraOperands.length; i++) for (let j = i + 1; j < extraOperands.length; j++) vals.push(...pairOps(extraOperands[i], extraOperands[j]));
  vals.push(extraOperands.reduce((a, x) => a + x, 0));
  return vals.filter((v) => Number.isFinite(v));
}

/** Enteros que no dicen nada del dinero: días del mes, meses, «100 %», «3 meses», años cercanos. */
function structural(x: number, decimals: number): boolean {
  if (decimals !== 0) return false;
  return (x >= 0 && x <= 31) || x === 100 || (x >= 2024 && x <= 2027);
}

export interface Fidelity {
  ok: boolean;
  unexplained: string[];
  numbers: number;
}

export function fidelity(answer: string, explained: number[]): Fidelity {
  const sorted = [...explained].sort((a, b) => a - b);
  const near = (x: number, d: number) => {
    // Búsqueda binaria del vecino; la tolerancia nunca pasa del 5 % de x o de 1.
    let lo = 0;
    let hi = sorted.length - 1;
    while (lo < hi) { const mid = (lo + hi) >> 1; if (sorted[mid] < x) lo = mid + 1; else hi = mid; }
    for (let i = Math.max(0, lo - 3); i <= Math.min(sorted.length - 1, lo + 3); i++) if (matchesValue(x, d, sorted[i])) return true;
    for (const v of sorted) if (Math.abs(v - x) <= Math.max(1, 0.05 * x) && matchesValue(x, d, v)) return true;
    return false;
  };
  const tokens = extractNumbers(answer);
  const unexplained: string[] = [];
  for (const tk of tokens) {
    const ok = tk.readings.some((r) => r.values.every((x) => structural(x, r.decimals) || near(x, r.decimals)));
    if (!ok) unexplained.push(tk.raw);
  }
  return { ok: unexplained.length === 0, unexplained, numbers: tokens.length };
}

// ---------- idioma ----------

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Nombres del usuario: no dicen nada del idioma de la respuesta («Plaza Vea», «Netflix», «外食»). */
export function contextNames(ctx: Json): string[] {
  const names = new Set<string>();
  for (const c of ctx.categories) { names.add(c.name); for (const s of c.subcategories) names.add(s.name); }
  for (const m of ctx.merchants_top_20) names.add(m.name);
  for (const b of ctx.budgets) names.add(b.name);
  for (const tg of ctx.tags_top_10) names.add(tg.name);
  for (const a of ctx.balances.accounts) names.add(a.name);
  for (const r of [...ctx.recurring.paid_this_month, ...ctx.recurring.pending_next_30_days]) { names.add(r.name); if (r.subcategory) names.add(r.subcategory); if (r.category) names.add(r.category); }
  for (const t of ctx.top_tx_by_subcategory) { names.add(t.subcategory_name); names.add(t.category_name); for (const x of t.transactions) if (x.merchant) names.add(x.merchant); }
  return [...names].filter((n) => n && n.length >= 2).sort((a, b) => b.length - a.length);
}

/**
 * Desempate para respuestas cortas, donde `detectLang` (pensado para sugerencias) empata: «Tienes S/ 120 en total»
 * solo tiene «en», que es español y francés. Palabras de función típicas de una respuesta sobre dinero; solo se
 * consultan si `detectLang` no decide, así que no cambian ningún veredicto que ya decidiera.
 */
const ANSWER_WORDS: Record<string, string[]> = {
  es: ["gasté", "pagué", "tienes", "tus", "tu", "te", "has", "llevas", "gastado", "gastaste", "cuentas", "quedan", "queda", "pasado", "presupuesto", "puedo", "ayudarte", "datos", "información", "año", "sobre", "menos", "ahora", "ya", "aún", "pagado", "pagaste", "superado", "excedido", "límite", "llevás", "tenés", "gastaste", "sumando", "solo", "tengo"],
  pt: ["paguei", "gastei", "recebi", "você", "tem", "seu", "sua", "seus", "suas", "gastou", "mês", "ainda", "não", "tenho", "dados", "orçamento", "limite", "já", "até", "agora", "pagou", "conseguiu", "poupar", "poupou", "sobram", "resta"],
  it: ["pagato", "ho", "hai", "tuo", "tua", "tuoi", "speso", "mese", "scorso", "ancora", "non", "ho", "dati", "già", "fino", "ora", "pagato", "rimangono", "resta", "restano", "superato"],
  fr: ["tu", "as", "ton", "ta", "tes", "dépensé", "mois", "dernier", "encore", "pas", "ai", "données", "déjà", "jusqu'ici", "maintenant", "payé", "reste", "vous", "avez", "votre", "vos"],
  de: ["du", "hast", "dein", "deine", "deinen", "ausgegeben", "monat", "letzten", "noch", "nicht", "habe", "daten", "bereits", "bisher", "jetzt", "bezahlt", "übrig", "insgesamt"],
  nl: ["je", "hebt", "jouw", "jij", "uitgegeven", "maand", "vorige", "nog", "niet", "heb", "gegevens", "al", "tot", "nu", "betaald", "over", "totaal", "jullie"],
  pl: ["masz", "twój", "twoje", "twoim", "wydałeś", "wydałaś", "miesiąc", "zeszłym", "jeszcze", "nie", "mam", "dane", "już", "teraz", "zapłaciłeś", "zostało", "łącznie", "razem"],
  en: ["you", "your", "have", "spent", "month", "last", "still", "not", "data", "already", "so", "far", "now", "paid", "left", "total", "has", "you've", "you're"],
};

/**
 * Palabras de función DISTINTIVAS por idioma para respuestas largas (la lista de `lang.ts` está pensada para
 * preguntas cortas, y en una respuesta portuguesa «que», «o» y «gasto» le daban la victoria al español). Las que
 * comparten dos idiomas puntúan en los dos; deciden las que no.
 */
const LONG_WORDS: Record<string, string[]> = {
  es: ["el", "los", "las", "del", "un", "una", "con", "en", "pero", "fue", "tu", "tus", "has", "mes", "ya", "eso", "esa", "hay", "tienes", "sin", "embargo", "más", "cuenta", "cuentas", "presupuesto", "pasado", "quedan", "queda", "solo", "puedo", "ayudarte", "es", "al", "lo", "se", "te", "por", "hasta", "muy", "aunque", "todavía", "aún", "llevas", "llevás", "tenés", "gastaste", "gastado", "este", "esta", "y"],
  pt: ["o", "os", "do", "da", "dos", "das", "um", "uma", "com", "em", "na", "nos", "nas", "mas", "foi", "teu", "tua", "teus", "tuas", "você", "seu", "sua", "mês", "já", "isso", "essa", "há", "tem", "tens", "não", "mais", "conta", "contas", "orçamento", "passado", "ainda", "só", "posso", "ajudar", "é", "ao", "pelo", "pela", "até", "muito", "embora", "ficou", "gastou", "gastaste", "este", "esta", "e"],
  it: ["il", "lo", "gli", "le", "un", "una", "con", "in", "ma", "è", "sei", "hai", "tuo", "tua", "tuoi", "del", "della", "dei", "delle", "nel", "nella", "questo", "questa", "mese", "già", "ancora", "non", "più", "che", "conto", "scorso", "speso", "solo", "posso", "aiutarti", "sono", "per", "fino", "molto", "anche", "e"],
  fr: ["le", "la", "les", "des", "un", "une", "avec", "en", "mais", "est", "tu", "ton", "ta", "tes", "vous", "votre", "vos", "du", "au", "aux", "ce", "cette", "mois", "déjà", "encore", "ne", "pas", "plus", "que", "qui", "compte", "dépensé", "dernier", "seulement", "peux", "aider", "sont", "pour", "très", "aussi", "as", "avez", "reste", "et"],
  de: ["der", "die", "das", "den", "dem", "ein", "eine", "einen", "mit", "in", "aber", "ist", "du", "hast", "dein", "deine", "deinen", "im", "am", "zum", "zur", "diesen", "diesem", "monat", "schon", "noch", "nicht", "kein", "mehr", "als", "konto", "ausgegeben", "letzten", "nur", "kann", "helfen", "sind", "für", "bis", "sehr", "auch", "und", "von", "bei"],
  // Sin «de», «en», «in», «is», «al» ni «op»: los comparte con el español, el portugués o el inglés, y una respuesta
  // portuguesa con seis «de» salía neerlandesa (medido el 2026-10-07).
  nl: ["het", "een", "met", "maar", "je", "jij", "jouw", "van", "deze", "dit", "maand", "nog", "niet", "geen", "meer", "dan", "rekening", "uitgegeven", "vorige", "alleen", "kan", "helpen", "zijn", "voor", "tot", "heel", "ook", "bij", "hebt", "heb", "uit", "wat", "hoeveel", "totaal", "nu"],
  pl: ["i", "w", "z", "na", "do", "nie", "jest", "są", "masz", "twój", "twoje", "twoim", "twojego", "ten", "to", "tym", "miesiąc", "miesiącu", "już", "jeszcze", "więcej", "niż", "konto", "wydałeś", "wydałaś", "wydatki", "poprzednim", "tylko", "mogę", "pomóc", "dla", "bardzo", "też", "oraz", "od", "za", "się"],
  en: ["the", "an", "with", "in", "but", "is", "you", "your", "you've", "you're", "of", "on", "this", "that", "month", "already", "still", "not", "more", "than", "account", "spent", "last", "only", "can", "help", "are", "for", "to", "very", "also", "and", "by", "at", "have", "has"],
};
/** Los meses también deciden: las respuestas los dicen («a 8 de outubro», «am 1. Oktober»). */
const MONTHS: Record<string, string[]> = {
  es: ["enero", "febrero", "marzo", "mayo", "junio", "julio", "septiembre", "setiembre", "octubre", "noviembre", "diciembre"],
  pt: ["janeiro", "fevereiro", "março", "maio", "junho", "julho", "setembro", "outubro", "novembro", "dezembro"],
  it: ["gennaio", "febbraio", "aprile", "maggio", "giugno", "luglio", "settembre", "ottobre", "dicembre"],
  fr: ["janvier", "février", "mars", "avril", "juin", "juillet", "août", "septembre", "octobre", "décembre"],
  de: ["januar", "februar", "märz", "dezember"],
  nl: ["januari", "februari", "maart", "mei", "augustus"],
  pl: ["stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca", "lipca", "sierpnia", "września", "października", "listopada", "grudnia", "październik", "listopad", "wrzesień"],
  en: ["january", "february", "march", "june", "july", "august", "september", "october", "december"],
};
for (const [lang, months] of Object.entries(MONTHS)) LONG_WORDS[lang].push(...months);

const LONG_MARKS: Record<string, RegExp> = { es: /[ñ¿¡]/g, pt: /[ãõ]|ç[ãõaoeu]/g, de: /[ßäöü]/g, pl: /[ąćęłńśźż]/g, fr: /[èêëàâîôûùœ]/g };

export function answerLanguage(answer: string, names: string[]): string {
  let t = answer.replace(/\*\*/g, " ");
  for (const n of names) t = t.replace(new RegExp(escapeRe(n), "giu"), " ");
  t = t.replace(/[\d.,%$€£¥]+/g, " ");
  if (/[\u3040-\u30ff]/.test(t)) return "ja";
  if (/[\u4e00-\u9fff]/.test(t)) return "zh";
  const tokens = t.toLowerCase().replace(/[¿?¡!:;()"“”«»*—–\-/]/g, " ").split(/\s+/).filter(Boolean);
  if (tokens.length < 6) return detectLangWithFallback(t);
  const score = Object.entries(LONG_WORDS).map(([lang, words]) => {
    const set = new Set(words);
    const marks = (t.match(LONG_MARKS[lang] ?? /$^/g) ?? []).length;
    return [lang, tokens.filter((w) => set.has(w)).length + 1.5 * Math.min(marks, 4)] as const;
  }).sort((a, b) => b[1] - a[1]);
  return score[0][1] > score[1][1] ? score[0][0] : detectLangWithFallback(t);
}

/** `detectLang` y, solo si empata, el desempate de `ANSWER_WORDS`. */
export function detectLangWithFallback(t: string): string {
  const first = detectLang(t);
  if (first !== "?") return first;
  const tokens = t.toLowerCase().replace(/[¿?¡!.,:;()"“”«»*]/g, " ").split(/\s+/).filter(Boolean);
  const ranked = Object.entries(ANSWER_WORDS)
    .map(([lang, words]) => [lang, tokens.filter((w) => words.includes(w)).length] as const)
    .sort((a, b) => b[1] - a[1]);
  return ranked[0][1] > 0 && ranked[0][1] > ranked[1][1] ? ranked[0][0] : "?";
}

// ---------- criterio ----------

export function gradeChatAnswer(content: string, c: ChatAnswerCase, p: Persona): Grade {
  // La app enseña `content` tal cual; solo falla si no hay texto (`ChatAssistantError.parseFailed`).
  const answer = content ?? "";
  if (!answer.trim()) return { pass: false, appParsed: false, detail: { error: "respuesta vacía" } };
  const b = personaContext(p);
  const ctx = b.context;
  const expNumbers = (c.expect?.numbers ?? []).map((r) => Number(resolveRef(ctx, r, b.lproj)));
  const operands = [...(c.operands ?? []).map((r) => Number(resolveRef(ctx, r, b.lproj))), ...expNumbers];
  const fromQuestion: number[] = [];
  for (const s of [c.question, ...(c.turns ?? []).flatMap((t) => [t.q, t.a])]) for (const tk of extractNumbers(s)) for (const r of tk.readings) fromQuestion.push(...r.values);
  const fid = fidelity(answer, [...explainedValues(ctx, operands), ...fromQuestion]);
  const target = baseLang(p.language);
  const lang = answerLanguage(answer, contextNames(ctx));
  const tokens = extractNumbers(answer);
  const hitNumber = expNumbers.length === 0 || tokens.some((tk) => tk.readings.some((r) => r.values.some((x) => expNumbers.some((v) => matchesValue(x, r.decimals, v)))));
  const expNames = (c.expect?.names ?? []).map((r) => String(resolveRef(ctx, r, b.lproj)));
  // Los nombres esperados son alternativas: basta uno (p. ej. el comercio con más gasto, o el primero que no es un pago fijo).
  const hitNames = expNames.length === 0 || expNames.some((n) => fold(answer).includes(fold(n)));
  const sentences = answer.split(/(?<=[.!?。！？])\s*/).filter((s) => s.trim().length > 1).length;
  let pass = fid.ok && lang === target;
  if (c.kind === "data") pass = pass && hitNumber && hitNames;
  // Fuera de tema: basta fidelidad e idioma. Que redirija (y no conteste la trivia) lo decide el juez; ofrecer de paso
  // una cifra real del usuario no inventa nada.
  return {
    pass,
    appParsed: true,
    detail: {
      det: pass,
      fidelity: fid.ok,
      ...(fid.unexplained.length ? { unexplained: fid.unexplained.slice(0, 8) } : {}),
      numbers: fid.numbers,
      lang,
      hitNumber,
      hitNames,
      expected: expNumbers.map((x) => Math.round(x * 100) / 100),
      sentences,
      chars: answer.length,
      answer: answer.slice(0, 2000),
    },
  };
}
