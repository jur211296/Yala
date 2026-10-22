import type { Env } from "./env";

/** Fila de attest_keys (ver migrations/0001_init.sql). */
export interface AttestKeyRow {
  key_id: string;
  public_key: ArrayBuffer | number[] | Uint8Array; // SPKI DER; D1 devuelve BLOB como number[]
  counter: number;
  revoked: number;
  entitlement_product: string | null;
  entitlement_expires_at: number | null; // epoch ms
  original_transaction_id: string | null;
  attest_env: string;
  created_at: number;
  updated_at: number;
}

/** Normaliza el BLOB de la clave pública (D1 lo devuelve como number[], a veces ArrayBuffer). */
export function publicKeyBytes(row: AttestKeyRow): Uint8Array {
  const v: unknown = row.public_key;
  if (v instanceof Uint8Array) return v;
  if (v instanceof ArrayBuffer) return new Uint8Array(v);
  if (Array.isArray(v)) return Uint8Array.from(v);
  throw new Error("public_key con formato inesperado");
}

export async function getAttestKey(env: Env, keyId: string): Promise<AttestKeyRow | null> {
  return env.DB.prepare("SELECT * FROM attest_keys WHERE key_id = ?").bind(keyId).first<AttestKeyRow>();
}

export async function insertAttestKey(
  env: Env,
  row: Pick<AttestKeyRow, "key_id" | "public_key" | "counter" | "attest_env">,
): Promise<void> {
  const now = Date.now();
  await env.DB.prepare(
    `INSERT INTO attest_keys (key_id, public_key, counter, revoked, attest_env, created_at, updated_at)
     VALUES (?, ?, ?, 0, ?, ?, ?)
     ON CONFLICT(key_id) DO UPDATE SET public_key = excluded.public_key, counter = excluded.counter,
       revoked = 0, attest_env = excluded.attest_env, updated_at = excluded.updated_at`,
  )
    .bind(row.key_id, row.public_key, row.counter, row.attest_env, now, now)
    .run();
}

export async function updateCounter(env: Env, keyId: string, counter: number): Promise<void> {
  await env.DB.prepare("UPDATE attest_keys SET counter = ?, updated_at = ? WHERE key_id = ?")
    .bind(counter, Date.now(), keyId)
    .run();
}

export async function updateEntitlement(
  env: Env,
  keyId: string,
  entitlement: { product: string; expiresAtMs: number; originalTransactionId: string } | null,
): Promise<void> {
  await env.DB.prepare(
    `UPDATE attest_keys SET entitlement_product = ?, entitlement_expires_at = ?,
       original_transaction_id = ?, updated_at = ? WHERE key_id = ?`,
  )
    .bind(
      entitlement?.product ?? null,
      entitlement?.expiresAtMs ?? null,
      entitlement?.originalTransactionId ?? null,
      Date.now(),
      keyId,
    )
    .run();
}

/** Actualiza el entitlement de TODAS las keys de una misma originalTransactionId (webhook App Store). */
export async function updateEntitlementByOriginalTxn(
  env: Env,
  originalTransactionId: string,
  e: { product: string | null; expiresAtMs: number },
): Promise<void> {
  await env.DB.prepare(
    "UPDATE attest_keys SET entitlement_product = ?, entitlement_expires_at = ?, updated_at = ? WHERE original_transaction_id = ?",
  )
    .bind(e.product, e.expiresAtMs, Date.now(), originalTransactionId)
    .run();
}

/** Marca Pro válido si el entitlement no expiró. */
export function isProActive(row: AttestKeyRow, nowMs = Date.now()): boolean {
  return row.entitlement_expires_at != null && row.entitlement_expires_at > nowMs;
}

// ------------------------------------------------------ account_entitlements (C-8, migración 0002)

/** Fila de `account_entitlements`: el MISMO entitlement verificado, indexado por CUENTA de Yala. */
export interface AccountEntitlementRow {
  user_id: string;
  entitlement_product: string | null;
  entitlement_expires_at: number | null; // epoch ms
  original_transaction_id: string;
  bound_via: string; // 'app_account_token' | 'jwt'
  created_at: number;
  updated_at: number;
}

export async function getAccountEntitlement(env: Env, userId: string): Promise<AccountEntitlementRow | null> {
  return env.DB.prepare("SELECT * FROM account_entitlements WHERE user_id = ?")
    .bind(userId)
    .first<AccountEntitlementRow>();
}

