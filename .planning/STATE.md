# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 11 — Plataforma Avanzada (V1.2 - App Store Release)

## Current Position

Version: 1.2 (en desarrollo)
Phase: 11 — Plataforma Avanzada
Spec: None
Plan: None
Status: **V1.1 COMPLETA ✅ - Auditoría cerrada ✅** — Lista para comenzar V1.2
Last activity: 2026-01-30 — STATE.md actualizado, preparado para Fase 11

Progress: V1.0 ████████████████ 100% ✅
Progress: V1.1 ████████████████ 100% ✅ (Fase 8 y Fase 10 completadas)
Progress: V1.2 ░░░░░░░░░░░░░░░░ 0% (Fase 11 pendiente)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-31] 4f132cf fix(onboarding): remove residual DEV_BUILD lastStep logic
- [2026-01-31] 340ef29 chore(seed): remove DevDataSeed completely
- [2026-01-30] 73c7e9f refactor(widget): simplify exchange rate widget to use only secondaryCurrencies
- [2026-01-30] cfd0447 fix(dev): restrict dev data seed to DEV_BUILD only (not regular DEBUG)
- [2026-01-30] d07aaac feat(dev): integrate dev data seed step in onboarding (DEBUG only)
- [2026-01-30] a1c2c7e feat(dev): implement varied daily transaction generation in DevDataSeed
- [2026-01-30] 39ff387 feat(dev): implement scheduled payment transaction generation in DevDataSeed
- [2026-01-30] fda19c3 feat(dev): implement scheduled payment seed creation in DevDataSeed
- [2026-01-30] 49bf92c feat(dev): implement subscription seed creation in DevDataSeed
- [2026-01-30] 9e0d8ac feat(dev): implement favorite payment seed creation in DevDataSeed
- [2026-01-30] 1b4ab3e feat(dev): implement budget seed creation in DevDataSeed
- [2026-01-30] 1cad135 feat(dev): implement tag seed creation in DevDataSeed
- [2026-01-30] 2e0cd45 feat(dev): implement account seed creation in DevDataSeed
- [2026-01-30] 8159f09 feat(dev): add DevDataSeed.swift base structure for dev onboarding
- [2026-01-30] a5e68b0 perf: optimize preloadHistoricalIfNeeded to fetch only required currencies
- [2026-01-30] 4122f8d fix: load historical exchange rates after onboarding completion
- [2026-01-30] 61b3612 fix: load historical exchange rates when adding secondary currencies
- [2026-01-30] f253d52 refactor: add getRequiredCurrencies helper to ExchangeRateService
- [2026-01-30] e380860 fix(ui): correct disclosure groups and secondary currency ordering in settings
- [2026-01-30] 5986131 fix(ui): correct alignment when no accounts exist
- [2026-01-30] c1457e8 fix(ui): correct theme switching, expandable lists, and capsule buttons

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
- **Bugfixes TestFlight Ronda 2** - SSOT para filtros, smart alignment para gráficas comparativas, clasificación correcta de transferencias (entrantes a Ingresos, salientes a Otros), protección de categorías/subcategorías del sistema, migración automática de transferencias existentes, 4 escenarios QA nuevos
- **Soporte XLSX completo** - Fix importación de fechas Excel (números seriales a ISO), XLSXWriter para crear archivos Excel usando ZIPFoundation, descarga de plantilla en CSV o XLSX, exportación de datos en CSV o XLSX, localizaciones actualizadas en 6 idiomas
- **Subfase 8.4: Imágenes MVP** - Toggle imagen input en Settings, opción FAB imagen (naranja), ImageSelectionView con PhotosPicker, Vision OCR (VNRecognizeTextRequest), clasificador heurístico (screenshotSingle/List/receiptPhoto), AmountParser ($€£, europeo/americano, negativos), DateParser (relativas/absolutas), ScreenshotSingleExtractor (alertas bancarias), RowClusterer + ScreenshotListExtractor (listas de transacciones), navegación automática a Inbox, localizaciones en 6 idiomas, 40 escenarios QA (Sección 18)
- **Subfase 8.5: Merchant Memory** - MerchantMemory model (SwiftData), MerchantCanonicalizer (normalización, strip prefijos pago, Levenshtein fuzzy match), MerchantMemoryService (suggest/updateMemory/applyDecay), política escalonada (<3=nada, >=3=sugerir, >=5=autoasignar), integrado en aprobación (detección correcciones), voice fallback, image fallback, DataWipeService, 13 escenarios QA (Sección 19)
- **Pagos planificados → Inbox (10.5)** - ScheduledPaymentDraftService crea drafts automáticamente para pagos vencidos, modal personalizado de notificación, detección de duplicados por UUID, badge "Pagado" en lista de pagos, actualización de lastPaidDate y avance de nextDueDate al aprobar, nuevos DraftSourceTypes (scheduledPayment, subscription), localizaciones en 6 idiomas
- **Mejoras UX divisas y sheets** - Divisa solo después de seleccionar cuenta en pago planificado, cierre automático de DetailView al eliminar, divisa de presupuesto sigue cuenta única, cálculo de gastos usa divisa correcta según número de cuentas
- **Share Extension (10.4)** - Recibir imágenes desde otras apps, App Group configurado, navegación automática a Panel, Panel bloqueado como primer tab
- **Onboarding seed (10.6)** - Grid visual de 11 categorías, usuario elige empezar con categorías o desde cero
- **Permisos y correcciones registro inteligente** - Permisos micrófono/fotos al activar toggle, prompts voz sin duplicar tags, FAB imagen en todas las vistas
- **App Intent "Registro rápido" (10.x)** - Shortcut Siri/Shortcuts con flujo conversacional (tipo → monto → nota → cuenta → subcategoría → etiqueta), subcategorías filtradas por tipo, búsqueda inteligente de etiquetas (insensible a mayúsculas/acentos), 6 idiomas, 10 escenarios QA
- **App Intents Voz e Imagen (10.x)** - Shortcuts "Registro por voz" y "Registro por imagen", validan toggles activos, deep links yala://voice-entry y yala://image-entry, error si feature desactivada, 6 idiomas, 5 escenarios QA
- **Automatización Apple Pay (10.x)** - ApplePayTransactionIntent recibe Amount/Merchant/Name de Wallet, parsea monto y divisa del texto, infiere cuenta por divisa única, auto-categoriza con MerchantMemory, crea InboxDraft con sourceType .applePay, 6 idiomas, 11 escenarios QA (Sección 23)
- **Automatización Externa (10.x)** - AutomationEntryIntent recibe JSON estructurado (amount, currency, merchant, date), ideal para correos de banco procesados por IA, crea InboxDraft con sourceType .automation, auto-asigna cuenta por divisa y categoría via MerchantMemory
- **Sistema de Notificaciones (10.x)** - NotificationItem con 7 tipos default (endOfDay, lunchTime, dailyReport, weeklyReport, monthlyReport, scheduledPayments, announcements, custom), NotificationService para scheduling con soporte weekdays, ReportConfig configurable, NotificationsSettingsView y NotificationEditorSheet con selector weekdays estilo iOS, paso 6 de onboarding para activación inicial, localización 6 idiomas, 40+ escenarios QA
- **Auditoría de código (10.x)** - **CRÍTICOS: TODOS RESUELTOS ✅** SEC-001/002 (keys seguras), ERR-001-004 (try? → do-catch), BUG-001-005 (force unwraps → guard), SWD-001-004 (inversas SwiftData), PERF-001-003 (optimizado O(n)), CFG-001/002 (config correcta); **ALTOS: TODOS RESUELTOS ✅** SEC-003/004/005/006 (security hardening), BUG-006-011 (bounds, threading), SWD-005/006/007 (@MainActor), PERF-004/005/006 (static formatters), UI-001/002 (accessibility), ARCH-001-006 (refactors arquitecturales) ✅ COMPLETADOS
- **Refactoring Arquitectural (10.x)** - **4 Fases completadas (A, B, C, D)**: Fase A - Singletons → @Environment (CurrencyConverter, ExchangeRateService, Vision/Voice services); Fase B - SessionState.shared → @Environment injection; Fase C - Services para ModelContext (DraftService, EntityDeletionService, TransactionService); Fase D - @Query → ViewModels (37+ views migradas, 70+ @Query eliminados, 35+ ViewModels con lógica real); Ver `.planning/ARCH-REFACTOR-PROGRESS.md` para detalles completos
- **Fix tipos de cambio históricos (10.x)** - Helper getRequiredCurrencies() centraliza detección de divisas necesarias (f253d52); Settings carga automáticamente 1 año de datos al agregar divisas secundarias con loading state (61b3612); Onboarding carga datos históricos en background después de completar sin bloquear UI (4122f8d); preloadHistoricalIfNeeded optimizado para traer solo divisas necesarias vs todas las 7 soportadas (a5e68b0); 5 escenarios QA nuevos (13.7-13.11) para validación de carga histórica (987da70)
- **Seed Dev (10.x)** - ~~Implementado~~ **ELIMINADO** (340ef29): Causaba errores de compilación con #Predicate macros. Removido completamente del proyecto.
- **Widget tipo de cambio simplificado (10.x)** - Refactorización para usar SOLO secondaryCurrencies como fuente de verdad (73c7e9f): eliminado selector de divisas innecesario y sheet asociado, sin defaults ni fallbacks, sin caché local, estado vacío cuando no hay divisas secundarias seleccionadas, widget automáticamente muestra las 1-2 divisas elegidas en Settings/onboarding, reacción inmediata a cambios en Settings via SessionState flag

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
  - Shared/: YalaEmptyState, YalaBadge, StandardButtons, YalaLoadingOverlay, SectionBox, CurrencySelectorView, IconColorPickerSheet, SkeletonView
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

