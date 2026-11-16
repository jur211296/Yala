-- 0004_connector_quota — tu IA registra en Yala (2.3, 2026-11-05; transporte a la cola común el 2026-11-16).
--
-- Claude, ChatGPT o Grok, conectados a Yala por el conector (`mcp/`), pueden apuntar un movimiento: «apunta 25 soles de
-- almuerzo». El conector no escribe en los datos de la nube de la persona (su sesión de Supabase es de solo lectura):
-- deja el movimiento en la cola COMÚN de borradores (`mail_drafts`, 0003, con `source: "ai"`; decisión D9 del plan de
-- Yala web) por la llamada interna `ConnectorDrafts.enqueue` (sin ruta pública). La app lo recoge con lo del correo y lo
-- de la web (GET /mail/drafts), crea el borrador en la Bandeja y lo confirma (ack).
--
-- Aquí solo vive el techo anti-abuso por cuenta y día (UTC). Va aparte de la cola porque la cola se vacía al recogerla.
-- Sustituye a `0004_connector_drafts`, que traía una cola propia y nunca se desplegó.
CREATE TABLE IF NOT EXISTS connector_quota (
  user_id   TEXT PRIMARY KEY,
  day_key   TEXT NOT NULL,                       -- YYYY-MM-DD (UTC)
  day_count INTEGER NOT NULL DEFAULT 0
);
