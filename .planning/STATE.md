# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 12 — Plataforma Extendida (V1.2)

## Current Position

Version: 1.2 (en desarrollo)
Phase: 12 — Plataforma Extendida
Spec: `.planning/SMART-INSIGHTS-DESIGN.md`
Plan: Refactor filtros deferred -> Smart Insights tab
Status: **Fase 12 en progreso** — What's New sheet + coach mark tours + onboarding improvements
Last activity: 2026-03-12 — Full review fixes: @MainActor, reduceMotion, L10n, a11y, DS, Date.now

### Apple Review History (V1.0)

| # | Fecha | Guideline | Problema | Solución | Estado |
|---|-------|-----------|----------|----------|--------|
| 1 | 2026-02-26 | 3.1.2 | Links de Terms/Privacy no separados ni localizados | Separar links y localizar URLs legales | ✅ Resuelto (9cc6831) |
| 2 | 2026-02-27 | 5.1.1(i) + 5.1.2(i) | App comparte datos con OpenAI (voz/imagen) sin revelar qué datos, identificar a OpenAI, ni obtener permiso explícito | Consent alert in-app al activar funciones AI + actualizar privacy policy web para nombrar OpenAI y detallar datos | ✅ Resuelto (44efe2f + 8 fixes preventivos) |
| 3 | 2026-03-05 | — | V1.0.1 aprobada | Tag 1.0.1, merged to 1.0, hotfix branches deleted | ✅ Aprobada |

**Detalle rechazo #2:**
- **Datos enviados a OpenAI:** Audio (Whisper), imágenes JPEG (GPT-4.1 Nano), texto transcrito + nombres de categorías (GPT-4.1 Nano)
- **Datos NO enviados:** Montos, historial de transacciones, información personal, EXIF/metadata
- **Lo que faltaba:** (1) Disclosure in-app de datos compartidos, (2) Identificación de OpenAI como tercero, (3) Consentimiento explícito antes de enviar datos
- **Privacy policy (.planning/appstore/):** Ya documentaba OpenAI correctamente
- **Privacy policy (Web):** Solo decía "servicio externo de IA" — no nombraba a OpenAI ni detallaba datos

### Branch Strategy
- **1.0** = Release (V1.0.1 — Apple approved 2026-03-05, tag `1.0.1`)
- **1.1** = Desarrollo activo (V1.2: Fase 12, includes all hotfix work)

Progress: V1.0 ████████████████ 100% ✅
Progress: V1.1 ████████████████ 100% ✅ (Cerrada 2026-02-13)
Progress: V1.2 ████████████░░░░ 75% (Fase 11 ✅, Fase 12 pendiente)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-03-13] 8bc8666 docs: update STATE.md + ROADMAP.md for financial report progress
- [2026-03-13] 6b207f3 feat: integrate financial report tab + generic RecordsFiltersView
- [2026-03-13] aa589d1 feat: add financial report views, ViewModel + l10n (6 langs)
- [2026-03-13] 2a7a356 feat: add financial report models, pivot table calculator + tests
- [2026-03-13] 9692528 refactor: extract HintPopoverContent — shared popover for InfoHintButton + FilterBlockedPopover
- [2026-03-12] 031bc7c feat: split AI consent into processing (voice/image) and insights (smart overview)
- [2026-03-12] 08883ee fix: AI insights — tip alignment, reactivity, currency format, budget threshold
- [2026-03-12] 52b451f feat: rewrite AI insight tone/focus prompts + country regionalization + brand voice enforcement
- [2026-03-12] 134200b feat: enrich AI insights data + anti-hallucination prompts + upgrade to GPT-4.1 Mini
- [2026-03-12] c935830 fix: prevent SEGV crash in test host by using in-memory config under XCTest
- [2026-03-08] b0be795 fix: onboarding QA — comma-locale budget bug, animation timing, updated scenarios
- [2026-03-08] 82f4e5c feat: polish onboarding budget step — reframe texts, horizontal pills, live preview card, currency fix
- [2026-03-08] 9488d0a feat: polish onboarding account step — SectionBox layout, balance guide, validation
- [2026-03-07] 275392d feat: add Smart Insights personalization — tone, focus, and actionable tips
- [2026-03-07] 7fcdc22 feat: add contextual AI insight card to PanelView
- [2026-03-06] 7f01298 refactor: extract shared FilterControlBar — eliminate ~790 duplicate lines
- [2026-03-06] f1ea108 fix: restore exclude mode filters — batch commit + AI filter context + Insights layout
- [2026-03-06] 38c2f0d docs: update STATE.md with OpenAI compliance fix
- [2026-03-05] cc2f4a5 Merge hotfix/1.0.2 into 1.1
- [2026-03-05] 2700d6d Merge hotfix/1.0.1 into 1.1
- [2026-02-24] 328ba03 fix: scheduled payments visual consistency — hot pink expenses, sign prefix, currency conversion
- [2026-02-24] dea0d82 feat: support form sheet with type picker before sending email
- [2026-02-24] 0962a43 fix: show initial balance mode when editing account without balance set
- [2026-02-24] 8fbb672 fix: a11y labels on 6 icon-only buttons + A11Y-DM audit comments on hardcoded colors
- [2026-02-24] afc1bc3 docs: Fase 11.5 polish — STATE, QA scenarios, CLAUDE.md test count
- [2026-02-24] 596ca67 feat: credit card account type with payment reminder notification (POLISH-3)
- [2026-02-24] c17ba2b feat: recurring badge in transaction edit mode (POLISH-2)
- [2026-02-24] b74e8e4 fix: budget widget uses hotPink for exceeded budgets (POLISH-1)
- [2026-02-24] 8c87eb7 refactor: empty states — YalaEmptyState.widget style, 0-accounts guide, autocomplete feedback (EMPTY-1, EMPTY-3, EMPTY-5)
- [2026-02-24] 2614785 fix: release review — DS tokens, dead code cleanup (DS-3, DS-10, DS-21, DS-28, CODE-24)
- [2026-02-24] b5506a6 fix: release review — DS tokens, a11y labels, l10n migration, code quality (~60 items)

