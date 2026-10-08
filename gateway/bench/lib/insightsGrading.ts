import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import type { Grade } from "./grading";
import { baseLang, type Lang } from "./lang";
import { detectLongLang, promptLeak } from "./insightsLang";

/**
 * Criterio de las cuatro tareas de Insights y Tendencias (sesión 2, trabajador B).
 *
 * Orden, como en la sesión 1: primero lo que hace la APP con la respuesta (si su parser la rechaza, el usuario no
 * ve nada: fallo); después lo que se puede medir sin opinar:
 *  (a) FIDELIDAD a los números: todo número que el texto afirma sale de los datos, tal cual, redondeado o con una
 *      operación simple documentada en `derivableValues`. Un número que no sale de ahí es INVENTADO.
 *  (b) IDIOMA = el del usuario.
 *  (c) lo que pide la pantalla / el prompt de la app: cantidad de tarjetas, iconos que existen, longitud, una
 *      viñeta por gráfica presente, divisa delante del número.
 * Lo que no se puede medir así (¿contradice los datos?, ¿es útil?) lo mira un juez aparte (`insightsJudge.ts`); por
 * eso cada respuesta guarda su texto visible en `detail.out`. Los casos son públicos (datos inventados).
 */

// ---------- texto visible ----------

/** Quita el markdown que la app interpreta (`AttributedString(markdown:)`): negritas, cursivas, código. */
export function visible(text: string): string {
  return text.replace(/\*\*|__|`/g, "").replace(/(^|\s)\*(\S)/g, "$1$2").replace(/(\S)\*(\s|$)/g, "$1$2");
}

/** Longitud que ve el usuario (graphemes aproximados con code points). */
export function visibleLength(text: string): number {
  return [...visible(text).trim()].length;
}

// ---------- números ----------

export interface NumberClaim {
  raw: string;
  /**
   * Lecturas posibles del número, cada una con la unidad de su última cifra mostrada: «4.500» = 4500 (unidad 100)
   * ó 4,5 (unidad 0,001); «4,5 mil» = 4500 (unidad 100); «12,5 %» = 12,5 (unidad 0,1). En valor absoluto.
   */
  alts: { value: number; unit: number }[];
  kind: "pct" | "money" | "plain";
  index: number;
  end: number;
}

const SPACES = /[    ]/g;

function normalizeDigits(t: string): string {
  return t
    .replace(/[０-９]/g, (d) => String.fromCharCode(d.charCodeAt(0) - 0xfee0))
    .replace(/％/g, "%")
    .replace(/[．]/g, ".")
    // La coma china «，» es puntuación, no separador de miles: «约¥ 8,400，10月» son dos números.
    .replace(/[，、]/g, " ， ")
    .replace(/−/g, "-")
    .replace(SPACES, " ");
}

/** «4万5千» → «45000», «28万5000» → «285000»: las cantidades compuestas de japonés y chino. */
function expandCJK(t: string): string {
  return t
    .replace(/(\d+(?:\.\d+)?)万(\d+)千/g, (_, a, b) => String(Number(a) * 10_000 + Number(b) * 1000))
    .replace(/(\d+(?:\.\d+)?)万(\d{1,4})(?![\d千万.,])/g, (_, a, b) => String(Number(a) * 10_000 + Number(b)));
}

// Tras la abreviatura no puede seguir una letra de ningún alfabeto: «980 könnte» no es 980 mil (con `\b` sin la
// bandera `u`, la «ö» contaba como fin de palabra).
const NL = "(?![\\p{L}])";
const MULTIPLIERS: [RegExp, number][] = [
  [new RegExp(`^\\s?(?:mil(?![lh])|k${NL}|K${NL}|mille${NL}|Tsd\\.?|tys\\.?|thousand|千)`, "u"), 1_000],
  [/^\s?(?:万|萬)/u, 10_000],
  [/^\s?(?:億)/u, 100_000_000],
  [new RegExp(`^\\s?(?:M${NL}|mln${NL}|Mio\\.?|millones?${NL}|millions?${NL}|milhões${NL}|milhão${NL}|milioni${NL}|milione${NL}|miljoen${NL}|milion(?:y|ów)?${NL})`, "u"), 1_000_000],
];

/** Unidad de la última cifra de un entero: 4500 → 100 (topada al 10 % del valor, para que «5,000» no cubra 4.000–6.000). */
function intUnit(v: number): number {
  const digits = String(Math.trunc(Math.abs(v)));
  const zeros = digits.length > 1 ? digits.length - digits.replace(/0+$/, "").length : 0;
  return Math.min(10 ** zeros, Math.max(1, 0.1 * Math.abs(v)));
}

/** Lecturas de un token de cifras con separadores de cualquier idioma. */
export function interpretations(token: string): { value: number; unit: number }[] {
  let t = token;
  // Espacios o apóstrofos entre grupos de 3 = miles.
  if (/\d[ '’]\d{3}/.test(t)) t = t.replace(/[ '’]/g, "");
  const dots = (t.match(/\./g) ?? []).length;
  const commas = (t.match(/,/g) ?? []).length;
  const dec = (s: string, d: number) => ({ value: Number(s), unit: d > 0 ? 10 ** -d : intUnit(Number(s)) });
  if (!dots && !commas) return [dec(t, 0)];
  if (dots && commas) {
    const decSep = t.lastIndexOf(".") > t.lastIndexOf(",") ? "." : ",";
    const thou = decSep === "." ? "," : ".";
    const s = t.split(thou).join("").replace(decSep, ".");
    return [dec(s, s.split(".")[1]?.length ?? 0)];
  }
  const sep = dots ? "." : ",";
  if ((dots || commas) > 1) return [dec(t.split(sep).join(""), 0)];
  const after = t.split(sep)[1];
  // Tres cifras tras un único separador = miles («4.500», «4,500»): ningún importe ni porcentaje lleva tres decimales,
  // y leerlo también como 4,5 dejaba pasar cifras inventadas que casaban con algún valor pequeño.
  if (after.length === 3) return [dec(t.replace(sep, ""), 0)];
  return [dec(t.replace(sep, "."), after.length)];
}

const NUMBER_RE = /\d{1,3}(?:[ .,'’]\d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)?/g;
const PCT_AFTER = /^\s?(?:%|por ?ciento|percent|per cent|Prozent|procent|pour ?cent|per ?cento|por ?cento|パーセント)/i;

export interface MoneyMarkers {
  /** Lo que la app pone delante del número (código, símbolo, `currency_display`). */
  before: string[];
  /** Lo que, escrito DETRÁS del número, incumple «la divisa va ANTES» (incluye palabras nativas). */
  after: string[];
}

const NATIVE_AFTER: Record<string, string[]> = {
  PEN: ["soles", "sol"],
  ARS: ["pesos"],
  USD: ["dólares", "dolares", "dollars"],
  GBP: ["pounds", "libras"],
  BRL: ["reais"],
  EUR: ["euros", "euro", "Euro", "€"],
  PLN: ["złotych", "zł", "zl"],
  JPY: ["円", "yen"],
  CNY: ["元", "人民币"],
  MXN: ["pesos"],
};

export function moneyMarkers(code: string, symbol: string | undefined, display: string): MoneyMarkers {
  const before = [...new Set([code, display, symbol ?? code].filter(Boolean))];
  const after = [...new Set([...before, ...(NATIVE_AFTER[code] ?? [])])];
  return { before, after };
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
}

/** Todos los números que el texto afirma, con su tipo (porcentaje, importe, otro) y su precisión mostrada. */
export function extractNumbers(text: string, money?: MoneyMarkers): NumberClaim[] {
  const t = expandCJK(normalizeDigits(visible(text)));
  const out: NumberClaim[] = [];
  const beforeRe = money ? new RegExp(`(?:${money.before.map(escapeRe).join("|")})\\s?-?$`) : null;
  const afterRe = money ? new RegExp(`^\\s?(?:${money.after.map(escapeRe).join("|")})`) : null;
  for (const m of t.matchAll(NUMBER_RE)) {
    const index = m.index ?? 0;
    let end = index + m[0].length;
    let factor = 1;
    const rest = t.slice(end);
    for (const [re, f] of MULTIPLIERS) {
      const mm = rest.match(re);
      if (mm) {
        factor = f;
        end += mm[0].length;
        break;
      }
    }
    const tail = t.slice(end);
    const pctMatch = tail.match(PCT_AFTER);
    const head = t.slice(Math.max(0, index - 6), index);
    const isMoney = !pctMatch && !!money && (!!beforeRe?.test(head) || !!afterRe?.test(tail));
    out.push({
      raw: t.slice(index, end + (pctMatch?.[0].length ?? 0)),
      alts: interpretations(m[0]).map((a) => ({ value: Math.abs(a.value * factor), unit: a.unit * factor })),
      kind: pctMatch ? "pct" : isMoney ? "money" : "plain",
      index,
      end,
    });
  }
  return out;
}

/**
 * Exentos de la verificación: enteros pequeños (≤ 10) sin % ni divisa. Son conteos o sugerencias («3 categorías»,
 * «cocina 2 días más por semana», el ejemplo de tip del propio prompt) y casi cualquier dato los «explicaría».
 */
export function isExempt(c: NumberClaim): boolean {
  return c.kind === "plain" && c.alts.every((a) => Number.isInteger(a.value) && a.value <= 10);
}

// ---------- valores derivables de los datos ----------

type LeafKind = "amount" | "pct" | "count" | "label";

interface Leaf {
  path: string;
  key: string;
  value: number;
  kind: LeafKind;
}

const PCT_KEY = /pct|percent|variation/i;
const COUNT_KEY = /^count$|_count$|Count$|^months(Total|Positive|Negative)$|^active_groups$/;

function walk(v: unknown, path: string, key: string, leaves: Leaf[]): void {
  if (typeof v === "number") leaves.push({ path, key, value: v, kind: PCT_KEY.test(key) ? "pct" : COUNT_KEY.test(key) ? "count" : "amount" });
  else if (typeof v === "string") {
    for (const c of extractNumbers(v)) for (const a of c.alts) leaves.push({ path, key, value: a.value, kind: c.kind === "pct" ? "pct" : "label" });
    // «vs Sep 26» → también 2026.
    for (const m of v.matchAll(/(?<!\d)(\d{2})(?!\d)/g)) leaves.push({ path, key, value: 2000 + Number(m[1]), kind: "label" });
  } else if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${path}[${i}]`, key, leaves));
  else if (v && typeof v === "object") for (const [k, x] of Object.entries(v)) walk(x, path ? `${path}.${k}` : k, k, leaves);
}

