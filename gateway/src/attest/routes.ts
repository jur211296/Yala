import type { Context } from "hono";
import type { Env } from "../env";
import { acceptedBundleIDs, allowsDevBypass } from "../env";
import { jsonError } from "../errors";
import { issueChallenge, verifyChallenge } from "./challenge";
import { AttestError, verifyAttestation } from "./verifyAttestation";
import { verifyAssertion } from "./verifyAssertion";
import { issueSessionToken, type Tier } from "./session";
import { verifyStoreKitJWS } from "../storekit/verifyStoreKitJWS";
import {
  type AttestKeyRow,
  getAccountEntitlement,
  getAttestKey,
  insertAttestKey,
  isAccountProActive,
  isProActive,
  publicKeyBytes,
  updateCounter,
  updateEntitlement,
} from "../db";
import { verifyUserToken } from "../sync/userauth";

type Ctx = Context<{ Bindings: Env }>;

function appIds(env: Env): string[] {
  return acceptedBundleIDs(env).map((b) => `${env.APPLE_TEAM_ID}.${b}`);
}

function str(v: unknown): string | null {
  return typeof v === "string" && v.length > 0 ? v : null;
}

async function readBody(c: Ctx): Promise<Record<string, unknown> | null> {
  try {
    return await c.req.json<Record<string, unknown>>();
  } catch {
    return null;
  }
}

/**
 * Verifica el JWS de StoreKit (si llega), actualiza el cache de entitlement y devuelve el tier.
 *
 * C-8: el tier ya no sale SOLO del device. Si el cliente adjunta el JWT de su cuenta de nube, el
 * derecho de esa CUENTA también cuenta — si no, el device donde C-8 devuelve Pro (otro Apple ID,
 * misma cuenta de Yala) tendría el chat y los insights desbloqueados en la UI y recibiría 403
 * `yala_pro_required` del proxy. El JWT es opcional y su ausencia deja el comportamiento anterior
 * intacto; un JWT inválido se ignora en silencio (no es una ruta de auth, es un dato de más).
 */
async function applyEntitlement(
  env: Env,
  keyId: string,
  storeKitJWS: string | null,
  cached: AttestKeyRow | null,
  userJWT: string | null = null,
): Promise<Tier> {
  // Solo-staging: trata a cualquier device atestado como Pro (para QA sin suscripción real).
  // Defensa en profundidad: además del flag, exige entorno no-prod (`allowsDevBypass`), así un
  // copy-paste del flag al bloque de prod NO regala Pro a todos.
  if (env.TRUST_ATTESTED_AS_PRO === "true" && allowsDevBypass(env)) return "pro";

  let deviceTier: Tier = "free";
  if (storeKitJWS) {
    const ent = await verifyStoreKitJWS(env, storeKitJWS);
    await updateEntitlement(
      env,
      keyId,
      ent ? { product: ent.productId, expiresAtMs: ent.expiresAtMs, originalTransactionId: ent.originalTransactionId } : null,
    );
    deviceTier = ent && ent.expiresAtMs > Date.now() ? "pro" : "free";
  } else {
    deviceTier = cached && isProActive(cached) ? "pro" : "free";
  }
  if (deviceTier === "pro") return "pro";

  return (await accountTier(env, userJWT)) ?? "free";
}

/** Tier derivado de la CUENTA de nube (C-8). `null` = sin JWT usable / sin derecho. */
async function accountTier(env: Env, userJWT: string | null): Promise<Tier | null> {
  if (!userJWT) return null;
  const user = await verifyUserToken(env, userJWT);
  if (!user) {
    console.log("[attest] userJWT inválido — tier solo por device");
    return null;
  }
  const row = await getAccountEntitlement(env, user.sub);
  return isAccountProActive(row) ? "pro" : null;
}

export async function handleChallenge(c: Ctx): Promise<Response> {
  const { challenge, ttlMs } = await issueChallenge(c.env);
  return c.json({ challenge, ttlMs });
}

