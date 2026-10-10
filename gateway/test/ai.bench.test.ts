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

  it("foto (sesión 2): la regla del «$» y las divisas del usuario, como VisionCurrencyContext", () => {
    const mx = photoSystemPrompt("2026-10-07", { main: "MXN", accounts: ["MXN", "USD"] });
    expect(mx).toContain('- "$" symbol alone → "MXN" (the user\'s main currency is written with $)');
    expect(mx).toContain("The user's main currency is MXN and their accounts use MXN, USD.");
    const pe = photoSystemPrompt("2026-10-07", { main: "PEN", accounts: ["PEN", "USD"] });
    expect(pe).toContain('- "$" symbol alone → null (a "$" alone does not say which dollar it is)');
    expect(photoSystemPrompt("2026-10-07")).not.toContain("The user's main currency");
    // El bloque de divisas, línea a línea, está en el Swift tal cual (salvo las dos que rellena la app).
    const src = swift("Yala/App/Services/ImageVision/ImageVisionService.swift");
    const lines = pe.split("\n");
    const start = lines.findIndex((l) => l.startsWith("Currency extraction rules"));
    expect(start).toBeGreaterThan(0);
    const block = lines.slice(start, lines.indexOf("", start));
    expect(block.length).toBeGreaterThan(15);
    for (const line of block.filter((l) => !l.includes("symbol alone") && !l.includes("user's main"))) expect(src, line).toContain(line.trim());
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

  it("foto: una página de extracto sin movimientos acierta vacía, y un saldo leído como movimiento la hace fallar", () => {
    const empty: PhotoCase = { id: "stmt-x", file: "", today: "2026-10-08", kind: "", lang: "es", source: "", expect: { imageType: "unknown", transactions: [] } };
    const conf = { overall: 1, imageType: 1 };
    const g = (txs: unknown[]) => gradePhoto(JSON.stringify({ imageType: "list", transactions: txs, confidence: conf }), empty);
    expect(g([]).pass).toBe(true);
    expect(g([{ amount: 3250.4, date: "2026-09-01", merchant: "SALDO ANTERIOR", note: null, currency: "PEN" }]).pass).toBe(false);
  });

  it("los casos multipágina (`stmt-*`) existen, tienen su imagen y una página sin movimientos al menos", () => {
    const cases = (JSON.parse(readFileSync(new URL("../bench/cases/photo.read.json", import.meta.url), "utf8")) as { cases: PhotoCase[] }).cases
      .filter((c) => c.id.startsWith("stmt-"));
    expect(cases.length).toBeGreaterThanOrEqual(12);
    for (const c of cases) expect(() => readFileSync(new URL(`../bench/cases/photo/${c.file}`, import.meta.url))).not.toThrow();
    expect(cases.some((c) => c.expect.transactions.length === 0)).toBe(true);
    expect(Math.max(...cases.map((c) => c.expect.transactions.length))).toBeGreaterThanOrEqual(40);
  });
});

// ---------- sesión 2 · chat y nota (trabajador A): text.parse, chat.answer, chat.rewrite ----------

import { categoryName, currencySymbol, seedSubcategoryNames, subcategoryName } from "../bench/lib/appCatalog";
import { chatDynamicPrompt, chatRegister, chatStaticPrompt, extractNumbers, fidelity, gradeChatAnswer, matchesValue, personaContext, triggersAnomalies } from "../bench/lib/chatAnswer";
import { toAppJSON } from "../bench/lib/chatContext";
import { commonWordSet, gradeRewrite, isPolishInflection, isValidSuggestion, parseRewritten, rewriteBody, type RewriteCase } from "../bench/lib/chatRewrite";
import { exampleHint, gradeTextParse, matchSubcategory, parserCurrencyValues, parseNoteResponse, resolveFamily, sharedNameFamilies, textParseBody, type TextParseCase } from "../bench/lib/textParse";
import { TEXT_PARSE_SCHEMA } from "../src/ai/schemas";
import { PERSONAS } from "../bench/tasks/chat.answer";

