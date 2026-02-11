# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 10.5.S — Deep Scan Pre-Launch (V1.1) — 28 issues cerrados (12✅ 6🟢 3🔵 7 false positives)

## Current Position

Version: 1.1 (en desarrollo)
Phase: 10.5 — Mejoras Pre-Release
Spec: None
Plan: None
Status: **Fase 10.5.S completada** — Deep Scan Pre-Launch (28/28 issues cerrados)
Last activity: 2026-02-09 — Deep scan resuelto: 12 fixed, 6 accepted, 3 deferred, 7 false positives

Progress: V1.0 ████████████████ 100% ✅
Progress: V1.1 ██████████████░░ 95% (Fase 8 ✅, Fase 10 ✅, Fase 10.5 en progreso — bugs)
Progress: V1.2 ░░░░░░░░░░░░░░░░ 0% (Fase 11 pendiente)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-02-11] 328efbb chore: pre-launch fixes — terms link, widget i18n, a11y labels, weak self
- [2026-02-11] 101fbb6 style: migrate hardcoded spacing to DS tokens + update docs (DS-COMPLIANCE)
- [2026-02-11] 0a2edec style: migrate hardcoded colors to DS.Semantic/Gradients/Colors tokens (DS-COMPLIANCE)
- [2026-02-11] 96ad324 style: add DS.Semantic, DS.Gradients and DS.Colors.borderDark tokens (DS-COMPLIANCE)
- [2026-02-11] 4cbc40c fix: add iCloud sync waiting screen for new device setup (BUG-22)
- [2026-02-11] 9406d11 fix: cross-view refresh via SessionState.dataVersion (BUG-20)
- [2026-02-09] 7e327e1 style: modernize TransactionSuccessView with gradient hero and staggered animations (BUG-19)
- [2026-02-09] 279ccc1 fix: resolve Share Extension cold launch race condition (BUG-18)
- [2026-02-09] af56040 fix: reduce inbox modal delay and defer when biometric locked (BUG-17)
- [2026-02-09] da8309e fix: resolve 7 high-priority deep scan issues (DS-6 to DS-12)
- [2026-02-09] 171a0ce fix: resolve 5 critical deep scan issues (DS-1 to DS-5)
- [2026-02-08] 453b849 fix: add createdAt tiebreaker for consistent same-day transaction ordering (BUG-16)
- [2026-02-08] e8a6844 fix: prevent unwanted balance adjustments when editing accounts (BUG-13)
- [2026-02-08] f5d2b43 fix: a11y audit corrections — missing labels, DT tokens, Reduce Motion
- [2026-02-08] 7545bf8 fix: refresh Inbox UI after deleting draft permanently (BUG-15)
- [2026-02-08] 0fdf436 feat: comprehensive accessibility — VoiceOver, Dynamic Type, Reduce Motion
- [2026-02-08] 4577ddf fix: invalidar cache de widgets al eliminar transacciones (BUG-14)
- [2026-02-08] c931b9f feat: waterfall chart for daily cash flow view (EXP-1)
- [2026-02-08] 6f92bb5 chore: clean up skills — remove GSD + redundant commands, add quality skills
- [2026-02-07] 6808209 fix: correct archive/exclude account behavior across entire app (BUG-12)
- [2026-02-07] c64d2a0 fix: prevent empty notifications for scheduled payments and announcements
- [2026-02-07] 085936d fix: correct report notification calculations — currency, interval, and account filtering
- [2026-02-07] 4976add refactor: apply code review fixes — DS tokens, search localization, error logging
- [2026-02-07] a5c87ef fix(widgets): restore native iOS background with .fill.tertiary
- [2026-02-07] 6f6faaa feat: add black PRO theme with paywall gate
- [2026-02-07] 7151ee7 feat: redesign voice/image counters with glass effects and rings
- [2026-02-07] 19ba584 feat: add push notifications for automatic records
- [2026-02-07] 74a0276 feat: add localization keys for notifications, theme, and seeds
- [2026-02-07] d14b299 chore: default widget theme to system instead of yala
- [2026-02-07] 871096a fix: resolve BUG-8 currency format and BUG-2 missing icon
- [2026-02-06] 9f36107 feat: add expenses-only mode across entire app
- [2026-02-06] b90443c fix: resolve BUG-5, BUG-6, BUG-7 for phase 10.5 closure
- [2026-02-05] fb7b75e fix(widgets): update Control Center labels and unify SF Symbol icons
- [2026-02-05] 463cd47 fix(sync): reload data on transaction delete and trends update
- [2026-02-05] 3f0099f fix(notifications): add background task reliability and model support
- [2026-02-04] 562820c feat(ux): add haptic feedback and animations
- [2026-02-04] 40b7925 feat(settings): add toggle to show/hide period variations
- [2026-02-04] 9c7a3fa refactor(ui): unify scheduled payments text styles with Records
- [2026-02-04] f863c40 feat(currency): add recommended section and auto-deselect logic
- [2026-02-04] 6219467 chore: rename Neto references to Yala in file headers
- [2026-02-04] 3b4adcd feat(widgets): add widgetAccentable support for iOS 18 tinted mode
- [2026-02-04] 9e86af6 fix(widgets): enable Control Center widget actions to trigger app flows
- [2026-02-04] 875d4a6 refactor(icloud): simplify sync to always-on when iCloud available
- [2026-02-04] eba675b refactor(widgets): remove deprecated period code and fix widget logic
- [2026-02-04] f3c6f08 refactor(widgets): replace hardcoded values with WDS design tokens
- [2026-02-04] 443acc5 feat(widgets): localize all widget texts for i18n support
- [2026-02-04] eddc1bc fix(widgets): redesign TopCategories/TopSubcategories with compact layout
- [2026-02-04] b69b8b1 fix(widgets): remove force unwraps in dateInterval()
- [2026-02-04] 7f678f5 fix(widgets): calculate historical balance for past periods
- [2026-02-04] 919166a fix(widgets): precalculate summaries for all periods
- [2026-02-04] 5427940 fix(widgets): align WidgetPeriod with DetailPeriod for correct data

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
- **Localización de Widgets (i18n)** - 13 widgets localizados con ~65 claves en es/en; AppIntents (title, description, @Parameter), WidgetPeriodOption enum, textos UI (headers, empty states, labels), Control Widgets iOS 18+; archivos eliminados (templates no usados)
- **Soporte Modo Teñido iOS 18 (widgetAccentable)** - `.widgetAccentable()` agregado a 12 archivos de widgets para soporte de tinted mode; KPIs, progress bars, charts, iconos y montos se tiñen con el color de acento del usuario; pie charts excluidos (mantienen colores para diferenciación visual)
- **Notificaciones Personalizadas (10.5.H)** - ScheduledPaymentNotificationService para pagos vencidos/hoy/próximos con nombre y monto ("Hoy vence: Netflix por $29.90"); BudgetAlertService mejorado con montos gastado/límite ("Presupuesto Comida al 50% — $500 de $1,000 gastados"); ReportNotificationService con datos reales calculados (balance, gastos, ingresos, top categoría); verificación de permisos y reprogramación automática al volver a la app o reinstalar; CurrencyUtils.symbol(for:) helper; localizaciones 6 idiomas
- **iCloud Sync Always-On (10.5.G.1 mejora)** - Sync simplificado a always-on (sin toggle opt-in); Settings solo muestra estado (sin restart); detección de datos iCloud al instalar para saltar onboarding; pantalla "Sincronizando..." mientras espera datos (5s timeout); localizaciones completas en 6 idiomas para todas las claves iCloud
- **Personalización de Widgets iOS (10.5.G.4)** - Tema (Yala/iOS) para 10 widgets de datos; modo de selección (Automático/Personalizado) para BudgetsWidget y ScheduledPaymentsWidget; AppEntity + EntityQuery para Budget y ScheduledPayment; ParameterSummary condicional para mostrar selector solo en modo custom; localizaciones es/en (tema, selección, entidades)
- **Fix etiquetas duplicadas en gráficos de barras** - Nueva función `calculateSmartAxisDates(forDataDates:grouping:)` en SmartAxisHelper que usa fechas reales de datos en vez de interpolación lineal para agrupación mes/semana; previene etiquetas duplicadas como "ene", "ene", "feb" cuando hay pocos datos; actualizado en CashFlowWidget, NatureTrendWidget (app y widget)
- **Toggle Comparativas (10.5.I)** - Toggle en Personalización para mostrar/ocultar variaciones vs periodo anterior; oculta chips de variación, selector M/A, línea de periodo anterior en gráficas, carrusel de comparación; @AppStorage propaga setting a todos los componentes; fix try? sin manejo de error en TrendsTabView; valores hardcodeados reemplazados por DS.Spacing tokens; localizaciones 6 idiomas
- **Tab Registros Standalone (10.5.J)** - Nueva tab "Registros" en sección "Más" con RecordsStandaloneView; FAB completo con voice/image input; selection mode y bulk edit; filtros sincronizados con SessionState (SSOT); promocionable a tabs principales desde Perfil > Personalización; tokens DS.Button para dimensiones FAB/action buttons; localizaciones 6 idiomas
- **Animaciones y Haptic Feedback (10.5.K)** - DS.Haptic helpers centralizados (success, selection, medium, light, warning); constantes spring en DS.Animation; haptic en FAB toggle/menu (3 vistas), save transaction (success), delete (warning); animación de selección en RecordRowView con bounce; animación de entrada en TransactionSuccessView con stagger; action bar animado slide-up con contentTransition; respeta accessibilityReduceMotion
- **Sistema Pro/Free (10.5.L)** - FeatureGateService con enum ProFeature (accounts, budgets, voiceInput, imageInput, premiumIcons); límites Free (2 cuentas, 3 presupuestos); gates en AccountsSettingsListView, BudgetsListView, PanelView (FAB voz/imagen), ProfileView (toggles), AppIconSettingsView; ProBadge component; UpgradePromptSheet contextual (limitReached/proFeature/trialExpired); StoreKitManager extendido (trial detection, wasProUser, syncToAppGroup); localizaciones 6 idiomas; gates en DetailContainerView FAB y carrusel de cuentas; fix toggle Simular Pro (devSimulatePro como stored property para @Observable, eliminar .disabled() que causaba dimming)
- **Fix Sistema Notificaciones (10.5.M)** - Deep links al tocar notificaciones (→statistics, →planning, →budgets); contenido dinámico para reportes (datos reales vs hints estáticos); prevención de duplicados por tipo (no count); background tasks con respaldo 1h después; ventana ampliada a mismo día para foreground check; requiresDynamicContent y lastNotifiedDate en NotificationItem; cancelDynamicNotifications en bootstrap
- **Fix Sincronización de Datos (10.5.N)** - Lista de registros ahora actualiza inmediatamente al eliminar transacción (refreshRecordsData llama loadData primero); Cash Flow ya no muestra empty state falso (onChange de allTransactions.count en TrendsTabView)
- **Auditoría Pre-Launch (10.5.O)** - Auditoría completa de 10 categorías: PrivacyInfo.xcprivacy para App Store compliance; 143+ prints envueltos en #if DEBUG; 26 try? convertidos a do/catch con diagnóstico en 14 archivos; force unwraps protegidos con guard; 40 traducciones faltantes añadidas a de/fr/it/pt; 16 claves L10n para columnas de exportación; foregroundColor→foregroundStyle (3 archivos); cornerRadius→clipShape (6 archivos); 19 @available innecesarios eliminados (target iOS 26+); deinit en iCloudSyncService; 4 commits (dc12ae6, 9bc7bff, aba270f, bc5916f)
- **Mejoras Onboarding (10.5.P)** - Botón "Activar todo" en notificaciones; LanguageManager + ls() helper para override de idioma in-app; selección de idioma como pantalla pre-onboarding (no dentro del flujo); eliminada vista "Sincronizando datos" de iCloud; MainTabView no se renderiza hasta completar onboarding; alert si datos iCloud llegan durante onboarding; welcome copy actualizado al brand voice en 6 idiomas; DE/FR corregido de formal a informal
- **Auditoría Documental y Web (10.5.R)** - Auditoría completa de toda la documentación del proyecto; 19 archivos obsoletos eliminados; rename Neto→Yala propagado a todos los docs activos (UI-PATTERNS, APPSTORE-CHECKLIST, QA-SCENARIOS, PROJECT, ROADMAP, AUDIT-REPORT); ROADMAP sincronizado con progreso real de fase 10.5; CLAUDE.md corregido (12 entidades SwiftData, tests actualizados, ref EXECUTION-RULES eliminada); PRIVACY-POLICY.md reescrita con datos reales (iCloud sync, OpenAI API, exchangerate.host, permisos); TERMS-CONDITIONS.md creado (suscripciones Free/Pro, servicios terceros, ley peruana); web actualizada: PrivacyPage y TermsPage reescritas en 6 idiomas (ES/EN/DE/FR/IT/PT), trust badges corregidos ("100% Local"→"Privacidad primero", "Sin servidores"→"Sin rastreo"); 3 commits (fc7a6ac, 1dc78a4, eb8f3f3)
- **Fix Dark Mode Cards (10.5.Q)** - Migración de List→ScrollView+SectionBox en 4 vistas (AdjustmentModeSelectorView, AccountTypeSelectorView, RecordsFiltersView accounts/tags sheets, MultiSelectionList); DatePickers mantienen List con `.listRowBackground(Color.yalaCard)`; fix crash PeriodSelector (safe DatePicker ranges con min/max); 5 keys L10n nuevas (filters.categories/type/nature/currency, action.apply); magic numbers→DS tokens; 6 idiomas
- **Bugs finales fase 10.5 (BUG-5/6/7)** - BUG-7: nextDueDate default mañana en SaveAsRecurringSheet y ScheduledPaymentEditorView, DatePickers restringidos a futuro; BUG-6: subcategorías filtradas por tipo en edición masiva, opción deshabilitada si selección mixta; BUG-5: conversión de divisas en resumen de pagos planificados (ViewModel y Widget) con CurrencyConverter; fixes de review: force unwrap eliminado en Widget calendar, @MainActor en RecordsViewModel, guard nil subcategory
- **Modo Solo Gastos (Fase 11.A)** - Toggle reversible en Personalización con doble confirmación; oculta income/transfers/balance en toda la app; SessionState.isExpensesOnlyMode como SSOT (stored property con didSet → UserDefaults + App Group + widgets); 42 archivos: creación de transacciones (solo gasto), panel (gasto por periodo en cuentas, CashFlow solo gastos, Trends forzado a expense), estadísticas (métricas/filtros/records sin income), settings (saldos ocultos, categorías income dimeadas), widgets iOS (filtrado income), búsqueda/records (FilterService forzado a expense), favoritos/planificados/notificaciones (filtrado income), onboarding (nuevo paso), Siri shortcuts (AppIntent forzado); localizaciones 6 idiomas; 50+ escenarios QA; DS spacing tokens corregidos en 9 archivos; @MainActor en StatisticsViewModel/SessionState; try?→do/catch en ContentView
- **Fix notificaciones de reportes (10.5)** - Cálculos corregidos: divisa correcta (preferredCurrency vs hardcoded), filtrado por intervalo correcto (semanal/mensual), filtrado por cuentas seleccionadas en ReportConfig; commit 085936d
- **Fix widgets fondo nativo (10.5)** - Restaurado fondo nativo iOS con .fill.tertiary en lugar de colores custom; commit a5c87ef
- **Code review fixes (10.5)** - DS tokens aplicados, localización de búsqueda corregida, error logging mejorado; commit 3fdc15e
- **Remoción tema negro PRO (10.5)** - Tema negro eliminado de V1.1, diferido a Fase 11 para implementación correcta; AppTheme solo system/light/dark; commit 63c2c43
- **Fix multi-select pie charts (BUG-9)** - Pie charts ahora resaltan TODOS los items seleccionados (no solo el primero); eliminados @State intermediarios single-value en CategoriesTabView, widgets aceptan Set<PersistentIdentifier> directamente; 6 sync functions eliminadas; DS tokens aplicados en 3 widgets (fonts, frames, spacing, colores); código muerto eliminado (isSelected, formattedAmountCompact duplicado); commit 69b8002
- **Fix notificaciones vacías (BUG-10)** - scheduledPayments y announcements marcados como requiresDynamicContent=true para evitar scheduling estático con texto placeholder; cancelación de notificaciones huérfanas en reschedule; commit c64d2a0
- **Fix decimales en transacciones individuales (BUG-11)** - forceFullPrecision: true en 11 call sites de YalaFormatter.currency() que muestran montos individuales (RecordCard, favoritos, inbox, pagos planificados, widgets, success views); ScheduledPaymentDetailView migrado de NumberFormatter manual a YalaFormatter; DS.Radius.card fix en ContentView; commit 57bd488
- **Waterfall Chart CashFlow diario (EXP-1)** - Vista diaria de CashFlow ahora muestra gráfico waterfall cumulative (cada barra parte donde terminó la anterior); teal=neto positivo, hot pink=neto negativo; vista mensual sin cambios (bidireccional + línea neta); implementado en app (CashFlowWidget) y widget iOS (BidirectionalCashFlowChart); días con neto=0 filtrados; valores hardcodeados tokenizados a WDS/DS; guard explícito para LineMark/PointMark en widget; 9 escenarios QA (Sección 32); commit c931b9f
- **Skills cleanup (tooling)** - Removidos 24 GSD skills + 13 redundantes (57→19); añadidos swift-audit, swiftdata-check, swift-modernize, ds-compliance, deep-scan, test-coverage, a11y-audit, pre-launch; CLAUDE.md optimizado (336→204 líneas) con Quick Reference tables; WORKFLOW.md simplificado; commit 6f92bb5
- **Restauración background nativo widgets (10.5)** - Eliminado sistema de temas custom (WidgetThemeOption enum, @Parameter theme en 11 widgets); restaurado `.containerBackground(.fill.tertiary, for: .widget)` original de Apple en los 11 widgets; eliminado WidgetColors.yalaCard (código muerto); eliminadas 3 claves L10n de tema en es/en; eliminados 3 preview blocks "System Theme"; 15 archivos, +60/-319; commits a1aae5b + f4752c8
- **Accesibilidad completa (A11Y)** - VoiceOver: label requerido en YalaToolbarButton + 83 call sites, labels en componentes shared e icon-only buttons, traits .isHeader, decorative icons hidden, disabled hints en 18 vistas, alternativas color-only (BudgetRow excedido icon, ScheduledPaymentRow "Vencido" text, VariationChip labels, BudgetProgressBar .accessibilityValue); Dynamic Type: @ScaledMetric para hero sizes (48pt+) con cap accessibility1, DS.Typography tokens en ~90 vistas; Reduce Motion: withAnimation→dsWithAnimation en 9 archivos, skeleton shimmer y confetti skip; L10n scheduled.overdue en 6 locales; 131 archivos, +782/-951; commit 0fdf436
- **Fix archive/exclude account behavior (BUG-12)** - Corregida semántica invertida de isArchived/excludeFromStatistics en toda la app: cálculos/estadísticas ahora filtran solo por excludeFromStatistics (no isArchived), selección de cuentas para nuevas tx filtra solo por isArchived (no excludeFromStatistics); 11 archivos de lógica corregidos (FilterService, StatisticsVM, TrendsTabView, PanelVM, BalanceHelper, RecordsVM, ReportNotificationService, WidgetDataCache, NewTransactionVM, InboxView, InboxDraftEditSheet); validación de cuenta archivada en aprobación de inbox; pre-filtro de cuentas excluidas en Records; L10n errorArchivedAccount en 6 idiomas; commit 6808209

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

