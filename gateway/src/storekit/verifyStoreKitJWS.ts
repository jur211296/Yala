import type { Env } from "../env";
import { acceptedBundleIDs } from "../env";
import { verifyAppleJWS } from "./verifyAppleJWS";

/**
 * Los productos que otorgan Pro. Espejo de `StoreKitManager.proMonthlyID`/`proYearlyID` — si se
 * añade un producto allí y no aquí, sus compradores no obtienen el derecho server-side.
 */
export const PRO_PRODUCT_IDS = ["com.yala.pro.monthly", "com.yala.pro.yearly"];

/** Entitlement Pro verificado (firma de Apple). */
export interface Entitlement {
  productId: string;
  expiresAtMs: number;
  originalTransactionId: string;
  /**
   * C-8: la cuenta de Yala que el comprador declaró AL COMPRAR (`Product.PurchaseOption
   * .appAccountToken` = el `sub` de la sesión de nube). Viaja DENTRO del JWS firmado por Apple,
   * así que es la única señal de propiedad que el cliente no puede falsear. `null` en las compras
   * anteriores al fix y en las hechas sin sesión de nube — esas se vinculan por JWT en el bind.
   */
  appAccountToken: string | null;
  /** `"Sandbox"` | `"Production"`. Lo consume el bind, que aplica su propia política. */
  environment: string | null;
}

interface TransactionPayload {
  bundleId?: string;
  productId?: string;
  type?: string;
  expiresDate?: number; // epoch ms
  originalTransactionId?: string;
  revocationDate?: number;
  environment?: string; // "Sandbox" | "Production"
  appAccountToken?: string; // UUID (lowercase) de la cuenta de nube; ausente = compra sin sesión
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
  // C-8: «cualquier suscripción activa de Yala = Pro» era cierto con UN solo producto, y se vuelve
  // un regalo silencioso el día que exista una segunda suscripción bajo el mismo bundle (un tier
  // básico, un add-on): su JWS pasaría el resto de validaciones y otorgaría Pro completo.
  if (!payload.productId || !PRO_PRODUCT_IDS.includes(payload.productId)) {
    console.log(`[storekit-reject] productId:${payload.productId}`);
    return null;
  }
  if (payload.revocationDate) {
    console.log("[storekit-reject] revoked");
    return null;
  }
  if (!payload.originalTransactionId || !payload.expiresDate) {
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
    environment: payload.environment ?? null,
    // Normalizado a lowercase: el `sub` de Supabase viaja lowercase y StoreKit devuelve el UUID
    // en mayúsculas — compararlos crudos daría un falso mismatch en TODAS las compras.
    appAccountToken: typeof payload.appAccountToken === "string" && payload.appAccountToken.length > 0
      ? payload.appAccountToken.toLowerCase()
      : null,
  };
}
