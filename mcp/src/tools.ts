/**
 * Las seis herramientas de lectura de la fase 0 (docs/exploracion/plugin-claude-mcp.md §1).
 *
 * Reglas de diseño que vienen de los criterios de revisión de Anthropic y no se relajan:
 * - Devuelven resultados YA CALCULADOS, no volcados de tablas: si Claude suma filas por su cuenta, sus cifras no
 *   cuadran con las de la app (divisas, signo de los reembolsos, ajustes de grupos).
 * - Nombre ≤ 64 caracteres, `title` y `readOnlyHint: true` en todas.
 * - Las descripciones dicen qué devuelve la herramienta; no dan instrucciones a Claude.
 * - Frugales: `buscar_movimientos` pagina y ninguna respuesta lista miles de filas.
 *
 * `plan` es el punto de extensión para marcar alguna herramienta como Pro más adelante (decisión de Jürgen del
 * 2026-09-26: gratis por defecto). Hoy todas son "gratis" y no hay cobro.
 */
import { z } from "zod";
import { COLUMNS, NOT_DELETED, type YalaReader } from "./data";
import type { Env } from "./env";
import {
  addDays,
  assertDay,
  assertTimeZone,
  dayInZone,
  InvalidInputError,
  resolvePeriod,
  txDay,
  zonedDayStartUtc,
  type Day,
  type PeriodKind,
} from "./logic/dates";
import { buildRateBook, CARRY_FORWARD_LOOKBACK, utcDateKey, type RateBook } from "./logic/fx";
import { buildGroupAdjustment, type GroupAdjustment } from "./logic/groups";
import { buildLookup, categoryOf, type Lookup } from "./logic/lookup";
import { computeBalances } from "./logic/balances";
import { summarize } from "./logic/summary";
import { budgetPeriod, budgetStatuses, isBudgetActive } from "./logic/budgets";
import { listRecurring } from "./logic/recurring";
import {
  num,
  round2,
  type AccountRow,
  type BudgetRow,
  type CategoryRow,
  type ExchangeRateRow,
  type PreferenceRow,
  type ScheduledPaymentRow,
  type SubcategoryRow,
  type TagRow,
  type TxRow,
} from "./logic/types";

export type Plan = "gratis" | "pro";

export interface ToolContext {
  reader: YalaReader;
  env: Env;
  now: Date;
}

export interface ToolDef {
  name: string;
  title: string;
  description: string;
  plan: Plan;
  inputSchema: z.ZodRawShape;
  run: (ctx: ToolContext, args: Record<string, unknown>) => Promise<unknown>;
}

// ------------------------------------------------------------------ carga común

const ORDER_ID: [string, string] = ["order", "sync_id.asc"];

async function loadPrefs(ctx: ToolContext): Promise<Map<string, string>> {
  const { rows } = await ctx.reader.all<PreferenceRow>("user_preferences", [
    ["select", COLUMNS.prefs],
    ["key", "in.(defaultCurrencyCode,firstWeekday)"],
    ["order", "key.asc"],
  ]);
  return new Map(rows.filter((r) => r.value !== null).map((r) => [r.key, r.value as string]));
}

/**
 * Filas de tasas para convertir con la tasa de los días UTC `[fromKey, toKey]`: las de ese rango y, por debajo, las
 * suficientes para la ventana de 30 días anteriores de la app (ver fx.ts). Hay días con dos o tres filas —una por
 * dispositivo—, así que se leen hasta tres por día de ventana.
 */
async function loadRates(ctx: ToolContext, fromKey: string, toKey: string = fromKey): Promise<RateBook> {
  const [inRange, before] = await Promise.all([
    ctx.reader.all<ExchangeRateRow>("exchange_rates", [
      ["select", COLUMNS.rates],
      NOT_DELETED,
      ["date_key", `gte.${fromKey}`],
      ["date_key", `lte.${toKey}`],
      ["order", "date_key.desc,sync_id.asc"],
    ]),
    ctx.reader.one<ExchangeRateRow>(
      "exchange_rates",
      [["select", COLUMNS.rates], NOT_DELETED, ["date_key", `lt.${fromKey}`], ["order", "date_key.desc,sync_id.asc"]],
      CARRY_FORWARD_LOOKBACK * 3,
    ),
  ]);
  return buildRateBook([...inRange.rows, ...before]);
}

