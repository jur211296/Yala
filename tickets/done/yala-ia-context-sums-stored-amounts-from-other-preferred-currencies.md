---
id: yala-ia-context-sums-stored-amounts-from-other-preferred-currencies
status: done
priority: low
area: "currency, ai"
created: 2026-10-10
updated: 2026-10-11
source: barrido de stats-aggregators-sum-stored-amounts-from-other-preferred-currencies (2026-10-10)
---

# Yala IA recibe totales con importes guardados en otra divisa principal

## Qué le pasa al usuario

Las sugerencias del chat y, en un gasto de grupo, el contexto financiero que recibe Yala IA suman
`amountInPreferredCurrency` sin mirar en qué divisa principal se guardó. Tras cambiar de divisa con
filas sin recalcular, la IA ve totales con dos escalas y puede responder con números que no cuadran
con Estadísticas.

## Dónde, medido el 2026-10-10 sobre `origin/2.1` (1c101c4a8)

- `Yala/App/Services/ChatSuggestionsLLMService.swift:203`, `:205`, `:215`, `:223`, `:233`, `:247` — suman
  `abs(tx.amountInPreferredCurrency)` crudo, sin divisa ni `adjustment`.
- `Yala/Services/Chat/FullFinancialContextBuilder.swift:1062` y
  `Yala/Services/Chat/AnomalyDetectionCalculator.swift:135` (`convertAmount`) — solo en la pata real de
  un gasto de grupo (cuando el `adjustment` cambia el monto) devuelven `abs(adjusted)` en la escala
  guardada; el resto ya pasa por `chatAmount`, que sí mira la divisa.

## Cómo se arregla

`CashFlowCalculator.resolvedAmount` en los tres sitios. Ojo con el golden de paridad con el conector
(`MCPAppParityGoldenTests`): si el contexto cambia, el conector `mcp/` tiene que seguirlo.

## Criterio de hecho

- [x] Los tres sitios resuelven en la divisa vigente.
- [x] Test con dos filas de `preferredCurrencyCode` distinto, control rojo y mutante.

## Cierre (2026-10-11)

- Sugerencias del chat: las sumas del mes salen a `ChatSuggestionsLLMService.monthSums` y resuelven cada fila
  con `CashFlowCalculator.resolvedAmount` (`adjustment: .none`, como antes).
- Contexto y anomalías: solo la rama de la pata real de un gasto de grupo pasa a `resolvedAmount`; el resto
  sigue con `chatAmount`, que ya miraba la divisa. La réplica TS del conector (`mcp/src/logic/summary.ts`,
  `chatMagnitude`) hace lo mismo, con su test en `mcp/test/logic.test.ts`. El golden de paridad no se movió:
  no compara ese campo.
- Tests: `YalaTests/AIAndHealthPreferredCurrencyTests` (mezcla y una sola divisa por superficie), control
  rojo con la producción vieja y mutante «reconvierte siempre».
- Hallazgos con ticket propio: `chat-suggestions-context-counts-the-whole-group-expense` y
  `chat-top-transactions-per-subcategory-rank-by-native-amount`.
