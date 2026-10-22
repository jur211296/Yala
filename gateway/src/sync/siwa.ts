/**
 * SIWA revoke 5.1.1(v) — Bloque B1 del gate §12. Dos endpoints STATELESS (el Worker jamás persiste
 * tokens de nadie; el refresh token de Apple viaja de vuelta al cliente y vive en SU Keychain):
 *
 *   - `POST /account/siwa/exchange` — canjea el `authorization_code` del sign-in nativo por el
 *     `refresh_token` de Apple (`/auth/token`). El code es de un solo uso y expira en ~5 min, por eso
 *     el canje ocurre EN el sign-in (best-effort client-side), no al borrar la cuenta.
 *   - `POST /account/siwa/revoke` — revoca ese `refresh_token` (`/auth/revoke`) como paso 4a del
 *     borrado de cuenta (Guideline 5.1.1(v)).
 *
 * `client_secret` de Apple: JWT ES256 firmado con la .p8 de SIWA — la .p8 JAMÁS sale del server
 * (secret `SIWA_AUTH_KEY`). Molde exacto `push/apns.ts::signApnsJwt`; diferencias: claims sub =
 * client_id (bundle), aud = appleid.apple.com y exp CORTO (5 min por request, sin cache — más simple
 * y sin estado; la firma ES256 es barata a este volumen: 1 exchange por sign-in, 1 revoke por borrado).
 *
 * Invariante multi-sitio intacto: el Worker no gana credencial que lea datos de usuario (el refresh
 * token de Apple ni siquiera pasa por reposo server-side).
 *
 * D3 (rate-limit) — VERIFICADO: ambos endpoints quedan DENTRO del paraguas de rate-limit por device
 * existente. `requireUser` y `requireUserAndAttest` (sync/account.ts) invocan `gateRequest(env,
 * claims, "sync")` cuando el binding `RATE_LIMITER` existe (bucket por keyId de attest o `sub:<sub>`),
 * ANTES de cualquier fetch a Apple. No hay residual que anotar.
 *
 * Logs SIN tokens: el authorization_code/refresh_token jamás entero (prefijo ≤8 solo si hace falta
 * correlación); el body de error de Apple NO se vuelca a logs ni al cliente (puede portar tokens).
 */
import type { Context } from "hono";
import { importPKCS8, SignJWT } from "jose";
import type { Env } from "../env";
import { acceptedBundleIDs } from "../env";
import { jsonError } from "../errors";
import { requireUser, requireUserAndAttest } from "./account";

type Ctx = Context<{ Bindings: Env }>;

const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";

/** El .p8 pegado como secret puede llegar con `\n` literales; normalizar a saltos reales (clon de apns.ts). */
function normalizePem(pem: string): string {
  return pem.replace(/\\n/g, "\n").trim();
}

/**
 * `client_id` del canje/revoke: el bundle id de la app. `APPLE_BUNDLE_IDS` es single-valued por env HOY
 * (staging `.dev`, prod el bundle de producción) — se toma el primer elemento del split por coma. Si
 * algún día un env acepta 2 bundles, el exchange necesitará un hint del cliente (fuera de alcance B1).
 */
function siwaClientId(env: Env): string {
  return acceptedBundleIDs(env)[0];
}

/**
 * Firma el `client_secret` de Apple: JWT ES256 con la .p8 de SIWA. Claims según la doc de Apple:
 * iss = Team ID, sub = client_id, aud = https://appleid.apple.com, iat + exp (corto: 5 min por
 * request — sin cache de 6 meses, sin estado module-scope).
 */
export async function signSiwaClientSecret(env: Env): Promise<string> {
  const key = await importPKCS8(normalizePem(env.SIWA_AUTH_KEY!), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: env.SIWA_KEY_ID! })
    .setIssuer(env.APPLE_TEAM_ID)
    .setSubject(siwaClientId(env))
    .setAudience("https://appleid.apple.com")
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(key);
}

/** Guard de configuración (molde GROUPS_ENC_KEY): sin la .p8/keyId los 2 endpoints degradan a 503, jamás crash. */
function siwaConfigGuard(env: Env): Response | null {
  if (!env.SIWA_AUTH_KEY || !env.SIWA_KEY_ID) {
    return jsonError("yala_siwa_not_configured", "SIWA no configurado (falta SIWA_AUTH_KEY/SIWA_KEY_ID)", 503);
  }
  return null;
}

/**
 * Shape-check del `authorization_code` (AJUSTE #5 del /review-plan) y del `refresh_token` (misma
 * clase de opaco de Apple, mismo charset). Rechaza temprano basura/inyección sin tocar a Apple.
 */
