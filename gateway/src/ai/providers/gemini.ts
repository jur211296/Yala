import type { ManagedRoute } from "../routes";
import { errorResult, extractJsonObject, openAICompletion, parseDataUrl, partsOf, systemTextOf, withRetries } from "./common";
import type { AdapterContext, AdapterResult, ChatAdapter, OpenAIChatBody, Usage } from "./types";

/**
 * Google Gemini por `models.generateContent` (REST nativo, no el endpoint compatible con OpenAI:
 * ese no expone la resolución de imagen ni el nivel de razonamiento).
 * Docs consultadas el 2026-10-07: ai.google.dev/api/generate-content, /gemini-api/docs/media-resolution.
 */
const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta";

const MEDIA_RESOLUTION: Record<string, string> = {
  low: "MEDIA_RESOLUTION_LOW",
  high: "MEDIA_RESOLUTION_HIGH",
};

export function buildGeminiBody(body: OpenAIChatBody, route: ManagedRoute): Record<string, unknown> {
  const p = route.params;
  const contents: unknown[] = [];
  for (const m of body.messages) {
    if (m.role === "system" || m.role === "developer") continue;
    const parts: unknown[] = [];
    for (const part of partsOf(m.content)) {
      if (part.type === "text") parts.push({ text: part.text });
      else {
        const img = parseDataUrl(part.image_url.url);
        if (img) parts.push({ inlineData: { mimeType: img.mime, data: img.data } });
      }
    }
    contents.push({ role: m.role === "assistant" ? "model" : "user", parts });
  }
  const generationConfig: Record<string, unknown> = {};
  if (p.temperature !== undefined) generationConfig.temperature = p.temperature;
  if (p.maxOutputTokens !== undefined) generationConfig.maxOutputTokens = p.maxOutputTokens;
  if (p.responseFormat === "json_object") {
    generationConfig.responseMimeType = "application/json";
    if (p.strictSchema && p.jsonSchema) generationConfig.responseJsonSchema = p.jsonSchema.schema;
  }
  if (p.reasoningEffort !== undefined) {
    // Gemini 2.5 se apaga con presupuesto 0; la familia 3.x usa niveles y su mínimo es `minimal`.
    generationConfig.thinkingConfig = route.model.startsWith("gemini-2.5")
      ? { thinkingBudget: p.reasoningEffort === "none" ? 0 : 1024 }
      : { thinkingLevel: p.reasoningEffort === "none" ? "minimal" : p.reasoningEffort };
  }
  const mr = p.image ? MEDIA_RESOLUTION[p.image.detail] : undefined;
  if (mr) generationConfig.mediaResolution = mr;

  const sys = systemTextOf(body.messages);
  return {
    ...(sys ? { systemInstruction: { parts: [{ text: sys }] } } : {}),
    contents,
    generationConfig,
  };
}

function geminiUsage(json: unknown): Usage | null {
  const u = (json as { usageMetadata?: Record<string, number> } | null)?.usageMetadata;
  if (!u) return null;
  const thoughts = u.thoughtsTokenCount ?? 0;
  return {
    inputTokens: u.promptTokenCount ?? 0,
    // Gemini factura el razonamiento como salida pero lo cuenta aparte: se suma para comparar igual.
    outputTokens: (u.candidatesTokenCount ?? 0) + thoughts,
    cachedInputTokens: u.cachedContentTokenCount ?? 0,
    reasoningTokens: thoughts,
  };
}

export const geminiAdapter: ChatAdapter = {
  async send(body: OpenAIChatBody, route: ManagedRoute, ctx: AdapterContext): Promise<AdapterResult> {
    const key = ctx.keys.gemini;
    if (!key) return errorResult(503, "gemini", "sin clave configurada", 0);
    const doFetch = ctx.fetch ?? fetch;
    const payload = JSON.stringify(buildGeminiBody(body, route));
    let resp: Response;
    let attempts: number;
    try {
      ({ resp, attempts } = await withRetries(route.retries, () =>
        doFetch(`${GEMINI_BASE}/models/${encodeURIComponent(route.model)}:generateContent`, {
          method: "POST",
          headers: { "content-type": "application/json", "x-goog-api-key": key },
          body: payload,
        }),
      ));
    } catch (err) {
      return errorResult(502, "gemini", `red: ${String(err)}`, route.retries + 1);
    }
    const text = await resp.text();
    if (!resp.ok) return errorResult(resp.status, "gemini", text, attempts);
    let json: {
      modelVersion?: string;
      candidates?: { content?: { parts?: { text?: string; thought?: boolean }[] }; finishReason?: string }[];
    } | null = null;
    try {
      json = JSON.parse(text);
    } catch {
      return errorResult(502, "gemini", "respuesta no JSON", attempts);
    }
    const cand = json?.candidates?.[0];
    const raw = (cand?.content?.parts ?? []).filter((p) => !p.thought).map((p) => p.text ?? "").join("");
    const content = route.params.responseFormat === "json_object" ? extractJsonObject(raw) : raw;
    const fr = cand?.finishReason === "MAX_TOKENS" ? "length" : cand?.finishReason === "SAFETY" ? "content_filter" : "stop";
    const usage = geminiUsage(json);
    const model = json?.modelVersion ?? route.model;
    return { status: 200, body: openAICompletion({ model, content, finishReason: fr, usage }), usage, model, attempts };
  },
};
