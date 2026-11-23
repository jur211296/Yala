---
id: widget-entry-background-uitests-red-on-2-3
status: done
priority: medium
area: testing, widgets
created: 2026-11-06
updated: 2026-11-22
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

## Cierre (2026-11-22)

Medido el 2026-11-22 (sesión nocturna «pruebas de interfaz rojas de 2.3», Max): **verde en la nocturna de 2.3 del 22-nov** (run 44991989046, sobre b27dcc084, runner del CI iOS 27.0) y **verde en local** sobre origin/2.3 = ea35c1234 (iPhone 17 Pro, iOS 27.2, `Yala Dev`, cola del simulador; 9 casos de los 8 tickets en una corrida, 9/9).

Los dos casos pasan (42 y 41 s en la nocturna, 28 y 27 s en local): la entrada pedida desde el widget sobrevive al segundo plano. No hay regresión de producto. Sin cambios.
