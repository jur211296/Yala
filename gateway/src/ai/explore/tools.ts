import { TOOL_CORES, type ToolCore } from "../../../../mcp/src/toolCore";
import { InvalidInputError } from "../../../../mcp/src/logic/dates";

/**
 * Las herramientas que el camino ampliado de Yala IA ofrece al modelo: las seis lecturas del conector MCP
 * (`mcp/src/toolCore.ts`), con su esquema en JSON Schema para Chat Completions.
 *
 * Dos diferencias con el conector, a propósito:
 * - **Sin `zona_horaria`**: la manda la app en `X-Yala-Time-Zone` y la pone el gateway en cada llamada
 *   (`exploreArgs`). Que la eligiera el modelo podía mover el borde de un mes.
 * - **`limite` de `buscar_movimientos` hasta 50, no 200**: cada movimiento son tokens de entrada que paga cada
 *   pregunta. Con más, el modelo pide la página siguiente con el cursor.
 *
 * El resto de campos tiene que casar con el `zod` del conector: lo comprueba `mcp/test/toolSchemas.test.ts`.
 */

export interface ExploreToolSpec {
  readonly name: string;
  /** JSON Schema del objeto de argumentos. */
  readonly parameters: Record<string, unknown>;
  /** La herramienta acepta `zona_horaria` en el conector: el gateway la rellena. */
  readonly takesTimeZone: boolean;
}

/** Tope de `limite` en `buscar_movimientos` para el camino ampliado. */
export const EXPLORE_MAX_MOVEMENTS = 50;