### Fase 10.5: Mejoras Pre-Release (V1.1) — EN PROGRESO (bugs)

**Subfases A-R completadas ✅** (ver Completed in Current Phase)

**Bugs resueltos previamente ✅ (b90443c):**
- ✅ BUG-5: Conversión de divisas en resumen de pagos planificados
- ✅ BUG-6: Filtrado de subcategorías por tipo en edición masiva
- ✅ BUG-7: nextDueDate default mañana al crear pagos planificados

**Fixes recientes (2026-02-07):**
- ✅ Fix notificaciones de reportes (divisa, intervalo, cuentas) — 085936d
- ✅ Fix widgets fondo nativo (.fill.tertiary) — a5c87ef
- ✅ Code review fixes (DS tokens, search L10n, error logging) — 3fdc15e
- ✅ Remoción tema negro PRO (diferido a Fase 11) — 63c2c43

**Bugs resueltos (2026-02-07 sesión 2):**
- ✅ **BUG-9: Pie charts ignoran selección múltiple de filtros** — Resuelto (69b8002)

**Bugs resueltos (2026-02-07 sesión 3):**
- ✅ **BUG-10: Notificaciones vacías en pagos planificados y novedades** — Resuelto (c64d2a0)
- ✅ **BUG-11: "Sin decimales" aplica a transacciones individuales** — Resuelto (57bd488)

