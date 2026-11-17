/**
 * Lo que la web lee de la nube, siempre con el token de SOLO LECTURA de la sesión (rol `yala_mcp_reader`).
 *
 * Los cálculos son los del núcleo compartido tal cual (`shared-core/src/toolCore.ts`): los mismos que usan el conector
 * de Claude y Yala IA, con paridad contra Swift (decisión R1). La web no suma filas por su cuenta: si lo hiciera, sus
 * cifras acabarían sin cuadrar con las del iPhone (divisas, reembolsos, ajustes de grupos).
 *
 * Lecturas propias: la Bandeja (`inbox_drafts`), que no tiene cálculo (se enseña lo que hay), y los movimientos
 * enlazados a un pago, para marcar «Ya pagado» con la regla del iPhone (`paid.ts`).
 */
import { NOT_DELETED, YalaReader } from "../../../shared-core/src/data";
import { COLUMNS } from "../../../shared-core/src/data";
import { addDays, addMonths, dayInZone, InvalidInputError, monthStart, zonedDayStartUtc } from "../../../shared-core/src/logic/dates";
import { skipKey, skippedKeys, upcomingPayments, type ScheduleRow } from "../../../shared-core/src/logic/schedule";
import {
  firstWeekday,
  loadLookup,
  loadPrefs,
  loadRates,
  resolvePreferredCurrency,
  todayUtcKey,
  TOOL_CORES,
  zoneOf,
  type ToolContext,
  type ToolCore,
} from "../../../shared-core/src/toolCore";
import { estadisticas as statsCore, UPCOMING_DAYS } from "../../../shared-core/src/webCore";
import { chargeKey, paidCharges, type LinkedTx } from "./paid";
import type { Env } from "./env";
import type { Fetcher } from "./egress";

export { InvalidInputError };

/** Tope de filas por consulta para la web: responde mientras alguien mira la pantalla. */
const WEB_MAX_ROWS = 10_000;

function core(name: string): ToolCore {
  const c = TOOL_CORES.find((t) => t.name === name);
  if (!c) throw new Error(`shared-core: falta ${name}`);
  return c;
}

/**
 * `apariencia`: la web pide además el ícono y el color de cuentas, categorías y subcategorías, y la necesidad de cada
 * registro (lote 2 de «Yala web como la app»). Es la única diferencia con el contexto del conector y del gateway.
 */
export function toolContext(env: Env, fetcher: Fetcher, access: string, now: Date): ToolContext {
  const reader = new YalaReader(env, access, fetcher, WEB_MAX_ROWS);
  return { reader, env, now, apariencia: true };
}

/** El Panel: saldos de hoy, entradas y salidas del mes y los últimos cinco registros. */
export async function panel(ctx: ToolContext) {
  const [cuentas, mes, ultimos] = await Promise.all([
    core("listar_cuentas").run(ctx, {}),
    core("resumen_periodo").run(ctx, { periodo: "mes_actual", top: 5 }),
    core("buscar_movimientos").run(ctx, { limite: 5 }),
  ]);
  return { cuentas, mes, ultimos };
}

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Registros, del más reciente al más antiguo, de 50 en 50. Los filtros los entiende `buscar_movimientos`. Exportar a CSV
 * (lote 2b) pide páginas de 200 (`limite=200`), el tope del núcleo; cualquier otro valor se queda en 50.
 */
export async function registros(ctx: ToolContext, q: URLSearchParams) {
  const args: Record<string, unknown> = { limite: q.get("limite") === "200" ? 200 : 50 };
  for (const k of ["desde", "hasta"] as const) {
    const v = q.get(k);
    if (v) {
      if (!DAY_RE.test(v)) throw new InvalidInputError(`${k} no es una fecha`);
      args[k] = v;
    }
  }
  for (const k of ["cuenta", "categoria", "texto", "cursor"] as const) {
    const v = q.get(k);
    if (v && v.length <= 200) args[k] = v;
  }
  return core("buscar_movimientos").run(ctx, args);
}

/** Estadísticas (lote 2): Resumen, Distribución y Tendencias de un período (`mes_actual`, `mes_pasado`, `anio_actual`). */
export async function estadisticas(ctx: ToolContext, q: URLSearchParams) {
  return statsCore(ctx, { periodo: q.get("periodo") ?? undefined });
}

/**
 * Pagos planificados (lote 2): próximos cobros de 30 días y suscripciones. Lote 2b: cada cobro dice si ya está pagado
 * (`pagado`, regla del iPhone en `paid.ts`), y «Por pagar» (`total_gastos`) deja fuera lo pagado. `pagados` cuenta los
 * cobros marcados de la lista.
 *
 * Es `webCore.pagos` con una sola lectura de `scheduled_payments` compartida por la lista y las marcas (dos lecturas
 * podían ver filas distintas si entraba un cambio entre una y otra). «Por pagar» se calcula con el mismo `upcomingPayments`
 * dando lo pagado por saltado: así redondea una sola vez, como antes (restar importes ya redondeados podía mover un
 * céntimo).
 */
