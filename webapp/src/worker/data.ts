/**
 * Lo que la web lee de la nube, siempre con el token de SOLO LECTURA de la sesión (rol `yala_mcp_reader`).
 *
 * Los cálculos son los del núcleo compartido tal cual (`shared-core/src/toolCore.ts`): los mismos que usan el conector
 * de Claude y Yala IA, con paridad contra Swift (decisión R1). La web no suma filas por su cuenta: si lo hiciera, sus
 * cifras acabarían sin cuadrar con las del iPhone (divisas, reembolsos, ajustes de grupos).
 *
 * La única lectura propia es la Bandeja (`inbox_drafts`), que no tiene cálculo: se enseña lo que hay.
 */
import { NOT_DELETED, YalaReader } from "../../../shared-core/src/data";
import { InvalidInputError } from "../../../shared-core/src/logic/dates";
import { TOOL_CORES, type ToolContext, type ToolCore } from "../../../shared-core/src/toolCore";
import { estadisticas as statsCore, pagos as paymentsCore } from "../../../shared-core/src/webCore";
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

export function toolContext(env: Env, fetcher: Fetcher, access: string, now: Date): ToolContext {
  const reader = new YalaReader(env, access, fetcher, WEB_MAX_ROWS);
  return { reader, env, now };
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

/** Registros, del más reciente al más antiguo, de 50 en 50. Los filtros los entiende `buscar_movimientos`. */
export async function registros(ctx: ToolContext, q: URLSearchParams) {
  const args: Record<string, unknown> = { limite: 50 };
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

/** Pagos planificados (lote 2): próximos cobros de 30 días y suscripciones. */
export async function pagos(ctx: ToolContext) {
  return paymentsCore(ctx);
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
