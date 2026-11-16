---
id: 2026-11-15-analisis-por-cuenta
status: done
priority: medium
area: "panel, cuentas, gráficas"
created: 2026-11-15
updated: 2026-11-16
source: "Jürgen, 15-nov: el análisis de cada cuenta se queda corto y sus gráficas no siguen el design system"
---

# La ficha de una cuenta, con las gráficas de los widgets del Panel

Al tocar una cuenta en el Panel se abre su ficha. Tenía una curva de saldo propia y unas barras de «En qué se fue» que
no se parecían a las gráficas del Panel, y enseñaba poco de la cuenta. Jürgen pidió rehacerla con gráficas iguales a las
de los widgets, para ver lo más posible de esa cuenta sin que abrume.

## Hecho cuando

- La ficha usa los mismos componentes de los widgets: la curva de Tendencias, el flujo de caja y la distribución por
  categoría, con los datos de la cuenta y sin tocar los widgets.
- Enseña la evolución del saldo, lo que entró y salió, en qué se fue, los gastos más grandes y la comparación con el
  período anterior; en una tarjeta de crédito, además, el estado de cuenta.
- Se mantiene lo que ya funcionaba: «Así se forma tu saldo», el selector de divisa de la tarjeta, «Filtrar por esta
  cuenta», «Últimos registros» y Editar.
- Tests de los cálculos nuevos: períodos, varias monedas y tarjeta de crédito con saldo negativo.

## Resolución (2026-11-16)

- `AccountAnalysisCharts` (en `Yala/App/Views/Accounts/AnalisisCuenta/`) monta `TrendChartView`, `CashFlowWidget` y
  `CategoriesPieWidget` tal cual, sin acciones: en la ficha un toque no cambia los filtros del Panel.
- `AccountAnalysisBuilder` les da de comer: la curva sale de `AccountDetailCalculator` (la misma suma que la tarjeta, con
  el suavizado del Panel en períodos largos), y el flujo y las categorías de `CashFlowCalculator` y
  `TopSpendingCategoriesCalculator` en la divisa de la línea elegida. La tarta suma lo mismo que lo gastado de la
  tarjeta en «solo gastos», con «Sin categoría». La comparación es contra el período anterior hasta hoy.
- `AccountDetailCalculator.largestExpenses`: los tres gastos más grandes del período.
- Las decisiones, en el Paso 0 del encargo (`encargos/lanzados/2026-11-16-analisis-por-cuenta-rediseno.md`).
- Tests: `YalaTests/AnalisisCuenta/AccountAnalysisTests.swift`.
