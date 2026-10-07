/**
 * Detector de idioma determinista para frases cortas (las sugerencias del chat, ≤ 80 caracteres).
 *
 * No pretende ser general: decide entre los 10 idiomas de la app con dos señales baratas y auditables.
 * 1. Escritura: kana → ja; han sin kana → zh.
 * 2. Palabras de función y marcas propias de cada idioma (tildes, ñ, ç, ß, ł, ij…). Gana el que más
 *    puntúa; empate o cero → «?» (cuenta como fallo de idioma: mejor estricto).
 *
 * Los nombres de datos del usuario (comercios, categorías) se quitan antes de puntuar: «Plaza Vea» o
 * «Netflix» no dicen nada del idioma de la frase.
 */
export type Lang = "es" | "en" | "pt" | "fr" | "de" | "it" | "nl" | "pl" | "ja" | "zh" | "?";

const WORDS: Record<Exclude<Lang, "ja" | "zh" | "?">, string[]> = {
  es: ["cuánto", "cuanto", "qué", "que", "cómo", "como", "mis", "mi", "en", "el", "la", "los", "las", "este", "esta", "mes", "gasté", "gaste", "gasto", "gastos", "más", "mas", "del", "por", "con", "para", "cuál", "cual", "dónde", "me", "queda", "presupuesto", "semana", "días", "día", "pagos", "he", "llevo", "comparado", "anterior", "pasado", "tengo", "y", "o", "es", "son", "hay", "voy"],
  en: ["how", "much", "what", "my", "the", "this", "month", "did", "i", "spend", "spent", "on", "in", "is", "are", "left", "budget", "which", "where", "when", "do", "compared", "last", "week", "most", "more", "than", "of", "for", "and", "have", "am", "per", "day", "average", "biggest", "top", "can"],
  pt: ["quanto", "quantos", "qual", "quais", "como", "meu", "minha", "meus", "minhas", "em", "no", "na", "nos", "este", "esse", "essa", "mês", "gastei", "gasto", "gastos", "mais", "do", "da", "com", "para", "onde", "sobra", "orçamento", "semana", "você", "tenho", "estou", "comparado", "anterior", "passado", "é", "são", "dia", "dias", "despesas", "pagamentos", "ainda"],
  fr: ["combien", "quel", "quelle", "quels", "comment", "mon", "ma", "mes", "en", "le", "la", "les", "ce", "cette", "mois", "dépensé", "dépenses", "dépense", "plus", "du", "des", "pour", "avec", "où", "reste", "budget", "semaine", "j'ai", "je", "est", "sont", "par", "jour", "au", "à", "que", "qu'est-ce", "est-ce"],
  de: ["wie", "viel", "was", "welche", "welcher", "wo", "mein", "meine", "meinen", "im", "in", "der", "die", "das", "diesen", "dieser", "monat", "ausgegeben", "ausgaben", "mehr", "als", "für", "mit", "noch", "übrig", "budget", "woche", "ich", "habe", "ist", "sind", "pro", "tag", "am", "letzten", "vormonat"],
  it: ["quanto", "quanti", "quale", "quali", "come", "mio", "mia", "miei", "mie", "in", "il", "lo", "la", "gli", "le", "questo", "questa", "mese", "speso", "spese", "spesa", "più", "del", "della", "per", "con", "dove", "resta", "rimane", "budget", "settimana", "ho", "è", "sono", "al", "giorno", "rispetto", "scorso"],
  nl: ["hoeveel", "wat", "welke", "hoe", "mijn", "in", "de", "het", "deze", "maand", "uitgegeven", "uitgaven", "meer", "dan", "van", "voor", "met", "waar", "over", "budget", "week", "ik", "heb", "is", "zijn", "per", "dag", "vorige", "aan", "nog"],
  pl: ["ile", "jaki", "jaka", "jakie", "jak", "mój", "moja", "moje", "moich", "w", "na", "ten", "tym", "tę", "miesiąc", "miesiącu", "wydałem", "wydałam", "wydatki", "wydatek", "więcej", "niż", "z", "dla", "gdzie", "zostało", "budżet", "budżetu", "tydzień", "tygodniu", "czy", "jest", "są", "dzień", "dziennie", "poprzednim", "się", "mi"],
};

const MARKS: Partial<Record<Lang, RegExp>> = {
  es: /[ñ¿¡]|ción\b/i,
  pt: /[ãõç]|ção\b|ões\b/i,
  fr: /[èêëàâîôûùœ]|\bl'|\bd'|\bj'|\bqu'/i,
  de: /[ßäöü]/i,
  it: /\bè\b|zione\b|\bun'|\bdell'|\bnell'/i,
  nl: /\bij|\boe|\baa|\bee/i,
  pl: /[ąćęłńśźż]/i,
};

export function detectLang(text: string, ignore: string[] = []): Lang {
  let t = text;
  for (const name of ignore) if (name) t = t.split(name).join(" ");
  if (/[぀-ヿ]/.test(t)) return "ja";
  if (/[一-鿿]/.test(t)) return "zh";
  const tokens = t.toLowerCase().replace(/[¿?¡!.,:;()"“”«»]/g, " ").split(/\s+/).filter(Boolean);
  const score: Record<string, number> = {};
  for (const [lang, words] of Object.entries(WORDS)) {
    const set = new Set(words);
    score[lang] = tokens.filter((w) => set.has(w)).length;
    const mark = MARKS[lang as Lang];
    if (mark && mark.test(t)) score[lang] += 1.5;
  }
  const ranked = Object.entries(score).sort((a, b) => b[1] - a[1]);
  if (ranked[0][1] === 0 || ranked[0][1] === ranked[1][1]) return "?";
  return ranked[0][0] as Lang;
}

/** `es-PE` → `es`, `zh-Hans-CN` → `zh`, `pt_BR` → `pt`. */
export function baseLang(locale: string): Lang {
  return locale.toLowerCase().split(/[-_]/)[0] as Lang;
}
