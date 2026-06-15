import type { Context } from "hono";
import type { Env } from "./env";
import { jsonError } from "./errors";
import { type SessionClaims, verifySessionToken } from "./attest/session";

/**
 * Exige un token de sesión válido (Bearer). Devuelve los claims, o una Response de error
 * (OpenAI-compatible) si falta/expiró → el cliente re-atesta.
 */
export async function requireSession(c: Context<{ Bindings: Env }>): Promise<SessionClaims | Response> {
  const auth = c.req.header("Authorization");
  const token = auth?.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return jsonError("yala_attest_required", "Falta token de sesión.", 401);
  const claims = await verifySessionToken(c.env, token);
  if (!claims) return jsonError("yala_attest_invalid", "Token de sesión inválido o expirado.", 401);
  return claims;
}