export interface Derivable {
  /** Importes: tal cual, sumas/diferencias entre hermanos, medias, ×7/×30 de promedios diarios, ×12 de mensuales. */
  amount: number[];
  /** Porcentajes: los del JSON, partes sobre los totales principales y variaciones/cocientes entre hermanos. */
  pct: number[];
  /** Cocientes «1,5 veces», conteos, años y cifras de etiquetas. */
  other: number[];
}

/** Totales principales sobre los que tiene sentido calcular «qué parte es»: ingresos, gastos, previsto, límite… */
const MAIN_TOTAL = /^(total_expense|total_income|totalExcess|startingBalance|income|expense|previous|current|limit|planned|monthly_total|total_shared|total_personal)$/;

/**
 * El conjunto de valores que un texto fiel puede citar, por tipo. Operaciones admitidas (y ninguna más):
 *  1. cada valor del JSON (números y los que van dentro de textos: «12%», «vs Sep 26» → 26 y 2026), en absoluto;
 *  2. entre HERMANOS (campos de un mismo objeto; la misma clave a lo largo de un array; los importes de primer
 *     nivel): suma y diferencia de dos, suma de tres, y suma, media y máximo−mínimo del grupo (lo que hay entre
 *     bloques distintos, ver `DerivableOptions`);
 *  3. porcentajes: los del JSON; la parte de cada importe sobre un total principal (`MAIN_TOTAL`) de su mismo
 *     objeto o de primer nivel; y entre dos importes hermanos, cociente·100 y variación ((a−b)/b·100);
 *  4. cocientes (a/b, «casi el doble») entre importes hermanos, e importe/conteo del mismo objeto (media por ítem);
 *  5. promedios diarios ×7, ×28, ×30, ×31 y mensuales ×12.
 * Una proyección de varios pasos («llegarías al límite el día 24») queda sin verificar: si es correcta, la revisión
 * manual la rescata; si no lo es, es justo lo que se busca.
 */
