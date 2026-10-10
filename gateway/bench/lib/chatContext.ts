import { categoryName, currencySymbol, lprojFor, needOf, seedCategoryOf, subcategoryName, type Need } from "./appCatalog";

/**
 * Réplica en TS de lo que `FullFinancialContextBuilder` (Yala/Services/Chat) entrega al asistente del chat,
 * y de su serialización (`FullFinancialContext.toJSONString`).
 *
 * Los casos del banco no traen un JSON escrito a mano: traen una PERSONA (cuentas, ingresos, hábitos de gasto,
 * presupuestos, pagos programados) y aquí se genera su libro de movimientos de forma determinista y se agrega
 * con las mismas reglas que la app. Así el contexto es coherente por construcción (la suma de las categorías
 * es el gasto del mes, el presupuesto gasta lo que gastan sus subcategorías…) y el criterio puede calcular la
 * respuesta correcta desde el mismo objeto que ve el modelo.
 *
 * Lo que se replica, y de dónde (medido en el Swift el 2026-10-07):
 * - Intervalos de `buildIntervals`: los meses y semanas cerrados acaban 1 s antes del siguiente; la semana
 *   empieza según la región (`Calendar.current.firstWeekday`: domingo en US, BR, PE, PT y JP; lunes en el resto).
 * - `last_month_to_date` (`lastMonthToDateInterval`, 2026-10-09): el mes pasado hasta el final del día equivalente a
 *   hoy (`DateAlignmentHelper.alignedPreviousInterval` menos 1 s); si hoy no existe en el mes pasado (31 frente a 30,
 *   29-31 frente a febrero), el mes pasado entero. Las categorías, subcategorías y comercios llevan su
 *   `total_last_month_to_date`, y la variación se calcula contra él (`variation_percent_vs_last_month_to_date`).
 * - `daily_avg` = gasto / `DateIntervalDayCount.days` (que TRUNCA: el mes en curso a las 12:00 del día 7 son 6 días).
 * - Nada se redondea: los importes viajan como `Double` crudos (12.300000000000001 incluido).
 * - `JSONEncoder` con `.sortedKeys`: claves ordenadas, opcionales `nil` OMITIDOS (no `null`) y la barra escapada
 *   (`S/` → `S\/`), que es el comportamiento por defecto de `JSONEncoder`.
 * - Lo que no se replica porque los casos no lo usan: multidivisa en los movimientos (todos en la divisa
 *   principal; las banderas `*_is_approximate` salen `false`), gastos de grupo puenteados, ajustes de saldo,
 *   cuentas excluidas y la sección `anomalies` (solo con palabras de anomalía en la pregunta; el banco comprueba
 *   que ninguna pregunta las tenga, ver `chatAnswer.ts`).
 */

// ---------- persona ----------

export interface PersonaAccount {
  name: string;
  /** Valor crudo de `AccountType` (la app guarda el rawValue en español: «Cuenta corriente», «Efectivo»…). */
  type: string;
  balance: number;
  currency?: string;
  /** Tasa a la divisa principal (solo cuentas en otra divisa). */
  rate?: number;
}

export interface SpendHabit {
  /** Clave del seed (`supermarkets`, `restaurants`…). */
  sub: string;
  /** Movimientos al mes (fracción = probabilidad del último). */
  perMonth: number;
  /** Importe mínimo y máximo en la divisa principal. */
  min: number;
  max: number;
  /** Cuenta del movimiento (por defecto, la primera). */
  account?: string;
}

export interface Persona {
  id: string;
  /** `AppLocale.current.identifier` (BCP-47): lo que la app pasa como idioma. */
  language: string;
  /** `Locale.current.region?.identifier`. */
  country: string;
  currency: string;
  /** Hoy (la hora es siempre las 12:00 local). */
  today: string;
  seed: number;
  /** Decimales de los importes generados (0 en JPY, CLP, ARS…). */
  decimals: number;
  accounts: PersonaAccount[];
  income: { sub: string; amount: number; day: number; note: string; account?: string }[];
  habits: SpendHabit[];
  /** Comercios por subcategoría del seed: la nota del movimiento. Sin comercios, la nota queda vacía. */
  merchants: Record<string, string[]>;
  budgets: { name: string; subs: string[]; limit: number }[];
  scheduled: { name: string; amount: number; sub: string; day: number; kind: "subscription" | "recurring"; account?: string }[];
  /** Etiquetas: se ponen a los movimientos de esas subcategorías en el mes indicado (0 = el actual, 1 = el pasado). */
  tags: { name: string; subs: string[]; monthsAgo: number }[];
  /** Movimientos sueltos añadidos a mano (fecha ISO, importe con signo, clave del seed, nota). */
  extra?: { date: string; amount: number; sub: string; note?: string; account?: string; tags?: string[] }[];
}

