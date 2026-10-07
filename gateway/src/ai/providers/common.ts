import type { AdapterResult, OpenAIContentPart, OpenAIMessage, Usage } from "./types";

/** `data:image/jpeg;base64,AAAA` → { mime, data }. La app manda siempre data URLs. */
export function parseDataUrl(url: string): { mime: string; data: string } | null {
  const m = url.match(/^data:([^;,]+);base64,(.*)$/s);
  return m ? { mime: m[1], data: m[2] } : null;
}

export function partsOf(content: OpenAIMessage["content"]): OpenAIContentPart[] {
  if (content == null) return [];
  if (typeof content === "string") return [{ type: "text", text: content }];
  return content;
}

/** Texto de los mensajes de sistema/developer, en orden. */
export function systemTextOf(messages: OpenAIMessage[]): string {
  return messages
    .filter((m) => m.role === "system" || m.role === "developer")
    .map((m) => partsOf(m.content).map((p) => (p.type === "text" ? p.text : "")).join(""))
    .join("\n\n");
}

/** Respuesta `chat.completion` con la forma que decodifica el SDK MacPaw 0.4.7 de la app. */
export function openAICompletion(args: {
  model: string;
  content: string;
  finishReason: "stop" | "length" | "content_filter";
  usage: Usage | null;
}): string {
  const u = args.usage;
  return JSON.stringify({
    id: `chatcmpl-yala-${crypto.randomUUID()}`,
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: args.model,
    choices: [
      {
        index: 0,
        message: { role: "assistant", content: args.content },
        finish_reason: args.finishReason,
        logprobs: null,
      },
    ],
    usage: u
      ? {
          prompt_tokens: u.inputTokens,
          completion_tokens: u.outputTokens,
          total_tokens: u.inputTokens + u.outputTokens,
        }
      : undefined,
  });
}

/** Error con el sobre que el SDK de la app sabe decodificar (ver src/errors.ts). */
export function errorResult(status: number, provider: string, detail: string, attempts: number): AdapterResult {
  return {
    status,
    body: JSON.stringify({
      error: { message: `Proveedor de IA no disponible (${provider} ${status}).`, type: "yala_upstream_error", param: null, code: "yala_upstream_error" },
    }),
    usage: null,
    model: null,
    attempts,
    error: `${provider} ${status}: ${detail.slice(0, 300)}`,
  };
}

/**
 * La app parsea el contenido con `JSONSerialization`: un JSON envuelto en ```json …``` o con texto
 * alrededor la rompe. Para proveedores sin modo JSON garantizado, se recorta al objeto.
 */
export function extractJsonObject(text: string): string {
  const trimmed = text.trim();
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) return trimmed;
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const inner = fenced ? fenced[1].trim() : trimmed;
  const start = inner.indexOf("{");
  const end = inner.lastIndexOf("}");
  return start >= 0 && end > start ? inner.slice(start, end + 1) : inner;
}

export function isRetryable(status: number): boolean {
  return status === 408 || status === 429 || status >= 500;
}

/**
 * Llama `attempt` hasta `retries + 1` veces. Reintenta ante error de red o status reintentable.
 * Devuelve la última respuesta (o lanza el último error de red).
 */
export async function withRetries(retries: number, attempt: () => Promise<Response>): Promise<{ resp: Response; attempts: number }> {
  let lastErr: unknown = null;
  for (let i = 0; i <= retries; i++) {
    try {
      const resp = await attempt();
      if (i < retries && isRetryable(resp.status)) {
        await resp.body?.cancel();
        continue;
      }
      return { resp, attempts: i + 1 };
    } catch (err) {
      lastErr = err;
      if (i === retries) throw err;
    }
  }
  throw lastErr ?? new Error("withRetries: sin intentos");
}
