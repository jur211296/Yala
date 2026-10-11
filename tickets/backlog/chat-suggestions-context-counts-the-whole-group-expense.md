---
id: chat-suggestions-context-counts-the-whole-group-expense
status: backlog
priority: low
area: "ai, groups"
created: 2026-10-11
updated: 2026-10-11
source: hallazgo de yala-ia-context-sums-stored-amounts-from-other-preferred-currencies (2026-10-11)
---

# Las sugerencias del chat cuentan el gasto de grupo entero y el préstamo como ingreso

## Qué le pasa al usuario

Las sugerencias del chat se generan con un resumen del mes («Month income», «Month expenses» y los
rankings de categorías, comercios y etiquetas). Ese resumen no aplica el ajuste de gastos de grupo que
usan Estadísticas y el contexto del chat (`GroupBridgeStatsAdjustment`): si pagué una cena de grupo de
S/ 300 de la que me tocan S/ 100, el resumen suma S/ 300 de gasto y la pata de préstamo (+S/ 200) como
ingreso. Tampoco sigue el interruptor «Grupos en el total». La IA recibe totales que no cuadran con el
Panel y puede sugerir preguntas sobre un gasto inflado.

Es menor: el resumen solo orienta las sugerencias, no es una cifra que se enseñe.

## Dónde, medido el 2026-10-11

`Yala/App/Services/ChatSuggestionsLLMService.swift`, `monthSums(_:tagCatalog:currencyCode:converter:)`:
resuelve cada fila con `CashFlowCalculator.resolvedAmount(..., adjustment: .none, ...)` y no filtra las
patas suprimidas. El fetch de `buildContext` tampoco pasa por `BridgedTransactionFilter`.

## Cómo se arregla

Construir el ajuste con `GroupBridgeStatsAdjustment.build(from:context:)` sobre las filas del mes, pasarlo
a `monthSums`, saltar `adjustment.isSuppressed` y aplicar el interruptor de grupos como el Panel.

## Criterio de hecho

- [ ] Un gasto de grupo Caso A suma «mi parte» y su préstamo no cuenta como ingreso.
- [ ] Test con la pareja de patas, control rojo con `adjustment: .none`.
