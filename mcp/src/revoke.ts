/**
 * Desconectar Claude desde Claude cierra también la sesión de Supabase (ticket
 * `claude-mcp-revoke-from-claude-leaves-supabase-session`).
 *
 * El problema. Claude desconecta con RFC 7009 (`POST /oauth/token` con `token`). Con un REFRESH, la librería borra el
 * grant entero; con un ACCESS, solo ese token. La sesión de Supabase vive cifrada dentro del grant y solo se descifra
 * con el refresh de Claude, así que al borrarse el grant quedaba viva en `auth.sessions` sin que nadie pudiera
 * cerrarla (huérfana).
 *
 * Qué se hace. ANTES de que la librería atienda la revocación de un refresh, se hace con ese mismo refresh un refresh
 * normal por la propia librería: pasa por `tokenExchangeCallback`, que refresca en Supabase, y devuelve un access token
 * del Worker cuyas `props` llevan el access de Supabase. Con él se cierra esa sesión (`/logout?scope=local`). Después
 * la librería revoca como siempre: el refresh que mandó Claude es ahora el `previousRefreshTokenId` del grant, que la
 * librería también acepta, y `revokeGrant` borra el grant y el access recién emitido.
 *
 * Por qué así y no descifrando el grant a mano: la librería no expone cómo descifrar un grant con el refresh, y copiar
 * su criptografía nos ataría a sus internos. Este camino solo usa su comportamiento público.
 *
 * Todo falla ABIERTO hacia la revocación: si algo de aquí falla (el grant ya no existe, Supabase no responde), la
 * revocación sigue igual y Claude recibe su 200. Lo peor que pasa es lo de antes: la sesión se queda huérfana.
 *
 * Lo que NO cubre (sin credencial con que cerrar la sesión): reconectar el mismo cliente (la librería retira el grant
 * anterior en `completeAuthorization`) y la caducidad del grant en el KV. Ver el ticket.
 */
import type { OAuthHelpers, OAuthProvider } from "@cloudflare/workers-oauth-provider";
import { auditEvent } from "./audit";
import type { Env } from "./env";
import type { Fetcher } from "./egress";
import { isAccessProps } from "./tokens";
import { logout } from "./upstream";

export interface RevokeDeps {
  provider: OAuthProvider<Env>;
  helpers: OAuthHelpers;
  fetcher: Fetcher;
  ctx: ExecutionContext;
}

/** ¿Es una revocación RFC 7009 en el endpoint de tokens? Devuelve el formulario si lo es. */
async function revocationForm(request: Request): Promise<URLSearchParams | null> {
  if (request.method !== "POST" || new URL(request.url).pathname !== "/oauth/token") return null;
  // Lo mismo que acepta la librería, y nada más: si aquí se leyera algo que ella rechaza (otro Content-Type, un
  // parámetro repetido), se cerraría la sesión de Supabase y la librería respondería 400 sin borrar la conexión.
  const type = (request.headers.get("Content-Type") ?? "").split(";")[0]!.trim().toLowerCase();
  if (type !== "application/x-www-form-urlencoded") return null;
  let form: URLSearchParams;
  try {
    form = new URLSearchParams(await request.clone().text());
  } catch {
    return null;
  }
  const keys = [...form.keys()];
  if (new Set(keys).size !== keys.length) return null;
  // La misma regla que la librería: sin `grant_type` y con `token`.
  if (form.get("grant_type") || !form.get("token")) return null;
  return form;
}

/**
 * Si la petición es una revocación con un refresh vivo, cierra antes su sesión de Supabase. No toca la petición: la
 * revocación la atiende después la librería con el cuerpo original.
 */
export async function closeUpstreamBeforeRevocation(request: Request, env: Env, deps: RevokeDeps): Promise<void> {
  const form = await revocationForm(request);
  if (!form) return;
  const token = form.get("token") as string;
  try {
    // Un ACCESS token: la librería solo borra ese token y la conexión sigue; no queda nada huérfano.
    if (await deps.helpers.unwrapToken(token)) return;

    const body = new URLSearchParams({ grant_type: "refresh_token", refresh_token: token });
    // La misma autenticación del cliente que traía la revocación: el refresh solo vale para su cliente.
    for (const k of ["client_id", "client_secret"]) {
      const v = form.get(k);
      if (v) body.set(k, v);
    }
    const headers = new Headers({ "Content-Type": "application/x-www-form-urlencoded" });
    const auth = request.headers.get("Authorization");
    if (auth) headers.set("Authorization", auth);
    const res = await deps.provider.fetch(new Request(request.url, { method: "POST", headers, body: body.toString() }), env, deps.ctx);
    if (!res.ok) return; // grant ya borrado, caducado o de otro cliente: nada que cerrar
    const access = ((await res.json()) as { access_token?: unknown }).access_token;
    if (typeof access !== "string") return;
    const props = (await deps.helpers.unwrapToken(access))?.grant.props;
    if (!isAccessProps(props)) return;
    await logout(env, deps.fetcher, props.access);
    auditEvent("mcp_revocacion", { motivo: "claude_desconecto", sub: props.sub });
  } catch (err) {
    console.warn(JSON.stringify({ evento: "mcp_revocacion_sin_cerrar_supabase", error: err instanceof Error ? err.name : "desconocido" }));
  }
}
