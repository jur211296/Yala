---
name: reference-linea-de-tiempo-de-una-activacion
description: Cómo reconstruir con hora dónde se fue el tiempo de una activación de la nube o una vuelta a iCloud de un teléfono concreto (AE por instalación + canarios de paso)
metadata:
  type: reference
---

Para saber qué paso de «Activar la nube» / «Volver a iCloud» se llevó el tiempo en un teléfono real:

1. Instalación: `blob5` del `register cloud migration` (o del `cloudConsentAccepted`) en `yala_metrics` / `yala_metrics_staging`
   alrededor de la hora del QA (token y query en la memoria global `reference_cloudflare_analytics_token`).
2. Todos los eventos de esa instalación en la ventana, ordenados por `timestamp`. La hora es la de LLEGADA al Worker, pero
   con red el spool sale al momento, así que vale como hora del evento.
3. Desde el build del PR #610 (23-oct) la serie trae `cloudMigrationStep` (`<de>><a>`, `x` = segundos del paso anterior)
   y `cloudMigrationImportWaited` (`preWait|runner` × `settled|cut|cap`). Antes de eso solo había un hueco mudo entre el
   claim y el primer `cloudkitExportSucceeded` — el del TF19 fueron 9 min.

**Ojo:** `cloudkitExportSucceeded` mide el tiempo DESDE EL EXPORT ANTERIOR, no la duración del export; `gt_30s` no es un
export lento. Y el PAT de `~/Secrets/yala-supabase-mgmt/pat` contesta 201 en staging (23-oct), aunque el RUNBOOK diga 401;
pero los perfiles del QA ya no estaban (cuentas borradas): no sirvió para fechar la subida.

Relacionado: [[feedback-el-silencio-de-la-telemetria-tambien-mide]].
