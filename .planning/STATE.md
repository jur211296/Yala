# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 5.1 — Correcciones y Mejoras

## Current Position

Phase: 5.1 of 8 (Correcciones y Mejoras)
Plan: In progress
Status: Gráficas de ingresos completas - última tarea grande de Fase 5.1
Last activity: 2026-01-19 — Gráficas de ingresos con selector unificado, widgets adaptativos, localizaciones

Progress: ████████░░░░░░ 60% (Fase 5.1)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-19T09:17:00-05:00] 45b9a69 feat(income): Add dynamic title, teal color, and dimming for income mode
- [2026-01-19T08:26:00-05:00] abe34ae feat(statistics): Hide nature widgets and category chart in income mode
- [2026-01-19T08:21:00-05:00] 4b9b8ca feat(panel): Widgets respect income/expense filter
- [2026-01-19T08:11:00-05:00] 92d78a7 feat(statistics): CategoriesTabView respects income/expense filter
- [2026-01-19T08:04:00-05:00] 4fdd604 feat(calculators): Add transactionNatures parameter for income support
- [2026-01-19T07:58:00-05:00] d5369bc feat(charts): Unify metric selector with chip filter system
- [2026-01-19T06:55:00-05:00] 7f90398 fix(filters): Complete income/expense filter sync and UX improvements
- [2026-01-18T21:30:00-05:00] d7b0b55 feat(filters): Add income/expense filter chips in Statistics
- [2026-01-18T20:52:00-05:00] 5e10a22 feat(ux): Auto-focus name field on remaining creation forms
- [2026-01-18T20:45:00-05:00] 0fc1085 feat(ux): Auto-focus name field on creation forms

## Completed in Current Phase

- **Var% vs periodo anterior completo** - Pie charts, Top widgets, listas, CashFlow cards, Nature widget; selector M/A; chips inline alineados derecha; oculto para All Time
- **"vs [amount]" en KPI** - Todas las cards muestran monto del periodo anterior al lado del KPI
- **"vs [period]" debajo de chips** - Texto de periodo de comparación debajo de variation chips
- **Balance calculation fix** - PanelView ahora calcula balance correctamente (igual que TrendsTabView)
- **Variation chip colors** - Colores corregidos para contexto de gastos (+% pink, -% purple)
- **Carrusel naturaleza con variación** - Widget compacto con Var% por naturaleza, dimming visual
- **Migración Design System (DS tokens)** completa en todas las vistas
  - Panel/: PanelView, widgets, AccountCardView
  - Statistics/: TrendsTabView, RecordsTabView, CategoriesTabView, DetailContainerView
  - Settings/: Todas las vistas de configuración
  - Records/: RecordsFiltersView, RecordRowView
  - Transactions/: NewTransactionView, SelectionChip
  - Shared/: NetoEmptyState, NetoBadge, StandardButtons, NetoLoadingOverlay, SectionBox, CurrencySelectorView, IconColorPickerSheet, SkeletonView
  - Planning/: PlanningView
  - Profile/: ProfileView
  - Tags/: TagFormView
  - Filters/: FilterChipsSection, FilterControlBar
- **Pie chart de etiquetas** en carrusel CategoriesTabView (tercer slide)
- **Tags con iconos y colores editables** (IconColorPickerSheet)
- **Paleta de 15 colores únicos** para nuevos tags (nunca negro)
- **Import asigna colores únicos** a tags nuevos
- **Interactividad del pie**: click filtra todas las vistas
- **Filter chips muestran icono** del tag (no solo color)
- **Lista de tags con iconos** en ProfileView (no puntos)
- **Migración SwiftData** con valor por defecto para iconName
- **Tooltip dinámico en gráficas** - Posición arriba/abajo según altura del punto (evita clipping)
- **Keyboard dismiss en formularios** - Tap fuera, scroll, sheets/NavigationLinks cierran teclado correctamente
- **Filas clickables con Button** - categoriesContent en filtros convertido de onTapGesture a Button
- **Auto-focus completo** - Todos los formularios de creación con auto-focus en campo nombre
- **Filtro Ingresos/Gastos completo** - Chips inline, sincronización bidireccional SessionState, totales clicables en RecordsTabView con dimming, chip visible en PanelView
- **Gráficas de ingresos completas** - Selector unificado (chip = fuente de verdad), calculadores parametrizados, CategoriesTabView adapta pie charts y lista, PanelView widgets adaptativos, NatureTrendWidget muestra mensaje en modo ingresos, CashFlowWidget con color teal y dimming, título dinámico "Análisis del ingreso", localizaciones completas (6 idiomas)

## Next Steps

### Otras tareas
- Importación multimoneda
- Investigar cambio de relación FavoritePayment ↔ Tag (1:1 → N:N)
- Optimizar cálculos en gráficas

## Parking Lot

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography

## Session Continuity

Last session: 2026-01-19
Stopped at: Filtro Ingresos/Gastos completo con sincronización
Next step: Estudiar enfoque para gráficas de ingresos (última tarea grande de Fase 5.1)
Resume file: None
