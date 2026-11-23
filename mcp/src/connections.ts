/**
 * «Conecta tu IA» en la app: qué IA tienen acceso a tus datos de Yala, y quitar una. Decisión 3 de Jürgen del
 * 2026-11-23 (encargo «Conecta tu IA», opción C): listar y desconectar desde la app entran ya, no en una fase 2.
 *
 *   GET    /connections        → `{ conexiones: [{ id, ia, vuelta, local, conectadaEl }] }`
 *   DELETE /connections/<id>   → 204; 404 si esa conexión no es tuya o ya no existe
 *
 * Quién puede llamar. Solo la APP, con su sesión normal de la nube (el mismo token con el que sincroniza). Nunca una
 * IA: el token que el Worker le da a Claude es opaco y no es un JWT de Supabase, y el de Supabase que guarda el Worker
 * lleva `client_id` y `role = yala_mcp_reader` (lo pone el hook). Aquí se exige lo contrario: `role = authenticated`,
 * audiencia `authenticated` y SIN `client_id`. Así una IA conectada no puede ver qué otras hay ni desconectarlas.
 *
 * Qué cuenta cada fila. La conexión es un grant del Worker (uno por IA; reconectar la misma IA retira el anterior).
 * `ia` sale de la vuelta que registró su cliente («Claude», «ChatGPT», «Grok»), no del nombre que se puso al
 * registrarse, que lo elige ella. Si no se reconoce, `null` y la app dice «Tu IA». Nada de tokens, ids de sesión ni el
 * nombre elegido por el cliente. No se guarda «última actividad» (decisión 4): la app ya enseña el último borrador.
 *
 * El listado de KV va atrasado (consistencia eventual, hasta un minuto; medido en staging el 2026-11-23: una conexión
 * recién hecha no salía). Una ya borrada no vuelve a salir, porque la librería relee cada grant por su clave al
 * listar. Una recién hecha puede tardar hasta un minuto en aparecer, y la app lo dice. Quitar no depende del listado:
 * lee el grant por su clave, así que una recién hecha se puede quitar ya.
 *
 * Qué cierra desconectar. El grant y sus tokens: la IA deja de leer y de apuntar al momento. La sesión de Supabase que
 * llevaba dentro NO se puede cerrar desde aquí: solo se descifra con el refresh de la IA. Queda inservible (nadie
 * tiene su refresh, y su access iba cifrado en los tokens que se borran) y la borra el barrido diario
 * (`qa/cloud/mcp0_04_sweep_connector_sessions.sql`) en 31 días como mucho, igual que al reconectar. Decidido por Jürgen
 * el 2026-11-23 («como al reconectar»): no se abre ninguna salida nueva del Worker hacia Supabase.
 */