- [2026-02-20] 4add74e feat: dev-only subscription reset on data wipe for testing
- [2026-02-20] 4a57873 fix: improve ProTrialOfferSheet layout and show success view after purchase
- [2026-02-20] 9860a60 feat: add free trial UI — paywall trial info, post-onboarding offer sheet, StoreKit config
- [2026-02-20] 5c8eb76 fix: dark mode system theme, circular selectors, budget pie filter, support email context
- [2026-02-19] 44d3b89 feat: add average line to bar and trend charts with personalization picker
- [2026-02-19] 71d6e92 fix: budget period chevron navigation + duplicate report notification guard
- [2026-02-19] cbe7678 feat: add theme system with accent color propagation across all views
- [2026-02-18] d1eab6b fix: widen metric selector touch targets in TrendsTabView
- [2026-02-18] 6796274 fix: make YalaToolbarButton circular with buttonBorderShape(.circle)
- [2026-02-18] 599e7b1 feat: add paid status tracking + per-occurrence display for scheduled payments
- [2026-02-17] 276b1a4 fix: guard iCloud sync UX for medium-severity risks (R3, R5, R6, R9)
- [2026-02-17] fbbedde fix: guard iCloud sync + onboarding data integrity (R1, R2, R4, R7, R8)
- [2026-02-17] 24c917a fix: guard App Intents without accounts + expand iCloud sync detection
- [2026-02-17] 347e36e fix: ensure SessionState environment propagates on Designed for iPad
- [2026-02-17] 7040290 fix: widget budget filters + NatureTrendWidget KPI (BUG-27, BUG-28)
- [2026-02-16] e2a69fd feat: add iPad adaptive layout — double column widgets, carousels, trends
- [2026-02-16] 9c196e5 chore: unify deployment target (26.0) and version (1.0) across all targets
- [2026-02-13] f586a15 fix: resolve pre-launch warnings — prints, VoiceOver, Dynamic Type, touch targets
- [2026-02-13] d7b2970 fix: show visible point on trend charts when period has single data point
- [2026-02-12] ed93611 fix: initialize BudgetAlertService context so threshold notifications actually fire
- [2026-02-12] 9e38af9 fix: preserve specific subcategory selection when opening filters sheet
- [2026-02-12] 78bd427 fix: propagate category chart filters to filters sheet as subcategories
- [2026-02-12] 329f3f8 feat: replicate improved success screen to inbox approvals
- [2026-02-12] 177d8b7 chore: remove redundant notes from avatar editing screen
- [2026-02-12] 52e1a6c fix: apply category dimming when subcategory filter is active in statistics
- [2026-02-12] 7065e73 fix: sort same-day transactions by createdAt instead of date hour
- [2026-02-12] ad63797 refactor: remove personalization and power user tutorial categories
- [2026-02-12] e0d0555 feat: redesign tutorials with categorized list, detail carousel and video support
- [2026-02-11] d5aefea feat: add privacy screen to onboarding + rename tips to tutorials
- [2026-02-11] 96ad324 style: add DS.Semantic, DS.Gradients and DS.Colors.borderDark tokens (DS-COMPLIANCE)
- [2026-02-11] 4cbc40c fix: add iCloud sync waiting screen for new device setup (BUG-22)
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
- **Cross-device wipe coordination (hotfix/1.0.1)** - Señalización via iCloud KV timestamps para que otros dispositivos detecten wipe en segundos (vs minutos de CloudKit). 3 escenarios: wipe remoto→onboarding, wipe+onboarding completo→sync banner, mid-onboarding exit si otro device termina primero. WipeKey enum para type-safety. broadcastSignal param en DataWipeService para evitar loops. Protección contra auto-reacción via lastKnownWipeTimestamp local.
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

