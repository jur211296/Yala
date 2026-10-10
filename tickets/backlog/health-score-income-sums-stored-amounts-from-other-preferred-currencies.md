---
id: health-score-income-sums-stored-amounts-from-other-preferred-currencies
status: backlog
priority: low
area: currency
created: 2026-10-10
updated: 2026-10-10
source: barrido de stats-aggregators-sum-stored-amounts-from-other-preferred-currencies (2026-10-10)
---

# La salud financiera suma el ingreso guardado en otra divisa principal

## Qué le pasa al usuario

El ingreso del período con el que se calcula la puntuación de salud financiera suma
`amountInPreferredCurrency` sin mirar en qué divisa principal se guardó. Tras cambiar de divisa con
filas sin recalcular, la puntuación sale de dos escalas mezcladas. No se ve un importe, pero el
número de la puntuación cambia.

## Dónde, medido el 2026-10-10 sobre `origin/2.1` (1c101c4a8)

- `Yala/App/Logic/Calculators/FinancialScoreCalculator.swift:510` — `.reduce(0) { $0 + abs(adjustment.amountInPreferredCurrency($1)) }`.

`InsightsCalculator` NO tiene el bug: su `convertedAmount` solo usa el monto guardado si
`preferredCode == toCode` (`:492`).

## Cómo se arregla

`CashFlowCalculator.resolvedAmount` con la divisa principal; el calculador necesita recibirla y un
converter.

## Criterio de hecho

- [ ] El ingreso de la puntuación se resuelve en la divisa vigente.
- [ ] Test con dos filas de `preferredCurrencyCode` distinto, control rojo y mutante.
