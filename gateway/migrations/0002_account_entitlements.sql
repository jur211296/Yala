-- 0002_account_entitlements — el derecho Pro deja de vivir SOLO en el device (C-8, 2026-07-27).
--
-- Hasta aquí el entitlement se guardaba en `attest_keys` (PK = keyId de App Attest), es decir por
-- DISPOSITIVO, y `isProUser` del cliente salía de `Transaction.currentEntitlements`, es decir del
-- APPLE ID. Quien migra a la nube para dejar de depender de Apple y entra con su cuenta de Yala en
-- un device con otro Apple ID veía sus datos y perdía Pro sobre ellos.
--
-- Esta tabla indexa el MISMO entitlement verificado por CUENTA de Yala (`user_id` = sub de Supabase).
--
-- `original_transaction_id` es UNIQUE a propósito (decisión owner 2026-07-27: «última vinculación
-- gana»). Una suscripción pertenece a UNA cuenta a la vez: al vincularla a una cuenta nueva, el
-- upsert por esa columna reasigna la fila y la cuenta anterior deja de tener derecho. Sin el UNIQUE,
-- pasear la suscripción por N cuentas daría Pro simultáneo a todas.
CREATE TABLE IF NOT EXISTS account_entitlements (
  user_id                 TEXT PRIMARY KEY,        -- sub de Supabase (UUID lowercase)
  entitlement_product     TEXT,                    -- p.ej. 'com.yala.pro.yearly' (NULL = Free)
  entitlement_expires_at  INTEGER,                 -- epoch ms; NULL = sin suscripción
  original_transaction_id TEXT NOT NULL,           -- la suscripción de Apple que otorga el derecho
  bound_via               TEXT NOT NULL,           -- 'app_account_token' | 'jwt' (procedencia del vínculo)
  created_at              INTEGER NOT NULL,        -- epoch ms
  updated_at              INTEGER NOT NULL         -- epoch ms
);

-- Single-owner por suscripción + índice del webhook (que reconcilia por originalTransactionId).
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_entitlements_txn
  ON account_entitlements (original_transaction_id);
