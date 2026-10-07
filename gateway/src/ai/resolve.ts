import type { Category } from "../policy";
import { TASKS, TASK_HEADER_PATTERN, type TaskId, isTaskId } from "./tasks";

/**
 * ¿Qué TAREA es esta petición?
 *
 * 1. Con cabecera `X-Yala-Task` válida y conocida → esa (si su cubo casa con `X-Yala-Category`).
 * 2. Sin cabecera (o con un valor que este gateway no conoce) → se deduce de la ruta, la categoría, el
 *    modelo pedido y la huella del prompt de sistema. Es lo que mandan TODAS las versiones instaladas.
 *
 * Las huellas son el inicio literal del prompt de sistema de cada servicio. Medido el 2026-10-07 con
 * `git log -S`: ninguna cambió desde que existe su servicio (abril de 2026), y el gateway es de junio,
 * así que toda versión que habla con él las manda tal cual. Las de las tres tareas de gpt-4.1-nano
 * deciden el enrutado; las de gpt-4.1-mini solo dan nombre al log (esas salen igual pase lo que pase).
 */

export type Resolution =
  | { ok: true; task: TaskId; how: "header" | "fingerprint" | "heuristic" | "category"; headerUnknown: boolean }
  | { ok: false; status: number; code: "yala_model_not_allowed" | "yala_task_mismatch" | "yala_bad_request"; message: string };

const NANO = "gpt-4.1-nano";
const MINI = "gpt-4.1-mini";

export const FINGERPRINTS = {
  "photo.read": "You are a financial transaction extractor.",
  "chat.intent": "Eres un clasificador de intenciones para un chat financiero.",
  "chat.suggestions": "You generate personalized chat conversation starters for a personal finance app.",
  "chat.rewrite": "You rewrite chat suggestion phrases for a personal finance app.",
  "insights.cards": "Analizas EXCLUSIVAMENTE los datos agregados proporcionados.",
  "insights.contextual": "Genera UNA SOLA oración corta (máximo 150 caracteres) sobre las finanzas del usuario.",
  "insights.cashflow": "sobre la proyección de flujo de caja del usuario.",
  "insights.deviation": "sobre las subcategorías donde el usuario gastó más de lo planeado.",
  "trends.summary": "El usuario está mirando la pestaña Tendencias de su app",
} as const;

/** Primer mensaje de sistema, en texto (la app manda `content` string o partes de texto). */
export function systemText(body: ChatBody): string {
  const messages = Array.isArray(body.messages) ? body.messages : [];
  for (const m of messages) {
    if (!m || typeof m !== "object") continue;
    const msg = m as { role?: unknown; content?: unknown };
    if (msg.role !== "system") continue;
    if (typeof msg.content === "string") return msg.content;
    if (Array.isArray(msg.content)) {
      return msg.content
        .map((p) => (p && typeof p === "object" && typeof (p as { text?: unknown }).text === "string" ? (p as { text: string }).text : ""))
        .join("");
    }
  }
  return "";
}

export interface ChatBody {
  model?: unknown;
  messages?: unknown;
  temperature?: unknown;
  [k: string]: unknown;
}

function has(text: string, task: keyof typeof FINGERPRINTS): boolean {
  return text.includes(FINGERPRINTS[task]);
}

function fromHeader(header: string | null | undefined, category: Category, endpoint: "chat" | "transcription"):
  | { kind: "none" }
  | { kind: "unknown" }
  | { kind: "known"; task: TaskId }
  | { kind: "error"; res: Resolution } {
  if (header == null || header === "") return { kind: "none" };
  const value = header.trim();
  if (!TASK_HEADER_PATTERN.test(value) || !isTaskId(value)) return { kind: "unknown" };
  const info = TASKS[value];
  if (info.endpoint !== endpoint) {
    return { kind: "error", res: { ok: false, status: 400, code: "yala_task_mismatch", message: `La tarea ${value} no va por esta ruta.` } };
  }
  if (info.category !== null && info.category !== category) {
    return {
      kind: "error",
      res: { ok: false, status: 400, code: "yala_task_mismatch", message: `La tarea ${value} no corresponde a la categoría ${category}.` },
    };
  }
  return { kind: "known", task: value };
}