/** Día UTC de ahora: la clave con la que la app busca «la tasa de hoy». */
function todayUtcKey(ctx: ToolContext): string {
  return utcDateKey(ctx.now) as string;
}

/**
 * Ajuste de gastos de grupo construido con el conjunto MÁS AMPLIO: los movimientos leídos más las patas hermanas que
 * se quedaron fuera del rango (misma `split_expense_id`), como pide `GroupBridgeStatsAdjustment.build`.
 */
async function loadGroupAdjustment(ctx: ToolContext, txs: TxRow[], lookup: Lookup): Promise<GroupAdjustment> {
  const ids = [...new Set(txs.map((t) => t.split_expense_id).filter((v): v is string => !!v))];
  const siblings: TxRow[] = [];
  for (let i = 0; i < ids.length; i += 50) {
    const chunk = ids.slice(i, i + 50).map(quoteValue).join(",");
    const { rows } = await ctx.reader.all<TxRow>("tx_items", [
      ["select", COLUMNS.tx],
      NOT_DELETED,
      ["split_expense_id", `in.(${chunk})`],
      ORDER_ID,
    ]);
    siblings.push(...rows);
  }
  return buildGroupAdjustment([...txs, ...siblings], lookup.accounts, lookup.subcategories);
}

async function loadLookup(ctx: ToolContext): Promise<Lookup> {
  const [accounts, categories, subcategories, tags] = await Promise.all([
    ctx.reader.all<AccountRow>("accounts", [["select", COLUMNS.accounts], NOT_DELETED, ORDER_ID]),
    ctx.reader.all<CategoryRow>("categories", [["select", COLUMNS.categories], NOT_DELETED, ORDER_ID]),
    ctx.reader.all<SubcategoryRow>("subcategories", [["select", COLUMNS.subcategories], NOT_DELETED, ORDER_ID]),
    ctx.reader.all<TagRow>("tags", [["select", COLUMNS.tags], NOT_DELETED, ORDER_ID]),
  ]);
  return buildLookup({ accounts: accounts.rows, categories: categories.rows, subcategories: subcategories.rows, tags: tags.rows });
}

/**
 * Divisa preferida: la preferencia sincronizada `defaultCurrencyCode`. Si el usuario nunca la tocó no viaja
 * (medido en staging: A no la tiene), y entonces se usa la más frecuente entre las candidatas.
 */
export function resolvePreferredCurrency(prefs: Map<string, string>, candidates: (string | null)[]): { code: string; inferred: boolean } {
  const pref = prefs.get("defaultCurrencyCode")?.trim().toUpperCase();
  if (pref && /^[A-Z]{3}$/.test(pref)) return { code: pref, inferred: false };
  const counts = new Map<string, number>();
  for (const c of candidates) if (c) counts.set(c.toUpperCase(), (counts.get(c.toUpperCase()) ?? 0) + 1);
  const best = [...counts.entries()].sort((a, b) => b[1] - a[1])[0];
  return { code: best?.[0] ?? "PEN", inferred: true };
}

/**
 * Primer día de la semana: el que pase Claude; si no, la preferencia sincronizada `firstWeekday` (1 = domingo,
 * 2 = lunes); y si no está, lunes. Ese último caso no es una suposición: la app solo sube la preferencia cuando el
 * usuario la cambia (`PrefSyncKey.firstWeekday`, «ints por presencia»), y sin ella usa lunes
 * (`userConfiguredCalendar`).
 */
function firstWeekday(prefs: Map<string, string>, args: Record<string, unknown>): 1 | 2 {
  if (args.primer_dia_semana === "domingo") return 1;
  if (args.primer_dia_semana === "lunes") return 2;
  return prefs.get("firstWeekday") === "1" ? 1 : 2;
}

function zoneOf(ctx: ToolContext, args: Record<string, unknown>): { tz: string; assumed: boolean } {
  const given = typeof args.zona_horaria === "string" && args.zona_horaria ? args.zona_horaria : null;
  return { tz: assertTimeZone(given ?? ctx.env.DEFAULT_TIMEZONE), assumed: given === null };
}

/**
 * Lo único que el conector no puede saber de la app: en qué zona está el teléfono (la app no la sube; ticket
 * `app-uploads-its-timezone-to-the-cloud`). Solo se avisa cuando Claude no la pasó y se ha tenido que suponer.
 */
