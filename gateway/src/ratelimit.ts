import type { Env } from "./env";
import type { SessionClaims } from "./attest/session";
import { jsonError } from "./errors";
import { type Category, limitsFor } from "./policy";
import type { CheckRequest, QuotaTicket, RateLimitResult, RefundRequest } from "./rate_limiter";

/**
 * Aplica entitlement + rate-limit a un request ya autenticado.
 * Devuelve una Response de error si debe bloquearse, o null si está permitido.
 *
 * - Categoría no permitida para el tier → 403 yala_pro_required.
 * - Cupo de prueba agotado + ENFORCE="enforce" → 403 yala_trial_exhausted (la app ofrece pasarse a Pro).
 * - Límite excedido + ENFORCE="enforce" → 429 (daily/burst).
 * - Límite excedido + ENFORCE="observe" → se cuenta pero NO se bloquea (ventana de rollout).
 */
export async function gateRequest(env: Env, claims: SessionClaims, category: Category): Promise<Response | null> {
  return (await gateAIRequest(env, claims, category)).blocked;
}

export interface GateOutcome {
  blocked: Response | null;
  /** Lo que gastó el paso, para devolverlo con `refundQuota` si el proveedor falla. `null` si no gastó nada. */
  ticket: QuotaTicket | null;
}

function limiter(env: Env, claims: SessionClaims) {
  return env.RATE_LIMITER.get(env.RATE_LIMITER.idFromName(claims.keyId));
}

export async function gateAIRequest(
  env: Env,
  claims: SessionClaims,
  category: Category,
  notePairing?: "grant" | "consume",
): Promise<GateOutcome> {
  const limits = limitsFor(claims.tier, category);
  if (!limits) {
    return { blocked: jsonError("yala_pro_required", "Esta función requiere Yala Pro.", 403), ticket: null };
  }

  const check: CheckRequest = { category, burstPerMin: limits.burstPerMin, ...(limits.trial !== undefined ? { trial: limits.trial } : { daily: limits.daily }), ...(notePairing ? { notePairing } : {}) };
  const res = await limiter(env, claims).fetch("https://ratelimiter/check", { method: "POST", body: JSON.stringify(check) });
  const { allowed, reason, ticket } = (await res.json()) as RateLimitResult;

  if (!allowed && env.ENFORCE === "enforce") {
    if (reason === "trial") {
      return {
        blocked: jsonError("yala_trial_exhausted", "Ya usaste tu prueba gratuita. Con Yala Pro puedes seguir.", 403, { "X-Yala-Limit": "trial" }),
        ticket: null,
      };
    }
    const type = reason === "burst" ? "yala_quota_burst" : "yala_quota_daily";
    return {
      blocked: jsonError(type, "Límite de uso alcanzado. Intenta más tarde.", 429, { "X-Yala-Limit": reason ?? "daily" }),
      ticket: null,
    };
  }
  return { blocked: null, ticket: ticket ?? null };
}

/**
 * Devuelve lo que gastó una petición cuyo proveedor no contestó (5xx o red). Best-effort: un fallo aquí deja el uso
 * gastado, que es como estaba antes de la sesión 2.
 */
export async function refundQuota(env: Env, claims: SessionClaims, category: Category, ticket: QuotaTicket | null): Promise<void> {
  if (!ticket) return;
  const body: RefundRequest = { op: "refund", category, ticket };
  try {
    await limiter(env, claims).fetch("https://ratelimiter/refund", { method: "POST", body: JSON.stringify(body) });
  } catch (err) {
    console.log(`[gw-ai] refund fallido ${category}: ${String(err).slice(0, 120)}`);
  }
}

/** ¿Este status del proveedor es un fallo suyo (no del usuario) que no debe gastar cupo? */
export function isProviderFailure(status: number): boolean {
  return status >= 500 || status === 429 || status === 408;
}
