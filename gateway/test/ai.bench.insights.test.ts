/**
 * El banco de Insights y Tendencias (sesión 2, trabajador B) sin red:
 * - los prompts salen del Swift y son los de verdad (con su tono, enfoque y filtros interpolados);
 * - los datos agregados replican, campo a campo, los builders de la app (truncado de `Int()`, redondeo de
 *   `.rounded()`, `N/A`, barra escapada de `JSONSerialization`, `.sortedKeys` en Tendencias);
 * - los parsers replican lo que la app acepta y rechaza;
 * - el verificador de números caza la cifra inventada y deja pasar la derivada (con su control positivo).
 */
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { FINGERPRINTS } from "../src/ai/resolve";
import {
  checkNumbers,
  claimMatches,
  currencyAfterNumber,
  derivableValues,
  extractNumbers,
  gradeCards,
  gradeComment,
  gradeTrends,
  interpretations,
  languageOf,
  moneyMarkers,
  parseCards,
  parseComment,
  parseTrends,
  perturbationSensitivity,
  presentCharts,
} from "../bench/lib/insightsGrading";
import { cohenKappa, JUDGES, judgesFor, parseVerdict, renderResponse, verdictPass } from "../bench/lib/insightsJudge";
import {
  cardsBody,
  cardsPayload,
  cashFlowBody,
  cashFlowPayload,
  currencySymbol,
  baseCode,
  cashFlowSystemPrompt,
  deviationBody,
  deviationPayload,
  deviationSystemPrompt,
  informalRegister,
  languageInstruction,
  languageLabel,
  nsJSON,
  trendsBody,
  trendsPayload,
  userDataJSON,
  type CardsInput,
  type TrendsInput,
} from "../bench/lib/insightsRequests";
import { detectLongLang, promptLeak } from "../bench/lib/insightsLang";
import { INSIGHTS_SCHEMAS } from "../bench/tasks/insights.schemas";
import { TASK_REGISTRY } from "../bench/tasks";

const swift = (p: string) => readFileSync(new URL(`../../${p}`, import.meta.url), "utf8");
const INSIGHTS = "Yala/Services/InsightsLLMService.swift";
const TRENDS = "Yala/Services/TrendsAIService.swift";

const msgs = (b: Record<string, unknown>) => b.messages as { role: string; content: string }[];

const baseCards: CardsInput = {
  currency: "PEN",
  currencyDisplayFormat: "symbol",
  language: "es",
  country: "PE",
  comparisonMode: "month",
  tone: "normal",
  focus: "balanced",
  summary: { totalExpense: 4523.7, totalIncome: 6000, netBalance: 1476.3, expenseVariation: 12.7, incomeVariation: null, dailyAverageVariation: -3.2, balanceVariation: -0.4, transactionCount: 42, previousPeriodLabel: "vs Sep 26" },
  dailyAverage: 150.8,
  topCategories: [{ name: "Comida", amount: 1500.9, percentage: 33.2 }],
};

const baseTrends: TrendsInput = {
  metric: "expense",
  periodLabel: "Mes pasado",
  comparisonLabel: "Ago 26",
  currentTotal: 1100,
  previousTotal: 1000,
  history: [{ start: "1970-01-01", income: 2000, expense: 1500, net: 500 }],
  historyUnit: "months",
  cashFlow: { income: 1500, expense: 1000, net: 500 },
  weekdaySpending: [{ weekday: 7, average: 100 }],
  currency: "PEN",
  currencyDisplayFormat: "symbol",
  locale: "es",
  country: "PE",
  filtersActive: false,
  tone: "normal",
  focus: "balanced",
};

const data = cardsPayload({
  ...baseCards,
  topCategories: [
    { name: "Comida", amount: 1310, percentage: 34.09 },
    { name: "Casa", amount: 1150, percentage: 29.93 },
  ],
  budgetsAtRisk: [{ name: "Comida", spent: 1310, limit: 1400, usagePercent: 93.57 }],
  subscriptions: { count: 3, monthly: 89.9 },
});
const d = derivableValues(data);
const m = moneyMarkers("PEN", "S/", "S/");

