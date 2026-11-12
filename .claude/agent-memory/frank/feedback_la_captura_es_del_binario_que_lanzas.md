---
name: feedback-la-captura-es-del-binario-que-lanzas
description: Al capturar a mano tras compilar, comprueba qué bundle lanzas; `-configuration Debug` deja un Yala.app de producción (com.jurgenschmidt.yala) junto al de Yala Dev (.dev) y yo capturaba el viejo.
metadata:
  type: feedback
---

Antes de dar por buena una captura del «después», mira que el bundle lanzado sea el que acabas de compilar.
El 2026-10-20 (lote decidido 07) compilé el «antes» con `-scheme "Yala Dev" -configuration Debug`, que deja
`Debug-iphonesimulator/Yala.app` con bundle **com.jurgenschmidt.yala**; los `build-for-testing` posteriores
dejan el bueno en `Debug-Dev-iphonesimulator/` con **com.jurgenschmidt.yala.dev**. Mi lanzador seguía
abriendo el primero: la hoja de Temas salía vacía en la captura mientras el XCUITest (que lanza .dev) pasaba.
Perdí media hora persiguiendo un bug que ya estaba arreglado.

**Why:** dos apps instaladas con el mismo nombre en el simulador; `simctl launch` no avisa de cuál es cuál.

**How to apply:** en capturas manuales, lanza `com.jurgenschmidt.yala.dev` e instala desde
`Debug-Dev-iphonesimulator/`. Si una captura contradice un test verde, compara bundle y fecha del `.app`
antes que el código. Relacionado: [[el-antes-sale-del-build-del-rojo]].
