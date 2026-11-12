/**
 * Las seis herramientas de lectura de la fase 0 (docs/exploracion/plugin-claude-mcp.md §1), tal como las ve el SDK de
 * MCP: el núcleo (qué leen y qué calculan) vive en `toolCore.ts`, que comparte el gateway; aquí se les pone el esquema
 * de entrada de `zod`.
 *
 * Reglas de diseño que vienen de los criterios de revisión de Anthropic y no se relajan:
 * - Nombre ≤ 64 caracteres, `title` y `readOnlyHint: true` en todas.
 * - Las descripciones dicen qué devuelve la herramienta; no dan instrucciones a Claude.
 *
 * El gateway no usa estos esquemas: declara los suyos en JSON Schema (`gateway/src/ai/explore/tools.ts`), y
 * `test/toolSchemas.test.ts` comprueba que casan con estos campo a campo.
 */
import { z } from "zod";
import { TOOL_CORES, type ToolCore } from "./toolCore";

export {
  planAllows,
  resolvePreferredCurrency,
  sanitizeSearch,
  TOOL_CORES,
  type Plan,
  type ToolContext,
  type ToolCore,
  type ToolEnv,
} from "./toolCore";

export interface ToolDef extends ToolCore {
  inputSchema: z.ZodRawShape;
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

/** El esquema de entrada de cada herramienta, por nombre. */
export const INPUT_SCHEMAS: Record<string, z.ZodRawShape> = {
  listar_cuentas: {
      incluir_archivadas: z.boolean().optional().describe("Incluir las cuentas archivadas. Por defecto, no."),
  },
  listar_categorias: {
      incluir_ocultas: z.boolean().optional().describe("Incluir categorías y subcategorías ocultas. Por defecto, no."),
  },
  buscar_movimientos: {
      desde: z.string().optional().describe("Primer día incluido, AAAA-MM-DD."),
      hasta: z.string().optional().describe("Último día incluido, AAAA-MM-DD."),
      cuenta: z.string().max(80).optional().describe("Nombre de la cuenta, o parte de él."),
      categoria: z.string().max(80).optional().describe("Nombre de una categoría o subcategoría, o parte de él."),
      texto: z.string().max(80).optional().describe("Texto que aparece en la nota del movimiento."),
      limite: z.number().int().min(1).max(200).optional().describe("Cuántos movimientos devolver, de 1 a 200. Por defecto, 50."),
      cursor: z.string().max(200).optional().describe("El cursor de la respuesta anterior, para pedir la página siguiente."),
      zona_horaria: zonaHoraria,
  },
  resumen_periodo: {
      periodo: z
        .enum(["mes_actual", "mes_pasado", "semana_actual", "anio_actual", "rango"])
        .describe("Periodo a resumir. Con «rango» hacen falta desde y hasta."),
      desde: z.string().optional().describe("Con periodo=rango: primer día incluido, AAAA-MM-DD."),
      hasta: z.string().optional().describe("Con periodo=rango: último día incluido, AAAA-MM-DD."),
      top: z.number().int().min(1).max(20).optional().describe("Cuántas categorías y comercios listar. Por defecto, 5."),
      zona_horaria: zonaHoraria,
      primer_dia_semana: primerDiaSemana,
  },
  estado_presupuestos: {
      solo_activos: z.boolean().optional().describe("Solo los presupuestos activos. Por defecto, sí."),
      zona_horaria: zonaHoraria,
      primer_dia_semana: primerDiaSemana,
  },
  listar_recurrentes: {
      solo_activos: z.boolean().optional().describe("Solo los pagos activos. Por defecto, sí."),
      zona_horaria: zonaHoraria,
  },
};

export const TOOLS: ToolDef[] = TOOL_CORES.map((core) => {
  const inputSchema = INPUT_SCHEMAS[core.name];
  if (!inputSchema) throw new Error(`tools.ts: ${core.name} no tiene esquema de entrada`);
  return { ...core, inputSchema };
});
