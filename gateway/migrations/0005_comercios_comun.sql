-- 0005_comercios_comun — «Comercios en común» (2.3, 2026-11-22; decisión de Jürgen: las opciones recomendadas).
--
-- Una lista anónima «comercio → tipo de comercio» (`supermarket`, `pharmacy`…, la lista cerrada de la foto) que se arma
-- cuando varios teléfonos distintos coinciden. El teléfono la baja entera y busca en local: nunca pregunta por un
-- comercio. El aporte llega en lote semanal, sin importe, fecha, cuenta ni categoría del usuario.
--
-- Lo que hay aquí y lo que no:
-- - `cc_votes`: un voto por (comercio, teléfono). El teléfono va como HUELLA (HMAC del keyId de App Attest con una llave
--   del servidor): cuenta un teléfono una vez y no lleva a la persona. Se guarda la SEMANA (ISO), nunca el día ni la
--   hora. Se borra al entrar el comercio en la lista y, si no, a las 13 semanas (~90 días).
-- - `cc_device_week`: cuántos aportes hizo cada huella en la semana (tope 30). Se borra con la misma regla.
-- - `cc_published`: la lista común. Sin huellas ni conteos.
-- La lista ya armada (cuerpo, versión y día del cálculo) se guarda en KV (`cc:list`): se recalcula al primer GET del
-- día UTC, sin cron.
-- Ninguna tabla guarda IP, cuenta, email ni importes.
CREATE TABLE IF NOT EXISTS cc_votes (
  merchant    TEXT NOT NULL,
  device_hash TEXT NOT NULL,
  kind        TEXT NOT NULL,
  week        TEXT NOT NULL,                 -- semana ISO, «2026-W47»
  PRIMARY KEY (merchant, device_hash)
);
CREATE INDEX IF NOT EXISTS idx_cc_votes_week ON cc_votes (week);

CREATE TABLE IF NOT EXISTS cc_device_week (
  device_hash TEXT NOT NULL,
  week        TEXT NOT NULL,
  count       INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (device_hash, week)
);

CREATE TABLE IF NOT EXISTS cc_published (
  merchant TEXT PRIMARY KEY,
  kind     TEXT NOT NULL
);