### Fase 10.5: Mejoras Pre-Release (V1.1) — ✅ COMPLETADA (2026-02-13)

**Todas las subfases completadas ✅** (A-S). Pre-launch checklist pasado. 524 commits. Mergeado a 1.0.

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
- ✅ **BUG-23: Gráfica de tendencias no muestra punto cuando solo hay un valor** — Resuelto (d7b2970)
- ✅ **BUG-24: Ejes X de gráficas desalineados con barras y puntos** — Resuelto (5b9038a)
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
- ✅ **DS-18: `.font(.system(size:))` hardcoded (~143 en 84 archivos)** — Parcialmente resuelto (ba2aca0). 21 fonts migrables → DS.Typography tokens (9 nuevos). ~70 icon sizing con @ScaledMetric y ~15 amount inputs con .rounded no migrables por diseño.
- ✅ **DS-19: Hardcoded `spacing:` (~237 en 96 archivos)** — Resuelto (13cff73). 23 instancias migrables → DS/WDS tokens (sheetTop, formIndent, WDS.xxl). ~214 restantes son intencionales (micro-ajustes, widgets con spacing:0, non-token values).
- ✅ **DS-20: `DispatchQueue.main.asyncAfter` (~46 ocurrencias)** — Parcialmente resuelto (0aa5597). 4 migraciones seguras (toast 2s, import render 0.1s ×2, splash). 42 instancias de timing UI (<0.4s) mantenidas intencionalmente.
- ✅ **DS-21: Force unwraps (5x) en PreviousPeriodHelper.swift** — Resuelto (3e80433). `?? fallback` preservando return types.
- ✅ **DS-22: Force unwraps (4x) en TransactionCSVImportService.swift** — Resuelto (3e80433). `.map { columns[$0] }` en single y multi-currency.

**S.4 — BAJOS (limpieza):**
- ✅ **DS-23: `@Relationship` en un lado** — Resuelto (eac4749). deleteRule explícito en todas las 33 relaciones.
- ✅ **DS-24: `print()` fuera de `#if DEBUG`** — Resuelto (f586a15). 2 prints en YalaShare/ShareViewController.swift envueltos en #if DEBUG.
- ✅ **DS-25: Código duplicado en QuickExpenseIntent** — Resuelto (fe5b6a7). 3x formatCurrency y 2x findAccount extraídos a funciones file-level.
- 🟢 **DS-26: VoiceTranscriptionService sin @MainActor** — Aceptado. Hacen network calls (OpenAI API), @MainActor bloquearía UI.
- 🟢 **DS-27: `try?` en Task.sleep** — Aceptado. Intencional — solo falla por CancellationError y queremos continuar.
- ✅ **DS-28: InboxDraft.tags inverse** — Resuelto (eac4749). Inverse consolidado en InboxDraft, deleteRule en ambos lados.

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

### Bugs pendientes V1.0

- ✅ **BUG-33: YalaSpark se cruza con el título en ProTrialOfferSheet** — Resuelto (4a57873). Layout compactado, botones dentro de ScrollView, SubscriptionSuccessView al suscribir.

- ✅ **BUG-25: RecordsStandalone no se refresca al crear/aprobar transacciones** — Corregido en cc565b0. Causa: `loadData()` y `applyFilters()` se ejecutaban síncronamente, filters leían datos stale. Fix: `DispatchQueue.main.async` (patrón DetailContainerView).

- ✅ **BUG-26: Share Sheet por imagen falla intermitentemente en uso repetido** — Corregido en bd9231a. Migrado de `hasPendingSharedImage` persistente a patrón one-shot `shouldShowSharedImage`. Eliminado double-trigger en `handleBecameActive`, reset inmediato en observer, cleanup de imágenes stale >24h.

