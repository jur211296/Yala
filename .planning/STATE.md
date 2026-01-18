# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 5 — Visualizaciones Categorías

## Current Position

Phase: 5 of 8 (Visualizaciones Categorías)
Plan: In progress
Status: Var% completo en todas las vistas, balance fix aplicado
Last activity: 2026-01-18 — Enhanced period comparison with vs-amount text

Progress: █████████████░ 90% (Fase 5)

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

- Revisar y cerrar fase 5 (Visualizaciones Categorías)
- Considerar items del Parking Lot antes de fase 6

## Parking Lot

- [2026-01-18] [Improvement] [UI/UX + Business Logic] [Medium]: Importación multimoneda con asignación de cuenta por divisa
  Contexto: Actualmente el importador fuerza elegir una única cuenta (una moneda). Permitir que al cargar archivo con múltiples monedas (ej: PEN y USD), el usuario asigne cada divisa a su cuenta correspondiente.
  Dependencias: Ya existe detección de moneda y validaciones, hay que adecuar el flujo de selección de cuenta.

- [2026-01-18] [Bug] [UI/UX] [High]: Etiqueta de hover en gráficas se corta cuando el punto está muy arriba
  Contexto: En PanelView y TrendsTabView, cuando el punto de la gráfica está cerca del borde superior, la etiqueta se recorta para no invadir el título
  Afecta: TrendChartView (usado en PanelView y TrendsTabView)
  Solución: Hacer que la etiqueta se sobreponga a todo (zIndex) o que se desplace hacia abajo dinámicamente

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography

## Session Continuity

Last session: 2026-01-18
Stopped at: Period comparison enhancements complete
Next step: Review phase 5 completion or address Parking Lot items
Resume file: None
