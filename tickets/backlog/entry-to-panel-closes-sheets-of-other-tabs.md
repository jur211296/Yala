---
id: entry-to-panel-closes-sheets-of-other-tabs
status: backlog
priority: medium
area: routing
created: 2026-10-10
updated: 2026-10-10
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