- ✅ **BUG-27: Widget WidgetKit de presupuestos no filtra por naturaleza ni tags** — Corregido en 7040290. Agregados filtros de nature y tags a `WidgetDataCache.calculateBudgetSpent()`, migrado matching de subcategory/account de nombre a ID.
  Síntoma: Si un presupuesto está basado en naturalezas (ej: "Solo gastos fijos"), el widget iOS muestra el total de TODAS las naturalezas en vez del filtrado. La vista Planificación > Presupuestos muestra el número correcto.

  Root cause: `WidgetDataCache.calculateBudgetSpent()` (líneas 422-468) es una copia simplificada de `BudgetsViewModel.getBudgetSpending()` (líneas 198-270) que no se actualizó cuando se agregaron filtros nuevos.

  Filtros comparados:
  | Filtro | Widget (`WidgetDataCache`) | Vista (`BudgetsViewModel`) |
  |--------|---------------------------|---------------------------|
  | Date range | ✓ | ✓ |
  | Account | ✓ (por nombre ⚠️) | ✓ (por ID) |
  | Subcategory | ✓ (por nombre ⚠️) | ✓ (por ID) |
  | **Nature** | **❌ FALTA** | ✓ |
  | **Tag** | **❌ FALTA** | ✓ |
  | Income/Expense | ✓ | ✓ |

  Problema adicional: El widget usa comparación por nombre (`$0.name == tx.subcategory?.name`) en vez de por ID (frágil si se renombra una cuenta/subcategoría).

  Archivos:
  - `Services/WidgetDataCache.swift:422-468` — `calculateBudgetSpent()` (incompleto)
  - `App/ViewModels/BudgetsViewModel.swift:198-270` — `getBudgetSpending()` (correcto)

  Fix propuesto:
  1. Agregar filtro de nature a `calculateBudgetSpent()` (parsear `budget.natures` como en BudgetsVM línea 245-252)
  2. Agregar filtro de tags a `calculateBudgetSpent()`
  3. Migrar matching de nombre a matching por ID para accounts y subcategories

- ✅ **BUG-28: KPI de NatureTrendWidget en Statistics no refleja filtro de naturaleza** — Corregido en 7040290. `totalAmount` y `variation` en NatureTrendWidget ahora respetan `selectedNature`, usando `amount(for:)` en NatureTrendPoint y `previousAmountByNature` para la variación.
  Síntoma: Al seleccionar una naturaleza en Statistics > Categories, el KPI del NatureTrendWidget muestra el total de TODAS las naturalezas. En PanelView, el mismo widget muestra el total filtrado correctamente.

  Root cause: `CategoriesTabView` (línea 1022) construye `natureCriteria` con `selectedNatures: []` explícitamente vacío, ignorando el filtro activo. El widget recibe transacciones sin filtrar por naturaleza y el KPI suma todo.

  Flujo PanelView (correcto):
  - `PanelViewModel.filtered` (línea 742) aplica TODOS los filtros incluyendo nature (líneas 765-772)
  - `expenseFiltered` → `natureWidgetTxns` → `NatureTrendHelper.calculateTrend()` — datos ya filtrados

  Flujo CategoriesTabView (bug):
  - `natureCriteria` (línea 1017-1029) excluye nature filter: `selectedNatures: []`
  - `FilterService.filterForTrends()` devuelve TODAS las naturalezas
  - `NatureTrendWidget` KPI: `trendPoints.reduce(0) { $0 + $1.total }` — suma todo

  Archivos:
  - `App/Views/Statistics/CategoriesTabView.swift:1017-1036` — `natureCriteria` con `selectedNatures: []`
  - `App/ViewModels/PanelViewModel.swift:765-772` — filtro de nature aplicado correctamente
  - `Widgets/NatureTrendWidget.swift:34-36` — KPI suma todos los trendPoints

  Fix propuesto:
  - Pasar `selectedNatures` del filtro activo al `natureCriteria` en CategoriesTabView
  - Mantener el dimming visual para naturalezas no seleccionadas, pero que el KPI refleje solo la seleccionada

### Bugs Pre-Release Pendientes

- ✅ **BUG-25: Banner de trial en Profile** — Resuelto (f66df45): eliminado TrialBanner + sheet + computed props (trial manejado por Apple)
- ✅ **BUG-26: Campo alias visible en perfil** — Resuelto (f66df45): ocultado VStack alias en PersonalDetailsView
- ✅ **BUG-27: "Fecha futura" al editar transacción de hoy** — Resuelto (f66df45): comparación Calendar.day granularity
- ✅ **BUG-28: Botón "Editar" en success abre transacción vacía** — Resuelto (f66df45): flag isEditingFromSuccess evita reset
- ✅ **BUG-29: Widget pagos planificados muestra pagados** — Resuelto (f66df45): filtro !isPaid && !isSkipped en getUpcomingPayments
- ✅ **BUG-29 (prev): Selector de mes falta en Presupuestos** — Resuelto (71d6e92): periodNavigationHeader con chevrones idéntico a ScheduledPaymentsListView
- ✅ **BUG-30: Notificación de resumen del día se envía duplicada** — Resuelto (71d6e92): isSendingReports guard en ReportNotificationService

### Bugs Producción V1.0.1 (reportados 2026-03-09)

Todos deben resolverse para V1.1 (próxima release). Prioridad: crashes > lógica incorrecta > UX > visual.

**Crashes:**
- [x] **BUG-34: Crash en Mac (Designed for Mac) al abrir registro de bandeja** — Resuelto (0d9f04d): conditional `.large` detents on Mac, remove assertionFailure, guard approve-next flows
- [x] **BUG-35: Crash intermitente al eliminar draft en bandeja (swipe + botón)** — Resuelto (0d9f04d): delay SwiftData deletion 400ms post-animation, extract removeDraftWithAnimation helper

