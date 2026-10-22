---
name: la-telemetria-de-la-card-puede-ser-de-otro-aparato
description: Un canario que cita una card del QA guiado puede ser de OTRA instalación del mismo QA; filtra por blob5 antes de construir encima.
metadata:
  type: feedback
---

Antes de obedecer el «MEDIDO» de telemetría de una card del QA guiado, consulta `yala_metrics` filtrando por instalación
(`substring(blob5,1,8)`) y ata cada canario al aparato que hacía el paso.

**Why:** 2026-10-19, card axgf: el `cloudSyncAttestRequired prefs-pull` que «probaba» el 401 de attest en el iPhone que migraba
era del iPad (otra instalación, otro paso). El iPhone no había emitido ningún 401: el push nunca salió y la causa real era otra
(una espera sin techo). Arreglar solo lo que pedía la card habría dejado el síntoma.

**How to apply:** query con `timestamp`, `blob2`, `blob3` y la instalación, en la ventana del paso; identifica la instalación por un
canario propio del paso (p. ej. `cloudConsentAccepted migration`). La AUSENCIA de un canario en el spool (kill-tolerante) también es
una medición. Ver [[instrumentar-gana-a-razonar]].
