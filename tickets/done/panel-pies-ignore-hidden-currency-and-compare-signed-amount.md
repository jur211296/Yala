---
id: panel-pies-ignore-hidden-currency-and-compare-signed-amount
status: done
priority: medium
area: "panel, filters"
created: 2026-10-25
updated: 2026-10-28
source: "review adversarial del lote 12.5 (2026-10-25), leído en el código, sin medir en pantalla"
---

# Las tartas del Panel tratan «Ocultar» una moneda como «Mostrar solo» y comparan el monto con signo

## Qué pasa (leído en `2.2`, sin medir)

`PanelViewModel.buildPieContextTransactions` (`PanelViewModel.swift`, filtro de moneda y de monto, ~`:1589-1600`):

1. El filtro de moneda siempre es «solo estas»: con «Ocultar PEN» las tartas enseñan **solo** PEN, lo contrario de lo
   que pide el filtro y de lo que hacen Registros y Estadísticas (`FilterService.matchesEntityFilter` respeta el modo).
2. El monto se compara con signo (`amountCondition.matches(Decimal(transaction.amount))`): los gastos son negativos, así
   que «Mayor a 100» vacía las tartas de gasto y «Menor a 100» deja pasar todos los gastos. `FilterService` compara el
   valor absoluto.

## Qué hacer

Medirlo en el simulador (Registros › Filtros › Ocultar PEN + monto, y mirar las tartas del Panel). Si se confirma, que
las tartas filtren con `FilterService` (o con su misma regla), con un test de paridad Panel ↔ Registros que traiga una
fila de cada moneda y un gasto por encima y por debajo del monto.

## Resolución (2026-10-28, lote panel-filtros-moneda)

1. **«Ocultar» moneda: ya estaba arreglado** cuando se abrió la card. El filtro de moneda del Panel pasó a
   `EntityFilter(included:excluded:)` en c5e2c1a89 (incluidos y excluidos, 2026-10-25/26). Se fija con
   `PanelPiesFilterParityTests` («Ocultar PEN» y «Solo PEN» + monto, tartas = Registros).
2. **Monto con signo: arreglado** con la regla única sin signo (ver `panel-pies-amount-filter-uses-signed-amount`).
