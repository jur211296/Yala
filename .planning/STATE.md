# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 2 — Periodos y Filtros

## Current Position

Phase: 2 of 8 (Periodos y Filtros)
Plan: In progress
Status: 3/4 items done
Last activity: 2026-01-14 — Sincronización completa de filtros

Progress: ███████░░░ 70%

## Completed (Fase 2)

- Periodo Personalizado en PeriodSelector (CustomPeriodPickerSheet, sincronización global, persistencia UserDefaults)
- Sincronización de filtros Statistics/Panel (Tags, Currency, Amount, Note + chips en todas las vistas)
- Filtro por nota: chips de búsqueda (searchText sincronizado, chip visible, filtrado aplicado)

## Pending (Fase 2)

- Filtro categorías aplica a gráficas

## Completed (Fase 1)

- Fix: Saldo inicial ahora es transacción (no propiedad de Account)
- Fix: Leyenda centrada en CashFlowWidget (Ingreso/Egreso/Flujo neto)
- Fix: Colores hover del tooltip coinciden con barras/líneas
- Fix: Título dinámico en TrendsTabView (cuenta/moneda)
- Fix: Carruseles ordenados por Profile y monto
- Fix: Crash en TrendDataProcessor (DateInterval validation)
- Fix: Bug tipo de cambio en transferencias

## Risk/Notes

- Orden de cuentas usa `@AppStorage("accountsSortOrderNames")`
- DateInterval crash si start > end; siempre validar (fix aplicado en CustomPeriodPickerSheet)
- customTitle en CashFlowWidget tiene prioridad sobre displayMode
- RecordsTabView usa @Query sin filtro para límites del DatePicker
- PanelSessionObservers extrae onChange para evitar límite del type-checker

## Session Continuity

Last session: 2026-01-14 08:40
Stopped at: Sincronización de filtros completada
Resume file: None
