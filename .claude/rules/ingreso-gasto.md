---
description: Cómo decide la app si un movimiento es ingreso o gasto, cómo se suma, qué filas entran en un saldo y de dónde sale lo gastado de un presupuesto. Una sola regla por cifra; se carga al tocar calculadores, ViewModels de pantallas con totales, widgets y filtros.
paths:
  - "Yala/App/Logic/Calculators/**"
  - "Yala/App/Logic/TransactionClassificationLogic.swift"
  - "Yala/App/Logic/AccountSpendingLogic.swift"
  - "Yala/App/Logic/Helpers/**"
  - "Yala/App/ViewModels/PanelViewModel.swift"
  - "Yala/App/ViewModels/BudgetsViewModel.swift"
  - "Yala/App/ViewModels/RecordsViewModel.swift"
  - "Yala/App/ViewModels/StatisticsViewModel.swift"
  - "Yala/Services/WidgetDataCache.swift"
  - "Yala/Services/FilterService.swift"
  - "Yala/Services/TrendDataProcessor.swift"
  - "YalaWidgets/Services/WidgetDataService.swift"
---

# Ingreso, gasto, saldo y presupuesto: una regla por cifra

El mismo dinero tiene que dar la misma cifra en todas las pantallas. Hasta el 2026-10-23 cada pantalla decidía por su
cuenta y el mismo mes salía con cuatro pares de cifras (ticket `records-standalone-amount-discrepancy`).

## Ingreso o gasto: `TransactionClassificationLogic.isIncome`

**La categoría manda; sin categoría, el signo (`>= 0` es ingreso).** Decisión de Jürgen del 2026-09-06. Toda decisión
ingreso/gasto que alimente un total, una curva, una lista, un filtro, un color o un formulario pasa por ahí; con datos
sueltos (sin `TransactionItem`), por `isIncome(categoryIsIncome:signedAmount:)`, que es la misma regla.

Al leer código, tres formas delatan una regla propia —cada una contesta otra cosa para el movimiento sin categoría—:
`category?.isIncome == true` y `?? false` (lo dan por gasto) y `guard let category … else { continue }` (lo hace
desaparecer). Cámbialas por el helper, salvo en un desglose por categoría (abajo).

**Excepción, abierta:** los desgloses POR CATEGORÍA (tarta y rankings de categorías/subcategorías, Sankey, distribución
por necesidad) no tienen dónde poner un movimiento sin categoría y lo dejan fuera; su suma puede quedar por debajo del
total. Es una decisión de UI pendiente (ticket `category-breakdowns-leave-out-uncategorized-movements`). Yala IA y el
conector `mcp/` tampoco siguen aún la regla (ticket `yala-ia-classifies-uncategorized-movements-as-expense`): si los
tocas, cambia los dos y regenera `MCPAppParityGoldenTests`.

## Cómo se suma: con signo

Un total de ingresos o de gastos acumula **con signo**: un importe contrario a su categoría (una devolución en una
categoría de gasto) **resta** de su lado, no suma su magnitud. Es lo que hacen Registros, Flujo de caja, Tendencias, el
hero del Panel y los widgets de inicio. `ingresos − gastos` es entonces la suma de los importes; reclasificar mueve dinero
de un lado al otro sin tocar el neto. Un lado puede salir negativo (devolvieron más de lo que se gastó): se enseña tal cual.

Lo que deja de poder leerse de la cifra, y ya no se lee: «no hubo movimientos» (`ingresos == 0 && gastos == 0` con un
gasto y su devolución; el hero usa `periodHasAnyTx`), el denominador de la marca «≈» de cada lado y el de los porcentajes
de un desglose, que son la suma de MAGNITUDES del lado (como `CashFlowCalculator`), no el total con signo.

Los desgloses que suman magnitudes (día de la semana, etiquetas, tartas, presupuestos) no son totales del período y no se
tocaron: si alguno pasa a pintarse como el total del mes, alinéalo antes.

## Qué filas entran en un saldo: `LiveBalanceCalculator.entersBalance`

Las que tienen cuenta. Lo leen el saldo vivo, la curva del widget de inicio y su saldo de período: la cifra del widget
contaba las filas sin cuenta y no coincidía con el último punto de su curva (card zyah). Un saldo nuevo pasa por ahí, y
por `TodayCutoff`.

Un movimiento sin cuenta tampoco entra en ingresos y gastos: el Panel, Registros y Estadísticas filtran por cuentas
elegibles (`guard let account = tx.account`), y desde el 2026-10-23 los widgets de inicio también
(`WidgetDataCache.countsForWidgets`). El aviso «Movimientos sin cuenta» del Panel es lo que lo enseña.

## Lo gastado de un presupuesto: `BudgetsViewModel.calculateSpending`

Planificación, la vista previa de Perfil, las alertas y la tarjeta del Panel llaman a la misma función (sin ajustes de
saldo, con «Contar mi parte de los gastos de grupo», con la parte neta de los gastos de grupo). El Panel le pasa su
`statsAdjustment`. El filtro de sesión NO entra: Planificación no lo mira. **Pendiente**: «Presupuestos en riesgo» de
Observaciones calcula por su cuenta (`InsightsCalculator.calculateCommitments`; ticket
`insights-budgets-at-risk-compute-spent-on-their-own`). Lo fija `PanelBudgetPlanningParityTests`.

## Los tests que lo fijan

`IncomeExpenseScreenParityTests` (seis superficies × tres períodos, Informe por dimensión, filtros y neto),
`PanelBudgetPlanningParityTests`, `WidgetBalanceAccountlessParityTests` y `ExcludedAccountSelectionTests`. Un fixture de
paridad tiene que traer las dos filas que separan las reglas: un movimiento sin categoría de cada signo y uno de signo
contrario a su categoría. Sin ellas todas las reglas dan lo mismo y el test no prueba nada.
