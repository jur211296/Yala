import { interpolate, readRepoFile, swiftMultilineAfter } from "./swift";

/**
 * Cuerpos de Chat Completions IDÉNTICOS a los que manda la app hoy para las cuatro llamadas de Insights y
 * Tendencias (sesión 2, trabajador B): `insights.cards`, `insights.cashflow`, `insights.deviation` y
 * `trends.summary`. Todas van con `gpt-4.1-mini`, temperatura 0.4, `json_object` y sin streaming.
 *
 * Los prompts se LEEN del Swift (`swiftMultilineAfter`), también los trozos que se interpolan dentro (tono,
 * enfoque, filtros) y los prefijos del mensaje de usuario. Los datos agregados replican, campo a campo, lo que
 * arma la app en Swift:
 * - `insights.cards`: `InsightsViewModel.buildAggregatedData` (+ `buildFilterContext`).
 * - `insights.cashflow`: `InsightsLLMService.buildCashFlowPayload`.
 * - `insights.deviation`: el diccionario de `InsightsLLMService.generateDeviationInsight`.
 * - `trends.summary`: `TrendsAIService.buildPayload`.
 * Lo fija `test/ai.bench.insights.test.ts`.
 *
 * Dos diferencias conocidas y aceptadas con la app, las dos de forma y no de contenido:
 * 1. `JSONSerialization` sin `.sortedKeys` (Insights, flujo, desviaciones) ordena las claves según el hash del
 *    diccionario, distinto en cada arranque. Aquí van en el orden en que el Swift las escribe.
 * 2. Los nombres de mes (flujo de caja) y de día (Tendencias) salen de `Intl` y no del ICU de iOS: mismo CLDR,
 *    pero algún separador puede variar.
 */

const PATHS = {
  insights: "Yala/Services/InsightsLLMService.swift",
  insightsVM: "Yala/App/ViewModels/InsightsViewModel.swift",
  trends: "Yala/Services/TrendsAIService.swift",
  currency: "Yala/Utils/CurrencyUtils.swift",
  language: "Yala/Services/AIPromptLanguage.swift",
} as const;

// ---------- utilidades Swift ----------

/** El código Swift desde `marker` (para buscar literales dentro de una función concreta). */
function from(source: string, marker: string): string {
  const at = source.indexOf(marker);
  if (at < 0) throw new Error(`swift: no encuentro «${marker}»`);
  return source.slice(at);
}

/** Literal de una línea (`"…"`) tras `marker`, con `\n` y `\"` resueltos. Las interpolaciones quedan como texto. */
function swiftLineLiteralAfter(source: string, marker: string): string {
  const rest = from(source, marker).slice(marker.length);
  const m = rest.match(/"((?:[^"\\]|\\.)*)"/);
  if (!m) throw new Error(`swift: no hay literal tras «${marker}»`);
  return m[1].replace(/\\n/g, "\n").replace(/\\"/g, '"').replace(/\\\\/g, "\\");
}

let symbolCache: Record<string, string> | null = null;

/** `CurrencyCode(rawValue:)?.symbol`, leído de `CurrencyUtils.swift`. */
export function currencySymbol(code: string): string | undefined {
  if (!symbolCache) {
    const src = readRepoFile(PATHS.currency);
    const block = from(src, "var symbol: String {");
    const end = block.indexOf("var localizedName");
    const raw: Record<string, string> = {};
    for (const m of block.slice(0, end).matchAll(/case \.(\w+): return "([^"]*)"/g)) raw[m[1].toUpperCase()] = m[2];
    symbolCache = raw;
  }
  return symbolCache[code.toUpperCase()];
}

/** `CurrencyUtils.symbol(for:)` cae a «$» con un código desconocido. */
export function currencySymbolOrDollar(code: string): string {
  return currencySymbol(code) ?? "$";
}

/** Lo que la app pone en `currency_display`: el código o el símbolo, según la preferencia de formato. */
export function currencyDisplay(code: string, format: "code" | "symbol"): string {
  return format === "symbol" ? currencySymbolOrDollar(code) : code;
}

// ---------- JSONSerialization ----------

