---
id: category-breakdowns-leave-out-uncategorized-movements
status: done
priority: low
area: "estadisticas, panel, widgets"
created: 2026-10-23
updated: 2026-10-24
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

## Decisión (Jürgen, 2026-10-23): A

Un trozo «Sin categoría» en gris neutro, como la fila del Informe. Sin copy nuevo.

## Hecho (2026-10-24, encargo `2026-10-24-tartas-sin-categoria-opcion-a`)

Qué ve el usuario: con 200 en Comida y 40 sin categoría, la tarta, el ranking de categorías y el de subcategorías de
Estadísticas y del Panel, el Sankey y las categorías del widget de inicio enseñan un trozo «Sin categoría» de 40 en gris
y suman 240, lo mismo que el gasto del mes. Un ingreso sin categoría va al lado de ingresos (filtro Ingresos, columna de
ingresos del Sankey). En la distribución por necesidad, el gasto sin categoría cae en «Sin clasificar».

- Lado: el signo, con la regla de los totales (`TransactionClassificationLogic.isIncome`).
- Texto: `L10n.Report.uncategorized`; en la extensión del widget, `widget.ui.uncategorized` con la misma traducción en
  los 16 idiomas. Color `#9CA3AF` e icono `questionmark.folder.fill` (`AppConstants.uncategorized*`).
- El trozo no se puede tocar para filtrar. Los textos que nombran la mayor categoría (Observaciones, aviso de informe,
  hallazgo de Distribución, «Tus datos» de la hoja de información) nombran la primera categoría real.
- Tests: `CategoryBreakdownUncategorizedTests` (caso 200 + 40 en tarta, rankings, Sankey, necesidad y widget, contra el
  total de `CashFlowCalculator`) y paridad por fuente de la copia de la extensión. Fixture de QA:
  `-uitest-seed-uncategorized-expense`.

Fuera de alcance, anotado: el ranking de subcategorías del widget de inicio deja fuera lo que no tiene subcategoría (con
o sin categoría); el Sankey suma magnitudes por movimiento, así que con una devolución su gasto no cuadra con el del
período (antes de este cambio ya pasaba).

## QA de Jürgen (ojo humano, no bloquea)

1. En Yala Dev, apunta un gasto sin categoría (por importación CSV, o en el simulador con
   `-uitest -uitest-seed minimal -uitest-seed-uncategorized-expense`).
2. Panel › tarta de categorías: sale un trozo gris «Sin categoría»; tocarlo no filtra nada.
3. Estadísticas › Distribución: la tarta, la lista de categorías y la de subcategorías suman lo que dice el hero.
4. Estadísticas › Sankey: nodo gris «Sin categoría» en la columna de categorías.
5. Widget de inicio de categorías (mediano o grande): fila gris «Sin categoría»; cambia el período del widget y sigue.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
