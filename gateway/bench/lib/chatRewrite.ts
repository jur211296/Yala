import type { Grade } from "./grading";
import { detectLangWithFallback } from "./chatAnswer";
import { baseLang } from "./lang";
import { interpolate, readRepoFile, swiftMultilineAfter } from "./swift";

/**
 * `chat.rewrite` — `SuggestionsRewriterService.rewrite`: cuando una sugerencia del chat nombra algo que el usuario
 * no tiene, una segunda llamada la reescribe con sus nombres reales. Hoy `gpt-4.1-mini`, temperatura 0.3,
 * `response_format: json_object`; corte de la app a los 8 s (`ChatSuggestionsConstants.timeoutSeconds`).
 *
 * Lo que hace la app con la respuesta (replicado): `parseRewritten` (JSON con `suggestions` = lista NO vacía de
 * strings; un elemento que no sea string tumba la respuesta) y, en `process`, cada frase nueva sustituye a la
 * inválida en su sitio si recortada no está vacía, mide ≤ 80 y pasa otra vez `isValid`; con menos de 3
 * sugerencias válidas al final, `tooFewItems` y la app cae a las sugerencias fijas.
 */

const SWIFT = "Yala/App/Services/SuggestionsRewriterService.swift";
const CONSTANTS = "Yala/App/Services/ChatSuggestionsLLMService.swift";

export interface Whitelist {
  categories: string[];
  subcategories: string[];
  budgets: string[];
  tags: string[];
  merchants: string[];
}

export interface RewriteCase {
  id: string;
  /** `context.language` de `ChatSuggestionsLLMService` (= `AppLocale.current.identifier`). */
  language: string;
  whitelist: Whitelist;
  /** Las sugerencias que salieron de `chat.suggestions`, en orden (válidas e inválidas). */
  suggestions: string[];
  /** Las que la app manda a reescribir (lo comprueba el test contra `isValid`). */
  invalid: string[];
  /** Nombres inventados que la reescritura no puede conservar. */
  forbidden: string[];
}

function constant(name: string): number {
  const m = readRepoFile(CONSTANTS).match(new RegExp(`static let ${name}(?:: \\w+)? = (\\d+)`));
  if (!m) throw new Error(`chatRewrite: no encuentro ChatSuggestionsConstants.${name}`);
  return Number(m[1]);
}

