/**
 * Ruta DEBUG del spike G0: envía un push de prueba vía APNs.
 *
 * Gateada igual que /v1/attest/dev (solo entorno NO-prod + DEV_SHARED_SECRET); en
 * producción responde 404. Estado intermedio deployable: sin los secrets de APNs
 * configurados responde 503 (permite probar los guards en vivo ANTES de tener la .p8).
 * Los fallos de APNs NO son errores del gateway: viajan en el body 200 como
 * diagnóstico (ApnsPushResult) — el objetivo del spike es observar, no abstraer.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { allowsDevBypass } from "../env";
import { jsonError } from "../errors";
import { sendPush } from "./apns";

type Ctx = Context<{ Bindings: Env }>;

const DEVICE_TOKEN_RE = /^[0-9a-f]{64}$/i;

export async function handleDebugPush(c: Ctx): Promise<Response> {
  if (!allowsDevBypass(c.env)) return jsonError("yala_bad_request", "no disponible", 404);
  const secret = c.req.header("X-Yala-Dev-Secret");
  if (!secret || secret !== c.env.DEV_SHARED_SECRET) {
    return jsonError("yala_attest_invalid", "dev secret inválido", 401);
  }
  if (!c.env.APNS_AUTH_KEY || !c.env.APNS_KEY_ID) {
    return jsonError("yala_unavailable", "APNs not configured", 503);
  }

  let body: { deviceToken?: unknown; sandbox?: unknown };
  try {
    body = await c.req.json();
  } catch {
    return jsonError("yala_bad_request", "body JSON inválido", 400);
  }
  const deviceToken = typeof body.deviceToken === "string" ? body.deviceToken : "";
  if (!DEVICE_TOKEN_RE.test(deviceToken)) {
    return jsonError("yala_bad_request", "deviceToken inválido (hex 64)", 400);
  }
  const sandbox = typeof body.sandbox === "boolean" ? body.sandbox : true;

  const result = await sendPush(c.env, { deviceToken, sandbox });
  return c.json(result);
}
