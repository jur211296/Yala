import type { Category } from "../policy";

/**
 * Catálogo de TAREAS de IA de Yala: el nombre con el que la app dirá qué pide.
 *
 * Contrato con la app (sesión 2 de `ai-model-choice-lives-in-the-app-binary`):
 *   cabecera `X-Yala-Task: <tarea>`, valor = una clave de `TASKS` (minúsculas, `area.accion`).
 * Con cabecera, el gateway elige proveedor, modelo y parámetros según `ROUTES` (routes.ts).
 * Sin cabecera (todas las versiones instaladas hasta la sesión 2), la tarea se DEDUCE (resolve.ts).
 *
 * `category` es el cubo de cuota (`X-Yala-Category`) que esa tarea usa HOY en la app. Una cabecera de
 * tarea cuyo cubo no casa con la categoría recibida se rechaza: si no, la app (o cualquiera) podría
 * pedir una tarea cara contando contra un cubo barato.
 *
 * `legacyModel` es el modelo que la app escribe hoy en el cuerpo para esa tarea: sirve para deducir
 * sin cabecera y, en las rutas `passthrough`, es el único modelo aceptado.
 */
export const TASK_HEADER = "X-Yala-Task";

export type Endpoint = "chat" | "transcription";

export interface TaskInfo {
  readonly category: Category | null; // null = cualquiera (solo `legacy.passthrough`)
  readonly endpoint: Endpoint;
  readonly legacyModel: string;
  /** Dónde vive la llamada en la app (para quien lea un log o la tabla). */
  readonly source: string;
}

export const TASKS = {
  // --- Las tres de gpt-4.1-nano (se apaga el 2026-10-23): las enruta la tabla ---
  "photo.read": { category: "vision", endpoint: "chat", legacyModel: "gpt-4.1-nano", source: "ImageVisionService.analyze" },
  "chat.intent": { category: "suggestions", endpoint: "chat", legacyModel: "gpt-4.1-nano", source: "ChatIntentClassifierService.classifyWithLLM" },
  "chat.suggestions": { category: "suggestions", endpoint: "chat", legacyModel: "gpt-4.1-nano", source: "ChatSuggestionsLLMService.generate" },

  // --- gpt-4.1-mini y whisper-1: hoy salen tal cual (passthrough) ---
  "chat.answer": { category: "chat", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "ChatAssistantService.runAskFlow" },
  "chat.rewrite": { category: "suggestions", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "SuggestionsRewriterService" },
  "text.parse": { category: "voice", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "TranscriptionParserService.parseMultiple" },
  "voice.transcribe": { category: "voice", endpoint: "transcription", legacyModel: "whisper-1", source: "VoiceTranscriptionService" },
  "insights.cards": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateInsights" },
  "insights.cashflow": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateCashFlowInsight" },
  "insights.deviation": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateDeviationInsight" },
  "insights.contextual": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateContextualInsight (sin llamadores)" },
  "trends.summary": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "TrendsAIService.generate" },
  // Retirada de la app el 2026-10-03 (5c12ffcd3); las versiones instaladas anteriores aún la mandan.
  "insights.hero": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateHeroMessage (versiones anteriores al 2026-10-03)" },
  // Cualquier petición con gpt-4.1-mini que ninguna huella reconoce: sale exactamente como hoy.
  "legacy.passthrough": { category: null, endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "petición con gpt-4.1-mini sin huella conocida" },
} as const satisfies Record<string, TaskInfo>;

export type TaskId = keyof typeof TASKS;

export function isTaskId(value: string): value is TaskId {
  return Object.prototype.hasOwnProperty.call(TASKS, value);
}

/** Formato del valor de la cabecera: `area.accion` en minúscula. Validar antes de mirar el catálogo. */
export const TASK_HEADER_PATTERN = /^[a-z]+(\.[a-z]+)+$/;
