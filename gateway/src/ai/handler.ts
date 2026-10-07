import type { Context } from "hono";
import type { Env } from "../env";
import { requireSession } from "../auth";
import { jsonError } from "../errors";
import { gateRequest } from "../ratelimit";
import type { Category } from "../policy";
import { ADAPTERS } from "./providers";
import { OPENAI_BASE, openAIUsage } from "./providers/openai";
import type { OpenAIChatBody, ProviderKeys, Usage } from "./providers/types";
import { type ChatBody, multipartField, resolveChatTask, resolveTranscriptionTask } from "./resolve";
import { routeFor } from "./routes";
import { TASK_HEADER, type TaskId } from "./tasks";

type Ctx = Context<{ Bindings: Env }>;

// `voice` entra el 2026-10-07: el parser de voz (TranscriptionParserService) manda `X-Yala-Category: voice` a
// esta ruta, y sin `voice` en la lista caía al cubo `chat`, que en free no existe → 403 «requiere Pro» en
// cada nota de voz de la prueba gratuita desde el 2026-06-15. Decisión de Jürgen: arreglarlo ya; la cuota
// nueva (una nota = un uso) llega con la sesión 2.
const CHAT_CATEGORIES: readonly Category[] = ["chat", "vision", "voice", "insights", "suggestions"];

/**
 * Categoría de cuota desde `X-Yala-Category` (best-effort: elige el cubo de límite, no es frontera de
 * seguridad — esa la dan attestation + el tope por device). Igual que antes de la tabla.
 */
function categoryFrom(c: Ctx, allowed: readonly Category[], fallback: Category): Category {
  const h = c.req.header("X-Yala-Category");
  return h && (allowed as readonly string[]).includes(h) ? (h as Category) : fallback;
}

/** Headers hacia OpenAI en passthrough: los mismos que antes de la tabla (content-type, accept, clave). */
function upstreamHeaders(incoming: Headers, openaiKey: string): Headers {
  const h = new Headers();
  const ct = incoming.get("content-type");
  if (ct) h.set("content-type", ct);
  const accept = incoming.get("accept");
  if (accept) h.set("accept", accept);
  h.set("authorization", `Bearer ${openaiKey}`);
  return h;
}

function providerKeys(env: Env): ProviderKeys {
  return { openai: env.OPENAI_API_KEY, gemini: env.GEMINI_API_KEY, anthropic: env.ANTHROPIC_API_KEY, xai: env.XAI_API_KEY };
}

/**
 * Una línea por petición para `wrangler tail`: tarea, cómo se resolvió, proveedor y modelo, estado,
 * milisegundos y tokens. NUNCA contenido del usuario.
 */
function logRoute(entry: {
  task: TaskId;
  how: string;
  headerUnknown: boolean;
  category: Category;
  provider: string;
  requested: string | null;
  model: string | null;
  status: number;
  ms: number;
  usage: Usage | null;
  attempts: number;
}): void {
  console.log(
    JSON.stringify({
      evt: "ai_route",
      task: entry.task,
      how: entry.how,
      ...(entry.headerUnknown ? { headerUnknown: true } : {}),
      category: entry.category,
      provider: entry.provider,
      requested: entry.requested,
      model: entry.model,
      status: entry.status,
      ms: entry.ms,
      in: entry.usage?.inputTokens ?? null,
      cached: entry.usage?.cachedInputTokens ?? null,
      out: entry.usage?.outputTokens ?? null,
      reasoning: entry.usage?.reasoningTokens ?? null,
      attempts: entry.attempts,
    }),
  );
}

/** Un valor que manda el cliente, recortado para el log. */
export function clip(value: string, max = 64): string {
  return value.length > max ? `${value.slice(0, max)}…` : value;
}

/** `type/code` del sobre de error de OpenAI (o del nuestro), sin el mensaje. */
function upstreamErrorKind(body: string): string {
  try {
    const e = (JSON.parse(body) as { error?: { type?: unknown; code?: unknown } }).error;
    return `${String(e?.type ?? "?")}/${String(e?.code ?? "?")}`;
  } catch {
    return "sin-json";
  }
}

function safeJsonParse(bytes: Uint8Array): unknown {
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return null;
  }
}

