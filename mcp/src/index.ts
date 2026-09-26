/**
 * Worker del conector MCP de Yala (staging).
 *
 * Es el SERVIDOR OAUTH de Claude y su recurso protegido, con `@cloudflare/workers-oauth-provider`. Supabase queda
 * aguas arriba: autentica al usuario y le da al Worker —no a Claude— una sesión de solo lectura. Por qué: el ADR
 * «El conector de Claude emite sus propios tokens» (docs/DECISIONS.md).
 *
 *   GET  /.well-known/oauth-authorization-server     → metadatos del servidor OAuth (RFC 8414)          [librería]
 *   GET  /.well-known/oauth-protected-resource/mcp   → metadatos del recurso protegido (RFC 9728)       [librería]
 *   POST /oauth/register                             → registro dinámico (RFC 7591), solo vueltas de Claude [librería]
 *   POST /oauth/token                                → canje, refresh y revocación (RFC 7009)            [librería]
 *   GET|POST /authorize, /oauth/consent, GET /oauth/supabase/callback → el permiso y el login      [authorize.ts]
 *   POST /mcp                                        → el servidor MCP (Streamable HTTP, sin estado)       [mcp.ts]
 *   GET  /                                           → qué es esto, en una línea
 */
import { OAuthProvider } from "@cloudflare/workers-oauth-provider";
import type { JWTVerifyGetKey } from "jose";
import { makeUpstreamVerifier, type UpstreamVerifier } from "./auth";
import { handleAuthorizeRoutes, registrationPolicy } from "./authorize";
import { mcpResource, publicOrigin, type Env } from "./env";
import { defaultFetch, type Fetcher } from "./egress";
import { handleMcpRoute } from "./mcp";
import { GRANT_IDLE_SECONDS, makeTokenExchangeCallback, SCOPE } from "./tokens";

export interface AppDeps {
  /** Salida hacia Supabase. Siempre pasa además por la lista cerrada de `egress.ts`. */
  fetcher?: Fetcher;
  /** Claves para verificar los tokens de Supabase sin red (tests). En producción, el JWKS del proyecto. */
  upstreamKeys?: JWTVerifyGetKey;
  now?: () => Date;
}

function buildProvider(env: Env, deps: AppDeps): OAuthProvider<Env> {
  const fetcher = deps.fetcher ?? defaultFetch;
  const verify: UpstreamVerifier = makeUpstreamVerifier(env, deps.upstreamKeys);
  const nowSec = () => Math.floor((deps.now ? deps.now() : new Date()).getTime() / 1000);
  const shared = { fetcher, verify, nowSec };

  return new OAuthProvider<Env>({
    apiRoute: "/mcp",
    apiHandler: {
      fetch: (request, e, ctx) => handleMcpRoute(request, e as Env, ctx, { fetcher, verify, now: deps.now }),
    },
    defaultHandler: {
      async fetch(request, e) {
        const routed = await handleAuthorizeRoutes(request, e as Env, shared);
        if (routed) return routed;
        const url = new URL(request.url);
        if (url.pathname === "/" && request.method === "GET") {
          return new Response(
            "Yala MCP (staging): conector de solo lectura para Claude. Endpoint MCP en /mcp; se autoriza con OAuth contra este Worker.\n",
            { headers: { "Content-Type": "text/plain; charset=utf-8" } },
          );
        }
        return new Response("Not found", { status: 404 });
      },
    },
    authorizeEndpoint: "/authorize",
    tokenEndpoint: "/oauth/token",
    clientRegistrationEndpoint: "/oauth/register",
    clientRegistrationCallback: registrationPolicy,
    scopesSupported: [SCOPE],
    refreshTokenTTL: GRANT_IDLE_SECONDS,
    refreshTokenIdleTTL: GRANT_IDLE_SECONDS,
    tokenExchangeCallback: makeTokenExchangeCallback(env, shared),
    onError({ code, status, internal }) {
      // Ni token ni detalle: solo qué comprobación falló.
      console.warn(JSON.stringify({ evento: "oauth_error", code, status, categoria: internal.category, motivo: internal.reason }));
    },
    resourceMetadata: {
      resource: mcpResource(env),
      authorization_servers: [publicOrigin(env)],
      scopes_supported: [SCOPE],
      bearer_methods_supported: ["header"],
      resource_name: env.ENVIRONMENT === "staging" ? "Yala (staging)" : "Yala",
    },
  });
}

export function createApp(deps: AppDeps = {}) {
  // Un proveedor por `env`: sus callbacks cierran sobre esa configuración (URL pública, cliente de Supabase).
  const providers = new WeakMap<Env, OAuthProvider<Env>>();
  return {
    async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
      let provider = providers.get(env);
      if (!provider) {
        provider = buildProvider(env, deps);
        providers.set(env, provider);
      }
      return provider.fetch(request, env, ctx);
    },
  };
}

export default createApp();