import type { GrantSummary, OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import { createRemoteJWKSet, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from "jose";
import { auditEvent } from "./audit";
import { authIssuer, type Env } from "./env";
import { clientLabelFromRedirects } from "./writeTool";

export const CONNECTIONS_PATH = "/connections";

/** Un id de grant de la librería: letras, números, `_` y `-`. Sin `:`, que separa las partes de sus claves en el KV. */
const GRANT_ID = /^[A-Za-z0-9_-]{1,128}$/;
/** Tope de páginas al listar (100 por página): nadie tiene 500 IA conectadas, y una lista rara no cuelga la petición. */
const MAX_PAGES = 5;

export type AppCheck = { ok: true; sub: string } | { ok: false; reason: "invalid" | "unavailable" | "not_app" };
export type AppVerifier = (raw: string) => Promise<AppCheck>;

/** Comprobaciones de claims de la sesión de la app, separadas de la firma para probarlas sin red. */
export function checkAppClaims(payload: JWTPayload): AppCheck {
  const sub = typeof payload.sub === "string" ? payload.sub : "";
  if (!sub || typeof payload.exp !== "number") return { ok: false, reason: "invalid" };
  // Un token emitido a un cliente OAuth (el del Worker o cualquier otro) no es la app, aunque alguien apague el hook y
  // llegue con `role = authenticated`.
  if (payload["client_id"] !== undefined) return { ok: false, reason: "not_app" };
  if (payload["role"] !== "authenticated") return { ok: false, reason: "not_app" };
  if (typeof payload["session_id"] !== "string" || !payload["session_id"]) return { ok: false, reason: "invalid" };
  return { ok: true, sub };
}

let cachedJwks: { url: string; set: JWTVerifyGetKey } | null = null;

function remoteJwks(env: Env): JWTVerifyGetKey {
  const url = `${authIssuer(env)}/.well-known/jwks.json`;
  if (!cachedJwks || cachedJwks.url !== url) cachedJwks = { url, set: createRemoteJWKSet(new URL(url)) };
  return cachedJwks.set;
}

/** El mismo criterio que `auth.ts`: no poder bajar las claves no es un token malo. */
function isJwksUnavailable(err: unknown): boolean {
  const code = (err as { code?: unknown })?.code;
  if (code === "ERR_JWKS_TIMEOUT" || code === "ERR_JWKS_NO_MATCHING_KEY" || code === "ERR_JWKS_MULTIPLE_MATCHING_KEYS") return true;
  if (err instanceof TypeError) return true;
  const msg = err instanceof Error ? err.message : "";
  return /Expected 200 OK|fetch failed|Failed to fetch|timed? ?out|network/i.test(msg);
}

export function makeAppVerifier(env: Env, keys?: JWTVerifyGetKey): AppVerifier {
  return async (raw) => {
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(raw, keys ?? remoteJwks(env), {
        issuer: authIssuer(env),
        audience: "authenticated",
        algorithms: ["ES256", "RS256"],
        requiredClaims: ["sub", "exp"],
      }));
    } catch (err) {
      return { ok: false, reason: isJwksUnavailable(err) ? "unavailable" : "invalid" };
    }
    return checkAppClaims(payload);
  };
}

/** Una fila de la lista, tal como la recibe la app (`ConectaTuIAClient.swift`). */
export interface PublicConnection {
  id: string;
  /** «Claude», «ChatGPT», «Grok»; `null` si la vuelta no es de ninguna conocida. */
  ia: string | null;
  /** El dominio al que vuelve el acceso (el mismo que enseñó la pantalla de permiso), o `null`. */
  vuelta: string | null;
  /** La vuelta es de la computadora del usuario (Claude Code, Claude Desktop). */
  local: boolean;
  /** Segundos Unix de cuando se conectó. */
  conectadaEl: number;
}

function hostOf(uri: string | undefined): string | null {
  if (!uri) return null;
  try {
    return new URL(uri).hostname || null;
  } catch {
    return null;
  }
}

function isLoopback(host: string | null): boolean {
  return host === "localhost" || host === "[::1]" || (!!host && /^127(\.\d{1,3}){3}$/.test(host));
}

/**
 * La clave del grant en el KV de la librería (`grant:<usuario>:<id>`, la misma que borra su `revokeGrant`). Se lee
 * directamente porque la librería no ofrece leer un grant por id, y su listado va atrasado.
 */
export function grantKey(sub: string, id: string): string {
  return `grant:${sub}:${id}`;
}

async function listGrants(helpers: OAuthHelpers, sub: string, nowSec: number): Promise<GrantSummary[]> {
  const out: GrantSummary[] = [];
  let cursor: string | undefined;
  for (let page = 0; page < MAX_PAGES; page++) {
    const res = await helpers.listUserGrants(sub, { limit: 100, ...(cursor ? { cursor } : {}) });
    out.push(...res.items);
    if (!res.cursor) break;
    cursor = res.cursor;
  }
  // El KV las borra con su TTL, pero puede tardar: una conexión caducada ya no cuenta.
  return out.filter((g) => g.userId === sub && (g.expiresAt === undefined || g.expiresAt > nowSec));
}

export async function describeGrant(helpers: OAuthHelpers, g: GrantSummary): Promise<PublicConnection> {
  let uris: string[] = [];
  try {
    uris = (await helpers.lookupClient(g.clientId))?.redirectUris ?? [];
  } catch (err) {
    console.warn(JSON.stringify({ evento: "conexiones_cliente_ilegible", error: err instanceof Error ? err.name : "desconocido" }));
  }
  const vuelta = hostOf(g.redirectUri) ?? hostOf(uris[0]);
  return {
    id: g.id,
    ia: clientLabelFromRedirects(g.redirectUri ? [g.redirectUri, ...uris] : uris),
    vuelta,
    local: isLoopback(vuelta),
    conectadaEl: g.createdAt,
  };
}

