-- 0001_init — registro de keys App Attest + cache de entitlement Pro.
-- Los nonces de challenge viven en KV (TTL nativo); los contadores de cuota en Durable Objects.
-- D1 guarda solo el estado durable por device.

CREATE TABLE IF NOT EXISTS attest_keys (
  key_id                  TEXT PRIMARY KEY,        -- keyId de DCAppAttestService (base64)
  public_key              BLOB NOT NULL,           -- clave pública (DER) extraída de la attestation
  counter                 INTEGER NOT NULL DEFAULT 0, -- último counter de assertion (anti-replay)
  revoked                 INTEGER NOT NULL DEFAULT 0, -- kill switch por device
  entitlement_product     TEXT,                    -- p.ej. 'yala.pro.yearly' (NULL = Free)
  entitlement_expires_at  INTEGER,                 -- epoch ms; NULL = sin suscripción
  original_transaction_id TEXT,                    -- correlación con el webhook de App Store
  attest_env              TEXT NOT NULL,           -- 'development' | 'production'
  created_at              INTEGER NOT NULL,        -- epoch ms
  updated_at              INTEGER NOT NULL          -- epoch ms
);

CREATE INDEX IF NOT EXISTS idx_attest_keys_txn
  ON attest_keys (original_transaction_id);
