---
name: girar-simulador-sin-simulator-app
description: Esta Mac no tiene Simulator.app; para capturas en horizontal o iPad hay que girar con un XCUITest temporal. Medido 2026-09-26
metadata:
  type: reference
---

**Esta Mac no tiene Simulator.app** (Xcode 27; `open -a Simulator` falla y no está en
`Xcode.app/Contents/Developer/Applications`). Sin él, `simctl` no sabe girar el dispositivo, abrir una
segunda app (Split View), redimensionar ventanas (Stage Manager) ni abrir una segunda ventana de Yala.

**Lo que funciona para girar** (2026-09-26, exploración iPad): un XCUITest temporal en
`YalaUITests/Flows/` (el target usa carpetas sincronizadas: basta con soltar el fichero) que hace
`XCUIDevice.shared.orientation = .landscapeLeft`, lanza con `launchForUITest(...)` y guarda
`XCUIScreen.main.screenshot().pngRepresentation` en una ruta del host. Los parámetros llegan con el
prefijo `TEST_RUNNER_` (`TEST_RUNNER_EXPLORA_ORIENT=landscape` → `EXPLORA_ORIENT` en el runner). Se
borra antes del commit.

**Why:** sin esto, cualquier QA en horizontal o de iPad se queda en vertical sin decirlo.

**How to apply:** capturas en horizontal, iPad o QA de orientación. Split View y ventanas múltiples
siguen sin poder medirse aquí: van a iPad real, con guion. Relacionado: [[capturas-simulador-para-la-web]].
