/**
 * `/mcp` con un token del Worker ya validado por la librería (existe, no caducó, su audiencia es `…/mcp`). Antes de
 * leer nada, aquí se comprueba la sesión de Supabase que ese token lleva dentro:
 *
 * 1. Tiene la forma esperada y es del mismo usuario que el token. Si no, 401: falla cerrado.
 * 2. Sigue siendo un token de solo lectura del cliente del Worker, bien firmado y sin caducar. Si no, 401 sin borrar
 *    nada: Claude refresca y el refresh decide.
 * 3. Supabase la sigue reconociendo (`GET /auth/v1/user`). Si se revocó el permiso, se borró la cuenta o se
 *    bloqueó, se retira la conexión del Worker y se responde 401: revocar corta AL MOMENTO, no a la hora.
 */
import type { OAuthResourceAuth } from "@cloudflare/workers-oauth-provider";
import { invalidTokenChallenge, type UpstreamVerifier } from "./auth";
import { auditEvent } from "./audit";
import type { Env } from "./env";
import type { Fetcher } from "./egress";
import { handleMcp } from "./server";
import { isAccessProps } from "./tokens";
import { sessionStatus } from "./upstream";

export interface McpRouteDeps {
  fetcher: Fetcher;
  verify: UpstreamVerifier;
  now?: () => Date;
}

type Ctx = ExecutionContext & { props?: unknown; auth?: OAuthResourceAuth };

function unauthorized(env: Env, description: string): Response {
  return Response.json(
    { error: "invalid_token", error_description: description },
    { status: 401, headers: { "WWW-Authenticate": invalidTokenChallenge(env, description), "Cache-Control": "no-store" } },
  );
}

/** El formato del token de la librería es `userId:grantId:secreto`; el grant se retira por su id. */
function grantIdOf(token: string): string | null {
  const parts = token.split(":");
  return parts.length === 3 && parts[1] ? parts[1] : null;
}

export async function handleMcpRoute(request: Request, env: Env, ctx: Ctx, deps: McpRouteDeps): Promise<Response> {
  // Sin estado no hay stream SSE que abrir con GET ni sesión que cerrar con DELETE. Un 405 es lo que el SDK lee
  // como «este servidor no tiene SSE»; un 200 vacío le hacía reconectar cada segundo.
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: { Allow: "POST" } });
  }
  const auth = ctx.auth;
  const props = ctx.props;
  if (!auth?.userId || !auth.clientId || !isAccessProps(props) || props.sub !== auth.userId) {
    return unauthorized(env, "Token no valido");
  }

  const check = await deps.verify(props.access, props.sub);
  if (!check.ok) return unauthorized(env, "Token no valido o caducado");

  const status = await sessionStatus(env, deps.fetcher, props.access);
  if (status === "gone") {
    const grantId = grantIdOf(auth.token);
    try {
      if (grantId && env.OAUTH_PROVIDER) await env.OAUTH_PROVIDER.revokeGrant(grantId, auth.userId);
    } catch {
      // Si el KV falla, el 401 corta igual esta petición y la siguiente vuelve a comprobarlo.
    }
    auditEvent("mcp_revocacion", { motivo: "sesion_supabase_retirada", cliente: auth.clientId, sub: props.sub });
    return unauthorized(env, "El acceso a Yala se retiro");
  }
  if (status === "stale") return unauthorized(env, "Token no valido o caducado");
  if (status === "unknown") {
    return Response.json(
      { error: "temporarily_unavailable", error_description: "Yala no respondio" },
      { status: 503, headers: { "Retry-After": "30", "Cache-Control": "no-store" } },
    );
  }

  return handleMcp(
    request,
    env,
    { sub: props.sub, clientId: auth.clientId, upstreamToken: props.access, expiresAt: auth.expiresAt ?? 0 },
    { fetcher: deps.fetcher, now: deps.now },
  );
}
