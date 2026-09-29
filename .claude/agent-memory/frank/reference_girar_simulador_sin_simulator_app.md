---
name: girar-simulador-sin-simulator-app
description: Esta Mac no tiene Simulator.app; girar y ESTRECHAR la ventana del iPad se hace con un XCUITest temporal; ensanchar de vuelta no. Medido 2026-09-26 y 2026-09-29
metadata:
  type: reference
---

**Esta Mac no tiene Simulator.app** (Xcode 27; `open -a Simulator` falla y no está en
`Xcode.app/Contents/Developer/Applications`). Sin él, `simctl` no sabe girar el dispositivo, abrir una
segunda app (Split View), redimensionar ventanas ni abrir una segunda ventana de Yala.

**Girar** (2026-09-26): un XCUITest temporal en `YalaUITests/Flows/` (carpetas sincronizadas: basta con
soltar el fichero) que hace `XCUIDevice.shared.orientation = .landscapeLeft`, lanza con
`launchForUITest(...)` y guarda `XCUIScreen.main.screenshot().pngRepresentation` en una ruta del host.
Los parámetros llegan con el prefijo `TEST_RUNNER_` (`TEST_RUNNER_X=1` → `X` en el runner). Se borra
antes del commit.

**Ventana estrecha en iPad — SÍ se puede, corrige lo que decía esta nota** (2026-09-29, paso 4 del
carril): (1) en el iPad simulado, Ajustes → Multitarea y gestos → **Apps en ventanas** (con
XcodeBuildMCP `snapshot_ui` + `tap`, que sí maneja Ajustes); (2) en el XCUITest,
`app.coordinate(0.995, 0.995).press(forDuration: 0.6, thenDragTo: app.coordinate(0.4, 0.995), …)`
arrastra la esquina y la app pasa a compacta (pestañas abajo). Sale igual en dos corridas (0 px de
diferencia). Al acabar, volver a «Apps en pantalla completa». XcodeBuildMCP `drag` no sirve: pide un
elementRef y el asa no lo tiene.

**Tres trampas del redimensionado, medidas el 2026-09-29 (paso 5):** (1) la ventana **recuerda su tamaño** entre
arranques: si una sesión anterior la estrechó, la app arranca pequeña y centrada y la receta no parte de pantalla
completa ⇒ `xcrun simctl erase <UDID>` del simulador del carril antes (permitido por UDID); (2) `app.frame` es LOCAL a
la ventana (minX 0), así que «arrastrar hasta el borde de la pantalla» calculado con él se sale y trae Ajustes al
frente (captura en blanco); (3) un arrastre mínimo de la esquina a pantalla completa la **desmaximiza** a 706 pt.
Lo que sí funciona: abrir a pantalla completa y arrastrar la esquina `(0.995, 0.995) → (0.4, 0.995)`. Ensanchar de
vuelta desde la ventana centrada NO lo conseguí: va a guion para Jürgen. Instruments: `xctrace --attach <pid>` con
Time Profiler sí graba en el simulador; Animation Hitches y la plantilla SwiftUI no («Hitches is not supported»).

**Antes/después con un solo runner:** un XCUITest no enlaza el código de la app, así que al corregir el
test basta recompilar el «después» y copiar `YalaUITests-Runner.app` sobre los productos del «antes»
(`Debug-Dev-iphonesimulator/`). Ahorra recompilar el árbol viejo.

**Why:** el ticket dejaba la ventana estrecha a Jürgen con Device Hub por esta nota; se midió en la sesión.

**How to apply:** QA de iPad en horizontal o en ventana estrecha. Split View con OTRA app y varias
ventanas de Yala siguen sin medirse. Relacionado: [[capturas-simulador-para-la-web]].