const caseFile = <T>(name: string): { cases: T[] } => JSON.parse(readFileSync(new URL(`../bench/cases/${name}`, import.meta.url), "utf8"));
const swiftLines = (file: string) => new Set(swift(file).replace(/\\"/g, '"').split("\n").map((l) => l.trim()).filter(Boolean));

describe("text.parse: el cuerpo de TranscriptionParserService", () => {
  const c = caseFile<TextParseCase>("text.parse.json").cases[0];
  const body = textParseBody(c) as { messages: { role: string; content: string }[]; temperature: number; model: string; response_format?: unknown };
  const prompt = body.messages[0].content;

  it("el prompt sale del Swift: toda línea fija está allí, sin interpolaciones sueltas", () => {
    const src = swiftLines("Yala/Services/TranscriptionParserService.swift");
    expect(prompt.startsWith("Eres un parser de gastos para una app de finanzas personales.")).toBe(true);
    expect(prompt).not.toMatch(/\\\(/);
    const fromDateContext = new Set(dateContext("2026-10-07").split("\n").map((l) => l.trim()));
    const cur = parserCurrencyValues(c.defaultCurrency, c.accountCurrencies ?? [c.defaultCurrency]);
    const fromCurrency = new Set([cur.userCurrencyLine, ...cur.sharedNameRules.split("\n")].map((l) => l.trim().replace(/^- /, "")));
    for (const line of prompt.split("\n").map((l) => l.trim()).filter(Boolean)) {
      if (fromDateContext.has(line) || fromCurrency.has(line.replace(/^- /, "")) || line.startsWith("Output:") || line.split(", ").length > 8) continue;
      expect(src.has(line) || src.has(line.replace("2026-10-07", "\\(today)")), line).toBe(true);
    }
    expect(body.temperature).toBe(0.1);
    expect(body.model).toBe("gpt-4.1-mini");
    expect(body.response_format).toEqual({ type: "json_schema", json_schema: { name: "text_parse", schema: TEXT_PARSE_SCHEMA.schema, strict: true } });
  });

  it("divisas como ParserCurrencyContext: la principal manda, luego la única cuenta de la familia, luego el defecto", () => {
    const fams = sharedNameFamilies();
    const [peso, dollar, franc] = fams;
    expect(peso.names).toContain('"pesos"');
    expect(resolveFamily({ main: "ARS", accounts: ["ARS", "USD"] }, peso)).toBe("ARS");
    expect(resolveFamily({ main: "USD", accounts: ["USD", "ARS"] }, peso)).toBe("ARS");
    expect(resolveFamily({ main: "PEN", accounts: ["PEN"] }, peso)).toBeNull();
    expect(resolveFamily({ main: "CAD", accounts: [] }, dollar)).toBe("CAD");
    expect(resolveFamily({ main: "EUR", accounts: ["EUR"] }, franc)).toBe("CHF");
    const ar = textParseBody({ ...c, defaultCurrency: "ARS", accountCurrencies: ["ARS", "USD"] }) as { messages: { content: string }[] };
    expect(ar.messages[0].content).toContain(`${peso.names} a secas → "ARS"`);
    expect(ar.messages[0].content).toContain("La divisa principal del usuario es ARS y sus cuentas usan ARS, USD.");
  });

  it("los ejemplos solo enseñan subcategorías de la lista (palabras clave leídas del Swift)", () => {
    expect(exampleHint(["Alquiler"], ["restaur"])).toBe("null");
    expect(exampleHint(["Supermärkte & Lebensmittel"], ["supermark"])).toBe('"Supermärkte & Lebensmittel"');
    const subs = new Set(seedSubcategoryNames("es-419").expense);
    for (const m of prompt.matchAll(/"subcategoryHint":("[^"]*"|null)/g)) {
      if (m[1] !== "null") expect(subs.has(JSON.parse(m[1])), m[1]).toBe(true);
    }
    expect(prompt).not.toContain('"date":null');
  });

  it("los ejemplos llevan la fecha de hoy y las listas son las subcategorías sembradas en el idioma del usuario", () => {
    expect(prompt).toContain('"date":"2026-10-07"');
    const es = seedSubcategoryNames("es-419");
    expect(prompt).toContain(es.expense.join(", "));
    expect(prompt).toContain(es.income.join(", "));
    expect(subcategoryName("de", "supermarkets")).toBe("Supermärkte & Lebensmittel");
    expect(categoryName("ja", "food")).toBe("食事");
  });

  it("parser de la app: quita las vallas, exige note/isExpense/confidence y tumba la respuesta por un tipo malo", () => {
    const tx = { amount: 12, date: "2026-10-06", note: "taxi", isExpense: true, subcategoryHint: "Taxis y apps", tagHints: [], currencyHint: null, confidence: { amount: 1, date: 1, merchant: 1, subcategory: 1, tags: 0 } };
    expect(parseNoteResponse("```json\n" + JSON.stringify({ transactions: [tx] }) + "\n```")).toHaveLength(1);
    expect(parseNoteResponse(JSON.stringify({ transactions: [{ ...tx, note: null }] }))).toBeNull();
    expect(parseNoteResponse(JSON.stringify({ transactions: [{ ...tx, amount: "12" }] }))).toBeNull();
    expect(parseNoteResponse(JSON.stringify({ transactions: [{ ...tx, confidence: { amount: 1 } }] }))).toBeNull();
    expect(parseNoteResponse("Aquí tienes: {}")).toBeNull();
  });

  it("subcategoría como DraftBuilder: exacta, parcial y ambigua = ninguna", () => {
    const list = ["Restaurantes", "Taxis y apps", "Otros", "Otros", "Supermercados y bodegas"];
    expect(matchSubcategory("restaurantes", list)).toBe("Restaurantes");
    expect(matchSubcategory("Taxis", list)).toBe("Taxis y apps");
    expect(matchSubcategory("Otros", list)).toBeNull();
    expect(matchSubcategory("Supermercados y bodegas (Wong)", list)).toBe("Supermercados y bodegas");
  });

  it("criterio: fecha y divisa por defecto como la app, signo, subcategoría y ningún movimiento de más", () => {
    const tx = (o: Record<string, unknown>) => ({ amount: 45.5, date: null, note: "Wong", isExpense: true, subcategoryHint: "Supermercados y bodegas", tagHints: [], currencyHint: null, confidence: { amount: 1, date: 1, merchant: 1, subcategory: 1, tags: 0 }, ...o });
    const k: TextParseCase = { id: "x", locale: "es-PE", today: "2026-10-07", defaultCurrency: "PEN", text: "", expect: [{ amount: 45.5, isExpense: true, date: "2026-10-07", currency: "PEN", sub: ["supermarkets"], merchant: "Wong" }] };
    const g = (txs: unknown[]) => gradeTextParse(JSON.stringify({ transactions: txs }), k);
    expect(g([tx({})]).pass).toBe(true); // sin fecha = hoy; sin divisa = la principal
    expect(g([tx({ date: "2026-10-07T10:00:00" })]).pass).toBe(true); // la app no la lee: hoy
    expect(g([tx({ currencyHint: "S/" })]).pass).toBe(false);
    expect(g([tx({ isExpense: false })]).pass).toBe(false);
    expect(g([tx({ amount: -45.5 })]).pass).toBe(false); // el chat descarta importes ≤ 0
    expect(g([tx({ subcategoryHint: "Comida" })]).pass).toBe(false);
    expect(g([tx({}), tx({ amount: 3 })]).pass).toBe(false);
  });
});

describe("chat.answer: el cuerpo de ChatAssistantService.runAskFlow", () => {
  const pe = PERSONAS.get("pe")!;

  it("parte estática del Swift, con idioma, divisa y registro de la app", () => {
    const p = chatStaticPrompt("es-PE", "S/");
    const src = swiftLines("Yala/Services/ChatAssistantService.swift");
    expect(p.startsWith("Eres el asistente financiero de Yala.")).toBe(true);
    expect(p).toContain("3. Responde en el idioma del usuario: es-PE.");
    expect(p).toContain("**S/45.50**");
    expect(p).not.toMatch(/\\\(|16\. Tono|17\. Enfoque/);
    for (const line of p.split("\n").map((l) => l.trim()).filter((l) => l && !/S\/|es-PE|tuteo/.test(l))) expect(src.has(line), line).toBe(true);
    expect(chatRegister("es-PE")).toBe("tuteo (tú)");
    expect(chatRegister("es-ES")).toBe("informal you"); // `SupportedLocale.from` da «es-ES» y el switch solo mira «es»
    expect(chatRegister("de-DE")).toBe("du");
    expect(chatRegister("pt-BR")).toBe("informal you");
  });

  it("parte dinámica: el JSON como lo escribe JSONEncoder (claves ordenadas, nil fuera, barra escapada) y las fechas", () => {
    const b = personaContext(pe);
    const d = chatDynamicPrompt(b.json, pe.today);
    expect(d.startsWith("DATOS DEL USUARIO (JSON):\n{")).toBe(true);
    expect(d).toContain('"currency_display":"S\\/"');
    expect(d).toContain("CONTEXTO DE FECHA:\nReglas de fecha:");
    expect(toAppJSON({ b: 1, a: { d: undefined, c: "x/y" } })).toBe('{"a":{"c":"x\\/y"},"b":1}');
    expect(currencySymbol("PLN")).toBe("zł");
  });

  it("el contexto es coherente: categorías, presupuestos y recurrentes cuadran con el gasto del mes", () => {
    for (const p of PERSONAS.values()) {
      const ctx = personaContext(p).context;
      const cats = ctx.categories.reduce((a: number, c: { total_current_month: number }) => a + c.total_current_month, 0);
      expect(cats, p.id).toBeCloseTo(ctx.periods.current_month.expense, 6);
      expect(ctx.patterns.needs_breakdown_current_month.total, p.id).toBeCloseTo(ctx.periods.current_month.expense, 6);
      for (const c of ctx.categories) {
        const subs = c.subcategories.reduce((a: number, s: { total_last_month: number }) => a + s.total_last_month, 0);
        expect(subs, `${p.id} ${c.name}`).toBeCloseTo(c.total_last_month, 6);
        const subsToDate = c.subcategories.reduce((a: number, s: { total_last_month_to_date: number }) => a + s.total_last_month_to_date, 0);
        expect(subsToDate, `${p.id} ${c.name} to_date`).toBeCloseTo(c.total_last_month_to_date, 6);
        expect(c.total_last_month_to_date, `${p.id} ${c.name} to_date ≤ entero`).toBeLessThanOrEqual(c.total_last_month + 1e-9);
      }
      // El mes pasado hasta hoy es parte del mes pasado entero (igual solo si hoy no existe en el mes pasado).
      expect(ctx.periods.last_month_to_date.expense, p.id).toBeLessThanOrEqual(ctx.periods.last_month.expense + 1e-9);
      expect(ctx.metadata.date_today).toBe(p.today);
      expect(ctx.anomalies).toBeUndefined();
    }
  });

  it("ninguna pregunta activa las anomalías (la app las añadiría y el banco no las replica)", () => {
    for (const c of caseFile<{ id: string; question: string }>("chat.answer.json").cases) expect(triggersAnomalies(c.question), c.id).toBe(false);
    expect(triggersAnomalies("¿Hay algún gasto raro este mes?")).toBe(true);
  });

  it("lee las cifras en cualquier convención y sabe que «1.234» puede ser las dos cosas", () => {
    const vals = (s: string) => extractNumbers(s).map((t) => t.readings.map((r) => r.values.join("+")).join("|"));
    expect(vals("**S/ 1,234.56**")).toEqual(["1234.56"]);
    expect(vals("1.234,56 €")).toEqual(["1234.56"]);
    expect(vals("2 350 €")).toEqual(["2+350|2350"]);
    expect(vals("28万円")).toEqual(["280000"]);
    expect(vals("450 mil pesos")).toEqual(["450000"]);
    expect(vals("S/1.234")).toEqual(["1234|1.234"]);
    expect(matchesValue(1235, 0, 1234.56)).toBe(true);
    expect(matchesValue(1200, 0, 1234.56)).toBe(true); // «unos 1200»
    expect(matchesValue(1250, 0, 1234.56)).toBe(false);
    expect(matchesValue(45.34, 2, 45.3333)).toBe(true);
  });

  it("fidelidad: una cifra que no sale del contexto ni de una operación documentada es inventada", () => {
    expect(fidelity("Gastaste **S/ 1,092.95**, un **68%** más que tu límite de S/650.", [1092.95, 650, 168.1538, 68.1538]).ok).toBe(true);
    const bad = fidelity("Gastaste **S/ 1,180.40** en Comida fuera.", [1092.95, 650]);
    expect(bad.ok).toBe(false);
    expect(bad.unexplained).toEqual(["1,180.40"]);
  });

  it("criterio: cifra esperada, idioma y fidelidad; y lo vacío es fallo de la app", () => {
    const c = { id: "x", persona: "pe", kind: "data" as const, question: "¿Cuánto tengo en total?", expect: { numbers: ["balances.total_balance"] } };
    const total = personaContext(pe).context.balances.total_balance as number;
    expect(gradeChatAnswer(`Tienes **S/ ${total.toFixed(2)}** en total sumando tus cuentas.`, c, pe).pass).toBe(true);
    expect(gradeChatAnswer(`You have **S/ ${total.toFixed(2)}** in total across your accounts.`, c, pe).pass).toBe(false);
    expect(gradeChatAnswer("Tienes **S/ 99,999.00** en total.", c, pe).pass).toBe(false);
    expect(gradeChatAnswer("  ", c, pe).appParsed).toBe(false);
  });
});

describe("chat.rewrite: el cuerpo de SuggestionsRewriterService.rewrite", () => {
  const cases = caseFile<RewriteCase>("chat.rewrite.json").cases;

  it("prompts del Swift: sistema con el idioma, usuario con la lista de nombres y las frases numeradas", () => {
    const body = rewriteBody(cases[0]) as { messages: { content: string }[]; response_format: unknown; temperature: number };
    expect(body.messages[0].content.startsWith(FINGERPRINTS["chat.rewrite"])).toBe(true);
    expect(body.messages[0].content).toContain("RESPOND ONLY IN es-PE.");
    expect(body.messages[1].content).toContain("Categorías: Comida, Transporte, Hogar, Entretenimiento\nSubcategorías: Mercado");
    expect(body.messages[1].content).toContain('1. "¿Cuánto gasté en Cafeterías este mes?"\n2. "¿Cuánto llevo gastado en Ropa?"');
    expect(body.messages[1].content).not.toMatch(/\\\(/);
    expect(body.response_format).toEqual({ type: "json_object" });
    expect(body.temperature).toBe(0.3);
  });

  it("las inválidas de cada caso son exactamente las que el isValid de la app manda a reescribir", () => {
    for (const c of cases) expect(c.suggestions.filter((s) => !isValidSuggestion(s, c.whitelist, c.language)), c.id).toEqual(c.invalid);
  });

  it("parseRewritten y el criterio", () => {
    expect(parseRewritten('{"suggestions":["a",2]}')).toBeNull();
    expect(parseRewritten('{"suggestions":[]}')).toBeNull();
    const c = cases[0];
    const good = ["¿Cuánto gasté en Restaurantes este mes?", "¿Cuánto llevo gastado en Mercado?", "¿Gasté más en Plaza Vea o en Tambo la semana pasada?"];
    expect(gradeRewrite(JSON.stringify({ suggestions: good }), c).pass).toBe(true);
    expect(gradeRewrite(JSON.stringify({ suggestions: [...good.slice(0, 2), "¿Gasté más en Wong o en Tambo?"] }), c).pass).toBe(false);
    expect(gradeRewrite(JSON.stringify({ suggestions: good.slice(0, 2) }), c).pass).toBe(false);
    expect(gradeRewrite(JSON.stringify({ suggestions: [...good.slice(0, 2), "How much did I spend at Tambo last week?"] }), c).pass).toBe(false);
  });
});

describe("chat.rewrite: el isValid replicado en alemán, polaco e inglés (ticket suggestions-rewriter-drops-german-and-polish-rewrites)", () => {
  const empty = { categories: [], subcategories: [], budgets: [], tags: [], merchants: [] };
  const de = { ...empty, categories: ["Lebensmittel", "Freizeit"], subcategories: ["Restaurant", "Tanken", "Supermarkt"], merchants: ["Rewe", "Lidl"] };
  const pl = { ...empty, categories: ["Jedzenie", "Rozrywka"], subcategories: ["Restauracje", "Kino", "Apteka"], merchants: ["Biedronka", "Żabka", "Lidl"] };
  const en = { ...empty, categories: ["Food"], subcategories: ["Gas"], merchants: ["Costco"] };
  const es = { ...empty, categories: ["Comida"], subcategories: ["Restaurantes"], merchants: ["Tambo"] };

  it("frases correctas pasan: sustantivos alemanes, meses, días, «I» y nombres declinados", () => {
    for (const t of [
      "Wie viel habe ich diesen Monat bei Rewe ausgegeben?",
      "Wie hoch waren meine Ausgaben für Lebensmittel im Oktober?",
      "Wie viel ist noch im Budget für Freizeit übrig?",
      "Habe ich am Samstag mehr für Restaurants ausgegeben als im Vergleich zum Vormonat?",
      "An welchen Wochentagen gebe ich mehr für Supermärkte aus?",
    ]) expect(isValidSuggestion(t, de, "de-DE"), t).toBe(true);
    for (const t of [
      "Ile wydałem w Biedronce w tym miesiącu?",
      "Ile wydałem w Żabce w tym tygodniu?",
      "Ile wydałem w Aptece?",
      "Ile wydałem na Rozrywkę?",
      "Ile wydałem w Restauracjach w tym miesiącu?",
      "Ile wydałem w Lidlu?",
      "Ile zostało Ci w budżecie Jedzenie?",
      "Jak wydatki na Rozrywkę wypadają względem Twojego budżetu?",
    ]) expect(isValidSuggestion(t, pl, "pl-PL"), t).toBe(true);
    for (const t of ["How much did I spend at Costco in October?", "Did I spend more on Gas on Saturday than on Sunday?"]) {
      expect(isValidSuggestion(t, en, "en-US"), t).toBe(true);
    }
  });

  it("un comercio o una categoría inventada sigue sin pasar, en los cuatro idiomas", () => {
    expect(isValidSuggestion("Wie viel habe ich bei Aldi ausgegeben?", de, "de-DE")).toBe(false);
    expect(isValidSuggestion("Wie hoch waren meine Kosten für Strom?", de, "de")).toBe(false);
    expect(isValidSuggestion("Wie viel zahle ich im Monat für Spotify?", de, "de-DE")).toBe(false);
    expect(isValidSuggestion("Ile wydałem w Rossmannie?", pl, "pl-PL")).toBe(false);
    expect(isValidSuggestion("Ile wydałem na Ubrania?", pl, "pl-PL")).toBe(false);
    expect(isValidSuggestion("How much did I spend at Walmart in October?", en, "en-US")).toBe(false);
    expect(isValidSuggestion("How much did I spend on Insurance?", en, "en-US")).toBe(false);
    expect(isValidSuggestion("¿Cuánto gasté en Wong en octubre?", es, "es-PE")).toBe(false);
    expect(isValidSuggestion("¿Cuánto gasté en Comisiones este mes?", es, "es-PE")).toBe(false);
  });

  it("las listas son del idioma: el alemán no abre el español ni la declinación polaca abre otro idioma", () => {
    expect(isValidSuggestion("¿Cuánto gasté este Monat?", es, "es-PE")).toBe(false);
    expect(isValidSuggestion("Wie viel habe ich in Biedronce ausgegeben?", { ...empty, merchants: ["Biedronka"] }, "de-DE")).toBe(false);
    expect(commonWordSet("de_DE").has("monat")).toBe(true);
    expect(commonWordSet("en-GB").has("i")).toBe(true);
    expect(commonWordSet("es").has("cuánto")).toBe(true);
    expect(commonWordSet("es").has("monat")).toBe(false);
  });

  it("la declinación polaca: raíz con alternancia k→c, sin abrir palabras que solo comparten el principio", () => {
    expect(isPolishInflection("biedronce", "biedronka")).toBe(true);
    expect(isPolishInflection("żabce", "żabka")).toBe(true);
    expect(isPolishInflection("kinie", "kino")).toBe(true);
    expect(isPolishInflection("restauracjach", "restauracje")).toBe(true);
    expect(isPolishInflection("biedronkowski", "biedronka")).toBe(false);
    expect(isPolishInflection("rossmannie", "lidl")).toBe(false);
    expect(isPolishInflection("domu", "dom")).toBe(false);
  });
});

describe("chat.rewrite: nombres declinados e idioma de frases cortas", () => {
  it("«w Biedronce» usa «Biedronka»; «Rozrywkę», «Rozrywka»; un nombre parecido no vale", async () => {
    const { usesName } = await import("../bench/lib/chatRewrite");
    expect(usesName("Ile wydałem w Biedronce w tym miesiącu?", "Biedronka")).toBe(true);
    expect(usesName("Ile wydałem na Rozrywkę?", "Rozrywka")).toBe(true);
    expect(usesName("Ile wydałem na Zakupy spożywcze?", "Zakupy spożywcze")).toBe(true);
    expect(usesName("Ile wydałem w Biedronce?", "Lidl")).toBe(false);
    expect(usesName("¿Cuánto gasté en Restaurantes?", "Restauración")).toBe(false);
  });

  it("una pregunta portuguesa corta no empata con el italiano", async () => {
    const { detectLangWithFallback } = await import("../bench/lib/chatAnswer");
    expect(detectLangWithFallback("Quanto paguei de ?")).toBe("pt");
  });
});

describe("chat.answer: idioma de respuestas largas", () => {
  it("una respuesta portuguesa no sale española por «que», «o» y «gasto»", async () => {
    const { answerLanguage } = await import("../bench/lib/chatAnswer");
    const pt = "No mês passado, o teu saldo foi de **-€230.09**, o que significa que não houve poupança, mas sim um saldo negativo. A tua taxa de poupança foi de **-15.34%**.";
    expect(answerLanguage(pt, [])).toBe("pt");
    expect(answerLanguage("Solo puedo ayudarte con tus finanzas personales — gastos, ingresos, presupuestos, patrones, etc. ¿Algo de eso?", [])).toBe("es");
    expect(answerLanguage("You've spent **$2,597.05** so far in October, versus **$3,019.03** for all of September.", [])).toBe("en");
    // Medidos el 2026-10-07: seis «de» la hacían neerlandesa y tres «a», inglesa.
    expect(answerLanguage("Nos próximos dias, tens o pagamento de **Renda** de **€750**, previsto para **8 de outubro**. Depois, está previsto o pagamento de **MEO** de **€45,99** em **20 de outubro**.", ["Renda", "MEO"])).toBe("pt");
    expect(answerLanguage("Nos próximos 30 dias tens **3 pagamentos recorrentes pendentes**, que somam **€809.98**:\n\n- **Renda**: **€750** a 8 de outubro\n- **MEO**: **€45.99** a 20 de outubro", ["Renda", "MEO"])).toBe("pt");
  });
});
