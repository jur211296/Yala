# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** V1.0 Release Complete — Listo para TestFlight

## Current Position

Version: 1.0 (RELEASE READY)
Phase: 7.1 of 7.1 en V1.0 (Acciones Rápidas en Transacciones) ✅ COMPLETADA
Spec: None
Plan: Complete
Status: **V1.0 en TestFlight** — Nuevos bugs reportados pendientes de resolver
Last activity: 2026-01-21 — Bugfixes TestFlight (5 commits), nuevos bugs documentados

Progress: ██████████████ 100% (V1.0 Completa)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-22T07:30:00-05:00] 33b70b8 fix(filters): improve filter sync between Panel and Statistics views
- [2026-01-22T07:20:00-05:00] 7fdb536 fix(widgets): update default order and visibility for panel widgets
- [2026-01-21T20:46:00-05:00] 6ce1466 fix(ui): use consistent tag selector style in quick action sheets
- [2026-01-21T20:33:00-05:00] e9b1da8 fix(i18n): use localized displayName for transaction type in success view
- [2026-01-21T20:30:00-05:00] 9db55a1 fix(ui): ensure DatePicker save button works on first tap
- [2026-01-21T20:05:00-05:00] 85a2648 fix(ui): use tag.iconName instead of hardcoded icon in TagSelectorSheet
- [2026-01-21T20:02:00-05:00] b159686 fix(ui): increase recent subcategories from 4 to 8
- [2026-01-20T19:35:00-05:00] da12c1f docs(qa): add bulk edit scenarios to QA-SCENARIOS.md
- [2026-01-20T19:32:00-05:00] 649a0eb feat(bulk-edit): implement bulk editing for multiple transactions
- [2026-01-20T19:15:00-05:00] 3a458b6 fix(ui): redesign selection action bar with iOS 18 style

## Completed in Current Phase

- **Subfase 7.1: Code Quality & Cleanup** - TODOs eliminados, código muerto limpiado, referencias legacy (FIN-XX) removidas, 0 warnings
- **Subfase 7.2: Performance & Optimización** - Auditoría de código OK (N+1, lazy loading, memory leaks)
- **Subfase 7.3: Localizaciones y Monedas** - 7 monedas (PEN, USD, EUR, MXN, COP, BRL, GBP), strings hardcodeados corregidos
- **Subfase 7.4: Testing & QA** - QA-SCENARIOS.md exhaustivo (15 secciones, ~120 escenarios, ~250 validaciones), CSVs de prueba para import (7 archivos)
- **Subfase 7.5: UX para Nuevos Usuarios** - Empty states estandarizados, InfoHintButton en 12 widgets con toggle, FilterBlockedPopover, empty states en TrendsTabView
- **Subfase 7.7: Estabilidad Pre-Release** - Error handling en persistencia (13 try? → do/catch con alertas), validaciones auditadas OK
- **Subfase 7.8: Primer Uso y Onboarding** - Onboarding 4 pasos (nombre, moneda, secundarias, periodo), 7 monedas, sección divisas secundarias en Settings
- **Fix urgente: Edición masiva** - BulkEditSheet completo con 5 opciones (cuenta, subcategoría, tags, nota, monto), barra de selección rediseñada estilo iOS 18, métodos bulk update en RecordsViewModel, localizaciones en 6 idiomas, 9 escenarios QA nuevos
- **Subfase 7.6: App Store Preparation** - Metadata en 6 idiomas (nombre, subtitle, keywords, descripción completa), Privacy Policy (ES/EN), demo-data.csv para screenshots; documentado en .planning/appstore/
- **Bugfixes TestFlight V1.0** - Subcategorías recientes de 4→8, icono correcto en TagSelectorSheet, estilos consistentes en tag selector de quick actions, DatePicker save button fix, localización de tipo transacción en success view
- **Fase 7.1: Acciones Rápidas en Transacciones** - Barra de 4 botones (duplicar, eliminar, favorito, recurrente) debajo del monto en NewTransactionView; duplicar crea nueva transacción con datos prefilled; eliminar con confirmación; guardar como favorito/recurrente con alerts y toasts; localizaciones completas en 6 idiomas; 7 escenarios QA nuevos

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

### Fase 7.1: Acciones Rápidas en Transacciones ✅ COMPLETADA

- [x] UI Base: Barra de acciones debajo del monto (4 botones con iconos)
- [x] Duplicar: Crea copia de transacción actual (solo edición)
- [x] Eliminar: Elimina con confirmación (solo edición)
- [x] Guardar como favorito: Crea FavoritePayment desde transacción
- [x] Guardar como recurrente: Crea ScheduledPayment desde transacción
- [x] Localizaciones en 6 idiomas
- [x] QA-SCENARIOS.md actualizado con 7 escenarios nuevos

---

### Bugs TestFlight V1.0 - Ronda 2 (2026-01-21)

| # | Bug | Complejidad | Estado |
|---|-----|-------------|--------|
| 1 | Gráfica naturaleza en CategoriesTabView no filtra por categoría/subcategoría (revisar PanelView también) | Media | **En progreso** - Refactor SSOT |
| 2 | Comparativa vs periodo anterior - fechas descuadradas (ej: 9 ene vs 13 dic a misma altura, incrementa por datos no por fecha) | Media-Alta | Pendiente |
| 3 | Transferencias entrantes no se ven como ingreso en registros | Alta | Pendiente |
| 4 | Saldo en RecordsTabView no cuadra con diferencia ingresos-egresos (relacionado con transferencias) | Media | Pendiente |
| 5 | Preferencias widgets default desactualizadas - reordenar y cambiar defaults | Baja | ✅ Completado (7fdb536) |

