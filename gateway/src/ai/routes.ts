import type { TaskId } from "./tasks";

/**
 * TABLA ÚNICA tarea → { proveedor, modelo, parámetros }.
 *
 * Cambiar el modelo de una tarea = editar su fila + `npm test` + deploy del Worker. Ninguna release.
 * La elección de cada fila sale del banco de calidad (`gateway/bench/`, informe en
 * `docs/ai-model-bench-2026-10.md`): primero calidad medida, después precio.
 *
 * Dos modos:
 * - `passthrough`: el cuerpo de la app sale BYTE A BYTE a OpenAI, como antes de la tabla. Solo se
 *   acepta el modelo de `allowedModels` (el que la app escribe hoy). Es el modo de las 9 llamadas que no
 *   usaban gpt-4.1-nano, hasta que la sesión 2 las pase por el banco.
 * - `managed`: el gateway decide proveedor, modelo y parámetros; de la app solo usa los mensajes.
 *
 * Proveedor sin cabecera de tarea = solo OpenAI (Paso 0, D6): las versiones instaladas dicen al usuario
 * que la foto «se envía a OpenAI». `routeFor()` lo hace cumplir y un test lo fija.
 */

export type ProviderId = "openai" | "gemini" | "anthropic" | "workersai" | "xai";

export type ReasoningEffort = "none" | "minimal" | "low" | "medium" | "high";

export type ImageDetail = "low" | "high" | "auto";

export interface ImageParams {
  /** `detail` que se manda al proveedor (OpenAI: `image_url.detail`; Gemini: media resolution). */
  readonly detail: ImageDetail;
  /**
   * Lado mayor, en px, que el modelo elegido aprovecha. El gateway NO reescala (Paso 0, D7): es el
   * contrato para que la app reduzca la foto antes de subirla (sesión 2). `null` = sin límite propio.
   */
  readonly maxEdge: number | null;
}

export interface ChatParams {
  /** `undefined` = no se manda (default del proveedor). Los modelos de razonamiento la rechazan. */
  readonly temperature?: number;
  /** `undefined` = no se manda. Solo modelos de razonamiento. */
  readonly reasoningEffort?: ReasoningEffort;
  /** Tope de salida (`max_completion_tokens` / `maxOutputTokens` / `max_tokens`). */
  readonly maxOutputTokens?: number;
  readonly responseFormat: "json_object" | "text";
  /**
   * Esquema de la respuesta, para proveedores sin modo JSON libre (Anthropic) o si se quiere estricto.
   * Con OpenAI solo se usa si `strictSchema` es true; si no, `json_object` como hoy.
   */
  readonly jsonSchema?: { readonly name: string; readonly schema: Record<string, unknown> };
  readonly strictSchema?: boolean;
  readonly image?: ImageParams;
}

export interface ManagedRoute {
  readonly mode: "managed";
  readonly provider: ProviderId;
  readonly model: string;
  readonly params: ChatParams;
  /** Reintentos ante red/429/5xx. 0 en las tres tareas: con 8 s de presupuesto, reintentar es timeout. */
  readonly retries: number;
}

export interface PassthroughRoute {
  readonly mode: "passthrough";
  readonly allowedModels: readonly string[];
}

export type Route = ManagedRoute | PassthroughRoute;

const PASS_MINI: PassthroughRoute = { mode: "passthrough", allowedModels: ["gpt-4.1-mini"] };

// Esquemas de las tres tareas = lo que parsea la app (ver bench/tasks/*.ts, que replica los parsers).
const PHOTO_SCHEMA = {
  name: "photo_read",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["imageType", "transactions", "confidence"],
    properties: {
      imageType: { type: "string", enum: ["single", "list", "receipt", "unknown"] },
      transactions: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["amount", "date", "merchant", "note", "currency"],
          properties: {
            amount: { type: ["number", "null"] },
            date: { type: ["string", "null"] },
            merchant: { type: ["string", "null"] },
            note: { type: ["string", "null"] },
            currency: { type: ["string", "null"] },
          },
        },
      },
      confidence: {
        type: "object",
        additionalProperties: false,
        required: ["overall", "imageType"],
        properties: { overall: { type: "number" }, imageType: { type: "number" } },
      },
    },
  },
} as const;

