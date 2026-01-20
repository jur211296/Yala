# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 7 — Beta Preparation (V1.0 Release)

## Current Position

Version: 1.0 (preparando release)
Phase: 7 of 7 en V1.0 (Beta Preparation)
Spec: .planning/PHASE7-BETAPREP-SPEC.md
Plan: Not started
Status: Features V1.0 completas, preparando para TestFlight beta pública
Last activity: 2026-01-20 — Reorganización de roadmap (V1.0 vs V1.1)

Progress: ████░░░░░░░░░░ 25% (Fase 7 - Subfases 7.1, 7.2 completadas)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-20T07:05:00-05:00] c0e407a chore(cleanup): remove TODOs, dead code, and legacy FIN-XX references
- [2026-01-19T20:55:00-05:00] 0083534 docs(state): Mark Phase 6 as complete, set Phase 7 as next
- [2026-01-19T20:44:00-05:00] 30b2a94 refactor(widget): Scheduled payments widget with 3 variants in preferences
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

- **Subfase 7.1: Code Quality & Cleanup** - TODOs eliminados, código muerto limpiado, referencias legacy (FIN-XX) removidas, 0 warnings
- **Subfase 7.2: Performance & Optimización** - Auditoría de código OK (N+1, lazy loading, memory leaks)

### Fase 6 (archivado)
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

### Fase 7: Beta Preparation (V1.0 Release)

**Subfase 7.1: Code Quality & Cleanup** ✅
- [x] Revisar TODOs/FIXMEs en el código
- [x] Eliminar código muerto o comentado
- [x] Eliminar referencias legacy (FIN-XX)
- [x] Imports no usados (verificado)
- [x] Warnings del compilador a cero

**Subfase 7.2: Performance & Optimización** ✅
- [x] Auditoría de código (N+1, lazy loading, view bodies)
- [x] Memory leaks (sin retain cycles detectados)
- [x] Nota: Profiling con Instruments pendiente (manual en Xcode)

**Subfase 7.3: Localizaciones y Monedas** ← Siguiente
- [ ] Auditoría de strings hardcodeados
- [ ] Verificar keys en 6 idiomas
- [ ] Formato números/fechas por locale
- [ ] Añadir monedas: MXN, COP, BRL, GBP

**Subfase 7.4: Testing & QA**
- [ ] Documento de escenarios de prueba manual
- [ ] Casos edge documentados

**Subfase 7.5: UX para Nuevos Usuarios**
- [ ] Empty states informativos
- [ ] Textos de ayuda en Settings

**Subfase 7.6: App Store Preparation**
- [ ] Screenshots, descripción, metadata

**Subfase 7.7: Estabilidad Pre-Release**
- [ ] Error handling consistente
- [ ] Validaciones de datos

**Subfase 7.8: Primer Uso y Onboarding**
- [ ] Detección idioma/región del sistema
- [ ] Onboarding básico (nombre + moneda)
- [ ] Defaults sensatos

## Parking Lot

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-01-20
Stopped at: Reorganización roadmap V1.0/V1.1
Next step: Crear spec Fase 7 (Beta Preparation) y planificar subfase 7.1
Resume file: None

## V1.1 (Futuro)

Registro Inteligente y Plataforma diferidos. Ver:
- .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP.md (Fases 8-9)