**Notificaciones (lógica incorrecta):**
- [x] **BUG-36: Notificaciones llegan a cualquier hora** — Llegan mucho antes de la hora configurada. ✅ c675e9c
- [x] **BUG-37: Notificación de pago planificado ya pagado (vinculado)** — Llega notificación de vencimiento hoy aunque el pago ya fue vinculado a un gasto. ✅ c675e9c
- [x] **BUG-38: Pago no vinculado no crea registro en bandeja** — Tenía 2 pagos venciendo hoy (1 vinculado, 1 no). Llegaron ambas notificaciones pero no se creó draft en bandeja para el no vinculado. ✅ c675e9c
- [x] **BUG-39: Notificación "vence en 3 días" pero realmente son 4** — Cálculo de días restantes off-by-one. ✅ c675e9c

**Filtros / Lógica:**
- [x] **BUG-40: Filtro subcategoría ingreso bloquea mal en PanelView** — Resuelto (1b9d9fc)
- [x] **BUG-41: Orden de búsqueda diferente a registros** — Resuelto (1b9d9fc)

**Race Conditions:**
- [x] **BUG-42: Race condition Share Sheet imagen + notificación in-app de bandeja** — Resuelto (ecc7758), QA pendiente
- [x] **BUG-43: Race condition Share Sheet imagen + Face ID** — Resuelto (ecc7758), QA pendiente

**Widget:**
- [x] **BUG-44: Widget de presupuestos no se actualiza automáticamente** — Desestimado

**iPad / Layout:**
- [x] **BUG-45: Calendario de fecha recortado en iPad (registro)** — Resuelto (bab15ee)
- [x] **BUG-46: Sheet de success recortada en iPad** — Resuelto (bab15ee)

**UX / Visual:**
- [x] **BUG-47: Animación de success pestañea** — Resuelto (e1f1a70)
- [x] **BUG-48: Pago recurrente muestra PEN aunque cuenta sea otra moneda** — Desestimado
- [x] **BUG-49: Exportación dice CSV pero permite Excel, periodo va 10 años atrás** — Resuelto (0f85f55)
- [x] **BUG-50: Selectores de fecha sin botón de guardar** — Resuelto (b28c7c2)
- [x] **BUG-51: Ocultar naturaleza para ingresos en registro/edición/aprobación** — Resuelto (1b9d9fc)
- [x] **BUG-52: Etiquetas de datos en CashFlow filtrado** — Resuelto (56968cb)

**Rediseños pendientes (UX crítico):**
- [x] **BUG-53: Rediseño flujo pagos planificados/recurrentes** — Resuelto (dd86e0c + 847b4eb)

**Infraestructura:**
- [x] **BUG-54: Implementar Telemetry Deck** — Resuelto (f890824): 12 eventos privacy-first via TelemetryDeck SDK.

**FAB / Registro:**
- [x] **BUG-55: FAB no muestra las 3 opciones de registro intermitentemente** — Resuelto (701d743): FAB siempre muestra 3 opciones, consent alert inline para Pro, ProBadge para Free. AIConsentAlertModifier extraído a ViewModifiers.swift.

**Suscripción:**
- [x] **BUG-56: Expiración de suscripción Pro no se refleja en tiempo real** — Resuelto (8474ddf): refreshSubscriptionStatus() en handleBecameActive con cancel-before-create Task.

### Bugs QA V1.2 (reportados 2026-03-12)

**Filtros / Lógica:**
- [ ] **BUG-57: Metric buttons de TrendWidget no bloquean correctamente con filtros de ingreso** — Al filtrar subcategorías de ingreso en Statistics y volver a PanelView, el botón "Gastos" sigue habilitado (debería bloquearse). Al presionarlo se bloquea "Ingresos" y "Balance", quedando en estado incongruente. Con subcategorías de gasto funciona bien (bloquea balance e ingresos). Root cause: `hasExpenseOnlyFilters` en TrendWidget.swift bloquea `type != .expense`, pero debería ser dinámico según el tipo de subcategorías filtradas (expense vs income). Archivo: `App/Views/Panel/TrendWidget.swift` líneas 19-26 y 120-155.

**Performance:**
- [ ] **BUG-58: CloudKit remote change triggers excesivos — "AppBootstrapper: Remote CloudKit change detected — refreshing UI" aparece triplicado** — Causa lentitud general y hace que la animación de success al crear transacción pestañee/se sienta lenta. Cada cambio remoto de CloudKit dispara múltiples refreshes de UI innecesarios. Investigar: debounce de refreshes, batch CloudKit notifications, o throttle de UI updates.

