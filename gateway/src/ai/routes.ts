import { CHAT_REWRITE_SCHEMA } from "./schemas";
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
 *   acepta el modelo de `allowedModels` (el que la app escribe hoy). Desde la sesión 2 solo lo usan lo que
 *   mandan versiones viejas sin huella reconocible (`insights.hero`, `legacy.passthrough`).
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

/** Parámetros de una transcripción gestionada (`voice.transcribe`, sesión 2). */
export interface TranscriptionParams {
  /** Cómo se pasa el idioma que elige la app: `languages[]` (gpt-transcribe) o `language` (whisper-1). */
  readonly languageField: "languages" | "language";
  /**
   * Cuántos términos del usuario (comercios y subcategorías que la app manda en `prompt`, uno por línea) se pasan como
   * `keywords[]`. 0 = ninguno (el modelo no los admite o el banco no los justifica).
   */
  readonly maxKeywords: number;
  /** Contexto fijo para el modelo (no lo manda la app). */
  readonly prompt?: string;
}

export interface TranscriptionRoute {
  readonly mode: "transcription";
  readonly provider: ProviderId;
  readonly model: string;
  readonly params: TranscriptionParams;
}

export type Route = ManagedRoute | PassthroughRoute | TranscriptionRoute;

const PASS_MINI: PassthroughRoute = { mode: "passthrough", allowedModels: ["gpt-4.1-mini"] };

/** Fila managed que reproduce la llamada de hoy con `gpt-4.1-mini`: se usa hasta que el banco de la tarea decida. */
function miniToday(params: ChatParams): ManagedRoute {
  return { mode: "managed", provider: "openai", model: "gpt-4.1-mini", params, retries: 0 };
}

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

  // --- Sesión 2: el gateway decide también las de gpt-4.1-mini. Hasta que su banco elija, cada fila reproduce
  // EXACTAMENTE lo que la app manda hoy (modelo, temperatura y formato), así que pasar de passthrough a managed no
  // cambia la respuesta; lo único nuevo es el tope de salida, holgado. ---
  // Banco del 2026-10-07 (sesión 2; informe en gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md): 100 % en 33
  // preguntas × 2 de 14 locales (criterio determinista de cifras e idioma + juez con 96–100 % de acuerdo con una muestra
  // puntuada a mano), frente al 98,5 % de gpt-4.1-mini; p95 2,1 s contra el corte de 20 s; 0,20 USD por 1 000 (mini:
  // 1,46). Tope: p99 de salida 67 tokens; 512 deja sitio a respuestas largas que el banco no tiene.
  "chat.answer": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "none", responseFormat: "text", maxOutputTokens: 512 },
    retries: 0,
  },
  // 100 % en 14 reescrituras × 2 (igual que mini), p95 2,1 s contra el corte de 8 s, 0,056 USD por 1 000 (mini: 0,198).
  "chat.rewrite": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "none", responseFormat: "json_object", jsonSchema: CHAT_REWRITE_SCHEMA, maxOutputTokens: 300 },
    retries: 0,
  },
  // 97,7 % en 44 frases × 2 de 14 locales (mini: 90,9 %); sin razonar se queda en 85,7 %, por eso esfuerzo `low`. p95
  // 3,7 s; 0,146 USD por 1 000 (mini: 0,589). El tope cuenta el razonamiento: p99 373 tokens; 1500 cubre notas de 5
  // movimientos, que el banco no tiene. Lo que falla: jerga («18 lucas») y divisas que el prompt no enseña.
  "text.parse": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "low", responseFormat: "text", maxOutputTokens: 1500 },
    retries: 0,
  },
  // Banco de voz del 2026-10-07 (docs/ai-voice-bench-2026-10.md): de 15 variantes medidas, la que menos se equivoca.
  // Error por palabra 2,7 % con los términos del usuario (whisper-1: 9,0 %), comercio bien escrito en el 96,9 % de las
  // notas (75 %), mejor que whisper-1 en las 14 variantes de idioma; p95 1,2 s en serie; 0,27 USD por hora (0,36).
  // El prompt fijo pide cifras: sin él deja importes en letra («cincuenta y seis veinte») que la lectura de la nota no
  // entiende. Las versiones instaladas también ganan sin mandar términos (3,7 % frente a 6,7 % en limpio), y whisper-1
  // se apaga el 2027-02-26. OpenAI: sin segundo proveedor ni cambio en los textos de permisos.
  "voice.transcribe": {
    mode: "transcription",
    provider: "openai",
    model: "gpt-transcribe",
    params: {
      languageField: "languages",
      maxKeywords: 100,
      prompt: "Personal finance voice note. Write every amount with digits, for example 12.50, 56.20 or 1,250.",
    },
  },
  // Banco del 2026-10-07 (gateway/bench/results/2026-10-07/REPORT-insights-y-tendencias.md). Ningún juez llegó al acuerdo
  // mínimo con la muestra a mano, así que deciden el criterio determinista (cero cifras inventadas, idioma, pantalla) y la
  // lectura a mano de las respuestas.
  // 90,6 % en 16 casos × 2 de 14 locales (mini: 56,3 %), cero cifras inventadas y una contradicción en 16 leídas; p95
  // 9,4 s contra el corte de 20 s; 0,48 USD por 1 000 (mini: 1,37). Tope: p99 1009 tokens con razonamiento, ×2.
  "insights.cards": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "low", responseFormat: "json_object", maxOutputTokens: 2020 },
    retries: 0,
  },
  // Flujo de caja y desviaciones: todos los candidatos aciertan el 100 % sin contar el idioma; con él, gpt-6-luna iguala o
  // supera a mini (25 % y 21,4 %) por 3-4 veces menos (0,052 y 0,048 USD por 1 000). El idioma falla con todos porque el
  // prompt de la app no lo pide: ticket insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language. Tope: p99 51-56
  // tokens; 256 da margen.
  "insights.cashflow": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "none", responseFormat: "json_object", maxOutputTokens: 256 },
    retries: 0,
  },
  "insights.deviation": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6-luna",
    params: { reasoningEffort: "none", responseFormat: "json_object", maxOutputTokens: 256 },
    retries: 0,
  },
  // Tendencias: solo Gemini 3.8 Flash y gpt-6.1-sol sacan el 100 % (mini: 68,8 %; gpt-6-luna: 68,8 %). Gana Gemini, que no
  // se puede encender todavía (ver PREPARED_ROUTES), así que sirve la mejor de OpenAI: primero calidad, aunque cueste más
  // (4,49 USD por 1 000 frente a 0,60; la app guarda el resumen 24 h). p95 9,8 s. Tope: p99 510 tokens con razonamiento,
  // ×2. gpt-6.1-sol no admite esfuerzo `none`.
  "trends.summary": {
    mode: "managed",
    provider: "openai",
    model: "gpt-6.1-sol",
    params: { reasoningEffort: "low", responseFormat: "json_object", maxOutputTokens: 1020 },
    retries: 0,
  },
  // Solo las mandan versiones anteriores al 2026-10-03 o peticiones sin huella: salen byte a byte como siempre.
  // `gpt-4.1-mini` no tiene apagado anunciado (developers.openai.com/api/docs/deprecations, 2026-10-07).
  "insights.hero": PASS_MINI,
  "legacy.passthrough": PASS_MINI,
};

