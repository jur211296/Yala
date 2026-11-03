---
id: widget-category-percentages-use-the-signed-total
status: qa
priority: high
area: widgets
created: 2026-11-01
updated: 2026-11-03
source: review adversarial de S35f2 (widgets-tanda-3-categorias, 2026-11-01) · card tablero-widgets-de-categorias-los-porcentajes-se-znu5
---

# Los porcentajes de las categorías del widget se miden contra el total con signo

## Qué le pasa al usuario

Con una devolución en el período, las tartas y los rankings de Categorías y Subcategorías de la pantalla de inicio
enseñan porcentajes que suman más del 100 % y un total en el centro menor que la suma de sus filas. Ejemplo: un gasto de
100 en Comida y una devolución de 30 dan «Comida S/ 130 · 186 %» con «Total S/ 70» en el centro.

## Por qué pasa (leído en el código, sin reproducir en un teléfono)

- Cada trozo suma importes en positivo (`abs`, `WidgetDataCache.buildTopCategories` y `buildTopSubcategories`).
- El porcentaje se divide por `totalExpense`, que acumula con signo (la devolución resta). `.claude/rules/ingreso-gasto.md`
  dice que el denominador de un desglose es la suma de MAGNITUDES del lado, no el total con signo.
- La tarta del widget (S35f2) agrupa contra ese total: lo que las filas no cubren va a «Otros». Si las filas cubren MÁS,
  el aro normaliza y no se inventa un resto negativo.

## Qué haría falta

Decidir en la app (lógica de datos, fuera del encargo de S35f2) si el trozo de una categoría con devoluciones resta como
el total o si el denominador pasa a ser la suma de magnitudes, y aplicarlo igual en la foto del widget y en el camino de
emergencia de la extensión (`WidgetDataService`). El Panel de la app tiene la misma pregunta pendiente.

## Qué se hizo (2026-11-03, encargo 03 de la cola)

Medido antes de tocar: los porcentajes de la foto ya se dividían por la suma de magnitudes desde el 2026-10-23. Lo roto
era el centro y «Otros» (contra el gasto con signo) y que cada trozo sumaba la magnitud de cada movimiento.

- Cada trozo es el neto de su categoría, como la tarta de Estadísticas: un gasto de 100 y su devolución de 30 dan 70.
  Regla única en `WidgetInsightsLogic.netExpenseSlices`, que usan la foto (`WidgetDataCache`) y el camino de emergencia
  de la extensión (`WidgetDataService`).
- La foto lleva `expenseBreakdownTotal` (la suma de todos los trozos, opcional en las dos copias). Las dos tartas lo
  ponen en el centro y miden «Otros» contra él; el resumen del mes mide su «Otros» igual. «Gastado» sigue siendo el gasto.
- Las subcategorías se miden contra su propio desglose: sus filas más lo que no tiene subcategoría, por categoría
  (`expenseSubcategoryBreakdownTotal`). Lo cazó la review: con el total de categorías, un gasto de 100 en Restaurante y
  una devolución de 80 en Comida sin subcategoría daban una fila del 500 %.
- Con un gasto y su devolución, los porcentajes suman 100 % y el centro es la suma de las filas. Con una categoría a
  favor también suman 100 %; el centro es entonces la suma de las magnitudes.
- No tocado: los porcentajes de Estadísticas (no comparten código; su denominador es el total con signo y solo se
  descuadra con una categoría a favor).

Tests: `WidgetInsightsLogicTests` (desglose), `WidgetDataCacheTests` (`periodSummary_aRefund*`,
`…subcategoriesNetTheRefund…`, `…aCategoryInFavor…`) y `WidgetBreakdownTotalWiringTests` (extensión y tartas).

## Guion de QA en el iPhone (2 min)

1. En Yala Dev, crea un gasto de 100 en Comida y, el mismo mes, un registro de +30 en Comida (la devolución).
2. Abre la app una vez (rehace la foto) y vuelve a la pantalla de inicio.
3. Mira el widget grande «Categorías» (este mes): Comida dice 70, los porcentajes de la leyenda suman 100 % y el
   «Total» del centro es la suma de las filas.
4. Mira «Top categorías» y el «Resumen del mes»: Comida con 70 y ningún porcentaje por encima de 100 %.
5. Borra los dos registros de prueba.


Cerrado en el barrido de QA 2026-11-03: cálculo con test (WidgetBreakdownTotalWiringTests, CategoryBreakdownUncategorizedTests, PR #753).
