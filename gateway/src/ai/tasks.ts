import type { Category } from "../policy";

/**
 * Catálogo de TAREAS de IA de Yala: el nombre con el que la app dirá qué pide.
 *
 * Contrato con la app (sesión 2 de `ai-model-choice-lives-in-the-app-binary`):
 *   cabecera `X-Yala-Task: <tarea>`, valor = una clave de `TASKS` (minúsculas, `area.accion`).
 * Con cabecera, el gateway elige proveedor, modelo y parámetros según `ROUTES` (routes.ts).
 * Sin cabecera (todas las versiones instaladas hasta la sesión 2), la tarea se DEDUCE (resolve.ts).
 *
 * `category` es el cubo de cuota de la tarea. Con la cabecera, el cubo SALE DE LA TAREA (sesión 2): la app ya
 * no lo elige. Si además llega un `X-Yala-Category` que no casa, se rechaza (un cliente mal cableado se ve en
 * vez de contar contra otro cubo).
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
  /**
   * Tope del cuerpo de la petición, en bytes (sesión 2, `gateway-proxies-any-model-and-any-length`). Medido con
   * margen sobre lo que manda la app: el texto cabe en decenas de KB; la foto, reducida a 1536 px, en ~1 MB de
   * base64, y una foto ORIGINAL de 12 MP de una versión instalada en unos 4-6 MB.
   */
  readonly maxBodyBytes: number;
  /** La petición tiene que traer una imagen (si no, es otra cosa colándose en el cubo de visión). */
  readonly requiresImage?: boolean;
  /**
   * Solo la deduce el gateway: ninguna app la manda en `X-Yala-Task` (son nombres de versiones viejas o de
   * peticiones sin huella). Con cabecera, se tratan como tarea desconocida.
   */
  readonly deducedOnly?: boolean;
  /** Qué hace con el cupo de una nota de voz (D7): transcribir abre la nota; leerla la cierra sin gastar otro uso. */
  readonly notePairing?: "grant" | "consume";
}

const KB = 1024;
const MB = 1024 * KB;

export const TASKS = {
  // --- Las tres de gpt-4.1-nano (apagado el 2026-10-23): las enruta la tabla desde la sesión 1 ---
  "photo.read": { category: "vision", endpoint: "chat", legacyModel: "gpt-4.1-nano", source: "ImageVisionService.analyze", maxBodyBytes: 12 * MB, requiresImage: true },
  "chat.intent": { category: "suggestions", endpoint: "chat", legacyModel: "gpt-4.1-nano", source: "ChatIntentClassifierService.classifyWithLLM", maxBodyBytes: 32 * KB },
  "chat.suggestions": { category: "suggestions", endpoint: "chat", legacyModel: "gpt-4.1-nano", source: "ChatSuggestionsLLMService.generate", maxBodyBytes: 64 * KB },

  // --- Las de gpt-4.1-mini y whisper-1: el gateway decide desde la sesión 2 ---
  "chat.answer": { category: "chat", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "ChatAssistantService.runAskFlow", maxBodyBytes: 512 * KB },
  "chat.rewrite": { category: "suggestions", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "SuggestionsRewriterService", maxBodyBytes: 64 * KB },
  "text.parse": { category: "voice", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "TranscriptionParserService.parseMultiple", maxBodyBytes: 128 * KB, notePairing: "consume" },
  "voice.transcribe": { category: "voice", endpoint: "transcription", legacyModel: "whisper-1", source: "VoiceTranscriptionService", maxBodyBytes: 26 * MB, notePairing: "grant" },
  "insights.cards": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateInsights", maxBodyBytes: 256 * KB },
  "insights.cashflow": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateCashFlowInsight", maxBodyBytes: 128 * KB },
  "insights.deviation": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateDeviationInsight", maxBodyBytes: 128 * KB },
  "trends.summary": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "TrendsAIService.generate", maxBodyBytes: 256 * KB },
  // Retirada de la app el 2026-10-03 (5c12ffcd3); las versiones instaladas anteriores aún la mandan.
  "insights.hero": { category: "insights", endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "InsightsLLMService.generateHeroMessage (versiones anteriores al 2026-10-03)", maxBodyBytes: 256 * KB, deducedOnly: true },
  // Cualquier petición con gpt-4.1-mini que ninguna huella reconoce: sale exactamente como hoy.
  "legacy.passthrough": { category: null, endpoint: "chat", legacyModel: "gpt-4.1-mini", source: "petición con gpt-4.1-mini sin huella conocida", maxBodyBytes: 512 * KB, deducedOnly: true },
} as const satisfies Record<string, TaskInfo>;

export type TaskId = keyof typeof TASKS;

export function isTaskId(value: string): value is TaskId {
  return Object.prototype.hasOwnProperty.call(TASKS, value);
}

/** Las tareas que una app puede nombrar en `X-Yala-Task` (las de `TASKS` menos las que solo se deducen). */
export function isHeaderTask(value: string): value is TaskId {
  return isTaskId(value) && !(TASKS[value] as TaskInfo).deducedOnly;
}

/** Formato del valor de la cabecera: `area.accion` en minúscula. Validar antes de mirar el catálogo. */
export const TASK_HEADER_PATTERN = /^[a-z]+(\.[a-z]+)+$/;
