---
id: ipad-reports-and-search-get-a-readable-width
status: backlog
priority: low
area: "ipad, reports, search, adaptativo"
updated: 2026-10-08
created: 2026-09-29
source: "fase 1 del carril adaptativo (ipad-sidebar-and-list-detail-for-records-and-planning), 2026-09-29"
---

# En iPad, Reportes y Buscar siguen estirando sus filas a todo el ancho

## Qué pasa

La fase 1 dio ancho legible (`DS.Adaptive.readableWidth`, 700 pt) a las dos columnas de detalle nuevas, y las listas
de Registros y Planificación quedaron en su columna. Las demás pantallas siguen como antes: **Reportes** y **Buscar** no topan su
ancho (`grep maxWidth` en `FinancialReportView.swift` y `GlobalSearchView.swift` no da nada), así que en un iPad a
pantalla completa sus filas se estiran a todo el ancho. Inferido del código; las capturas del «antes» son lo primero.
Panel y Estadísticas tienen su fase (2b, [[ipad-and-duo-panel-and-statistics-use-the-width]]) y Grupos y Ajustes la
suya ([[ipad-list-detail-for-groups-and-settings-and-chat-inspector]]); estas dos no tenían ninguna.

## Qué hacer

- Tope `DS.Adaptive.readableWidth` al contenido, centrado (`.frame(maxWidth:)` + `.frame(maxWidth: .infinity)`), como
  `BudgetDetailView`. En iPhone no cambia nada: el tope es más ancho que cualquier iPhone.

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPad-Pro-13`, vertical y horizontal.
- `YalaLane-Adapt-iPhone-SE` y `-ProMax`: idénticas píxel a píxel.

## Relacionados

- [[ipad-sidebar-and-list-detail-for-records-and-planning]].

## Medido en 2.1 (triage 2026-10-08)

- `grep maxWidth|readableWidth` sigue dando 0 en `Yala/App/Views/Reports/FinancialReportView.swift` y en `Yala/App/Views/Search/GlobalSearchView.swift`. Su último cambio es el de varias ventanas (`133437905`, 2026-10-02), que no toca el ancho.
- `DS.Adaptive.readableWidth` se aplica hoy en `BudgetDetailView`, `TransactionDetailSheet`, `AccountDetailSheet`, `ChatSheetView`, `StepGuide`, `FollowerWindowRoot` y, vía `readableListMargin`, en las listas de ajustes.

Triage 2026-10-08: abierto · low → low · `FinancialReportView.swift` y `GlobalSearchView.swift` siguen sin ningún `maxWidth` ni `readableWidth`; el tope solo lo usan detalles, ajustes, chat y `StepGuide`.
