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
