---
id: yala-ia-classifies-uncategorized-movements-as-expense
status: backlog
priority: low
area: "yala-ia, mcp"
created: 2026-10-23
updated: 2026-10-23
source: "encargo 2026-10-23-cifras-distintas-mismo-dinero-2-2 (card vl1q)"
---

# Yala IA y el conector de Claude no siguen la regla de ingreso/gasto de la app

La app decide ingreso o gasto con `TransactionClassificationLogic` (sin categoría, el signo) desde el 2026-10-23. El
contexto de Yala IA no: `FullFinancialContextBuilder` filtra con `category?.isIncome == false` / `!= true` / `== true`
en una docena de sitios (gasto del mes, comparativas, anomalías, ingresos), y lo mismo `AnomalyDetectionCalculator`,
`ChatTopicAreasLogic` y `ChatSuggestionsLLMService`. Un gasto sin categoría cuenta como gasto en unos sitios y no
existe en otros, y un ingreso sin categoría se pierde. El conector `mcp/` porta el builder
(`MCPAppParityGoldenTests`), así que se cambian los dos y se regenera el golden.

**Ya alineado el 2026-10-23**: los totales de periodo del chat (salen de `CashFlowCalculator`) y lo gastado de los
presupuestos (`BudgetsViewModel.calculateSpending`), con su port en `mcp/src/logic/summary.ts` y `budgets.ts` y el golden
regenerado. Queda lo que el builder filtra por su cuenta (gasto del mes por categoría, comparativas, anomalías,
ingresos recurrentes, sugerencias) y el `tipo` de `buscar_movimientos` del conector, que sigue diciendo `sin_categoria`.

## Hecho cuando

Yala IA y el conector clasifican con la regla de la app, con el golden regenerado y un caso sin categoría de cada signo.