export interface Tx {
  /** ms desde epoch de una fecha «ingenua» (sin zona: los días son de 86 400 000 ms). */
  t: number;
  /** Con signo: gasto negativo. */
  amount: number;
  sub: string;
  catKey: string;
  isIncome: boolean;
  note: string | null;
  account: string;
  tags: string[];
}

// ---------- fechas ingenuas ----------

const DAY = 86_400_000;

export function naive(iso: string, h = 0, m = 0, s = 0): number {
  const [y, mo, d] = iso.split("-").map(Number);
  return Date.UTC(y, mo - 1, d, h, m, s);
}

function ymd(t: number): string {
  return new Date(t).toISOString().slice(0, 10);
}

function startOfMonth(t: number, add = 0): number {
  const d = new Date(t);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + add, 1);
}

function daysInMonth(t: number): number {
  const d = new Date(t);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
}

/** `DateIntervalDayCount.days(from:to:)`: días completos de `start` a `end + 1 s`, truncados. */
export function dayCount(start: number, end: number): number {
  if (!(end > start)) return 0;
  return Math.max(0, Math.floor((end + 1000 - start) / DAY));
}

/** Regiones cuyo primer día de la semana es domingo según CLDR (las de los casos). */
const SUNDAY_FIRST = new Set(["US", "BR", "PE", "PT", "JP", "CA", "MX", "CO"]);

// ---------- generador determinista ----------

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function round(x: number, decimals: number): number {
  const f = 10 ** decimals;
  return Math.round(x * f) / f;
}

/** El libro de la persona: del 1 de enero del año de `today` hasta `today` a las 12:00. */
export function generateLedger(p: Persona): Tx[] {
  const rnd = mulberry32(p.seed);
  const now = naive(p.today, 12);
  const yearStart = Date.UTC(new Date(now).getUTCFullYear(), 0, 1);
  const txs: Tx[] = [];
  const defaultAccount = p.accounts[0].name;
  const push = (t: number, amount: number, sub: string, note: string | null, account?: string, tags: string[] = []) => {
    if (t > now) return;
    const cat = seedCategoryOf(sub);
    txs.push({ t, amount, sub, catKey: cat.key, isIncome: cat.isIncome, note, account: account ?? defaultAccount, tags });
  };
  const monthsBack = (t: number) => {
    const a = new Date(now);
    const b = new Date(t);
    return (a.getUTCFullYear() - b.getUTCFullYear()) * 12 + a.getUTCMonth() - b.getUTCMonth();
  };
  for (let ms = yearStart; ms <= now; ms = startOfMonth(ms, 1)) {
    const dim = daysInMonth(ms);
    // Un poco de variación entre meses, para que «más que el mes pasado» tenga sentido.
    const monthFactor = 0.8 + rnd() * 0.45;
    for (const inc of p.income) push(ms + (Math.min(inc.day, dim) - 1) * DAY + 9 * 3_600_000, inc.amount, inc.sub, inc.note, inc.account);
    for (const s of p.scheduled) push(ms + (Math.min(s.day, dim) - 1) * DAY + 8 * 3_600_000, -s.amount, s.sub, s.name, s.account);
    for (const h of p.habits) {
      const whole = Math.floor(h.perMonth);
      const n = whole + (rnd() < h.perMonth - whole ? 1 : 0);
      for (let i = 0; i < n; i++) {
        const day = 1 + Math.floor(rnd() * dim);
        const hour = 8 + Math.floor(rnd() * 13);
        const amount = round((h.min + rnd() * (h.max - h.min)) * monthFactor, p.decimals);
        const list = p.merchants[h.sub] ?? [];
        const note = list.length ? list[Math.floor(rnd() * list.length)] : null;
        const t = ms + (day - 1) * DAY + hour * 3_600_000;
        const tags = p.tags.filter((tg) => tg.subs.includes(h.sub) && monthsBack(t) === tg.monthsAgo).map((tg) => tg.name);
        push(t, -Math.max(amount, 10 ** -p.decimals), h.sub, note, h.account, tags);
      }
    }
  }
  for (const e of p.extra ?? []) push(naive(e.date, 10), e.amount, e.sub, e.note ?? null, e.account, e.tags ?? []);
  return txs.sort((a, b) => b.t - a.t);
}

