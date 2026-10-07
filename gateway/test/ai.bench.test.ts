/**
 * El banco (bench/) sin red: que mide lo que manda la app y que puntúa como dice su criterio.
 *
 * - Los prompts salen del Swift y son los de verdad: si el extractor fallara en silencio, el banco
 *   mediría otro prompt y la elección de modelo no valdría.
 * - Las huellas con las que el gateway deduce la tarea siguen en el Swift de la app.
 * - Los criterios replican el parser de la app (lo que la app rechaza es fallo) y cuentan bien.
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { FINGERPRINTS } from "../src/ai/resolve";
import { dateContext, intentSystemPrompt, photoSystemPrompt, suggestionsSystemPrompt } from "../bench/lib/appRequests";
import { gradeIntent, gradePhoto, gradeSuggestions, parseVision, type PhotoCase } from "../bench/lib/grading";
import { detectLang } from "../bench/lib/lang";
import { interpolate, swiftMultilineAfter } from "../bench/lib/swift";

const swift = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), "utf8");

describe("extractor de literales Swift", () => {
  it("aplica la regla de sangría del cierre y deja las interpolaciones", () => {
    const src = 'func f() -> String {\n        return """\n        Hola \\(name)\n          sangrado\n        "fin"\n        """\n    }\n';
    expect(swiftMultilineAfter(src, "func f")).toBe('Hola \\(name)\n  sangrado\n"fin"');
    expect(interpolate("Hola \\(name)", { name: "Ana" })).toBe("Hola Ana");
    expect(() => interpolate("Hola \\(otro)", {})).toThrow(/sin valor/);
  });

  it("elige el literal n-ésimo tras el marcador (los dos ejemplos de las sugerencias y el prompt)", () => {
    const es = suggestionsSystemPrompt("es-PE");
    const en = suggestionsSystemPrompt("de-DE");
    expect(es).toContain("¿Por qué gasté más en Restaurantes este mes?");
    expect(en).toContain("Why did I spend more on Restaurants this month?");
    expect(en).toContain("WRITE EVERY suggestion in the user's language: de-DE.");
    expect(en).not.toContain('"""');
  });
});

describe("prompts del banco = prompts de la app", () => {
  it("clasificador: el literal entero está en el Swift", () => {
    const p = intentSystemPrompt();
    expect(p.startsWith(FINGERPRINTS["chat.intent"])).toBe(true);
    for (const line of p.split("\n").filter((l) => l.trim())) expect(swift("Yala/Services/Chat/ChatIntentClassifierService.swift")).toContain(line.trim());
  });

  it("foto: empieza por su huella y lleva el contexto de fechas sin interpolaciones sueltas", () => {
    const p = photoSystemPrompt("2026-10-07");
    expect(p.startsWith(FINGERPRINTS["photo.read"])).toBe(true);
    expect(p).toContain("Hoy es Wednesday (miércoles), 2026-10-07");
    expect(p).toContain('"ayer", "yesterday" → 2026-10-06');
    expect(p).not.toMatch(/\\\(/);
  });

  it("contexto de fechas: el lunes pasado y la semana pasada, como DateContextProvider", () => {
    const c = dateContext("2026-10-07");
    expect(c).toContain('- "el lunes" / "Monday" → 2026-10-05');
    expect(c).toContain('- "el miércoles" / "Wednesday" → 2026-09-30');
    expect(c).toContain("rango 2026-09-28 a 2026-10-04");
    expect(c).toContain("usar año 2025");
  });

  it("las huellas del gateway siguen en el Swift de la app", () => {
    const files: Record<keyof typeof FINGERPRINTS, string> = {
      "photo.read": "Yala/App/Services/ImageVision/ImageVisionService.swift",
      "chat.intent": "Yala/Services/Chat/ChatIntentClassifierService.swift",
      "chat.suggestions": "Yala/App/Services/ChatSuggestionsLLMService.swift",
      "chat.rewrite": "Yala/App/Services/SuggestionsRewriterService.swift",
      "insights.cards": "Yala/Services/InsightsLLMService.swift",
      "insights.contextual": "Yala/Services/InsightsLLMService.swift",
      "insights.cashflow": "Yala/Services/InsightsLLMService.swift",
      "insights.deviation": "Yala/Services/InsightsLLMService.swift",
      "trends.summary": "Yala/Services/TrendsAIService.swift",
    };
    for (const [task, file] of Object.entries(files)) expect(swift(file), task).toContain(FINGERPRINTS[task as keyof typeof FINGERPRINTS]);
  });
});

describe("detector de idioma", () => {
  const cases: [string, string][] = [
    ["¿Cuánto gasté en Restaurantes este mes?", "es"],
    ["How much is left in my Groceries budget?", "en"],
    ["Quanto gastei no iFood este mês?", "pt"],
    ["Combien ai-je dépensé en courses ce mois-ci ?", "fr"],
    ["Wie viel habe ich diesen Monat bei Rewe ausgegeben?", "de"],
    ["Quanto ho speso al supermercato questo mese?", "it"],
    ["Hoeveel heb ik deze maand aan boodschappen uitgegeven?", "nl"],
    ["Ile wydałem na paliwo w tym miesiącu?", "pl"],
    ["今月の外食はいくら？", "ja"],
    ["这个月外卖花了多少？", "zh"],
  ];
  for (const [text, lang] of cases) it(`${lang}: ${text}`, () => expect(detectLang(text)).toBe(lang));

  it("los nombres de datos no cuentan: una frase inglesa con nombres japoneses es inglesa", () => {
    expect(detectLang("How much did I spend on 外食 this month?", ["外食"])).toBe("en");
  });
});

describe("criterios", () => {
  it("clasificador: aplica el umbral de 0.7 de la app", () => {
    const c = { id: "x", locale: "es", text: "", expect: "register" as const };
    expect(gradeIntent('{"intent":"register","confidence":0.9}', c).pass).toBe(true);
    expect(gradeIntent('{"intent":"register","confidence":0.6}', c).pass).toBe(false); // la app lo pasa a ambiguous
    expect(gradeIntent("no json", c).appParsed).toBe(false);
  });

  it("sugerencias: textos de más de 80 caracteres no cuentan, como en la app", () => {
    const ctx = { language: "es-PE", topCategories: ["Comida"], subcategoryNames: [], merchantNames: [], activeBudgets: [], tagNames: [], recurringPaidNames: [], totalIncome: 0, totalExpense: 0 };
    const ok = Array.from({ length: 10 }, (_, i) => ({ text: `¿Cuánto gasté en Comida el día ${i}?`, icon: "cart" }));
    expect(gradeSuggestions(JSON.stringify({ suggestions: ok }), { id: "x", context: ctx }).pass).toBe(true);
    const long = ok.map((s) => ({ ...s, text: `${s.text} ${"x".repeat(80)}` }));
    expect(gradeSuggestions(JSON.stringify({ suggestions: long }), { id: "x", context: ctx }).appParsed).toBe(false);
  });

  it("foto: la decodificación estricta de la app rechaza un tipo incorrecto", () => {
    const base = { imageType: "single", confidence: { overall: 1, imageType: 1 } };
    expect(parseVision(JSON.stringify({ ...base, transactions: [{ amount: -1, date: null, merchant: null, note: null, currency: null }] }))).not.toBeNull();
    expect(parseVision(JSON.stringify({ ...base, transactions: [{ amount: "-1" }] }))).toBeNull();
    expect(parseVision(JSON.stringify({ imageType: "single", transactions: [] }))).toBeNull();
  });

  it("foto: exige importe con signo, fecha y divisa de cada movimiento, y ninguno de más", () => {
    const c: PhotoCase = {
      id: "x", file: "", today: "2026-10-07", kind: "", lang: "es", source: "",
      expect: { imageType: "list", transactions: [{ amount: -10, date: "2026-10-01", currency: "PEN" }, { amount: 5, date: "2026-10-02", currency: "PEN" }] },
    };
    const conf = { overall: 1, imageType: 1 };
    const t = (amount: number, date: string, currency = "PEN") => ({ amount, date, merchant: null, note: null, currency });
    const g = (txs: unknown[]) => gradePhoto(JSON.stringify({ imageType: "list", transactions: txs, confidence: conf }), c);
    expect(g([t(-10, "2026-10-01"), t(5, "2026-10-02")]).pass).toBe(true);
    expect(g([t(10, "2026-10-01"), t(5, "2026-10-02")]).pass).toBe(false); // signo
    expect(g([t(-10, "2026-10-01"), t(5, "2026-10-03")]).pass).toBe(false); // fecha
    expect(g([t(-10, "2026-10-01"), t(5, "2026-10-02", "USD")]).pass).toBe(false); // divisa
    expect(g([t(-10, "2026-10-01"), t(5, "2026-10-02"), t(-1, "2026-10-02")]).pass).toBe(false); // de más
    expect(g([t(-10, "2026-10-01"), t(5, "2026-10-02"), { ...t(0, "2026-10-02"), amount: null }]).pass).toBe(true); // sin importe: no cuenta
  });
});
