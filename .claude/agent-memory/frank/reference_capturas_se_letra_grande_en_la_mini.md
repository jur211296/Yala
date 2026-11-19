---
name: capturas-se-letra-grande-en-la-mini
description: En la Mini (y la Max) no hay iPhone SE; crearlo, capturar con letra grande por lanzamiento y borrarlo. Con letra grande los toques de XcodeBuildMCP caen desplazados.
metadata:
  type: reference
---

La Mini solo tiene el iPhone 17 Pro de 27.2 (regla de testing). Para capturas en el SE (encargo de la hoja de foto, 2026-11-17):

- `simctl create "iPhone SE capturas" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation`, apagar el 17 Pro (en la Mini, uno solo), arrancar el SE, `simctl ui <udid> appearance dark`, instalar el `.app` del derived data y lanzar con los args de `-uitest` más `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`. Al terminar: apagar, `simctl delete` y volver a arrancar el 17 Pro.
- **Con letra grande, `tap` por elementRef de XcodeBuildMCP cae desplazado** (el marco llega mientras la pantalla se recoloca): «Foto» de Registros abrió Estadísticas, y la descripción de «Esto leí» tocó la línea de debajo. Lo que funcionó: `simctl io screenshot`, leer la coordenada en la imagen (puntos = píxeles / escala) y `axe tap -x -y`, que sí llega a una hoja aunque axe no la vea en el árbol ([[axe-no-ve-las-hojas]]).
- Un simulador recién creado enseña el tutorial del teclado («Speed up your typing…») la primera vez que sale el teclado: queda en la captura.
- El presupuesto de 30 min de pruebas de interfaz se fue en el gate (10 clases, ~14 min) y cuatro corridas de depuración; estas capturas a mano no son XCUITest y no cuentan.
- **Pagos planificados en el SE con AX5 (Max, 2026-11-18):** `-uitest-deeplink scheduledPayments` aterriza en el Panel, no en Pagos (en el 17 Pro sí aterriza), y en los ~30 s tras el arranque ni `axe swipe` ni `axe tap --label` hacen nada. Lo que llegó: esperar 30 s, `axe tap -x 196 -y 612` (pestaña Planificación), arrastrar la fila de chips a la izquierda en y=194 (el chip de Pagos queda fuera de la pantalla) y `axe tap --id planning_chip_scheduledPayments`; después, arrastres verticales con x=40 para no caer en el selector de mes. `simctl launch` sobre la app ya abierta NO reaplica los argumentos (`-userTheme 1` incluido): `terminate` antes.
- **Tema claro de verdad:** la apariencia del simulador no cambia el tema de Yala; claro pide `-userTheme 1` ([[tema-claro-de-yala-en-el-simulador]]).
