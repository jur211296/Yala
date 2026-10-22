---
name: la-marca-de-la-salida-no-la-ve-quien-no-salio
description: Una marca durable que escribe la SALIDA de una pantalla no existe tras un kill; el consumidor tiene que leer también el testigo anterior que la salida habría traducido.
metadata:
  type: feedback
---

Si una marca («a medias») la escribe el gesto de salir (`disarm()` al pulsar «Dejarlo por ahora»), **tras un kill o
una hoja desmontada esa marca no existe**: solo queda el testigo anterior que la salida iba a traducir (el arm + la
marca de la zona). Un consumidor que decide solo por la marca nueva cae en el camino viejo justo en el caso más probable.

**Why:** 2026-09-27, PR #278. `.finishOnReentry` terminaba el borrado a medias al volver a entrar, pero solo miraba
`leftHalfway`. Dos lentes de la review, por separado, cazaron el kill tras la zona: arm + `zoneDone` sin marca ⇒
`.proceed` ⇒ onboarding encima de las filas importadas. Mi `disarm()` escribía la marca una línea ANTES de `onProceed()`.
Otra lente cazó en el mismo diff que una salida distinta («Restaurar») dejaba viva la marca que yo acababa de crear.

**How to apply:** al introducir una marca que escribe una salida, enumera (1) los consumidores y pregúntate qué leen
tras un kill sin salida, y (2) TODAS las salidas de la pantalla y de la pantalla de después (chooser), y decide en cada
una qué pasa con la marca. Relacionado: [[el-testigo-vive-menos-que-lo-que-describe]], [[una-key-nueva-esta-ausente-en-todo-el-parque]].
