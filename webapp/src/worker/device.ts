/**
 * Cómo se identifica el iPhone ante la web para «Navegadores conectados»: con el token de SU sesión de Supabase (la del
 * login de la app), en `Authorization: Bearer`. Sin cookie, sin `Origin`: no es un navegador.
 *
 * Se exige, además de la firma (JWKS del proyecto) y el emisor:
 * - `role = authenticated`: el de la app. El de la web y el del conector (`yala_mcp_reader`) no sirven aquí.
 * - SIN `client_id`: la sesión de la app no es de ningún cliente OAuth. Una sesión de la web o del conector lo lleva.
 * - `session_id` y `sub`.
 *
 * Sin App Attest, a propósito (decisión P9 del lote 1): lo único que permite es ver y cerrar las sesiones web PROPIAS,
 * y cerrar protege. Leer datos o apuntar gastos no pasa por aquí.
 */
import { createRemoteJWKSet, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "jose";
import { authIssuer, type Env } from "./env";

export type AppCheck = { ok: true; sub: string; sessionId: string } | { ok: false; reason: "invalid" | "unavailable" | "not_app" };

export type AppVerifier = (raw: string) => Promise<AppCheck>;

export function checkAppClaims(payload: JWTPayload): AppCheck {
  const sub = typeof payload.sub === "string" ? payload.sub : "";
  const sessionId = typeof payload["session_id"] === "string" ? (payload["session_id"] as string) : "";
  if (!sub || !sessionId) return { ok: false, reason: "invalid" };
  if (payload["role"] !== "authenticated" || payload["client_id"] !== undefined) return { ok: false, reason: "not_app" };
  return { ok: true, sub, sessionId };
}

let cached: { url: string; set: JWTVerifyGetKey } | null = null;

function remoteJwks(env: Env): JWTVerifyGetKey {
  const url = `${authIssuer(env)}/.well-known/jwks.json`;
  if (!cached || cached.url !== url) cached = { url, set: createRemoteJWKSet(new URL(url)) };
  return cached.set;
}

export function makeAppVerifier(env: Env, keys?: JWTVerifyGetKey): AppVerifier {
  return async (raw) => {
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(raw, keys ?? remoteJwks(env), {
        issuer: authIssuer(env),
        algorithms: ["ES256", "RS256"],
        requiredClaims: ["sub", "exp"],
      }));
    } catch (err) {
      const code = (err as { code?: unknown })?.code;
      const down = err instanceof TypeError || code === "ERR_JWKS_TIMEOUT" || code === "ERR_JWKS_NO_MATCHING_KEY";
      return { ok: false, reason: down ? "unavailable" : "invalid" };
    }
    return checkAppClaims(payload);
  };
}

const BEARER_RE = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/;

export function bearer(request: Request): string | null {
  const raw = request.headers.get("Authorization") ?? "";
  return raw.length <= 4096 ? (BEARER_RE.exec(raw)?.[1] ?? null) : null;
}
