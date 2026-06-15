import type { Env } from "../env";
import { acceptedBundleIDs } from "../env";
import { verifyAppleJWS } from "./verifyAppleJWS";

/** Entitlement Pro verificado (firma de Apple). */
export interface Entitlement {
  productId: string;
  expiresAtMs: number;
  originalTransactionId: string;
}

interface TransactionPayload {
  bundleId?: string;
  productId?: string;
  type?: string;
  expiresDate?: number; // epoch ms
  originalTransactionId?: string;
  revocationDate?: number;
  environment?: string; // "Sandbox" | "Production"
}

/**
 * Verifica la transacción StoreKit 2 firmada (jwsRepresentation) y devuelve el entitlement si es
 * una suscripción auto-renovable vigente, no revocada, de nuestro bundle. Cualquier suscripción
 * activa de Yala = Pro (Yala tiene una única suscripción Pro). Acepta Sandbox y Production.
 */
export async function verifyStoreKitJWS(env: Env, jws: string | undefined): Promise<Entitlement | null> {
  if (!jws) return null;
  const payload = (await verifyAppleJWS(jws)) as TransactionPayload | null;
  if (!payload) return null;

  if (!payload.bundleId || !acceptedBundleIDs(env).includes(payload.bundleId)) return null;
  if (payload.type !== "Auto-Renewable Subscription") return null;
  if (payload.revocationDate) return null;
  if (!payload.productId || !payload.originalTransactionId || !payload.expiresDate) return null;
  if (payload.expiresDate <= Date.now()) return null;
  // En producción exigir transacción de Production (no Sandbox). Staging acepta ambas (TestFlight/QA).
  // Sin esto, una suscripción sandbox (gratis de crear) firmada por Apple daría Pro en prod.
  if (env.ENVIRONMENT === "production" && payload.environment !== "Production") return null;

  return {
    productId: payload.productId,
    expiresAtMs: payload.expiresDate,
    originalTransactionId: payload.originalTransactionId,
  };
}
