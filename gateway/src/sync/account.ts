/**
 * Rutas de CUENTA del Modo Nube (I7a): `POST /account/claim` y `GET /account/exists`.
 *
 * Son el gate de identidad de §f.1 — corren INMEDIATAMENTE tras un `signInWithIdToken` exitoso y
 * ANTES de cualquier `save()` de onboarding. Preceden al `/attest/bind` (el device aún no vinculó su
 * keyId), así que NO exigen App Attest: solo el JWT de usuario (Supabase). RLS es el árbitro final
 * (se reenvía el MISMO JWT del usuario a PostgREST; jamás `service_role`).
 *
 * Invariante de seguridad (§2.3, §f.1): el `sub` SIEMPRE del JWT verificado, NUNCA del body. El RPC
 * `claim_account` usa `auth.uid()` adentro; cualquier `sub`/`id`/`user_id` del payload se DESCARTA.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { jsonError } from "../errors";
import { gateRequest } from "../ratelimit";
import type { SessionClaims } from "../attest/session";
import { bearerToken, callRpc, getRows, verifyUserToken } from "./userauth";

type Ctx = Context<{ Bindings: Env }>;

interface AuthedUser {
  sub: string;
  userJWT: string;
}

/**
 * Auth de las rutas de cuenta: solo el JWT de usuario (Supabase) + rate-limit. A diferencia de las
 * rutas de sync NO exige App Attest — el claim precede al `/attest/bind`, así que el device todavía
 * no tiene una sesión de attest. El bucket de rate-limit usa el `sub` (reusa el limiter `sync`, la
 * categoría existente del Modo Nube; en tests sin Durable Object se omite).
 */
async function requireUser(c: Ctx): Promise<AuthedUser | Response> {
  const token = bearerToken(c.req.header("Authorization"));
  if (!token) return jsonError("yala_attest_required", "Falta el JWT de usuario (Authorization: Bearer).", 401);
  const user = await verifyUserToken(c.env, token);
  if (!user) return jsonError("yala_attest_invalid", "JWT de usuario inválido o expirado.", 401);

  if (c.env.RATE_LIMITER) {
    const claims: SessionClaims = { keyId: `sub:${user.sub}`, tier: "free" };
    const blocked = await gateRequest(c.env, claims, "sync");
    if (blocked) return blocked;
  }

  return { sub: user.sub, userJWT: user.token };
}

// ----------------------------------------------------------------------------------- /account/claim

/**
 * Reserva ATÓMICA de la cuenta (§f.1). Body `{device_id, provider}`. Descarta cualquier `sub`/`id`/
 * `user_id` del body (el sub sale del JWT vía `claim_account`→`auth.uid()`). Devuelve el estado de 3
 * valores tal cual lo emite el RPC: `created` | `existing_stable` | `claiming_in_progress`.
 */
export async function handleAccountClaim(c: Ctx): Promise<Response> {
  const auth = await requireUser(c);
  if (auth instanceof Response) return auth;

  let body: Record<string, unknown>;
  try {
    body = await c.req.json<Record<string, unknown>>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }

  // El sub SIEMPRE del JWT — cualquier intento de inyectarlo por el body se descarta (metadata-only log).
  for (const k of ["sub", "id", "user_id"]) {
    if (k in body) console.log(`[account-claim] descartando '${k}' del payload (se usa el sub del JWT)`);
  }

  const deviceId = typeof body.device_id === "string" ? body.device_id : "";
  const provider = typeof body.provider === "string" ? body.provider : "";
  if (!deviceId || !provider) {
    return jsonError("yala_bad_request", "Se espera { device_id, provider }", 400);
  }

  const { ok, status, body: out } = await callRpc(c.env, auth.userJWT, "claim_account", {
    p_device_id: deviceId,
    p_provider: provider,
  });
  if (!ok) {
    console.log(`[account-claim] claim_account upstream ${status}`);
    return jsonError("yala_unavailable", `claim upstream ${status}`, 502);
  }
  return c.json((out ?? {}) as Record<string, unknown>);
}

// ---------------------------------------------------------------------------------- /account/exists

/**
 * ¿El `sub` autenticado ya tiene fila en `profiles`? Es un HINT de encaminamiento barato para la UI
 * (§f.1) — NO la garantía anti-doble-siembra: esa la da la atomicidad de `POST /account/claim`. RLS
 * filtra a la fila del propio usuario, así que basta con ver si hay una.
 */
export async function handleAccountExists(c: Ctx): Promise<Response> {
  const auth = await requireUser(c);
  if (auth instanceof Response) return auth;

  const { ok, status, rows } = await getRows(c.env, auth.userJWT, "profiles", "select=id&limit=1");
  if (!ok) return jsonError("yala_unavailable", `exists upstream ${status}`, 502);
  return c.json({ exists: rows.length > 0 });
}
