---
id: chat-top-transactions-per-subcategory-rank-by-native-amount
status: backlog
priority: very-low
area: "ai, currency"
created: 2026-10-11
updated: 2026-10-11
source: review adversarial de yala-ia-context-sums-stored-amounts-from-other-preferred-currencies (2026-10-11)
---

# Los movimientos destacados por subcategoría del contexto de Yala IA se eligen por el importe nativo

## Qué le pasa al usuario

El contexto que recibe Yala IA lleva, por subcategoría, sus 10 movimientos más grandes
(`top_tx_by_subcategory`). Se eligen ordenando por el importe NATIVO, sin convertir. Con cuentas en
varias divisas, un gasto de 100 USD (≈ S/ 370) queda por detrás de uno de S/ 150, y si la subcategoría
tiene más de 10 movimientos puede quedarse fuera aunque sea el mayor. El importe que se manda de cada
uno sí está convertido; lo que falla es cuáles entran y en qué orden.

## Dónde, medido el 2026-10-11

`Yala/Services/Chat/FullFinancialContextBuilder.swift`, `buildTopTxBySubcategory`:
`.sorted { abs(adjustment.amount($0)) > abs(adjustment.amount($1)) }` antes del `.prefix(10)`.

## Cómo se arregla

Ordenar por `convertAmount(tx, currencyCode:converter:adjustment:)`, el mismo importe que se manda.
Ojo con el golden de paridad con el conector `mcp/` si replica ese orden.

## Criterio de hecho

- [ ] El orden usa el importe en la divisa principal.
- [ ] Test con dos divisas nativas donde el orden nativo y el convertido difieren.
