/**
 * Ruta DEBUG: lanza un error a propósito para comprobar que el aviso llega a Sentry (`yala-gateway`) y que llega
 * limpio. El mensaje lleva un correo y un importe FALSOS: en el evento tienen que verse como `[email]` y `[monto]`.
 *
 * Gateada igual que /v1/debug/push (solo entorno NO-prod + DEV_SHARED_SECRET); en producción responde 404.
 */
import type { Context } from "hono";
import type { Env } from "./env";
import { allowsDevBypass } from "./env";
import { jsonError } from "./errors";

type Ctx = Context<{ Bindings: Env }>;

export class SentryTestError extends Error {
  constructor() {
    super("Prueba de Sentry del gateway: prueba@example.com pagó S/ 123.45");
    this.name = "SentryTestError";
  }
}

export async function handleDebugSentry(c: Ctx): Promise<Response> {
  if (!allowsDevBypass(c.env)) return jsonError("yala_bad_request", "no disponible", 404);
  const secret = c.req.header("X-Yala-Dev-Secret");
  if (!secret || secret !== c.env.DEV_SHARED_SECRET) {
    return jsonError("yala_attest_invalid", "dev secret inválido", 401);
  }
  throw new SentryTestError();
}