/**
 * Operaciones extra, medidas el 2026-10-07 con la sensibilidad (importes alterados ±7-15 % que el verificador caza,
 * sobre las respuestas reales de la criba; Insights / flujo / desviaciones / Tendencias):
 * - base: 63 / 88 / 50 / 67 %;
 * - `crossPairs` (suma, resta y cociente entre DOS importes cualesquiera): 41 / 84 / 44 / 48 %;
 * - `weekly` (/4 y /30 de cada importe): 57 / 87 / 39 / 64 %;
 * - `triples` (suma de tres hermanos): 60 / 88 / 50 / 64 %.
 * Por defecto solo `triples`: la aritmética entre bloques distintos (que es correcta a menudo) se marca y se revisa
 * a mano en las finalistas (`insights.flagged-review.json`). Mejor marcar de más y revisar que dejar pasar inventados.
 */
export interface DerivableOptions {
  crossPairs?: boolean;
  weekly?: boolean;
  triples?: boolean;
}

export function derivableValues(data: unknown, opts: DerivableOptions = {}): Derivable {
  const { crossPairs = false, weekly = false, triples = true } = opts;
  const leaves: Leaf[] = [];
  walk(data, "", "", leaves);
  const amount = new Set<number>();
  const pct = new Set<number>();
  const other = new Set<number>();
  const add = (s: Set<number>, x: number) => {
    if (Number.isFinite(x)) s.add(Math.abs(x));
  };
  for (const l of leaves) add(l.kind === "amount" ? amount : l.kind === "pct" ? pct : other, l.value);

  const groups = new Map<string, Leaf[]>();
  const push = (g: string, l: Leaf) => groups.set(g, [...(groups.get(g) ?? []), l]);
  const parentOf = (p: string) => (p.includes(".") ? p.slice(0, p.lastIndexOf(".")) : "$root");
  for (const l of leaves) {
    push(`obj:${parentOf(l.path)}`, l);
    const arrayKey = l.path.replace(/\[\d+\]/g, "[]");
    if (arrayKey !== l.path) push(`arr:${arrayKey}`, l);
  }
  for (const [name, members] of groups) {
    const amountLeaves = members.filter((l) => l.kind === "amount");
    const amounts = [...new Set(amountLeaves.map((l) => l.value))];
    // Porcentajes entre hermanos solo donde la comparación tiene sentido: la misma clave a lo largo de un array
    // (meses, categorías), un objeto pequeño (gastado/límite, actual/anterior, previsto/real) o un total principal
    // como denominador. Entre importes cualesquiera de primer nivel cubriría casi cualquier cifra.
    const pctPairs = name.startsWith("arr:") || amounts.length <= 4;
    for (const a of amounts) for (const bl of amountLeaves) {
      const b = bl.value;
      if (a === b) continue;
      add(amount, a + b);
      add(amount, a - b);
      if (b !== 0) {
        add(other, a / b);
        if (pctPairs || MAIN_TOTAL.test(bl.key)) {
          add(pct, (a / b) * 100);
          add(pct, ((a - b) / Math.abs(b)) * 100);
        }
      }
    }
    if (amounts.length > 1) {
      const sum = amounts.reduce((x, y) => x + y, 0);
      add(amount, sum);
      add(amount, sum / amounts.length);
      add(amount, Math.max(...amounts) - Math.min(...amounts));
    }
    if (name.startsWith("obj:")) {
      const counts = members.filter((l) => l.kind === "count" && l.value > 0);
      for (const a of amounts) for (const c of counts) add(amount, a / c.value);
    }
  }
  // Entre DOS importes cualesquiera (de objetos distintos), solo con `crossPairs`: «recurrentes + suscripciones =
  // 662.400» o «saldo − pendientes = 54» son aritmética correcta, pero admitirla sin mirar baja la sensibilidad del
  // 63 al 41 % (ver `DerivableOptions`).
  const allAmounts = [...new Set(leaves.filter((l) => l.kind === "amount").map((l) => l.value))];
  for (let i = 0; i < allAmounts.length; i++) {
    const a = allAmounts[i];
    // Semanal y diario de un importe mensual («un tope semanal de 45.000» = 180.000 / 4).
    if (weekly) {
      add(amount, a / 4);
      add(amount, a / 30);
    }
    if (!crossPairs) continue;
    for (let j = i + 1; j < allAmounts.length; j++) {
      const b = allAmounts[j];
      add(amount, a + b);
      add(amount, a - b);
      if (a !== 0 && b !== 0) {
        add(other, a / b);
        add(other, b / a);
      }
    }
  }
  // Sumas de TRES hermanos («Mieszkanie, Jedzenie i Transport razem: 4.660»).
  for (const [, members] of groups) {
    const g = [...new Set(members.filter((l) => l.kind === "amount").map((l) => l.value))];
    if (!triples || g.length < 3 || g.length > 8) continue;
    for (let i = 0; i < g.length; i++) for (let j = i + 1; j < g.length; j++) for (let k = j + 1; k < g.length; k++) add(amount, g[i] + g[j] + g[k]);
  }
  // Partes sobre los totales principales del mismo objeto o de primer nivel.
  const totals = leaves.filter((l) => l.kind === "amount" && MAIN_TOTAL.test(l.key) && l.value !== 0);
  for (const t of totals) {
    const scope = parentOf(t.path);
    for (const l of leaves) {
      if (l.kind !== "amount") continue;
      const lp = parentOf(l.path);
      if (scope === "$root" || lp === scope || lp.startsWith(`${scope}.`) || lp.startsWith(`${scope}[`)) add(pct, (l.value / t.value) * 100);
    }
  }
  for (const l of leaves) {
    if (l.kind !== "amount") continue;
    if (/avg|average|daily/i.test(l.key)) for (const k of [7, 28, 30, 31]) add(amount, l.value * k);
    if (/monthly/i.test(l.key)) add(amount, l.value * 12);
  }
  return { amount: [...amount], pct: [...pct], other: [...other] };
}

