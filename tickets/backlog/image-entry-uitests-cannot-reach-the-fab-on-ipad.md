---
id: image-entry-uitests-cannot-reach-the-fab-on-ipad
status: backlog
priority: low
area: "testing"
created: 2026-10-07
source: hallazgo del encargo 2026-10-07-ipad-drop-unreadable-file-fails-silently
---

# Los XCUITest del registro por imagen no llegan al FAB en el iPad

## Qué pasa

`YalaUITests/ImageEntryReviewUITests` cae entero (5 de 5) en un iPad Pro 13 (iOS 27.0) con «No apareció el FAB del
Panel (fab_new_transaction)». `revealPanelFAB()` baja el Panel hasta que el FAB flotante entra, pero en el iPad el
Panel con el seed `minimal` cabe sin scroll y el flotante no entra nunca.

## Medido

- 2026-10-07, iPad Pro 13 (M5), iOS 27.0: 5 de 5 rojos con el árbol del encargo, y el mismo rojo en
  `test_readsWithoutCountdown_andSavesInTheSameSheet` con `origin/2.1` (`beed3a228`) sin cambios. No es de ese encargo.
- En iPhone el gate y el CI corren estas suites, así que no se ve.

## Salida posible

Que el helper use la fila de acciones del Panel (`panel_action_image`) cuando el flotante no puede entrar, o que estas
suites se declaren de iPhone. `ReceiptDropUITests` ya entra por `panel_action_image` por esto mismo.
