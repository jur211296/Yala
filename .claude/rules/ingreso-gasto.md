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

## Cuatro cifras que tienen que cuadrar (lote 02 de mejoras necesarias de 2.3, 2026-11-10)

- **El desglose «Por categoría» de un presupuesto suma lo gastado.** `BudgetsViewModel.combinedBreakdown` usa los mismos
  movimientos que `calculateSpending`, con «Sin categoría» y «Sin subcategoría»: un presupuesto por cuenta o etiqueta
  cuenta en lo gastado lo que no tiene subcategoría, y el desglose también. Lo fija `BudgetBreakdownSumsSpentTests`.
- **El día más caro de Estadísticas sale de una entrada**, `WeekdaySpendingCalculator.forStatistics`, para Resumen y
  Tendencias (ignora el chip Ingresos/Gastos; con «Todo», cuenta hasta hoy). Lo fija `WeekdayPriciestDayParityTests`.
- **El flujo proyectado proyecta lo que falta de cada mes** (decisión de Jürgen del 2026-11-10; desde S6 del replanteo
  del flujo de caja, 18-nov-2026, con la mediana del motor del mes en vez del ritmo de 90 días): lo esperado del mes
  menos lo que ya tiene, real o fechado, por lado y nunca negativo. Contar lo esperado a secas por día volvía a contar
  el sueldo ya cobrado. Lo fijan `ProjectedFlowCalculatorTests` y `FlujoConsumidoresParidadTests`.
- **Un reparto de grupo cuadra al céntimo** (decisión de Jürgen): «Monto» y «Porcentaje» con
  `GroupSplitCalculator.balanceTolerance` (medio céntimo, solo coma flotante), y la insignia del formulario con la misma.
  Un porcentaje que se REABRE (edición, plantilla, pago planificado) pasa por `GroupExpenseViewModel.loadPercentages`,
  que lo deja sumando 100: a un decimal, un gasto pequeño se reabría con 100,1 y no dejaba guardar.

## «Al 30 tendrías»: una cifra, la del Panel (decisión 30 de 2.3, 2026-11-11)

La cabecera del mes en curso del flujo de caja y «Ver proyectado» del Panel (Saldo, «Este mes», sin filtro de cuentas)
dan la misma cifra porque salen de la misma cuenta: saldo vivo de las cuentas del Panel + `ProjectedFlowBuilder` hasta
fin de mes sin filtros de sesión (`MonthEndBalanceLogic`). Si cambias cómo proyecta el Panel con Saldo, cambia esa pieza
también; lo fija `FlujoAl30YEstimadoTests` (paridad y caso con plan).

**Con plan, lo que falta sale del motor del mes (`FlujoMotorMes`, S1 del replanteo del flujo de caja, 2026-11-18).** El
flujo de caja y `ProjectedFlowBuilder.planRemaining` (Panel, Tendencias, widget de Saldo) piden al mismo motor lo que les
falta a las líneas y, en «otros», lo que se detecta en los registros (párrafo de la proyección inteligente, abajo); lo no
cubierto ya no va al ritmo. Un plan sin líneas también manda. Cada mes del flujo de caja es real con signo (fechado antes
de mañana, con lo sin categoría) + lo que falta; el cierre de un mes pasado es el saldo real de las cuentas (cada divisa
a la tasa de su cierre), el del mes en curso es «Al 30», y los futuros encadenan. El saldo inicial manual del plan ya no
se usa. Cada movimiento tiene UN dueño (su pago con línea, su subcategoría, su categoría, el «sin subcategoría» del grupo
o «otros») y el promedio de una línea sale de ese mismo reparto: si añades una forma de atribuir, cambia las dos a la
vez. Lo fijan `FlujoMotorMesTests` (un caso por hallazgo del ticket `2026-11-17-flujo-de-caja-replanteo`, paridad con
`MonthEndBalanceLogic` incluida).

**Sin plan, o con filtros de sesión, el mismo motor sin líneas (S6, 18-nov-2026).** `ProjectedFlowBuilder.othersRemaining`
pide al motor «otros» (la proyección inteligente, abajo); ya no hay ritmo de 90 días. Sin filtros, la mediana sale de todos los movimientos, como con plan; con filtros, de los filtrados. Sin un mes
completo de historia no hay mediana: solo pagos planificados y lo fechado. Panel, Tendencias y el widget de Saldo
heredan la pieza por `ProjectedFlowBuilder.build`: «Al 30» del flujo de caja, del Panel y el último punto del mes del
widget son la misma cifra, con plan y sin plan (`FlujoConsumidoresParidadTests`).