**Visual / Layout:**
- [ ] **BUG-59: ProBadge en FAB no alineado a la derecha** — En los menús FAB (PanelView, DetailContainerView, RecordsStandaloneView), el ProBadge debería estar alineado a la derecha del botón para verse ordenado. Actualmente está posicionado justo después del texto. Archivos: `App/Views/Panel/PanelView.swift`, `App/Views/Statistics/DetailContainerView.swift`, `App/Views/Records/RecordsStandaloneView.swift` — función `fabMenuButton`.

- [ ] **BUG-60: Data labels en CashFlow no deberían mostrarse en modo Balance** — Las etiquetas de datos sobre barras (cuando hay ≤10 barras) deberían mostrarse solo en modo Ingreso o Gasto, no en Balance (bidireccional). En modo balance los labels son confusos porque hay barras en ambas direcciones. Archivo: `App/Views/Panel/CashFlowWidget.swift` — condición `showLabels` en línea 456.

- [ ] **BUG-61: Cards de resumen rápido en Insights no fuerzan mismo tamaño cuando falta 3ra línea** — Cuando "Promedio diario" es 0 (por filtrar solo ingresos), la card pierde la 3ra línea (variation chip) y queda más corta que las demás. La técnica de `opacity(0)` para reservar espacio no está funcionando correctamente en ese caso. Archivos: `App/Views/Statistics/InsightsTabView.swift` líneas 376-403, `App/Views/Statistics/Components/QuickStatCell.swift`.

**Lógica de negocio:**
- [ ] **BUG-62: Presupuestos en vista Compromisos se desbordan al cambiar periodo a "Este año"** — Los presupuestos son mensuales pero la suma de transacciones al cambiar a "Este año" acumula todo el año, mostrando montos que exceden enormemente el límite mensual. **Decisión:** Los presupuestos deben mantener su propio periodo y mostrar siempre el último visible (mensual → este mes, anual → este año, etc.), ignorando el periodo global de Compromisos. Además, añadir título o nota aclaratoria en la sección de presupuestos dentro de Compromisos indicando el periodo real que se muestra.

**Notificaciones:**
- [ ] **BUG-63: Notification primer post-3ra transacción no activa alertas de presupuestos** — Al aceptar notificaciones desde el banner (después de la 3ra transacción), se activan todas las notificaciones seeded excepto las alertas de presupuestos. Las demás (endOfDay, lunchTime, dailyReport, weeklyReport, monthlyReport, scheduledPayments) sí se activan. Archivo: `App/Views/Notifications/NotificationPrimerSheet.swift` línea 89-112 — el loop activa todos los NotificationItem seeded pero las alertas de presupuesto usan un mecanismo diferente (BudgetAlertService con toggle por presupuesto, no NotificationItem).

### Fase 11: Sistema de Temas Independientes (V1.2) — ✅ COMPLETADA (2026-02-19)

Refactorización completa del sistema de colores. 6 temas (3 free + 3 PRO). YalaTheme struct + ThemeColor ShapeStyle + @Observable ThemeManager. Cambio de tema sin reinicio (eliminado `.id(userThemeRaw)`). 0 usos de colores legacy. 12 escenarios QA (Sección 38).

### Fase 11.5: Polish Pre-Fase 12 — ✅ COMPLETADA (2026-02-24)

- [x] POLISH-1: Budget progress bar — hotPink en widget para excedido (consistencia con app)
- [x] POLISH-2: Badge "Recurrente" en edición de transacción (chip pill en quickActionsBar)
- [x] POLISH-3: Tipo cuenta tarjeta de crédito + notificación de pago (AccountType, form, reminder)

### Siguiente: Fase 12 — Plataforma Extendida (V1.2)

**Prioridad: Tech Debt del Release Review (10 items)**

Empty States:
- [x] EMPTY-1: Widgets migrados a `YalaEmptyState` con `Style.widget` (11 widgets, ~200 LOC eliminados)
- [x] EMPTY-3: Empty state `YalaEmptyState.noAccounts` en Panel cuando 0 cuentas
- [x] EMPTY-5: Autocomplete muestra "Sin resultados" cuando mención activa sin matches

Accessibility:
- [x] A11Y-DT: Migrar `.font(.system(size:))` a Dynamic Type — 2 fixes (@ScaledMetric + DT cap), 47 archivos auditados con comentarios A11Y-DT

Code Quality:
- [x] CODE-20: Tags relationship — already resolved, Tag.swift declares inverse:\TransactionItem.tags (SwiftData only needs one side)
- [x] CODE-21: Triple save en creación de transfer — reducido a 1 save atómico (8665498)
- [x] CODE-28: Bulk delete — added processPendingChanges() for @Query consistency (8665498)
- [x] CODE-30: Removed dead `month`/`year` from Budget model (552c664). `category`/`currencyCode`/`limitAmount` kept — still used.
- [x] CODE-32: Migrated 3 DispatchQueue.main.asyncAfter → Task.sleep in BudgetPeriodSelectorSheet (552c664)
- [x] CODE-41: Direct modelContext.save() bypasea DraftService — FALSE ALARM, InboxView already uses DraftService correctly
- [x] CODE-46: Search views extracted to App/Views/Search/GlobalSearchView.swift (40391ba). ContentView 1212→796 LOC.

