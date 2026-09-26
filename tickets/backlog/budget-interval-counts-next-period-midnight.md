---
id: budget-interval-counts-next-period-midnight
status: backlog
priority: medium
area: budgets
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (hallazgo al portar el cálculo de presupuestos)
---

# Un gasto del día 1 a medianoche cuenta en el presupuesto del mes anterior

## Qué cambia para el usuario

Si apuntas un gasto el 1 de octubre sin hora (el selector de fecha lo guarda a las 00:00), la app lo suma al
presupuesto de octubre **y también al de septiembre** cuando miras septiembre. Lo mismo con los semanales y el
lunes siguiente, y con los anuales y el 1 de enero.

## Qué se midió (por lectura del código, sin ejecutar)

Es el patrón de «Cálculos con fechas» del `CLAUDE.md`: `DateInterval` es cerrado en los dos extremos, y estos tres
sitios construyen el periodo con `end` = inicio del periodo siguiente, sin restar el segundo:

- `BudgetsViewModel.getBudgetDateInterval` (`Yala/App/ViewModels/BudgetsViewModel.swift:705`), que alimenta el
  gasto, la curva acumulada y el desglose por categoría de la pantalla de Presupuestos.
- `PanelViewModel.getBudgetDateInterval` (`Yala/App/ViewModels/PanelViewModel.swift:2453`).
- `InsightsCalculator.currentBudgetInterval` (`Yala/App/Logic/Calculators/InsightsCalculator.swift:565`), que usa
  también el chat (`FullFinancialContextBuilder.buildBudgets`).

`BudgetsViewModel.filterTransactions` filtra con `interval.contains($0.date)` (`:546`), así que el instante
`end` entra. En el periodo en curso casi no se nota —ese instante es futuro, y el chat además excluye lo futuro—;
en un periodo pasado, sí.

El conector de Claude (`mcp/src/logic/budgets.ts`) ya cuenta por días inclusivos y no tiene el problema.

## Qué hay que hacer

Restar un segundo al `end` en las ramas semanal, mensual y anual de los tres sitios, con un test por rama con una
transacción a las 00:00 del primer día del periodo siguiente. El caso «único» usa las fechas del presupuesto y
hay que mirar si `endDate` se guarda a medianoche antes de tocarlo.
