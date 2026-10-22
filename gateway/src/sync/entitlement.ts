/**
 * Rutas de ENTITLEMENT por cuenta (C-8, 2026-07-27): `POST /account/entitlement` (vincular) y
 * `GET /account/entitlement` (consultar).
 *
 * El problema que cierran: `isProUser` del cliente sale de `Transaction.currentEntitlements`, que
 * está scoped al Apple ID del device. Quien migra a la nube justamente para no depender de Apple y
 * entra con su cuenta de Yala en un device con OTRO Apple ID ve sus datos y pierde Pro sobre ellos,
 * con el límite de creación aplicado a un corpus que ya lo excede.
 *
 * Modelo de confianza: el derecho lo otorga SIEMPRE una transacción firmada por Apple y verificada
 * offline contra el Root CA G3 (`verifyStoreKitJWS`); el JWT de usuario solo dice A QUÉ CUENTA se
 * vincula. Un cliente no puede fabricar un JWS, así que el peor caso de un atacante es vincular su
 * PROPIA suscripción a su propia cuenta.
 *
 * Precedencia del dueño (los dos casos que existen):
 *  - El JWS trae `appAccountToken` (compras posteriores al fix): ES la autoridad. Si no coincide con
 *    el `sub` del JWT → 409, sin escribir nada. El comprador ya declaró la cuenta al comprar.
 *  - El JWS no lo trae (los Pro de hoy, que compraron antes de que el cliente lo emitiera): se
 *    vincula por JWT — es el único puente posible para esa población, y sigue exigiendo tener la
 *    transacción firmada EN el device.
 *
 * Auth: `requireUser` (solo JWT de usuario), igual que el resto de `/account/*` — el bind de attest
 * puede no haber ocurrido y no queremos que un device sin attest pierda su derecho.
 */
import type { Context } from "hono";
import type { Env } from "../env";
import { jsonError } from "../errors";
import { verifyStoreKitJWS } from "../storekit/verifyStoreKitJWS";
import {
  bindAccountEntitlement,
  getAccountEntitlement,
  getAccountEntitlementByOriginalTxn,
  isAccountProActive,
  type AccountEntitlementRow,
} from "../db";
import { requireUser } from "./account";

type Ctx = Context<{ Bindings: Env }>;

/** Respuesta común de las dos rutas: lo mínimo que el cliente necesita para resolver el derecho. */
function entitlementBody(row: AccountEntitlementRow | null): Record<string, unknown> {
  return {
    pro: isAccountProActive(row),
    product: row?.entitlement_product ?? null,
    // El cliente CACHEA este epoch: firmado por Apple, así que sirve de derecho offline hasta esa
    // fecha sin regalar nada (es el mismo horizonte que StoreKit aplicaría en local).
    expires_at_ms: row?.entitlement_expires_at ?? null,
  };
}

// ------------------------------------------------------------------- POST /account/entitlement

export async function handleEntitlementBind(c: Ctx): Promise<Response> {
  const auth = await requireUser(c);
  if (auth instanceof Response) return auth;

  let body: Record<string, unknown>;
  try {
    body = await c.req.json<Record<string, unknown>>();
  } catch {
    return jsonError("yala_bad_request", "JSON inválido", 400);
  }

  // El sub SIEMPRE del JWT — cualquier intento de inyectarlo por el body se descarta.
  for (const k of ["sub", "id", "user_id"]) {
    if (k in body) console.log(`[entitlement-bind] descartando '${k}' del payload (se usa el sub del JWT)`);
  }

  const jws = typeof body.storekit_jws === "string" && body.storekit_jws.length > 0 ? body.storekit_jws : null;
  if (!jws) return jsonError("yala_bad_request", "Se espera { storekit_jws }", 400);

  const ent = await verifyStoreKitJWS(c.env, jws);
  if (!ent) {
    // JWS inválido, de otro bundle, revocado o expirado: NO es un error del usuario que merezca
    // ruido — devolver el estado real de la cuenta (probablemente Free) sin tocar nada.
    return c.json(entitlementBody(await getAccountEntitlement(c.env, auth.sub)));
  }

  // `verifyStoreKitJWS` acepta Sandbox en producción a propósito (TestFlight usa StoreKit sandbox
  // incluso en builds de producción), y su comentario justifica el riesgo diciendo que la barrera
  // real es App Attest. Esta ruta usa `requireUser` SIN attest, así que esa barrera no está — y aquí
  // el premio es mayor que en el proxy de IA: una compra sandbox gratuita concedería Pro a una
  // cuenta de PRODUCCIÓN, en todos sus devices y de forma persistente. Los testers conservan su Pro
  // local (`currentEntitlements` ya se lo da); lo único que no se propaga es el derecho de cuenta.
  if (c.env.ENVIRONMENT === "production" && ent.environment === "Sandbox") {
    console.log("[entitlement-bind] sandbox en producción — no otorga derecho de cuenta");
    return c.json(entitlementBody(await getAccountEntitlement(c.env, auth.sub)));
  }

  const existing = await getAccountEntitlementByOriginalTxn(c.env, ent.originalTransactionId);

  // Un JWS es un string que el dueño del device puede guardar y reenviar. Si el webhook YA revocó
  // esa suscripción (reembolso/cancelación ⇒ `expires_at = 0`), un re-bind con el JWS viejo la
  // resucitaría hasta su `expiresDate` original — Pro gratis a cambio de un reembolso. La
  // revocación es terminal: solo una notificación de Apple puede levantarla.
  if (existing && existing.entitlement_expires_at === 0) {
    console.log("[entitlement-bind] suscripción revocada — bind ignorado");
    return c.json(entitlementBody(await getAccountEntitlement(c.env, auth.sub)));
  }

  // La compra declaró OTRA cuenta: el token firmado gana sobre el JWT... pero SOLO mientras esa
  // cuenta siga siendo la dueña viva de la suscripción. Sin la segunda condición, quien borra su
  // cuenta de Yala y crea otra queda bloqueado para siempre (Apple no permite cambiar el
  // `appAccountToken` de una suscripción ya comprada), contra la decisión «última vinculación gana».
  if (ent.appAccountToken && ent.appAccountToken !== auth.sub && existing && existing.user_id !== auth.sub) {
    console.log("[entitlement-bind] appAccountToken de otra cuenta viva — rechazado");
    return jsonError("yala_entitlement_owner_mismatch", "La suscripción pertenece a otra cuenta de Yala.", 409);
  }

  await bindAccountEntitlement(c.env, auth.sub, {
    product: ent.productId,
    expiresAtMs: ent.expiresAtMs,
    originalTransactionId: ent.originalTransactionId,
    boundVia: ent.appAccountToken ? "app_account_token" : "jwt",
  });

  return c.json(entitlementBody(await getAccountEntitlement(c.env, auth.sub)));
}

// -------------------------------------------------------------------- GET /account/entitlement

export async function handleEntitlementGet(c: Ctx): Promise<Response> {
  const auth = await requireUser(c);
  if (auth instanceof Response) return auth;
  return c.json(entitlementBody(await getAccountEntitlement(c.env, auth.sub)));
}
