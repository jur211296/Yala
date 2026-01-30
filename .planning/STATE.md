# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-15)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 10 — Refinamiento & Notificaciones (V1.1)

## Current Position

Version: 1.1
Phase: 10 — Refinamiento & Notificaciones
Spec: None
Plan: TBD
Status: **V1.0 COMPLETA** — Iniciando V1.1
Last activity: 2026-01-27 — Fase 9 cerrada, V1.0 lista para release

Progress: V1.0 ████████████████ 100% ✅
Progress: V1.1 ███████████████░ ~95% (Fase 8 completa, Fase 10 casi completa - 1 item UAT pendiente)

---

## Recent Progress
<!-- Últimos 10 commits registrados automáticamente por /commit-one -->
- [2026-01-30] c1457e8 fix(ui): correct theme switching, expandable lists, and capsule buttons
- [2026-01-30] 2fe8d26 feat(ui): add expandable currency lists in settings (E.4)
- [2026-01-30] a1fe45b refactor(ui): reorder Preferences section items (E.3)
- [2026-01-30] b40079b fix(ui): force sheet dismiss when selecting System theme (E.2)
- [2026-01-30] 07f9293 fix(ui): align recurrence selectors to the right (E.1)
- [2026-01-30] e64b18f fix(ui): change inbox icon to tray.fill for toolbar consistency
- [2026-01-30] 169e059 Revert "fix(ui): change toolbar icons from filled to outline style (D.2)"
- [2026-01-30] c3a625e fix(ui): change onboarding buttons to capsule style (D.5)
- [2026-01-30] 2bee962 feat(ui): add filter indicator to TrendsTabView and CategoriesTabView (D.3)
- [2026-01-30] f8fc6da fix(ui): change toolbar icons from filled to outline style (D.2)

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
- **Auditoría de código (10.x)** - **CRÍTICOS: TODOS RESUELTOS ✅** SEC-001/002 (keys seguras), ERR-001-004 (try? → do-catch), BUG-001-005 (force unwraps → guard), SWD-001-004 (inversas SwiftData), PERF-001-003 (optimizado O(n)), CFG-001/002 (config correcta); **ALTOS: TODOS RESUELTOS ✅** SEC-003/004/005/006 (security hardening), BUG-006-011 (bounds, threading), SWD-005/006/007 (@MainActor), PERF-004/005/006 (static formatters), UI-001/002 (accessibility); **PENDIENTES:** ARCH-001-006 (refactors arquitecturales - planificación requerida)

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

### Fase 10: Refinamiento & Notificaciones (V1.1)

**Completados:**
- [x] Pagos planificados crean transacción en bandeja de entrada ✅ (35de0f7)
- [x] Integración Share Sheet para enviar imágenes directamente ✅ (e5c3dfd, 12f7830, 616ec4d)
- [x] Revisar prompts voz: tildes crean etiquetas duplicadas ✅ (669b537)
- [x] FAB fuera de PanelView no tiene opción de registro de imagen ✅ (669b537)
- [x] Pedir permiso de micrófono al activar toggle ✅ (12e054f)
- [x] Pedir permiso de fotos al activar toggle ✅ (12e054f)
- [x] Mejorar onboarding: seed de categorías predeterminadas ✅ (ecce7fb)
- [x] Vaciar datos: ofrece seed via onboarding ✅
- [x] Notificaciones: recordatorio de registro, reporte semanal/mensual, pagos planificados, anuncios ✅ (0eb8561, fbc89f5, 1f398a3, f0c9d74)
- [x] Atajos Siri/Shortcuts (Registro rápido, Voz, Imagen) ✅ (9f6bd37, 93dbeeb)
- [x] Automatización Apple Pay ✅ (4b2eab4) — Intent recibe datos de Wallet, crea draft en inbox
- [x] Automatización externa ✅ (caa04cc) — Intent recibe JSON para correos de banco procesados por IA

**Pendientes (17 items restantes - UAT 2026-01-30):**

**10.A: Bugs Críticos**
- [x] A.1: PanelView no reacciona inmediatamente al crear cuenta, importar CSV o crear registros ✅ (95b3ec7)
- [x] A.2: Filtro texto SearchBar sincronización con navegación directa a Statistics ✅ (bf8e2d6)
- [x] A.3: FAB no se cierra al navegar a otra pestaña (PanelView y StatisticsView) ✅ (381c041)
- [x] A.4: Vista "Yala está bloqueada" no aparece si estabas en sheet de perfil ✅ (7d0138c)

**10.B: Lógica de Negocio**
- [x] B.1: Transacciones futuras - BLOQUEAR con validación ✅ (acaeb92)
  - **Decisión:** Bloquear transacciones con fecha > hoy (previene inconsistencia balance vs registros)
  - **Implementación:**
    1. NewTransactionViewModel.save() - Alert informativo sugiriendo Pagos Planificados
    2. DraftService.approveDraft() + bulkApprove() - throw DraftServiceError.futureDateNotAllowed
    3. TransactionCSVImportService.importCSV() - Filtrar + contar ignoradas + notificar usuario
  - **Cobertura:** Creación manual, duplicar, inbox (voz/imagen/ApplePay/automation/pagos), importación CSV/XLSX

