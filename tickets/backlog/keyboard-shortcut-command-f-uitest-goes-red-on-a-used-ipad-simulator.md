---
id: keyboard-shortcut-command-f-uitest-goes-red-on-a-used-ipad-simulator
status: backlog
priority: low
area: "testing"
created: 2026-10-07
updated: 2026-10-08
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
