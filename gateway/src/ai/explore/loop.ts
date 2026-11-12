import type { ToolContext } from "../../../../mcp/src/toolCore";
import { InvalidInputError } from "../../../../mcp/src/logic/dates";
import { UpstreamError } from "../../../../mcp/src/data";
import { errorResult } from "../providers/common";
import { buildOpenAIBody, OPENAI_BASE, openAIUsage } from "../providers/openai";
import type { AdapterResult, FetchLike, OpenAIChatBody, Usage } from "../providers/types";
import type { ManagedRoute } from "../routes";
import { withExploreAddendum } from "./prompt";
import { EXPLORE_TOOLS, exploreArgs, openAIToolDefinitions } from "./tools";

/**
 * El bucle del camino ampliado: el modelo contesta o pide herramientas; el gateway las ejecuta contra las tablas del
 * usuario y le devuelve los resultados, hasta que contesta o se agotan los topes. La respuesta que vuelve a la app es la
 * última de OpenAI tal cual: la app no distingue este camino del de `chat.answer`.
 *
 * Los topes son por PREGUNTA y existen por coste y por tiempo (la app espera 30 s): pasado cualquiera de ellos, la
 * última llamada sale con `tool_choice: "none"` y el modelo contesta con lo que ya tiene.
 */
export interface ExploreLimits {
  /** Rondas con herramientas (cada ronda es una llamada al modelo que pide herramientas). */
  readonly maxRounds: number;
  /** Herramientas ejecutadas en toda la pregunta. */
  readonly maxToolCalls: number;
  /** Caracteres del resultado de una herramienta que llegan al modelo. */
  readonly maxResultChars: number;
  /** A partir de aquí no se empieza otra ronda con herramientas. */
  readonly softDeadlineMs: number;
  /** Lo más que espera una herramienta; pasado, el modelo recibe un error y sigue con lo que tiene. */
  readonly toolTimeoutMs: number;
}

/**
 * Presupuesto de tiempo, contra los 30 s de la app: una ronda que empieza justo antes de los 12 s tarda como mucho una
 * llamada al modelo (≈2-3 s) + 6 s de herramientas EN PARALELO, y la última llamada sin herramientas, otros ≈3 s.
 */
export const EXPLORE_LIMITS: ExploreLimits = {
  maxRounds: 3,
  maxToolCalls: 4,
  maxResultChars: 16_000,
  softDeadlineMs: 12_000,
  toolTimeoutMs: 6_000,
};

export interface ExploreStats {
  rounds: number;
  /** Nombres de las herramientas ejecutadas, en orden (nunca sus argumentos: pueden citar al usuario). */
  tools: string[];
  /** Caracteres de resultados que se le dieron al modelo. */
  resultChars: number;
  /** La última llamada salió sin herramientas porque se agotó un tope. */
  forcedFinal: boolean;
  /** Herramientas que devolvieron error. */
  toolErrors: number;
  /** Una llamada con herramientas falló y se repitió la pregunta sin ellas (como `chat.answer`). */
  fellBack: boolean;
}

export interface ExploreResult extends AdapterResult {
  stats: ExploreStats;
}

export interface ExploreDeps {
  openaiKey: string | undefined;
  /** Hacia OpenAI. Las lecturas de Supabase van por el lector de `toolContext`. */
  fetch?: FetchLike;
  toolContext: ToolContext;
  /** Zona horaria del teléfono, ya validada. */
  timeZone: string;
  clock?: () => number;
  limits?: ExploreLimits;
}

type LoopMessage = Record<string, unknown>;

interface ToolCall {
  id: string;
  type?: string;
  function?: { name?: unknown; arguments?: unknown };
}

