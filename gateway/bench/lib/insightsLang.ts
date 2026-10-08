import type { Lang } from "./lang";

/**
 * Detector de idioma para los textos de Insights y Tendencias: varias frases, no la pregunta corta de las
 * sugerencias (para esa sigue `lib/lang.ts`, que no se toca). Con frases enteras manda la frecuencia de palabras
 * gramaticales —artículos, preposiciones, conjunciones—, que cada idioma tiene propias; las marcas ortográficas solo
 * desempatan. Medido el 2026-10-07: el detector corto leía el portugués europeo («O gasto médio foi maior ao sábado»)
 * como francés, porque su lista no tiene «o», «e», «do», «da» y la «à» puntuaba como marca francesa.
 *
 * Y una segunda pregunta, porque los prompts de la app están en español: ¿se le escapó al modelo vocabulario del
 * prompt («gasto», «ingreso», «presupuesto»…) dentro de un texto en otro idioma? Es «Nunca mezcles idiomas» incumplido
 * aunque el idioma dominante sea el bueno (medido: «Wrz 26 był wyjątkiem: gasto wyniósł zł 9,841»).
 */

const FUNCTION_WORDS: Record<Exclude<Lang, "ja" | "zh" | "?">, string[]> = {
  // Solo palabras propias de cada idioma, o compartidas y listadas en TODOS los que las usan («o», «e», «do», «na», «i»,
  // «da»): una común a varios que solo figure en uno («de», «en», «del», «con») sesga hacia él.
  es: ["el", "los", "las", "y", "tus", "más", "día", "días", "mayor", "fue", "hay", "tienes", "puedes", "llevas", "ingresos", "promedio", "muy", "pero", "gastaste", "ingresaste", "sigue", "bajó", "subió", "están", "también"],
  pt: ["o", "os", "do", "da", "dos", "das", "em", "na", "nos", "nas", "e", "um", "uma", "teu", "tua", "teus", "tuas", "seu", "sua", "seus", "suas", "ao", "à", "aos", "mais", "mês", "foi", "é", "são", "com", "pelo", "pela", "também", "já", "você", "rendimento", "rendimentos", "receita", "despesas", "média", "maior", "dia", "dias", "face"],
  fr: ["le", "les", "du", "des", "et", "une", "avec", "pour", "par", "ton", "ta", "tes", "au", "aux", "est", "sont", "ce", "cette", "mois", "semaine", "plus", "moins", "dépenses", "revenus", "moyenne", "jour", "jours", "qui", "sur", "été", "ont", "pas", "dépensé"],
  it: ["il", "gli", "i", "di", "della", "dei", "delle", "e", "da", "per", "alla", "tuo", "tua", "tuoi", "tue", "è", "sono", "più", "meno", "questo", "questa", "mese", "settimana", "spese", "entrate", "giorno", "hai", "che", "nel", "nella", "rispetto", "speso"],
  de: ["der", "die", "das", "den", "dem", "des", "und", "im", "ist", "sind", "mit", "für", "von", "zu", "zum", "zur", "ein", "eine", "einen", "dein", "deine", "deinen", "deiner", "du", "hast", "mehr", "als", "diesen", "diesem", "monat", "woche", "ausgaben", "einnahmen", "durchschnitt", "auf", "bei", "nicht", "noch", "liegt", "ausgegeben"],
  nl: ["het", "een", "van", "op", "met", "voor", "je", "jouw", "zijn", "meer", "dan", "deze", "maand", "uitgaven", "inkomsten", "gemiddeld", "dag", "bij", "naar", "niet", "nog", "hebt", "uitgegeven"],
  pl: ["w", "na", "z", "i", "do", "o", "się", "nie", "jest", "są", "że", "twoje", "twój", "twoja", "twoich", "tym", "miesiąc", "miesiącu", "tydzień", "tygodniu", "wydatki", "wydatków", "wydałeś", "więcej", "niż", "przychody", "dochody", "średnio", "średni", "dzień", "przy", "od", "po"],
  en: ["the", "of", "and", "on", "to", "your", "you", "is", "are", "was", "with", "for", "than", "more", "this", "month", "week", "spending", "spent", "income", "average", "day", "at", "from", "an", "it", "its", "so", "which", "while", "up", "down"],
};

const MARKS: Partial<Record<Lang, RegExp>> = {
  es: /[ñ¿¡]/i,
  pt: /[ãõ]|ção\b|ções\b/i,
  fr: /[èêëîœ]|\bl'|\bd'|\bqu'/i,
  de: /[ßäöü]/i,
  it: /\bè\b|\bun'|\bdell'|\bnell'/i,
  pl: /[ąćęłńśźż]/i,
};

const SETS = Object.fromEntries(Object.entries(FUNCTION_WORDS).map(([k, v]) => [k, new Set(v)])) as Record<keyof typeof FUNCTION_WORDS, Set<string>>;

function tokens(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[0-9]+([.,][0-9]+)*/g, " ")
    .replace(/[¿?¡!.,:;()"“”«»*_%/\-–—+=\[\]{}]/g, " ")
    .split(/\s+/)
    .filter(Boolean);
}

function strip(text: string, ignore: string[]): string {
  let t = text;
  // Nombres de 3+ caracteres, o de 2 si son japonés/chino («外食», «打车»): sin quitarlos, una frase en español con
  // nombres de categorías japoneses salía «chino».
  for (const name of [...ignore].sort((a, b) => b.length - a.length)) {
    if (name.length >= 3 || (name.length === 2 && /[\u3040-\u30ff\u4e00-\u9fff]/.test(name))) t = t.split(name).join(" ");
  }
  return t;
}

export function detectLongLang(text: string, ignore: string[] = []): Lang {
  const t = strip(text, ignore);
  if (/[぀-ヿ]/.test(t)) return "ja";
  if (/[一-鿿]/.test(t)) return "zh";
  const toks = tokens(t);
  const score: Record<string, number> = {};
  for (const [lang, set] of Object.entries(SETS)) {
    score[lang] = toks.filter((w) => set.has(w)).length;
    const mark = MARKS[lang as Lang];
    if (mark && mark.test(t)) score[lang] += 1.5;
  }
  const ranked = Object.entries(score).sort((a, b) => b[1] - a[1]);
  if (ranked[0][1] === 0 || ranked[0][1] === ranked[1][1]) return "?";
  return ranked[0][0] as Lang;
}

/** Vocabulario de los prompts (en español) que no debería aparecer en un texto en otro idioma. */
const PROMPT_SPANISH = ["gasto", "gastos", "ingreso", "ingresos", "presupuesto", "presupuestos", "promedio", "ahorro", "periodo", "período", "transacción", "transacciones"];
/** Palabras de esa lista que también son del idioma de destino: en portugués «gasto(s)» y «período»; en italiano «periodo». */
const OWN: Partial<Record<Lang, Set<string>>> = {
  pt: new Set(["gasto", "gastos", "período", "periodo"]),
  it: new Set(["periodo"]),
};

export function promptLeak(text: string, target: Lang, ignore: string[] = []): string[] {
  if (target === "es" || target === "?") return [];
  const toks = tokens(strip(text, ignore));
  return [...new Set(toks.filter((w) => PROMPT_SPANISH.includes(w) && !OWN[target]?.has(w)))];
}