Fase 12 completados:
- [x] iPad/Mac layouts adaptados ✅ (e2a69fd)
- [x] Línea promedio en gráficas de barras ✅ (44d3b89)
- [x] Siri registro rápido ✅
- [x] Lock Screen widgets ✅
- [x] Filtros avanzados: excluir/incluir en DetailContainerView ✅ (1716c2d..fe9eebd)

Fase 12 siguiente (en orden):
- [x] **Refactor filtros deferred** — RecordsFiltersView usa estado local, "Aplicar" escribe a SessionState, "X" descarta. Prerequisito para Smart Insights. (81559d6)
- [x] **Smart Insights** — Nueva tab en Statistics con KPIs, gráficas, textos inteligentes (Free: rule-based, Pro: LLM). Funcionalidad (3439fe3) + UI refinement (daa9b03)

Ver ROADMAP.md para más detalles de Fase 12.

### Pendiente: Reubicación de pasos eliminados del onboarding (post-redesign 82f4e5c)

Estos pasos se eliminaron del onboarding para reducirlo de 9→7 pasos. Cada uno necesita un nuevo momento y mecanismo en la app:

| Funcionalidad eliminada | Nuevo momento | Mecanismo |
|-------------------------|---------------|-----------|
| Divisas secundarias | Settings > Divisas, o al crear cuenta en otra divisa | Ya existe en CurrencySettingsView. Falta: prompt contextual al crear cuenta con divisa diferente |
| Periodo predeterminado | Default "Este mes", cambiable en filtros | Ya implementado (hardcode .thisMonth en onboarding). Sin trabajo adicional |
| Notificaciones (7 toggles) | Después de 3-5 transacciones | Pendiente: pre-permission primer full-screen que invite a activar notifs |
| Tutoriales | Primeras interacciones en Panel | Pendiente: tooltips in-context / coach marks para funciones clave |

**Estado:**
- [x] Prompt contextual divisas secundarias — alert en AccountFormView al crear cuenta con divisa ≠ preferred (max 2 slots)
- [x] Periodo default .thisMonth (ya funciona)
- [x] Pre-permission primer para notificaciones — NotificationPrimerSheet después de 3ra transacción nueva
- [x] Tooltips / coach marks post-onboarding — custom CoachMarkOverlay system with 4 tours (Panel 5 steps, Registro 3 steps, Settings 7 steps, Interactivity 2 steps) + ComparisonTip (TipKit)

### Refactors Pendientes: Filtros Excluir/Incluir (identificados 2026-03-05)

Descubiertos durante simplify + audit de la feature de filtros excluir/incluir. No bloquean funcionalidad pero acumulan deuda técnica.

**RF-1: PanelViewModel — 3 copias inline de FilterService (~200 LOC)** ✅ Completado (eab0c8d)
3 pases de filtrado reemplazados por `buildFilterCriteria()` + `FilterService.matchesCriteria()`. También: fix nature nil → `.unclassified`, search narrowed to note-only. `pieWidgetContext` (líneas 1021-1089) sigue inline — evaluar en RF futuro.
- **Solución propuesta:** Construir `FilterCriteria` y llamar `FilterService.filter()`. Para variantes (sin fecha, balance), usar criterias modificados o añadir flags opcionales a `FilterCriteria`.
- **Esfuerzo:** Medio — requiere entender las 3 variantes y mapearlas correctamente.

**RF-2: hasActiveFilters / activeFilterCount duplicados en 4 lugares** ✅ Completado (fe9eebd)
Fix: searchText faltaba en `FilterCriteria.activeFilterCount`. RecordsVM y StatisticsVM delegan a `FilterCriteria` via `Filterable.filterCriteria`. Protocolo extendido con `activeFilterCount`, `isExcludeMode`, `selectedTransactionNatures`.

**RF-3: processChartData() llamado 5+ veces por render en pie widgets** ✅ Completado (932dd00)
Computed `chartData` eliminado de 3 widgets. `body` computa una vez via `let`, threading por parámetro a todas las funciones hijas.

### Refactors Pendientes: Statistics Control Bar (identificados 2026-03-06)

Descubiertos durante simplify de Smart Insights UI refinement. No bloquean funcionalidad.

**RF-4: controlBar duplicado en 4 tabs (~160 LOC × 4)** ✅ Completado (7f01298)
- Extraído `FilterControlBar<VM: Filterable & Observable, PeriodView, TrailingContent>` compartido
- 4 tabs migrados: Trends, Categories, Insights, Records (~790 líneas eliminadas)

