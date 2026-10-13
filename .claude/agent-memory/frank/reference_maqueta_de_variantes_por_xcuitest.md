---
name: maqueta-de-variantes-por-xcuitest
description: Para enseñar N variantes de UI en el simulador, un argumento -mockv N en la maqueta y un XCUITest que guarda PNG en el Mac; launchForUITest pisa launchArguments
metadata:
  type: reference
---

Receta medida el 2026-10-13 (variantes L1UI, 72 capturas en ~6 min de simulador):

- La maqueta lee `-mockv N` (0 = la app de hoy, el «antes»): un solo build sirve para todas las familias.
- Un XCUITest de la rama de maqueta recorre el flujo y escribe `XCUIScreen.main.screenshot().pngRepresentation`
  a una ruta del Mac. La familia y la carpeta entran por `TEST_RUNNER_MOCKV` / `TEST_RUNNER_MOCKOUT`.
- `build-for-testing` una vez y `test-without-building` por familia, con `sim-lock.sh`.

**Trampas:** `launchForUITest` ASIGNA `launchArguments`, así que lo añadido antes se pierde en silencio (la familia 1
salió idéntica al «antes»): pásalo por `extraArguments:`. `app.keyboards.count` no vio el teclado del sheet: ciérralo
tocando contenido tras subir arriba. El Chrome sin cabeza no baja de 500 px: para ver 390, la página en un iframe.

Relacionado: [[capturar-widgets-por-galeria]], [[auditoria-ui-glass-se-queda-jerarquiza]].