/** Deducción sin cabecera para `/v1/chat/completions`. */
export function deduceChatTask(category: Category, body: ChatBody): Resolution {
  const model = typeof body.model === "string" ? body.model : "";
  const sys = systemText(body);

  if (model === NANO) {
    if (category === "vision") return { ok: true, task: "photo.read", how: has(sys, "photo.read") ? "fingerprint" : "category", headerUnknown: false };
    if (category === "suggestions") {
      if (has(sys, "chat.intent")) return { ok: true, task: "chat.intent", how: "fingerprint", headerUnknown: false };
      if (has(sys, "chat.suggestions")) return { ok: true, task: "chat.suggestions", how: "fingerprint", headerUnknown: false };
      // Sin huella: ningún build de la app llega aquí. El clasificador manda temperatura 0; las
      // sugerencias, 0.7. Se registra como `heuristic` para verlo en el tail si alguna vez pasa.
      const t = typeof body.temperature === "number" ? body.temperature : null;
      return { ok: true, task: t === 0 ? "chat.intent" : "chat.suggestions", how: "heuristic", headerUnknown: false };
    }
    // gpt-4.1-nano en otra categoría: ninguna versión con gateway lo hace (medido en 60fa56077 y v2.0.4).
    return {
      ok: false,
      status: 400,
      code: "yala_model_not_allowed",
      message: `El modelo ${NANO} no se acepta en la categoría ${category}.`,
    };
  }

  if (model === MINI) {
    // Solo da nombre al log: todas salen byte a byte como hoy.
    switch (category) {
      case "chat":
        return { ok: true, task: "chat.answer", how: "category", headerUnknown: false };
      case "voice":
        return { ok: true, task: "text.parse", how: "category", headerUnknown: false };
      case "suggestions":
        return { ok: true, task: has(sys, "chat.rewrite") ? "chat.rewrite" : "legacy.passthrough", how: has(sys, "chat.rewrite") ? "fingerprint" : "category", headerUnknown: false };
      case "insights": {
        const order: (keyof typeof FINGERPRINTS)[] = ["trends.summary", "insights.cards", "insights.contextual", "insights.cashflow", "insights.deviation"];
        for (const t of order) if (has(sys, t)) return { ok: true, task: t as TaskId, how: "fingerprint", headerUnknown: false };
        // El hero (retirado de la app el 2026-10-03) era la única llamada de insights con temperatura 0.75.
        if (body.temperature === 0.75) return { ok: true, task: "insights.hero", how: "heuristic", headerUnknown: false };
        return { ok: true, task: "legacy.passthrough", how: "category", headerUnknown: false };
      }
      default:
        return { ok: true, task: "legacy.passthrough", how: "category", headerUnknown: false };
    }
  }

  return {
    ok: false,
    status: 400,
    code: model ? "yala_model_not_allowed" : "yala_bad_request",
    message: model ? `El modelo ${model.slice(0, 64)} no está permitido en este gateway.` : "Falta el modelo.",
  };
}

export function resolveChatTask(header: string | null | undefined, category: Category, body: ChatBody): Resolution {
  const h = fromHeader(header, category, "chat");
  if (h.kind === "error") return h.res;
  if (h.kind === "known") return { ok: true, task: h.task, how: "header", headerUnknown: false };
  const deduced = deduceChatTask(category, body);
  return deduced.ok ? { ...deduced, headerUnknown: h.kind === "unknown" } : deduced;
}

/** `/v1/audio/transcriptions`: una sola tarea; lo que se valida es el modelo del multipart. */
export function resolveTranscriptionTask(header: string | null | undefined, category: Category, model: string | null): Resolution {
  const h = fromHeader(header, category, "transcription");
  if (h.kind === "error") return h.res;
  if (model !== "whisper-1") {
    return {
      ok: false,
      status: 400,
      code: model ? "yala_model_not_allowed" : "yala_bad_request",
      message: model ? `El modelo ${model.slice(0, 64)} no está permitido en este gateway.` : "Falta el modelo.",
    };
  }
  return { ok: true, task: "voice.transcribe", how: h.kind === "known" ? "header" : "category", headerUnknown: h.kind === "unknown" };
}

/** Lee el campo `model` de un multipart/form-data sin tocar el resto de bytes. */
export function multipartField(bytes: Uint8Array, contentType: string | null, field: string): string | null {
  const m = contentType?.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
  if (!m) return null;
  // latin1 conserva un byte por carácter: el audio binario no rompe la búsqueda.
  let text = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    text += String.fromCharCode(...bytes.subarray(i, Math.min(i + chunk, bytes.length)));
  }
  const re = new RegExp(`Content-Disposition:\\s*form-data;\\s*name="${field}"[^\\r\\n]*\\r\\n(?:[^\\r\\n]+\\r\\n)*\\r\\n([^\\r\\n]*)\\r\\n`, "i");
  const found = text.match(re);
  return found ? found[1] : null;
}