export async function pagos(ctx: ToolContext) {
  const prefsP = loadPrefs(ctx);
  prefsP.catch(() => undefined);
  const zone = await zoneOf(ctx, {}, prefsP);
  const tz = zone.tz;
  const today = dayInZone(ctx.now, tz);
  const todayUtc = todayUtcKey(ctx);
  const until = addDays(today, UPCOMING_DAYS - 1);
  const months: string[] = [];
  for (let mo = monthStart(today); mo <= until; mo = addMonths(mo, 1)) months.push(mo);
  const from = zonedDayStartUtc(addDays(months[0]!, -1), tz).toISOString();
  const to = zonedDayStartUtc(addDays(addMonths(months[months.length - 1]!, 1), 1), tz).toISOString();
  const [payments, linked, lookup, rates, prefs] = await Promise.all([
    ctx.reader.all<ScheduleRow>("scheduled_payments", [["select", COLUMNS.scheduledCalendar], NOT_DELETED, ["order", "sync_id.asc"]]),
    // Un día de margen a cada lado: el día exacto lo decide `txDay` (con `local_day` si el teléfono lo mandó).
    ctx.reader.all<LinkedTx>("tx_items", [
      ["select", "scheduled_payment_ref,date,local_day"],
      NOT_DELETED,
      ["scheduled_payment_ref", "not.is.null"],
      ["and", `(date.gte."${from}",date.lt."${to}")`],
      ["order", "sync_id.asc"],
    ]),
    loadLookup(ctx),
    loadRates(ctx, todayUtc),
    prefsP,
  ]);
  const fw = firstWeekday(prefs, {});
  const preferred = resolvePreferredCurrency(prefs, payments.rows.map((p) => p.currency_code));
  const sctx = { today, todayUtc, tz, preferredCurrency: preferred.code, rates, days: UPCOMING_DAYS, firstWeekday: fw };
  const base = upcomingPayments(payments.rows, lookup, sctx);
  const paid = paidCharges(payments.rows, linked.rows, months, tz, fw);

  // Lo pagado, como si estuviera saltado: lo que queda es «Por pagar».
  const paidDays = new Map<string, string[]>();
  for (const key of paid) {
    const [id, day] = key.split("|") as [string, string];
    paidDays.set(id, [...(paidDays.get(id) ?? []), skipKey(day, tz)]);
  }
  const pendingRows = payments.rows.map((p) => {
    const extra = paidDays.get(p.sync_id.toLowerCase());
    return extra ? { ...p, skipped_dates_raw: [...skippedKeys(p), ...extra] } : p;
  });
  const pending = upcomingPayments(pendingRows, lookup, sctx);

  const proximos = base.proximos.map((c) => ({ ...c, pagado: paid.has(chargeKey(c.id, c.dia)) }));
  return {
    zona_horaria: tz,
    ...base,
    proximos,
    total_gastos: pending.total_gastos,
    pagados: proximos.filter((c) => c.pagado).length,
    incompleto: payments.truncated || linked.truncated,
  };
}

/** Presupuestos (lote 2b): todos, activos e inactivos, en su período actual, con `estado_presupuestos` tal cual. */
export async function presupuestos(ctx: ToolContext) {
  return core("estado_presupuestos").run(ctx, { solo_activos: false });
}

export async function categorias(ctx: ToolContext) {
  return core("listar_categorias").run(ctx, {});
}

export interface InboxRow {
  sync_id: string;
  note: string | null;
  amount: number | string | null;
  date: string | null;
  cached_currency_code: string | null;
  cached_account_name: string | null;
  cached_subcategory_name: string | null;
  source_type_raw: string | null;
  evidence: string | null;
  created_at: string | null;
  needs_user_input: string[] | null;
}

const INBOX_COLUMNS =
  "sync_id,note,amount,date,cached_currency_code,cached_account_name,cached_subcategory_name,source_type_raw,evidence,created_at,needs_user_input";

/** Los borradores pendientes de la Bandeja del iPhone (los que ya recogió y aún no confirmó ni descartó). */
export async function bandeja(ctx: ToolContext): Promise<InboxRow[]> {
  return ctx.reader.one<InboxRow>(
    "inbox_drafts",
    [["select", INBOX_COLUMNS], NOT_DELETED, ["status_raw", "eq.pending"], ["order", "created_at.desc,sync_id.asc"]],
    200,
  );
}