const INTENT_SCHEMA = {
  name: "chat_intent",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["intent", "confidence"],
    properties: {
      intent: { type: "string", enum: ["ask", "register", "ambiguous"] },
      confidence: { type: "number" },
    },
  },
} as const;

const SUGGESTIONS_SCHEMA = {
  name: "chat_suggestions",
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["suggestions"],
    properties: {
      suggestions: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["text", "icon"],
          properties: { text: { type: "string" }, icon: { type: "string" } },
        },
      },
    },
  },
} as const;

export const TASK_SCHEMAS = {
  "photo.read": PHOTO_SCHEMA,
  "chat.intent": INTENT_SCHEMA,
  "chat.suggestions": SUGGESTIONS_SCHEMA,
} as const;

/**
 * Las filas. Las tres primeras las decide el banco del 2026-10 (ver el informe para el porqué de cada
 * una); el resto sale como hoy.
 */
export const ROUTES: Readonly<Record<TaskId, Route>> = {
  // Banco del 2026-10-07 (docs/ai-model-bench-2026-10.md): 96 % estricto / 100 % en importe, fecha y número
  // de movimientos (dos pasadas, 26 fotos), frente al 42 % de gpt-4.1-nano. Lo que falla es la divisa de ¥ y zł,
  // que el prompt de la app no enseña. 0,53 USD por 1 000 fotos a resolución original; p95 6,7 s.
  // `maxEdge` 1536: la calidad es plana de 768 px al original; 1536 deja margen para papel gastado con un 38 %
  // menos de tokens. Hoy la app manda la original (el gateway no reescala); la sesión 2 la reduce.
  "photo.read": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: {
      reasoningEffort: "low",
      responseFormat: "json_object",
      jsonSchema: PHOTO_SCHEMA,
      image: { detail: "high", maxEdge: 1536 },
    },
    retries: 0,
  },
  // 100 % en 115 frases de 12 locales (y 100 % en la repetición); p95 2,0 s contra el corte de 8 s de la app;
  // 0,073 USD por 1 000, lo mismo que nano. Modelo de razonamiento: sin temperatura (no la admite).
  "chat.intent": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "none", responseFormat: "json_object", jsonSchema: INTENT_SCHEMA },
    retries: 0,
  },
  // 100 % en 16 contextos de 12 idiomas, dos pasadas (nano: 96,9 %); p95 4,2 s contra el corte de 8 s;
  // 0,19 USD por 1 000.
  "chat.suggestions": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "none", responseFormat: "json_object", jsonSchema: SUGGESTIONS_SCHEMA },
    retries: 0,
  },

  "chat.answer": PASS_MINI,
  "chat.rewrite": PASS_MINI,
  "text.parse": PASS_MINI,
  "voice.transcribe": { mode: "passthrough", allowedModels: ["whisper-1"] },
  "insights.cards": PASS_MINI,
  "insights.cashflow": PASS_MINI,
  "insights.deviation": PASS_MINI,
  "insights.contextual": PASS_MINI,
  "trends.summary": PASS_MINI,
  "insights.hero": PASS_MINI,
  "legacy.passthrough": PASS_MINI,
};

/**
 * Filas que sustituyen a las de `ROUTES` cuando la petición llega SIN cabecera de tarea (versiones
 * instaladas). Vacío mientras todas las filas managed sean de OpenAI. Si la sesión 2 pone otro proveedor
 * en una tarea, aquí va el mejor de OpenAI para esa tarea: esas versiones prometen OpenAI en su texto.
 */
export const LEGACY_OVERRIDES: Readonly<Partial<Record<TaskId, ManagedRoute>>> = {};

export function routeFor(task: TaskId, viaHeader: boolean, table: Readonly<Record<TaskId, Route>> = ROUTES,
  legacy: Readonly<Partial<Record<TaskId, ManagedRoute>>> = LEGACY_OVERRIDES): Route {
  const route = viaHeader ? table[task] : (legacy[task] ?? table[task]);
  if (!viaHeader && route.mode === "managed" && route.provider !== "openai") {
    // Defensa en profundidad: la tabla está mal y una versión que promete OpenAI saldría a otro sitio.
    throw new Error(`routeFor: ${task} sin cabecera resuelve a ${route.provider}; falta su LEGACY_OVERRIDE de OpenAI`);
  }
  return route;
}