/** Reenvía los bytes de la app a OpenAI tal cual y devuelve su respuesta tal cual. */
async function passthrough(c: Ctx, path: string, bytes: Uint8Array): Promise<{ resp: Response; usage: Usage | null; model: string | null }> {
  const upstream = await fetch(`${OPENAI_BASE}${path}`, {
    method: "POST",
    headers: upstreamHeaders(c.req.raw.headers, c.env.OPENAI_API_KEY),
    body: bytes,
  });
  const out = new Uint8Array(await upstream.arrayBuffer());
  const json = upstream.headers.get("content-type")?.includes("json") ? (safeJsonParse(out) as { model?: string } | null) : null;
  return {
    resp: new Response(out, { status: upstream.status, statusText: upstream.statusText, headers: upstream.headers }),
    usage: openAIUsage(json),
    model: json?.model ?? null,
  };
}

export async function handleChatCompletions(c: Ctx): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;
  const category = categoryFrom(c, CHAT_CATEGORIES, "chat");

  const bytes = new Uint8Array(await c.req.arrayBuffer());
  const body = safeJsonParse(bytes) as ChatBody | null;
  if (!body || typeof body !== "object" || !Array.isArray(body.messages)) {
    return jsonError("yala_bad_request", "Cuerpo de chat inválido.", 400);
  }

  const res = resolveChatTask(c.req.header(TASK_HEADER), category, body);
  if (!res.ok) return jsonError(res.code, res.message, res.status);

  const route = routeFor(res.task, res.how === "header");
  const requested = typeof body.model === "string" ? body.model : null;
  // Antes de la cuota: una petición que se va a rechazar no gasta del cubo del usuario.
  if (route.mode === "passthrough" && (!requested || !route.allowedModels.includes(requested))) {
    return jsonError("yala_model_not_allowed", `La tarea ${res.task} no acepta el modelo ${clip(requested ?? "(vacío)")}.`, 400);
  }

  const blocked = await gateRequest(c.env, claims, category);
  if (blocked) return blocked;
  const started = Date.now();

  if (route.mode === "passthrough") {
    const { resp, usage, model } = await passthrough(c, "/chat/completions", bytes);
    logRoute({ task: res.task, how: res.how, headerUnknown: res.headerUnknown, category, provider: "openai", requested, model, status: resp.status, ms: Date.now() - started, usage, attempts: 1 });
    return resp;
  }

  const result = await ADAPTERS[route.provider].send(body as OpenAIChatBody, route, { keys: providerKeys(c.env) });
  logRoute({
    task: res.task,
    how: res.how,
    headerUnknown: res.headerUnknown,
    category,
    provider: route.provider,
    requested,
    model: result.model ?? route.model,
    status: result.status,
    ms: Date.now() - started,
    usage: result.usage,
    attempts: result.attempts,
  });
  // Solo el tipo y el código del error del proveedor: su mensaje podría citar el contenido de la petición.
  if (result.status >= 400) console.log(`[gw-ai] ${res.task} ${route.provider} ${result.status} ${upstreamErrorKind(result.body)}`);
  return new Response(result.body, { status: result.status, headers: { "content-type": "application/json" } });
}

export async function handleAudioTranscriptions(c: Ctx): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;
  const category: Category = "voice";

  const bytes = new Uint8Array(await c.req.arrayBuffer());
  const model = multipartField(bytes, c.req.header("content-type") ?? null, "model");
  const res = resolveTranscriptionTask(c.req.header(TASK_HEADER), category, model);
  if (!res.ok) return jsonError(res.code, res.message, res.status);

  const blocked = await gateRequest(c.env, claims, category);
  if (blocked) return blocked;

  // Hoy una sola fila y en passthrough; `routeFor` se consulta igual para que la sesión 2 cambie solo la tabla.
  const route = routeFor(res.task, res.how === "header");
  if (route.mode !== "passthrough") {
    return jsonError("yala_unavailable", "La transcripción solo admite passthrough en esta versión del gateway.", 503);
  }
  const started = Date.now();
  const { resp } = await passthrough(c, "/audio/transcriptions", bytes);
  logRoute({ task: res.task, how: res.how, headerUnknown: res.headerUnknown, category, provider: "openai", requested: model, model, status: resp.status, ms: Date.now() - started, usage: null, attempts: 1 });
  return resp;
}
