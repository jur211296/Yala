import type { Context } from "hono";
import type { Env } from "../env";
import { requireSession } from "../auth";
import { jsonError } from "../errors";
import { gateAIRequest, isProviderFailure, refundQuota } from "../ratelimit";
import type { Category } from "../policy";
import { ADAPTERS } from "./providers";
import { OPENAI_BASE, openAIUsage } from "./providers/openai";
import { sendTranscription } from "./providers/transcription";
import type { OpenAIChatBody, ProviderKeys, Usage } from "./providers/types";
import { type ChatBody, multipartField, resolveChatTask, resolveTranscriptionTask } from "./resolve";
import { routeFor } from "./routes";
import { TASKS, TASK_HEADER, type TaskId, type TaskInfo } from "./tasks";

type Ctx = Context<{ Bindings: Env }>;

// `voice` entra el 2026-10-07: el parser de voz (TranscriptionParserService) manda `X-Yala-Category: voice` a
// esta ruta, y sin `voice` en la lista caía al cubo `chat`, que en free no existe → 403 «requiere Pro» en
// cada nota de voz de la prueba gratuita desde el 2026-06-15. Decisión de Jürgen: arreglarlo ya; la cuota
// nueva (una nota = un uso) llega con la sesión 2.
const CHAT_CATEGORIES: readonly Category[] = ["chat", "vision", "voice", "insights", "suggestions"];

/**
 * La categoría que DECLARA el cliente en `X-Yala-Category`, si es una de las de la ruta; si no, `null`.
 * Sin cabecera de tarea decide el cubo, como antes de la tabla; con ella, solo tiene que casar (resolve.ts).
 */
function declaredCategory(c: Ctx, allowed: readonly Category[]): Category | null {
  const h = c.req.header("X-Yala-Category");
  return h && (allowed as readonly string[]).includes(h) ? (h as Category) : null;
}

/** ¿El cuerpo trae al menos una imagen? (`photo.read` la exige.) */
export function hasImagePart(body: ChatBody): boolean {
  const messages = Array.isArray(body.messages) ? body.messages : [];
  return messages.some(
    (m) => Array.isArray((m as { content?: unknown })?.content) && ((m as { content: unknown[] }).content).some((p) => (p as { type?: unknown })?.type === "image_url"),
  );
}

/** Tope de cuerpo y forma mínima de la tarea, ANTES de la cuota: lo que se rechaza no gasta. */
function shapeError(info: TaskInfo, task: TaskId, size: number, body: ChatBody | null): Response | null {
  if (size > info.maxBodyBytes) {
    return jsonError("yala_too_large", `La petición de ${task} pesa ${size} bytes (tope ${info.maxBodyBytes}).`, 413);
  }
  if (info.requiresImage && body && !hasImagePart(body)) {
    return jsonError("yala_bad_request", `La tarea ${task} necesita una imagen.`, 400);
  }
  return null;
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
  /** Cómo contó en la cuota: `trial` / `daily`, `note` (leyó una nota abierta), `refunded` (se devolvió). */
  quota: string;
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
      quota: entry.quota,
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
  let upstream: Response;
  try {
    upstream = await fetch(`${OPENAI_BASE}${path}`, {
      method: "POST",
      headers: upstreamHeaders(c.req.raw.headers, c.env.OPENAI_API_KEY),
      body: bytes,
    });
  } catch (err) {
    console.log(`[gw-ai] red hacia OpenAI en ${path}: ${String(err).slice(0, 120)}`);
    return { resp: jsonError("yala_upstream_error", "El proveedor de IA no respondió.", 502), usage: null, model: null };
  }
  const out = new Uint8Array(await upstream.arrayBuffer());
  const json = upstream.headers.get("content-type")?.includes("json") ? (safeJsonParse(out) as { model?: string } | null) : null;
  return {
    resp: new Response(out, { status: upstream.status, statusText: upstream.statusText, headers: upstream.headers }),
    usage: openAIUsage(json),
    model: json?.model ?? null,
  };
}

function quotaLabel(ticket: { counted: string | null } | null, refunded: boolean): string {
  if (refunded) return "refunded";
  if (!ticket) return "none";
  return ticket.counted ?? "note";
}

