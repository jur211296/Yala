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
  if (!jws) return null; // sin suscripción (usuario Free) — caso común, no se loguea
  const payload = (await verifyAppleJWS(jws)) as TransactionPayload | null;
  if (!payload) {
    console.log("[storekit-reject] jws-invalid");
    return null;
  }
  if (!payload.bundleId || !acceptedBundleIDs(env).includes(payload.bundleId)) {
    console.log(`[storekit-reject] bundleId:${payload.bundleId}`);
    return null;
  }
  if (payload.type !== "Auto-Renewable Subscription") {
    console.log(`[storekit-reject] type:${payload.type}`);
    return null;
  }
  if (payload.revocationDate) {
    console.log("[storekit-reject] revoked");
    return null;
  }
  if (!payload.productId || !payload.originalTransactionId || !payload.expiresDate) {
    console.log("[storekit-reject] missing-fields");
    return null;
  }
  if (payload.expiresDate <= Date.now()) {
    console.log("[storekit-reject] expired");
    return null;
  }

  // TestFlight usa StoreKit SANDBOX incluso en builds de producción → se aceptan Sandbox Y Production.
  // La barrera real es App Attest (entorno production: solo builds genuinas de TestFlight/App Store) +
  // el rate-limit por device. Rechazar Sandbox rompería a TODOS los testers de TestFlight.
  if (env.ENVIRONMENT === "production" && payload.environment === "Sandbox") {
    console.log("[storekit] sandbox sub aceptada en prod (TestFlight)");
  }

  return {
    productId: payload.productId,
    expiresAtMs: payload.expiresDate,
    originalTransactionId: payload.originalTransactionId,
  };
}
