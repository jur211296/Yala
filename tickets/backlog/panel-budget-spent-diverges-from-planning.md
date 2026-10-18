---
id: panel-budget-spent-diverges-from-planning
status: backlog
priority: medium
area: "budgets, panel"
created: 2026-10-17
updated: 2026-10-17
source: "review adversarial del lote 9 de la auditoría UX 2.2"
---

# La tarjeta de Presupuestos del Panel y Planificación pueden decir distinto lo que queda

Medido por la review adversarial del lote 9 (2026-10-17), anterior al lote: `PanelViewModel.calculateBudgetSummary` no filtra lo que sí filtra `BudgetsViewModel.filterTransactions`: los ajustes de saldo (`balanceAdjustmentType`), «Contar mi parte de los gastos de grupo» (`includeSharedExpenses`) y la parte neta de los gastos de grupo (`GroupBridgeStatsAdjustment`). Un presupuesto sin filtros cuenta un ajuste de saldo como gasto en el Panel y no en Planificación, así que «Te quedan» sale distinto en las dos pantallas. La vista previa de Perfil › Presupuestos usa el cálculo de Planificación.

## Hecho cuando

El Panel calcula lo gastado con la misma función que Planificación, con un test que compare las dos cifras para el mismo presupuesto.
