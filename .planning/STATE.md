# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 4 — Panel y Navegación

## Current Position

Phase: 4 of 8 (Panel y Navegación)
Plan: In progress
Status: 1/3 items done
Last activity: 2026-01-15 — Localización completa de la app

Progress: ███░░░░░░░ 33%

## Pending (Fase 4)

- Widget de Presupuestos en PanelView
- Home configurable (tabs desde personalización)

## Completed (Fase 4)

- Chevron en widgets para redirigir a detalle (SessionState.navigateToDetail, 7 widgets conectados)

## i18n (Trabajo paralelo completado)

- Localización completa ES/EN de toda la app
- Fechas con AppLocale.current (no hardcoded "es")
- Nombres de moneda localizados (currencyInfo → L10n.Currency.*)
- Tipos de cuenta con localizedName
- Formularios de cuentas, tags, categorías localizados
- SearchView, Statistics, RecordsTabView localizados
- Chips de filtros y secciones localizadas

## Bug Fixes (Sesión actual)

- Fix: Animación suave al mostrar pantalla de éxito en transacciones (transition opacity + scale)
- Fix: Crash al acceder categoría eliminada (cascade delete en Category.swift)
- Fix: Posición incorrecta de pantalla éxito con teclado abierto (dismiss + delay 150ms)
- Fix: Teclado se cierra al abrir selectores de cuenta/categoría/tags en NewTransactionView
- Fix: Widgets de gastos en Panel excluyen ajustes y saldos iniciales (expenseFilteredTransactions)
- Fix: TagSelectorSheet permite crear etiquetas + diseño mejorado de filas
- Fix: "Crear otra transacción" tras editar no precarga datos (isCreatingAnother flag)
- Fix: ImportAccountPickerSheet dark mode (fondo negro → netoCard con ScrollView)
- Fix: FavoriteRowView ancho completo (.frame(maxWidth: .infinity))
- Fix: CashFlow eje en TrendsTabView usa intervalo efectivo basado en transacciones reales
- Fix: Crash al vaciar datos (SessionState.isWipingData + TabView unmount durante wipe)

## Completed (Fase 3) ✅

- Eliminación sin transacciones (botón eliminar con validación de transacciones asociadas)
- Transferencia de transacciones al eliminar (sheet con 3 opciones: transferir a específica, mover a Sin asignar, eliminar transacciones)
- Edición masiva de categorías/subcategorías (modo editar con botones delete en CategoriesSettingsListView y CategoryDetailView)

## Completed (Fase 2) ✅

- Periodo Personalizado en PeriodSelector (CustomPeriodPickerSheet, sincronización global, persistencia UserDefaults)
- Sincronización de filtros Statistics/Panel (Tags, Currency, Amount, Note + chips en todas las vistas)
- Filtro por nota: chips de búsqueda (searchText sincronizado, chip visible, filtrado aplicado)
- Fix: Chips subcategoría/categoría ahora aparecen correctamente en todas las vistas
- Fix: "Seleccionar todo" en CategorySelectorSheet funciona correctamente
- Fix: Resumen de categorías muestra "Todas" cuando todo seleccionado
- Fix: Selección manual de subcategorías funciona sin comportamiento inesperado

## Completed (Fase 1) ✅

- Fix: Saldo inicial ahora es transacción (no propiedad de Account)
- Fix: Leyenda centrada en CashFlowWidget (Ingreso/Egreso/Flujo neto)
- Fix: Colores hover del tooltip coinciden con barras/líneas
- Fix: Título dinámico en TrendsTabView (cuenta/moneda)
- Fix: Carruseles ordenados por Profile y monto
- Fix: Crash en TrendDataProcessor (DateInterval validation)
- Fix: Bug tipo de cambio en transferencias

## Risk/Notes

- Orden de cuentas usa `@AppStorage("accountsSortOrderNames")`
- DateInterval crash si start > end; siempre validar
- customTitle en CashFlowWidget tiene prioridad sobre displayMode
- Anti-loop flags (`isSyncingFilters`, `isSyncingState`) previenen ciclos de sincronización
- `SessionState.shared` controla navegación entre tabs (selectedMainTab, selectedDetailTab)

## Session Continuity

Last session: 2026-01-15 06:45
Stopped at: i18n completo, listo para continuar Fase 4
Resume file: None
