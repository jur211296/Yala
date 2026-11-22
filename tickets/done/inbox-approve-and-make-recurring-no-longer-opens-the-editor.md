---
id: inbox-approve-and-make-recurring-no-longer-opens-the-editor
status: done
priority: high
area: "inbox, scheduled-payments"
created: 2026-11-18
updated: 2026-11-22
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

## Cierre (2026-11-22, encargo «Bandeja: aprobar y hacer recurrente, y cierre»)

Ya no pasa en `2.3`. Medido sobre `origin/2.3` (4368d5ccb) en el iPhone 17 Pro, iOS 27.2, con el simulador en cola
(`sim-lock.sh`) y sin nadie más: `RecurrenteDesdeRegistroUITests#test_inbox_approveAndMakeRecurring_approvesAndOpensTheEditor`
e `InboxCrudUITests#test_saveReadyButton_savesEveryCompleteDraftAfterConfirming` verdes 1 de 1 y otras 3 vueltas cada una
(`-test-iterations 3 -run-tests-until-failure`), sin tocar sus aserciones. No se tocó el código del cierre de la Bandeja
ni el paso al editor. Causa sin aislar (inferido: lo arregló algo de 2.3 entre la fecha del ticket y hoy; el rojo del
editor coincidía con el que la semilla del día provocaba con «Posible duplicado», quitado en 57d54796a).