describe("cuerpos = los de la app", () => {
  it("las cuatro tareas están registradas con su esquema y el cuerpo de hoy (gpt-4.1-mini, 0.4, json_object)", () => {
    for (const name of ["insights.cards", "insights.cashflow", "insights.deviation", "trends.summary"] as const) {
      const t = TASK_REGISTRY.find((x) => x.name === name);
      expect(t, name).toBeDefined();
      expect(t?.baseParams.jsonSchema).toBe(INSIGHTS_SCHEMAS[name]);
      expect(t?.baseParams.temperature).toBe(0.4);
    }
    const b = cardsBody(baseCards);
    expect(b).toMatchObject({ model: "gpt-4.1-mini", temperature: 0.4, response_format: { type: "json_object" }, stream: false });
  });

  it("Insights: el prompt lleva la huella del gateway, sin interpolaciones sueltas, y cada línea fija está en el Swift", () => {
    const sys = msgs(cardsBody(baseCards))[0].content;
    expect(sys).toContain(FINGERPRINTS["insights.cards"]);
    expect(sys).not.toMatch(/\\\(/);
    expect(sys).toContain("SIEMPRE formatea: S/ NÚMERO (ej: S/ 4,500)");
    expect(sys).toContain('contra "periodo anterior" (vs Sep 26).');
    expect(sys).toContain("ENFOQUE — EQUILIBRADO:");
    const src = swift(INSIGHTS);
    for (const line of sys.split("\n").filter((l) => l.trim() && !/S\/|PEN|vs Sep 26|IDIOMA|Trato:|periodo anterior/.test(l))) expect(src, line).toContain(line.trim());
  });

  it("Insights, flujo y desviaciones: piden el idioma de la app con la línea y el trato del Swift", () => {
    expect(languageInstruction("de")).toBe(
      "IDIOMA: Responde SIEMPRE en alemán (de), el idioma de la app del usuario, aunque estas instrucciones estén en español. Nunca mezcles idiomas ni copies palabras de estas instrucciones: gasto, ingreso, presupuesto y plan se dicen con la palabra propia de ese idioma.",
    );
    expect(languageLabel("zh-Hans")).toBe("chino (zh-Hans)");
    expect(languageLabel("ko")).toBe("ko");
    expect(informalRegister(baseCode("es-PE"))).toBe("tuteo (tú)");
    expect(informalRegister(baseCode("pt-PT"))).toBe("você");
    expect(informalRegister(baseCode("zh-Hans"))).toBe("informal you");
    const cards = msgs(cardsBody({ ...baseCards, language: "de" }))[0].content;
    expect(cards).toContain(languageInstruction("de"));
    expect(cards).toContain("- Trato: du, como un amigo que sabe de finanzas");
    for (const sys of [cashFlowSystemPrompt("EUR", "pt-BR"), deviationSystemPrompt("EUR", "pt-BR")]) {
      expect(sys).toContain(languageInstruction("pt-BR"));
      expect(sys).toContain("- Trato: você. Lidera con el dato");
      expect(sys).not.toMatch(/\\\(/);
    }
  });

  it("Insights: tono, región y filtro de exclusión entran como en la app", () => {
    const sys = msgs(cardsBody({ ...baseCards, tone: "sarcastic", focus: "cautious", filters: { mode: "exclude", categories: ["Casa"] } }))[0].content;
    expect(sys).toContain("ESTILO — TU AMIGO CERCANO:");
    expect(sys).toContain("País del usuario: PE.");
    expect(sys).toContain("ENFOQUE — PRECAVIDO:");
    expect(sys).toContain("FILTROS ACTIVOS (EXCLUSIÓN): Excluyendo categorías: Casa\nIMPORTANTE: Los datos que recibes EXCLUYEN");
    const sinPais = msgs(cardsBody({ ...baseCards, tone: "considerate", country: "" }))[0].content;
    expect(sinPais).toContain("País del usuario: no especificado — usa español neutro.");
  });

  it("Insights: los datos son los de `buildAggregatedData` (orden del Swift, `Int()` trunca, N/A, barra escapada)", () => {
    const user = msgs(cardsBody({ ...baseCards, filters: { mode: "include", categories: ["Comida"] } }))[1].content;
    expect(user.startsWith("Datos financieros del periodo:\n{")).toBe(true);
    expect(userDataJSON(cardsBody(baseCards))).toBe(
      '{"currency":"PEN","currency_display":"S\\/","locale":"es","country":"PE","comparison_ref":"periodo anterior","comparison_label":"vs Sep 26",' +
        '"total_expense":4523,"total_income":6000,"net_balance":1476,"spending_total_variation":"12%","income_variation":"N\\/A",' +
        '"daily_avg_variation":"-3%","balance_variation":"0%","count":42,"daily_avg":150,"top_categories":[{"name":"Comida","amount":1500,"pct":33}]}',
    );
    const withYear = cardsPayload({ ...baseCards, comparisonMode: "year", yearOverYear: { current: 4523.7, previous: 5000, variation: -9.5 } });
    expect(withYear.comparison_ref).toBe("año anterior");
    expect(withYear.year_ago).toEqual({ current: 4523, previous: 5000, variation: "-9%" });
    const f = cardsPayload({ ...baseCards, filters: { mode: "include", categories: ["Comida"], transactionType: { kind: "expense", displayName: "Gastos" } } });
    expect(f.active_filters).toEqual({ mode: "include", categories: ["Comida"], transaction_type: "expense", summary: "Solo categorías: Comida. Solo gastos" });
  });

  it("flujo de caja: prompt con el símbolo de `CurrencyCode` y payload de `buildCashFlowPayload`", () => {
    const b = cashFlowBody({
      currency: "EUR",
      startingBalance: 1200.5,
      months: [
        { month: "2026-09", income: 3000, expense: 2800 },
        { month: "2026-10", income: 3000, expense: 3500, isCurrent: true },
        { month: "2026-11", income: 3000, expense: 4000 },
      ],
    }, "de-DE");
    const [sys, user] = msgs(b).map((m) => m.content);
    expect(sys).toContain(FINGERPRINTS["insights.cashflow"]);
    expect(sys).toContain("Montos en EUR: SIEMPRE € NÚMERO (ej: € 4,500)");
    expect(sys).toContain(languageInstruction("de-DE")); // desde el 2026-10-07 la app le dice el idioma
    expect(sys).not.toMatch(/\\\(/);
    expect(user).toBe(
      'Proyección de flujo de caja:\n{"startingBalance":1200.5,"monthsTotal":3,"monthsPositive":2,"monthsNegative":1,"avgMonthlyNet":-433,"currency":"EUR",' +
        '"currentMonth":{"name":"okt. 2026","income":3000,"expense":3500,"net":-500,"accumulated":900},"endMonth":{"name":"nov. 2026","accumulated":-99},' +
        '"lowestAccumulated":{"month":"nov. 2026","balance":-99}}',
    );
    expect(swift(INSIGHTS)).toContain('user: "Proyección de flujo de caja:\\n\\(jsonString)"');
    const before = cashFlowPayload({ currency: "EUR", startingBalance: 100, balanceFrom: 1, months: [{ month: "2026-09", income: 10, expense: 5 }, { month: "2026-10", income: 10, expense: 50 }] }, "it-IT");
    expect(before.lowestAccumulated).toEqual({ month: "ott 2026", balance: 60 }); // el mes sin saldo no cuenta como el más bajo
  });

  it("desviaciones: trunca cada importe y suma los excesos SIN truncar antes", () => {
    const p = deviationPayload({ currency: "PLN", deviations: [{ name: "A", planned: 400.9, actual: 612.9, excess: 212.6 }, { name: "B", planned: 10, actual: 15.5, excess: 5.5 }] });
    expect(nsJSON(p)).toBe('{"items":[{"name":"A","planned":400,"actual":612,"excess":212},{"name":"B","planned":10,"actual":15,"excess":5}],"totalExcess":218,"currency":"PLN"}');
    const sys = msgs(deviationBody({ currency: "PLN", deviations: [] }, "pl"))[0].content;
    expect(sys).toContain(FINGERPRINTS["insights.deviation"]);
    expect(sys).toContain("SIEMPRE zł NÚMERO");
    expect(currencySymbol("pen")).toBe("S/");
  });

  it("Tendencias: los mismos valores que fija TrendsAIServiceTests, claves ordenadas y redondeo lejos de cero", () => {
    const p = trendsPayload(baseTrends);
    expect(p.comparison).toEqual({ previous_label: "Ago 26", current: 1100, previous: 1000, variation_pct: 10 });
    expect(p.cash_flow).toEqual({ income: 1500, expense: 1000, net: 500, income_covers_expense_pct: 150 });
    expect(p.weekday_avg_expense).toEqual([{ day: "sábado", avg: 100 }]);
    expect(p.history_unit).toBe("months");
    const empty = trendsPayload({ ...baseTrends, comparisonLabel: null, previousTotal: null, history: [], cashFlow: null, weekdaySpending: [] });
    expect(empty).not.toHaveProperty("comparison");
    expect(empty).not.toHaveProperty("cash_flow");
    expect(empty).not.toHaveProperty("weekday_avg_expense");
    expect(empty).not.toHaveProperty("history_completed_periods");
    const half = trendsPayload({ ...baseTrends, history: [{ start: "2026-01-01", income: 2.5, expense: 0.5, net: -2.5 }] });
    expect(half.history_completed_periods).toEqual([{ start: "2026-01-01", income: 3, expense: 1, net: -3 }]);
    expect(trendsPayload({ ...baseTrends, previousTotal: 0 }).comparison).toEqual({ previous_label: "Ago 26", current: 1100, previous: 0 });
    const user = msgs(trendsBody(baseTrends))[1].content;
    expect(user.startsWith('Datos de las gráficas de Tendencias:\n{"cash_flow":{"expense":1000,"income":1500,"income_covers_expense_pct":150,"net":500},"comparison"')).toBe(true);
    expect(user).toContain('"currency_display":"S\\/"');
    const sys = msgs(trendsBody({ ...baseTrends, filtersActive: true, locale: "zh-Hans" }))[0].content;
    expect(sys).toContain(FINGERPRINTS["trends.summary"]);
    expect(sys).toContain("\nFILTROS ACTIVOS: los datos son un subconjunto filtrado");
    expect(sys).toContain("IDIOMA: Responde SIEMPRE en zh-Hans.");
    expect(sys).not.toMatch(/\\\(/);
    expect(swift(TRENDS)).toContain("Escribe UN bullet por gráfica PRESENTE en el JSON");
  });
});

describe("parsers = los de la app", () => {
  it("Insights: `hero` obligatorio; tarjetas sin `text` se saltan; un elemento que no es objeto anula todas", () => {
    expect(parseCards('{"cards":[]}')).toBeNull();
    expect(parseCards("no json")).toBeNull();
    const ok = parseCards('{"hero":"h","cards":[{"text":"a"},{"icon":"x"},{"text":"b","icon":"cart.fill","sentiment":"positive","tip":"t"}],"funFact":7}');
    expect(ok?.cards).toEqual([
      { icon: "sparkles", text: "a", sentiment: "neutral", tip: null },
      { icon: "cart.fill", text: "b", sentiment: "positive", tip: "t" },
    ]);
    expect(ok?.funFact).toBeNull();
    expect(parseCards('{"hero":"h","cards":[{"text":"a"},"b"]}')?.cards).toEqual([]);
  });

  it("comentario: `null` y un no-string son «sin comentario»; no-JSON o no-objeto, fallo", () => {
    expect(parseComment('{"comment":null}')).toEqual({ comment: null });
    expect(parseComment('{"comment":5}')).toEqual({ comment: null });
    expect(parseComment('["x"]')).toBeUndefined();
    expect(parseComment("x")).toBeUndefined();
  });

  it("Tendencias: como TrendsAIServiceTests (tope 4, textos vacíos fuera, gráfica desconocida sin icono)", () => {
    const five = parseTrends('{"bullets":[{"chart":"trend","text":"Uno"},{"chart":"comparison","text":"Dos"},{"chart":"cash_flow","text":"Tres"},{"chart":"weekday","text":"Cuatro"},{"chart":"trend","text":"Cinco"}]}');
    expect(five?.map((b) => b.text)).toEqual(["Uno", "Dos", "Tres", "Cuatro"]);
    expect(five?.map((b) => b.chart)).toEqual(["trend", "comparison", "cashflow", "weekday"]);
    const one = parseTrends('{"bullets":[{"chart":"trend","text":"  "},{"chart":"otra","text":"Vale"}]}');
    expect(one).toEqual([{ chart: null, rawChart: "otra", text: "Vale" }]);
    expect(parseTrends('{"bullets":[]}')).toBeNull();
    expect(parseTrends('{"hero":"x"}')).toBeNull();
  });
});

describe("verificador de números", () => {
  it("lee los formatos de los 14 idiomas, con multiplicadores y cantidades CJK", () => {
    expect(interpretations("4.500").map((a) => a.value)).toEqual([4500]);
    expect(interpretations("1.234,56")).toEqual([{ value: 1234.56, unit: 0.01 }]);
    expect(interpretations("4 500")).toEqual([{ value: 4500, unit: 100 }]);
    const v = (s: string) => extractNumbers(s).map((c) => c.alts[0].value);
    expect(v("4,5 mil")).toEqual([4500]);
    expect(v("约28万5000元")).toEqual([285000]);
    expect(v("4.5万円")).toEqual([45000]);
    expect(v("1,2 Mio.")).toEqual([1_200_000]);
    expect(v("月均支出约¥ 8,400，10月目前")).toEqual([8400, 10]); // la coma china es puntuación, no miles
    expect(v("unter EUR 980 könnte")).toEqual([980]); // «k» seguida de letra no es «mil»
    expect(v("4.5k € und 2 Mio.")).toEqual([4500, 2_000_000]);
    expect(extractNumbers("**12,5 %**")[0].kind).toBe("pct");
    const m = moneyMarkers("PEN", "S/", "S/");
    expect(extractNumbers("**S/ 1,310**", m)[0].kind).toBe("money");
  });

  it("acepta lo que sale de los datos (tal cual, redondeado, diferencia, suma, parte, ×12) y caza lo inventado", () => {
    const ok = [
      "Gastaste **S/ 4,523** (S/ 4.5 mil), un **12%** más.",
      "Te quedan **S/ 90** de Comida (**93%** usado).",
      "Comida y Casa suman **S/ 2,460**; Comida es el **29%** del gasto.",
      "Tus 3 suscripciones son **S/ 89** al mes, **S/ 1,068** al año.",
    ];
    for (const t of ok) expect(checkNumbers([t], d, m).unverified, t).toEqual([]);
    const invented = ["Llegarías al límite el día **24**.", "Gastaste **S/ 4,880** en total.", "Comida sube un **47%**."];
    for (const t of invented) expect(checkNumbers([t], d, m).unverified.length, t).toBe(1);
    expect(checkNumbers(["En 3 categorías"], d, m).claims).toBe(0); // conteo pequeño: exento
  });

  it("sensibilidad: un importe alterado ±7-15 % se caza salvo que caiga en otro dato real (1.310 × 1,07 = 1.400, el límite)", () => {
    const s = perturbationSensitivity(["Gastaste **S/ 4,523** y en Comida **S/ 1,310**."], d, m);
    expect(s.amount.tried).toBe(8);
    expect(s.amount.caught).toBe(6);
    expect(claimMatches(extractNumbers("S/ 4,523", m)[0], d)).toBe(true);
  });

  it("divisa detrás del número = fallo; delante, no", () => {
    expect(currencyAfterNumber(["Gastaste 4.500 € en total"], moneyMarkers("EUR", "€", "€"))).toHaveLength(1);
    expect(currencyAfterNumber(["Wydałeś 120 zł"], moneyMarkers("PLN", "zł", "zł"))).toHaveLength(1);
    expect(currencyAfterNumber(["使った金額は28,500円です"], moneyMarkers("JPY", "¥", "JPY"))).toHaveLength(1);
    expect(currencyAfterNumber(["Gastaste € 4.500 y S/ 20"], moneyMarkers("EUR", "€", "€"))).toEqual([]);
  });

  it("mezcla: el vocabulario del prompt en español dentro de otro idioma, salvo lo que también es de ese idioma", () => {
    expect(promptLeak("Dein Gasto lag zwischen EUR 2,630 und EUR 3,210.", "de")).toEqual(["gasto"]);
    expect(promptLeak("Nel periodo hai speso EUR 86.", "it")).toEqual([]);
    expect(promptLeak("Os teus gastos no período subiram.", "pt")).toEqual([]);
    expect(promptLeak("Os teus ingresos subiram.", "pt")).toEqual(["ingresos"]);
    expect(promptLeak("Tu gasto bajó.", "es")).toEqual([]);
  });

  it("detector largo: el portugués europeo no es francés, y los nombres CJK de 2 caracteres no cuentan", () => {
    expect(detectLongLang("O gasto médio foi maior ao sábado, EUR 52, e menor à terça-feira, EUR 22.")).toBe("pt");
    expect(detectLongLang("En 交際費 gastaste más de lo planeado, al igual que en 外食 y en el resto.", ["交際費", "外食"])).toBe("es");
  });

  it("idioma de textos largos, sin contar los nombres de los datos", () => {
    expect(languageOf(["Gastaste **S/ 4,523** este mes, un 12% más que el periodo anterior."], ["Comida"])).toBe("es");
    expect(languageOf(["Este mês gastaste R$ 4.523, mais 12% do que no mês anterior."], [])).toBe("pt");
    expect(languageOf(["Du hast diesen Monat 4.523 € ausgegeben, 12 % mehr als im Vormonat."], [])).toBe("de");
    expect(languageOf(["今月は**JPY 286,450**を使いました。"], [])).toBe("ja");
  });
});

describe("criterios por tarea", () => {
  const ctx = { data, locale: "es-PE", money: m };

  it("Insights: pasa con hero con cifra, 3-6 tarjetas y cifras de los datos; falla con un número inventado", () => {
    const card = (text: string) => ({ icon: "cart.fill", text, sentiment: "neutral", tip: null });
    const good = { hero: "Gastaste **S/ 4,523** este mes, un **12%** más.", cards: [card("Comida suma **S/ 1,310**."), card("Casa suma **S/ 1,150**."), card("Te quedan **S/ 90** del presupuesto de Comida.")], funFact: null };
    const g = gradeCards(JSON.stringify(good), ctx);
    expect(g.detail.failures).toEqual([]);
    expect(g.pass).toBe(true);
    const bad = { ...good, cards: [...good.cards, card("Llegarás al límite el día **24**.")] };
    expect(gradeCards(JSON.stringify(bad), ctx).detail.failures).toContain("número sin respaldo");
    expect(gradeCards(JSON.stringify({ ...good, cards: good.cards.slice(0, 2) }), ctx).pass).toBe(false);
    expect(gradeCards(JSON.stringify({ ...good, hero: "Buen mes." }), ctx).detail.failures).toContain("hero sin cifra");
  });

  it("comentario: `null` solo pasa donde el caso lo admite; largo por encima de 180 falla", () => {
    expect(gradeComment('{"comment":null}', ctx, false).pass).toBe(false);
    expect(gradeComment('{"comment":null}', ctx, true).pass).toBe(true);
    const long = `Gastaste **S/ 4,523** este mes ${"y sigue ".repeat(25)}.`;
    expect(gradeComment(JSON.stringify({ comment: long }), ctx, false).detail.failures).toEqual(expect.arrayContaining([expect.stringMatching(/^largo=/)]));
    expect(gradeComment(JSON.stringify({ comment: "Gastaste **S/ 4,523** este mes." }), ctx, false).pass).toBe(true);
  });

  it("Tendencias: una viñeta por gráfica presente, cada una con cifra", () => {
    const tdata = trendsPayload(baseTrends);
    expect(presentCharts(tdata)).toEqual(["trend", "comparison", "cashflow", "weekday"]);
    const tctx = { data: tdata, locale: "es", money: moneyMarkers("PEN", "S/", "S/") };
    const bullets = [
      { chart: "trend", text: "El mes completo anterior gastaste **S/ 1,500**." },
      { chart: "comparison", text: "Este mes llevas **S/ 1,100**, un **10%** más." },
      { chart: "cashflow", text: "Ingresaste **S/ 1,500** y gastaste **S/ 1,000**." },
      { chart: "weekday", text: "El sábado gastas **S/ 100** de media." },
    ];
    expect(gradeTrends(JSON.stringify({ bullets }), tctx).pass).toBe(true);
    expect(gradeTrends(JSON.stringify({ bullets: bullets.slice(0, 3) }), tctx).pass).toBe(false);
    expect(gradeTrends(JSON.stringify({ bullets: [...bullets.slice(0, 3), { chart: "weekday", text: "Los sábados gastas más." }] }), tctx).detail.failures).toContain("viñeta sin cifra");
  });
});

describe("juez", () => {
  it("nadie se juzga a sí mismo: los dos jueces de una respuesta son de otro proveedor", () => {
    for (const p of ["openai", "anthropic", "gemini", "xai", "workersai"]) {
      const js = judgesFor(p);
      expect(js).toHaveLength(2);
      expect(js.every((j) => j.provider !== p)).toBe(true);
      expect(new Set(js.map((j) => j.provider)).size).toBe(2);
    }
    expect(JUDGES.length).toBeGreaterThanOrEqual(3);
  });

  it("Sonnet 5.5 abre la lista y a Anthropic lo juzgan otros (2026-10-08)", () => {
    for (const p of ["openai", "gemini", "xai", "workersai"]) expect(judgesFor(p)[0].id).toBe("anthropic:claude-sonnet-5-5");
    expect(judgesFor("anthropic").map((j) => j.provider)).not.toContain("anthropic");
    // Sonnet 5.5 rechaza una temperatura distinta de la de por defecto: el juez no la manda.
    expect(JUDGES.find((j) => j.id === "anthropic:claude-sonnet-5-5")?.temperature).toBeUndefined();
  });

  it("veredicto = no contradice y es útil; JSON ilegible = sin veredicto", () => {
    const v = parseVerdict('{"contradice_datos":false,"util":true,"voz_ok":false,"motivo":"x"}');
    expect(v && verdictPass(v)).toBe(true);
    expect(parseVerdict('{"util":true}')).toBeNull();
    expect(verdictPass({ contradice: true, util: true })).toBe(false);
  });

  it("κ de Cohen: 1 con acuerdo total, 0 con acuerdo de azar", () => {
    expect(cohenKappa([true, false, true, false], [true, false, true, false])).toBe(1);
    expect(cohenKappa([true, true, false, false], [true, false, true, false])).toBe(0);
  });

  it("la respuesta se le enseña como la ve el usuario", () => {
    expect(renderResponse("insights.cashflow", { comment: null })).toMatch(/sin comentario/);
    expect(renderResponse("trends.summary", { bullets: [{ chart: "trend", text: "x" }] })).toBe("Viñetas:\n- [trend] x");
  });
});
