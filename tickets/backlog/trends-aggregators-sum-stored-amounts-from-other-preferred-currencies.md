---
id: trends-aggregators-sum-stored-amounts-from-other-preferred-currencies
status: backlog
priority: medium
area: currency
created: 2026-10-10
updated: 2026-10-10
source: barrido de stats-aggregators-sum-stored-amounts-from-other-preferred-currencies (2026-10-10)
---

# Las curvas por cuenta, los históricos y los saldos de Tendencias suman importes guardados en otra divisa principal

## Qué le pasa al usuario

Es el mismo bug que Distribución, etiquetas, Informes y la tarjeta de Tendencias (arreglados en el PR
del ticket de origen), en lo que queda de Tendencias. Si el usuario cambió de divisa principal y quedan
transacciones sin recalcular, estas gráficas suman su `amountInPreferredCurrency` tal cual, aunque se
guardara en la divisa anterior, y lo pintan con el símbolo de la actual.

Desde ese PR la vista agregada de Tendencias (total, curva y KPI) ya reconvierte. La vista por cuenta,
el histórico y la curva de saldo no: al pasar de una a otra, el mismo período puede dar números distintos.

## Dónde, medido el 2026-10-10 sobre `origin/2.1` (1c101c4a8) + el PR del ticket de origen

Ingreso y gasto, sin mirar `tx.preferredCurrencyCode`:

- `Yala/App/ViewModels/StatisticsViewModel.swift`, curvas por cuenta (`case .income` / `case .expense`
  del bucle por cuenta, `buckets[bucketDate, default: 0] += / -= adjustment.amountInPreferredCurrency(txn)`).
- `Yala/App/ViewModels/StatisticsViewModel.swift`, `historicalTotals` (`let amount = adjustment.amountInPreferredCurrency(tx)`).

Saldos acumulados, con el monto guardado CRUDO (sin `adjustment` ni divisa):

- `Yala/Services/TrendDataProcessor.swift`, `fillBalanceBuckets` (`runningBalance += transaction.amountInPreferredCurrency` y `+= txn.amountInPreferredCurrency`).
- `Yala/App/ViewModels/StatisticsViewModel.swift`, `case .balance` del bucle por cuenta (los dos `runningBalance +=`).

## Cómo se arregla

Ingreso y gasto, con `CashFlowCalculator.resolvedAmount(_:currencyCode:adjustment:converter:)`, como la
vista agregada. Los saldos acumulados son otra pregunta (saldo, no flujo): conviene decidir si
reconvierten con la tasa de su fecha o si se apoyan en `LiveBalanceCalculator`, y no mezclar las dos
cosas en el mismo cambio.

## Criterio de hecho

- [ ] Cada sitio de la lista resuelve el importe en la divisa vigente.
- [ ] Un test por superficie con dos filas de `preferredCurrencyCode` distinto, control rojo y mutante.
