---
id: keyboard-shortcut-command-f-uitest-goes-red-on-a-used-ipad-simulator
status: done
priority: low
area: "testing"
created: 2026-10-07
updated: 2026-11-05
source: hallazgo del encargo 2026-10-07-ipad-drop-unreadable-file-fails-silently
---

# `test_commandF_opensSearch` pasa en un iPad recién creado y cae después

## Qué pasa

En el mismo simulador (iPad Pro 13 M5, iOS 27.0, creado para la sesión), `KeyboardShortcutsUITests` pasó 5 de 5 en la
primera corrida. Una hora y unas veinte corridas después, `test_commandF_opensSearch` cae 3 de 3 con «⌘F no abrió
Buscar»; el vídeo del resultado enseña el Panel sin cambios tras ⌘F. Los otros cuatro casos siguen pasando.

## Medido

- Con `origin/2.1` (`beed3a228`), sin los cambios del encargo, en ese mismo simulador: 3 de 3 rojos. No es de ese
  encargo.
- No se averiguó qué estado del simulador lo cambia. El test pulsa ⌘F en cuanto hay una barra de navegación, sin
  esperar a `uitest_ready`; es la primera hipótesis a medir, no una causa comprobada.

## Medido en 2.1 (triage 2026-10-08)

- El test no ha cambiado desde `f96aae000`: espera `navigationBars.firstMatch` y pulsa ⌘F sin esperar a `uitest_ready`. La hipótesis del ticket sigue sin medir.

Triage 2026-10-08: abierto · low → low · `test_commandF_opensSearch` (YalaUITests/Flows/KeyboardShortcutsUITests.swift) sigue pulsando ⌘F en cuanto hay barra de navegación, sin esperar a `uitest_ready`; solo corre en iPad, fuera del gate.

## Resuelto (lote de XCUITest en iPad, 2026-11-05)

- Medido con una traza en `RootCommandPerformer.perform` (iPad Pro 13, iOS 27.2): si ⌘F es la primera tecla tras abrir
  la app, no llega a la app; la segunda sí abre Buscar. ⌘G en su lugar y quitar el `.disabled` del menú no cambian
  nada; ⌘4 y ⌘N como primera tecla sí llegan; con Escape antes, ⌘F llega. La hipótesis de `uitest_ready` era falsa:
  `launch()` ya lo esperaba.
- Arreglo del test: pulsa Escape antes de ⌘F, con el porqué en el código. Decisión del bot dueño (opción A).
- En verde en dos pasadas seguidas de la suite en el iPad Pro 13.
- Card de producto aparte para Jürgen: «El primer ⌘F tras abrir Yala se pierde en iPad», probarlo en un iPad real.