### Fase 10: Refinamiento & Notificaciones (V1.1) ✅ COMPLETADA

**Resumen:** 21/21 items UAT completados (2026-01-30)

- [x] Pagos planificados → transacción en bandeja de entrada ✅
- [x] Integración Share Sheet ✅
- [x] Permisos micrófono/fotos al activar toggles ✅
- [x] Onboarding seed de categorías ✅
- [x] Sistema de notificaciones configurables ✅
- [x] Atajos Siri/Shortcuts (Registro rápido, Voz, Imagen) ✅
- [x] Automatización Apple Pay ✅
- [x] Automatización externa (JSON) ✅
- [x] 10.A: Bugs críticos (4/4 items) ✅
- [x] 10.B: Lógica de negocio (3/3 items) ✅
- [x] 10.C: Widgets (4/4 items) ✅
- [x] 10.D: Consistencia visual (5/5 items) ✅
- [x] 10.E: Settings y preferencias (4/4 items) ✅
- [x] 10.F: Desarrollo - Seed Dev (ELIMINADO - causaba errores)

**Decisiones importantes de la fase:**
- B.1: Bloquear transacciones con fecha futura (previene inconsistencias balance/registros)
- B.2: Campo `createdAt` para ordenar registros del mismo día por hora de creación
- F.1: ~~Seed Dev solo visible en scheme "Yala Dev"~~ **ELIMINADO** (340ef29)

