/**
 * Límites de peticiones (binding Rate Limiting de Workers). Aproximados y por ubicación: contra abuso, no para cuotas.
 * - `RL_AUTH`, por IP: `/auth/*`, lo que abre el navegador para entrar y salir.
 * - `RL_API`, por sesión: `/api/*`, ya con sesión.
 * - `RL_QR`, por IP: lo que el navegador pregunta mientras enseña un código QR (`/auth/qr/estado` y `/renovar`).
 * Sin binding (tests, `wrangler dev`) no se limita; en producción `config.ts` lo exige. Si consultar falla, se deja pasar.
 */
import type { Env } from "./env";

export type Bucket = "RL_AUTH" | "RL_API" | "RL_QR";

export function clientIp(request: Request): string {
  return request.headers.get("CF-Connecting-IP") ?? "sin-ip";
}

export async function allow(env: Env, bucket: Bucket, key: string): Promise<boolean> {
  const limiter = env[bucket];
  if (!limiter) return true;
  try {
    const { success } = await limiter.limit({ key: `${bucket}:${key}` });
    if (!success) console.warn(JSON.stringify({ evento: "web_limite", cubo: bucket }));
    return success;
  } catch (err) {
    console.error(JSON.stringify({ evento: "web_limite_error", cubo: bucket, error: err instanceof Error ? err.name : "desconocido" }));
    return true;
  }
}