**Bug 1 - Decisión arquitectónica:**
La sincronización de filtros entre vistas tiene múltiples fuentes de verdad (SessionState, ViewModels, @State locales).
Se aprobó refactor a **Single Source of Truth (SSOT)** usando SessionState como única fuente.
- Commit checkpoint: 33b70b8 (mejoras parciales, punto de reversión)
- Próximo: Refactor completo SSOT para todos los filtros

**Detalle Bug 3 (Transferencias):**
Propuesta de diseño: crear subcategorías de transferencia
- Saliente → Otros/Transferencia entre cuentas (gasto)
- Entrante → Ingresos/Transferencia entre cuentas (ingreso)
- Actualizar filtros de cálculos para excluir ambas de totales reales

**Detalle Bug 5 (Widgets):**
Nuevo orden: Tendencias, Flujo efectivo, Dist. categorías, Dist. subcategorías, Top categorías, Top subcategorías, Naturaleza, Presupuestos, Pagos planificados, Tipo de cambio (último)
Defaults visibles: Tendencias, Flujo de efectivo compacto, Distribución de categorías, TopSubcategoría, Últimos registros

**Orden sugerido de implementación:**
1. Bug 5 (widgets) - rápido, sin riesgo
2. Bug 1 (filtro naturaleza) - aislado
3. Bug 2 (fechas comparativa) - requiere investigación
4. Bugs 3+4 (transferencias) - juntos, decisión de diseño pendiente

---

### Post V1.0 — Opciones

1. Resolver bugs Ronda 2 arriba
2. Capturar screenshots manuales con demo-data.csv
3. Iniciar V1.1 (Fase 8: Registro Inteligente)

---

### Fase 7: Beta Preparation (V1.0 Release) ✅ COMPLETADA

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

**Subfase 7.3: Localizaciones y Monedas** ✅
- [x] Auditoría de strings hardcodeados (3 títulos corregidos)
- [x] Nuevas keys en 6 idiomas (filters.title, iconPicker.title)
- [x] Añadir monedas: MXN, COP, BRL, GBP (7 monedas total)

**Subfase 7.4: Testing & QA** ✅
- [x] Documento QA-SCENARIOS.md exhaustivo (reescritura completa)
- [x] 15 secciones con orden de dependencias
- [x] ~120 escenarios detallados con precondiciones
- [x] ~250+ validaciones específicas
- [x] CSVs de prueba en .qa-test-data/ (7 archivos)
- [x] screenshot_data_pen.csv para capturas App Store

**Subfase 7.5: UX para Nuevos Usuarios** ✅
- [x] Empty states informativos (auditados, iconos estandarizados)
- [x] Textos de ayuda en Settings (verificados)
- [x] InfoHintButton en 12 widgets con toggle showWidgetHints
- [x] FilterBlockedPopover para mensajes de bloqueo de filtros
- [x] Empty states en TrendsTabView (gráfica trend y cashflow)

**Subfase 7.6: App Store Preparation** ✅
- [x] Metadata en 6 idiomas (nombre, subtitle, keywords, descripción)
- [x] Privacy Policy (ES/EN)
- [x] demo-data.csv para screenshots
- [x] Documentado en .planning/appstore/
- [ ] Screenshots (pendiente - captura manual en Xcode)

**Subfase 7.7: Estabilidad Pre-Release** ✅
- [x] Error handling consistente (13 operaciones de persistencia con alertas)
- [x] Validaciones de datos (auditadas - todas OK)

**Subfase 7.8: Primer Uso y Onboarding** ✅
- [x] Onboarding de 4 pasos (nombre, moneda preferida, secundarias, periodo)
- [x] Integración con ContentView (fullScreenCover)
- [x] Reactivo a data wipe (muestra onboarding automáticamente)
- [x] 7 monedas soportadas (PEN, USD, EUR, MXN, COP, BRL, GBP)
- [x] Sección divisas secundarias en CurrencySettingsView

## Parking Lot

### Ideas Capturadas

- **2026-01-21 [Feature] [Business Logic] [Low]: Split de transacción (1.1)**
  Contexto: Funcionalidad aparte para dividir una transacción en múltiples partes
  Estado: Por definir, no está claro el alcance ni implementación
  Dependencias: Por determinar cuando se defina el alcance

### Notas Técnicas

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-01-22
Stopped at: Bug 5 completado, Bug 1 parcial con mejoras de sync, decisión de refactor SSOT
Next step: Refactor Single Source of Truth para filtros (11 filtros, 3 ViewModels, 5 vistas)
Resume file: .claude/sessions/2026-01-22-071628.log
Resume context:
- Checkpoint commit: 33b70b8 (punto de reversión antes de SSOT)
- Plan SSOT aprobado: SessionState como única fuente de verdad para todos los filtros
- Archivos a refactorizar: PanelViewModel, StatisticsViewModel, RecordsViewModel, CategoriesTabView, TrendsTabView, RecordsTabView, DetailContainerView, PanelView

## V1.1 (Futuro)

Registro Inteligente y Plataforma diferidos. Ver:
- .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP.md (Fases 8-9)
