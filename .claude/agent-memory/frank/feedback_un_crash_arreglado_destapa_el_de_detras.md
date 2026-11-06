---
name: un-crash-arreglado-destapa-el-de-detras
description: Tras arreglar un crash del iPhone, repite el gesto en el iPhone antes de cerrar — el cierre de sesión en la nube tenía dos crashes en fila y el primero tapaba al segundo.
metadata:
  type: feedback
---

Un crash arreglado no prueba que el gesto ya no cierre la app: repite el gesto en el aparato y mira `list_crashes`.

**Why:** 2026-11-05, card 7e60. Arreglé el crash de Ajustes (almacén soltado) y el mismo cierre de sesión volvió a
cerrar Yala 8 s después, por otra causa (`BGTaskScheduler` registrado dos veces en el re-arranque). El simulador no
lo ejerce (monta con espejo). La sesión de QA de la tarde tenía el primer `.ips` y nadie podía ver el segundo.

**How to apply:** en bugs de «se cierra la app» del cambio de almacén en caliente o del arranque, el criterio de hecho
es el gesto repetido en el iPhone 14 sin `.ips` nuevo. Relacionado: [[sentry-vacio-no-descarta-un-crash]],
[[el-iphone-de-pruebas-es-el-14-por-cable]].
