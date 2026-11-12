# Implementar opción A: trozo «Sin categoría» gris en tartas, rankings, Sankey y widget

## Contexto
Card: `tablero-decidir-las-tartas-y-rankings-por-catego-1a5m` (in progress).
Ticket: `tickets/backlog/category-breakdowns-leave-out-uncategorized-movements.md` en origin/2.2.
Jürgen eligió **A** el 23/10: un trozo «Sin categoría» en gris neutro en la tarta, el ranking, el Sankey y el widget, igual que ya hace el Informe por categoría (fila «Sin categoría», `L10n.Report.uncategorized`). Sin copy nuevo en 16 idiomas.

Desde el 2026-10-23 un movimiento sin categoría cuenta como ingreso o gasto por su signo en todos los totales. Los desgloses por categoría lo dejan fuera: con 200 en Comida y 40 sin categoría, el gasto del mes dice 240 y la tarta suma 200.

Calculadoras/sitios a tocar (del ticket):
- `TopSpendingCategoriesCalculator`, `TopSubcategoriesCalculator` (Estadísticas)
- `SankeyFlowCalculator`
- `InsightsCalculator`, `NeedTrendHelper` (distribución por necesidad)
- `WidgetDataCache.buildTopCategories` (widgets de inicio)
- Referencia de UI/copy: Informe por categoría con `L10n.Report.uncategorized`

Base: `origin/2.2`. Antes del PR, fetch y rebase una sola vez sobre `origin/2.2` con el simulador apagado.

## Que se pide
1. Incluir los movimientos sin categoría como trozo/fila «Sin categoría» con el gris neutro del Informe en tartas, rankings de categorías y subcategorías, Sankey, distribución por necesidad y categorías de widgets.
2. Cada desglose por categoría debe sumar el total del período (mismo criterio de signo que ya usan los totales).
3. Reusar `L10n.Report.uncategorized` (u homólogo ya existente); no añadir copy nuevo.
4. Tests que fijen el caso 200+40 → tarta/ranking/Sankey/widget suman 240 con trozo Sin categoría.
5. Actualizar el ticket cuando el PR esté listo.
6. Pipeline serial Yala: limpiar → build con `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar/limpiar. Máximo 1 sim. Al cerrar: apagar sims, erase data de esos devices, quitar DerivedData de esta sesión y cachés XcodeBuildMCP de worktrees que ya no existen.
7. Cierra con `/cerrar-total` (form-4). No esperes a Jürgen: la decisión A ya está tomada.

## Que NO hay que tocar
- No opciones B ni C.
- No cambiar cómo los totales cuentan sin categoría (eso ya está).
- No marketing/, no producción, no mergear a mano a 2.2 (deja el PR en cola).
- No abrir otro simulador en paralelo ni dejar sims booted al terminar.

## Como se sabe que esta bien
- Con 200 en Comida y 40 sin categoría, tarta/ranking/Sankey/widget muestran trozo «Sin categoría» y suman 240.
- Misma apariencia/gris/copy que el Informe.
- Tests verdes del alcance; PR abierto a 2.2 listo para auto-merge.
- Si solo tests bastan → card a done con nota; si hace falta ojo humano en UI → in qa.

## Paso 0

Decisiones resueltas antes de tocar código (sesión autónoma; la de producto, A, ya la tomó Jürgen el 23-oct).

**Qué es «sin categoría» en un desglose.** Un movimiento sin categoría entra en el desglose del lado que dice su signo
(`TransactionClassificationLogic.isIncome`, la regla de los totales), como un trozo/fila propio con el texto del Informe
(`L10n.Report.uncategorized`) y el gris neutro de la app (`#9CA3AF`, el de «Sin subcategoría» y «Otros fondos» del
Sankey). Así cada tarta y ranking suma lo mismo que el total del período con el mismo criterio de signo.
- *Asumido*: el Informe no pinta icono en esa fila. Una fila o un trozo de tarta sin icono dejaría un círculo gris vacío,
  así que lleva `questionmark.folder.fill` sobre el gris. Copy: ninguno nuevo.
- *Asumido*: el trozo no se puede tocar para filtrar (no hay categoría que seleccionar). La tarta y las filas ya
  admiten trozos sin identificador («Otros»); se reusa eso.
- *Asumido*: en los textos que NOMBRAN la categoría principal (Observaciones, notificación de informe, hallazgo de
  Distribución) «Sin categoría» no cuenta como categoría: se nombra la primera categoría real.
- *Asumido*: la distribución por necesidad no tiene trozos por categoría: la necesidad vive en la subcategoría, así que
  un movimiento sin categoría cae en «Sin clasificar» (y en Observaciones, donde ese tramo se suma a Opcional, ahí). Es lo
  que ya les pasa a los movimientos con categoría y sin subcategoría.
- *Asumido*: el Sankey suma magnitudes por movimiento (no con signo) y eso no se toca; el movimiento sin categoría entra
  como nodo «Sin categoría» en la columna de ingresos o en la de categorías de gasto.
- *Asumido*: el widget de inicio necesita el texto en su propio catálogo (la extensión recalcula al cambiar de período).
  Se copia la traducción existente de `report.uncategorized` de la app a los 16 idiomas del widget: misma cadena, no copy
  nuevo.
- *Fuera*: el ranking de subcategorías del widget de inicio deja fuera también lo que tiene categoría y no subcategoría;
  es otra pregunta y no la pide el ticket. Se anota.

Ficheros: más de 3 (modo autónomo: nota). Review adversarial: sí, toca cálculos financieros de desgloses.
