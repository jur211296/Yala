/**
 * Verificación de los tokens de Supabase que guarda el Worker. Claude ya no ve ninguno (ver `authorize.ts`): recibe
 * un token opaco del propio Worker, y el Worker lee las finanzas con una sesión de Supabase que consiguió como
 * cliente OAuth propio de Supabase.
 *
 * Esa sesión se verifica al recibirla (canje del código y cada refresh) y en cada uso, con el JWKS del proyecto
 * (ES256, el mismo que usa el gateway). Además de la firma se exige:
 *
 * - `client_id` = el cliente del Worker. Es el único al que el hook de Supabase deja recibir tokens
 *   (`qa/cloud/mcp0_02_oauth_client_allowlist.sql`); un token de la app, o de cualquier otro cliente, no sirve aquí.
 * - `role = yala_mcp_reader`: lo pone ese hook. Con ese rol PostgREST no deja escribir ni ejecutar las RPC de
 *   escritura.
 * - `session_id`: sin él no se puede comprobar que la sesión siga viva (revocación al momento).
 * - `sub` = el usuario del grant, cuando se conoce: un refresh no puede cambiar de usuario.
 *
 * Todo falla CERRADO: si alguien apaga el hook, los tokens vuelven con `role = authenticated` —que sí escribe— y el
 * Worker deja de atender en vez de atender con un token que escribe.
 *
 * Lo que NO se comprueba y por qué: la audiencia. Supabase emite `aud = "authenticated"` y no implementa RFC 8707.
 * La audiencia que importa ahora es la del token de Claude, que es del Worker y está atada a `…/mcp`.
 */
import { createRemoteJWKSet, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "jose";
import { authIssuer, resourceMetadataUrl, type Env } from "./env";

export const READER_ROLE = "yala_mcp_reader";

export interface UpstreamClaims {
  /** user_id de Supabase. Nunca se usa para filtrar: el filtro lo pone RLS con el propio token. */
  sub: string;
  sessionId: string;
  /** `exp` del JWT, en segundos Unix. */
  exp: number;
}

export type UpstreamCheck =
  | { ok: true; claims: UpstreamClaims }
  // `unavailable`: no se pudo verificar AHORA (el JWKS de Supabase no respondió, red). NO es un token malo: no se
  // borra la conexión, se reintenta. El resto son veredictos firmes sobre un token que sí llegó a verificarse.
  | { ok: false; reason: "invalid" | "unavailable" | "not_worker_client" | "not_read_only" | "no_session" | "wrong_user" };

export type UpstreamVerifier = (raw: string, expectedSub?: string) => Promise<UpstreamCheck>;

let cachedJwks: { url: string; set: JWTVerifyGetKey } | null = null;

function remoteJwks(env: Env): JWTVerifyGetKey {
  const url = `${authIssuer(env)}/.well-known/jwks.json`;
  if (!cachedJwks || cachedJwks.url !== url) {
    cachedJwks = { url, set: createRemoteJWKSet(new URL(url)) };
  }
  return cachedJwks.set;
}

/** Comprobaciones de claims, separadas de la firma para poder probarlas sin red. */
export function checkUpstreamClaims(payload: JWTPayload, env: Env, expectedSub?: string): UpstreamCheck {
  const sub = typeof payload.sub === "string" ? payload.sub : "";
  if (!sub || typeof payload.exp !== "number") return { ok: false, reason: "invalid" };
  if (!env.SUPABASE_OAUTH_CLIENT_ID || payload["client_id"] !== env.SUPABASE_OAUTH_CLIENT_ID) {
    return { ok: false, reason: "not_worker_client" };
  }
  if (payload["role"] !== READER_ROLE) return { ok: false, reason: "not_read_only" };
  const sessionId = typeof payload["session_id"] === "string" ? (payload["session_id"] as string) : "";
  if (!sessionId) return { ok: false, reason: "no_session" };
  if (expectedSub !== undefined && sub !== expectedSub) return { ok: false, reason: "wrong_user" };
  return { ok: true, claims: { sub, sessionId, exp: payload.exp } };
}

/**
 * ¿El fallo de `jwtVerify` es porque no se pudo BAJAR o usar el JWKS (red, timeout, respuesta no-200, rotación de
 * claves), en vez de porque el token esté mal firmado o caducado? En el primer caso no se sabe si el token vale, así
 * que no se borra nada: se reintenta. jose marca esos casos con un `code` propio, y una caída de red es un `TypeError`.
 * Como los únicos tokens que verificamos son los que Supabase nos emitió a nosotros, un «no hay clave que case» es casi
 * siempre una rotación a medio propagar, no un ataque: también cuenta como no disponible.
 */
function isJwksUnavailable(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  if (code === "ERR_JWKS_TIMEOUT" || code === "ERR_JWKS_NO_MATCHING_KEY" || code === "ERR_JWKS_MULTIPLE_MATCHING_KEYS") return true;
  if (err instanceof TypeError) return true; // fetch rechazado (red)
  const msg = err instanceof Error ? err.message : "";
  return /Expected 200 OK|fetch failed|Failed to fetch|timed? ?out|network/i.test(msg);
}

export function makeUpstreamVerifier(env: Env, keys?: JWTVerifyGetKey): UpstreamVerifier {
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
    return checkUpstreamClaims(payload, env, expectedSub);
  };
}

/**
 * Cabecera del 401 que pide la especificación de autorización de MCP: apunta a los metadatos del recurso
 * protegido, de donde el cliente saca el servidor de autorización (este Worker). La del 401 sin token la pone la
 * librería; esta es para cuando el token de Claude es bueno pero la sesión de Supabase que representa ya no.
 */
export function invalidTokenChallenge(env: Env, description: string): string {
  // RFC 6750 §3: error_description solo admite ASCII visible sin comillas ni barra invertida.
  const safe = description.replace(/[^\x20-\x21\x23-\x5b\x5d-\x7e]/g, "");
  return [
    `Bearer realm="OAuth"`,
    `resource_metadata="${resourceMetadataUrl(env)}"`,
    `error="invalid_token"`,
    `error_description="${safe}"`,
  ].join(", ");
}
