# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 5.1 — Correcciones y Mejoras

## Current Position

Phase: 5.1 of 8 (Correcciones y Mejoras)
Plan: Not started
Status: Fase 5 cerrada, preparando correcciones y mejoras
Last activity: 2026-01-18 — Closed phase 5, created phase 5.1

Progress: ░░░░░░░░░░░░░░ 0% (Fase 5.1)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-18T17:26:00-05:00] d92b6ec feat: Enhance period comparison with vs-amount text and fix balance calculation
- [2026-01-16T17:58:53-05:00] 85fa1ac fix: Capitalize transaction type labels in segmented control
- [2026-01-16T17:23:35-05:00] b540af3 fix: Show category filter chip when clicking pie chart in PanelView
- [2026-01-16T17:23:35-05:00] 543690e feat: Add previous period calculations for nature widget
- [2026-01-16T17:23:35-05:00] ce7306c fix: Hide variation chips when period is All Time
- [2026-01-16T17:23:35-05:00] aafbf94 fix: Remove leading dot from variation chips and add showNAWhenNil parameter
- [2026-01-16T15:08:52-05:00] fb30c65 feat: Add period comparison variation (Var%) to statistics widgets
- [2026-01-16] 59de1fa fix: Move comparison selector outside carousel and fix filtering
- [2026-01-16] 8553e97 chore: Fix project path in command files

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

## Next Steps

- Planificar Fase 5.1 (Correcciones y Mejoras)
- Investigar cambio de relación FavoritePayment ↔ Tag (1:1 → N:N)

## Parking Lot

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography

## Session Continuity

Last session: 2026-01-18
Stopped at: Phase 5 closed, Phase 5.1 created
Next step: Plan and execute Phase 5.1 (Correcciones y Mejoras)
Resume file: None
