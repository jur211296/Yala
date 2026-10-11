---
id: entry-to-panel-closes-sheets-of-other-tabs
status: done
priority: medium
area: routing
created: 2026-10-10
updated: 2026-10-11
source: XCUITest del encargo 2026-10-10-share-image-reading-does-not-always-start
---

# Entrar desde fuera al Panel cierra la hoja abierta en otra pestaña

## Qué pasa (medido en simulador, iPhone 17 Pro, iOS 27.0)

Con el detalle de un registro abierto en Estadísticas › Registros, compartir una foto a Yala lleva al Panel
(`.navigate(.panel)`) y el detalle se cierra al cambiar de pestaña; después arranca la lectura
(`SharedImageEntryUITests.test_foreignSheetOpen_sharedImage_startsReading`). Lo mismo hace cualquier enlace que navegue
de pestaña (widgets, notificaciones). Viene de antes de este encargo.

## Por qué importa

Con un detalle de solo lectura no se pierde nada. Con un formulario a medias en otra pestaña (Nuevo registro desde
Registros, un editor de Planificación) se perdería lo escrito — inferido, sin medir.

## Qué falta decidir

Si una entrada desde fuera debe esperar a que se cierre una hoja con datos sin guardar (como hace en el Panel) o
llevar al Panel igualmente. Medir primero qué hojas de otras pestañas guardan borrador al cerrarse.

## Resolución (2026-10-11)

**Medido primero, y la premisa del ticket no se sostenía.** Con un «Nuevo registro» a medias en Estadísticas, abrir
`yaladev://panel` desde fuera cambia la pestaña por debajo y **la hoja sigue abierta con lo escrito**; con el detalle de
un registro, igual. Lo que la cerraba era lo que el Panel presentaba después: la lectura de una foto compartida (o la
Bandeja de una notificación). El candado del Panel solo miraba sus propias hojas, presentaba con la de otra pestaña
arriba y esa segunda presentación tumbaba la primera. Con el formulario a medias, lo escrito se perdía (rojo medido).

**Arreglo:** el Panel pregunta a UIKit si su ventana tiene algo presentado (`panelCanDrain(windowPresentationVisible:)`)
y espera; como cerrar una hoja de otra pestaña no avisa a nadie, vuelve a mirar cada 300 ms mientras solo eso lo
retiene. Es la regla que ya valía para las hojas del Panel: lo pedido desde fuera sale al cerrar lo que hay delante.

Red: `ExternalEntryForeignSheetUITests` (foto compartida con el formulario a medias, rojo antes / verde después; enlace
al Panel, verde en los dos), `SharedImageEntryUITests#test_foreignSheetOpen_sharedImage_startsReadingWhenItCloses`
(contrato nuevo) y `RouterConsumerGateLogicTests`.

Fuera, con ticket: `invite-and-app-notices-present-over-other-tab-sheets`.
