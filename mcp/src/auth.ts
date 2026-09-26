/**
 * Validación del token que manda Claude en cada llamada a /mcp.
 *
 * El token lo emite el servidor OAuth de Supabase Auth, no este Worker. Se verifica con el JWKS del proyecto
 * (ES256, el mismo que usa el gateway) y además se exige que sea un token DE SOLO LECTURA:
 *
 * - `client_id` presente: solo lo llevan los tokens emitidos a un cliente OAuth. Un token de la app (SIWA, Google,
 *   contraseña) no lo trae, así que aquí no sirve aunque su firma sea buena.
 * - `role = yala_mcp_reader`: lo pone el hook `yala_mcp_access_token_hook` (qa/cloud/mcp0_01_readonly_role.sql).
 *   Con ese rol, PostgREST no deja escribir nada ni ejecutar las RPC de escritura.
 *
 * Las dos condiciones fallan CERRADO a propósito: si alguien apaga el hook, los tokens de Claude vuelven a salir con
 * `role = authenticated` —que sí escribe— y el MCP deja de atender en vez de atender con un token que escribe.
 *
 * Lo que NO se comprueba y por qué: la audiencia. Supabase emite `aud = "authenticated"` y no implementa todavía el
 * parámetro `resource` de RFC 8707, así que no hay audiencia propia que exigir. Lo anota la exploración (§7).
 */
import { createRemoteJWKSet, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "jose";
import { authIssuer, type Env } from "./env";

export const READER_ROLE = "yala_mcp_reader";

export interface VerifiedToken {
  /** user_id de Supabase. Nunca se usa para filtrar: el filtro lo pone RLS con el propio token. */
  sub: string;
  clientId: string;
  sessionId: string | null;
  expiresAt: number;
  /** El JWT tal cual, para reenviarlo a PostgREST. */
  raw: string;
}

export type VerifyResult =
  | { ok: true; token: VerifiedToken }
  | { ok: false; reason: "missing" | "invalid" | "not_oauth_client" | "not_read_only" };

export type TokenVerifier = (raw: string | null) => Promise<VerifyResult>;

let cachedJwks: { url: string; set: JWTVerifyGetKey } | null = null;

function remoteJwks(env: Env): JWTVerifyGetKey {
  const url = `${authIssuer(env)}/.well-known/jwks.json`;
  if (!cachedJwks || cachedJwks.url !== url) {
    cachedJwks = { url, set: createRemoteJWKSet(new URL(url)) };
  }
  return cachedJwks.set;
}

/** Comprobaciones de claims, separadas de la firma para poder probarlas sin red. */
export function checkClaims(payload: JWTPayload, raw: string): VerifyResult {
  const sub = typeof payload.sub === "string" ? payload.sub : "";
  if (!sub) return { ok: false, reason: "invalid" };
  const clientId = typeof payload["client_id"] === "string" ? (payload["client_id"] as string) : "";
  if (!clientId) return { ok: false, reason: "not_oauth_client" };
  if (payload["role"] !== READER_ROLE) return { ok: false, reason: "not_read_only" };
  const sessionId = typeof payload["session_id"] === "string" ? (payload["session_id"] as string) : null;
  return {
    ok: true,
    token: { sub, clientId, sessionId, expiresAt: typeof payload.exp === "number" ? payload.exp : 0, raw },
  };
}

export function makeVerifier(env: Env, keys?: JWTVerifyGetKey): TokenVerifier {
  return async (raw) => {
    if (!raw) return { ok: false, reason: "missing" };
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(raw, keys ?? remoteJwks(env), {
        issuer: authIssuer(env),
        algorithms: ["ES256", "RS256"],
        requiredClaims: ["sub", "exp"],
      }));
    } catch {
      return { ok: false, reason: "invalid" };
    }
    return checkClaims(payload, raw);
  };
}

export function bearer(header: string | null): string | null {
  if (!header) return null;
  const m = /^Bearer\s+(.+)$/i.exec(header.trim());
  return m?.[1]?.trim() || null;
}

/**
 * Cabecera del 401 que pide la especificación de autorización de MCP: apunta a los metadatos del recurso
 * protegido, de donde el cliente saca el servidor de autorización.
 */
export function wwwAuthenticate(resourceMetadataUrl: string, reason: string): string {
  const parts = [`Bearer resource_metadata="${resourceMetadataUrl}"`];
  if (reason !== "missing") {
    parts.push(`error="invalid_token"`);
    parts.push(`error_description="${describe(reason)}"`);
  }
  return parts.join(", ");
}

function describe(reason: string): string {
  switch (reason) {
    case "not_oauth_client":
      return "El token no es de un cliente OAuth";
    case "not_read_only":
      return "El token no es de solo lectura";
    default:
      return "Token no valido o caducado";
  }
}