interface CompletionJson {
  model?: string;
  choices?: { message?: { role?: string; content?: string | null; tool_calls?: ToolCall[] }; finish_reason?: string }[];
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function addUsage(total: Usage | null, u: Usage | null): Usage | null {
  if (!u) return total;
  if (!total) return { ...u };
  return {
    inputTokens: total.inputTokens + u.inputTokens,
    outputTokens: total.outputTokens + u.outputTokens,
    cachedInputTokens: total.cachedInputTokens + u.cachedInputTokens,
    reasoningTokens: total.reasoningTokens + u.reasoningTokens,
  };
}

/** Nombre para el log: solo los de la lista. Uno inventado por el modelo podría citar al usuario. */
function logName(name: string): string {
  return EXPLORE_TOOLS.has(name) ? name : "?";
}

/**
 * Un resultado que no cabe: si trae `movimientos`, se quitan de la cola hasta que quepa y se dice (el cursor ya no
 * valdría, así que se retira); si no, se corta el texto y se dice.
 */
export function fitResult(result: unknown, maxChars: number): string {
  const text = JSON.stringify(result);
  if (text.length <= maxChars) return text;
  const r = result as { movimientos?: unknown[]; avisos?: unknown } | null;
  if (r && Array.isArray(r.movimientos) && r.movimientos.length > 1) {
    const total = r.movimientos.length;
    let keep = total;
    let candidate = text;
    while (keep > 1 && candidate.length > maxChars) {
      keep = Math.max(1, Math.floor(keep * 0.8));
      const avisos = [
        ...(Array.isArray(r.avisos) ? r.avisos : []),
        `Solo caben ${keep} de ${total} movimientos en la respuesta: pide un rango más corto o un límite menor para ver el resto.`,
      ];
      candidate = JSON.stringify({ ...r, movimientos: r.movimientos.slice(0, keep), siguiente_cursor: null, avisos });
    }
    if (candidate.length <= maxChars) return candidate;
  }
  return `${text.slice(0, maxChars)}… [recortado: pide un periodo más corto o menos movimientos]`;
}

class ToolTimeout extends Error {}

function withTimeout<T>(work: Promise<T>, ms: number): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new ToolTimeout()), ms);
  });
  return Promise.race([work, timeout]).finally(() => {
    if (timer !== undefined) clearTimeout(timer);
  });
}

/** Resultado de una herramienta como texto para el modelo, recortado al tope. Nunca lanza. */
export async function runExploreTool(
  call: ToolCall,
  deps: ExploreDeps,
  maxChars: number,
  timeoutMs: number = EXPLORE_LIMITS.toolTimeoutMs,
): Promise<{ name: string; content: string; ok: boolean }> {
  const name = typeof call.function?.name === "string" ? call.function.name : "";
  const tool = EXPLORE_TOOLS.get(name);
  if (!tool) return { name: "?", content: JSON.stringify({ error: "Esa herramienta no existe." }), ok: false };
  let raw: unknown = {};
  if (typeof call.function?.arguments === "string" && call.function.arguments.trim()) {
    raw = safeJson(call.function.arguments);
    if (raw === null) return { name, content: JSON.stringify({ error: "Los argumentos no son JSON válido." }), ok: false };
  }
  try {
    const args = exploreArgs(tool.spec, raw, deps.timeZone);
    const result = await withTimeout(tool.core.run(deps.toolContext, args), timeoutMs);
    return { name, content: fitResult(result, maxChars), ok: true };
  } catch (err) {
    // Un argumento mal formado se le explica al modelo para que lo corrija; lo demás, sin detalle (podría citar la
    // respuesta de PostgREST).
    if (err instanceof InvalidInputError) return { name, content: JSON.stringify({ error: err.message }), ok: false };
    if (err instanceof ToolTimeout) {
      console.log(`[gw-ai] chat.explore ${name}: tardó más de ${timeoutMs} ms`);
      return { name, content: JSON.stringify({ error: "Esa consulta tardó demasiado. Responde con lo que ya tienes o pide algo más acotado." }), ok: false };
    }
    const kind = err instanceof UpstreamError ? `lectura ${err.status}` : `fallo ${err instanceof Error ? err.name : "?"}`;
    console.log(`[gw-ai] chat.explore ${name}: ${kind}`);
    return { name, content: JSON.stringify({ error: "No se pudieron leer esos datos ahora." }), ok: false };
  }
}

