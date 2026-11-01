---
id: widget-category-percentages-use-the-signed-total
status: backlog
priority: low
area: widgets
created: 2026-11-01
updated: 2026-11-01
source: review adversarial de S35f2 (widgets-tanda-3-categorias, 2026-11-01)
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
