---
id: yala-ia-context-sums-stored-amounts-from-other-preferred-currencies
status: backlog
priority: low
area: "currency, ai"
created: 2026-10-10
updated: 2026-10-10
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

- [ ] Los tres sitios resuelven en la divisa vigente.
- [ ] Test con dos filas de `preferredCurrencyCode` distinto, control rojo y mutante.