export interface NumberCheck {
  claims: number;
  verified: number;
  unverified: string[];
}

/** ¿Sale la cifra de los datos? Acepta cualquier redondeo (o truncado) coherente con la precisión mostrada. */
export function claimMatches(c: NumberClaim, d: Derivable): boolean {
  // Un número sin «%» ni divisa no se compara con los porcentajes derivados: son tantos que lo explicarían casi todo.
  const pool = c.kind === "pct" ? d.pct : c.kind === "money" ? d.amount : [...d.amount, ...d.other];
  return c.alts.some((a) => {
    // Porcentaje: el dato redondeado o truncado (la app trunca con `Int()`; el modelo puede redondear): a menos de
    // 1 punto, estricto. Importe: dentro de la unidad mostrada («4,500» cubre de 4.400 a 4.600; «4,523», ±1).
    if (c.kind === "pct") return pool.some((x) => Math.abs(a.value - x) < Math.max(1, a.unit));
    const tol = Math.max(a.unit, 0.501);
    return pool.some((x) => Math.abs(a.value - x) <= tol);
  });
}

export function checkNumbers(texts: string[], derivable: Derivable, money?: MoneyMarkers): NumberCheck & { perText: number[] } {
  let claims = 0;
  let verified = 0;
  const unverified: string[] = [];
  const perText: number[] = [];
  for (const text of texts) {
    let ok = 0;
    for (const c of extractNumbers(text, money)) {
      if (isExempt(c)) continue;
      claims++;
      if (claimMatches(c, derivable)) {
        verified++;
        ok++;
      } else unverified.push(c.raw.trim());
    }
    perText.push(ok);
  }
  return { claims, verified, unverified, perText };
}

