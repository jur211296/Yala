---
name: no-editar-con-xcodebuild-test-compilando
description: Un `xcodebuild test` del gate de UI compila primero los tres targets; editar mientras tanto deja una build a medias y cero casos ejecutados
metadata:
  type: feedback
---

El 20-nov-2026 lancé el XCUITest del gate con `xcodebuild test` y, mientras compilaba, edité un fichero de la app y su
test (arreglo del revisor). La build tomó el test nuevo sin la función nueva: `error: has no member`, cero casos, y
media hora de turno de simulador perdida. Después, la corrida siguiente cayó por «Timed out waiting for AX loaded
notification» (tras `YalaTests` entero): reiniciar el simulador lo curó, como ya decía [[runner-ax-timeout-tras-suite-larga]].

**Why:** el gate de UI es lo más caro de la sesión; perderlo por una edición cuesta 30 min.
**How to apply:** para el gate de UI, `build-for-testing` primero y luego `test-without-building`; así se puede editar
mientras corren los casos. Y tras `YalaTests` entero, reinicia el simulador antes del XCUITest.
