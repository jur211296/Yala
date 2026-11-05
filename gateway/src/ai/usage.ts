import type { Env } from "../env";
import type { Usage } from "./providers/types";

/**
 * Registro de uso de cada llamada de IA (card «No se guarda cuántos tokens gasta cada función de IA», 2026-11-04).
 *
 * Una fila por petición que salió hacia el proveedor: qué función (`task`), con qué proveedor y modelo, cuántos tokens
 * de entrada (y de ellos, de caché), de salida (y de ellos, de razonamiento), por qué terminó (`finish_reason`) y el
 * estado. **Nada del contenido ni del usuario**: ni mensajes, ni respuesta, ni keyId, ni JWT. Lo fija
 * `test/ai.usage.test.ts`.
 *
 * Dónde se guarda vive detrás de `AIUsageSink`: el registro no depende del sitio. Hoy, Analytics Engine (`usageSink`).
 */
export interface AIUsageRecord {
  task: string;
  category: string;
  provider: string;
  model: string | null;
  status: number;
  finishReason: string | null;
  inputTokens: number | null;
  cachedInputTokens: number | null;
  outputTokens: number | null;
  reasoningTokens: number | null;
  ms: number;
  attempts: number;
}

export interface AIUsageSink {
  record(entry: AIUsageRecord): void;
}

export function usageRecord(args: {
  task: string;
  category: string;
  provider: string;
  model: string | null;
  status: number;
  finishReason: string | null;
  usage: Usage | null;
  ms: number;
  attempts: number;
}): AIUsageRecord {
  return {
    task: args.task,
    category: args.category,
    provider: args.provider,
    model: args.model,
    status: args.status,
    finishReason: args.finishReason,
    inputTokens: args.usage?.inputTokens ?? null,
    cachedInputTokens: args.usage?.cachedInputTokens ?? null,
    outputTokens: args.usage?.outputTokens ?? null,
    reasoningTokens: args.usage?.reasoningTokens ?? null,
    ms: args.ms,
    attempts: args.attempts,
  };
}

const NOOP_SINK: AIUsageSink = { record() {} };

/**
 * Columnas de Analytics Engine, por posición (el SQL de la consulta las nombra `blob1…`, `double1…`). Un campo nuevo va
 * AL FINAL: mover uno rompe las consultas guardadas y la serie.
 *   blobs   [task, category, provider, model, finishReason]
 *   doubles [status, inputTokens, cachedInputTokens, outputTokens, reasoningTokens, ms, attempts, hasUsage]
 *   indexes [task]
 * Los tokens desconocidos (error, transcripción) van a 0 con `hasUsage = 0`, para que las sumas no se ensucien.
 */
export function analyticsEngineSink(dataset: AnalyticsEngineDataset): AIUsageSink {
  return {
    record(e) {
      dataset.writeDataPoint({
        blobs: [e.task, e.category, e.provider, e.model ?? "", e.finishReason ?? ""],
        doubles: [
          e.status,
          e.inputTokens ?? 0,
          e.cachedInputTokens ?? 0,
          e.outputTokens ?? 0,
          e.reasoningTokens ?? 0,
          e.ms,
          e.attempts,
          e.inputTokens === null ? 0 : 1,
        ],
        indexes: [e.task],
      });
    },
  };
}

/**
 * El sitio donde se guarda: Analytics Engine, dataset `yala_ai_usage` (`_staging` en staging), decisión de Jürgen del
 * 2026-11-04. Guarda 90 días; si hiciera falta más historia, la idea aprobada es un resumen mensual aparte. Sin el
 * binding (tests, entorno sin configurar) no hace nada, y un fallo al guardar tampoco llega al usuario.
 */
export function usageSink(env: Env): AIUsageSink {
  return env.AI_USAGE ? analyticsEngineSink(env.AI_USAGE) : NOOP_SINK;
}

/** Guarda sin lanzar nunca: un registro roto no puede tumbar la respuesta que ya pagó el usuario. */
export function recordUsage(sink: AIUsageSink, entry: AIUsageRecord): void {
  try {
    sink.record(entry);
  } catch (err) {
    console.log(`[gw-ai] registro de uso falló: ${err instanceof Error ? err.name : "?"}`);
  }
}
