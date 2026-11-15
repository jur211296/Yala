---
id: vs-hardcoded-in-statistics-and-panel-comparisons
status: backlog
priority: low
area: "l10n, estadísticas, panel"
created: 2026-11-12
updated: 2026-11-12
source: "lote 08 de las necesarias 2.3 (Flujo de caja), al buscar todas las instancias del «vs» escrito a mano"
---

# «vs» sigue escrito a mano en las comparaciones de Estadísticas y del Panel

El lote 08 quitó el «vs» del detalle de una línea del flujo de caja. Fuera de su alcance quedan otras instancias del
mismo patrón, que salen «vs» en los 16 idiomas (medido en `origin/2.3` el 2026-11-12):

- `Yala/App/Logic/Helpers/PreviousPeriodHelper.swift:192-235`: siete `return "vs \(…)"` del rótulo del período anterior.
  `CategoriesTabView.swift:1361` y `TrendsTabView.swift:1131` le quitan el prefijo con `hasPrefix("vs ")`, así que el
  arreglo tiene que mover también esos dos lectores.
- `Yala/App/Views/Panel/TopSubcategoriesWidget.swift:149`: `Text("vs \(…)")` bajo cada subcategoría.

Arreglo esperado: una frase o un rótulo traducido por caso, como `cashFlowPlan.cellDetailSpentVsPlan`, y un
source-scan que prohíba `"vs \(` en `Yala/App`.
