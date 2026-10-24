---
id: category-breakdowns-leave-out-uncategorized-movements
status: backlog
priority: low
area: "estadisticas, panel, widgets"
created: 2026-10-23
updated: 2026-10-23
source: "encargo 2026-10-23-cifras-distintas-mismo-dinero-2-2 (card vl1q)"
---

# Las tartas y rankings por categoría no enseñan los movimientos sin categoría

Desde el 2026-10-23 un movimiento sin categoría cuenta como ingreso o gasto por su signo en todos los totales
(decisión de Jürgen del 2026-09-06). Los desgloses POR CATEGORÍA no tienen dónde ponerlo y lo dejan fuera: la tarta y
el ranking de categorías y subcategorías de Estadísticas (`TopSpendingCategoriesCalculator`,
`TopSubcategoriesCalculator`), el Sankey (`SankeyFlowCalculator`), la distribución por necesidad
(`InsightsCalculator`, `NeedTrendHelper`) y las categorías de los widgets de inicio (`WidgetDataCache.buildTopCategories`).

Qué ve el usuario: con 200 en Comida y un gasto sin categoría de 40, el gasto del mes dice 240 y la tarta de categorías suma 200. Es
raro (el flujo normal siempre pone categoría; llegan por import o por grupos), pero la pantalla se contradice.

## Qué hay que decidir (Jürgen)

- **A · Un trozo «Sin categoría»** en la tarta, el ranking, el Sankey y el widget, con el gris neutro. La tarta suma
  el total. *Recomendada*: es lo que ya hace el Informe por categoría (fila «Sin categoría», `L10n.Report.uncategorized`),
  sin copy nuevo.
- **B · Dejarlo fuera y decirlo**: una línea bajo la tarta («No incluye 40 sin categoría»). Copy nuevo en 16 idiomas.
- **C · Dejarlo como está**: el desglose es de categorías y lo sin categoría no es una.

## Hecho cuando

Decidida la opción, y la suma de cada desglose por categoría coincide con el total del período o dice por qué no.