function zoneNotice(zone: { tz: string; assumed: boolean }): string[] {
  return zone.assumed
    ? [`No se indicó zona horaria: se usa ${zone.tz} para decidir qué día es hoy y dónde empieza cada periodo. Si el usuario está en otra, las cifras del borde del periodo pueden cambiar.`]
    : [];
}

const primerDiaSemana = z
  .enum(["lunes", "domingo"])
  .optional()
  .describe("Día en que empieza la semana del usuario, si lo sabes. Si no, se usa el que eligió en la app. Solo afecta a periodos y presupuestos semanales.");

const zonaHoraria = z
  .string()
  .max(64)
  .optional()
  .describe("Zona horaria IANA del usuario, por ejemplo America/Lima. Decide qué día es «hoy» y dónde empieza cada mes.");

function truncationNotice(truncated: boolean): string[] {
  return truncated ? ["Hay más datos de los que esta versión lee de una vez: la cifra puede quedarse corta."] : [];
}

// ------------------------------------------------------------------ herramientas

const listarCuentas: ToolDef = {
  name: "listar_cuentas",
  title: "Cuentas y saldos",
  plan: "gratis",
  description:
    "Devuelve las cuentas del usuario en Yala con su saldo actual en la divisa de cada cuenta, y el total de las cuentas " +
    "que cuentan para estadísticas convertido a su divisa preferida. Las cuentas archivadas solo salen si se piden.",
  inputSchema: {
    incluir_archivadas: z.boolean().optional().describe("Incluir las cuentas archivadas. Por defecto, no."),
  },
  async run(ctx, args) {
    const [accounts, txs, prefs, rates] = await Promise.all([
      ctx.reader.all<AccountRow>("accounts", [["select", COLUMNS.accounts], NOT_DELETED, ORDER_ID]),
      ctx.reader.all<Pick<TxRow, "account_ref" | "amount" | "currency_code">>("tx_items", [
        ["select", COLUMNS.txBalance],
        NOT_DELETED,
        ["account_ref", "not.is.null"],
        ORDER_ID,
      ]),
      loadPrefs(ctx),
      loadRates(ctx, todayUtcKey(ctx)),
    ]);
    const preferred = resolvePreferredCurrency(prefs, accounts.rows.map((a) => a.currency_code));
    const result = computeBalances(accounts.rows, txs.rows, preferred.code, rates, {
      incluirArchivadas: args.incluir_archivadas === true,
      todayUtc: todayUtcKey(ctx),
    });
    const avisos = [...truncationNotice(txs.truncated)];
    if (preferred.inferred) avisos.push(`No hay divisa preferida guardada; se usa ${preferred.code}, la más frecuente en tus cuentas.`);
    if (result.total.aproximado) {
      avisos.push("El total es aproximado: alguna divisa se convirtió sin la cotización exacta de hoy. La app lo marca igual, con «≈».");
    }
    if (result.total.sin_convertir.length > 0) avisos.push("Algunas divisas no son de las que la app reconoce y su saldo no está en el total.");
    return { ...result, avisos };
  },
};

const listarCategorias: ToolDef = {
  name: "listar_categorias",
  title: "Categorías",
  plan: "gratis",
  description:
    "Devuelve las categorías del usuario con sus subcategorías, indicando cuáles son de ingreso. Las ocultas solo salen si se piden.",
  inputSchema: {
    incluir_ocultas: z.boolean().optional().describe("Incluir categorías y subcategorías ocultas. Por defecto, no."),
  },
  async run(ctx, args) {
    const lookup = await loadLookup(ctx);
    const includeHidden = args.incluir_ocultas === true;
    const byCategory = new Map<string, SubcategoryRow[]>();
    for (const s of lookup.subcategories.values()) {
      if (!s.category_ref || (!includeHidden && s.is_visible === false)) continue;
      const list = byCategory.get(s.category_ref) ?? [];
      list.push(s);
      byCategory.set(s.category_ref, list);
    }
    const categorias = [...lookup.categories.values()]
      .filter((c) => includeHidden || c.is_visible !== false)
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0) || (a.name ?? "").localeCompare(b.name ?? "", "es"))
      .map((c) => ({
        id: c.sync_id,
        nombre: c.name ?? "(sin nombre)",
        es_ingreso: c.is_income === true,
        oculta: c.is_visible === false,
        subcategorias: (byCategory.get(c.sync_id) ?? [])
          .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
          .map((s) => ({ id: s.sync_id, nombre: s.name ?? "(sin nombre)", naturaleza: s.nature_raw_value, oculta: s.is_visible === false })),
      }));
    return { categorias, total: categorias.length };
  },
};

