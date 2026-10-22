/**
 * Métricas del banco de voz: error por palabra, importes y comercio en el texto transcrito.
 *
 * Normalización (la misma para la referencia y para la transcripción):
 *  1. NFKC y minúsculas.
 *  2. Fuera los símbolos de divisa ($, £, €, ¥, R$, S/): «£23.40» y «23.40» cuentan igual; «23 pounds 40» no.
 *  3. Cada número escrito en cifras se reescribe en una forma canónica: sin separador de miles y con punto
 *     decimal. Un separador seguido de exactamente 3 cifras es de miles («1.250», «2,400», «2 100»); con 1-2
 *     cifras, decimal («25,50», «42.50»). Así «25,50», «25.50» y «25.5» son la misma palabra.
 *  4. Toda la puntuación pasa a espacio (apóstrofos y guiones incluidos: «all'Eni» → «all eni»), salvo el punto
 *     decimal de un número. Las tildes se conservan.
 *  5. ja y zh: CER (error por carácter) sin espacios ni puntuación; el resto, WER por palabras.
 *
 * Números dichos en palabras: cada nota trae varias referencias aceptables (`ref` en cifras, `refAlt` con otras
 * grafías naturales y `tts`, el texto tal cual se dijo, con los números en letra) y el error es el MÍNIMO de las
 * tres. «veinticinco con cincuenta» contra «25,50» no penaliza si la transcripción entera está en letra.
 */

export type Lang = "es" | "en" | "pt" | "fr" | "de" | "it" | "nl" | "pl" | "ja" | "zh";

export const isCJK = (lang: string) => lang === "ja" || lang === "zh";

/** Interpreta un número escrito con separadores. Devuelve null si no lo es. */
export function parseNumber(tok: string): number | null {
  const t = tok.replace(/[\s  ]/g, " ");
  if (/^\d{1,3}( \d{3})+([.,]\d+)?$/.test(t)) return parseNumber(t.replace(/ /g, ""));
  if (!/^\d+([.,]\d+)*$/.test(t)) return null;
  const dots = (t.match(/\./g) ?? []).length;
  const commas = (t.match(/,/g) ?? []).length;
  if (dots && commas) {
    const dec = t.lastIndexOf(".") > t.lastIndexOf(",") ? "." : ",";
    const thou = dec === "." ? "," : ".";
    return Number(t.split(thou).join("").replace(dec, "."));
  }
  if (!dots && !commas) return Number(t);
  const sep = dots ? "." : ",";
  const parts = t.split(sep);
  if (parts.length > 2) return Number(parts.join(""));
  return parts[1].length === 3 ? Number(parts.join("")) : Number(`${parts[0]}.${parts[1]}`);
}

function canonNumber(v: number): string {
  return String(Number(v.toFixed(2)));
}

const NUM_RE = /\d{1,3}(?:[   ]\d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)*/g;

export function normalize(text: string, lang: string): string {
  let s = text.normalize("NFKC").toLowerCase();
  s = s.replace(/r\$|s\/(?=\s?\d)|[$£€¥￥]/g, " ");
  const spaced = !isCJK(lang) && lang !== "en";
  s = s.replace(spaced ? NUM_RE : /\d+(?:[.,]\d+)*/g, (m) => {
    const v = parseNumber(m);
    return v === null ? m : ` ${canonNumber(v)} `;
  });
  // Toda puntuación/símbolo → espacio, menos el punto decimal entre cifras.
  s = s.replace(/(?<!\d)\.|\.(?!\d)/g, " ").replace(/[^\p{L}\p{N}\p{M}.\s]/gu, " ");
  s = s.replace(/\s+/g, " ").trim();
  if (isCJK(lang)) s = s.replace(/ /g, "");
  return s;
}

