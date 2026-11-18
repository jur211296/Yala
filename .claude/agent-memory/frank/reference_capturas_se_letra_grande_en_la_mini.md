---
name: capturas-se-letra-grande-en-la-mini
description: En la Mini no hay iPhone SE; crearlo, capturar con letra grande por lanzamiento y borrarlo. Con letra grande los toques de XcodeBuildMCP caen desplazados.
metadata:
  type: reference
---

La Mini solo tiene el iPhone 17 Pro de 27.2 (regla de testing). Para capturas en el SE (encargo de la hoja de foto, 2026-11-17):

- `simctl create "iPhone SE capturas" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation`, apagar el 17 Pro (en la Mini, uno solo), arrancar el SE, `simctl ui <udid> appearance dark`, instalar el `.app` del derived data y lanzar con los args de `-uitest` más `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`. Al terminar: apagar, `simctl delete` y volver a arrancar el 17 Pro.
- **Con letra grande, `tap` por elementRef de XcodeBuildMCP cae desplazado** (el marco llega mientras la pantalla se recoloca): «Foto» de Registros abrió Estadísticas, y la descripción de «Esto leí» tocó la línea de debajo. Lo que funcionó: `simctl io screenshot`, leer la coordenada en la imagen (puntos = píxeles / escala) y `axe tap -x -y`, que sí llega a una hoja aunque axe no la vea en el árbol ([[axe-no-ve-las-hojas]]).
- Un simulador recién creado enseña el tutorial del teclado («Speed up your typing…») la primera vez que sale el teclado: queda en la captura.
- El presupuesto de 30 min de pruebas de interfaz se fue en el gate (10 clases, ~14 min) y cuatro corridas de depuración; estas capturas a mano no son XCUITest y no cuentan.
