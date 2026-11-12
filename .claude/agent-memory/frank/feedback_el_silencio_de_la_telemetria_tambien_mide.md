---
name: el-silencio-de-la-telemetria-tambien-mide
description: Antes de inferir una espera, consulta Analytics Engine por la instalación y la ventana: un hueco sin eventos o un valor idéntico en toda la flota ya dicen dónde está el tiempo
metadata:
  type: feedback
---

**Una card de «tarda minutos» se abre por la telemetría de producción, filtrada por la ventana exacta, antes de leer
código.** Dos lecturas que no estaban en ninguna card y cambiaron el diagnóstico (2026-10-21, encargo nube y primera foto):

- **El silencio es un dato.** «Activar la nube» del TF19: entre el consentimiento y el corte del servidor, 9 min sin un
  solo evento, ni un export de iCloud (el canario `cloudkitExportSucceeded` sale en cada export y su detalle es el tiempo
  desde el ANTERIOR, no la duración). Eso descartaba la subida colgada y apuntaba a la espera de la quiescencia de iCloud,
  que solo dejaba rastro en el log local. Respuesta: canario donde no lo había.
- **Un valor constante en toda la flota es el bug.** `cloudAdoptOrphanReconciled` = 366 en 5 de 5 entradas: no eran
  huérfanas de nadie, eran los tipos de cambio que el arranque descarga. Ninguna card lo sospechaba.

**Why:** las cards traían inferencias («el attest», «iCloud no se asienta») y cuesta minutos refutarlas con una query.
La regla de [[la-telemetria-de-la-card-puede-ser-de-otro-aparato]] es la mitad; esta es la otra: mira también lo que NO
llegó y lo que llega siempre igual.

**How to apply:** query de `yala_metrics` por la ventana de la card (sin filtrar por evento) y otra por el canario del
camino agrupado por valor en la flota. Receta del token en la memoria de usuario `reference-cloudflare-analytics-token`.