**RF-5: Chip helpers duplicados en 4 tabs** ✅ Completado (7f01298)
- `buildAccountChips`, `buildTagChips`, `buildNatureChips` movidos a `FilterChipHelper.swift`
- Eliminados computed properties duplicados de los 4 tabs

### Refactor Completado: CurrencyConverting Protocol (2026-03-11) ✅

**Problema resuelto:** 7 calculators/helpers no tenían tests porque requerían `ModelContext` en firma (CloudKit crash en tests).

**Solución implementada:**
- Protocolo `CurrencyConverting` (context-free) con `convert()` y `convertWithLatestRate()`
- `CurrencyConverter.shared.setContext()` en bootstrap (patrón existente de BudgetAlertService)
- `MockCurrencyConverter` para tests con `fixedRate` configurable
- 7 calculators/helpers: `context: ModelContext` → `converter: CurrencyConverting = CurrencyConverter.shared`
- ~15 call sites actualizados en ViewModels/Views
- `TrendDataProcessor.processTrendData`: eliminado parámetro `context:` muerto

**Tests desbloqueados (68 tests, 7 suites nuevas):**
CashFlowCalculatorTests (18), BalanceTrendCalculatorTests (8), WeekdaySpendingCalculatorTests (8), TopSpendingCategoriesCalculatorTests (10), TopSubcategoriesCalculatorTests (8), BalanceHelperTests (8), NeedTrendHelperTests (8)

**Componentes aún sin tests (requieren ModelContext propio):**
TransactionService, EntityDeletionService, MerchantMemoryService, CurrencyChangeService, ExchangeRateService

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

## Deferred Features

### Panel Balance Breakdown (saldo desglosado)

**Status:** Diferido — documentado para implementación futura.

**Concepto:** Mostrar desglose "Disponible / Pendiente" en Panel cuando el usuario tiene tarjetas de crédito con saldo ≠ 0, dando contexto sobre cuánto del saldo total es realmente disponible vs consumo pendiente.

**Complejidades identificadas:**
- **Panel:** Fila "Disponible / Pendiente" debajo del carousel — requiere patrón visual nuevo (no hay precedente de 2 KPIs lado a lado ahí). Solo mostrar cuando no hay cuenta seleccionada AND existen TCs con saldo ≠ 0.
- **TrendsTabView:** La gráfica de tendencia de saldo muestra una línea. Si queremos desglose visual, necesitaríamos dos líneas o área apilada — cambio significativo en `TrendChartView`, `TrendWidget`, y procesamiento de datos en `PanelViewModel`.
- **Conversión multi-divisa:** El desglose necesita convertir saldos de cuentas en distintas divisas a la preferida, usando `BalanceHelper` pattern.
- **Redundancia parcial:** El carousel ya muestra saldos individuales por cuenta. Evaluar si el desglose agrega valor suficiente vs ruido visual.
- **Archivos impactados:** `PanelViewModel.swift` (nuevo método `balanceBreakdown()`), `PanelView.swift` (fila condicional), `TrendWidget.swift`, `TrendsTabView.swift`, `TrendChartView.swift`, localization (×6).

## Session Continuity

Last session: 2026-03-13
Stopped at: Financial Report — MVP funcional, pendiente ajustes y testing
Next step: Ajustes y testing del Financial Report antes de avanzar
Resume context:
- MVP funcional: pivot table, grouping reorder, net flow summary, tab integration
- **Pendiente ajustes UI:**
  - Drag handles en GroupingReorderSheet — solo Tipo los muestra, los demás no (bug con editMode)
  - Verificar visualmente tamaños de fuente en GroupingChipsBar (reducidos a .caption)
  - Verificar NetFlowSummaryView se ve alineado con filas de Ingresos/Gastos
- **Pendiente testing filtros:**
  - Filtros de cuenta, categoría, subcategoría, tags, naturaleza, divisas en el reporte
  - RecordsFiltersView genérico (ahora Filterable & Observable) — verificar que funciona igual en Records y Reports
  - Modo exclusión de filtros
  - Filtro por monto (amountCondition)
  - searchText en contexto de reportes
- **Pendiente testing general:**
  - Cambio de periodo (mes/semana/año/custom) actualiza pivot table
  - Comparación con periodo anterior (variaciones correctas)
  - Moneda preferida se refleja correctamente (fix: defaultCurrencyCode)
  - Reorder de dimensiones se persiste y actualiza la tabla
  - Toggle dimensiones (activar/desactivar) funciona correctamente
  - Empty state cuando no hay datos
- **Pendiente funcionalidad:**
  - Cash flow tab (placeholder actual)
  - onChange handlers: 12 separados podrían causar recálculos redundantes
