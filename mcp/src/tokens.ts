/**
 * Qué guarda cada conexión de Claude y cómo se renueva.
 *
 * La librería (`@cloudflare/workers-oauth-provider`) guarda por cada conexión un GRANT y sus tokens, solo por hash,
 * y unos `props` cifrados con una clave que envuelve el propio token: leer el KV no revela nada. Aquí se decide qué
 * va en esos `props`:
 *
 * - En el GRANT (`GrantProps`): el REFRESH de Supabase. Solo se descifra con el refresh token de Claude.
 * - En cada ACCESS TOKEN de Claude (`AccessProps`): el ACCESS de Supabase. Solo se descifra con ese access token.
 *
 * Así cada credencial de Supabase viaja pegada a la de Claude que le corresponde, y ninguna sale del Worker.
 *
 * Caducidad:
 * - El access token de Claude caduca un minuto antes que el de Supabase que lleva dentro, así Claude refresca antes
 *   de que el de dentro deje de valer.
 * - La conexión caduca a los 30 días sin usarse (`GRANT_IDLE_SECONDS`, deslizante).
 * - Y a los 90 días de autorizarla hay que volver a conectar aunque se use (`GRANT_MAX_AGE_SECONDS`), como en las
 *   apps que leen datos bancarios. En staging la sesión de Supabase no caduca nunca sola: esto la acota.
 *
 * Rotación: la del token de Claude la hace la librería; la de Supabase se hace aquí, en cada refresh, y se guarda en
 * la MISMA escritura del grant. Si Supabase dice que la sesión ya no vale, se lanza `invalid_grant` y la librería
 * borra la conexión: Claude vuelve a pedir permiso. Si Supabase no contesta, `temporarily_unavailable` y la conexión
 * se conserva para el reintento.
 */
import { OAuthError, type TokenExchangeCallbackOptions, type TokenExchangeCallbackResult } from "@cloudflare/workers-oauth-provider";
import type { UpstreamVerifier } from "./auth";
import type { Env } from "./env";
import type { Fetcher } from "./egress";
import { refreshTokens } from "./upstream";
import { auditEvent } from "./audit";

export const SCOPE = "lectura";
export const GRANT_IDLE_SECONDS = 30 * 86_400;
export const GRANT_MAX_AGE_SECONDS = 90 * 86_400;
/** Lo que el token de Claude caduca antes que el de Supabase que lleva dentro. */
export const UPSTREAM_MARGIN_SECONDS = 60;
/** Mínimo que acepta la librería (TTL de KV). */
const MIN_TTL_SECONDS = 60;

export interface GrantProps {
  v: 1;
  sub: string;
  sid: string;
  /** Segundos Unix de cuando el usuario autorizó. Fija el máximo de 90 días. */
  authorizedAt: number;
  refresh: string;
  /** Solo entre `completeAuthorization` y el canje del código: luego pasa al access token y sale del grant. */
  access?: string;
  accessExp?: number;
}

export interface AccessProps {
  v: 1;
  sub: string;
  sid: string;
  access: string;
  accessExp: number;
}

export function isAccessProps(p: unknown): p is AccessProps {
  const o = p as Partial<AccessProps> | null;
  return (
    !!o &&
    o.v === 1 &&
    typeof o.sub === "string" &&
    typeof o.sid === "string" &&
    typeof o.access === "string" &&
    typeof o.accessExp === "number"
  );
}

function isGrantProps(p: unknown): p is GrantProps {
  const o = p as Partial<GrantProps> | null;
  return (
    !!o && o.v === 1 && typeof o.sub === "string" && typeof o.sid === "string" && typeof o.authorizedAt === "number" && typeof o.refresh === "string"
  );
}

/** TTL del token de Claude: lo que le queda al de Supabase menos el margen, entre 60 s y 1 h. */
export function accessTtlFor(accessExp: number, nowSec: number): number {
  return Math.max(MIN_TTL_SECONDS, Math.min(3600, accessExp - nowSec - UPSTREAM_MARGIN_SECONDS));
}