function noStore(extra: Record<string, string> = {}): Record<string, string> {
  return { "Cache-Control": "no-store", ...extra };
}

function fail(status: number, error: string, description: string, extra: Record<string, string> = {}): Response {
  return Response.json({ error, error_description: description }, { status, headers: noStore(extra) });
}

export interface ConnectionsDeps {
  helpers: OAuthHelpers;
  /** El KV de la librería (`OAUTH_KV`): quitar lee el grant por su clave, sin esperar al listado. */
  kv: KVNamespace;
  verifyApp: AppVerifier;
  nowSec: () => number;
}

/** ¿Es una ruta de este servicio? (`/connections` o `/connections/<algo>`.) */
export function isConnectionsPath(pathname: string): boolean {
  return pathname === CONNECTIONS_PATH || pathname.startsWith(`${CONNECTIONS_PATH}/`);
}

export async function handleConnectionsRoute(request: Request, deps: ConnectionsDeps): Promise<Response | null> {
  const path = new URL(request.url).pathname;
  if (!isConnectionsPath(path)) return null;

  const isList = path === CONNECTIONS_PATH;
  const id = isList ? "" : path.slice(CONNECTIONS_PATH.length + 1);
  if (isList && request.method !== "GET") return fail(405, "method_not_allowed", "Usa GET.", { Allow: "GET" });
  if (!isList && request.method !== "DELETE") return fail(405, "method_not_allowed", "Usa DELETE.", { Allow: "DELETE" });

  const auth = request.headers.get("Authorization") ?? "";
  const raw = /^Bearer\s+(\S+)$/i.exec(auth.trim())?.[1] ?? "";
  if (!raw) return fail(401, "invalid_token", "Falta la sesión de la app.", { "WWW-Authenticate": 'Bearer realm="Yala"' });
  const check = await deps.verifyApp(raw);
  if (!check.ok) {
    if (check.reason === "unavailable") return fail(503, "temporarily_unavailable", "Prueba de nuevo en un momento.", { "Retry-After": "30" });
    // Un token de IA (o de otro cliente) y uno malo reciben lo mismo: a quien no es la app no se le cuenta qué falló.
    return fail(401, "invalid_token", "La sesión de la app no es válida.", { "WWW-Authenticate": 'Bearer realm="Yala", error="invalid_token"' });
  }

  // El id se valida DESPUÉS de autenticar: sin sesión, todo es 401, exista o no.
  if (!isList && !GRANT_ID.test(id)) return fail(404, "not_found", "Esa conexión no existe.");

  if (isList) {
    const grants = await listGrants(deps.helpers, check.sub, deps.nowSec());
    const conexiones = await Promise.all(grants.map((g) => describeGrant(deps.helpers, g)));
    conexiones.sort((a, b) => b.conectadaEl - a.conectadaEl);
    return Response.json({ conexiones }, { headers: noStore() });
  }

  // Solo se borra un grant que existe con SU usuario en la clave: `revokeGrant` borra por prefijo, y el id ya pasó por
  // `GRANT_ID` (sin `:`), así que no puede alcanzar las claves de otro usuario ni de otro grant.
  const stored = await deps.kv.get(grantKey(check.sub, id));
  if (stored === null) return fail(404, "not_found", "Esa conexión no existe.");
  let clientId: string | undefined;
  try {
    const parsed = JSON.parse(stored) as { clientId?: unknown };
    if (typeof parsed.clientId === "string") clientId = parsed.clientId;
  } catch {
    // Solo es para la auditoría.
  }
  await deps.helpers.revokeGrant(id, check.sub);
  auditEvent("mcp_revocacion", { motivo: "app_desconecto", ...(clientId ? { cliente: clientId } : {}), sub: check.sub });
  return new Response(null, { status: 204, headers: noStore() });
}
