import type { ManagedRoute } from "../routes";
import { errorResult, extractJsonObject, openAICompletion, withRetries } from "./common";
import type { AdapterContext, AdapterResult, ChatAdapter, OpenAIChatBody, OpenAIContentPart, OpenAIMessage, Usage } from "./types";

export const OPENAI_BASE = "https://api.openai.com/v1";

/** Mensajes de la app con el `detail` de imagen que pide la fila. El resto, intacto. */
export function withImageDetail(messages: OpenAIMessage[], detail: string | undefined): OpenAIMessage[] {
  if (!detail) return messages;
  return messages.map((m) => {
    if (!Array.isArray(m.content)) return m;
    const content: OpenAIContentPart[] = m.content.map((p) =>
      p.type === "image_url" ? { type: "image_url", image_url: { ...p.image_url, detail } } : p,
    );
    return { ...m, content };
  });
}

/** Cuerpo hacia OpenAI (o un endpoint compatible): mensajes de la app + parámetros de la fila. */
export function buildOpenAIBody(body: OpenAIChatBody, route: ManagedRoute): Record<string, unknown> {
  const p = route.params;
  const out: Record<string, unknown> = {
    model: route.model,
    messages: withImageDetail(body.messages, p.image?.detail),
  };
  if (p.temperature !== undefined) out.temperature = p.temperature;
  if (p.reasoningEffort !== undefined) out.reasoning_effort = p.reasoningEffort;
  if (p.maxOutputTokens !== undefined) out.max_completion_tokens = p.maxOutputTokens;
  if (p.responseFormat === "json_object") {
    out.response_format =
      p.strictSchema && p.jsonSchema
        ? { type: "json_schema", json_schema: { name: p.jsonSchema.name, schema: p.jsonSchema.schema, strict: true } }
        : { type: "json_object" };
  }
  return out;
}

export function openAIUsage(json: unknown): Usage | null {
  const u = (json as { usage?: Record<string, unknown> } | null)?.usage;
  if (!u || typeof u.prompt_tokens !== "number") return null;
  const pd = (u.prompt_tokens_details ?? {}) as { cached_tokens?: number };
  const cd = (u.completion_tokens_details ?? {}) as { reasoning_tokens?: number };
  return {
    inputTokens: u.prompt_tokens as number,
    outputTokens: typeof u.completion_tokens === "number" ? u.completion_tokens : 0,
    cachedInputTokens: pd.cached_tokens ?? 0,
    reasoningTokens: cd.reasoning_tokens ?? 0,
  };
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/**
 * OpenAI y compatibles. Con OpenAI la respuesta vuelve TAL CUAL (ya tiene la forma que la app
 * decodifica). Con un endpoint compatible de terceros (`normalize: true`) se reconstruye la respuesta
 * y se recorta el JSON, porque su forma y su modo JSON no están garantizados.
 */
export function makeOpenAICompatibleAdapter(opts: {
  provider: string;
  baseUrl: (ctx: AdapterContext) => string;
  key: (ctx: AdapterContext) => string | undefined;
  normalize: boolean;
  /** Tope de salida si la fila no fija uno: Workers AI corta a 256 tokens por defecto. */
  defaultMaxTokens?: number;
}): ChatAdapter {
  return {
    async send(body: OpenAIChatBody, route: ManagedRoute, ctx: AdapterContext): Promise<AdapterResult> {
      const key = opts.key(ctx);
      if (!key) return errorResult(503, opts.provider, "sin clave configurada", 0);
      const doFetch = ctx.fetch ?? fetch;
      const built = buildOpenAIBody(body, route);
      if (opts.defaultMaxTokens && built.max_completion_tokens === undefined) built.max_tokens = opts.defaultMaxTokens;
      const payload = JSON.stringify(built);
      let resp: Response;
      let attempts: number;
      try {
        ({ resp, attempts } = await withRetries(route.retries, () =>
          doFetch(`${opts.baseUrl(ctx)}/chat/completions`, {
            method: "POST",
            headers: { "content-type": "application/json", authorization: `Bearer ${key}` },
            body: payload,
          }),
        ));
      } catch (err) {
        return errorResult(502, opts.provider, `red: ${String(err)}`, route.retries + 1);
      }
      const text = await resp.text();
      const json = safeJson(text) as { model?: string; choices?: { message?: { content?: string | null }; finish_reason?: string }[] } | null;
      if (!resp.ok) {
        if (!opts.normalize) {
          return { status: resp.status, body: text, usage: null, model: null, attempts, error: `${opts.provider} ${resp.status}: ${text.slice(0, 300)}` };
        }
        return errorResult(resp.status, opts.provider, text, attempts);
      }
      const usage = openAIUsage(json);
      if (!opts.normalize) {
        return { status: resp.status, body: text, usage, model: json?.model ?? null, attempts };
      }
      const choice = json?.choices?.[0];
      const raw = choice?.message?.content ?? "";
      const content = route.params.responseFormat === "json_object" ? extractJsonObject(raw) : raw;
      const fr = choice?.finish_reason === "length" ? "length" : "stop";
      return {
        status: 200,
        body: openAICompletion({ model: json?.model ?? route.model, content, finishReason: fr, usage }),
        usage,
        model: json?.model ?? route.model,
        attempts,
      };
    },
  };
}

export const openaiAdapter = makeOpenAICompatibleAdapter({
  provider: "openai",
  baseUrl: () => OPENAI_BASE,
  key: (ctx) => ctx.keys.openai,
  normalize: false,
});

/** xAI (Grok): API compatible con OpenAI. Se normaliza por si el modo JSON no viene garantizado. */
export const xaiAdapter = makeOpenAICompatibleAdapter({
  provider: "xai",
  baseUrl: () => "https://api.x.ai/v1",
  key: (ctx) => ctx.keys.xai,
  normalize: true,
});

/** Workers AI por su endpoint compatible con OpenAI (REST). Modelos `@cf/...`. */
export const workersAIAdapter = makeOpenAICompatibleAdapter({
  provider: "workersai",
  baseUrl: (ctx) => `https://api.cloudflare.com/client/v4/accounts/${ctx.keys.workersai?.accountId ?? ""}/ai/v1`,
  key: (ctx) => ctx.keys.workersai?.token,
  normalize: true,
  defaultMaxTokens: 2048,
});