// ---------- el contexto ----------

/* eslint-disable @typescript-eslint/no-explicit-any */
export type Json = any;

function weekdaySymbols(language: string): string[] {
  // `Calendar.current.weekdaySymbols`, 1 = domingo. Un domingo conocido: 2026-10-04.
  return Array.from({ length: 7 }, (_, i) => new Intl.DateTimeFormat(language, { weekday: "long", timeZone: "UTC" }).format(new Date(Date.UTC(2026, 9, 4 + i))));
}

/** `DateFormatter` con `dateFormat = "MMMM yyyy"` y `Locale(identifier: language)` (mes en forma de formato). */
export function monthLabel(language: string, t: number): string {
  const d = new Date(t);
  const parts = new Intl.DateTimeFormat(language, { month: "long", day: "numeric", timeZone: "UTC" }).formatToParts(d);
  let month = parts.find((x) => x.type === "month")?.value ?? "";
  const base = language.split("-")[0];
  if (base === "ja" || base === "zh") month = new Intl.DateTimeFormat(language, { month: "long", timeZone: "UTC" }).format(d);
  return `${month} ${d.getUTCFullYear()}`;
}

/** `MerchantCanonicalizer.canonicalize`: mayúsculas, sin símbolos, espacios colapsados. */
export function canonicalMerchant(note: string | null): string | null {
  if (!note) return null;
  const c = note.toUpperCase().trim().replace(/[^\p{L}\p{N}_\s]/gu, "").replace(/\s+/g, " ").trim();
  return c || null;
}

interface Interval {
  start: number;
  end: number;
}

const inside = (iv: Interval, t: number) => t >= iv.start && t <= iv.end;

function needKey(n: Need): "essential" | "priority" | "optional" | "unclassified" {
  return n;
}

export interface BuiltContext {
  context: Json;
  /** `toJSONString()` de la app. */
  json: string;
  ledger: Tx[];
  lproj: string;
}

