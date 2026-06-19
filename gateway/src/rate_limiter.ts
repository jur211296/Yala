import type { Env } from "./env";

interface DOState {
  day: string; // 'YYYY-MM-DD' UTC
  counts: Record<string, number>; // por categoría
  burst: number[]; // timestamps ms en los últimos 60s (global, anti-flood)
}

interface CheckRequest {
  category: string;
  daily: number;
  burstPerMin: number;
}

export interface RateLimitResult {
  allowed: boolean;
  reason: "daily" | "burst" | null;
}

/**
 * Durable Object: contador de cuota por keyId (consistencia fuerte, single-threaded → sin races).
 * Cuenta por categoría (reset diario UTC) + ráfaga global en ventana de 60s.
 */
export class RateLimiter {
  constructor(
    private state: DurableObjectState,
    private env: Env,
  ) {}

  async fetch(request: Request): Promise<Response> {
    const { category, daily, burstPerMin } = (await request.json()) as CheckRequest;
    const now = Date.now();
    const today = new Date(now).toISOString().slice(0, 10);

    const stored: DOState = (await this.state.storage.get<DOState>("s")) ?? { day: today, counts: {}, burst: [] };
    if (stored.day !== today) {
      stored.day = today;
      stored.counts = {};
    }

    stored.burst = stored.burst.filter((t) => now - t < 60_000);

    // Chequear ANTES de incrementar: un request bloqueado no debe consumir cuota
    // (si no, los reintentos del cliente amplifican su propio lockout).
    const dailyExceeded = (stored.counts[category] ?? 0) >= daily;
    const burstExceeded = stored.burst.length >= burstPerMin;
    const allowed = !dailyExceeded && !burstExceeded;
    if (allowed) {
      stored.counts[category] = (stored.counts[category] ?? 0) + 1;
      stored.burst.push(now);
    }
    await this.state.storage.put("s", stored);

    const result: RateLimitResult = {
      allowed,
      reason: dailyExceeded ? "daily" : burstExceeded ? "burst" : null,
    };
    return Response.json(result);
  }
}
