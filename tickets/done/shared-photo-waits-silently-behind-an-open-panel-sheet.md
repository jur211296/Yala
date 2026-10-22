---
id: shared-photo-waits-silently-behind-an-open-panel-sheet
status: done
priority: medium
area: image
created: 2026-10-10
updated: 2026-10-12
source: decisión pendiente del encargo 2026-10-10-share-image-reading-does-not-always-start
---

# Una foto compartida espera en silencio detrás de una hoja abierta del Panel

## Qué pasa (medido en simulador)

Si al compartir la foto Yala tiene abierta una hoja del Panel —la Bandeja, la hoja de lectura de una foto anterior, un
formulario—, la lectura espera a que esa hoja se cierre y arranca sola al cerrarla
(`SharedImageEntryUITests.test_inboxOpen_…`, `test_background_twice_…`). Es lo que pedía el encargo. Pero mientras la
hoja siga abierta, Yala no dice nada: quien compartió ve la Bandeja como la dejó y puede pensar que la lectura no
arrancó, y cerrar la app del todo. Es una explicación posible del reporte del 10-oct («a veces no arranca hasta
reiniciar»), no medida en su iPhone.

## Opciones para Jürgen

- **A — Dejarlo así** (esperar en silencio y arrancar al cerrar).
- **B — Que la foto compartida cierre las hojas sin datos por guardar** (Bandeja sin edición abierta, hoja de lectura
  en «elige una foto», información de un widget) y arranque; las que tienen datos sin guardar siguen esperando.
- **C — Esperar, pero decirlo**: un aviso breve («Tu foto se leerá al cerrar esto»).

Recomendación: B. Es lo que la persona espera al compartir, y lo que ya pasa con las hojas de otras pestañas.

## Resolución (2026-10-12)

**Decisión de Jürgen: opción B.** Una foto compartida que llega con una hoja del Panel sin nada por guardar la cierra y
empieza la lectura. Se cierran, y solo si están solas en la ventana (nada encima):

- la Bandeja;
- el registro por imagen en «elige una foto», fuera de la práctica guiada (cerrarla ahí la daría por saltada);
- el «?» de un widget del Panel sin un tamaño cambiado por guardar.

Todo lo demás sigue esperando a que la persona lo cierre: un «Nuevo registro» a medias, Ajustes, el chat, una hoja de
otra pestaña, la revisión de una lectura anterior, y cualquiera de las tres con algo encima (un borrador en edición, el
selector de fotos, un aviso). Ante la duda, espera. Solo la foto compartida (y el recibo soltado en el iPad, que entra
por el mismo camino); voz, imagen y nuevo registro desde un widget no cierran nada.

Cómo: `SharedPhotoPanelSheetLogic.sheetToClose` decide con lo que ve el Panel al retener la foto
(`PanelShell.closeDataFreeSheetForSharedPhoto`). La profundidad de la pila la mide UIKit
(`ModalPresentationProbe.presentationDepth`); «elige una foto» lo publica `ImageSelectionView`
(`SceneNavigation.isImageEntryChoosing`) y el «?» sin cambios, `WidgetInfoSheet`, que se cierra al pedírselo
(`panelWidgetInfoCloseRequest`).

Red: `SharedImageEntryUITests` (Bandeja, «?» y «elige una foto»: rojo antes / verde después; «Nuevo registro» a medias
en el Panel: espera en los dos) y `YalaTests/SharedPhotoPanelSheetLogicTests`.
