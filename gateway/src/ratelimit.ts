import type { Env } from "./env";
import type { SessionClaims } from "./attest/session";
import { jsonError } from "./errors";
import { type Category, limitsFor } from "./policy";
import type { RateLimitResult } from "./rate_limiter";

/**
 * Aplica entitlement + rate-limit a un request ya autenticado.
 * Devuelve una Response de error si debe bloquearse, o null si está permitido.
 *
 * - Categoría no permitida para el tier → 403 yala_pro_required.
 * - Límite excedido + ENFORCE="enforce" → 429 (daily/burst).
 * - Límite excedido + ENFORCE="observe" → se cuenta pero NO se bloquea (ventana de rollout).
 */
export async function gateRequest(env: Env, claims: SessionClaims, category: Category): Promise<Response | null> {
  const limits = limitsFor(claims.tier, category);
  if (!limits) {
    return jsonError("yala_pro_required", "Esta función requiere Yala Pro.", 403);
  }

  const id = env.RATE_LIMITER.idFromName(claims.keyId);
  const stub = env.RATE_LIMITER.get(id);
  const res = await stub.fetch("https://ratelimiter/check", {
    method: "POST",
    body: JSON.stringify({ category, daily: limits.daily, burstPerMin: limits.burstPerMin }),
  });
  const { allowed, reason } = (await res.json()) as RateLimitResult;

  if (!allowed && env.ENFORCE === "enforce") {
    const type = reason === "burst" ? "yala_quota_burst" : "yala_quota_daily";
    return jsonError(type, "Límite de uso alcanzado. Intenta más tarde.", 429, {
      "X-Yala-Limit": reason ?? "daily",
    });
  }
  return null;
}
