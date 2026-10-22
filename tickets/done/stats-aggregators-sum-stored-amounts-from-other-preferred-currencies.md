---
id: stats-aggregators-sum-stored-amounts-from-other-preferred-currencies
status: done
priority: medium
area: currency
created: 2026-10-10
updated: 2026-10-10
source: hallazgo de camino en records-summary-mixes-preferred-currencies (2026-10-10)
---

# Más totales de Estadísticas suman importes guardados en otra divisa principal

## Qué le pasa al usuario

Es el mismo bug que `records-summary-mixes-preferred-currencies` en otras pantallas. Si el usuario
cambió de divisa principal y quedan transacciones sin recalcular, estos totales suman su
`amountInPreferredCurrency` tal cual, aunque se guardara en la divisa anterior. El número mezcla
dos escalas y se pinta con el símbolo de la actual.

## Dónde, medido el 2026-10-10 sobre `origin/2.1` + el PR de Registros

Suman `adjustment.amountInPreferredCurrency(tx)` sin comprobar `tx.preferredCurrencyCode`:

- `SankeyFlowCalculator.swift:74` (flujo de Distribución)
- `TagSpendingCalculator.swift:53` (gasto por etiqueta)
- `PivotTableCalculator.swift:56` y `:59` (tabla dinámica, cuando no usa el monto original)
- `HeroBucketsCalculator.swift:103` (hero de Estadísticas)

Es un grep, no un barrido completo: `grep -rln amountInPreferredCurrency Yala | xargs grep -L "preferredCurrencyCode =="`
devuelve ~40 ficheros, y muchos no agregan (servicios de escritura, sync, seeds). Falta recorrerlos.

## Cómo se arregla

La regla ya existe y es única: `CashFlowCalculator.resolvedAmount(_:currencyCode:adjustment:converter:)`,
extraída en el PR de Registros. Devuelve el importe y su magnitud dudosa para la marca «≈». Cada
calculador necesita recibir la divisa principal y un converter.

## Criterio de hecho

- [x] Cada superficie de la lista resuelve el importe con `resolvedAmount`.
- [x] Un test por superficie con dos filas de `preferredCurrencyCode` distinto: el total sale en la divisa vigente.
- [x] El barrido de los ~40 ficheros queda hecho y anotado aquí.

## Hecho (2026-10-10)

Los cuatro de la lista resuelven con `CashFlowCalculator.resolvedAmount`. El hero era el del Panel
(`HeroBucketsCalculator`), no el de Estadísticas: su marca «≈» sale ahora de la misma regla (la
reconversión con tasa no exacta marca). Entraron además dos superficies que comparten pantalla con lo
arreglado, porque arreglar solo una mitad dejaba la pantalla contradiciéndose:

- el **neto de Informes** (`FinancialReportViewModel.calculateReport`), encima de la tabla dinámica;
- la **tarjeta de Tendencias** (`TrendDataProcessor`: total y curva de ingreso/gasto), que comparte el
  Panel con el hero, y su **KPI en Estadísticas** (`StatisticsViewModel.periodTotals`, extraído de
  `calculateTotals` para poder probarlo).

Tests:
`StatsAggregatorsPreferredCurrencyTests` (mezcla y una sola divisa por superficie), con mutantes en
las dos direcciones.

## Barrido de los ~40 ficheros, medido el 2026-10-10 sobre `origin/2.1` (1c101c4a8)

El grep del ticket (`grep -rln amountInPreferredCurrency Yala | xargs grep -L "preferredCurrencyCode =="`)
más los ficheros que SÍ tienen una guarda en un sitio y suman sin ella en otro
(`grep -rnE 'adjustment\.amountInPreferredCurrency\(|incomeAwarePreferred\(|…'`).

**Agregan sin guarda y quedan con ticket propio:**

| superficie | sitios | ticket |
|---|---|---|
| Tendencias: curvas por cuenta, histórico y saldos (lo agregado entró aquí) | `TrendDataProcessor:309,324` · `StatisticsViewModel:514,814,825,838,847` | `trends-aggregators-sum-stored-amounts-from-other-preferred-currencies` |
| Salud financiera (ingreso del score) | `FinancialScoreCalculator:510` | `health-score-income-sums-stored-amounts-from-other-preferred-currencies` |
| Yala IA (sugerencias y pata real de grupo) | `ChatSuggestionsLLMService:203-247` · `FullFinancialContextBuilder:1062` · `AnomalyDetectionCalculator:135` | `yala-ia-context-sums-stored-amounts-from-other-preferred-currencies` |
| Widgets | `WidgetDataCache:595-605` (y sus 6 usos) · `YalaWidgets/…/WidgetDataService:491,548,591,634` | `widgets-sum-stored-amounts-from-other-preferred-currencies` |

**Ya guardan por `preferredCurrencyCode`** (no es este bug): `CashFlowProjectionCalculator`,
`TopSpendingCategoriesCalculator`, `TopSubcategoriesCalculator`, `WeekdaySpendingCalculator`,
`NeedTrendHelper`, `BalanceHelper`, `FXPnLLogic`, `ReportNotificationService`,
`TransactionItem+ChatAmount`, `InsightsCalculator` (su `convertedAmount`, `:492`) y
`CashFlowCalculator`/`DailySpendingCalculator`/`RecordsViewModel` (PR #434).

**No agregan:** escritura y reparación (`TransactionService`, `TransactionUpdateService`,
`DraftService`, `InitialBalanceService`, `CurrencyChangeService`, `AccountCurrencyMigrationService`,
`ExchangeRateRepairLogic`, `ChatUnsignedExpenseRepair*`, `TransactionCSVImportService`,
`NewTransactionViewModel`, `ChatAssistantViewModel`, `InboxDraftEditSheet`), sync
(`CloudSyncReconciler`, `EntityApplyMap`, `EntityEmissionMap`), seeds (`DevSeed*`), el modelo
(`TransactionItem`), el propio ajuste (`GroupBridgeStatsAdjustment`, que es el accesor), la
clasificación por signo (`TransactionClassificationLogic`, el signo no depende de la escala), el
detalle de un registro (`TransactionDetailSheet`, que pinta con la divisa de la fila), la vista
previa del widget (`LatestRecordsWidget`) y comentarios (`AppBootstrapper`, `BalanceKPICalculator`,
`LiveBalanceCalculator`, `BudgetsViewModel`, `PanelViewModel`).
