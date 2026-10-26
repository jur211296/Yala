---
id: panel-pies-amount-filter-uses-signed-amount
status: backlog
priority: medium
area: "panel, filters"
created: 2026-10-26
updated: 2026-10-26
source: "review adversarial de stats-filter-segment-tap-should-ask-include-or-exclude (2026-10-26), medido en el código"
---

# Con un filtro de importe, las tartas del Panel dejan fuera los gastos que Registros sí cuenta

## Qué pasa (experiencia)

Con «Importe mayor que 100» puesto, un gasto de 150 sale en Registros y en Estadísticas pero no en las tartas y los tops
del Panel. Las mismas cifras del mismo filtro no cuadran entre pantallas.

## Medido

- `PanelViewModel.buildPieContextTransactions` compara el importe CON SIGNO: `amountCondition.matches(Decimal(transaction.amount))`.
  Un gasto es negativo, así que «mayor que 100» nunca lo deja pasar.
- `FilterService.matchesCriteria`, que usan Registros, Estadísticas e Informe, compara el valor ABSOLUTO
  (`criteria.amountCondition.matches(abs(amount))`).
- Preexistente: no lo introdujo el cambio de incluidos/excluidos. Salió al revisar el cálculo de las tartas del Panel.

## Arreglo propuesto

Comparar `abs` también en el Panel (la regla de `FilterService`) y fijarlo en `CombinedFiltersScreenParityTests` con un
caso de importe.
