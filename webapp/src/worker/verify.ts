/**
 * Verificación de la sesión de solo lectura que guarda la web: firma (JWKS del proyecto, como el gateway y el conector)
 * y, además:
 *
 * - `client_id` = el cliente OAuth de la web. Un token de la app o del conector no sirve aquí.
 * - `role = yala_mcp_reader`: lo pone el hook de Supabase (`webapp/supabase/web0_01_hook_web_client.sql`). Con ese rol
 *   PostgREST no deja escribir. Si alguien apagara el hook, el token volvería con `authenticated` —que escribe— y la
 *   web dejaría de dejar entrar en vez de guardar un token que escribe: falla CERRADO.
 * - `session_id`, y `sub` = el usuario que acaba de entrar (o el de la sesión, al refrescar).
 */
import { createRemoteJWKSet, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "jose";
import { authIssuer, type Env } from "./env";

export const READER_ROLE = "yala_mcp_reader";

export interface ReaderClaims {
  sub: string;
  sessionId: string;
  exp: number;
}

export type ReaderCheck =
  | { ok: true; claims: ReaderClaims }
  | { ok: false; reason: "invalid" | "unavailable" | "not_web_client" | "not_read_only" | "no_session" | "wrong_user" };

export type ReaderVerifier = (raw: string, expectedSub: string) => Promise<ReaderCheck>;

export function checkReaderClaims(payload: JWTPayload, env: Env, expectedSub: string): ReaderCheck {
  const sub = typeof payload.sub === "string" ? payload.sub : "";
  if (!sub || typeof payload.exp !== "number") return { ok: false, reason: "invalid" };
  if (!env.SUPABASE_OAUTH_CLIENT_ID || payload["client_id"] !== env.SUPABASE_OAUTH_CLIENT_ID) return { ok: false, reason: "not_web_client" };
  if (payload["role"] !== READER_ROLE) return { ok: false, reason: "not_read_only" };
  const sessionId = typeof payload["session_id"] === "string" ? (payload["session_id"] as string) : "";
  if (!sessionId) return { ok: false, reason: "no_session" };
  if (sub !== expectedSub) return { ok: false, reason: "wrong_user" };
  return { ok: true, claims: { sub, sessionId, exp: payload.exp } };
}

/** El fallo es de no poder BAJAR o usar las claves (red, rotación), no de un token malo: no se borra nada. */
function isJwksUnavailable(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  if (code === "ERR_JWKS_TIMEOUT" || code === "ERR_JWKS_NO_MATCHING_KEY" || code === "ERR_JWKS_MULTIPLE_MATCHING_KEYS") return true;
  if (err instanceof TypeError) return true;
  const msg = err instanceof Error ? err.message : "";
  return /Expected 200 OK|fetch failed|Failed to fetch|timed? ?out|network/i.test(msg);
}

let cachedJwks: { url: string; set: JWTVerifyGetKey } | null = null;

function remoteJwks(env: Env): JWTVerifyGetKey {
  const url = `${authIssuer(env)}/.well-known/jwks.json`;
  if (!cachedJwks || cachedJwks.url !== url) cachedJwks = { url, set: createRemoteJWKSet(new URL(url)) };
  return cachedJwks.set;
}

export function makeReaderVerifier(env: Env, keys?: JWTVerifyGetKey): ReaderVerifier {
  return async (raw, expectedSub) => {
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(raw, keys ?? remoteJwks(env), {
        issuer: authIssuer(env),
        algorithms: ["ES256", "RS256"],
        requiredClaims: ["sub", "exp"],
      }));
    } catch (err) {
      return { ok: false, reason: isJwksUnavailable(err) ? "unavailable" : "invalid" };
    }
    return checkReaderClaims(payload, env, expectedSub);
  };
}
