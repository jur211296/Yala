---
id: ipad-uitests-fail-on-layout-differences-not-the-tab-bar
status: backlog
priority: low
area: testing
created: 2026-11-06
updated: 2026-11-06
source: gate del lote «XCUITest de selectores y neto del flujo», pasada en iPad
---

# En iPad, varios XCUITest caen por diferencias de pantalla que no son la barra de pestañas

Medido el 2026-11-06 en el iPad Pro 13 (M5), iOS 27.2, en **vertical** (pestañas arriba), al pasar por iPad las suites
que tocó el lote de la barra de pestañas. Estos rojos caen en líneas que el lote no cambió y en pantallas cuyo código de
app no se tocó; se infiere que son anteriores, **sin correrlos contra la base**:

- `BulkEditUITests` (3 casos), línea 49: «Seleccionar» no está en la barra de Registros. En iPad Registros es lista y
  detalle; el botón vive en otra barra o en el menú.
- `RecordsLote8UITests` — `test_detail_deleteAsks…` (l. 63) y `test_detail_duplicate…` (l. 95): el detalle no ofrece
  Eliminar ni Duplicar al pie. En iPad el registro se abre en columna, no en la hoja con pie.
- `SettingsLote15UITests.test_tutorial_closesWithDoItNow_andTheListMarksItDone` (l. 243): el cierre no ofrece «Hacerlo
  ahora».
- `TopPrimaryActionUITests` (3 casos, l. 61, 77 y 103): al bajar, el «+» flotante de Presupuestos / Estadísticas no
  aparece.
- `AccountCardReportsUITests.test_cashFlow_byCard_hidesTheLinePage_andByLineShowsIt` (`bringToMiddle`): «No se pudo
  dejar el selector a media pantalla» (y=471 con el mínimo en 478). **Este sí, medido contra la base**: `origin/2.3`
  sin cambios cae igual en el iPad en vertical.
- `AdaptiveNavigationUITests.test_narrowingTheWindow_keepsEveryPageOpen_andWideningBringsTheSidebarBack` (l. 620): «La
  barra estrecha perdió «Más»».

## Qué haría falta

Lo mismo que la card de la barra: por caso, o la comprobación pasa a una forma que valga en los dos aparatos, o el caso
se declara de iPhone con `XCTSkip` y su motivo. Antes, correr cada uno contra la base para confirmar que es anterior.
