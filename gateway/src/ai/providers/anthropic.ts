import type { ManagedRoute } from "../routes";
import { errorResult, extractJsonObject, openAICompletion, parseDataUrl, partsOf, systemTextOf, withRetries } from "./common";
import type { AdapterContext, AdapterResult, ChatAdapter, OpenAIChatBody, Usage } from "./types";

/**
 * Anthropic por la Messages API (HTTP crudo: el gateway es neutral de proveedor y no carga SDKs).
 * Referencia: skill claude-api (modelos al 2026-09-25) y platform.claude.com/docs.
 *
 * - Sin modo «JSON libre»: con `jsonSchema` en la fila se usa `output_config.format` (salida que no puede
 *   romper el esquema); sin él, se confía en el prompt y se recorta al objeto.
 * - Razonamiento: Haiku 4.5 va sin thinking por defecto y lo enciende con presupuesto; Sonnet 5.5 lo apaga con
 *   `between_tools`, Haiku 5.5 con `disabled` (`thinkingOff`), y los dos lo gradúan con `output_config.effort`.
 */
const ANTHROPIC_BASE = "https://api.anthropic.com/v1";
const DEFAULT_MAX_TOKENS = 4096;

function isHaiku45(model: string): boolean {
  return model.startsWith("claude-haiku-4-5");
}

/**
 * Cómo se apaga el razonamiento en la familia 4.6+: solo Sonnet 5.5 acepta `between_tools`; el resto (Claude
 * Haiku 5.5, Sonnet 5, Opus 5 a esfuerzo `high` o menos) acepta `disabled` y rechaza `between_tools` con un 400.
 * Opus 5.5 y Fable rechazan las dos: con ellos no se pide `none` (skill claude-api, tabla de razonamiento, 2026-10-06).
 */
function thinkingOff(model: string): Record<string, unknown> {
  return model.startsWith("claude-sonnet-5-5") ? { type: "between_tools" } : { type: "disabled" };
}

export function buildAnthropicBody(body: OpenAIChatBody, route: ManagedRoute): Record<string, unknown> {
  const p = route.params;
  const messages: unknown[] = [];
  for (const m of body.messages) {
    if (m.role === "system" || m.role === "developer") continue;
    const content: unknown[] = [];
    for (const part of partsOf(m.content)) {
      if (part.type === "text") content.push({ type: "text", text: part.text });
      else {
        const img = parseDataUrl(part.image_url.url);
        if (img) content.push({ type: "image", source: { type: "base64", media_type: img.mime, data: img.data } });
      }
    }
    messages.push({ role: m.role === "assistant" ? "assistant" : "user", content });
  }
  const out: Record<string, unknown> = {
    model: route.model,
    max_tokens: p.maxOutputTokens ?? DEFAULT_MAX_TOKENS,
    messages,
  };
  const sys = systemTextOf(body.messages);
  if (sys) out.system = sys;
  if (p.temperature !== undefined) out.temperature = p.temperature;

  const outputConfig: Record<string, unknown> = {};
  if (p.responseFormat === "json_object" && p.jsonSchema) {
    outputConfig.format = { type: "json_schema", schema: p.jsonSchema.schema };
  }
  if (p.reasoningEffort !== undefined) {
    if (isHaiku45(route.model)) {
      if (p.reasoningEffort !== "none") {
        out.thinking = { type: "enabled", budget_tokens: 1024 };
        delete out.temperature; // con thinking, Haiku 4.5 solo acepta la temperatura por defecto
      }
    } else if (p.reasoningEffort === "none") {
      out.thinking = thinkingOff(route.model);
    } else {
      outputConfig.effort = p.reasoningEffort === "minimal" ? "low" : p.reasoningEffort;
    }
  }
  if (Object.keys(outputConfig).length > 0) out.output_config = outputConfig;
  return out;
}

function anthropicUsage(json: unknown): Usage | null {
  const u = (json as { usage?: Record<string, number> } | null)?.usage;
  if (!u) return null;
  const cacheRead = u.cache_read_input_tokens ?? 0;
  const cacheWrite = u.cache_creation_input_tokens ?? 0;
  return {
    // `input_tokens` excluye lo leído o escrito en caché: se suma para comparar igual con OpenAI.
    inputTokens: (u.input_tokens ?? 0) + cacheRead + cacheWrite,
    outputTokens: u.output_tokens ?? 0,
    cachedInputTokens: cacheRead,
    reasoningTokens: 0,
  };
}

export const anthropicAdapter: ChatAdapter = {
  async send(body: OpenAIChatBody, route: ManagedRoute, ctx: AdapterContext): Promise<AdapterResult> {
    const key = ctx.keys.anthropic;
    if (!key) return errorResult(503, "anthropic", "sin clave configurada", 0);
    const doFetch = ctx.fetch ?? fetch;
    const payload = JSON.stringify(buildAnthropicBody(body, route));
    let resp: Response;
    let attempts: number;
    try {
      ({ resp, attempts } = await withRetries(route.retries, () =>
        doFetch(`${ANTHROPIC_BASE}/messages`, {
          method: "POST",
          headers: { "content-type": "application/json", "x-api-key": key, "anthropic-version": "2023-06-01" },
          body: payload,
        }),
      ));
    } catch (err) {
      return errorResult(502, "anthropic", `red: ${String(err)}`, route.retries + 1);
    }
    const text = await resp.text();
    if (!resp.ok) return errorResult(resp.status, "anthropic", text, attempts);
    let json: { model?: string; stop_reason?: string; content?: { type: string; text?: string }[] } | null = null;
    try {
      json = JSON.parse(text);
    } catch {
      return errorResult(502, "anthropic", "respuesta no JSON", attempts);
    }
    const raw = (json?.content ?? []).filter((b) => b.type === "text").map((b) => b.text ?? "").join("");
    const content = route.params.responseFormat === "json_object" ? extractJsonObject(raw) : raw;
    const fr = json?.stop_reason === "max_tokens" ? "length" : json?.stop_reason === "refusal" ? "content_filter" : "stop";
    const usage = anthropicUsage(json);
    const model = json?.model ?? route.model;
    return { status: 200, body: openAICompletion({ model, content, finishReason: fr, usage }), usage, model, attempts };
  },
};