/** La fila (de cualquier cuenta) que ya reclamó esa suscripción. Gobierna el 409 y la revocación. */
export async function getAccountEntitlementByOriginalTxn(
  env: Env,
  originalTransactionId: string,
): Promise<AccountEntitlementRow | null> {
  return env.DB.prepare("SELECT * FROM account_entitlements WHERE original_transaction_id = ?")
    .bind(originalTransactionId)
    .first<AccountEntitlementRow>();
}

/** Borrado GDPR: el derecho vive en D1, fuera del RPC de Supabase que borra el resto de la cuenta. */
export async function deleteAccountEntitlement(env: Env, userId: string): Promise<void> {
  await env.DB.prepare("DELETE FROM account_entitlements WHERE user_id = ?").bind(userId).run();
}

/**
 * Vincula (o re-vincula) una suscripción a una cuenta. «Última vinculación gana» (decisión owner
 * 2026-07-27): la suscripción pertenece a UNA cuenta a la vez, así que antes del upsert se borra
 * cualquier fila que tenga esa `original_transaction_id` en OTRA cuenta — la anterior pierde el
 * derecho en el mismo instante en que la nueva lo gana. Sin ese DELETE el UNIQUE haría fallar el
 * re-vínculo (y con `INSERT OR REPLACE` a secas quedarían dos cuentas Pro con una sola suscripción
 * hasta que el índice reventara).
 */
export async function bindAccountEntitlement(
  env: Env,
  userId: string,
  e: { product: string; expiresAtMs: number; originalTransactionId: string; boundVia: string },
): Promise<void> {
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM account_entitlements WHERE original_transaction_id = ? AND user_id != ?")
      .bind(e.originalTransactionId, userId),
    env.DB.prepare(
      `INSERT INTO account_entitlements (user_id, entitlement_product, entitlement_expires_at,
         original_transaction_id, bound_via, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE SET entitlement_product = excluded.entitlement_product,
         entitlement_expires_at = excluded.entitlement_expires_at,
         original_transaction_id = excluded.original_transaction_id,
         bound_via = excluded.bound_via, updated_at = excluded.updated_at`,
    ).bind(userId, e.product, e.expiresAtMs, e.originalTransactionId, e.boundVia, now, now),
  ]);
}

/**
 * Reconciliación del webhook de App Store: aplica expiración/revocación a la cuenta dueña de esa
 * suscripción. NO crea filas — una cuenta sin vínculo previo no gana derecho por una notificación.
 */
export async function updateAccountEntitlementByOriginalTxn(
  env: Env,
  originalTransactionId: string,
  e: { product: string | null; expiresAtMs: number },
): Promise<void> {
  // Guarda de ORDEN. Apple no garantiza el orden de entrega de las notificaciones y reintenta las
  // fallidas durante días: un DID_RENEW que llega DESPUÉS de un REFUND resucitaría un derecho ya
  // revocado. Reglas: la revocación (`expiresAtMs = 0`) siempre gana y es TERMINAL para esa
  // suscripción; una renovación solo puede EMPUJAR la fecha hacia delante, nunca acortarla ni
  // reactivar una fila revocada.
  if (e.expiresAtMs === 0) {
    await env.DB.prepare(
      `UPDATE account_entitlements SET entitlement_product = ?, entitlement_expires_at = 0,
         updated_at = ? WHERE original_transaction_id = ?`,
    )
      .bind(e.product, Date.now(), originalTransactionId)
      .run();
    return;
  }
  await env.DB.prepare(
    `UPDATE account_entitlements SET entitlement_product = ?, entitlement_expires_at = ?,
       updated_at = ? WHERE original_transaction_id = ?
       AND entitlement_expires_at IS NOT NULL AND entitlement_expires_at != 0
       AND entitlement_expires_at < ?`,
  )
    .bind(e.product, e.expiresAtMs, Date.now(), originalTransactionId, e.expiresAtMs)
    .run();
}

/** Pro por CUENTA: el entitlement vinculado sigue vigente. */
export function isAccountProActive(row: AccountEntitlementRow | null, nowMs = Date.now()): boolean {
  return row?.entitlement_expires_at != null && row.entitlement_expires_at > nowMs;
}
