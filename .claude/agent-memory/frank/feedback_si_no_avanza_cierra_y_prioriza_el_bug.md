---
name: si-no-avanza-cierra-y-prioriza-el-bug
description: Cuando una prueba en su iPhone choca con un bug grave ajeno al encargo, Jürgen prefiere cerrar dejando lo pendiente abierto y que la card del bug se trabaje primero
metadata:
  type: feedback
---

Si la prueba de un encargo queda parada por un bug grave que no es del encargo, no insistas en rodearlo: cierra con el PR
abierto (sin cola de merge), deja lo pendiente como device-QA en su ticket y sube la card del bug como prioritaria.

**Why:** 2026-11-13, minitutorial del correo: el iPhone 14 no entraba en su cuenta de staging («Conectando… 60 %» 15 min).
Tras dos intentos de rodeo (reinstalar, borrar el iCloud de Yala Dev) dijo «Si no podemos avanzar, cierra aquí dejando
abierto y que se trabajen las cards de los bugs de manera prioritaria». Antes había dicho «es grave este bug».

**How to apply:** mide la causa antes del primer rodeo (la telemetría `yala_metrics_staging` de la instalación lo dijo
en un minuto: `cloudAdoptLineageBlocked`); si la causa no es del entorno, ofrece cerrar así en vez de otro rodeo.
Relacionado: [[feedback-el-tablero-antes-que-el-bug]].
