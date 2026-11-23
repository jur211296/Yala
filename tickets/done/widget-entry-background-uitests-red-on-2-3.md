---
id: widget-entry-background-uitests-red-on-2-3
status: backlog
priority: medium
area: testing, widgets
created: 2026-11-06
updated: 2026-11-06
source: gate del lote «XCUITest de selectores y neto del flujo», medido contra la base
---

# Los dos casos de `WidgetEntryBackgroundUITests` están en rojo en 2.3

Medido el 2026-11-06 en el iPhone 17 Pro, iOS 27.2, aislado y con el centinela limpio, **con la base `origin/2.3`
@ `21f563125` sin cambios** (y lo mismo con el lote encima):

- `test_newTransactionWaitingForThePanel_survivesTheBackground` (l. 101): no encuentra el campo del monto del Nuevo
  registro que el widget pidió mientras había otro formulario abierto y la app pasó a segundo plano.
- `test_voiceEntryWaitingForThePanel_survivesTheBackground` (l. 88): al cerrar el formulario, la voz pedida desde el
  widget antes de salir no se abre (`voice_done`).

Es el escenario de [[widget-and-siri-entries-lost-on-background]] (cerrado): una entrada de fuera pedida con un
formulario abierto, la app a segundo plano y de vuelta. Puede ser una regresión de producto (la entrada se pierde) o
del test; no se ha mirado el vídeo. `ExternalEntryForeignSheetUITests` y `WidgetEntryToPanelUITests`, sin el paso por
segundo plano, pasan.

## Qué haría falta

Ver el vídeo del `.xcresult` del rojo, decidir si es de app o de test y bisecar contra la última nocturna verde.