/**
 * Sensibilidad del verificador: de cada cifra verificada se fabrican versiones alteradas (×0,85, ×0,93, ×1,07,
 * ×1,15, con la misma precisión) y se mide qué fracción sale como «sin respaldo». Es la tasa con la que el criterio
 * caza un número inventado que se parece a uno real.
 */
export function perturbationSensitivity(texts: string[], derivable: Derivable, money?: MoneyMarkers): Record<"pct" | "amount", { tried: number; caught: number }> {
  const out = { pct: { tried: 0, caught: 0 }, amount: { tried: 0, caught: 0 } };
  for (const text of texts) {
    for (const c of extractNumbers(text, money)) {
      if (isExempt(c) || !claimMatches(c, derivable)) continue;
      const a = c.alts[0];
      const bucket = c.kind === "pct" ? out.pct : out.amount;
      for (const f of [0.85, 0.93, 1.07, 1.15]) {
        const v = Math.round((a.value * f) / a.unit) * a.unit;
        if (Math.abs(v - a.value) < a.unit) continue;
        bucket.tried++;
        if (!claimMatches({ ...c, alts: [{ value: v, unit: a.unit }] }, derivable)) bucket.caught++;
      }
    }
  }
  return out;
}

/** «4.500 €», «120 zł», «285,000円»: la divisa DETRÁS del número, que el prompt de la app prohíbe. */
export function currencyAfterNumber(texts: string[], money: MoneyMarkers): string[] {
  const hits: string[] = [];
  // Tras un marcador latino («EUR», «soles») no puede seguir otra letra; tras «円» o «元» sí (no hay espacios en CJK).
  const alt = money.after.map((a) => `${escapeRe(a)}${/[A-Za-z]$/.test(a) ? "(?![A-Za-z])" : ""}`).join("|");
  const re = new RegExp(`^\\s?(?:${alt})`, "u");
  for (const text of texts) {
    const t = expandCJK(normalizeDigits(visible(text)));
    for (const c of extractNumbers(text, money)) {
      const tail = t.slice(c.end);
      if (re.test(tail)) hits.push(`${c.raw}${tail.slice(0, 6)}`.trim());
    }
  }
  return hits;
}