### Próxima fase: Fase 11 — Plataforma Avanzada (V1.2)

Ver ROADMAP.md para detalles de Fase 11:
- Modo "Solo gastos"
- Widgets iOS (WidgetKit)
- Integración Apple Watch
- Smart Insights
- Refinamiento iPad
- Vista de reportes

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
- [x] Screenshots ✅

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

- **2026-01-29 [Testing] [Quality] [Medium]: Unit Tests para ViewModels** ✅ COMPLETADO (2026-01-30)
  Contexto: ViewModels testeables después del refactoring D.8
  Documento: `.planning/TESTING-STRATEGY.md`
  Estado: **COMPLETADO** - 56 tests de ViewModels:
  - NewTransactionViewModelTests: 35 tests (teclado, validación, tipos cambio)
  - BudgetsViewModelTests: 11 tests (status, display properties)
  - InboxViewModelTests: 10 tests (filtrado, agrupación, conteo)
  Patrón: Lógica pura extraída en métodos `calculate*()` para evitar SwiftData en tests

### V2.0 (Futuro)

- **Split de transacción**
  Contexto: Funcionalidad para dividir una transacción en múltiples partes
  Estado: Por definir alcance e implementación

### Notas Técnicas

(Items movidos a Fase 5.1)

- `iconName` en Tag tiene default `"tag.fill"` para migración
- `TagsPieWidget` sigue patrón de CategoriesPieWidget/SubcategoriesPieWidget
- Sincronización bidireccional pie ↔ filtros usa flag `isSyncingFilters`
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-01-31
Stopped at: Fix bug onboarding que regresaba al paso 1 (residuo de DevDataSeed)
Next step: Continuar refinamiento V1.1 o comenzar Fase 11
Resume context:
- V1.0 completa ✅ (Fases 1-9)
- V1.1 completa ✅ (Fase 8 y Fase 10)
- Auditoría de código: CERRADA ✅
  - 24 issues críticos resueltos
  - 42+ issues altos resueltos (incluyendo ARCH-001 a ARCH-006)
  - Refactoring arquitectural completo (Fases A, B, C, D)
  - 37+ views migradas a ViewModels
  - Tests de ViewModels: 56 tests (NewTransactionViewModel: 35, BudgetsViewModel: 11, InboxViewModel: 10)
- Fase 10: 21/21 items UAT completados
  - Sección A: 4/4 bugs críticos ✅
  - Sección B: 3/3 lógica de negocio ✅
  - Sección C: 4/4 widgets ✅
  - Sección D: 5/5 consistencia visual ✅
  - Sección E: 4/4 settings ✅
  - Sección F: Seed Dev **ELIMINADO** (causaba errores)
- Decisiones clave Fase 10:
  - Bloqueo de transacciones futuras (previene inconsistencias)
  - Campo createdAt para orden por hora en mismo día

## V1.2 (Next - App Store Release)

Ver ROADMAP.md para Fase 11 — Plataforma Avanzada:
- Modo "Solo gastos" (ocultar ingresos/saldos globalmente)
- Widgets iOS (WidgetKit para pantalla de inicio)
- Acciones rápidas (centro de control/pantalla de bloqueo)
- Smart Insights (predicciones, vista insights)
- Integración Apple Watch
- Refinamiento iPad
- Vista de reportes financieros
