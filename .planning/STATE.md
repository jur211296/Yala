# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 1 — Estabilidad Core

## Current Position

Phase: 1 of 8 (Estabilidad Core)
Plan: In progress
Status: Working on bugs
Last activity: 2026-01-13 — Fix bug de etiquetas (many-to-many relationship)

Progress: ██░░░░░░░░ 15%

## Completed

- Refactor: Saldo inicial ahora es transacción (no propiedad de Account)
- Fix: Gráficas de tendencia se actualizan al cambiar saldo inicial
- Fix: SwiftData @Query detecta cambios en transacciones de saldo
- Fix: Bug de etiquetas — múltiples transacciones pueden tener la misma etiqueta (many-to-many)

## Next (Fase 1)

- Bug: Hover CashFlow en Panel/Trends muestra colores incorrectos. Bug: Actualmente el hover muestra puntitos de colores que no son los colores de las barras/lineas. Añadir: leyenda debajo porque no está claro que el teal es ingreso, rosa egreso y morado saldo. Simple, similar a la de naturalezas. Esto en ambos lugares. Bug: El título siempre dice Flujo neto. Para PanelView esta bien, pero en TrendsTabView hay otros matices: Ahi tenemos un selector para ver un CashFlow por cada cuenta o por cada Moneda, entonces en lugar de Flujo neto deberia decir el nombre de la cuenta o el nombre de la moneda (nombre completo: dólar estadounidense, no diminutivo).
- KPIs de Tendencia de saldo de: PanelView, TrendsTabView y RecordsTabView no cuadran. Todos deben considerar todas las transacciones: saldo inicial, ajustes, gastos e ingresos. El ultimo punto de la grafica para el periodo seleccionado deberia ser el KPI. Las graficas siempre deben mostrar el saldo en ese momento, no el saldo del periodo seleccionado (para cuando no es "Todo el tiempo"). De esta manera el KPI sea cual sea el periodo denotara el saldo en dicho momento. 

## Risk/Notes

- SwiftData @Query no detecta modificaciones in-place; usar delete+insert
- Cadenas largas de .onChange pueden exceder límite del compilador; extraer a ViewModifiers
- Saldo inicial usa `balanceAdjustmentType = "initial_balance"` en TransactionItem
- Categoría seed "Otros/Ajustes de saldo" para transacciones de ajuste
- Tag ↔ TransactionItem require `@Relationship(inverse:)` para many-to-many correcto

## Session Continuity

Last session: 2026-01-13 17:19
Stopped at: Tag bug fixed, 2 bugs pendientes en Fase 1
Resume file: None
