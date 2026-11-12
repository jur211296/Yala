---
id: panel-preview-sample-trend-helper-has-no-callers
status: backlog
priority: very-low
area: "panel, código muerto"
created: 2026-11-04
updated: 2026-11-04
source: "sesión «Widgets: estados con pocos datos + restos» (2026-11-04), al retirar la hoja huérfana de la Comparativa"
---

# Un ayudante de vista previa del Panel no lo usa nadie

## El problema

No se ve nada: es código que no corre. `PanelViewModel.previewWithSampleTrend()` y la muestra que carga
(`PanelPeriodComparisonData.previewSample`), en `Yala/App/Views/Panel/InfoSheets/PreviewSampleData.swift`, no tienen
ningún llamador (medido con grep el 2026-11-04 en `Yala/`, `YalaTests/` y `YalaUITests/`). Según `git log -S`, nació
con los pilotos de la hoja de ayuda de los widgets del Panel y su uso se fue en la v2 de esa hoja.

No se tocó al retirar la hoja de la Comparativa porque no es de esa hoja: es otra limpieza.

## Qué hacer

Borrar los dos (función y muestra) tras comprobar otra vez con grep que siguen sin llamadores, y compilar.
