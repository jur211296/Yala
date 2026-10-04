---
name: el-tap-de-xcodebuildmcp-se-pierde-en-pantallas-vivas
description: En una pantalla que se repinta ~10 veces por segundo (grabando), el `tap` de XcodeBuildMCP dice SUCCEEDED y no llega; `touch` down+up con 0,1 s sí
metadata:
  type: feedback
---

El `tap` de XcodeBuildMCP (y `axe tap`, que además está roto en esta Mac: falta SimulatorKit) **no dispara el botón
mientras la vista se repinta sin parar** — la hoja de voz grabando actualiza tiempo y nivel cada 0,1 s. El resultado
dice `SUCCEEDED` con las coordenadas correctas y el temporizador sigue corriendo. `touch` con `down: true, up: true,
delay: 0.1` sobre el mismo `elementRef` entra a la primera.

**Why:** el 2026-10-04 lo confundí dos veces con un bug de la app (Listo «no respondía» en la hoja vieja y en la nueva)
antes de probar un toque con duración. La hoja estaba bien.

**How to apply:** si un botón «no responde» en el simulador en una pantalla viva, repite con `touch` 0,1 s antes de
abrir hipótesis sobre el código. XCUITest no tiene el problema (su `tap()` ya dura). Ver [[instrumentar-gana-a-razonar]].
