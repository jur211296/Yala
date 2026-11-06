-- 0004_connector_drafts — tu IA registra en Yala (2.3, 2026-11-05).
--
-- Claude, ChatGPT o Grok, conectados a Yala por el conector (`mcp/`), pueden apuntar un movimiento: «apunta 25 soles de
-- almuerzo». El conector no escribe en los datos de la nube de la persona (su sesión de Supabase es de solo lectura):
-- deja el movimiento aquí, en una cola por cuenta, por la llamada interna `ConnectorDrafts.enqueue` (sin ruta pública).
-- La app lo recoge (GET /connector/drafts), crea el borrador en la Bandeja —que la persona confirma— y lo confirma al
-- gateway (POST /connector/drafts/ack), que lo borra. Mismo molde que `mail_drafts` (0003).
--
-- Lo que se guarda: solo lo que el borrador necesita (importe, tipo, divisa, nota, fecha y, si la IA los nombró, la
-- cuenta y la subcategoría ya resueltas contra las de la persona), y solo hasta que la app lo recoge o pasan 30 días.
CREATE TABLE IF NOT EXISTS connector_drafts (
  id          TEXT PRIMARY KEY,                  -- UUID del borrador (la app lo usa para no duplicar)
  user_id     TEXT NOT NULL,                     -- sub de Supabase (UUID lowercase)
  created_at  INTEGER NOT NULL,                  -- epoch ms
  payload     TEXT NOT NULL                      -- JSON validado (ver src/connector/store.ts)
);
CREATE INDEX IF NOT EXISTS idx_connector_drafts_user ON connector_drafts (user_id, created_at);

-- Techo anti-abuso por cuenta y día (UTC). Va aparte de la cola porque la cola se vacía al recogerla.
CREATE TABLE IF NOT EXISTS connector_quota (
  user_id   TEXT PRIMARY KEY,
  day_key   TEXT NOT NULL,                       -- YYYY-MM-DD (UTC)
  day_count INTEGER NOT NULL DEFAULT 0
);
