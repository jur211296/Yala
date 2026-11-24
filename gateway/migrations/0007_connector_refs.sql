-- 0007_connector_refs — la referencia de lo que apunta tu IA (2026-11-24, lote 5 de «Bandeja sin duplicados»).
--
-- `apuntar_movimiento` acepta una `referencia` opcional (el id del correo del banco, por ejemplo): la misma referencia
-- en la misma cuenta no crea un segundo borrador. Aquí se guarda solo su SHA-256, nunca el texto, y qué borrador creó.
-- La fila sobrevive a que la app recoja el borrador (la cola se vacía con el ack): por eso va aparte de `mail_drafts`.
-- Caduca a los 90 días (la borra el propio conector al apuntar) y se borra con la cuenta (`deleteConnectorData`).
CREATE TABLE IF NOT EXISTS connector_refs (
  user_id    TEXT NOT NULL,                      -- sub de Supabase, tal cual
  ref_hash   TEXT NOT NULL,                      -- SHA-256 en hex de la referencia normalizada
  draft_id   TEXT NOT NULL,                      -- el id que recibió en la cola común (`mail_drafts.id`)
  created_at INTEGER NOT NULL,                   -- epoch ms
  PRIMARY KEY (user_id, ref_hash)
);
