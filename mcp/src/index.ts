/**
 * Worker del conector MCP de Yala (fase 0, staging).
 *
 *   GET  /                                          → qué es esto, en una línea
 *   GET  /.well-known/oauth-protected-resource[/mcp] → metadatos del recurso protegido (RFC 9728)
 *   GET|POST /oauth/consent, POST /oauth/consent/decision → pantalla de consentimiento (ver consent.ts)
 *   POST /mcp                                       → el servidor MCP (Streamable HTTP, sin estado)
 *
 * El servidor de autorización NO es este Worker: es Supabase Auth. Aquí solo se valida el token.
 */
import { bearer, makeVerifier, wwwAuthenticate, type TokenVerifier } from "./auth";
import { handleConsent } from "./consent";
import { authIssuer, type Env } from "./env";
import { handleMcp } from "./server";
import type { Fetcher } from "./data";

export interface AppDeps {
  verifier?: TokenVerifier;
  fetcher?: Fetcher;
  now?: () => Date;
}

const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type, Mcp-Session-Id, Mcp-Protocol-Version, Last-Event-ID",
  "Access-Control-Expose-Headers": "WWW-Authenticate, Mcp-Session-Id",
  "Access-Control-Max-Age": "86400",
};

function withCors(res: Response): Response {
  const out = new Response(res.body, res);
  for (const [k, v] of Object.entries(CORS)) out.headers.set(k, v);
  return out;
}

export function protectedResourceMetadata(origin: string, env: Env) {
  return {
    resource: `${origin}/mcp`,
    authorization_servers: [authIssuer(env)],
    bearer_methods_supported: ["header"],
    resource_name: env.ENVIRONMENT === "staging" ? "Yala (staging)" : "Yala",
    resource_documentation: `${origin}/`,
  };
}

export function createApp(deps: AppDeps = {}) {
  return {
    async fetch(request: Request, env: Env): Promise<Response> {
      const url = new URL(request.url);
      const origin = url.origin;
      // Ruta canónica de RFC 9728 para el recurso `/mcp`: la raíz sirve lo mismo, por clientes que no la construyan.
      const metadataUrl = `${origin}/.well-known/oauth-protected-resource/mcp`;

      if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

      if (url.pathname === "/.well-known/oauth-protected-resource" || url.pathname === "/.well-known/oauth-protected-resource/mcp") {
        if (request.method !== "GET") return withCors(new Response("Method not allowed", { status: 405 }));
        return withCors(Response.json(protectedResourceMetadata(origin, env), { headers: { "Cache-Control": "public, max-age=300" } }));
      }

      if (url.pathname === "/oauth/consent" || url.pathname === "/oauth/consent/decision") {
        return handleConsent(request, env, deps.fetcher ?? fetch);
      }

      if (url.pathname === "/mcp" || url.pathname === "/mcp/") {
        // Sin estado no hay stream SSE que abrir con GET ni sesión que cerrar con DELETE. Un 405 es lo que el SDK
        // lee como «este servidor no tiene SSE»; un 200 vacío le hacía reconectar cada segundo.
        if (request.method !== "POST") {
          return withCors(new Response("Method not allowed", { status: 405, headers: { Allow: "POST" } }));
        }
        const verify = deps.verifier ?? makeVerifier(env);
        const result = await verify(bearer(request.headers.get("Authorization")));
        if (!result.ok) {
          return withCors(
            Response.json(
              { error: result.reason === "missing" ? "unauthorized" : "invalid_token" },
              { status: 401, headers: { "WWW-Authenticate": wwwAuthenticate(metadataUrl, result.reason) } },
            ),
          );
        }
        const res = await handleMcp(request, env, result.token, { fetcher: deps.fetcher, now: deps.now });
        return withCors(res);
      }

      if (url.pathname === "/" && request.method === "GET") {
        return new Response(
          "Yala MCP (staging): conector de solo lectura para Claude. Endpoint MCP en /mcp; se autoriza con OAuth contra Yala en la nube.\n",
          { headers: { "Content-Type": "text/plain; charset=utf-8" } },
        );
      }

      return new Response("Not found", { status: 404 });
    },
  };
}

export default createApp();
