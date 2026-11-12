---
description: Cómo decide la app si un movimiento es ingreso o gasto, cómo se suma, qué filas entran en un saldo y de dónde sale lo gastado de un presupuesto. Una sola regla por cifra; se carga al tocar calculadores, ViewModels de pantallas con totales, widgets y filtros.
paths:
  - "Yala/App/Logic/Calculators/**"
  - "Yala/App/Logic/CreditCardStatement*.swift"
  - "Yala/Services/CreditCardReminderScheduler.swift"
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
desaparecer). Cámbialas por el helper, también en un desglose por categoría (abajo).

**Un desglose POR CATEGORÍA lleva un trozo «Sin categoría» (decisión A de Jürgen, 2026-10-23).** Tarta y rankings de
categorías y subcategorías, Sankey y categorías del widget de inicio meten el movimiento sin categoría del lado que dice
su signo, con el texto del Informe (`L10n.Report.uncategorized`; en la extensión, `widget.ui.uncategorized`, la misma
traducción) y el gris `AppConstants.uncategorizedColorHex`. Así su suma es el total del período. En
`CategorySpendingSummary` es `category == nil` (`isUncategorized`, `id == nil`): no se puede elegir como filtro
(`isSelected(in:)`), y lo que NOMBRA la mayor categoría (Observaciones, aviso de informe, hallazgo de Distribución) se
lo salta. Con Ingresos y Gastos elegidos a la vez, el trozo suma la magnitud de cada lado (no se restan). La distribución
por necesidad no tiene trozos por categoría: sin categoría no hay necesidad y cae en «Sin clasificar» (en Observaciones,
que suma lo sin clasificar a Opcional, ahí). El corte del período anterior (`DistributionPreviousPeriodCalculator.currentDates`)
cuenta el movimiento sin categoría, porque todas sus calculadoras lo cuentan. Un desglose nuevo por categoría sigue la misma forma; lo fija `CategoryBreakdownUncategorizedTests`.
Pendiente: el ranking de subcategorías del widget de inicio deja fuera lo que no tiene subcategoría, con o sin
categoría. Yala IA y el conector `mcp/` la siguen desde el 2026-10-29 (ticket
`yala-ia-classifies-uncategorized-movements-as-expense`): el contexto del chat pone el gasto sin categoría en «Other» de
categorías, comercios, necesidades, historial y anomalías, y el ingreso sin categoría en «Other» de `income_categories`;
el bucket `uncategorized` es solo gasto. El `tipo` de `buscar_movimientos` ya no dice `sin_categoria` (`txKindOf`), y el
golden lo ata (`kinds`). Si tocas uno, cambia el otro y regenera `MCPAppParityGoldenTests`; lo fija
`YalaIAUncategorizedClassificationTests`.

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

## `balanceAdjustmentType != nil` NO quiere decir «ajuste de saldo» (2026-10-27)

El campo tiene tres valores: `initial_balance`, `adjustment` y `transfer` (`TransactionItem.adjustmentTypeTransfer`, las
DOS patas de una transferencia y el import CSV). Para separar «corrige el saldo» de «movimiento real», compara contra los
dos primeros (`InitialBalanceService.typeInitialBalance` / `.typeAdjustment`), nunca contra `nil`. Lo pagó el estado de
cuenta de la tarjeta (card nmtk): con `!= nil`, pagar la tarjeta con una transferencia —la forma normal— no bajaba lo
facturado, y el aviso anunciaba una deuda ya pagada. Lo cazó la review; lo fija
`CreditCardReminderSchedulerTests.unaTransferenciaALaTarjeta_esUnPago` (`CreditCardReminderScheduler.isBalanceAdjustment`).