export function buildContext(p: Persona): BuiltContext {
  const lproj = lprojFor(p.language);
  const ledger = generateLedger(p);
  const now = naive(p.today, 12);
  const startOfToday = naive(p.today);
  const nowDate = new Date(now);
  const sundayFirst = SUNDAY_FIRST.has(p.country);
  const weekdayIdx = nowDate.getUTCDay(); // 0 = domingo
  const back = sundayFirst ? weekdayIdx : (weekdayIdx + 6) % 7;
  const weekStart = startOfToday - back * DAY;
  const monthStart = startOfMonth(now);
  const lastMonthStart = startOfMonth(now, -1);
  const twoStart = startOfMonth(now, -2);
  const threeStart = startOfMonth(now, -3);
  const yearStart = Date.UTC(nowDate.getUTCFullYear(), 0, 1);
  const iv = {
    today: { start: startOfToday, end: now },
    currentWeek: { start: weekStart, end: now },
    lastWeek: { start: weekStart - 7 * DAY, end: weekStart - 1000 },
    currentMonth: { start: monthStart, end: now },
    lastMonth: { start: lastMonthStart, end: monthStart - 1000 },
    lastMonthToDate: {
      start: lastMonthStart,
      end: nowDate.getUTCDate() <= Math.round((monthStart - lastMonthStart) / DAY)
        ? lastMonthStart + nowDate.getUTCDate() * DAY - 1000
        : monthStart - 1000,
    },
    twoMonthsAgo: { start: twoStart, end: lastMonthStart - 1000 },
    threeMonthsAgo: { start: threeStart, end: twoStart - 1000 },
    currentYear: { start: yearStart, end: now },
    last30: { start: now - 30 * DAY, end: now },
  };
  const weeks: Interval[] = [3, 2, 1, 0].map((i) => ({ start: weekStart - i * 7 * DAY, end: weekStart - i * 7 * DAY + 7 * DAY - 1000 }));
  const tx = ledger.filter((x) => x.t <= now);
  const abs = (x: Tx) => Math.abs(x.amount);
  const catName = (x: Tx) => categoryName(lproj, x.catKey);
  const subName = (x: Tx) => subcategoryName(lproj, x.sub);
  const iso = (t: number) => ymd(t);

  const summarize = (i: Interval) => {
    const ptx = tx.filter((x) => inside(i, x.t));
    const income = ptx.filter((x) => x.isIncome).reduce((a, x) => a + x.amount, 0);
    const expense = ptx.filter((x) => !x.isIncome).reduce((a, x) => a + abs(x), 0);
    const days = Math.max(1, dayCount(i.start, Math.min(i.end, now)));
    const out: Json = {
      income,
      expense,
      balance: income - expense,
      tx_count: ptx.length,
      daily_avg: expense / days,
      income_is_approximate: false,
      expense_is_approximate: false,
      balance_is_approximate: false,
    };
    if (income > 0) out.savings_rate_percent = ((income - expense) / income) * 100;
    return out;
  };

  const expenseIn = (i: Interval) => tx.filter((x) => inside(i, x.t) && !x.isIncome);

  // categories
  const cur = expenseIn(iv.currentMonth);
  const last = expenseIn(iv.lastMonth);
  const two = expenseIn(iv.twoMonthsAgo);
  const catAgg = new Map<string, { cur: number; n: number; last: number; lastToDate: number; two: number; subs: Map<string, { cur: number; last: number; lastToDate: number; two: number; n: number }> }>();
  const touch = (x: Tx) => {
    const c = catName(x);
    if (!catAgg.has(c)) catAgg.set(c, { cur: 0, n: 0, last: 0, lastToDate: 0, two: 0, subs: new Map() });
    const e = catAgg.get(c)!;
    const s = subName(x);
    if (!e.subs.has(s)) e.subs.set(s, { cur: 0, last: 0, lastToDate: 0, two: 0, n: 0 });
    return { e, s: e.subs.get(s)! };
  };
  for (const x of cur) { const { e, s } = touch(x); e.cur += abs(x); e.n++; s.cur += abs(x); s.n++; }
  for (const x of last) {
    const { e, s } = touch(x);
    e.last += abs(x); s.last += abs(x);
    if (inside(iv.lastMonthToDate, x.t)) { e.lastToDate += abs(x); s.lastToDate += abs(x); }
  }
  for (const x of two) { const { e, s } = touch(x); e.two += abs(x); s.two += abs(x); }
  const variation = (c: number, l: number) => (l > 0 ? ((c - l) / l) * 100 : undefined);
  const categories = [...catAgg.entries()]
    .sort((a, b) => b[1].cur - a[1].cur)
    .slice(0, 10)
    .map(([name, v]) => ({
      name,
      total_current_month: v.cur,
      total_last_month: v.last,
      total_last_month_to_date: v.lastToDate,
      total_two_months_ago: v.two,
      variation_percent_vs_last_month_to_date: variation(v.cur, v.lastToDate),
      tx_count_current_month: v.n,
      subcategories: [...v.subs.entries()]
        .filter(([, s]) => s.cur > 0 || s.last > 0 || s.two > 0)
        .sort((a, b) => b[1].cur - a[1].cur)
        .map(([sn, s]) => ({
          name: sn,
          total_current_month: s.cur,
          total_last_month: s.last,
          total_last_month_to_date: s.lastToDate,
          total_two_months_ago: s.two,
          variation_percent_vs_last_month_to_date: variation(s.cur, s.lastToDate),
          tx_count_current_month: s.n,
        })),
    }));

  // merchants
  const mCur = new Map<string, { total: number; n: number }>();
  const mLast = new Map<string, number>();
  const mLastToDate = new Map<string, number>();
  for (const x of cur) { const m = canonicalMerchant(x.note); if (!m) continue; const e = mCur.get(m) ?? { total: 0, n: 0 }; e.total += abs(x); e.n++; mCur.set(m, e); }
  for (const x of last) {
    const m = canonicalMerchant(x.note); if (!m) continue;
    mLast.set(m, (mLast.get(m) ?? 0) + abs(x));
    if (inside(iv.lastMonthToDate, x.t)) mLastToDate.set(m, (mLastToDate.get(m) ?? 0) + abs(x));
  }
  const merchants = [...mCur.entries()].sort((a, b) => b[1].total - a[1].total).slice(0, 20).map(([name, v]) => ({
    name,
    total_current_month: v.total,
    total_last_month: mLast.get(name) ?? 0,
    total_last_month_to_date: mLastToDate.get(name) ?? 0,
    tx_count: v.n,
    avg_amount: v.n ? v.total / v.n : 0,
    variation_percent_vs_last_month_to_date: variation(v.total, mLastToDate.get(name) ?? 0),
  }));

  // budgets (mensuales: el intervalo del mes en curso hasta su último segundo)
  const monthEnd = startOfMonth(now, 1) - 1000;
  const budgets = p.budgets.map((b) => {
    const spent = tx.filter((x) => !x.isIncome && b.subs.includes(x.sub) && x.t >= monthStart && x.t <= monthEnd).reduce((a, x) => a + abs(x), 0);
    const usage = b.limit > 0 ? (spent / b.limit) * 100 : undefined;
    const status = b.limit <= 0 ? "no_limit" : (usage ?? 0) >= 100 ? "exceeded" : (usage ?? 0) >= 75 ? "at_risk" : "on_track";
    return { name: b.name, limit: b.limit, spent, usage_percent: usage, days_left: Math.max(0, Math.floor((monthEnd - now) / DAY)), status, period_type: "monthly", currency: p.currency };
  });

  // recurring
  const paid: Json[] = [];
  const pending: Json[] = [];
  const cutoff = now + 30 * DAY;
  for (const add of [-1, 0, 1]) {
    const ms = startOfMonth(now, add);
    for (const s of p.scheduled) {
      const date = ms + (Math.min(s.day, daysInMonth(ms)) - 1) * DAY;
      const c = seedCategoryOf(s.sub);
      const base = { name: s.name, amount: s.amount, category: categoryName(lproj, c.key), subcategory: subcategoryName(lproj, s.sub) };
      if (inside(iv.currentMonth, date) && date <= now) paid.push({ ...base, date: iso(date) });
      else if (date > now && date <= cutoff) pending.push({ ...base, due_date: iso(date), type: s.kind });
    }
  }
  paid.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0));
  pending.sort((a, b) => (a.due_date < b.due_date ? -1 : a.due_date > b.due_date ? 1 : 0));
  const monthly = (kind: string) => p.scheduled.filter((s) => s.kind === kind).reduce((a, s) => a + s.amount, 0);

  // patterns
  const w30 = tx.filter((x) => inside(iv.last30, x.t) && !x.isIncome);
  const totals = new Map<number, { total: number; n: number }>();
  for (const x of w30) { const wd = new Date(x.t).getUTCDay() + 1; const e = totals.get(wd) ?? { total: 0, n: 0 }; e.total += abs(x); e.n++; totals.set(wd, e); }
  const totalDays = dayCount(iv.last30.start, iv.last30.end);
  const occ = new Map<number, number>();
  for (let d = 1; d <= 7; d++) occ.set(d, Math.floor(totalDays / 7));
  for (let i = 0; i < totalDays % 7; i++) { const wd = new Date(iv.last30.start + i * DAY).getUTCDay() + 1; occ.set(wd, (occ.get(wd) ?? 0) + 1); }
  const symbols = weekdaySymbols(p.language);
  const weekday = [1, 2, 3, 4, 5, 6, 7].map((d) => {
    const e = totals.get(d) ?? { total: 0, n: 0 };
    const o = occ.get(d) ?? 0;
    return { weekday: symbols[d - 1], total: e.total, avg_per_day: o > 0 ? e.total / o : 0, sample_size: e.n, day_occurrences: o };
  });
  const needs = { essential: 0, priority: 0, optional: 0, unclassified: 0 };
  for (const x of cur) needs[needKey(needOf(x.sub))] += abs(x);

  // tags
  const tagAgg = new Map<string, { total: number; n: number }>();
  for (const x of cur) for (const tg of x.tags) { const e = tagAgg.get(tg) ?? { total: 0, n: 0 }; e.total += abs(x); e.n++; tagAgg.set(tg, e); }
  const tags = [...tagAgg.entries()].sort((a, b) => b[1].total - a[1].total).slice(0, 10).map(([name, v]) => ({ name, total_current_month: v.total, tx_count: v.n }));

  // top tx by subcategory
  const bySub = new Map<string, { cat: string; txs: Tx[] }>();
  for (const x of cur) { const s = subName(x); const e = bySub.get(s) ?? { cat: catName(x), txs: [] }; e.txs.push(x); bySub.set(s, e); }
  const topTx = [...bySub.entries()]
    .map(([name, v]) => ({ name, cat: v.cat, txs: v.txs, total: v.txs.reduce((a, x) => a + abs(x), 0) }))
    .sort((a, b) => b.total - a.total)
    .slice(0, 10)
    .map((e) => ({
      subcategory_name: e.name,
      category_name: e.cat,
      transactions: [...e.txs].sort((a, b) => abs(b) - abs(a)).slice(0, 10).map((x) => ({ date: iso(x.t), amount: abs(x), merchant: canonicalMerchant(x.note) ?? undefined, account: x.account })),
    }));

  const accounts = p.accounts.map((a) => ({ name: a.name, type: a.type, balance: a.balance, currency: a.currency ?? p.currency }));
  const totalBalance = p.accounts.reduce((acc, a) => acc + a.balance * (a.rate ?? 1), 0);

  const context: Json = {
    metadata: {
      date_today: p.today,
      weekday: symbols[weekdayIdx],
      month_label: monthLabel(p.language, now),
      currency: p.currency,
      currency_display: currencySymbol(p.currency),
      language: p.language,
      country: p.country,
      excluded_accounts: [],
    },
    // Las personas del banco no tienen cuentas de Grupos: el total suma todo, como la app con «Grupos en el total»
    // encendido (su default).
    balances: { accounts, total_balance: totalBalance, total_includes_groups: true },
    periods: {
      today: summarize(iv.today),
      current_week: summarize(iv.currentWeek),
      last_week: summarize(iv.lastWeek),
      last_4_weeks: weeks.map((w) => {
        const s = summarize(w);
        return { week_start: iso(w.start), income: s.income, expense: s.expense, income_is_approximate: false, expense_is_approximate: false };
      }),
      current_month: summarize(iv.currentMonth),
      last_month: summarize(iv.lastMonth),
      last_month_to_date: summarize(iv.lastMonthToDate),
      two_months_ago: summarize(iv.twoMonthsAgo),
      three_months_ago: summarize(iv.threeMonthsAgo),
      current_year: summarize(iv.currentYear),
    },
    categories,
    uncategorized: { total_current_month: 0, tx_count_current_month: 0 },
    merchants_top_20: merchants,
    budgets,
    recurring: { paid_this_month: paid, pending_next_30_days: pending, totals: { subscriptions_monthly: monthly("subscription"), recurring_monthly: monthly("recurring") } },
    patterns: { weekday_pattern_30_days: weekday, needs_breakdown_current_month: { ...needs, total: needs.essential + needs.priority + needs.optional + needs.unclassified } },
    tags_top_10: tags,
    top_tx_by_subcategory: topTx,
  };
  return { context, json: toAppJSON(context), ledger, lproj };
}

/**
 * `JSONEncoder` con `.sortedKeys` y la estrategia de fecha por defecto: claves ordenadas, `undefined` fuera
 * (Swift omite los opcionales `nil`) y `/` escapada como `\/` (la escapa `JSONEncoder` salvo con
 * `.withoutEscapingSlashes`, que la app no pone).
 */
export function toAppJSON(value: Json): string {
  const sort = (v: Json): Json => {
    if (Array.isArray(v)) return v.map(sort);
    if (v && typeof v === "object") {
      const out: Json = {};
      for (const k of Object.keys(v).sort()) if (v[k] !== undefined) out[k] = sort(v[k]);
      return out;
    }
    return v;
  };
  return JSON.stringify(sort(value)).replace(/\//g, "\\/");
}
