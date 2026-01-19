# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 6 — Pagos Planificados

## Current Position

Phase: 6 of 8 (Pagos Planificados)
Plan: In progress (Mini-Fase 6.3+ completada)
Status: Suscripciones con calendario, campos requeridos, iconos subcategoría, fix parpadeo
Last activity: 2026-01-19 — Subscriptions calendar view, UX improvements

Progress: ██████░░░░░░░░ 50% (Fase 6)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-19T17:05:00-05:00] 1937184 feat(scheduled): Add subscriptions calendar view and UX improvements
- [2026-01-19T16:45:00-05:00] b40ccf3 feat(scheduled): Add settings view in Profile for payment management
- [2026-01-19T16:44:00-05:00] f06a17f feat(scheduled): Add detail view with payment history
- [2026-01-19T16:43:00-05:00] 91b2a0b feat(scheduled): Redesign recurrence with one-time/recurring toggle
- [2026-01-19T16:30:00-05:00] db09829 feat(i18n): Add scheduled payments localizations for 6 languages
- [2026-01-19T15:02:00-05:00] dc488b5 feat(scheduled): Add scheduled payments UI with CRUD and filters
- [2026-01-19T14:42:00-05:00] ab9c874 feat(scheduled): Add ScheduledPayment model and supporting enums
- [2026-01-19T09:17:00-05:00] 45b9a69 feat(income): Add dynamic title, teal color, and dimming for income mode
- [2026-01-19T08:26:00-05:00] abe34ae feat(statistics): Hide nature widgets and category chart in income mode
- [2026-01-19T08:21:00-05:00] 4b9b8ca feat(panel): Widgets respect income/expense filter

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
- **Importación multimoneda** - Auto-detecta monedas en CSV, permite asignar cuenta por divisa, fix parsing de campos con newlines embebidos
- **Primer día de semana** - Nueva preferencia en Personalización (Domingo/Lunes)
- **FavoritePayment ↔ Tag N:N** - Relación muchos-a-muchos correcta con @Relationship(inverse:), fix DataWipeService
- **Optimización de cálculos** - N+1 queries eliminados en TrendsTabView, TagSpendingCalculator extraído como servicio, recordsSummary cacheado en ViewModel, onChange handlers consolidados

## Next Steps

### Fase 6: Pagos Planificados
- ~~Diseñar modelo ScheduledPayment (SwiftData)~~ ✅
- ~~CRUD de pagos planificados con SegmentedControl~~ ✅
- ~~Vista detalle con historial de pagos~~ ✅
- ~~Vista de gestión en Perfil~~ ✅
- ~~Rediseño de recurrencia (one-time/recurring toggle)~~ ✅
- ~~Suscripciones con calendario interactivo~~ ✅
- ~~Campos requeridos (cuenta, subcategoría, nombre, monto)~~ ✅
- ~~Iconos/colores de subcategoría en listas~~ ✅
- ~~Fix parpadeo de título en navegación~~ ✅
- Widget Medium: 3 pagos siguientes
- Widget Large: calendario por periodo
- Notificaciones push (UNNotificationCenter)

## Parking Lot

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-01-19
Stopped at: Fase 5.1 completada - optimización de cálculos
Next step: Iniciar Fase 6 (Pagos Planificados)
Resume file: None
