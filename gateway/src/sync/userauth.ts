/**
 * Auth de USUARIO (Supabase) para las rutas de sync — DISTINTA del token de sesión de App Attest.
 *
 * FIRMA DEL JWT DEL PROYECTO (verificado 2026-07-07 vía `GET /auth/v1/.well-known/jwks.json`):
 * **claves ASIMÉTRICAS ES256** (JWKS con `{kty:"EC", crv:"P-256", alg:"ES256"}`) → el árbol fijado es
 * verificación `jose` + JWKS remoto en el Worker (el diseño tal cual). NO es HS256 legacy, así que NO
 * aplica la rama "decodificar-sin-verificar". Aun así, la validación REAL de autorización la hace
 * PostgREST/RLS al recibir el token (reenviamos el MISMO JWT del usuario); esta verificación local es
 * para extraer `sub` (reinyección/telemetría) y rechazar temprano tokens obviamente inválidos.
 */
import { createRemoteJWKSet, jwtVerify } from "jose";
import type { Env } from "../env";

let jwks: ReturnType<typeof createRemoteJWKSet> | null = null;
let jwksForUrl: string | null = null;

function jwkSet(env: Env): ReturnType<typeof createRemoteJWKSet> {
  const url = `${env.SUPABASE_URL}/auth/v1/.well-known/jwks.json`;
  if (!jwks || jwksForUrl !== url) {
    jwks = createRemoteJWKSet(new URL(url));
    jwksForUrl = url;
  }
  return jwks;
}

export interface UserClaims {
  sub: string;
  token: string; // el JWT crudo — se reenvía VERBATIM a PostgREST (RLS es el árbitro final)
}

/**
 * Verifica el JWT de Supabase (ES256/JWKS) y devuelve `sub` + el token crudo, o null si inválido.
 * El `sub` es el `user_id` que se reinyecta; NUNCA se confía en un `user_id` del body.
 */
export async function verifyUserToken(env: Env, token: string): Promise<UserClaims | null> {
  try {
    const { payload } = await jwtVerify(token, jwkSet(env), {
      // El emisor OIDC de Supabase es `${SUPABASE_URL}/auth/v1`. No forzamos audience aquí
      // (Supabase usa "authenticated"); PostgREST/RLS re-valida el token de todos modos.
    });
    const sub = typeof payload.sub === "string" ? payload.sub : "";
    if (!sub) return null;
    return { sub, token };
  } catch {
    return null;
  }
}

/** Extrae el Bearer del header Authorization (el JWT del usuario en las rutas de sync). */
export function bearerToken(authHeader: string | undefined | null): string | null {
  return authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : null;
}

// --------------------------------------------------------------------------- PostgREST (JWT usuario)

/** Base de headers para PostgREST con el JWT del USUARIO (RLS activa). NUNCA service_role. */
export function postgrestHeaders(env: Env, userJWT: string, extra?: Record<string, string>): Record<string, string> {
  return {
    apikey: env.SUPABASE_ANON_KEY,
    Authorization: `Bearer ${userJWT}`,
    "Content-Type": "application/json",
    ...(extra ?? {}),
  };
}

/** Llama a un RPC de PostgREST con el JWT del usuario. Devuelve {ok, status, body}. */
export async function callRpc(
  env: Env,
  userJWT: string,
  fn: string,
  args: Record<string, unknown>,
): Promise<{ ok: boolean; status: number; body: unknown }> {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: postgrestHeaders(env, userJWT),
    body: JSON.stringify(args),
  });
  let body: unknown = null;
  const text = await res.text();
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  return { ok: res.ok, status: res.status, body };
}

/** GET a una tabla vía PostgREST con el JWT del usuario (RLS filtra a sus filas). */
export async function getRows(
  env: Env,
  userJWT: string,
  entity: string,
  query: string,
): Promise<{ ok: boolean; status: number; rows: Record<string, unknown>[]; body: unknown }> {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/${entity}?${query}`, {
    method: "GET",
    headers: postgrestHeaders(env, userJWT),
  });
  const text = await res.text();
  let body: unknown = null;
  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
  }
  const rows = Array.isArray(body) ? (body as Record<string, unknown>[]) : [];
  return { ok: res.ok, status: res.status, rows, body };
}