/** `Whitelist.toPromptSnippet()`: etiquetas y orden leídos del Swift. */
export function promptSnippet(w: Whitelist): string {
  const src = readRepoFile(SWIFT);
  const parts = [...src.matchAll(/parts\.append\("([^"]+): \\\((\w+)\.joined\(separator: ", "\)\)"\)/g)];
  if (parts.length !== 5) throw new Error(`chatRewrite: toPromptSnippet tiene ${parts.length} partes, esperaba 5`);
  return parts
    .map(([, label, field]) => ({ label, list: w[field as keyof Whitelist] }))
    .filter((p) => p.list.length > 0)
    .map((p) => `${p.label}: ${p.list.join(", ")}`)
    .join("\n");
}

export function rewriteSystemPrompt(language: string): string {
  return interpolate(swiftMultilineAfter(readRepoFile(SWIFT), "private func rewrite(", 0), { language });
}

export function rewriteUserPrompt(w: Whitelist, invalidTexts: string[]): string {
  const tpl = swiftMultilineAfter(readRepoFile(SWIFT), "private func rewrite(", 1);
  const lines = tpl.split("\n");
  const at = lines.findIndex((l) => l.startsWith("\\(invalidTexts.enumerated()"));
  if (at < 0) throw new Error("chatRewrite: cambió la lista numerada del mensaje de usuario");
  lines[at] = invalidTexts.map((t, i) => `${i + 1}. "${t}"`).join("\n");
  return interpolate(lines.join("\n"), { "whitelist.toPromptSnippet()": promptSnippet(w) });
}

export function rewriteBody(c: RewriteCase): Record<string, unknown> {
  return {
    messages: [
      { role: "system", content: rewriteSystemPrompt(c.language) },
      { role: "user", content: rewriteUserPrompt(c.whitelist, c.invalid) },
    ],
    model: "gpt-4.1-mini",
    response_format: { type: "json_object" },
    temperature: 0.3,
    stream: false,
  };
}

// ---------- réplica del validador de la app ----------

let commonCache: Set<string> | null = null;

function commonWords(): Set<string> {
  if (!commonCache) {
    const src = readRepoFile(SWIFT);
    const start = src.indexOf("private static let commonWords");
    const end = src.indexOf("]", start);
    commonCache = new Set([...src.slice(start, end).matchAll(/"([^"]+)"/g)].map((m) => m[1]));
  }
  return commonCache;
}

/** `isValid`: toda palabra con mayúscula inicial (menos la primera) es común, está en la lista o la contiene. */
export function isValidSuggestion(text: string, w: Whitelist): boolean {
  const all = [...w.categories, ...w.subcategories, ...w.budgets, ...w.tags, ...w.merchants].map((x) => x.toLowerCase());
  const set = new Set(all);
  const words = text.split(/[^\p{L}\p{N}\p{M}]+/u).filter(Boolean);
  if (words.length <= 1) return true;
  for (const word of words.slice(1)) {
    if (!/^\p{Lu}/u.test(word)) continue;
    const lower = word.toLowerCase();
    if (commonWords().has(lower) || set.has(lower)) continue;
    if (all.some((x) => x.includes(lower) || lower.includes(x))) continue;
    return false;
  }
  return true;
}

/** `parseRewritten`. `null` = la app lanza `malformedJSON`/`emptyArray`. */
export function parseRewritten(content: string): string[] | null {
  let obj: unknown;
  try {
    obj = JSON.parse(content);
  } catch {
    return null;
  }
  const arr = (obj as { suggestions?: unknown } | null)?.suggestions;
  if (!Array.isArray(arr) || arr.some((x) => typeof x !== "string") || arr.length === 0) return null;
  return arr as string[];
}

function fold(s: string): string {
  return s.toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
}

/**
 * ¿La frase usa este nombre? Literal, o declinado: en polaco «w Biedronce» es «Biedronka» y «na Rozrywkę» es
 * «Rozrywka», así que cada palabra del nombre (de 5 letras o más) vale si comparte raíz con una de la frase
 * (prefijo común de al menos la palabra menos 2 letras). Lo mismo cubre plurales y artículos pegados.
 */
export function usesName(text: string, name: string): boolean {
  const f = fold(text);
  const n = fold(name);
  if (f.includes(n)) return true;
  const words = f.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  const parts = n.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  if (!parts.length || parts.some((p) => p.length < 5)) return false;
  return parts.every((p) => words.some((w) => {
    let k = 0;
    while (k < Math.min(p.length, w.length) && p[k] === w[k]) k++;
    return k >= p.length - 2 && w.length <= p.length + 3;
  }));
}

function mentionsForbidden(text: string, forbidden: string[]): string | null {
  const f = fold(text);
  const words = f.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  for (const x of forbidden) {
    const fx = fold(x);
    if (fx.includes(" ") ? f.includes(fx) : words.some((w) => w.startsWith(fx)) || (/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u.test(f) && f.includes(fx))) return x;
  }
  return null;
}

/**
 * Pasa si: (1) `parseRewritten` la acepta; (2) devuelve tantas frases como se pidieron (el prompt lo exige y la
 * app las empareja por posición); y cada frase (3) recortada no está vacía y mide ≤ 80 caracteres; (4) está en el
 * idioma pedido (detector de bench/lib/lang.ts, sin los nombres del usuario); (5) no conserva ningún nombre
 * inventado de la original; y (6) al menos la mitad usa un nombre real del usuario. Aparte, sin entrar en el acierto, se mide
 * qué conserva la app de verdad: las frases que vuelven a pasar `isValid` y si al final quedan ≥ 3 sugerencias.
 * (En alemán `isValid` rechaza todo sustantivo con mayúscula, así que la app descarta casi cualquier frase: es un
 * fallo de la app que ningún modelo arregla, y por eso no cuenta en el acierto.)
 */
export function gradeRewrite(content: string, c: RewriteCase): Grade {
  const items = parseRewritten(content);
  if (!items) return { pass: false, appParsed: false, detail: { error: "parseRewritten de la app" } };
  const maxLen = constant("maxTextLength");
  const minItems = constant("minItems");
  const names = [...c.whitelist.categories, ...c.whitelist.subcategories, ...c.whitelist.budgets, ...c.whitelist.tags, ...c.whitelist.merchants];
  const target = baseLang(c.language);
  const problems: string[] = [];
  let appKept = 0;
  const result: string[] = [];
  let idx = 0;
  for (const original of c.suggestions) {
    if (!c.invalid.includes(original)) { result.push(original); continue; }
    if (idx >= items.length) continue;
    const t = items[idx++].trim();
    if (!t || [...t].length > maxLen) continue;
    if (isValidSuggestion(t, c.whitelist)) { result.push(t); appKept++; }
  }
  items.forEach((raw, i) => {
    const t = raw.trim();
    if (!t) problems.push(`${i + 1}: vacía`);
    else if ([...t].length > maxLen) problems.push(`${i + 1}: ${[...t].length} caracteres`);
    let stripped = t;
    for (const n of [...names].sort((a, b) => b.length - a.length)) stripped = stripped.replace(new RegExp(n.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "giu"), " ");
    const lang = detectLangWithFallback(stripped);
    if (lang !== target) problems.push(`${i + 1}: idioma ${lang}`);
    const bad = mentionsForbidden(t, c.forbidden);
    if (bad) problems.push(`${i + 1}: conserva «${bad}»`);
  });
  // Específicas: al menos la mitad usa un nombre real (el criterio de las sugerencias de la sesión 1). Una frase
  // genérica («¿Cuánto gasté este mes?») no inventa nada; que TODAS lo sean pierde la sugerencia.
  const named = items.filter((x) => names.some((n) => usesName(x, n))).length;
  if (named * 2 < items.length) problems.push(`solo ${named} de ${items.length} con un nombre real`);
  if (items.length !== c.invalid.length) problems.push(`devolvió ${items.length} de ${c.invalid.length}`);
  return {
    pass: problems.length === 0,
    appParsed: true,
    detail: {
      n: items.length,
      want: c.invalid.length,
      appKept,
      appEnough: result.length >= minItems,
      ...(problems.length ? { problems } : {}),
      items,
    },
  };
}