**Bugs resueltos (2026-02-07 sesión 4):**
- ✅ **BUG-12: Comportamiento incorrecto de Archivar/Excluir en cuentas** — Resuelto (6808209)

**Fixes recientes (2026-02-08):**
- ✅ Restauración background nativo widgets (tema custom eliminado) — a1aae5b + f4752c8
- ✅ Dark mode de deep slate blue a negro puro (#000000 + #1C1C1E) — 15565d1

**Bugs pendientes:**
- ✅ **BUG-13: Archivar/desarchivar cuenta fuerza ajuste de saldo** — Resuelto (e8a6844)
- ✅ **BUG-14: Eliminar transacción no actualiza cache de widgets** — Resuelto (4577ddf)
- ✅ **A11Y: Accesibilidad completa** — VoiceOver, Dynamic Type, Reduce Motion (0fdf436)
- ✅ **BUG-15: Eliminar draft desde Inbox no actualiza UI** — Resuelto (7545bf8)
- ✅ **BUG-16: Orden inconsistente de transacciones del mismo día** — Resuelto (453b849)
- ✅ **BUG-17: Modal de drafts nuevos en Inbox demora en aparecer** — Resuelto (af56040)
- ✅ **BUG-18: Share Extension no ejecuta registro por imagen al abrir** — Resuelto (279ccc1)
- ✅ **BUG-19: Modernizar pantalla de éxito de transacciones** — Resuelto (7e327e1)
- ✅ **BUG-20: Vistas no se refrescan después de mutaciones de datos** — Resuelto (9406d11)
- ✅ **BUG-21: Archivar cuenta cambia balance total en Panel** — False positive (código correcto, solo filtra por excludeFromStatistics)
- ✅ **BUG-22: iCloud Sync no sincroniza datos en dispositivo nuevo** — Resuelto (4cbc40c)

### BUG-22: ✅ RESUELTO (4cbc40c)

**Pantalla de espera iCloud sync para dispositivo nuevo.** Polling cada 2s durante hasta 14s cuando iCloud está disponible pero no hay datos. Sync screen con ProgressView + textos localizados + botón "Configurar como nuevo" para skip manual. Alert fallback si datos llegan después del timeout/skip durante onboarding. Sin iCloud → onboarding directo. Usuarios existentes nunca ven sync screen. 5 escenarios QA nuevos (30.7–30.11).

### BUG-20: ✅ RESUELTO (9406d11)

**Cross-view refresh con SessionState.dataVersion.** Cada servicio/VM que hace `context.save()` incrementa `dataVersion`. Vistas clave observan con `.onChange(of: sessionState.dataVersion)` y llaman `loadData()`/`refreshData()`. También corregido `WidgetDataCache.updateCache()` faltante en `TransactionService.save()/saveAll()`. 16 archivos Swift modificados.

---

**10.5.S: Deep Scan Pre-Launch (2026-02-09)**

Escaneo profundo de 293 archivos Swift. Todos los puntos deben resolverse antes del lanzamiento.

**S.1 — CRITICOS (crashes, data loss):**
- ✅ **DS-1: UserDefaults key incorrecta** — Resuelto (171a0ce). 3 archivos migrados a `CurrencyDefaults.currentPreferred` / `@AppStorage("defaultCurrencyCode")`.
- ✅ **DS-2: División por cero en CategoriesPieWidget** — Resuelto (171a0ce). Guard `totalExpense > 0`.
- ✅ **DS-3: División por cero en TagsPieWidget** — Resuelto (171a0ce). Guard `totalExpense > 0`.
- ✅ **DS-4: Force unwraps en DateContextProvider (5x)** — Resuelto (171a0ce). `guard let` con fallback `"N/A"` / `continue`.
- ✅ **DS-5: Force unwraps en TrendDataProcessor** — Resuelto (171a0ce). Optional binding.

**S.2 — ALTOS (bugs probables):**
- ✅ **DS-6: Error silenciado en CurrencyConverter.swift** — Resuelto (da8309e). Debug logs en 2 catch blocks.
- ✅ **DS-7: Error silenciado en ExchangeRateService.swift** — Resuelto (da8309e). Debug logs en 2 catch blocks.
- ✅ **DS-8: Fetch sin límite en RecordsFiltersViewModel.swift** — Aceptado (da8309e). SwiftData no soporta DISTINCT; comentario explicativo.
- ✅ **DS-9: Fetch redundante en TrendsTabView.swift** — Resuelto (da8309e). Reemplazado por `allTransactions` existente.
- ✅ **DS-10: `try?` silenciando I/O en AudioRecorderService.swift** — Resuelto (da8309e). 3x try? → do/catch con debug logs.
- ✅ **DS-11: Force unwrap en ImportIntroSheet.swift** — Resuelto (da8309e). `.map { }` safe.
- ✅ **DS-12: Force unwraps (12x) en SharedModels.swift** — Resuelto (da8309e). `?? fallback` pattern.

**S.3 — MEDIOS (mejoras importantes):**
- 🟢 **DS-13: `.cornerRadius()` en charts** — FALSE POSITIVE: todas las 15 instancias son ChartContent (BarMark/SectorMark), no View API deprecated.
- ✅ **DS-14: Calendar extension duplicada en 5 archivos** — Resuelto (8d2dbce). Extraído a Calendar+Extensions.swift.
- ✅ **DS-15: `@MainActor` faltante en WidgetConfigManager** — Resuelto (3e80433). StoreKitManager excluido (usa nonisolated/Task.detached).
- 🟢 **DS-16: `try?` en regex compilation (3x)** — Aceptado. `guard let regex = try?` es patrón correcto en parsers.
- 🟢 **DS-17: `Subcategory.safeCategory` crea placeholder sin contexto** — Aceptado. assertionFailure + fallback es razonable para edge case CloudKit.
- 🔵 **DS-18: `.font(.system(size:))` hardcoded (~143 en 84 archivos)** — Diferido. Tarea mecánica masiva, separar.
- 🔵 **DS-19: Hardcoded `spacing:` (~237 en 96 archivos)** — Diferido. Tarea mecánica masiva, separar.
- 🔵 **DS-20: `DispatchQueue.main.asyncAfter` (~46 ocurrencias)** — Diferido. Cambio de comportamiento riesgoso en UI timing.
- ✅ **DS-21: Force unwraps (5x) en PreviousPeriodHelper.swift** — Resuelto (3e80433). `?? fallback` preservando return types.
- ✅ **DS-22: Force unwraps (4x) en TransactionCSVImportService.swift** — Resuelto (3e80433). `.map { columns[$0] }` en single y multi-currency.

**S.4 — BAJOS (limpieza):**
- 🟢 **DS-23: `@Relationship` en un lado** — Aceptado. Suficiente para SwiftData/CloudKit.
- 🟢 **DS-24: `print()` fuera de `#if DEBUG`** — FALSE POSITIVE: todos los prints ya envueltos en #if DEBUG o dentro de #Preview.
- ✅ **DS-25: Código duplicado en QuickExpenseIntent** — Resuelto (fe5b6a7). 3x formatCurrency y 2x findAccount extraídos a funciones file-level.
- 🟢 **DS-26: VoiceTranscriptionService sin @MainActor** — Aceptado. Hacen network calls (OpenAI API), @MainActor bloquearía UI.
- 🟢 **DS-27: `try?` en Task.sleep** — Aceptado. Intencional — solo falla por CancellationError y queremos continuar.
- 🟢 **DS-28: InboxDraft.tags inverse** — Aceptado. Ya declarado en Tag.inboxDrafts — funcional.

**Archivos > 500 líneas (top 10 — candidatos a refactorizar):**
TrendsTabView (1786), PanelViewModel (1735), CategoriesTabView (1723), TransactionCSVImportService (1682), PanelView (1399), NewTransactionView (1250), OnboardingView (1184), VoiceRecordingView (1154), QuickExpenseIntent (1141), InboxDraftEditSheet (1072)

**Sin issues (validado limpio):**
- foregroundColor → foregroundStyle: OK (0 usos legacy)
- @available innecesarios: OK (0 encontrados)
- #Predicate con enums: OK (todos usan rawValue)
- SwiftData relationships: todas tienen inverse en al menos un lado
- onChange firma vieja: OK (todos usan versión moderna)
- No TODOs/FIXMEs pendientes
- Retain cycles: OK (sin closures problemáticas)

---

### BUG-11: ✅ RESUELTO (57bd488)

"Sin decimales" ahora solo aplica a valores agregados. Montos individuales siempre muestran 2 decimales via `forceFullPrecision: true` en 11 call sites + migración de ScheduledPaymentDetailView a YalaFormatter.

### BUG-12: ✅ RESUELTO (6808209)

Semántica de isArchived/excludeFromStatistics corregida en toda la app. Cálculos/estadísticas filtran solo por excludeFromStatistics (cuentas archivadas siguen contando). Selección de cuentas para nuevas tx filtra solo por isArchived. Validación de cuenta archivada añadida en aprobación de inbox. 11 archivos de lógica + L10n en 6 idiomas.

### BUG-13: ✅ RESUELTO (e8a6844)

Root cause: `initializeBalanceIfNeeded()` pre-llenaba `balanceText` con saldo inicial en modo `.byEntry`, causando ajuste no deseado al guardar. Fix: solo pre-llenar en `.changeInitialBalance`; `.byEntry` empieza vacío. Sección "Ajuste" oculta en creación. Títulos localizados. 5 tests nuevos (20 total).

### BUG-14: ✅ RESUELTO (4577ddf)

Agregado `WidgetDataCache.updateCache(context:)` en los 2 paths de eliminación que bypaseaban TransactionService: NewTransactionView.deleteTransaction() y RecordsViewModel.deleteSelected(). Widgets ahora se invalidan inmediatamente al eliminar transacciones.

### EXP-1: ✅ COMPLETADO (c931b9f)

Waterfall chart cumulative para vista diaria de CashFlow. Cada barra parte donde terminó la anterior: teal (neto positivo), hot pink (neto negativo). Vista mensual sin cambios (bidireccional + línea neta). Implementado en in-app (CashFlowWidget.swift) y widget iOS (YalaWidgets). Días con neto=0 filtrados. Valores hardcodeados tokenizados a WDS/DS.

### BUG-15: ✅ RESUELTO (7545bf8)

`deleteDraftPermanently()` eliminaba el draft del contexto pero no llamaba `viewModel.loadData()` para refrescar los arrays manuales del ViewModel. Agregada 1 línea. Aplica tanto a pendientes como rechazados (misma función).

### BUG-16: ✅ RESUELTO (453b849)

Agregado `SortDescriptor(\.createdAt, order: .reverse)` como tiebreaker en 4 FetchDescriptors (WidgetDataCache, BudgetsVM, NewTransactionVM, AccountsSettingsListVM) y `createdAt` tiebreaker en 4 array sorts (FilterService.groupByDate, InboxVM.groupedDrafts, StatisticsVM.recentRecords, PanelVM últimas 5 tx). 8 archivos corregidos.

### BUG-17: ✅ RESUELTO (af56040)

**Modal de drafts nuevos en Inbox demora en aparecer.** Fix: reducir delay y defer cuando biometric lock activo.

### BUG-18: ✅ RESUELTO (279ccc1)

**Share Extension cold launch race condition.** Fix: race condition en deep link/lifecycle de Share Extension.

### BUG-19: ✅ RESUELTO (7e327e1)

**Modernizar pantalla de éxito al crear/aprobar transacción.** Hero con gradiente lineal + glow radiante + glass overlay + checkmark blanco. Monto promovido al hero. Animación escalonada 5 fases (0→700ms). Brand voice corregido en 6 idiomas. QA-SCENARIOS sección 33 agregada.

---

### Después de 10.5: Fase 11 — Sistema de Temas Independientes (V1.2)

**Plan completo:** `.planning/THEME-REFACTOR-PLAN.md`

Refactorizar el sistema de colores para soportar temas completamente independientes.
Arquitectura: YalaTheme struct + ThemeColor ShapeStyle + @Observable ThemeManager.
Elimina el hack de `.id(userThemeRaw)` que reinicia la app al cambiar tema.
~60-70 archivos a migrar, cambio mecánico (`Color.yalaBackground` → `.thBackground`).

### Después de Fase 11: Fase 12 — Plataforma Extendida (V1.2)

Ver ROADMAP.md para detalles.

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

- **2026-02-01 [Quality] [Low]: Limpiar try? en QuickExpenseIntent.swift** ✅ COMPLETADO (2026-02-05)
  Contexto: 14 instancias de `try?` convertidas a do/catch con diagnóstico
  Estado: Resuelto como parte de auditoría pre-launch (commit 9bc7bff)

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
- Sincronización bidireccional pie ↔ filtros: solo Nature usa `isSyncingFilters`; Category/Subcategory/Tag pasan Sets directamente al ViewModel
- Tags existentes migran automáticamente con icono por defecto
- Design System (DS) en `DesignTokens.swift` con: Spacing, Radius, FormRow, ListRow, Typography
- SwiftData N:N requiere `@Relationship(inverse:)` explícito en un lado; arrays sin inverse se tratan como 1:N

## Session Continuity

Last session: 2026-02-11
Stopped at: Pre-launch fixes completados (W1/W2/W3/W5)
Next step: Siguiente item de /next (pendiente evaluación)
Resume context:
- 4 pre-launch fixes en 1 commit (328efbb): terms link paywall, widget i18n, FAB a11y labels, weak self
- W4 (64 fonts hardcodeados) diferido intencionalmente
- Build limpio, swift-audit limpio
