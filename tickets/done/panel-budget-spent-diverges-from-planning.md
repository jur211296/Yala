---
id: panel-budget-spent-diverges-from-planning
status: done
priority: medium
area: "budgets, panel"
created: 2026-10-17
updated: 2026-10-23
source: "review adversarial del lote 9 de la auditoría UX 2.2"
implementation_date: 2026-10-23
qa-date: 2026-10-23
qa-notes: cerrado con PanelBudgetPlanningParityTests y su mutante muerto
---

# La tarjeta de Presupuestos del Panel y Planificación pueden decir distinto lo que queda

Medido por la review adversarial del lote 9 (2026-10-17), anterior al lote: `PanelViewModel.calculateBudgetSummary` no filtra lo que sí filtra `BudgetsViewModel.filterTransactions`: los ajustes de saldo (`balanceAdjustmentType`), «Contar mi parte de los gastos de grupo» (`includeSharedExpenses`) y la parte neta de los gastos de grupo (`GroupBridgeStatsAdjustment`). Un presupuesto sin filtros cuenta un ajuste de saldo como gasto en el Panel y no en Planificación, así que «Te quedan» sale distinto en las dos pantallas. La vista previa de Perfil › Presupuestos usa el cálculo de Planificación.

## Hecho cuando

El Panel calcula lo gastado con la misma función que Planificación, con un test que compare las dos cifras para el mismo presupuesto.

## Implementación (2026-10-23, card 7ld8)

`PanelViewModel.calculateBudgetSummary` calcula lo gastado con `BudgetsViewModel.calculateSpending` (la de
Planificación, la vista previa de Perfil y las alertas) y el `statsAdjustment` del Panel: ya no cuenta ajustes de saldo,
respeta «Contar mi parte de los gastos de grupo» y netea la parte de los gastos de grupo. Se quitó el filtro de
categorías excluidas de la sesión que solo aplicaba el Panel (Planificación no lo mira). Test:
`PanelBudgetPlanningParityTests` (fixture discriminante: 1.000 con el cálculo viejo, 240 con el nuevo, + source-scan).
Fuera: «Presupuestos en riesgo» de Observaciones (`insights-budgets-at-risk-compute-spent-on-their-own`).

Cerrado en el barrido de QA 2026-10-23: test de integración contra el código real, con sus mutantes muertos (caso 3 del barrido). Registro: `docs/qa/tanda-qa-jurgen-2.2-cifras.md`.
