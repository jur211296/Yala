---
id: yala-ia-classifies-uncategorized-movements-as-expense
status: done
priority: low
area: "yala-ia, mcp"
created: 2026-10-23
updated: 2026-10-29
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

## Hecho (2026-10-29)

- **Yala IA**: el contexto del chat (`FullFinancialContextBuilder`), las anomalías, las áreas de temas y las sugerencias
  deciden con `TransactionClassificationLogic`. El gasto sin categoría aparece en «Other» de categorías, comercios,
  necesidades («sin clasificar»), historial y en la línea base de anomalías; el ingreso sin categoría, en «Other» de
  `income_categories` y en los ingresos de las sugerencias. El bucket `uncategorized` es solo gasto.
- **Conector**: `buscar_movimientos` da `ingreso`/`gasto` por la misma regla (`txKindOf`, sin `sin_categoria`; `categoria:
  null` lo sigue diciendo). Una pata de transferencia con `balance_adjustment_type = "transfer"` sale `transferencia`
  (antes, `ajuste_de_saldo`).
- **Golden**: gana `kinds` (el `tipo` de cada movimiento, calculado por la app) y el escenario de la tarjeta, un ingreso
  sin categoría y una transferencia con la forma real. Regenerado.
- **Tests**: `YalaIAUncategorizedClassificationTests` (8 casos, uno de cada signo; con el código viejo, los 8 en rojo) y
  `txKindOf` en `mcp/test/logic.test.ts` (con el `tipo` viejo, rojo también el golden).
- **Fuera**: «Presupuestos en riesgo» de Observaciones (`InsightsCalculator`, ticket propio) y
  `ChatUnsignedExpenseRepairLogic`, que deja fuera lo sin categoría a propósito.