interface Cursor {
  d: string;
  id: string;
}

function encodeCursor(c: Cursor): string {
  return btoa(JSON.stringify(c)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function decodeCursor(raw: string): Cursor {
  try {
    const json = atob(raw.replace(/-/g, "+").replace(/_/g, "/"));
    const c = JSON.parse(json) as Cursor;
    if (typeof c.d !== "string" || typeof c.id !== "string" || !/^[0-9a-f-]{36}$/i.test(c.id)) throw new Error();
    // ISO estricto: `Date.parse` de V8 traga cosas como «2026-01-01 (x\\», que meterían sintaxis en `and=(…)`.
    if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/.test(c.d)) throw new Error();
    return c;
  } catch {
    throw new InvalidInputError("cursor no válido");
  }
}

/** Texto libre para `ilike`: solo letras, dígitos, espacios y puntuación inofensiva. Sin comodines ni sintaxis de PostgREST. */
export function sanitizeSearch(text: string): string {
  return text
    .replace(/[^\p{L}\p{M}\p{N} .'&-]/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

function quoteValue(v: string): string {
  return `"${v.replace(/["\\]/g, "")}"`;
}

function matchIds<T extends { sync_id: string; name: string | null }>(rows: Iterable<T>, needle: string): string[] {
  const n = needle.trim().toLocaleLowerCase("es");
  const all = [...rows];
  const exact = all.filter((r) => (r.name ?? "").toLocaleLowerCase("es") === n).map((r) => r.sync_id);
  if (exact.length > 0) return exact;
  return all.filter((r) => (r.name ?? "").toLocaleLowerCase("es").includes(n)).map((r) => r.sync_id);
}

function txKind(tx: TxRow, lookup: Lookup): "ajuste_de_saldo" | "transferencia" | "ingreso" | "gasto" | "sin_categoria" {
  if (tx.balance_adjustment_type) return "ajuste_de_saldo";
  if (tx.transfer_pair_id) return "transferencia";
  const c = categoryOf(lookup, tx);
  if (!c) return "sin_categoria";
  return c.is_income === true ? "ingreso" : "gasto";
}

const buscarMovimientos: ToolDef = {
  name: "buscar_movimientos",
  title: "Buscar movimientos",
  plan: "gratis",
  description:
    "Devuelve movimientos del usuario, del más reciente al más antiguo, filtrados por fechas, cuenta, categoría o texto de la nota. " +
    "Pagina de hasta 200 en 200: si hay más, la respuesta trae un cursor para la página siguiente.",
  inputSchema: {
    desde: z.string().optional().describe("Primer día incluido, AAAA-MM-DD."),
    hasta: z.string().optional().describe("Último día incluido, AAAA-MM-DD."),
    cuenta: z.string().max(80).optional().describe("Nombre de la cuenta, o parte de él."),
    categoria: z.string().max(80).optional().describe("Nombre de una categoría o subcategoría, o parte de él."),
    texto: z.string().max(80).optional().describe("Texto que aparece en la nota del movimiento."),
    limite: z.number().int().min(1).max(200).optional().describe("Cuántos movimientos devolver, de 1 a 200. Por defecto, 50."),
    cursor: z.string().max(200).optional().describe("El cursor de la respuesta anterior, para pedir la página siguiente."),
    zona_horaria: zonaHoraria,
  },
  async run(ctx, args) {
    const zone = zoneOf(ctx, args);
    const tz = zone.tz;
    const limit = typeof args.limite === "number" ? args.limite : 50;
    const params: [string, string][] = [
      ["select", COLUMNS.tx],
      NOT_DELETED,
      ["date", "not.is.null"],
      ["order", "date.desc,sync_id.desc"],
    ];
    const ands: string[] = [];
    // El día que se filtra es el mismo que se enseña (`txDay`): `local_day` si el teléfono lo mandó, y si no,
    // `date` en la zona pedida. Filtrar solo por `date` enseñaba movimientos con una fecha fuera del rango pedido.
    if (typeof args.desde === "string") {
      const d = assertDay(args.desde, "desde");
      const instant = zonedDayStartUtc(d, tz).toISOString();
      ands.push(`or(local_day.gte.${d},and(local_day.is.null,date.gte.${quoteValue(instant)}))`);
    }
    if (typeof args.hasta === "string") {
      const h = assertDay(args.hasta, "hasta");
      const instant = zonedDayStartUtc(addDays(h, 1), tz).toISOString();
      ands.push(`or(local_day.lte.${h},and(local_day.is.null,date.lt.${quoteValue(instant)}))`);
    }
    const [lookup, prefs] = await Promise.all([loadLookup(ctx), loadPrefs(ctx)]);
    const avisos: string[] = [...zoneNotice(zone)];

    if (typeof args.cuenta === "string" && args.cuenta.trim()) {
      const ids = matchIds(lookup.accounts.values(), args.cuenta);
      if (ids.length === 0) return { movimientos: [], siguiente_cursor: null, avisos: [`No hay ninguna cuenta que se llame «${args.cuenta}».`] };
      params.push(["account_ref", `in.(${ids.join(",")})`]);
    }
    if (typeof args.categoria === "string" && args.categoria.trim()) {
      const cats = matchIds(lookup.categories.values(), args.categoria);
      const subs = matchIds(lookup.subcategories.values(), args.categoria);
      if (cats.length === 0 && subs.length === 0) {
        return { movimientos: [], siguiente_cursor: null, avisos: [`No hay ninguna categoría que se llame «${args.categoria}».`] };
      }
      const ors: string[] = [];
      if (cats.length > 0) ors.push(`category_ref.in.(${cats.join(",")})`);
      if (subs.length > 0) ors.push(`subcategory_ref.in.(${subs.join(",")})`);
      ands.push(`or(${ors.join(",")})`);
    }
    if (typeof args.texto === "string") {
      const clean = sanitizeSearch(args.texto);
      if (clean) params.push(["note", `ilike.*${clean}*`]);
    }
    if (typeof args.cursor === "string" && args.cursor) {
      const c = decodeCursor(args.cursor);
      ands.push(`or(date.lt.${quoteValue(c.d)},and(date.eq.${quoteValue(c.d)},sync_id.lt.${c.id}))`);
    }
    if (ands.length > 0) params.push(["and", `(${ands.join(",")})`]);

    const rows = await ctx.reader.one<TxRow>("tx_items", params, limit + 1);
    const page = rows.slice(0, limit);
    const last = page[page.length - 1];
    const preferred = resolvePreferredCurrency(prefs, page.map((r) => r.preferred_currency_code));

    const movimientos = page.map((tx) => {
      const sub = tx.subcategory_ref ? lookup.subcategories.get(tx.subcategory_ref) : undefined;
      const inPreferred = tx.preferred_currency_code?.toUpperCase() === preferred.code ? num(tx.amount_in_preferred_currency) : null;
      return {
        id: tx.sync_id,
        fecha: txDay(tx, tz),
        importe: num(tx.amount),
        divisa: tx.currency_code,
        importe_en_divisa_preferida: inPreferred === null ? null : round2(inPreferred),
        nota: tx.note,
        tipo: txKind(tx, lookup),
        categoria: categoryOf(lookup, tx)?.name ?? null,
        subcategoria: sub?.name ?? null,
        cuenta: tx.account_ref ? (lookup.accounts.get(tx.account_ref)?.name ?? null) : null,
        etiquetas: (tx.tag_refs ?? []).map((t) => lookup.tags.get(t)?.name).filter((n): n is string => !!n),
        gasto_de_grupo: tx.split_expense_id !== null,
      };
    });
    return {
      movimientos,
      divisa_preferida: preferred.code,
      siguiente_cursor: rows.length > limit && last?.date ? encodeCursor({ d: last.date, id: last.sync_id }) : null,
      zona_horaria: tz,
      avisos,
    };
  },
};

/**
 * Movimientos con fecha de un rango de días, con un día de margen a cada lado: el día exacto lo decide `txDay`.
 * Del más reciente al más antiguo, para que si se alcanza el tope de filas se pierda lo más viejo y no lo de hoy.
 */
async function loadTxInRange(ctx: ToolContext, from: Day, to: Day, tz: string) {
  return ctx.reader.all<TxRow>("tx_items", [
    ["select", COLUMNS.tx],
    NOT_DELETED,
    ["date", `gte.${zonedDayStartUtc(addDays(from, -1), tz).toISOString()}`],
    ["date", `lt.${zonedDayStartUtc(addDays(to, 2), tz).toISOString()}`],
    ["order", "date.desc,sync_id.desc"],
  ]);
}

const resumenPeriodo: ToolDef = {
  name: "resumen_periodo",
  title: "Resumen de un periodo",
  plan: "gratis",
  description:
    "Devuelve ingresos, gastos, neto, tasa de ahorro y gasto medio diario de un periodo en la divisa preferida del usuario, " +
    "con las categorías y comercios en los que más gastó. Usa las mismas reglas que las estadísticas de la app.",
  inputSchema: {
    periodo: z
      .enum(["mes_actual", "mes_pasado", "semana_actual", "anio_actual", "rango"])
      .describe("Periodo a resumir. Con «rango» hacen falta desde y hasta."),
    desde: z.string().optional().describe("Con periodo=rango: primer día incluido, AAAA-MM-DD."),
    hasta: z.string().optional().describe("Con periodo=rango: último día incluido, AAAA-MM-DD."),
    top: z.number().int().min(1).max(20).optional().describe("Cuántas categorías y comercios listar. Por defecto, 5."),
    zona_horaria: zonaHoraria,
    primer_dia_semana: primerDiaSemana,
  },
  async run(ctx, args) {
    const zone = zoneOf(ctx, args);
    const tz = zone.tz;
    const today = dayInZone(ctx.now, tz);
    const prefs = await loadPrefs(ctx);
    const fw = firstWeekday(prefs, args);
    const kind = args.periodo as PeriodKind;
    const period = resolvePeriod(kind, today, {
      desde: args.desde as string | undefined,
      hasta: args.hasta as string | undefined,
      firstWeekday: fw,
    });
    // Tasas de los días UTC que pueden tocar los movimientos leídos (`loadTxInRange` lee un día de margen a cada lado).
    const lastKey = addDays(period.hasta, 2) > todayUtcKey(ctx) ? addDays(period.hasta, 2) : todayUtcKey(ctx);
    const [lookup, rates, txs] = await Promise.all([
      loadLookup(ctx),
      loadRates(ctx, addDays(period.desde, -2), lastKey),
      loadTxInRange(ctx, period.desde, period.hasta, tz),
    ]);
    const groups = await loadGroupAdjustment(ctx, txs.rows, lookup);
    const preferred = resolvePreferredCurrency(prefs, txs.rows.map((t) => t.preferred_currency_code));
    const result = summarize(txs.rows, lookup, period, {
      today,
      tz,
      preferredCurrency: preferred.code,
      rates,
      groups,
      top: typeof args.top === "number" ? args.top : 5,
    });
    result.avisos.push(...truncationNotice(txs.truncated), ...zoneNotice(zone));
    if (preferred.inferred) result.avisos.push(`No hay divisa preferida guardada; se usa ${preferred.code}.`);
    return result;
  },
};

const estadoPresupuestos: ToolDef = {
  name: "estado_presupuestos",
  title: "Estado de los presupuestos",
  plan: "gratis",
  description:
    "Devuelve cada presupuesto del usuario en su periodo actual: límite, gastado, porcentaje, lo que queda, días restantes " +
    "y si va en camino, en riesgo (75 % o más) o excedido.",
  inputSchema: {
    solo_activos: z.boolean().optional().describe("Solo los presupuestos activos. Por defecto, sí."),
    zona_horaria: zonaHoraria,
    primer_dia_semana: primerDiaSemana,
  },
  async run(ctx, args) {
    const zone = zoneOf(ctx, args);
    const tz = zone.tz;
    const today = dayInZone(ctx.now, tz);
    const todayUtc = todayUtcKey(ctx);
    const [budgets, lookup, rates, prefs] = await Promise.all([
      ctx.reader.all<BudgetRow>("budgets", [["select", COLUMNS.budgets], NOT_DELETED, ORDER_ID]),
      loadLookup(ctx),
      loadRates(ctx, todayUtc),
      loadPrefs(ctx),
    ]);
    const fw = firstWeekday(prefs, args);
    const soloActivos = args.solo_activos !== false;
    // Se leen solo los días que cubren los presupuestos que se van a enseñar: un «único» inactivo de hace años no
    // arrastra años de movimientos. La pantalla de Presupuestos cuenta también lo futuro, así que `hasta` llega al
    // final de cada periodo, no a hoy.
    const shown = budgets.rows.filter((b) => !soloActivos || isBudgetActive(b));
    let from: Day | null = null;
    let to: Day | null = null;
    for (const b of shown) {
      const p = budgetPeriod(b, today, tz, fw);
      if (!from || p.desde < from) from = p.desde;
      if (!to || p.hasta > to) to = p.hasta;
    }
    const txs = from && to ? await loadTxInRange(ctx, from, to, tz) : { rows: [] as TxRow[], truncated: false };
    const groups = await loadGroupAdjustment(ctx, txs.rows, lookup);
    const result = budgetStatuses(budgets.rows, txs.rows, lookup, { today, todayUtc, tz, rates, groups, firstWeekday: fw, soloActivos });
    return {
      ...result,
      zona_horaria: tz,
      avisos: [...result.avisos, ...truncationNotice(txs.truncated || budgets.truncated), ...zoneNotice(zone)],
    };
  },
};

const listarRecurrentes: ToolDef = {
  name: "listar_recurrentes",
  title: "Pagos recurrentes",
  plan: "gratis",
  description:
    "Devuelve los pagos recurrentes y programados del usuario con su importe, frecuencia, próximo cobro, último movimiento " +
    "enlazado y equivalente mensual y anual, más los totales de suscripciones y recurrentes. Marca los que conviene revisar: " +
    "sin movimientos recientes enlazados o con la fecha de cobro ya pasada.",
  inputSchema: {
    solo_activos: z.boolean().optional().describe("Solo los pagos activos. Por defecto, sí."),
    zona_horaria: zonaHoraria,
  },
  async run(ctx, args) {
    const zone = zoneOf(ctx, args);
    const tz = zone.tz;
    const today = dayInZone(ctx.now, tz);
    const todayUtc = todayUtcKey(ctx);
    const [payments, lookup, rates, prefs, linked] = await Promise.all([
      ctx.reader.all<ScheduledPaymentRow>("scheduled_payments", [["select", COLUMNS.scheduled], NOT_DELETED, ORDER_ID]),
      loadLookup(ctx),
      loadRates(ctx, todayUtc),
      loadPrefs(ctx),
      ctx.reader.all<Pick<TxRow, "scheduled_payment_ref" | "date" | "local_day">>("tx_items", [
        ["select", "scheduled_payment_ref,date,local_day"],
        NOT_DELETED,
        ["scheduled_payment_ref", "not.is.null"],
        ORDER_ID,
      ]),
    ]);
    const lastLinked = new Map<string, Day>();
    for (const t of linked.rows) {
      const day = txDay(t, tz);
      if (!t.scheduled_payment_ref || !day || day > today) continue;
      const prev = lastLinked.get(t.scheduled_payment_ref);
      if (!prev || day > prev) lastLinked.set(t.scheduled_payment_ref, day);
    }
    const preferred = resolvePreferredCurrency(prefs, payments.rows.map((p) => p.currency_code));
    const result = listRecurring(payments.rows, lastLinked, lookup, {
      today,
      todayUtc,
      tz,
      preferredCurrency: preferred.code,
      rates,
      soloActivos: args.solo_activos !== false,
    });
    result.avisos.push(...truncationNotice(payments.truncated || linked.truncated), ...zoneNotice(zone));
    return result;
  },
};

export const TOOLS: ToolDef[] = [listarCuentas, listarCategorias, buscarMovimientos, resumenPeriodo, estadoPresupuestos, listarRecurrentes];

/**
 * Punto de extensión Pro. Hoy no se consulta ningún entitlement: la decisión es gratis por defecto. Cuando una
 * herramienta pase a "pro", aquí se leerá el entitlement del usuario (el gateway ya lo verifica para la IA de la app).
 */
export function planAllows(plan: Plan, entitlement: { pro: boolean }): boolean {
  return plan === "gratis" || entitlement.pro;
}