/** Vida que le queda a la conexión: 30 días deslizantes, sin pasar de 90 desde la autorización. */
export function grantTtlFor(authorizedAt: number, nowSec: number): number {
  return Math.min(GRANT_IDLE_SECONDS, authorizedAt + GRANT_MAX_AGE_SECONDS - nowSec);
}

function revoke(description: string): never {
  // `invalid_grant` hace que la librería borre la conexión y sus tokens antes de responder.
  throw new OAuthError("invalid_grant", { description });
}

export interface TokenDeps {
  fetcher: Fetcher;
  verify: UpstreamVerifier;
  nowSec: () => number;
}

export function makeTokenExchangeCallback(env: Env, deps: TokenDeps) {
  return async (opts: TokenExchangeCallbackOptions): Promise<TokenExchangeCallbackResult | void> => {
    const nowSec = deps.nowSec();

    if (opts.grantType === "authorization_code") {
      const p = opts.props as unknown;
      if (!isGrantProps(p) || !p.access || typeof p.accessExp !== "number") revoke("Conexión incompleta");
      const ttl = grantTtlFor(p.authorizedAt, nowSec);
      if (ttl < MIN_TTL_SECONDS) revoke("La conexión caducó");
      const access: AccessProps = { v: 1, sub: p.sub, sid: p.sid, access: p.access, accessExp: p.accessExp };
      const grant: GrantProps = { v: 1, sub: p.sub, sid: p.sid, authorizedAt: p.authorizedAt, refresh: p.refresh };
      return { accessTokenProps: access, newProps: grant, accessTokenTTL: accessTtlFor(p.accessExp, nowSec), refreshTokenTTL: ttl };
    }

    if (opts.grantType === "refresh_token") {
      const p = opts.props as unknown;
      if (!isGrantProps(p)) revoke("Conexión incompleta");
      const ttl = grantTtlFor(p.authorizedAt, nowSec);
      if (ttl < MIN_TTL_SECONDS) {
        auditEvent("mcp_revocacion", { motivo: "caducidad_maxima", cliente: opts.clientId, sub: p.sub });
        revoke("La conexión caducó: vuelve a conectar Yala");
      }
      const r = await refreshTokens(env, deps.fetcher, p.refresh);
      if (!r.ok) {
        if (r.kind === "rejected") {
          auditEvent("mcp_revocacion", { motivo: `supabase_${r.code}`, cliente: opts.clientId, sub: p.sub });
          revoke("Yala retiró el acceso: vuelve a conectar");
        }
        throw new OAuthError("temporarily_unavailable", {
          description: "Yala no respondió. Prueba de nuevo en un momento",
          statusCode: 503,
          headers: { "Retry-After": "30" },
        });
      }
      const check = await deps.verify(r.value.access, p.sub);
      if (!check.ok) {
        // El hook no marcó el token como de solo lectura, o es de otro cliente o de otro usuario: falla cerrado.
        auditEvent("mcp_revocacion", { motivo: `token_${check.reason}`, cliente: opts.clientId, sub: p.sub });
        revoke("Yala no entregó un acceso de solo lectura");
      }
      const access: AccessProps = { v: 1, sub: p.sub, sid: check.claims.sessionId, access: r.value.access, accessExp: check.claims.exp };
      const grant: GrantProps = { v: 1, sub: p.sub, sid: check.claims.sessionId, authorizedAt: p.authorizedAt, refresh: r.value.refresh };
      return {
        accessTokenProps: access,
        newProps: grant,
        accessTokenTTL: accessTtlFor(check.claims.exp, nowSec),
        refreshTokenIdleTTL: ttl,
      };
    }

    // El intercambio de tokens (RFC 8693) está apagado: no llega aquí.
    return undefined;
  };
}
