/**
 * Límites de peticiones, con el binding Rate Limiting de Workers (`[[ratelimits]]` en `wrangler.toml`). El contador es
 * aproximado y por ubicación de Cloudflare: sirve contra abuso (fuerza bruta, registro masivo, un bucle), no para
 * cobrar cuotas exactas.
 *
 * Tres cubos, y por qué cada uno tiene su clave:
 * - `RL_BROWSER`, por IP: las páginas que abre el NAVEGADOR del usuario (`/authorize`, `/oauth/consent`, la vuelta de
 *   Supabase). Ahí la IP es la del usuario. Frena la fuerza bruta del formulario y el abuso de la pantalla de permiso.
 * - `RL_OAUTH`, por IP y generoso: `/oauth/register` (escribe en KV) y `/oauth/token`. claude.ai los llama desde los
 *   servidores de Anthropic, con pocas IPs para todos los usuarios: el límite tiene que dejar pasar a todos juntos y
 *   solo cortar una avalancha.
 * - `RL_MCP`, por USUARIO, ya autenticado: `/mcp`. Por IP ahogaría a todos los usuarios de claude.ai a la vez.
 *
 * Si el binding no está (tests, `wrangler dev`) no se limita. En producción no puede faltar: `config.ts` lo exige y
 * sin él el Worker no atiende. Si el binding falla al consultar, se deja pasar: un límite caído no tumba el servicio.
 */
import type { Env } from "./env";

export type Bucket = "RL_BROWSER" | "RL_OAUTH" | "RL_MCP";

const BROWSER_PATHS = new Set(["/authorize", "/oauth/consent", "/oauth/supabase/callback"]);
const OAUTH_PATHS = new Set(["/oauth/register", "/oauth/token"]);

/** Qué cubo por IP le toca a esta ruta, o ninguno (`/mcp` se limita por usuario dentro de `mcp.ts`). */
export function ipBucketFor(pathname: string): Bucket | null {
  if (BROWSER_PATHS.has(pathname)) return "RL_BROWSER";
  if (OAUTH_PATHS.has(pathname)) return "RL_OAUTH";
  return null;
}

/** La IP del que llama, tal como la pone Cloudflare. Sin ella (tests), una clave fija: todos al mismo cubo. */
export function clientIp(request: Request): string {
  return request.headers.get("CF-Connecting-IP") ?? "sin-ip";
}

/** ¿Puede pasar? `true` también si no hay binding o si consultarlo falla. */
export async function allow(env: Env, bucket: Bucket, key: string): Promise<boolean> {
  const limiter = env[bucket];
  if (!limiter) return true;
  try {
    const { success } = await limiter.limit({ key: `${bucket}:${key}` });
    if (!success) console.warn(JSON.stringify({ evento: "mcp_limite", cubo: bucket }));
    return success;
  } catch (err) {
    console.error(JSON.stringify({ evento: "mcp_limite_error", cubo: bucket, error: err instanceof Error ? err.name : "desconocido" }));
    return true;
  }
}

/** 429 con `Retry-After`. El periodo de los cubos es de 60 s. */
export function tooManyRequests(): Response {
  return Response.json(
    { error: "too_many_requests", error_description: "Demasiadas peticiones. Prueba de nuevo en un minuto." },
    { status: 429, headers: { "Retry-After": "60", "Cache-Control": "no-store" } },
  );
}