const APPLE_OPAQUE_TOKEN_SHAPE = /^[A-Za-z0-9._-]{10,2048}$/;

export function isValidAppleOpaqueToken(value: unknown): value is string {
  return typeof value === "string" && APPLE_OPAQUE_TOKEN_SHAPE.test(value);
}

// ---------------------------------------------------------------------- POST /account/siwa/exchange

/**
 * Canje del authorization_code → `{ refresh_token }` (SOLO ese campo: el id_token/access_token de
 * Apple NO se reenvían — minimización). Auth `requireUser` (NO attest — load-bearing: el sign-in
 * PRECEDE al `/attest/bind`, la misma asimetría documentada del resto de `/account/*`; un attest
 * obligatorio aquí fallaría SIEMPRE en el primer sign-in).
 *
 * El form hacia Apple OMITE `redirect_uri` (AJUSTE #3): solo aplica al flujo web — con un code de
 * `ASAuthorizationController` enviarlo produce `invalid_grant`.
 */
export async function handleSiwaExchange(c: Ctx): Promise<Response> {
  const auth = await requireUser(c);
  if (auth instanceof Response) return auth;

  const guard = siwaConfigGuard(c.env);
  if (guard) return guard;

  let body: Record<string, unknown>;
  try {
    body = await c.req.json<Record<string, unknown>>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }

  const code = body.authorization_code;
  if (!isValidAppleOpaqueToken(code)) {
    return jsonError("yala_bad_input", "authorization_code con shape inválido", 400);
  }

  const clientSecret = await signSiwaClientSecret(c.env);
  const form = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    client_id: siwaClientId(c.env),
    client_secret: clientSecret,
    // SIN redirect_uri — deliberado (flujo nativo).
  });

  let res: Response;
  try {
    res = await fetch(APPLE_TOKEN_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    });
  } catch (err) {
    console.log(`[siwa-exchange] transporte a Apple falló: ${String(err)}`);
    return jsonError("yala_unavailable", "Apple /auth/token unreachable", 502);
  }

  if (!res.ok) {
    // JAMÁS el body de Apple a logs/respuesta (puede portar tokens); el code solo como prefijo ≤8.
    console.log(`[siwa-exchange] Apple ${res.status} code=${code.slice(0, 8)}…`);
    return jsonError("yala_unavailable", `Apple token upstream ${res.status}`, 502);
  }

  let out: unknown = null;
  try {
    out = await res.json();
  } catch {
    return jsonError("yala_unavailable", "Apple token response undecodable", 502);
  }
  const refreshToken = (out as { refresh_token?: unknown }).refresh_token;
  if (typeof refreshToken !== "string" || refreshToken.length === 0) {
    return jsonError("yala_unavailable", "Apple token response sin refresh_token", 502);
  }
  return c.json({ refresh_token: refreshToken });
}

// ------------------------------------------------------------------------ POST /account/siwa/revoke

/**
 * Revocación del refresh_token (5.1.1(v)). Auth `requireUserAndAttest` — mismo molde que
 * `/account/delete` (coherencia: ambos son pasos del mismo flujo destructivo; en staging `observe`
 * el attest es opcional). Apple responde 200 vacío → `{ revoked: true }`; fallo → 502 (el cliente lo
 * trata best-effort — el borrado JAMÁS se bloquea por esto).
 */
export async function handleSiwaRevoke(c: Ctx): Promise<Response> {
  const auth = await requireUserAndAttest(c);
  if (auth instanceof Response) return auth;

  const guard = siwaConfigGuard(c.env);
  if (guard) return guard;

  let body: Record<string, unknown>;
  try {
    body = await c.req.json<Record<string, unknown>>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }

  const refreshToken = body.refresh_token;
  if (!isValidAppleOpaqueToken(refreshToken)) {
    return jsonError("yala_bad_input", "refresh_token con shape inválido", 400);
  }

  const clientSecret = await signSiwaClientSecret(c.env);
  const form = new URLSearchParams({
    client_id: siwaClientId(c.env),
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: "refresh_token",
  });

  let res: Response;
  try {
    res = await fetch(APPLE_REVOKE_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: form.toString(),
    });
  } catch (err) {
    console.log(`[siwa-revoke] transporte a Apple falló: ${String(err)}`);
    return jsonError("yala_unavailable", "Apple /auth/revoke unreachable", 502);
  }

  if (!res.ok) {
    console.log(`[siwa-revoke] Apple ${res.status} token=${refreshToken.slice(0, 8)}…`);
    return jsonError("yala_unavailable", `Apple revoke upstream ${res.status}`, 502);
  }
  return c.json({ revoked: true });
}