export async function handleRegister(c: Ctx): Promise<Response> {
  const body = await readBody(c);
  if (!body) return jsonError("yala_bad_request", "JSON inválido", 400);
  const keyId = str(body.keyId);
  const attestation = str(body.attestation);
  const challenge = str(body.challenge);
  const storeKitJWS = str(body.storeKitJWS);
  const userJWT = str(body.userJWT);
  if (!keyId || !attestation || !challenge) return jsonError("yala_bad_request", "faltan campos requeridos", 400);

  if (!(await verifyChallenge(c.env, challenge))) {
    return jsonError("yala_attest_invalid", "challenge inválido o expirado", 401);
  }

  try {
    const result = await verifyAttestation(attestation, keyId, challenge, appIds(c.env), c.env.ATTEST_ENV);
    await insertAttestKey(c.env, {
      key_id: keyId,
      public_key: result.publicKeySpki,
      counter: result.signCount,
      attest_env: c.env.ATTEST_ENV,
    });
  } catch (e) {
    return jsonError("yala_attest_invalid", e instanceof AttestError ? e.message : "attestation inválida", 401);
  }

  const tier = await applyEntitlement(c.env, keyId, storeKitJWS, null, userJWT);
  const { token, expMs } = await issueSessionToken(c.env, { keyId, tier });
  return c.json({ sessionToken: token, expMs, tier });
}

export async function handleAssert(c: Ctx): Promise<Response> {
  const body = await readBody(c);
  if (!body) return jsonError("yala_bad_request", "JSON inválido", 400);
  const keyId = str(body.keyId);
  const assertion = str(body.assertion);
  const challenge = str(body.challenge);
  const storeKitJWS = str(body.storeKitJWS);
  const userJWT = str(body.userJWT);
  if (!keyId || !assertion || !challenge) return jsonError("yala_bad_request", "faltan campos requeridos", 400);

  if (!(await verifyChallenge(c.env, challenge))) {
    return jsonError("yala_attest_invalid", "challenge inválido o expirado", 401);
  }

  const row = await getAttestKey(c.env, keyId);
  if (!row) return jsonError("yala_attest_unknown_key", "key no registrada; re-registrar", 401);
  if (row.revoked) return jsonError("yala_attest_invalid", "key revocada", 401);

  // Accepted-risk (2026-06-16, decisión del owner): el ciclo leer-verificar-escribir del counter NO
  // es atómico. Un /code-review puede marcarlo como race — está aceptado a propósito, NO es bug.
  // El replay SECUENCIAL ya lo bloquea verifyAssertion (newCounter <= stored → throw); el único hueco
  // es replay CONCURRENTE de una assertion CAPTURADA en ventana de ms, y el blast radius está acotado
  // por rate-limit por device + gate Pro + hard cap de OpenAI (no expone keys ni datos). Fix disponible
  // si cambia el modelo de amenaza: CAS en updateCounter (UPDATE … WHERE key_id=? AND counter<?) +
  // rechazar si changes===0. Ver DESIGN-secure-proxy-gateway.md.
  try {
    const { newCounter } = await verifyAssertion(assertion, challenge, publicKeyBytes(row), row.counter, appIds(c.env));
    await updateCounter(c.env, keyId, newCounter);
  } catch (e) {
    console.log(`[assert-exc] ${e instanceof Error ? e.message : String(e)}`);
    return jsonError("yala_attest_invalid", e instanceof AttestError ? e.message : "assertion inválida", 401);
  }

  const tier = await applyEntitlement(c.env, keyId, storeKitJWS, row, userJWT);
  const { token, expMs } = await issueSessionToken(c.env, { keyId, tier });
  return c.json({ sessionToken: token, expMs, tier });
}

/**
 * Bypass de dev/test (solo entorno NO-prod + DEV_SHARED_SECRET). Permite que simulador y
 * XCUITests obtengan un token sin DCAppAttestService (que no corre en simulador).
 */
export async function handleDevToken(c: Ctx): Promise<Response> {
  if (!allowsDevBypass(c.env)) return jsonError("yala_bad_request", "no disponible", 404);
  const secret = c.req.header("X-Yala-Dev-Secret");
  if (!secret || secret !== c.env.DEV_SHARED_SECRET) {
    return jsonError("yala_attest_invalid", "dev secret inválido", 401);
  }
  const tier: Tier = c.req.header("X-Yala-Dev-Tier") === "free" ? "free" : "pro";
  // keyId FIJO: si fuera elegible por el caller, rotarlo evadiría el rate-limit (cada keyId
  // es un bucket nuevo en el Durable Object). Fijo → el dev-bypass comparte un solo bucket.
  const keyId = "dev:shared";
  const { token, expMs } = await issueSessionToken(c.env, { keyId, tier });
  return c.json({ sessionToken: token, expMs, tier });
}