export async function handleChatCompletions(c: Ctx): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;
  const declared = declaredCategory(c, CHAT_CATEGORIES);

  const bytes = new Uint8Array(await c.req.arrayBuffer());
  const body = safeJsonParse(bytes) as ChatBody | null;
  if (!body || typeof body !== "object" || !Array.isArray(body.messages)) {
    return jsonError("yala_bad_request", "Cuerpo de chat inválido.", 400);
  }

  const res = resolveChatTask(c.req.header(TASK_HEADER), declared, body);
  if (!res.ok) return jsonError(res.code, res.message, res.status);
  const info: TaskInfo = TASKS[res.task];
  const category = res.category;
  const shape = shapeError(info, res.task, bytes.length, body);
  if (shape) return shape;

  const route = routeFor(res.task, res.how === "header");
  if (route.mode === "transcription") {
    return jsonError("yala_unavailable", `La tarea ${res.task} no va por el chat.`, 503);
  }
  const requested = typeof body.model === "string" ? body.model : null;
  // Antes de la cuota: una petición que se va a rechazar no gasta del cubo del usuario.
  if (route.mode === "passthrough" && (!requested || !route.allowedModels.includes(requested))) {
    return jsonError("yala_model_not_allowed", `La tarea ${res.task} no acepta el modelo ${clip(requested ?? "(vacío)")}.`, 400);
  }

  const gate = await gateAIRequest(c.env, claims, category, info.notePairing);
  if (gate.blocked) return gate.blocked;
  const started = Date.now();

  if (route.mode === "passthrough") {
    const { resp, usage, model } = await passthrough(c, "/chat/completions", bytes);
    const refunded = isProviderFailure(resp.status);
    if (refunded) await refundQuota(c.env, claims, category, gate.ticket);
    logRoute({ task: res.task, how: res.how, headerUnknown: res.headerUnknown, category, quota: quotaLabel(gate.ticket, refunded), provider: "openai", requested, model, status: resp.status, ms: Date.now() - started, usage, attempts: 1 });
    return resp;
  }

  const result = await ADAPTERS[route.provider].send(body as OpenAIChatBody, route, { keys: providerKeys(c.env) });
  const refunded = isProviderFailure(result.status);
  if (refunded) await refundQuota(c.env, claims, category, gate.ticket);
  logRoute({
    task: res.task,
    how: res.how,
    headerUnknown: res.headerUnknown,
    category,
    quota: quotaLabel(gate.ticket, refunded),
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
  const declared = declaredCategory(c, ["voice"]);

  const bytes = new Uint8Array(await c.req.arrayBuffer());
  const model = multipartField(bytes, c.req.header("content-type") ?? null, "model");
  const res = resolveTranscriptionTask(c.req.header(TASK_HEADER), declared, model);
  if (!res.ok) return jsonError(res.code, res.message, res.status);
  const info: TaskInfo = TASKS[res.task];
  const category = res.category;
  const shape = shapeError(info, res.task, bytes.length, null);
  if (shape) return shape;

  const route = routeFor(res.task, res.how === "header");
  if (route.mode === "managed") {
    return jsonError("yala_unavailable", "La transcripción no admite una fila de chat.", 503);
  }
  if (route.mode === "transcription" && route.provider !== "openai") {
    // Defensa: el adaptador de transcripción de hoy solo habla con OpenAI. Otro proveedor entra con el suyo.
    return jsonError("yala_unavailable", `La transcripción con ${route.provider} no está disponible en esta versión del gateway.`, 503);
  }
  const gate = await gateAIRequest(c.env, claims, category, info.notePairing);
  if (gate.blocked) return gate.blocked;
  const started = Date.now();

  if (route.mode === "transcription") {
    const result = await sendTranscription(bytes, c.req.header("content-type") ?? "", route, c.env.OPENAI_API_KEY);
    const refunded = isProviderFailure(result.status);
    if (refunded) await refundQuota(c.env, claims, category, gate.ticket);
    logRoute({ task: res.task, how: res.how, headerUnknown: res.headerUnknown, category, quota: quotaLabel(gate.ticket, refunded), provider: route.provider, requested: model, model: route.model, status: result.status, ms: Date.now() - started, usage: null, attempts: 1 });
    if (result.status >= 400) console.log(`[gw-ai] ${res.task} ${route.provider} ${result.status} ${upstreamErrorKind(result.body)}`);
    return new Response(result.body, { status: result.status, headers: { "content-type": "application/json" } });
  }

  const { resp } = await passthrough(c, "/audio/transcriptions", bytes);
  const refunded = isProviderFailure(resp.status);
  if (refunded) await refundQuota(c.env, claims, category, gate.ticket);
  logRoute({ task: res.task, how: res.how, headerUnknown: res.headerUnknown, category, quota: quotaLabel(gate.ticket, refunded), provider: "openai", requested: model, model, status: resp.status, ms: Date.now() - started, usage: null, attempts: 1 });
  return resp;
}