- [x] B.2: Orden de registros del mismo día - agregar campo createdAt ✅ (c6c4dd9)
  - **Implementación:**
    1. Agregar `var createdAt: Date = Date()` a modelo TransactionItem (timestamp completo con hora)
    2. Actualizar FetchDescriptors: `sortBy: [.date DESC, .createdAt DESC]`
    3. Migración SwiftData: para registros existentes `createdAt = date`
  - **Comportamiento:**
    - Creación manual: createdAt = Date() al momento de guardar
    - Aprobación drafts: createdAt = Date() al momento de aprobar (no draft.createdAt)
    - Importación CSV: createdAt = Date() al momento de importar
  - **Resultado UX:** Registros del mismo día aparecen en orden de creación/aprobación (más reciente primero)

- [x] B.3: Widget pagos planificados solo gastos ✅ (1cb68f2)
  - **Archivos:**
    1. ScheduledPaymentsWidget.swift:207 calculateMonthlyTotal() - filtrar `payment.transactionType != "income"`
    2. Vista principal pagos planificados (cajas superiores) - aplicar mismo filtro
  - **Test:** Crear pago planificado tipo ingreso, verificar que NO cuenta en totales

**10.C: Widgets** ✅ COMPLETA
- [x] C.1: Hover widget presupuestos no fuerza vista Presupuestos (te lleva a donde estabas en Planificación) ✅ (3008b95)
- [x] C.2: Widget Presupuestos muestra siempre divisa preferida, no la del presupuesto específico ✅ (3354706)
- [x] C.3: Widgets pieCategories y pieSubcategories sin icono informativo ✅ (110baf3)
- [x] C.4: Icono informativo en widget Pagos planificados mal posicionado (entre título y subtítulo vs arriba del título) ✅ (f0d6f97)

**10.D: Consistencia Visual** ✅ COMPLETA
- [x] D.1: Label "hoy" en tendencias se sobrepasa a la zona del eje Y ✅ (e87687b)
- [x] D.2: Todos los iconos del toolbar deben ser no filled (outline) ✅ (f8fc6da)
- [x] D.3: Indicador de filtros solo en RecordsTabView, falta en TrendsTabView y CategoriesTabView ✅ (2bee962)
- [x] D.4: Icono informativo en CashFlow debe ir en título "Flujo de efectivo", no repetido en cada gráfica ✅ (b802c9e)
- [x] D.5: Botones onboarding y FaceID no son capsule - auditar todos los botones del proyecto ✅ (c3a625e)

**10.E: Settings y Preferencias** ✅ COMPLETA
- [x] E.1: Selectores "1" y "Mes" en Recurrencia de pago planificado deben alinearse a la derecha ✅ (07f9293)
- [x] E.2: Al elegir tema Sistema, no fuerza la sheet (sí lo hace para Claro y Oscuro) ✅ (b40079b)
- [x] E.3: Reordenar Preferencias: Personalización, Notificaciones, Divisa y Cambio, Ícono de app, Temas, Registro por voz, Registro por imagen ✅ (a1fe45b)
- [x] E.4: Listas expansibles para divisas (preferida: 1+expansión, secundarias: 1-2+expansión, tipos cambio: secundarias+expansión) ✅ (2fe8d26)

**10.F: Desarrollo**
- [ ] F.1: Seed Dev completa para onboarding (solo bundle dev) - cuentas, categorías, subcategorías, etiquetas, presupuestos, pagos planificados, suscripciones, favoritos

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

Last session: 2026-01-30
Stopped at: Sección E COMPLETA - 4 items de settings completados (2fe8d26)
Next step: Continuar con F.1 (Seed Dev) - último item UAT
Resume context:
- V1.0 completa (Fases 1-9 todas done)
- V1.1: Fase 8 done, Fase 10 en progreso
- **Sección A COMPLETA:** 4/4 bugs críticos ✅
- **Sección B COMPLETA:** 3/3 lógica de negocio ✅
  - ✅ B.1: Bloquear fechas futuras (acaeb92)
  - ✅ B.2: Campo createdAt para orden mismo día (c6c4dd9)
  - ✅ B.3: Widget pagos planificados solo gastos (1cb68f2)
- **Sección C COMPLETA:** 4/4 widgets ✅
  - ✅ C.1: Navegación a vista Presupuestos (3008b95)
  - ✅ C.2: Divisa del presupuesto (3354706)
  - ✅ C.3: InfoHintButton en pie charts (110baf3)
  - ✅ C.4: InfoHintButton alineado en pagos (f0d6f97)
- **Sección D COMPLETA:** 5/5 consistencia visual ✅
  - ✅ D.1: Label "hoy" spacing fix (e87687b)
  - ✅ D.2: Toolbar icons outline (f8fc6da)
  - ✅ D.3: Filter indicators (2bee962)
  - ✅ D.4: CashFlow InfoHintButton consolidado (b802c9e)
  - ✅ D.5: Onboarding capsule buttons (c3a625e)
- **Sección E COMPLETA:** 4/4 settings ✅
  - ✅ E.1: Selectores recurrencia (07f9293)
  - ✅ E.2: Tema Sistema sheet (b40079b)
  - ✅ E.3: Reordenar Preferencias (a1fe45b)
  - ✅ E.4: Listas expansibles divisas (2fe8d26)
- **1 item UAT restante:** F.1 (Seed Dev)
- **20 completados de 21** (95% progreso Fase 10)

## V1.1 (Futuro)

Registro Inteligente y Plataforma diferidos. Ver:
- .planning/PHASE8-REGISTRO-SPEC.md
- ROADMAP.md (Fases 8-9)
