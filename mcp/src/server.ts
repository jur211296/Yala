/**
 * Servidor MCP por petición, sin estado (Streamable HTTP en modo stateless): cada POST a /mcp crea el servidor,
 * atiende y se descarta. Así no hay sesiones MCP que guardar en el Worker, y la sesión de Supabase del usuario vive
 * en memoria lo que dura la petición.
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { WebStandardStreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js";
import { UpstreamError, YalaReader, type Fetcher } from "./data";
import type { Env } from "./env";
import { InvalidInputError } from "./logic/dates";
import { planAllows, TOOLS, type ToolDef } from "./tools";
import { audit } from "./audit";

/** Lo que una petición a /mcp sabe de quién llama. */
export interface McpSession {
  /** user_id de Supabase. Nunca se usa para filtrar: el filtro lo pone RLS con `upstreamToken`. */
  sub: string;
  /** El cliente de Claude en ESTE Worker (lo registró por DCR). Solo para la auditoría. */
  clientId: string;
  /** El access token de Supabase, de solo lectura. Solo va a PostgREST; nunca sale hacia Claude. */
  upstreamToken: string;
  /** Caducidad del token de Claude, en segundos Unix. */
  expiresAt: number;
}

export const SERVER_INFO = { name: "yala", version: "0.0.1" };

export function buildServer(env: Env, session: McpSession, deps: { fetcher?: Fetcher; now?: () => Date } = {}): McpServer {
  const server = new McpServer(SERVER_INFO, {
    capabilities: { tools: {} },
    instructions:
      "Yala es una app de finanzas personales. Estas herramientas leen los datos del usuario en la nube de Yala y no pueden modificarlos. " +
      "Los importes ya vienen calculados con las reglas de la app; el campo «avisos» dice cuándo una cifra es aproximada.",
  });
  const reader = new YalaReader(env, session.upstreamToken, deps.fetcher);

  for (const def of TOOLS) {
    server.registerTool(
      def.name,
      {
        title: def.title,
        description: def.description,
        inputSchema: def.inputSchema,
        annotations: { title: def.title, readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
      },
      async (args: Record<string, unknown>) => runTool(def, env, session, reader, args, deps.now),
    );
  }
  return server;
}

async function runTool(
  def: ToolDef,
  env: Env,
  session: McpSession,
  reader: YalaReader,
  args: Record<string, unknown>,
  now?: () => Date,
) {
  const started = Date.now();
  if (!planAllows(def.plan, { pro: false })) {
    audit({ tool: def.name, session, ms: 0, outcome: "plan" });
    return errorResult("Esta herramienta es de Yala Pro.");
  }
  try {
    const result = await def.run({ reader, env, now: now ? now() : new Date() }, args ?? {});
    audit({ tool: def.name, session, ms: Date.now() - started, outcome: "ok" });
    return { content: [{ type: "text" as const, text: JSON.stringify(result) }] };
  } catch (err) {
    if (err instanceof InvalidInputError) {
      audit({ tool: def.name, session, ms: Date.now() - started, outcome: "input" });
      return errorResult(err.message);
    }
    if (err instanceof UpstreamError) {
      audit({ tool: def.name, session, ms: Date.now() - started, outcome: `upstream_${err.status}` });
      return errorResult(
        err.status === 401 || err.status === 403
          ? "La sesión con Yala ya no es válida. Vuelve a conectar Yala."
          : err.status === 400
            ? "La consulta no es válida. Revisa los filtros."
            : "La nube de Yala no respondió. Prueba de nuevo en un momento.",
      );
    }
    audit({ tool: def.name, session, ms: Date.now() - started, outcome: "error" });
    return errorResult("Algo falló al leer tus datos de Yala.");
  }
}

function errorResult(message: string) {
  return { isError: true, content: [{ type: "text" as const, text: message }] };
}

export async function handleMcp(
  request: Request,
  env: Env,
  session: McpSession,
  deps: { fetcher?: Fetcher; now?: () => Date } = {},
): Promise<Response> {
  const server = buildServer(env, session, deps);
  const transport = new WebStandardStreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
  await server.connect(transport);
  try {
    // `authInfo` llega a las herramientas del SDK. No lleva el token de Supabase: ninguna herramienta lo necesita
    // (leen por `reader`) y así no hay camino por el que acabe en una respuesta.
    return await transport.handleRequest(request, {
      authInfo: { token: "", clientId: session.clientId, scopes: [], expiresAt: session.expiresAt },
    });
  } finally {
    // Stateless: nada sobrevive a la petición.
    void server.close();
  }
}
