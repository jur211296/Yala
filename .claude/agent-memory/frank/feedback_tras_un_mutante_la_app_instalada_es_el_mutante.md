---
name: tras-un-mutante-la-app-instalada-es-el-mutante
description: Tras correr un XCUITest con un mutante, el Yala Dev que queda instalado en el simulador ES el mutante; capturar sin recompilar enseña el bug. Y type_text de XcodeBuildMCP no escribió: axe type sí.
metadata:
  type: feedback
---

**Después de una tanda de mutantes con XCUITest, recompila (`build_run_sim`) antes de capturar el «después».** El
`com.jurgenschmidt.yala.dev` instalado es el binario de la última corrida: restaurar el fichero no cambia lo
instalado.

**Why:** el 2026-10-13 (pasada UI del lote 1) maté un mutante de `TrialOfferMomentLogic` con
`TrialOfferMomentUITests`, restauré el fichero y lancé con `launch_app_sim` para capturar: abrió el `.dev` del mutante.
Lo vi porque el bundle que contestó no era el que acababa de compilar (`Debug` da `com.jurgenschmidt.yala`,
`Debug-Dev` da `.dev`).

**How to apply:** captura siempre con un `build_run_sim` posterior al último cambio, y mira el `bundleId` de la
respuesta. Para conducir: `axe tap --id` y `axe type` (el `type_text` de XcodeBuildMCP devolvió éxito sin escribir
nada en el campo del nombre). Relacionado: [[el-antes-sale-del-build-del-rojo]].