**Proyección inteligente de lo que no tiene línea (decisión de Jürgen del 19-nov-2026, corrige P6 del replanteo).**
`FlujoProyeccionInteligente`, llamado desde `FlujoMotorMes.calcular`, detecta en los movimientos de «otros»:
**ingresos fijos** (un grupo —subcategoría, categoría o sin categoría; dentro de uno que varía, un comercio por su nota—
con un monto parecido, ±25 %, en ≥ 2/3 de los 6 meses completos y presente el último mes o el actual), que se proyectan
con su monto y su día típico; y **aislados** (≥ 3 meses típicos sin repetirse en su grupo), que cuentan en su mes y salen
de la mediana de gastos, sin comerse lo que falta del mes en que ocurren (ni ellos ni su devolución). Los ingresos que
varían no se proyectan; con < 3 meses de historia no se detecta nada. En gastos no se parte por grupos: la mediana
mensual de «otros» sigue siendo una sola. Sin doble conteo: lo ya cobrado del fijo (también con otra categoría de monto
parecido, o adelantado a fin del mes anterior), los pagos planificados de su grupo y una línea libre del plan descuentan
de lo que le falta; si ya llegó el 75 %, no se proyecta la diferencia. Los ingresos fijos se detectan solo en lo que
cuenta para la cifra (con Saldo, las cuentas que suman): un cobro en una cuenta excluida no se proyecta en ese saldo.
En «Ver proyectado», un fijo de una vez al mes se dibuja en su día (`dayPlacedFlows`), no repartido; el cierre del mes no
cambia. Los umbrales viven en `FlujoProyeccionInteligente.Umbrales`; lo fijan `YalaTests/FlujoProyeccionInteligente/`
(un caso por cada hallazgo de su review adversarial) y la paridad con Panel, widget y Tendencias.

**Con plan, los meses que vienen proyectan fuera de las líneas solo lo fijo (decisión de Jürgen del 19-nov-2026, 10:47).**
`FlujoMotorMes.Entrada.soloFijosEnMesesFuturos` (lo enciende `CashFlowProjectionCalculator.calculate`, que siempre tiene
plan): en «otros» de un mes que viene no hay mediana, solo los fijos a futuro de `FlujoProyeccionInteligente.Lado`
(ingresos: los mismos fijos; gastos: una vez al mes, ±25 %, día dentro de ±5 de su día típico, sin aislados). El mes en
curso y los pasados no cambian, y sin plan (Panel sin plan) se sigue proyectando lo variable. Cada fijo se puede apagar
en «Considerar a futuro» (`FlujoFijosAFuturo`). Desde el 19-nov-2026 (tarde) viaja entre teléfonos como preferencia
sincronizada (`PrefSyncKey.cashFlowFutureExcludedFixed`, lista JSON; iCloud clave-valor o la tabla de preferencias del
Modo Nube, sin despliegue); la lista local de antes la une la lectura y la sube una pasada al arrancar. Lo fija
`YalaTests/FlujoSyncYPanelDia1/`. La hoja de no
considerados pinta `CashFlowOtherResult.items` (una fila por subcategoría): su suma más `variableLeft` es el total del
mes. Lo fijan `FlujoAisladosPromedioTests` y el caso «partida apagada» de `FlujoProyeccionInteligenteParidadTests`.

**El saldo al empezar el mes es una cifra, la de «Empezaste con» (decisión de Jürgen del 19-nov-2026, 14:04).** La fila
del gráfico de saldo del Panel («1 nov S/ … → hoy S/ … · %») parte de lo que había ANTES del primer instante del período,
con `FlujoMotorMesEntrada.FuenteSaldo.saldos(antesDe:)`, la misma pieza del flujo de caja (`PanelTrendData.trendPeriodStartBalance`).
El primer punto de la curva es el CIERRE de su primer día y contaba lo movido el día 1 (el sueldo): el Panel decía
S/ 72,979 y el flujo de caja S/ 64,345. La curva no cambia. El widget y Tendencias no pintan esa cifra. Lo fija
`YalaTests/FlujoSyncYPanelDia1/`.

**Las líneas por promedio, último mes o tendencia dejan fuera los meses aislados, y su límite se mueve solo (19-nov-2026,
10:10 y 10:21; corrige el P4 del replanteo).** `CashFlowProjectionCalculator.explainEstimate` busca los meses aislados de
la línea con `FlujoProyeccionInteligente.mesesAislados` (a nivel de MES: ≥ 3 veces la mediana de los meses con algo, con
≥ 3 meses; a nivel de movimiento dos meses fuertes se «repetirían» entre sí) en los 6 meses anteriores (12 con «Promedio
12 meses») y cada método mira su ventana sin ellos. Cada mes pasado o en curso usa su propia ventana; los que vienen, la
del mes en curso. Crear el plan y «Agregar línea» guardan el método elegido: solo «Monto fijo» deja un número quieto
(`FlujoLimitesMovilesMigracion` devuelve a su método, una vez, las líneas que el P4 sembró). Si cambias cómo sale un
límite, la explicación de «Cómo se calcula» y las cifras de «Cálculo del monto» salen de la misma función.

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
