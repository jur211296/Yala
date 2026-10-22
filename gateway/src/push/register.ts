/**
 * Registro/desregistro del device token APNs (G8-1). El cliente (`PushTokenRegistrationClient`, G8-2) llama
 * `POST /push/register` en cada boot con sesión viva y `POST /push/unregister` en el seam de sign-out.
 *
 * Invariantes (molde de las rutas de grupos): auth = `requireUserAndAttest` (JWT Supabase + App Attest +
 * rate-limit), REUSADO de groups/routes.ts (sin una 3ª copia). El `user_id` de la fila lo pone el WORKER
 * desde el JWT (`auth.sub`) — JAMÁS del body del cliente; la RLS `with check user_id = auth.uid()` de
 * push_tokens lo defiende igual. Se reenvía el JWT del usuario a PostgREST; NUNCA service_role. Sin logging
 * de token/PII.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { jsonError } from "../errors";
import { postgrestHeaders } from "../sync/userauth";
import { requireUserAndAttest } from "../groups/routes";

type Ctx = Context<{ Bindings: Env }>;

const DEVICE_TOKEN_RE = /^[0-9a-f]{64}$/i;
const VALID_PLATFORMS = new Set(["ios-sandbox", "ios-prod"]);

/** POST /push/register — body `{device_token, platform}` → upsert idempotente en push_tokens. 200 {registered:true}. */
export async function handlePushRegister(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  let body: { device_token?: unknown; platform?: unknown };
  try {
    body = await c.req.json();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  const deviceToken = typeof body.device_token === "string" ? body.device_token : "";
  if (!DEVICE_TOKEN_RE.test(deviceToken)) {
    return jsonError("yala_bad_request", "device_token inválido (hex 64)", 400);
  }
  const platform = typeof body.platform === "string" ? body.platform : "";
  if (!VALID_PLATFORMS.has(platform)) {
    return jsonError("yala_bad_request", "platform inválida (ios-sandbox|ios-prod)", 400);
  }

  // Upsert a PostgREST: la PK compuesta (user_id, device_token) basta para el merge (sin on_conflict param).
  // `updated_at` EXPLÍCITO en el body es obligatorio: el default now() de la columna NO re-dispara en la rama
  // conflict-update de merge-duplicates → sin él, un re-registro no refrescaría la marca de vida del token.
  const res = await fetch(`${c.env.SUPABASE_URL}/rest/v1/push_tokens`, {
    method: "POST",
    headers: postgrestHeaders(c.env, auth.userJWT, { Prefer: "resolution=merge-duplicates" }),
    body: JSON.stringify({
      user_id: auth.sub, // del JWT, JAMÁS del body (RLS with-check lo re-valida)
      device_token: deviceToken,
      platform,
      updated_at: new Date().toISOString(),
    }),
  });
  if (!res.ok) {
    console.log(`[push-register] upsert upstream ${res.status}`);
    return jsonError("yala_unavailable", "registro falló", res.status >= 500 ? 502 : 400);
  }
  return c.json({ registered: true });
}

/** POST /push/unregister — body `{device_token}` → DELETE del par (sub, token). 200 {unregistered:true}. */
export async function handlePushUnregister(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  let body: { device_token?: unknown };
  try {
    body = await c.req.json();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }
  const deviceToken = typeof body.device_token === "string" ? body.device_token : "";
  if (!DEVICE_TOKEN_RE.test(deviceToken)) {
    return jsonError("yala_bad_request", "device_token inválido (hex 64)", 400);
  }

  // device_token es hex-64 validado y sub es un UUID del JWT → seguros en la query string (sin inyección).
  const url = `${c.env.SUPABASE_URL}/rest/v1/push_tokens?user_id=eq.${auth.sub}&device_token=eq.${deviceToken}`;
  const res = await fetch(url, { method: "DELETE", headers: postgrestHeaders(c.env, auth.userJWT) });
  if (!res.ok) {
    console.log(`[push-unregister] delete upstream ${res.status}`);
    return jsonError("yala_unavailable", "desregistro falló", res.status >= 500 ? 502 : 400);
  }
  return c.json({ unregistered: true });
}
