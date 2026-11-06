-- 0001_daily — el resumen diario del panel (telemetría propia, decisión 3: historia de más de 90 días).
--
-- Analytics Engine guarda el dato fino 90 días. Esto guarda, para siempre, los AGREGADOS de cada día: ni un `install`,
-- ni una cuenta, ni un importe. Lo escribe el cron del Worker (src/cron.ts) y lo lee la página (src/render.ts).
--
--   day     AAAA-MM-DD (UTC). En las métricas de ventana (`active7`, `canary30`…), el día en que TERMINA la ventana.
--           En las de cohorte (`cohort_*`), el día del alta.
--   metric  qué se cuenta (lista en src/summarize.ts)
--   dim     el corte: función, versión, nombre del canario, tipo de aviso… ('' si no hay corte)
--   value   el número
--   devices aparatos distintos detrás de `value`, cuando se sabe (el panel no pinta cortes de menos de 3)
CREATE TABLE IF NOT EXISTS daily (
  day     TEXT NOT NULL,
  metric  TEXT NOT NULL,
  dim     TEXT NOT NULL DEFAULT '',
  value   REAL NOT NULL,
  devices INTEGER,
  PRIMARY KEY (day, metric, dim)
);
CREATE INDEX IF NOT EXISTS idx_daily_metric_day ON daily (metric, day);

-- Una fila por corrida del cron: cuándo, hasta qué día y si salió bien. La página la enseña al pie («al día hasta…»)
-- para que un cron parado no se lea como «no pasó nada».
CREATE TABLE IF NOT EXISTS runs (
  ran_at       INTEGER PRIMARY KEY,  -- epoch ms
  through_day  TEXT NOT NULL,        -- último día resumido
  days         INTEGER NOT NULL,     -- cuántos días recalculó
  ok           INTEGER NOT NULL,     -- 1 bien · 0 falló
  note         TEXT                  -- motivo del fallo, o qué faltó (p.ej. «sin conteos de la base»)
);
