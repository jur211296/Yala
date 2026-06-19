import type { Context } from "hono";
import type { Env } from "../env";
import { requireSession } from "../auth";
import { gateRequest } from "../ratelimit";
import type { Category } from "../policy";

type Ctx = Context<{ Bindings: Env }>;

const OPENAI_BASE = "https://api.openai.com";
const CHAT_CATEGORIES: readonly Category[] = ["chat", "vision", "insights", "suggestions"];

/**
 * Categoría de cuota desde el header X-Yala-Category (best-effort: solo elige el bucket de límite,
 * no es frontera de seguridad — esa la dan attestation + el tope por device). El cliente la setea
 * por servicio. Default si falta/ inválida.
 */
function categoryFrom(c: Ctx, allowed: readonly Category[], fallback: Category): Category {
  const h = c.req.header("X-Yala-Category");
  return h && (allowed as readonly string[]).includes(h) ? (h as Category) : fallback;
}

/** Headers hacia OpenAI: preserva content-type (incl. boundary multipart) + inyecta la key real. */
function upstreamHeaders(incoming: Headers, openaiKey: string): Headers {
  const h = new Headers();
  const ct = incoming.get("content-type");
  if (ct) h.set("content-type", ct);
  const accept = incoming.get("accept");
  if (accept) h.set("accept", accept);
  h.set("authorization", `Bearer ${openaiKey}`);
  return h;
}

async function proxy(c: Ctx, path: string, category: Category): Promise<Response> {
  const claims = await requireSession(c);
  if (claims instanceof Response) return claims;
  const blocked = await gateRequest(c.env, claims, category);
  if (blocked) return blocked;

  // Passthrough del body como stream (chat JSON o multipart de audio) — sin bufferizar, sin loguear.
  const init: RequestInit = {
    method: "POST",
    headers: upstreamHeaders(c.req.raw.headers, c.env.OPENAI_API_KEY),
    body: c.req.raw.body,
  };
  const resp = await fetch(`${OPENAI_BASE}${path}`, init);
  // Respuesta verbatim (stream-ready) → el SDK MacPaw la parsea igual que hoy.
  return new Response(resp.body, { status: resp.status, statusText: resp.statusText, headers: resp.headers });
}

export function handleChatCompletions(c: Ctx): Promise<Response> {
  return proxy(c, "/v1/chat/completions", categoryFrom(c, CHAT_CATEGORIES, "chat"));
}

export function handleAudioTranscriptions(c: Ctx): Promise<Response> {
  return proxy(c, "/v1/audio/transcriptions", "voice");
}