// ---------- idioma ----------

/**
 * Idioma del texto sin los nombres de los datos (categorías, días, etiquetas: ya vienen en el idioma del usuario).
 * Con el detector de textos largos (`insightsLang.ts`): el corto de la sesión 1 leía el portugués europeo como francés.
 */
export function languageOf(texts: string[], dataStrings: string[]): Lang {
  const names = dataStrings.filter((s) => s.length >= 2);
  return detectLongLang(texts.map((t) => visible(t)).join(" "), names);
}

export function dataStringsOf(data: unknown): string[] {
  const out: string[] = [];
  const rec = (v: unknown) => {
    if (typeof v === "string") out.push(v);
    else if (Array.isArray(v)) v.forEach(rec);
    else if (v && typeof v === "object") Object.values(v).forEach(rec);
  };
  rec(data);
  return out;
}

// ---------- SF Symbols ----------

let symbols: Set<string> | null | undefined;

/**
 * Nombres de SF Symbols que pinta iOS 26 (el target de Yala), leídos del catálogo del propio Mac
 * (`CoreGlyphs.bundle/name_availability.plist`, con su año de publicación) más sus alias. `null` fuera de macOS:
 * entonces no se comprueban los iconos y el detalle lo dice.
 */
export function sfSymbols(): Set<string> | null {
  if (symbols !== undefined) return symbols;
  const dir = "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources";
  if (!existsSync(`${dir}/name_availability.plist`)) return (symbols = null);
  const avail = JSON.parse(String(execFileSync("plutil", ["-convert", "json", "-o", "-", `${dir}/name_availability.plist`]))) as {
    symbols: Record<string, string>;
    year_to_release: Record<string, { iOS: string }>;
  };
  const ok = new Set<string>();
  const iosMajorMinor = (v: string) => v.split(".").map(Number);
  for (const [name, year] of Object.entries(avail.symbols)) {
    const ios = avail.year_to_release[year]?.iOS;
    if (!ios) continue;
    const [maj, min] = iosMajorMinor(ios);
    if (maj < 26 || (maj === 26 && (min ?? 0) === 0)) ok.add(name);
  }
  if (existsSync(`${dir}/name_aliases.strings`)) {
    const aliases = JSON.parse(String(execFileSync("plutil", ["-convert", "json", "-o", "-", `${dir}/name_aliases.strings`]))) as Record<string, string>;
    for (const [alias, target] of Object.entries(aliases)) if (ok.has(target)) ok.add(alias);
  }
  return (symbols = ok);
}

// ---------- parsers de la app ----------

export interface CardsOut {
  hero: string;
  cards: { icon: string; text: string; sentiment: string; tip: string | null }[];
  funFact: string | null;
}

/** Réplica de `InsightsLLMService.parseResponse`. */
export function parseCards(content: string): CardsOut | null {
  let dict: unknown;
  try {
    dict = JSON.parse(content);
  } catch {
    return null;
  }
  if (!dict || typeof dict !== "object" || Array.isArray(dict)) return null;
  const d = dict as Record<string, unknown>;
  if (typeof d.hero !== "string") return null;
  const cards: CardsOut["cards"] = [];
  // `dict["cards"] as? [[String: Any]]`: si algún elemento no es un objeto, el cast falla y no hay tarjetas.
  if (Array.isArray(d.cards) && d.cards.every((c) => c && typeof c === "object" && !Array.isArray(c))) {
    for (const c of d.cards as Record<string, unknown>[]) {
      if (typeof c.text !== "string") continue;
      cards.push({
        icon: typeof c.icon === "string" ? c.icon : "sparkles",
        text: c.text,
        sentiment: typeof c.sentiment === "string" ? c.sentiment : "neutral",
        tip: typeof c.tip === "string" ? c.tip : null,
      });
    }
  }
  return { hero: d.hero, cards, funFact: typeof d.funFact === "string" ? d.funFact : null };
}

