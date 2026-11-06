import type { Context } from "hono";
import { type Env, acceptedBundleIDs } from "../env";
import { updateAccountEntitlementByOriginalTxn, updateEntitlementByOriginalTxn } from "../db";
import { verifyAppleJWS } from "../storekit/verifyAppleJWS";
import { appstoreNotificationDetail, serverEvent } from "../serverEvent";

type Ctx = Context<{ Bindings: Env }>;

interface SignedTransaction {
  originalTransactionId?: string;
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
  bundleId?: string;
  offerDiscountType?: string;
}

/**
 * App Store Server Notifications V2. Defensa-en-profundidad: acelera la revocación
 * (cancelación/reembolso/expiración) sin esperar al refresh de sesión de ≤15 min.
 *
 * Apple POSTea { signedPayload: JWS }. El payload trae data.signedTransactionInfo (otro JWS).
 * Verificamos ambos contra el G3 y aplicamos el estado por originalTransactionId (idempotente).
 */
export async function handleAppStoreWebhook(c: Ctx): Promise<Response> {
  let body: { signedPayload?: unknown };
  try {
    body = await c.req.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }
  if (typeof body.signedPayload !== "string") return new Response("missing signedPayload", { status: 400 });

  const payload = await verifyAppleJWS(body.signedPayload);
  if (!payload) return new Response("invalid signature", { status: 401 });

  const data = payload.data as { signedTransactionInfo?: unknown; bundleId?: unknown; environment?: unknown } | undefined;
  let tx: SignedTransaction | null = null;
  if (typeof data?.signedTransactionInfo === "string") {
    tx = (await verifyAppleJWS(data.signedTransactionInfo)) as SignedTransaction | null;
    // El G3 firma transacciones de TODAS las apps de la App Store → exigir nuestro bundleId,
    // o un atacante con su propia app podría enviar transacciones ajenas.
    if (tx?.originalTransactionId && tx.bundleId && acceptedBundleIDs(c.env).includes(tx.bundleId)) {
      // C-8: la misma reconciliación se aplica a las DOS superficies — por device (attest_keys) y
      // por cuenta (account_entitlements). Si solo se actualizara la primera, un reembolso dejaría
      // el derecho vivo en la cuenta hasta la fecha de expiración original.
      if (tx.revocationDate != null) {
        const revoked = { product: tx.productId ?? null, expiresAtMs: 0 };
        await updateEntitlementByOriginalTxn(c.env, tx.originalTransactionId, revoked);
        await updateAccountEntitlementByOriginalTxn(c.env, tx.originalTransactionId, revoked);
      } else if (tx.expiresDate != null) {
        const renewed = { product: tx.productId ?? null, expiresAtMs: tx.expiresDate };
        await updateEntitlementByOriginalTxn(c.env, tx.originalTransactionId, renewed);
        await updateAccountEntitlementByOriginalTxn(c.env, tx.originalTransactionId, renewed);
      }
      // Sin expiresDate ni revocación (notificación no-relevante) → no tocar, para no revocar a un pagador.
    }
  }
  // Telemetría propia (decisión 5, 2026-11-06): el panel cuenta pruebas, compras, renovaciones y bajas desde aquí.
  // Solo avisos de NUESTRO bundle (el G3 firma los de todas las apps) y solo tipos: ni ids ni importes.
  const bundleId = typeof data?.bundleId === "string" ? data.bundleId : tx?.bundleId;
  if (bundleId && acceptedBundleIDs(c.env).includes(bundleId)) {
    serverEvent(
      c.env,
      "appstoreNotification",
      appstoreNotificationDetail({
        notificationType: payload.notificationType,
        subtype: payload.subtype,
        offerDiscountType: tx ? (tx.offerDiscountType ?? null) : undefined,
        environment: data?.environment,
      }),
    );
  }
  // 200 siempre que la firma sea válida (evita reintentos de Apple por notificaciones no accionables).
  return new Response("ok", { status: 200 });
}