function editDistance<T>(a: T[], b: T[]): number {
  const prev = new Array(b.length + 1).fill(0).map((_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    let diag = prev[0];
    prev[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const tmp = prev[j];
      prev[j] = Math.min(prev[j] + 1, prev[j - 1] + 1, diag + (a[i - 1] === b[j - 1] ? 0 : 1));
      diag = tmp;
    }
  }
  return prev[b.length];
}

function units(s: string, lang: string): string[] {
  return isCJK(lang) ? Array.from(s) : s.split(" ").filter(Boolean);
}

/** WER (o CER en ja/zh) contra la mejor de las referencias. 0..∞ (las inserciones pueden pasar de 1). */
export function errorRate(hyp: string, refs: string[], lang: string): number {
  const h = units(normalize(hyp, lang), lang);
  let best = Infinity;
  for (const r of refs) {
    const ru = units(normalize(r, lang), lang);
    if (!ru.length) continue;
    best = Math.min(best, editDistance(ru, h) / ru.length);
  }
  return best;
}

// ---------- importes ----------

const CJK_DIGITS: Record<string, number> = { 〇: 0, 零: 0, 一: 1, 二: 2, 两: 2, 兩: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9 };
const CJK_UNITS: Record<string, number> = { 十: 10, 百: 100, 千: 1000 };

/** «三十二点八» → 32.8, «二十八万» → 280000, «千二百» → 1200. */
export function parseCJKNumber(s: string): number | null {
  const [intPart, decPart] = s.split(/[点點]/);
  let total = 0;
  let section = 0;
  let digit = -1;
  for (const ch of intPart) {
    if (ch in CJK_DIGITS) digit = CJK_DIGITS[ch];
    else if (ch in CJK_UNITS) {
      section += (digit < 0 ? 1 : digit) * CJK_UNITS[ch];
      digit = -1;
    } else if (ch === "万" || ch === "萬") {
      total += (section + (digit < 0 ? 0 : digit) || 1) * 10_000;
      section = 0;
      digit = -1;
    } else return null;
  }
  total += section + (digit < 0 ? 0 : digit);
  if (decPart !== undefined) {
    const decs = Array.from(decPart).map((c) => CJK_DIGITS[c]);
    if (decs.some((d) => d === undefined)) return null;
    total += Number(`0.${decs.join("")}`);
  }
  return total;
}

const THOUSAND_WORDS = /^(mil|mille|thousand|k|tysięcy|tysiące|tysiąc|tausend|duizend|千)$/;

/**
 * Todos los importes que se pueden leer en cifras en el texto, con tolerancia de lectura: cada número suelto;
 * «45 mil» / «28万» con su multiplicador; y «23 pounds 40», «25 con 50», «1 euro e 20» (un entero seguido, a
 * dos palabras como mucho, de otro de 1-2 cifras) como 23.40. Los números en letra los cubre `amountPresent`
 * con la forma dicha de cada importe (manifiesto: `spoken`).
 */
export function amountsIn(text: string, lang: string): number[] {
  const out: number[] = [];
  const s = text.normalize("NFKC").toLowerCase().replace(/r\$|s\/(?=\s?\d)|[$£€¥￥]/g, " ");
  // Números árabes con su posición en tokens.
  const toks = s.replace(/(\d)\s*([万萬千])/g, "$1 $2 ").split(/[\s]+|(?<=[^\d.,])(?=\d)|(?<=\d)(?=[^\d.,\s])/).filter(Boolean);
  const nums: { i: number; v: number; raw: string }[] = [];
  const spaced = !isCJK(lang) && lang !== "en";
  for (let i = 0; i < toks.length; i++) {
    // Fuera lo que no es número por delante y por detrás, también el punto o la coma finales de la frase («$55.»).
    const raw = toks[i].replace(/[^\d.,]+$/, "").replace(/^[^\d]+/, "").replace(/[.,]+$/, "");
    if (!raw || !/\d/.test(raw)) continue;
    // «2 100» partido en dos tokens: júntalos si el segundo son 3 cifras justas.
    let v = parseNumber(raw);
    if (v === null) continue;
    if (spaced && i + 1 < toks.length && /^\d{3}$/.test(toks[i + 1]) && /^\d{1,3}$/.test(raw)) {
      out.push(v * 1000 + Number(toks[i + 1]));
    }
    nums.push({ i, v, raw });
    out.push(v);
    const next = toks[i + 1] ?? "";
    if (THOUSAND_WORDS.test(next)) out.push(v * 1000);
    if (next === "万" || next === "萬") out.push(v * 10_000);
  }
  for (let k = 0; k + 1 < nums.length; k++) {
    const a = nums[k];
    const b = nums[k + 1];
    if (b.i - a.i <= 3 && /^\d{1,2}$/.test(b.raw) && Number.isInteger(a.v)) out.push(a.v + b.v / 100);
  }
  // Números chinos/japoneses en caracteres.
  for (const m of s.matchAll(/[〇零一二两兩三四五六七八九十百千万萬点點]+/g)) {
    const v = parseCJKNumber(m[0]);
    if (v !== null && v > 0) out.push(v);
  }
  return out;
}

/**
 * El importe esperado está en la transcripción: en cifras (con la tolerancia de `amountsIn`) o, si se da `spoken`,
 * escrito en letra tal como se dijo («veinticinco con cincuenta», «forty-two fifty»), como palabras enteras tras
 * normalizar. Así no penaliza a un motor que deja los números en letra: la app los entiende igual.
 */
export function amountPresent(text: string, expected: number, lang: string, spoken?: string): boolean {
  const target = Math.abs(expected);
  if (amountsIn(text, lang).some((v) => Math.abs(v - target) < 0.005)) return true;
  if (!spoken) return false;
  const h = ` ${normalize(text, lang)} `;
  return h.includes(` ${normalize(spoken, lang)} `);
}

// ---------- comercio ----------

function fold(s: string): string {
  return s.normalize("NFKD").replace(/\p{M}/gu, "").toLowerCase();
}

/**
 * El comercio (o una grafía alternativa del manifiesto) aparece en el texto. Nombres de 4 o más letras (2 o más
 * caracteres CJK): subcadena del texto sin espacios ni puntuación («PlazaVea» vale por «Plaza Vea»). Más cortos
 * («dm», «Eni», «AH»): palabra entera, para no casar dentro de otra.
 */
export function merchantPresent(text: string, names: string[]): boolean {
  const ft = fold(text);
  const compact = ft.replace(/[^\p{L}\p{N}]/gu, "");
  const words = new Set(ft.split(/[^\p{L}\p{N}]+/u).filter(Boolean));
  return names.some((n) => {
    const c = fold(n).replace(/[^\p{L}\p{N}]/gu, "");
    if (!c) return false;
    const cjk = /[぀-ヿ一-鿿]/.test(c);
    if ((cjk && c.length >= 2) || c.length >= 4) return compact.includes(c);
    return words.has(c);
  });
}
