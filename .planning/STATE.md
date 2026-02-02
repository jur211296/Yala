# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 10.5 — Mejoras Pre-Release (V1.1)

## Current Position

Version: 1.1 (en desarrollo)
Phase: 10.5 — Mejoras Pre-Release
Spec: None
Plan: None
Status: **Fase 10.5 en progreso** — Notificaciones personalizadas implementadas
Last activity: 2026-02-02 — Sistema de notificaciones personalizadas (pagos, presupuestos, reportes)

Progress: V1.0 ████████████████ 100% ✅
Progress: V1.1 ██████████████░░ 90% (Fase 8 ✅, Fase 10 ✅, Fase 10.5 en progreso)
Progress: V1.2 ░░░░░░░░░░░░░░░░ 0% (Fase 11 pendiente)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-02-02] 801bb7e feat(notifications): add personalized scheduled payment and report notifications
- [2026-02-02] 671dbda docs: mark 10.5.D.2 as completed in STATE and ROADMAP
- [2026-02-02] b1ae949 feat(onboarding): add budget alerts toggle to notifications step
- [2026-02-02] 7f0cde5 feat(notifications): add global toggle for budget alerts in settings
- [2026-02-02] 620eec8 chore: rename /compact to /pre-compact, clarify manual Shift+C requirement
- [2026-02-02] 7e440fe Merge feature/10.5.G.3-control-center into 1.1
- [2026-02-02] 9ff53cb Merge feature/10.5.G.2-widgets-ios into 1.1
- [2026-02-02] 1563970 Merge feature/10.5.G.1-icloud-sync into 1.1
- [2026-02-02] f4ed518 feat(widgets): add iOS WidgetKit widgets for balance, records, payments and budgets
- [2026-02-01] 1c32cc2 feat(voice): use dynamic currency names in voice input examples

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
- **Sistema de divisas completo (1.1)** - 48 divisas soportadas organizadas por 7 continentes (Latinoamérica, Norteamérica, Europa, Asia, Oceanía, Medio Oriente, África); enum CurrencyCode como SSOT con flag, symbol, aliases, fallbackRateToUSD, regionCodes; rediseño UX de selección de divisas con 3 sheets (CurrencyPickerSheet, SecondaryCurrencyPickerSheet, ExchangeRatesSheet); agrupación por continente en todos los selectores; chip de tipo de cambio en transacciones multimoneda
- **Aislamiento Yala vs Yala Dev (10.5.E)** - SwiftDataConfiguration helper centralizado que usa APP_GROUP_IDENTIFIER de Info.plist para determinar nombre de base de datos (YalaModel vs YalaModel-Dev); 7 ubicaciones migradas (YalaApp + 6 App Intents); UserDefaults ya aislado por bundle ID; permisos iOS ya aislados por app
- **Consistencia Visual Pagos Planificados (10.5.B)** - Summary card sin gradientes (color primario, borde/sombra neutros); section headers simplificados (solo vencidos con indicador rojo); due status en cards simplificado (hotPink solo vencidos, resto secundario); botones calendario sin fondo coloreado; ingresos mantienen teal
- **UX Divisas (10.5.C completo)** - C.1: Ejemplos voz dinámicos con shortPluralName (ej: "50 soles", "50 dólares") sin país; C.2: Filtro monedas solo muestra las usadas en transacciones, sección oculta si no hay transacciones; C.3: Onboarding agrupa monedas por continente con sección "Recomendada" destacada, sin duplicación
- **Modal Unificado Inbox (10.5.F completo)** - Modal al volver a la app cuando hay drafts nuevos no vistos; mensaje adaptado según tipo (pagos planificados, suscripciones, automatizaciones, mixto con desglose); excluye voz/imagen; detección por lastCheckDate en UserDefaults; 14 escenarios QA
- **Alertas de Presupuestos (10.5.D completo)** - D.1: Notificaciones push cuando presupuestos alcanzan umbrales configurados (50%, 75%, 90%, 100%); configuración por presupuesto con toggle y chips de umbrales; BudgetAlertService evalúa al crear/aprobar transacciones; BudgetAlertTracker previene duplicados por período; D.2: Toggle global en Settings > Notificaciones (default OFF, activable en onboarding); 15+ escenarios QA
- **Widgets iOS WidgetKit (10.5.G.2 completo)** - 4 tipos de widgets: Balance (small/medium con mini gráfico), Últimos Registros (5 transacciones recientes), Pagos Planificados (próximos con filtro), Presupuestos (barras de progreso con colores); WidgetDataCache para sincronización via App Groups; deep links desde widgets (yala://panel, statistics/records, planning, budgets); Background App Refresh cada 4h; 30 escenarios QA (Sección 28)
- **Control Center iOS 18+ (10.5.G.3 completo)** - 3 ControlWidgets para iOS 18+: QuickExpenseControl (flujo Siri sin abrir app), VoiceEntryControl (abre app en modo voz), ImageEntryControl (abre app en modo imagen); @available(iOS 18.0, *) para compatibilidad; localizaciones 6 idiomas; 15 escenarios QA (Sección 29)
- **iCloud Sync CloudKit (10.5.G.1 completo)** - Integración nativa SwiftData+CloudKit con ModelConfiguration(cloudKitContainerIdentifier:); toggle opt-in en Settings; SyncSettingsView con estado de sync y cuenta iCloud; containers iCloud.com.jurgenschmidt.yala y iCloud.com.jurgenschmidt.yala.dev; paso opcional en onboarding; Privacy Policy actualizada; 20 escenarios QA (Sección 30)
- **Notificaciones Personalizadas (10.5.H)** - ScheduledPaymentNotificationService para pagos vencidos/hoy/próximos con nombre y monto ("Hoy vence: Netflix por $29.90"); BudgetAlertService mejorado con montos gastado/límite ("Presupuesto Comida al 50% — $500 de $1,000 gastados"); ReportNotificationService con datos reales calculados (balance, gastos, ingresos, top categoría); verificación de permisos y reprogramación automática al volver a la app o reinstalar; CurrencyUtils.symbol(for:) helper; localizaciones 6 idiomas

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

### Fase 10.5: Mejoras Pre-Release (V1.1) — EN PROGRESO

**10.5.A: Bugs Críticos (4)** ✅ COMPLETADO
- [x] A.1: Share Sheet envía imagen a app incorrecta → App Group y URL Scheme dinámicos
- [x] A.2: Atajo de automatización no lee JSON de texto → DecodingError detallado
- [x] A.3: Notificación in-app no aparece si hay sheet abierta → fullScreenCover
- [x] A.4: Cambio de tema no se aplica inmediatamente → themeRefreshKey con UUID

**10.5.E: Aislamiento Yala vs Yala Dev** ✅ COMPLETADO
- [x] E.1: Onboarding aislado → SwiftDataConfiguration usa DB name dinámico
- [x] E.2: Inbox/transacciones aislados → YalaModel vs YalaModel-Dev
- [x] E.3: Permisos separados → son por bundle ID automáticamente
- [x] E.4: Análisis completo:
  - SwiftData: CORREGIDO (SwiftDataConfiguration.swift)
  - UserDefaults: Ya aislado por bundle ID
  - App Group: Ya dinámico (APP_GROUP_IDENTIFIER)
  - Keychain: Sin access group = aislado por app

**10.5.F: Modal Unificado para Nuevos Items en Bandeja** ✅ COMPLETADO
- [x] F.1: Modal unificado para pagos planificados, suscripciones y automatizaciones
  - PendingInboxNotification struct con conteo por tipo
  - checkForPendingInboxDrafts detecta drafts nuevos desde lastCheck (UserDefaults)
  - InboxAlertModal muestra mensaje adaptado según tipo (scheduled/subscription/automation/mixed)
  - Desglose en mensaje mixto: "2 pagos y 3 registros automáticos"
  - Notifica al abrir app y al volver de background
  - Excluye voz/imagen (usuario los ejecuta en la app)

**10.5.B: Consistencia Visual (1)** ✅ COMPLETADO
- [x] B.1: UI de Pagos Planificados (alinear con Presupuestos)

**10.5.C: UX y Personalización (3)** ✅ COMPLETADO
- [x] C.1: Ejemplo voz "pesos" hardcodeado → moneda preferida (shortPluralName)
- [x] C.2: Filtro monedas solo con transacciones existentes
- [x] C.3: Onboarding divisas: recomendada + continentes

**10.5.D: Features (2)** ✅ COMPLETADO
- [x] D.1: Notificaciones de presupuestos (porcentaje + límite) — código completo, QA pendiente (Sección 27)
- [x] D.2: Toggle global en Notificaciones para alertas de presupuestos — default OFF, configurable en onboarding

**10.5.G: Sincronización y Widgets** ✅ COMPLETADO
- [x] G.1: iCloud Sync (CloudKit)
  - Integración nativa SwiftData+CloudKit
  - Toggle opt-in en SyncSettingsView
  - Containers: iCloud.com.jurgenschmidt.yala / .dev
  - Paso opcional en onboarding
  - Privacy Policy actualizada
  - 20 escenarios QA (Sección 30)
- [x] G.2: Widgets iOS (WidgetKit)
  - 4 widgets: Balance (S/M), Últimos Registros, Pagos, Presupuestos
  - WidgetDataCache + WidgetDataService
  - Deep links desde widgets
  - Background App Refresh cada 4h
  - 30 escenarios QA (Sección 28)
- [x] G.3: Control Center (iOS 18+)
  - 3 ControlWidgets: QuickExpense, Voice, Image
  - @available(iOS 18.0, *) para compatibilidad
  - Localizaciones 6 idiomas
  - 15 escenarios QA (Sección 29)

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

### Después de 10.5: Fase 11 — Plataforma Avanzada (V1.2)

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
- [x] 48 divisas soportadas en 7 continentes (expandido desde 7 originales)

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

- **2026-02-01 [Quality] [Low]: Limpiar try? en QuickExpenseIntent.swift**
  Contexto: 14 instancias de `try?` que silencian errores en App Intents (Shortcuts/Siri)
  Archivo: `Yala/App/Intents/QuickExpenseIntent.swift`
  Líneas: 274, 281, 287, 365, 418, 481, 739, 1009 (fetches) + 6 ModelContainer creations
  También: 1 force unwrap en línea 201 (simplificable)
  Estado: Pendiente - código preexistente, no crítico pero mejora diagnóstico

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

Last session: 2026-02-02
Stopped at: D.2 completado (toggle global alertas de presupuestos)
Next step: Validación manual de QA-SCENARIOS secciones 25-30
Resume context:
- **Sección G completa:**
  - G.1: iCloud Sync con SwiftData nativo (44 archivos)
  - G.2: 4 WidgetKit widgets (26 archivos)
  - G.3: 3 ControlWidgets iOS 18+ (11 archivos)
- **QA Pendiente:**
  - Sección 25: Fase 10.5.B y 10.5.C
  - Sección 26: Modal Unificado Inbox (10.5.F)
  - Sección 27: Alertas de Presupuestos (10.5.D.1)
  - Sección 28: Widgets iOS (10.5.G.2)
  - Sección 29: Control Center (10.5.G.3)
  - Sección 30: iCloud Sync (10.5.G.1)
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
