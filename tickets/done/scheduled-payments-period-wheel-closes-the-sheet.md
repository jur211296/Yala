---
id: scheduled-payments-period-wheel-closes-the-sheet
status: backlog
priority: low
area: "scheduled-payments, ui"
created: 2026-10-17
updated: 2026-10-17
source: "implementación UX 2.2 · lote 9 (L9-8, mismo patrón fuera del lote)"
---

# El selector de período de Pagos planificados usa la rueda propia que se cierra al arrastrar

L9-8 cambió los dos selectores de período de Presupuestos (lista y gráficas) a la rueda nativa de iOS: la propia vivía en un `ScrollView` dentro de una hoja a media altura, arrastrar hacia abajo cerraba la hoja y sus franjas de degradado se veían como bandas oscuras. `ScheduledPaymentPeriodSelectorSheet.swift` es la misma rueda (mismo `PeriodOption`, mismos `LinearGradient`) y no se tocó: es de Pagos planificados, fuera del lote 9.

## Hecho cuando

Pagos planificados elige período con `BudgetPeriodWheelSheet` (o la misma rueda nativa) y arrastrar la rueda no cierra la hoja.