/** Réplica de la lectura de `{"comment": …}` (flujo de caja y desviaciones). `undefined` = la app lanza `parseFailed`. */
export function parseComment(content: string): { comment: string | null } | undefined {
  let dict: unknown;
  try {
    dict = JSON.parse(content);
  } catch {
    return undefined;
  }
  if (!dict || typeof dict !== "object" || Array.isArray(dict)) return undefined;
  const c = (dict as Record<string, unknown>).comment;
  return { comment: typeof c === "string" ? c : null };
}

export type TrendsChart = "trend" | "comparison" | "cashflow" | "weekday";

/** Réplica de `TrendsAIService.parseResponse` + `source(for:)`. `null` = la app lanza `parseFailed`. */
export function parseTrends(content: string): { chart: TrendsChart | null; rawChart: unknown; text: string }[] | null {
  let dict: unknown;
  try {
    dict = JSON.parse(content);
  } catch {
    return null;
  }
  if (!dict || typeof dict !== "object" || Array.isArray(dict)) return null;
  const items = (dict as Record<string, unknown>).bullets;
  if (!Array.isArray(items) || !items.every((x) => x && typeof x === "object" && !Array.isArray(x))) return null;
  const out: { chart: TrendsChart | null; rawChart: unknown; text: string }[] = [];
  for (const item of items as Record<string, unknown>[]) {
    if (typeof item.text !== "string") continue;
    const text = item.text.trim();
    if (!text) continue;
    const raw = item.chart;
    const chart = typeof raw === "string" ? sourceFor(raw) : null;
    out.push({ chart, rawChart: raw, text });
    if (out.length === 4) break;
  }
  return out.length ? out : null;
}

function sourceFor(chart: string): TrendsChart | null {
  switch (chart.toLowerCase()) {
    case "trend":
      return "trend";
    case "comparison":
      return "comparison";
    case "cashflow":
    case "cash_flow":
      return "cashflow";
    case "weekday":
      return "weekday";
    default:
      return null;
  }
}

// ---------- criterios por tarea ----------

export interface GradeContext {
  data: Record<string, unknown>;
  /** Idioma que el usuario espera (el de la app). */
  locale: string;
  money: MoneyMarkers;
}

function common(texts: string[], ctx: GradeContext) {
  const derivable = derivableValues(ctx.data);
  const numbers = checkNumbers(texts, derivable, ctx.money);
  const names = dataStringsOf(ctx.data);
  const lang = languageOf(texts, names);
  const target = baseLang(ctx.locale);
  const after = currencyAfterNumber(texts, ctx.money);
  // «Nunca mezcles idiomas»: vocabulario del prompt (en español) dentro de un texto en otro idioma.
  const leak = promptLeak(texts.map((t) => visible(t)).join(" "), target, names);
  // «?» = texto demasiado corto para decidir («En ene 2027 tu saldo acumulado bajará a € -450»): no es fallo; se anota.
  return { numbers, lang, langOk: (lang === target || lang === "?") && leak.length === 0, after, leak };
}

export const CARDS_MIN = 3;
export const CARDS_MAX = 6;

export function gradeCards(content: string, ctx: GradeContext): Grade {
  const parsed = parseCards(content);
  if (!parsed) return { pass: false, appParsed: false, detail: { error: "parser de la app (hero)" } };
  const texts = [parsed.hero, ...parsed.cards.flatMap((c) => [c.text, c.tip ?? ""]), parsed.funFact ?? ""].filter(Boolean);
  const c = common(texts, ctx);
  const sym = sfSymbols();
  const badIcons = sym ? parsed.cards.map((x) => x.icon).filter((i) => !sym.has(i)) : [];
  const heroNums = checkNumbers([parsed.hero], derivableValues(ctx.data), ctx.money);
  const failures: string[] = [];
  if (parsed.cards.length < CARDS_MIN || parsed.cards.length > CARDS_MAX) failures.push(`tarjetas=${parsed.cards.length}`);
  if (parsed.cards.some((x) => !x.text.trim())) failures.push("tarjeta vacía");
  if (badIcons.length) failures.push("icono inexistente");
  if (!c.langOk) failures.push(`idioma=${c.lang}${c.leak.length ? ` (mezcla: ${c.leak.join(",")})` : ""}`);
  if (c.numbers.unverified.length) failures.push("número sin respaldo");
  if (heroNums.verified === 0) failures.push("hero sin cifra");
  if (c.after.length) failures.push("divisa detrás");
  return {
    pass: failures.length === 0,
    appParsed: true,
    detail: {
      failures,
      cards: parsed.cards.length,
      lang: c.lang,
      claims: c.numbers.claims,
      unverified: c.numbers.unverified,
      currencyAfter: c.after,
      badIcons,
      ...(sym ? {} : { icons: "sin catálogo de SF Symbols: no se comprueban" }),
      badSentiment: parsed.cards.filter((x) => !["positive", "neutral", "attention"].includes(x.sentiment)).length,
      heroLen: visibleLength(parsed.hero),
      out: parsed,
    },
  };
}