export async function runExplore(body: OpenAIChatBody, route: ManagedRoute, deps: ExploreDeps): Promise<ExploreResult> {
  const limits = deps.limits ?? EXPLORE_LIMITS;
  const clock = deps.clock ?? Date.now;
  const doFetch = deps.fetch ?? ((input: string, init: RequestInit) => fetch(input, init));
  const started = clock();
  const stats: ExploreStats = { rounds: 0, tools: [], resultChars: 0, forcedFinal: false, toolErrors: 0, fellBack: false };
  if (!deps.openaiKey) return { ...errorResult(503, "openai", "sin clave configurada", 0), stats };

  const tools = openAIToolDefinitions();
  const messages: LoopMessage[] = withExploreAddendum(body.messages) as unknown as LoopMessage[];
  let usage: Usage | null = null;
  let attempts = 0;

  for (;;) {
    const allowTools =
      stats.rounds < limits.maxRounds && stats.tools.length < limits.maxToolCalls && clock() - started < limits.softDeadlineMs;
    const payload = buildOpenAIBody({ messages: [] }, route);
    payload.messages = messages;
    payload.tools = tools;
    // Con herramientas ya usadas el historial lleva `tool_calls`: OpenAI exige `tools` aunque no se puedan pedir más.
    payload.tool_choice = allowTools ? "auto" : "none";
    if (!allowTools) stats.forcedFinal = stats.rounds > 0;

    let resp: Response;
    try {
      attempts++;
      resp = await doFetch(`${OPENAI_BASE}/chat/completions`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${deps.openaiKey}` },
        body: JSON.stringify(payload),
      });
    } catch (err) {
      return { ...errorResult(502, "openai", `red: ${String(err)}`, attempts), usage, stats };
    }
    const text = await resp.text();
    const json = safeJson(text) as CompletionJson | null;
    usage = addUsage(usage, openAIUsage(json));
    if (!resp.ok) {
      // Tras una ronda con herramientas, un fallo puede ser del historial que montó el gateway (p. ej. demasiado
      // contexto): la pregunta se repite UNA vez sin herramientas, como `chat.answer`, para que el usuario reciba su
      // respuesta. En la primera llamada no: ahí la petición es la de siempre y su error es el de siempre.
      if (stats.rounds > 0 && !stats.fellBack) {
        stats.fellBack = true;
        const plain = buildOpenAIBody(body, route);
        try {
          attempts++;
          const again = await doFetch(`${OPENAI_BASE}/chat/completions`, {
            method: "POST",
            headers: { "content-type": "application/json", authorization: `Bearer ${deps.openaiKey}` },
            body: JSON.stringify(plain),
          });
          const againText = await again.text();
          const againJson = safeJson(againText) as CompletionJson | null;
          usage = addUsage(usage, openAIUsage(againJson));
          return { status: again.status, body: againText, usage, model: againJson?.model ?? null, attempts, stats };
        } catch (err) {
          return { ...errorResult(502, "openai", `red: ${String(err)}`, attempts), usage, stats };
        }
      }
      return { status: resp.status, body: text, usage, model: null, attempts, error: `openai ${resp.status}: ${text.slice(0, 300)}`, stats };
    }

    const message = json?.choices?.[0]?.message;
    const calls = Array.isArray(message?.tool_calls) ? message.tool_calls : [];
    if (calls.length === 0 || !allowTools) {
      // Respuesta final. Si con `tool_choice: none` aún trajera llamadas (no debería), la app lee `content` igual.
      return { status: resp.status, body: text, usage, model: json?.model ?? null, attempts, stats };
    }

    stats.rounds++;
    messages.push({ role: "assistant", content: message?.content ?? null, tool_calls: calls });
    // Las de una misma ronda corren EN PARALELO: en serie, cuatro lecturas de un año podían comerse los 30 s de la app.
    const budget = Math.max(0, limits.maxToolCalls - stats.tools.length);
    const runnable = calls.slice(0, budget);
    const results = await Promise.all(runnable.map((call) => runExploreTool(call, deps, limits.maxResultChars, limits.toolTimeoutMs)));
    calls.forEach((call, i) => {
      // Cada `tool_call_id` necesita su respuesta, o OpenAI rechaza la siguiente llamada.
      const r = results[i];
      if (!r) {
        messages.push({ role: "tool", tool_call_id: call.id, content: JSON.stringify({ error: "Se alcanzó el número de consultas de esta pregunta. Responde con lo que ya tienes." }) });
        return;
      }
      stats.tools.push(logName(r.name));
      stats.resultChars += r.content.length;
      if (!r.ok) stats.toolErrors++;
      messages.push({ role: "tool", tool_call_id: call.id, content: r.content });
    });
  }
}
