import type { Context } from "hono";
import type { Env } from "../env";
import { acceptedBundleIDs, allowsDevBypass } from "../env";
import { jsonError } from "../errors";
import { issueChallenge, verifyChallenge } from "./challenge";
import { AttestError, verifyAttestation } from "./verifyAttestation";
import { verifyAssertion } from "./verifyAssertion";
import { issueSessionToken, type Tier } from "./session";
import { verifyStoreKitJWS } from "../storekit/verifyStoreKitJWS";
import { type AttestKeyRow, getAttestKey, insertAttestKey, isProActive, publicKeyBytes, updateCounter, updateEntitlement } from "../db";

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

/** Verifica el JWS de StoreKit (si llega), actualiza el cache de entitlement y devuelve el tier. */
async function applyEntitlement(
  env: Env,
  keyId: string,
  storeKitJWS: string | null,
  cached: AttestKeyRow | null,
): Promise<Tier> {
  // Solo-staging: trata a cualquier device atestado como Pro (para QA sin suscripción real).
  // Defensa en profundidad: además del flag, exige entorno no-prod (`allowsDevBypass`), así un
  // copy-paste del flag al bloque de prod NO regala Pro a todos.
  if (env.TRUST_ATTESTED_AS_PRO === "true" && allowsDevBypass(env)) return "pro";
  if (storeKitJWS) {
    const ent = await verifyStoreKitJWS(env, storeKitJWS);
    await updateEntitlement(
      env,
      keyId,
      ent ? { product: ent.productId, expiresAtMs: ent.expiresAtMs, originalTransactionId: ent.originalTransactionId } : null,
    );
    return ent && ent.expiresAtMs > Date.now() ? "pro" : "free";
  }
  return cached && isProActive(cached) ? "pro" : "free";
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

  const tier = await applyEntitlement(c.env, keyId, storeKitJWS, null);
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
  if (!keyId || !assertion || !challenge) return jsonError("yala_bad_request", "faltan campos requeridos", 400);

  if (!(await verifyChallenge(c.env, challenge))) {
    return jsonError("yala_attest_invalid", "challenge inválido o expirado", 401);
  }

  const row = await getAttestKey(c.env, keyId);
  if (!row) return jsonError("yala_attest_unknown_key", "key no registrada; re-registrar", 401);
  if (row.revoked) return jsonError("yala_attest_invalid", "key revocada", 401);

  try {
    const { newCounter } = await verifyAssertion(assertion, challenge, publicKeyBytes(row), row.counter, appIds(c.env));
    await updateCounter(c.env, keyId, newCounter);
  } catch (e) {
    console.log(`[assert-exc] ${e instanceof Error ? e.message : String(e)}`);
    return jsonError("yala_attest_invalid", e instanceof AttestError ? e.message : "assertion inválida", 401);
  }

  const tier = await applyEntitlement(c.env, keyId, storeKitJWS, row);
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