const DAY = { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" } as const;
const PRIMER_DIA_SEMANA = {
  type: "string",
  enum: ["lunes", "domingo"],
  description: "Día en que empieza la semana del usuario, si lo sabes. Si no, se usa el que eligió en la app. Solo afecta a periodos y presupuestos semanales.",
} as const;

function object(properties: Record<string, unknown>, required: string[] = []): Record<string, unknown> {
  return { type: "object", additionalProperties: false, properties, ...(required.length ? { required } : {}) };
}

export const EXPLORE_TOOL_SPECS: readonly ExploreToolSpec[] = [
  {
    name: "listar_cuentas",
    takesTimeZone: false,
    parameters: object({
      incluir_archivadas: { type: "boolean", description: "Incluir las cuentas archivadas. Por defecto, no." },
    }),
  },
  {
    name: "listar_categorias",
    takesTimeZone: false,
    parameters: object({
      incluir_ocultas: { type: "boolean", description: "Incluir categorías y subcategorías ocultas. Por defecto, no." },
    }),
  },
  {
    name: "buscar_movimientos",
    takesTimeZone: true,
    parameters: object({
      desde: { ...DAY, description: "Primer día incluido, AAAA-MM-DD." },
      hasta: { ...DAY, description: "Último día incluido, AAAA-MM-DD." },
      cuenta: { type: "string", maxLength: 80, description: "Nombre de la cuenta, o parte de él." },
      categoria: { type: "string", maxLength: 80, description: "Nombre de una categoría o subcategoría, o parte de él." },
      texto: { type: "string", maxLength: 80, description: "Texto que aparece en la nota del movimiento." },
      limite: {
        type: "integer",
        minimum: 1,
        maximum: EXPLORE_MAX_MOVEMENTS,
        description: `Cuántos movimientos devolver, de 1 a ${EXPLORE_MAX_MOVEMENTS}. Por defecto, 20.`,
      },
      cursor: { type: "string", maxLength: 200, description: "El cursor de la respuesta anterior, para pedir la página siguiente." },
    }),
  },
  {
    name: "resumen_periodo",
    takesTimeZone: true,
    parameters: object(
      {
        periodo: {
          type: "string",
          enum: ["mes_actual", "mes_pasado", "semana_actual", "anio_actual", "rango"],
          description: "Periodo a resumir. Con «rango» hacen falta desde y hasta.",
        },
        desde: { ...DAY, description: "Con periodo=rango: primer día incluido, AAAA-MM-DD." },
        hasta: { ...DAY, description: "Con periodo=rango: último día incluido, AAAA-MM-DD." },
        top: { type: "integer", minimum: 1, maximum: 20, description: "Cuántas categorías y comercios listar. Por defecto, 5." },
        primer_dia_semana: PRIMER_DIA_SEMANA,
      },
      ["periodo"],
    ),
  },
  {
    name: "estado_presupuestos",
    takesTimeZone: true,
    parameters: object({
      solo_activos: { type: "boolean", description: "Solo los presupuestos activos. Por defecto, sí." },
      primer_dia_semana: PRIMER_DIA_SEMANA,
    }),
  },
  {
    name: "listar_recurrentes",
    takesTimeZone: true,
    parameters: object({
      solo_activos: { type: "boolean", description: "Solo los pagos activos. Por defecto, sí." },
    }),
  },
];

/** Por defecto, `buscar_movimientos` devuelve 20 (el conector, 50): menos tokens si el modelo no pide más. */
export const EXPLORE_DEFAULT_MOVEMENTS = 20;

export interface ExploreTool {
  readonly spec: ExploreToolSpec;
  readonly core: ToolCore;
}

function coreFor(name: string): ToolCore {
  const core = TOOL_CORES.find((c) => c.name === name);
  if (!core) throw new Error(`explore/tools: el conector no tiene la herramienta ${name}`);
  return core;
}

/** Herramienta + núcleo, por nombre. Falla al cargar el módulo si el conector renombra una. */
export const EXPLORE_TOOLS: ReadonlyMap<string, ExploreTool> = new Map(
  EXPLORE_TOOL_SPECS.map((spec) => [spec.name, { spec, core: coreFor(spec.name) }]),
);

/** `tools` de Chat Completions. Sin `strict`: los argumentos los valida cada herramienta (fechas, cursor, nombres). */
export function openAIToolDefinitions(): Record<string, unknown>[] {
  return EXPLORE_TOOL_SPECS.map((spec) => ({
    type: "function",
    function: { name: spec.name, description: EXPLORE_TOOLS.get(spec.name)?.core.description ?? "", parameters: spec.parameters },
  }));
}

/**
 * Los argumentos que llegan a la herramienta: solo los campos declarados, `limite` acotado y la zona horaria del
 * teléfono (nunca la del modelo). Sin `strict`, OpenAI no garantiza el esquema: aquí se valida lo que en el conector
 * valida `zod` (tipo, enum, enteros con rango, longitud y obligatorios). Lo que no casa lanza `InvalidInputError`, que el
 * bucle le explica al modelo para que lo corrija.
 */
export function exploreArgs(spec: ExploreToolSpec, raw: unknown, timeZone: string): Record<string, unknown> {
  const props = (spec.parameters.properties ?? {}) as Record<string, JsonProp>;
  const input = raw && typeof raw === "object" && !Array.isArray(raw) ? (raw as Record<string, unknown>) : {};
  const out: Record<string, unknown> = {};
  for (const key of Object.keys(props)) if (input[key] !== undefined && input[key] !== null) out[key] = input[key];
  if (spec.name === "buscar_movimientos") {
    const n = typeof out.limite === "number" && Number.isFinite(out.limite) ? Math.trunc(out.limite) : EXPLORE_DEFAULT_MOVEMENTS;
    out.limite = Math.min(EXPLORE_MAX_MOVEMENTS, Math.max(1, n));
  }
  for (const key of (spec.parameters.required ?? []) as string[]) {
    if (out[key] === undefined) throw new InvalidInputError(`Falta ${key}.`);
  }
  for (const [key, value] of Object.entries(out)) checkValue(key, value, props[key]);
  if (spec.takesTimeZone) out.zona_horaria = timeZone;
  return out;
}

interface JsonProp {
  type?: string;
  enum?: readonly string[];
  minimum?: number;
  maximum?: number;
  maxLength?: number;
  pattern?: string;
}

function checkValue(key: string, value: unknown, prop: JsonProp | undefined): void {
  if (!prop) return;
  const bad = (why: string) => new InvalidInputError(`${key}: ${why}.`);
  switch (prop.type) {
    case "boolean":
      if (typeof value !== "boolean") throw bad("tiene que ser true o false");
      return;
    case "integer":
      if (typeof value !== "number" || !Number.isInteger(value)) throw bad("tiene que ser un número entero");
      if (prop.minimum !== undefined && value < prop.minimum) throw bad(`como mínimo ${prop.minimum}`);
      if (prop.maximum !== undefined && value > prop.maximum) throw bad(`como máximo ${prop.maximum}`);
      return;
    case "string":
      if (typeof value !== "string") throw bad("tiene que ser texto");
      if (prop.enum && !prop.enum.includes(value)) throw bad(`uno de ${prop.enum.join(", ")}`);
      if (prop.maxLength !== undefined && value.length > prop.maxLength) throw bad(`como mucho ${prop.maxLength} caracteres`);
      if (prop.pattern && !new RegExp(prop.pattern).test(value)) throw bad("formato AAAA-MM-DD");
      return;
  }
}
