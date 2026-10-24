---
id: insights-budgets-at-risk-compute-spent-on-their-own
status: backlog
priority: low
area: "presupuestos, estadisticas"
created: 2026-10-23
updated: 2026-10-23
source: "encargo 2026-10-23-cifras-distintas-mismo-dinero-2-2 (card 7ld8)"
---

# «Presupuestos en riesgo» de Observaciones calcula lo gastado por su cuenta

Desde el 2026-10-23 Planificación, la vista previa de Perfil, las alertas y la tarjeta del Panel calculan lo gastado
de un presupuesto con `BudgetsViewModel.calculateSpending`. Observaciones no:
`InsightsCalculator.calculateCommitments` solo mira presupuestos con la categoría legada (`budget.category`; los
presupuestos por subcategorías, etiquetas o cuentas no salen), filtra por categoría, no aplica «Contar mi parte de los
gastos de grupo» y suma sobre el conjunto ya filtrado de Estadísticas. El porcentaje de uso puede no coincidir con
Planificación.

## Hecho cuando

Observaciones enseña el porcentaje de cada presupuesto con la misma función que Planificación, sobre los movimientos sin
el filtro de sesión, con un test de paridad.
