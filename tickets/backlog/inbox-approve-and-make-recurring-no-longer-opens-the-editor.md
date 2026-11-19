---
id: inbox-approve-and-make-recurring-no-longer-opens-the-editor
status: backlog
priority: high
area: "inbox, scheduled-payments"
created: 2026-11-18
updated: 2026-11-18
source: "gate del encargo «Pagos planificados: el logo del comercio» (2026-11-18), rojo que ya vive en 2.3"
---

# Bandeja: «Aprobar y hacer recurrente» ya no abre el editor del pago

## Qué pasa

En la Bandeja, en la hoja de un borrador, tocar «Aprobar y hacer recurrente» cierra la hoja y deja a la persona en el
Panel. El editor del pago recurrente (prellenado con el borrador) no llega a salir.

## Medido

- `YalaUITests/RecurrenteDesdeRegistroUITests#test_inbox_approveAndMakeRecurring_approvesAndOpensTheEditor` cae 3 de 3 en
  la Max el 2026-11-18 («No se abrió el editor de recurrentes», línea 125): dos con el cambio del logo y **una con las dos
  vistas de Pagos devueltas a `origin/2.3`** (55ddcb657). El árbol de accesibilidad al fallar es el del Panel.
- En la nocturna del 2026-11-17 pasó (45 s). Entre las dos entró, entre otros, el asistente de «Nuevo pago planificado»
  por pasos (a77a50913). Que sea esa la causa es inferencia, sin bisecar.

## Hecho cuando

El botón abre el editor prellenado y el XCUITest vuelve a verde.