/**
 * Réplica de `JSONSerialization.data(withJSONObject:)`: compacto, sin espacios, UTF-8 sin `\u` y con la barra
 * ESCAPADA (`S/` sale `S\/`, que es lo que ve el modelo). `sortedKeys` = la opción `.sortedKeys` (Tendencias).
 */
export function nsJSON(value: unknown, sortedKeys = false): string {
  if (value === null || value === undefined) return "null";
  if (typeof value === "string") return JSON.stringify(value).replace(/\//g, "\\/");
  if (typeof value === "number") return Object.is(value, -0) ? "0" : String(value);
  if (typeof value === "boolean") return value ? "true" : "false";
  if (Array.isArray(value)) return `[${value.map((v) => nsJSON(v, sortedKeys)).join(",")}]`;
  const entries = Object.entries(value as Record<string, unknown>).filter(([, v]) => v !== undefined);
  if (sortedKeys) entries.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return `{${entries.map(([k, v]) => `${nsJSON(k)}:${nsJSON(v, sortedKeys)}`).join(",")}}`;
}

/** `Int(x)` de Swift: trunca hacia cero. */
const int = (x: number): number => (Math.trunc(x) === 0 ? 0 : Math.trunc(x));
/** `Int(x.rounded())` de Swift: redondeo al más cercano, mitades lejos de cero. */
const intRounded = (x: number): number => {
  const r = Math.sign(x) * Math.round(Math.abs(x));
  return r === 0 ? 0 : r;
};

// ---------- idioma y trato (compartidos por los tres prompts de Insights y el chat) ----------

/** `AIPromptLanguage.baseCode(of:)`: «es-PE» → «es», «zh-Hans» → «zh». */
export function baseCode(language: string): string {
  return new Intl.Locale(language).language;
}

/** Una tabla `switch` de `AIPromptLanguage` (`case "x": return "y"`), solo dentro de su función. */
function languageTable(marker: string): { cases: Map<string, string>; fallback: string | null } {
  const rest = from(readRepoFile(PATHS.language), marker);
  const end = rest.indexOf("\n    static func ", marker.length);
  const fn = end < 0 ? rest : rest.slice(0, end);
  const cases = new Map([...fn.matchAll(/case "([\w-]+)": return "([^"]+)"/g)].map((m) => [m[1], m[2]]));
  if (cases.size === 0) throw new Error(`swift: no encuentro la tabla de «${marker}» en AIPromptLanguage`);
  return { cases, fallback: fn.match(/default: return "([^"]+)"/)?.[1] ?? null };
}

/** `AIPromptLanguage.informalRegister(forBaseLanguage:)`, con la tabla leída del Swift. */
export function informalRegister(base: string): string {
  const { cases, fallback } = languageTable("static func informalRegister(");
  if (!fallback) throw new Error("swift: el trato de AIPromptLanguage no tiene default");
  return cases.get(base) ?? fallback;
}

/** `AIPromptLanguage.label(for:)`: «italiano (it)», o el código si el idioma no tiene nombre. */
export function languageLabel(language: string): string {
  const name = languageTable("static func spanishName(").cases.get(baseCode(language));
  return name ? `${name} (${language})` : language;
}

/** `InsightsLLMService.languageInstruction(_:)`: la línea de idioma de los tres prompts de Insights. */
export function languageInstruction(language: string): string {
  const fn = from(readRepoFile(PATHS.insights), "static func languageInstruction(");
  return interpolate(swiftLineLiteralAfter(fn, "return "), { label: languageLabel(language) });
}

// ---------- tono y enfoque (compartidos por Insights y Tendencias) ----------

export type InsightTone = "normal" | "considerate" | "sarcastic";
export type InsightFocus = "balanced" | "saver" | "cautious";

/** `InsightsLLMService.toneInstruction(for:country:)`. */
export function toneInstruction(tone: InsightTone, country: string): string {
  if (tone === "normal") return "";
  const src = readRepoFile(PATHS.insights);
  const fn = from(src, "static func toneInstruction(");
  const fallback = swiftLineLiteralAfter(fn, "let regionHint = country.isEmpty ? ");
  const regionHint = country === "" ? fallback : country;
  const tpl = swiftMultilineAfter(fn, "static func toneInstruction(", tone === "considerate" ? 0 : 1);
  return interpolate(tpl, { regionHint });
}

/** `InsightsLLMService.focusInstruction(for:)`. */
export function focusInstruction(focus: InsightFocus): string {
  const src = readRepoFile(PATHS.insights);
  const nth = { balanced: 0, saver: 1, cautious: 2 }[focus];
  return swiftMultilineAfter(src, "static func focusInstruction(", nth);
}

// ---------- insights.cards ----------

export interface CardsFilters {
  mode: "include" | "exclude";
  accounts?: string[];
  categories?: string[];
  subcategories?: string[];
  tags?: string[];
  /** `NeedType.displayName` ya localizado. */
  needs?: string[];
  currencies?: string[];
  /** Una sola naturaleza seleccionada; `displayName` localizado («Gastos», «Ingresos»…). */
  transactionType?: { kind: "income" | "expense"; displayName: string };
  search?: string;
}

/** Lo que `InsightData` lleva a `buildAggregatedData`, con los `Double` crudos (la app los trunca al serializar). */
export interface CardsInput {
  currency: string;
  currencyDisplayFormat: "code" | "symbol";
  /** El idioma de la app, `AIPromptLanguage.current` (BCP-47: «es-PE», «zh-Hans»…). Hasta el 2026-10-07 la app
   * mandaba `Locale.current.language.languageCode`, el de la región. */
  language: string;
  /** `Locale.current.region` («PE», «ES»…), «» si no hay. */
  country: string;
  comparisonMode: "month" | "year";
  tone: InsightTone;
  focus: InsightFocus;
  summary: {
    totalExpense: number;
    totalIncome: number;
    netBalance: number;
    expenseVariation: number | null;
    incomeVariation: number | null;
    dailyAverageVariation: number | null;
    balanceVariation: number | null;
    transactionCount: number;
    /** `PreviousPeriodHelper.formatComparisonText`: «vs Sep 26», «vs 2025»… */
    previousPeriodLabel: string;
  };
  dailyAverage: number;
  topCategories: { name: string; amount: number; percentage: number }[];
  topSubcategory?: { name: string; amount: number };
  /** `visibleCategoryTreeLabels()`: «Comida (Restaurantes, Supermercado)». */
  categoryTree?: string[];
  highestExpense?: { amount: number; note: string };
  highestAvgWeekday?: { day: string; average: number };
  subscriptions?: { count: number; monthly: number };
  recurring?: { count: number; monthly: number };
  pending?: { count: number; amount: number };
  needs?: { essential: number; priority: number; optional: number };
  budgetsAtRisk?: { name: string; spent: number; limit: number; usagePercent: number }[];
  yearOverYear?: { current: number; previous: number; variation: number | null };
  filters?: CardsFilters;
  shared?: {
    totalShared: number;
    totalPersonal: number;
    sharedCount: number;
    groupCount: number;
    byGroup?: { name: string; total: number }[];
    topSharedCategories?: { category: string; amount: number }[];
    pendingDebt?: number;
  };
}

/** `comparison_ref` del VM («periodo anterior» / «año anterior»), leído del Swift. */
function comparisonRef(mode: "month" | "year"): string {
  const vm = readRepoFile(PATHS.insightsVM);
  const m = from(vm, "let comparisonLabel = comparisonMode == .year ? ").match(/\? "([^"]*)" : "([^"]*)"/);
  if (!m) throw new Error("swift: no encuentro comparison_ref en InsightsViewModel");
  return mode === "year" ? m[1] : m[2];
}

/** Réplica de `InsightsViewModel.buildFilterContext`. */
export function cardsFilterContext(f: CardsFilters): Record<string, unknown> {
  const out: Record<string, unknown> = { mode: f.mode };
  const descriptions: string[] = [];
  const verb = f.mode === "exclude" ? "Excluyendo" : "Solo";
  const list = (key: string, label: string, names?: string[]) => {
    if (!names?.length) return;
    out[key] = names;
    descriptions.push(`${verb} ${label}: ${names.join(", ")}`);
  };
  list("accounts", "cuentas", f.accounts);
  list("categories", "categorías", f.categories);
  list("subcategories", "subcategorías", f.subcategories);
  list("tags", "etiquetas", f.tags);
  list("needs", "naturalezas", f.needs);
  list("currencies", "monedas", f.currencies);
  if (f.transactionType) {
    out.transaction_type = f.transactionType.kind;
    descriptions.push(`Solo ${f.transactionType.displayName.toLowerCase()}`);
  }
  if (f.search) {
    out.search = f.search;
    descriptions.push(`Buscando: "${f.search}"`);
  }
  out.summary = descriptions.join(". ");
  return out;
}

const pctString = (v: number | null): string => (v === null ? "N/A" : `${int(v)}%`);

/** Réplica de `InsightsViewModel.buildAggregatedData`: claves en el orden del Swift. */
export function cardsPayload(c: CardsInput): Record<string, unknown> {
  const s = c.summary;
  const r: Record<string, unknown> = {
    currency: c.currency,
    currency_display: currencyDisplay(c.currency, c.currencyDisplayFormat),
    locale: c.language,
    country: c.country,
    comparison_ref: comparisonRef(c.comparisonMode),
    comparison_label: s.previousPeriodLabel,
    total_expense: int(s.totalExpense),
    total_income: int(s.totalIncome),
    net_balance: int(s.netBalance),
    spending_total_variation: pctString(s.expenseVariation),
    income_variation: pctString(s.incomeVariation),
    daily_avg_variation: pctString(s.dailyAverageVariation),
    balance_variation: pctString(s.balanceVariation),
    count: s.transactionCount,
    daily_avg: int(c.dailyAverage),
  };
  if (c.topCategories.length) r.top_categories = c.topCategories.map((t) => ({ name: t.name, amount: int(t.amount), pct: int(t.percentage) }));
  if (c.topSubcategory) {
    const pct = s.totalExpense > 0 ? int((c.topSubcategory.amount / s.totalExpense) * 100) : 0;
    r.top_subcategory = { name: c.topSubcategory.name, amount: int(c.topSubcategory.amount), pct_of_total: pct };
  }
  if (c.categoryTree?.length) r.category_tree = c.categoryTree;
  if (c.highestExpense) r.highest_expense = { amount: int(c.highestExpense.amount), description: c.highestExpense.note };
  if (c.highestAvgWeekday) r.highest_avg_weekday = { day: c.highestAvgWeekday.day, avg: int(c.highestAvgWeekday.average) };
  if (c.subscriptions && c.subscriptions.count > 0) r.subscriptions = { count: c.subscriptions.count, monthly_total: int(c.subscriptions.monthly) };
  if (c.recurring && c.recurring.count > 0) r.recurring_payments = { count: c.recurring.count, monthly_total: int(c.recurring.monthly) };
  if (c.pending && c.pending.count > 0) r.pending_payments = { count: c.pending.count, amount: int(c.pending.amount) };
  if (c.needs) {
    const total = c.needs.essential + c.needs.priority + c.needs.optional;
    if (total > 0) {
      const part = (x: number) => ({ pct: int((x / total) * 100), amount: int(x) });
      r.need_split = { essential: part(c.needs.essential), priority: part(c.needs.priority), optional: part(c.needs.optional) };
    }
  }
  if (c.budgetsAtRisk?.length) {
    r.budgets_at_risk = c.budgetsAtRisk.map((b) => ({ name: b.name, spent: int(b.spent), limit: int(b.limit), usage_pct: int(b.usagePercent) }));
  }
  if (c.yearOverYear) {
    const y: Record<string, unknown> = { current: int(c.yearOverYear.current), previous: int(c.yearOverYear.previous) };
    if (c.yearOverYear.variation !== null) y.variation = `${int(c.yearOverYear.variation)}%`;
    r.year_ago = y;
  }
  if (c.filters) r.active_filters = cardsFilterContext(c.filters);
  if (c.shared) {
    const g = c.shared;
    const d: Record<string, unknown> = { total_shared: int(g.totalShared), total_personal: int(g.totalPersonal), shared_count: g.sharedCount, active_groups: g.groupCount };
    if (s.totalExpense > 0) d.shared_pct = int((g.totalShared / s.totalExpense) * 100);
    if (g.byGroup?.length) d.by_group = g.byGroup.slice(0, 5).map((x) => ({ name: x.name, amount: int(x.total) }));
    if (g.topSharedCategories?.length) d.top_shared_categories = g.topSharedCategories.slice(0, 3).map((x) => ({ name: x.category, amount: int(x.amount) }));
    if ((g.pendingDebt ?? 0) > 0) d.pending_debt = int(g.pendingDebt ?? 0);
    r.shared_expenses = d;
  }
  return r;
}

/** El `filterContext` del prompt de Insights (vacío sin filtros con resumen). */
function cardsFilterPrompt(payload: Record<string, unknown>): string {
  const f = payload.active_filters as { summary?: string; mode?: string } | undefined;
  if (!f?.summary) return "";
  const fn = from(readRepoFile(PATHS.insights), "func generateInsights(");
  const tpl = swiftMultilineAfter(fn, "func generateInsights(", f.mode === "exclude" ? 0 : 1);
  return interpolate(tpl, { summary: f.summary });
}

export function cardsSystemPrompt(c: CardsInput, payload: Record<string, unknown> = cardsPayload(c)): string {
  const fn = from(readRepoFile(PATHS.insights), "func generateInsights(");
  const tpl = swiftMultilineAfter(fn, "let systemPrompt = \"\"\"");
  return interpolate(tpl, {
    currencyCode: c.currency,
    currencyDisplay: String(payload.currency_display),
    languageLine: languageInstruction(c.language),
    register: informalRegister(baseCode(c.language)),
    comparisonRef: String(payload.comparison_ref),
    comparisonLabel: String(payload.comparison_label),
    filterContext: cardsFilterPrompt(payload),
    toneInstruction: toneInstruction(c.tone, c.country),
    focusInstruction: focusInstruction(c.focus),
  });
}

function userMessage(fnMarker: string, literalMarker: string, json: string, key: string): string {
  const fn = from(readRepoFile(fnMarker.startsWith("Trends") ? PATHS.trends : PATHS.insights), fnMarker.replace(/^Trends:/, ""));
  return interpolate(swiftLineLiteralAfter(fn, literalMarker), { [key]: json });
}

function body(system: string, user: string): Record<string, unknown> {
  return {
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    model: "gpt-4.1-mini",
    response_format: { type: "json_object" },
    temperature: 0.4,
    stream: false,
  };
}

export function cardsBody(c: CardsInput): Record<string, unknown> {
  const payload = cardsPayload(c);
  const user = userMessage("func generateInsights(", "let userMessage = ", nsJSON(payload), "jsonString");
  return body(cardsSystemPrompt(c, payload), user);
}

// ---------- insights.cashflow ----------

export interface CashFlowInput {
  currency: string;
  startingBalance: number;
  /**
   * Meses de la proyección en orden. `accumulated` explícito o, si se omite, `startingBalance` más el neto
   * acumulado desde el primer mes con saldo (`balanceFrom`, por defecto el primero).
   */
  months: { month: string; income: number; expense: number; isCurrent?: boolean; accumulated?: number | null }[];
  balanceFrom?: number;
}

interface CashFlowMonthCalc {
  month: string;
  income: number;
  expense: number;
  net: number;
  isCurrent: boolean;
  accumulated: number | null;
}

export function cashFlowMonths(c: CashFlowInput): CashFlowMonthCalc[] {
  let acc = c.startingBalance;
  const from = c.balanceFrom ?? 0;
  return c.months.map((m, i) => {
    const net = m.income - m.expense;
    let accumulated: number | null;
    if (m.accumulated !== undefined) accumulated = m.accumulated;
    else if (i < from) accumulated = null;
    else {
      acc += net;
      accumulated = acc;
    }
    return { month: m.month, income: m.income, expense: m.expense, net, isCurrent: !!m.isCurrent, accumulated };
  });
}

/** `date.formatted(monthStyle).lowercased()`: mes abreviado y año en el idioma de la app. */
export function monthName(month: string, locale: string): string {
  const d = new Date(`${month}-15T12:00:00Z`);
  return new Intl.DateTimeFormat(locale, { month: "short", year: "numeric", timeZone: "UTC" }).format(d).toLowerCase();
}

/** Réplica de `InsightsLLMService.buildCashFlowPayload`. `language` = idioma de la app (los nombres de mes). */
export function cashFlowPayload(c: CashFlowInput, language: string): Record<string, unknown> {
  const months = cashFlowMonths(c);
  const current = months.find((m) => m.isCurrent);
  const withBalance = months.filter((m) => m.accumulated !== null);
  // `min(by:)` devuelve el PRIMERO de los empatados.
  let lowest: CashFlowMonthCalc | undefined;
  for (const m of withBalance) if (!lowest || (m.accumulated ?? 0) < (lowest.accumulated ?? 0)) lowest = m;
  const negative = months.filter((m) => (m.accumulated ?? 0) < 0).length;
  const avgNet = months.length ? months.reduce((a, m) => a + m.net, 0) / months.length : 0;
  const p: Record<string, unknown> = {
    startingBalance: c.startingBalance,
    monthsTotal: months.length,
    monthsPositive: months.length - negative,
    monthsNegative: negative,
    avgMonthlyNet: int(avgNet),
    currency: c.currency,
  };
  if (current) {
    p.currentMonth = {
      name: monthName(current.month, language),
      income: int(current.income),
      expense: int(current.expense),
      net: int(current.net),
      accumulated: int(current.accumulated ?? 0),
    };
  }
  const last = months[months.length - 1];
  if (last) p.endMonth = { name: monthName(last.month, language), accumulated: int(last.accumulated ?? 0) };
  if (lowest) p.lowestAccumulated = { month: monthName(lowest.month, language), balance: int(lowest.accumulated ?? 0) };
  return p;
}

/** `InsightsLLMService.cashFlowSystemPrompt(currencyCode:language:)`. */
export function cashFlowSystemPrompt(currency: string, language: string): string {
  return commentSystemPrompt("static func cashFlowSystemPrompt(", currency, language);
}

/** Los dos comentarios de una frase comparten forma: divisa, línea de idioma y trato. */
function commentSystemPrompt(marker: string, currency: string, language: string): string {
  const fn = from(readRepoFile(PATHS.insights), marker);
  return interpolate(swiftMultilineAfter(fn, "return \"\"\""), {
    currencyCode: currency,
    currencyDisplay: currencySymbol(currency) ?? currency,
    languageLine: languageInstruction(language),
    register: informalRegister(baseCode(language)),
  });
}

export function cashFlowBody(c: CashFlowInput, language: string): Record<string, unknown> {
  const user = userMessage("func generateCashFlowInsight(", "buildChatMessages(system: systemPrompt, user: ", nsJSON(cashFlowPayload(c, language)), "jsonString");
  return body(cashFlowSystemPrompt(c.currency, language), user);
}

// ---------- insights.deviation ----------

export interface DeviationInput {
  currency: string;
  /** Promedios por mes de cada línea del plan que se pasó (`CashFlowChartsSheet.buildDeviations`), sin truncar. */
  deviations: { name: string; planned: number; actual: number; excess: number }[];
}

/** El diccionario de `generateDeviationInsight`. */
export function deviationPayload(c: DeviationInput): Record<string, unknown> {
  const total = c.deviations.reduce((a, d) => a + d.excess, 0);
  return {
    items: c.deviations.map((d) => ({ name: d.name, planned: int(d.planned), actual: int(d.actual), excess: int(d.excess) })),
    totalExcess: int(total),
    currency: c.currency,
  };
}

/** `InsightsLLMService.deviationSystemPrompt(currencyCode:language:)`. */
export function deviationSystemPrompt(currency: string, language: string): string {
  return commentSystemPrompt("static func deviationSystemPrompt(", currency, language);
}

export function deviationBody(c: DeviationInput, language: string): Record<string, unknown> {
  const user = userMessage("func generateDeviationInsight(", "buildChatMessages(system: systemPrompt, user: ", nsJSON(deviationPayload(c)), "jsonString");
  return body(deviationSystemPrompt(c.currency, language), user);
}

// ---------- trends.summary ----------

export interface TrendsInput {
  metric: "balance" | "income" | "expense";
  periodLabel: string;
  comparisonLabel: string | null;
  currentTotal: number;
  previousTotal: number | null;
  /** Períodos COMPLETOS anteriores, del más antiguo al más reciente. */
  history: { start: string; income: number; expense: number; net: number }[];
  historyUnit: "weeks" | "months" | "years" | null;
  cashFlow: { income: number; expense: number; net: number } | null;
  /** weekday: 1 = domingo … 7 = sábado (Calendar de Swift). */
  weekdaySpending: { weekday: number; average: number }[];
  currency: string;
  currencyDisplayFormat: "code" | "symbol";
  /** `AppLocale.identifier`: «es-PE», «zh-Hans»… */
  locale: string;
  country: string;
  filtersActive: boolean;
  tone: InsightTone;
  focus: InsightFocus;
}

/** `calendar.weekdaySymbols[weekday - 1]` con el idioma de la app. */
export function weekdayName(weekday: number, locale: string): string {
  // 2026-10-04 fue domingo.
  const d = new Date(Date.UTC(2026, 9, 3 + weekday, 12));
  return new Intl.DateTimeFormat(locale, { weekday: "long", timeZone: "UTC" }).format(d);
}

/** Réplica de `TrendsAIService.buildPayload` (las claves las ordena `serialize`, con `.sortedKeys`). */
export function trendsPayload(t: TrendsInput): Record<string, unknown> {
  const p: Record<string, unknown> = {
    locale: t.locale,
    country: t.country,
    currency: t.currency,
    currency_display: currencyDisplay(t.currency, t.currencyDisplayFormat),
    metric: t.metric,
    period: t.periodLabel,
    filters_active: t.filtersActive,
  };
  if (t.history.length) {
    p.history_unit = t.historyUnit ?? "period";
    p.history_completed_periods = t.history.map((h) => ({ start: h.start, income: intRounded(h.income), expense: intRounded(h.expense), net: intRounded(h.net) }));
  }
  if (t.comparisonLabel !== null) {
    const comparison: Record<string, unknown> = { previous_label: t.comparisonLabel, current: intRounded(t.currentTotal) };
    if (t.previousTotal !== null) {
      comparison.previous = intRounded(t.previousTotal);
      if (t.previousTotal !== 0) comparison.variation_pct = intRounded(((t.currentTotal - t.previousTotal) / Math.abs(t.previousTotal)) * 100);
    }
    p.comparison = comparison;
  }
  if (t.cashFlow) {
    const flow: Record<string, unknown> = { income: intRounded(t.cashFlow.income), expense: intRounded(t.cashFlow.expense), net: intRounded(t.cashFlow.net) };
    if (t.cashFlow.expense > 0) flow.income_covers_expense_pct = intRounded((t.cashFlow.income / t.cashFlow.expense) * 100);
    p.cash_flow = flow;
  }
  const days = t.weekdaySpending.filter((d) => d.average > 0).sort((a, b) => a.weekday - b.weekday);
  if (days.length) p.weekday_avg_expense = days.map((d) => ({ day: weekdayName(d.weekday, t.locale), avg: intRounded(d.average) }));
  return p;
}

export function trendsSystemPrompt(t: TrendsInput): string {
  const src = readRepoFile(PATHS.trends);
  const fn = from(src, "private static func systemPrompt(");
  const filters = t.filtersActive ? swiftLineLiteralAfter(fn, "let filters = input.filtersActive") : "";
  return interpolate(swiftMultilineAfter(fn, "return \"\"\""), {
    "input.metric.rawValue": t.metric,
    "input.currencyCode": t.currency,
    "input.currencyDisplay": currencyDisplay(t.currency, t.currencyDisplayFormat),
    filters,
    "input.locale": t.locale,
    toneInstruction: toneInstruction(t.tone, t.country),
    focusInstruction: focusInstruction(t.focus),
  });
}

export function trendsBody(t: TrendsInput): Record<string, unknown> {
  const user = userMessage("Trends:func generate(", "let userMessage = ", nsJSON(trendsPayload(t), true), "Self.serialize(payload)");
  return body(trendsSystemPrompt(t), user);
}

/** Los datos tal como los lee el modelo (para el criterio y el juez). */
export function userDataJSON(b: Record<string, unknown>): string {
  const msgs = b.messages as { role: string; content: string }[];
  const u = msgs.find((m) => m.role === "user")?.content ?? "";
  return u.slice(u.indexOf("\n") + 1);
}