/** Prompt: «máximo 150 caracteres». Fallo por encima de 150 × 1,2: ya no es «una sola oración corta». */
export const COMMENT_MAX = 150;
export const COMMENT_HARD = Math.round(COMMENT_MAX * 1.2);

export function gradeComment(content: string, ctx: GradeContext, allowNull: boolean): Grade {
  const parsed = parseComment(content);
  if (!parsed) return { pass: false, appParsed: false, detail: { error: "parser de la app" } };
  const comment = parsed.comment;
  if (comment === null) {
    return { pass: allowNull, appParsed: true, detail: { failures: allowNull ? [] : ["comment null"], out: { comment: null } } };
  }
  const failures: string[] = [];
  const len = visibleLength(comment);
  if (!comment.trim()) failures.push("comentario vacío");
  const c = common([comment], ctx);
  if (len > COMMENT_HARD) failures.push(`largo=${len}`);
  if (!c.langOk) failures.push(`idioma=${c.lang}${c.leak.length ? ` (mezcla: ${c.leak.join(",")})` : ""}`);
  if (c.numbers.unverified.length) failures.push("número sin respaldo");
  if (c.after.length) failures.push("divisa detrás");
  return {
    pass: failures.length === 0,
    appParsed: true,
    detail: {
      failures,
      len,
      within150: len <= COMMENT_MAX,
      lang: c.lang,
      claims: c.numbers.claims,
      unverified: c.numbers.unverified,
      currencyAfter: c.after,
      out: { comment },
    },
  };
}

/** Prompt: «Máximo 110 caracteres por bullet». Fallo por encima de 110 × 1,2. */
export const BULLET_MAX = 110;
export const BULLET_HARD = Math.round(BULLET_MAX * 1.2);

export function presentCharts(data: Record<string, unknown>): TrendsChart[] {
  const out: TrendsChart[] = [];
  if (Array.isArray(data.history_completed_periods) && data.history_completed_periods.length) out.push("trend");
  if (data.comparison) out.push("comparison");
  if (data.cash_flow) out.push("cashflow");
  if (Array.isArray(data.weekday_avg_expense) && data.weekday_avg_expense.length) out.push("weekday");
  return out;
}

export function gradeTrends(content: string, ctx: GradeContext): Grade {
  const bullets = parseTrends(content);
  if (!bullets) return { pass: false, appParsed: false, detail: { error: "parser de la app (bullets)" } };
  const texts = bullets.map((b) => b.text);
  const c = common(texts, ctx);
  const present = presentCharts(ctx.data);
  const got = bullets.map((b) => b.chart);
  const failures: string[] = [];
  if (got.some((x) => x === null)) failures.push("chart inválido");
  const set = new Set(got.filter(Boolean));
  if (set.size !== got.length) failures.push("chart repetido");
  if (present.some((p) => !set.has(p)) || [...set].some((s) => s && !present.includes(s))) failures.push(`charts=${got.join(",")} (esperado ${present.join(",")})`);
  const lens = texts.map(visibleLength);
  if (lens.some((l) => l > BULLET_HARD)) failures.push(`largo=${Math.max(...lens)}`);
  if (c.numbers.perText.some((n) => n === 0)) failures.push("viñeta sin cifra");
  if (!c.langOk) failures.push(`idioma=${c.lang}${c.leak.length ? ` (mezcla: ${c.leak.join(",")})` : ""}`);
  if (c.numbers.unverified.length) failures.push("número sin respaldo");
  if (c.after.length) failures.push("divisa detrás");
  const inOrder = got.join(",") === present.filter((p) => set.has(p)).join(",");
  return {
    pass: failures.length === 0,
    appParsed: true,
    detail: {
      failures,
      n: bullets.length,
      charts: got,
      inOrder,
      maxLen: Math.max(...lens),
      within110: lens.every((l) => l <= BULLET_MAX),
      lang: c.lang,
      claims: c.numbers.claims,
      unverified: c.numbers.unverified,
      currencyAfter: c.after,
      out: { bullets: bullets.map((b) => ({ chart: b.rawChart, text: b.text })) },
    },
  };
}
