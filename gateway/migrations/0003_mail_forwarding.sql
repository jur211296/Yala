-- 0003_mail_forwarding — el correo del banco por reenvío (2.3, 2026-11-04).
--
-- Cada cuenta de Yala en la nube tiene UNA dirección `auto+<code>@yalainbox.com`. El Worker recibe por Email Routing lo
-- que la persona reenvía desde Gmail, Outlook o iCloud Mail, lo lee con IA y deja el movimiento aquí, en una cola por
-- cuenta, hasta que la app lo recoge (GET /mail/drafts) y lo confirma (POST /mail/drafts/ack). La app crea el borrador
-- local, que sincroniza como cualquier otro: el servidor nunca escribe en los datos de la nube de la persona.
--
-- Lo que NO se guarda: el correo. Ni el cuerpo, ni el asunto, ni el remitente. Solo lo que el movimiento necesita
-- (importe, divisa, comercio, fecha, banco y los 4 últimos dígitos si el aviso los trae), y solo hasta que la app lo
-- recoge o pasan 30 días.
CREATE TABLE IF NOT EXISTS mail_addresses (
  user_id          TEXT PRIMARY KEY,             -- sub de Supabase (UUID lowercase)
  code             TEXT NOT NULL UNIQUE,         -- el `<code>` de auto+<code>@ (10 caracteres, sin ambiguos)
  created_at       INTEGER NOT NULL,             -- epoch ms
  trial_used       INTEGER NOT NULL DEFAULT 0,   -- correos leídos con IA sin Pro (cupo de prueba: 5)
  skipped_quota    INTEGER NOT NULL DEFAULT 0,   -- correos que llegaron con el cupo agotado y no se leyeron
  gmail_code       TEXT,                         -- el código con que Gmail confirma la dirección de reenvío
  gmail_code_at    INTEGER,                      -- epoch ms en que llegó
  last_received_at INTEGER,                      -- último correo recibido (para la guía: «ya llegó uno»)
  day_key          TEXT,                         -- YYYY-MM-DD (UTC) del contador diario
  day_count        INTEGER NOT NULL DEFAULT 0    -- correos recibidos ese día (techo anti-abuso)
);

CREATE TABLE IF NOT EXISTS mail_drafts (
  id          TEXT PRIMARY KEY,                  -- UUID del borrador (la app lo usa para no duplicar)
  user_id     TEXT NOT NULL,
  created_at  INTEGER NOT NULL,                  -- epoch ms
  payload     TEXT NOT NULL                      -- JSON con el movimiento leído (ver src/mail/read.ts)
);
CREATE INDEX IF NOT EXISTS idx_mail_drafts_user ON mail_drafts (user_id, created_at);

-- Un mismo aviso reenviado dos veces (Gmail reintenta, o la persona lo reenvía a mano) se lee una sola vez.
CREATE TABLE IF NOT EXISTS mail_seen (
  user_id      TEXT NOT NULL,
  message_hash TEXT NOT NULL,                    -- SHA-256 del Message-ID (o del cuerpo si no trae)
  seen_at      INTEGER NOT NULL,
  PRIMARY KEY (user_id, message_hash)
);
