---
id: fx-category-totals-unmarked
status: backlog
priority: low
area: currency
created: 2026-09-09
updated: 2026-10-08
source: hallazgo de camino en fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# Los desgloses por categoría no pueden decir si son aproximados

## Qué le pasa al usuario

El total de gastos del mes lleva «≈» y las categorías que lo componen no. No es una contradicción
—un total puede ser dudoso porque UNA categoría lo es— pero el usuario que quiere saber **cuál** no
tiene forma de averiguarlo: abre el desglose buscando el origen de la marca y todas las líneas se
presentan como exactas.

## Dónde, medido el 2026-09-09

Ninguno de estos calculadores acumula la calidad de las conversiones que suma:

| calculador | qué alimenta |
|---|---|
| `TopSpendingCategoriesCalculator` | hero de Distribución fuera de modo Balance, pie de categorías, `TopCategoriesWidget` |
| el mismo, por subcategoría | `TopSubcategoriesWidget`, pie de subcategorías |
| `InsightsCalculator.calculateNeedDistribution` | los tres buckets de necesidad de Estadísticas |
| `buildTopCategories` / `buildTopSubcategories` de `WidgetDataCache` | las filas de los widgets de inicio |

Los sitios que pintan estos importes llevan ya el comentario que explica por qué NO heredan la
señal del total: la incertidumbre puede estar entera en otra categoría, y atribuírsela a ésta sería
inventar. El precedente que fija el criterio es `CashFlowSummary`, cuya señal va **por lado** por la
misma razón.

## Por qué es `low`

El total que agrega estas líneas SÍ avisa desde el 2026-09-09, así que el usuario no ve un número
declarado exacto que no lo sea: ve un desglose sin marca bajo un total marcado. Es información que
falta, no información falsa.

## Criterio de hecho (AC)

- [ ] Cada fila del desglose lleva su propia marca, medida con `ApproximateMarkThreshold` sobre las
      transacciones de ESA categoría.
- [ ] Un test que fije que una categoría exacta bajo un total marcado **no** se marca.

## Medido en 2.1 (triage 2026-10-08)

- `TopSpendingCategoriesCalculator` no tiene ningún campo de calidad (cero coincidencias de `approx`), e `InsightsCalculator.calculateNeedDistribution` tampoco. `WidgetDataCache` marca ingresos, gastos, flujo y saldo, no las filas de categorías.
- Ningún commit desde el 2026-09-09 toca la marca en estos calculadores. Hermano con otra superficie: `pie-header-total-unmarked` (medium, el total del pie).

Triage 2026-10-08: abierto · low → low · los desgloses por categoría siguen sin marca; es información que falta, no falsa, porque el total sí avisa.
