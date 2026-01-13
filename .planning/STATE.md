# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 1 — Estabilidad Core

## Current Position

Phase: 1 of 8 (Estabilidad Core)
Plan: In progress
Status: Working on bugs
Last activity: 2026-01-13 — Fix saldo inicial en gráficas de tendencia

Progress: ░░░░░░░░░░ 5%

## Completed

- Refactor: Saldo inicial ahora es transacción (no propiedad de Account)
- Fix: Gráficas de tendencia se actualizan al cambiar saldo inicial
- Fix: SwiftData @Query detecta cambios en transacciones de saldo

## Next (Fase 1)

- Bug: Tipo de cambio en transferencias se resetea a 1.000 con teclado
- Bug: Hover CashFlow en Panel/Trends muestra colores incorrectos

## Risk/Notes

- SwiftData @Query no detecta modificaciones in-place; usar delete+insert
- Cadenas largas de .onChange pueden exceder límite del compilador; extraer a ViewModifiers
- Saldo inicial usa `balanceAdjustmentType = "initial_balance"` en TransactionItem
- Categoría seed "Otros/Ajustes de saldo" para transacciones de ajuste

## Session Continuity

Last session: 2026-01-13 16:15
Stopped at: Fase 1 bugs pendientes
Resume file: None
