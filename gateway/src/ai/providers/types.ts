import type { ManagedRoute } from "../routes";

/**
 * Interfaz común de los adaptadores de proveedor.
 *
 * Entrada: el cuerpo que la app manda hoy (Chat Completions de OpenAI) + la fila de la tabla.
 * Salida: SIEMPRE un `chat.completion` con la forma de OpenAI, que es lo que decodifica el SDK MacPaw de
 * la app; los errores, con el sobre `{error:{message,type,param,code}}`. Así cambiar de proveedor
 * nunca exige release.
 *
 * El banco de calidad (`gateway/bench/`) llama a estos mismos adaptadores: lo que mide es lo que sale.
 */

export interface ProviderKeys {
  openai?: string;
  gemini?: string;
  anthropic?: string;
  xai?: string;
  /** Workers AI por REST (banco) o binding (Worker, sesión 2). */
  workersai?: { accountId: string; token: string };
}

export interface Usage {
  inputTokens: number;
  outputTokens: number;
  cachedInputTokens: number;
  /** Tokens de razonamiento (ya incluidos en `outputTokens` en todos los proveedores). */
  reasoningTokens: number;
}

export interface AdapterResult {
  status: number;
  /** Cuerpo listo para devolver a la app (JSON con forma de OpenAI). */
  body: string;
  usage: Usage | null;
  /** Modelo que contestó, tal como lo dice el proveedor. */
  model: string | null;
  attempts: number;
  /** Solo diagnóstico (banco): por qué falló, sin contenido del usuario. */
  error?: string;
}

export type FetchLike = (input: string, init: RequestInit) => Promise<Response>;

export interface AdapterContext {
  keys: ProviderKeys;
  fetch?: FetchLike;
}

/** Cuerpo de Chat Completions tal como lo manda la app (solo se leen los mensajes). */
export interface OpenAIChatBody {
  messages: OpenAIMessage[];
  [k: string]: unknown;
}

export interface OpenAIMessage {
  role: "system" | "user" | "assistant" | "developer" | string;
  content: string | OpenAIContentPart[] | null;
}

export type OpenAIContentPart =
  | { type: "text"; text: string }
  | { type: "image_url"; image_url: { url: string; detail?: string } };

export interface ChatAdapter {
  send(body: OpenAIChatBody, route: ManagedRoute, ctx: AdapterContext): Promise<AdapterResult>;
}