/**
 * Filas que el banco eligió y todavía NO se pueden encender: son de otro proveedor y falta lo que pide el paso 7 de
 * `ai-every-call-sends-its-task-and-passes-the-bench` (textos de permisos y consentimiento en los 16 idiomas, la
 * política de privacidad web publicada, DPA y nivel de pago, la clave como secret del Worker y su `LEGACY_OVERRIDES` de
 * OpenAI). No las lee ningún código: encender una = moverla a `ROUTES` y poner en `LEGACY_OVERRIDES` la fila de OpenAI
 * que hoy está en `ROUTES`.
 */
export const PREPARED_ROUTES: Readonly<Partial<Record<TaskId, ManagedRoute>>> = {
  // Tendencias, banco del 2026-10-07: 100 % como gpt-6.1-sol, a un tercio del precio (1,47 USD por 1 000; ~2,95 desde el
  // 2027-01-01) y la mitad de latencia (p95 4,2 s). Hubo 429 y 503 en el banco. Apagado anunciado: sin comprobar.
  "trends.summary": {
    mode: "managed",
    provider: "gemini",
    model: "gemini-3.8-flash",
    params: { temperature: 0.4, reasoningEffort: "low", responseFormat: "json_object", maxOutputTokens: 460 },
    retries: 0,
  },
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
  if (!viaHeader && route.mode !== "passthrough" && route.provider !== "openai") {
    // Defensa en profundidad: la tabla está mal y una versión que promete OpenAI saldría a otro sitio.
    throw new Error(`routeFor: ${task} sin cabecera resuelve a ${route.provider}; falta su LEGACY_OVERRIDE de OpenAI`);
  }
  return route;
}
