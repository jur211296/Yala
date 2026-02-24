# Flow Review — Revisión completa de flujos

> **Objetivo:** Revisar cada flujo del proyecto verificando funcionalidad, diseño, bugs, claridad y UX.
> **Inicio:** 2026-02-23
> **Estado:** En progreso

---

## Progreso general

| # | Grupo | Estado | Issues ALTA | Issues MEDIA | Issues BAJA | Fixes aplicados |
|---|-------|--------|-------------|--------------|-------------|-----------------|
| 1 | Launch & First-Run | Revisado + fixes | 3 → 0 | 8 → 2 | 7 | 7 fixes |
| 2 | Autenticación | Revisado (limpio) | 0 | 0 | 1 | — |
| 3 | Panel (Home) | Revisado + fixes | 4 → 0 | 10 → 2 | ~20 | 12 fixes |
| 4 | Statistics + Records | Revisado + fixes | 0 | 14 → 0 | ~10 | 14 fixes |
| 5 | Transaction CRUD | Revisado + fixes | 5 → 0 | 12 → 5 | ~8 | 5 fixes + 2 skip |
| 6 | Inbox (Smart Recording) | Revisado + fixes | 1 → 0 | 6 → 0 | 0 | 8 fixes |
| 7 | Planning | Pendiente | — | — | — | — |
| 8 | Global Search | Pendiente | — | — | — | — |
| 9 | Profile & Settings | Pendiente | — | — | — | — |
| 10 | Upgrade/Paywall | Pendiente | — | — | — | — |
| 11 | More Tab | Pendiente | — | — | — | — |
| 12 | Widget Deep Links | Pendiente | — | — | — | — |
| 13 | Share Extension | Pendiente | — | — | — | — |
| 14 | Siri/Shortcuts | Pendiente | — | — | — | — |

---

## Grupo 1: Launch & First-Run

### Archivos revisados

| Archivo | Flujo |
|---------|-------|
| `Yala/App/Views/SplashScreenView.swift` | 1.1 Splash Screen |
| `Yala/App/ContentView.swift` | 1.2 iCloud Sync Wait, 1.6 Remote Wipe, orchestration |
| `Yala/App/Views/Onboarding/LanguageSelectionView.swift` | 1.3 Language Selection |
| `Yala/App/Views/Onboarding/OnboardingView.swift` | 1.4 Onboarding (8 pasos) |
| `Yala/App/Views/Subscription/ProTrialOfferSheet.swift` | 1.5 Pro Trial Offer |
| `Yala/App/Views/BiometricLockOverlay.swift` | 1.7 Biometric Lock |
| `Yala/App/Services/BiometricAuthService.swift` | 1.7 Biometric Lock (service) |
| `Yala/Utils/L10n.swift` | LanguageManager |
| `Yala/Seed/CategorySeed.swift` | Seed categories |
| `Yala/Utils/DataWipeService.swift` | Wipe flags |

### Issues encontrados

#### ALTA (3) — TODOS CORREGIDOS

| ID | Archivo:Línea | Descripción | Estado |
|----|---------------|-------------|--------|
| G1-O1 | `OnboardingView.swift:1117-1121` | Animación de categorías no se triggerea si el usuario hace swipe (TabView `.page` permite swipe libre) | CORREGIDO — `.scrollDisabled(true)` |
| G1-O2 | `OnboardingView.swift` (TabView) | Swipe libre permite saltarse pasos del onboarding sin completar datos intermedios | CORREGIDO — `.scrollDisabled(true)` (mismo fix que O1) |
| G1-C1 | `ContentView.swift` (splash/sync) | Flash de fondo vacío entre splash fadeout y sync-wait/onboarding si el timing es justo | CORREGIDO — splash espera `isInitialCheckDone` antes de fadeout |

#### MEDIA (8) — 6 CORREGIDOS, 2 PENDIENTES

| ID | Archivo:Línea | Descripción | Estado |
|----|---------------|-------------|--------|
| G1-S1 | `SplashScreenView.swift:138` | `Timer.scheduledTimer` a 20fps creando animaciones con `dsWithAnimation` — posibles frame drops. Considerar `TimelineView` o `Canvas` | PENDIENTE |
| G1-C2 | `ContentView.swift:307-315` | `modelContext.fetchCount` para TransactionItem se llama 15 veces cada 2s en el sync-wait loop. Eficiente (count query) pero podría causar brief hitches | PENDIENTE |
| G1-L1 | `LanguageSelectionView.swift:15` | Default hardcodeado `selectedLanguage = "en"`. Dispositivo en japonés región Perú → debería pre-seleccionar español | CORREGIDO — `LanguageManager.closestSupportedLanguage` detecta por región |
| G1-O3 | `OnboardingView.swift:1339-1351` | `SeedCategoryPreview.categories` con nombres hardcodeados en español. No respeta idioma seleccionado | CORREGIDO — usa `L10n.Category.*` |
| G1-O4 | `OnboardingView.swift:1154` | Campo nombre permite caracteres especiales, emojis, sin límite de longitud | PENDIENTE (bajo impacto) |
| G1-O5 | `OnboardingView.swift:1172` | `hasCompletedOnboarding = true` se setea ANTES de crear account/categories/notifications. Crash mid-setup deja estado inconsistente | CORREGIDO — flag movido después de data creation |
| G1-P1 | `ProTrialOfferSheet.swift:71-77` | Si `loadProducts()` falla, muestra `ProgressView()` infinito. Sin timeout ni error | CORREGIDO — muestra error con botón "Reintentar" si products vacío |
| G1-W1 | `ContentView.swift:132-133` | Remote wipe confirm no resetea `seedCategoriesExecuted`/`notificationsSeeded`. Re-onboarding no puede crear datos | CORREGIDO — resetea ambos flags |

#### BAJA (7) — PENDIENTES (no bloquean)

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G1-S2 | `SplashScreenView.swift` (Particle struct) | `let id = UUID()` crea nuevo UUID en cada ciclo de ForEach. Funciona pero no ideal para identidad estable |
| G1-S3 | `SplashScreenView.swift` | Sin `accessibilityLabel`. VoiceOver no anuncia nada durante splash (aceptable por ser temporal) |
| G1-C3 | `ContentView.swift:363` | Botón "Skip" en sync-wait sin `accessibilityHint` explicando que irá al onboarding |
| G1-L2 | `LanguageSelectionView.swift` | Sin animación de transición al aparecer como `fullScreenCover`. Abrupto comparado con splash |
| G1-O6 | `OnboardingView.swift:48` | `availablePeriods` incluye `lastMonth`/`lastYear` que son períodos temporales. Puede confundir como default |
| G1-O7 | `OnboardingView.swift:1235-1264` | `loadHistoricalRatesForSecondaryCurrencies` en `Task` sin capturar errores de red. Falla silenciosamente |
| G1-P3 | `ProTrialOfferSheet.swift:103` | URL hardcodeada `"https://yala-app.pe/terms"`. Debería estar en constants file |

#### P2 MEDIA reclasificado a BAJA

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G1-P2 | `ProTrialOfferSheet.swift:315` | `planPeriodLabel` para monthly retorna `L10n.Subscription.perMonth("")` — posible espacio extra en localización |

---

## Grupo 2: Autenticación

### Archivos revisados

| Archivo | Flujo |
|---------|-------|
| `Yala/App/Views/BiometricLockOverlay.swift` | Lock screen |
| `Yala/App/Services/BiometricAuthService.swift` | Auth service |

### Issues encontrados

#### BAJA (1)

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G2-B1 | `BiometricLockOverlay.swift:61` | `accessibilityHint("Autenticando")` hardcodeado en español, no usa `L10n` |

### Notas positivas
- Race condition prevention con `isAuthenticating` flag correcto
- Timeout configurable almacenado en Keychain (seguro)
- `deviceOwnerAuthentication` permite passcode fallback
- Auto-trigger en `onAppear`
- `didEnterBackground` flag evita lock falso por system dialogs

---

## Grupo 3: Panel (Home)

### Archivos revisados

#### PanelView + ViewModel (2 archivos)

| Archivo | Propósito |
|---------|-----------|
| `Yala/App/Views/Panel/PanelView.swift` | Vista principal del Panel/Home |
| `Yala/App/ViewModels/PanelViewModel.swift` | ViewModel con filtrado, cálculos, widgets |

#### Widgets del Panel (20 archivos)

| Archivo | Widget |
|---------|--------|
| `Yala/App/Views/Panel/AccountsCarouselView.swift` | Carrusel de cuentas |
| `Yala/App/Views/Panel/AccountCardView.swift` | Tarjeta individual de cuenta |
| `Yala/App/Views/Panel/TrendWidget.swift` | Widget de tendencia |
| `Yala/App/Views/Panel/TrendChartView.swift` | Chart de tendencia |
| `Yala/App/Views/Panel/TopCategoriesWidget.swift` | Top categorías (limpio) |
| `Yala/App/Views/Panel/TopSubcategoriesWidget.swift` | Top subcategorías |
| `Yala/App/Views/Panel/CategoriesPieWidget.swift` | Pie de categorías |
| `Yala/App/Views/Panel/SubcategoriesPieWidget.swift` | Pie de subcategorías |
| `Yala/App/Views/Panel/TagsPieWidget.swift` | Pie de etiquetas |
| `Yala/App/Views/Panel/CashFlowWidget.swift` | Flujo de caja |
| `Yala/App/Views/Panel/RecentRecordsWidget.swift` | Últimos registros (limpio) |
| `Yala/App/Views/Panel/NatureTrendWidget.swift` | Tendencia por naturaleza |
| `Yala/App/Views/Panel/ExchangeRateWidget.swift` | Tipo de cambio |
| `Yala/App/Views/Panel/BudgetsWidget.swift` | Presupuestos (limpio) |
| `Yala/App/Views/Panel/BudgetWidgetRow.swift` | Fila de presupuesto (limpio) |
| `Yala/App/Views/Panel/ScheduledPaymentsWidget.swift` | Pagos planificados |
| `Yala/App/Views/Panel/WidgetPreferencesView.swift` | Preferencias widgets (limpio) |
| `Yala/App/Views/Panel/BalanceStatusIndicator.swift` | Indicador balance (limpio) |
| `Yala/App/Views/Panel/PieChartVariationHeader.swift` | Header variación pie (limpio) |
| `Yala/App/Views/Panel/NatureCompactLegendItem.swift` | Leyenda compacta (limpio) |

#### Flujos de entrada: FAB, Inbox, Voice, Image (12 archivos)

| Archivo | Flujo |
|---------|-------|
| `Yala/App/Views/Panel/PanelView.swift` | FAB (Floating Action Button) + sheets |
| `Yala/App/Views/Voice/VoiceRecordingView.swift` | Grabación de voz |
| `Yala/App/Views/Image/ImageSelectionView.swift` | Selección de imagen/recibo |
| `Yala/App/Views/Inbox/InboxView.swift` | Lista de borradores |
| `Yala/App/ViewModels/InboxViewModel.swift` | ViewModel del inbox |
| `Yala/App/Views/Inbox/InboxDraftEditSheet.swift` | Edición de borrador |
| `Yala/App/ViewModels/InboxDraftEditViewModel.swift` | ViewModel edición borrador |
| `Yala/App/Views/Shared/InboxAlertModal.swift` | Modal alerta inbox |
| `Yala/App/Views/Inbox/InboxBulkActionsSheet.swift` | Acciones bulk inbox |
| `Yala/App/Views/Inbox/InboxDraftRowView.swift` | Fila de borrador |
| `Yala/App/Views/Inbox/InboxApproveSuccessView.swift` | Éxito al aprobar |
| `Yala/App/Views/Inbox/InboxBulkApproveSuccessView.swift` | Éxito bulk approve |

### Issues encontrados

#### ALTA (4) — TODOS CORREGIDOS

| ID | Archivo:Línea | Descripción | Estado |
|----|---------------|-------------|--------|
| G3-PV-W12 | `PanelViewModel.swift:1618-1626` | Conversión de divisa incorrecta en budget summary — usaba amount original en vez de convertir | CORREGIDO — lógica de 3 ramas con `convertToPreferredCurrency` |
| G3-FAB-01 | `InboxApproveSuccessView.swift:162-191` | 4x `try?` silencioso en `Task.sleep` para animación secuencial | CORREGIDO — `do/catch` con return en cancel |
| G3-FAB-02 | `InboxAlertModal.swift:154-163` | `superview?.superview?.backgroundColor = .clear` — hack UIKit frágil | CORREGIDO — eliminado `ClearBackgroundView`, usa `.presentationBackground(.clear)` |
| G3-FAB-04 | `VoiceRecordingView.swift:681` | Timer sin invalidar en `onDisappear` | CORREGIDO — `.onDisappear` invalida timer y cancela task |

#### MEDIA (10) — 8 CORREGIDOS, 2 PENDIENTES

| ID | Archivo:Línea | Descripción | Estado |
|----|---------------|-------------|--------|
| G3-PV-W1 | `PanelView.swift:523` | `"Fecha:"` hardcodeado sin localizar | CORREGIDO — `L10n.Filters.datePrefix(...)` |
| G3-PV-W11 | `PanelViewModel.swift:744-999` | Filtrado duplicado 4 veces | PENDIENTE — refactor grande, requiere batch dedicado |
| G3-WG-01 | 7 widgets | Accessibility values hardcodeados en español sin L10n | CORREGIDO — 9 claves nuevas en `L10n.Accessibility` × 6 idiomas |
| G3-WG-02 | 4 widgets | `NumberFormatter` recreado en cada render | CORREGIDO — `static let percentFormatter` |
| G3-WG-03 | 7 archivos | `DateFormatter` recreado en cada render | CORREGIDO — 14 `static let` formatters |
| G3-WG-04 | 3 pie widgets | `processChartData()` múltiples veces por render | CORREGIDO — `let chartData = processChartData()` al inicio del body |
| G3-WG-11 | `NatureTrendWidget.swift:328` | `UUID()` en `ChartItem` rompe SwiftUI diffing | CORREGIDO — ID determinista `"\(nature.rawValue)-\(timestamp)"` |
| G3-FAB-05 | `VoiceRecordingView.swift:718` | `processingTask` sin cancelar en `onDisappear` | CORREGIDO — `.onDisappear` cancela task (mismo fix que FAB-04) |
| G3-FAB-06 | `ImageSelectionView.swift:25` | `countdownTask` sin cancelar en `onDisappear` | CORREGIDO — `.onDisappear` cancela task |
| G3-FAB-07 | `InboxView.swift:143,155,186,197` | `asyncAfter(0.3)` frágil para encadenar sheets | NO CAMBIAR — patrón funcional, riesgo de regresión alto |

##### Detalle G3-WG-01: Accessibility hardcodeado en español

| Archivo | Líneas |
|---------|--------|
| `TrendChartView.swift` | 248-250 |
| `CategoriesPieWidget.swift` | 571-572 |
| `SubcategoriesPieWidget.swift` | 569-570 |
| `CashFlowWidget.swift` | 497-498 |
| `NatureTrendWidget.swift` | 470-471 |
| `TagsPieWidget.swift` | 464-465 |
| `ExchangeRateWidget.swift` | 126-127 |

##### Detalle G3-WG-02: NumberFormatter recreado

| Archivo | Líneas |
|---------|--------|
| `CategoriesPieWidget.swift` | 583-586 |
| `SubcategoriesPieWidget.swift` | 580-584 |
| `TagsPieWidget.swift` | 475-479 |
| `NatureTrendWidget.swift` | 869-875, 917-923 |

##### Detalle G3-WG-03: DateFormatter recreado

| Archivo | Líneas |
|---------|--------|
| `TrendChartView.swift` | 369-372, 375-383 |
| `CashFlowWidget.swift` | 857-865 |
| `NatureTrendWidget.swift` | 703-712, 742-751 |
| `ExchangeRateWidget.swift` | 139-149, 510-524 |
| `PanelView.swift` | 755-760 |
| `InboxDraftEditSheet.swift` | 731-736 |
| `InboxDraftRowView.swift` | 359 |

##### Bonus: Dead code eliminado

| Archivo | Código | Motivo |
|---------|--------|--------|
| `NatureTrendWidget.swift:742-751` | `formatDate(_:grouping:)` | Nunca llamado, reemplazado por `formatDateFull` |

#### BAJA (~20) — PENDIENTES (no bloquean)

##### DS Compliance — Valores hardcodeados

| ID | Archivo:Línea | Valor | Sugerido |
|----|---------------|-------|----------|
| G3-DS-01 | `PanelView.swift:136` | `padding(.vertical, 1)` | `DS.Spacing.xxxs` o documentar excepción |
| G3-DS-02 | `PanelView.swift:141` | `offset(x: 8, y: -6)` | `DS.Spacing` tokens |
| G3-DS-03 | `PanelView.swift:415` | `frame(width: 24)` | `DS.Spacing.xl` o icon token |
| G3-DS-04 | `PanelView.swift:371, 392` | `shadow(radius: 20, y: 10)` FAB duplicado | Extraer `DS.Shadow.fab` |
| G3-DS-05 | `PanelView.swift:938` | `frame(height: 200)` empty state | Token o constante |
| G3-DS-06 | `PanelView.swift:1405` | `frame(width: 36, height: 36)` SiriTipCard | Icon token |
| G3-DS-07 | `PanelViewModel.swift:1706, 1723` | Color hex `#6366F1` hardcodeado | Constante del DS |
| G3-DS-08 | `ExchangeRateWidget.swift:73` | `padding(.bottom, 2)` | `DS.Spacing.xxs` |
| G3-DS-09 | Pie widgets (3 archivos):272-273 | `iconSize: 32/24`, `fontSize: 10/8` bubbles | Constantes privadas o DS token |
| G3-DS-10 | `ScheduledPaymentsWidget.swift:552, 563` | `spacing: 1`, `spacing: 2` | `DS.Spacing.xxs` |
| G3-DS-11 | `ScheduledPaymentsWidget.swift:555` | `.font(.caption2)` | `DS.Typography.captionSmall` |
| G3-DS-12 | `ScheduledPaymentsWidget.swift:566-567` | `.font(.system(size: 6))` no respeta Dynamic Type | `@ScaledMetric` o Typography token |
| G3-DS-13 | `AccountsCarouselView.swift:47` | `frame(height: 96)` sin Dynamic Type | `@ScaledMetric` |
| G3-DS-14 | `AccountCardView.swift:90` | `lineWidth: 0.8` vs `1` en otros archivos | `DS.Border.width` token |
| G3-DS-15 | `TrendWidget.swift:57, 117` | `chartHeight: 160` hardcodeado | Token o `@ScaledMetric` |
| G3-DS-16 | `InboxApproveSuccessView.swift:240,264,289` | `frame(width: 20)` | Icon token |
| G3-DS-17 | `InboxApproveSuccessView.swift:275,299` | `frame(width: 8, height: 8)` color dots | `DS.Icon.dot` |
| G3-DS-18 | `PanelView.swift:432` | `shadow(radius: 8, y: 4)` submenu valores mágicos | Shadow token |

##### Accesibilidad

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G3-A11Y-01 | `TopSubcategoriesWidget.swift:166-176` | Header chevron sin `accessibilityLabel` (TopCategories sí lo tiene) |
| G3-A11Y-02 | `InboxView.swift:267` | `accessibilityHint` en español sin L10n — CORREGIDO en G6 |
| G3-A11Y-03 | `InboxDraftEditSheet.swift:705` | `accessibilityHint` en español sin L10n — CORREGIDO en G6 |

##### Performance

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G3-PERF-01 | `PanelViewModel.swift:1499-1506` | `DateFormatter` creado en cada invocación de `calculateExchangeRateData` |

##### Mantenibilidad

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G3-MAINT-01 | `PanelViewModel.swift:713-1060` | `buildCalculationContext` es función de ~300 líneas. Candidata a refactoring |
| G3-MAINT-02 | `PanelViewModel.swift:184` | String literal `"pending"` en Predicate hardcodeado. Debería usar constante del enum |
| G3-MAINT-03 | `AccountCardView.swift:119-130` | `normalizeCurrencyCode` duplicado. Ya existe en `CurrencyUtils.swift` |
| G3-MAINT-04 | CategoriesPie/SubcategoriesPie/TagsPie | ~80% de estructura duplicada entre los 3 widgets. Candidatos a componente genérico |
| G3-MAINT-05 | `NatureTrendWidget.swift:742-751` | Función `formatDate(_:grouping:)` no usada. Código muerto |

##### UX

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G3-UX-01 | `PanelView.swift:289` | FAB disabled sin feedback visual para usuarios sin VoiceOver. Solo hay `accessibilityHint` |
| G3-UX-02 | `ExchangeRateWidget.swift:492` | `.foregroundStyle(.orange)` hardcodeado. Debería ser `DS.Semantic.warningForeground` |

##### Testabilidad

| ID | Archivo | Descripción |
|----|---------|-------------|
| G3-TEST-01 | `PanelViewModel.swift:14` | Singleton fallback `exchangeRateService = .shared` dificulta testing |

---

## Grupo 4: Statistics + Records

### Archivos revisados

#### Statistics Views (6 archivos)

| Archivo | Flujo |
|---------|-------|
| `Yala/App/Views/Statistics/StatisticsView.swift` | Vista wrapper (limpio) |
| `Yala/App/Views/Statistics/RecordsTabView.swift` | Tab de registros |
| `Yala/App/Views/Statistics/TrendsTabView.swift` | Tab de tendencias |
| `Yala/App/Views/Statistics/CategoriesTabView.swift` | Tab de categorías |
| `Yala/App/Views/Statistics/DetailContainerView.swift` | Container con FAB y tabs |
| `Yala/App/Views/Statistics/PeriodComparisonChartView.swift` | Chart comparación periodos |

#### Records Views (5 archivos)

| Archivo | Flujo |
|---------|-------|
| `Yala/App/Views/Records/Components/RecordDateSectionView.swift` | Header de sección fecha |
| `Yala/App/Views/Records/Components/RecordRowView.swift` | Fila de registro |
| `Yala/App/Views/Records/RecordsFiltersView.swift` | Filtros de registros |
| `Yala/App/Views/Records/BulkEditSheet.swift` | Edición masiva |
| `Yala/App/Views/Records/RecordsStandaloneView.swift` | Vista standalone registros |

#### ViewModels (3 archivos)

| Archivo | Propósito |
|---------|-----------|
| `Yala/App/ViewModels/StatisticsViewModel.swift` | ViewModel Statistics |
| `Yala/App/ViewModels/RecordsViewModel.swift` | ViewModel Records |
| `Yala/App/ViewModels/RecordsFiltersViewModel.swift` | ViewModel filtros |

### Issues encontrados

#### ALTA (0)

No se encontraron issues de severidad alta.

#### MEDIA (14)

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G4-RT-01 | `RecordsTabView.swift:420` | `AccountChip` usa `let id = UUID()` — ID no determinista |
| G4-RT-02 | `RecordsTabView.swift:426` | `CategoryChip` usa `let id = UUID()` — idem |
| G4-RT-03 | `RecordsTabView.swift:431` | `SubcategoryChip` usa `let id = UUID()` — idem |
| G4-RT-04 | `RecordsTabView.swift:446` | `NatureChipData` usa `let id = UUID()` — idem |
| G4-TT-01 | `TrendsTabView.swift:1208,1214,1218,1226` | 4 chip structs con `let id = UUID()` — mismos que RecordsTabView |
| G4-CT-01 | `CategoriesTabView.swift:1365,1434` | `CategoryChip` y `AccountChip` con `let id = UUID()` |
| G4-CT-05 | `CategoriesTabView.swift:1696` | `NumberFormatter` inline en `formattedPercentage()` |
| G4-CT-06 | `CategoriesTabView.swift:1782` | `NumberFormatter` inline en `SubcategoryRowView.formattedPercentage()` |
| G4-PC-01 | `PeriodComparisonChartView.swift:459` | `DateFormatter` inline en `periodLabel()` |
| G4-PC-02 | `PeriodComparisonChartView.swift:238-239` | Accessibility values hardcodeados: `"Sin datos"`, `"Periodo actual vs anterior"` |
| G4-DC-01 | `DetailContainerView.swift:486` | `accessibilityHint("Crea al menos una cuenta y una categoría")` sin L10n |
| G4-RV-01 | `RecordDateSectionView.swift:30` | `DateFormatter` inline |
| G4-RV-04 | `RecordsFiltersView.swift:558,641,661` | `"Atrás"` hardcodeado ×3 — L10n.Action.back existe |
| G4-RV-10 | `RecordsStandaloneView.swift:323` | `accessibilityHint` hardcodeado en español sin L10n |

#### BAJA (~10)

##### UUID no determinista (patrón repetido)

> Los ~12 chip structs con `UUID()` son el mismo patrón. Un fix futuro: extraer un struct genérico `FilterChipModel<ID>` reutilizable.

##### DS Compliance

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G4-RV-05 | `RecordsFiltersView.swift:277,610` | `.frame(width: 8/10)` color dots hardcodeados |
| G4-RV-07 | `BulkEditSheet.swift:309` | `.frame(width: 36, height: 36)` icon size |
| G4-RV-08 | `BulkEditSheet.swift:545` | `.frame(width: 28, height: 28)` tag icon |

##### Accesibilidad

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G4-RV-06 | `BulkEditSheet.swift:444,695` | `"Completa la selección requerida"` sin L10n |

##### Mantenibilidad

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G4-VM-04 | `StatisticsViewModel.swift:472-484` | Filtrado duplicado: `allAccountTxns` idéntico a `accountTransactions` |
| G4-VM-05 | `StatisticsViewModel.swift:354-393` | Income/expense calculado dos veces (local + TrendDataProcessor) |
| G4-VM-06 | `RecordsViewModel.swift:420-527` | 6 métodos bulk con patrón repetido → candidato a helper |
| G4-VM-11 | `StatisticsViewModel.swift:145` | Propiedades deprecated `customStartDate`/`customEndDate` sin uso |
| G4-VM-12 | `RecordsViewModel.swift:81` | Idem propiedades deprecated |

### Fixes aplicados (2026-02-23)

Todos los 14 MEDIA resueltos:
- G4-RT-01/02/03/04: UUID → ID determinista en RecordsTabView chip structs
- G4-TT-01/02/03/04: UUID → ID determinista en TrendsTabView chip structs
- G4-CT-01: UUID → ID determinista en CategoriesTabView chip structs
- G4-CT-05/06: NumberFormatter inline → `static let percentFormatter`
- G4-PC-01: DateFormatter inline → `static let periodDayFormatter/periodMonthFormatter`
- G4-PC-02: Accessibility values → `L10n.Accessibility.noData` + `periodComparisonValue`
- G4-DC-01: Hint → `L10n.Accessibility.createAccountFirst`
- G4-RV-01: DateFormatter inline → `static let sectionDateFormatter`
- G4-RV-04: `"Atrás"` ×3 → `L10n.Action.back`
- G4-RV-10: Hint → `L10n.Accessibility.createAccountFirst`
- G4-RV-06: `"Completa la selección requerida"` → `L10n.Accessibility.completeSelectionHint`

### Hallazgos positivos

- `StatisticsView.swift` limpio — buen wrapper delegando a `DetailContainerView`
- `RecordRowView.swift` bien estructurado con DS tokens
- Manejo de errores correcto en todos los ViewModels (do/catch con #if DEBUG)
- Bulk edit con `TransactionService.shared.notifyWidgets()` correcto
- `RecordsFiltersViewModel` con tests existentes (3 tests)
- Period comparison con `PreviousPeriodHelper` reutilizado
- FAB en DetailContainerView reutiliza misma lógica que PanelView

---

## Grupo 5: Transaction CRUD

### Archivos revisados (27 archivos)

| Categoría | Archivos |
|-----------|----------|
| Views principales | `NewTransactionView.swift`, `TransactionSuccessView.swift` |
| Componentes form | `TransactionAmountInputView`, `TransferAmountInputView`, `TransactionTypeSelectorView`, `NatureSelectorSheet`, `NatureEditChip`, `DatePickerSheet`, `SelectionChip`, `NumericKeypadView`, `TransactionFormRow`, `TransactionTypeSegmentedView` |
| Sheets selector | `AccountSelectorSheet`, `SubcategorySelectorSheet`, `TagSelectorSheet`, `SaveAsFavoriteSheet`, `SaveAsRecurringSheet`, `DescriptionAutocomplete` |
| ViewModels | `NewTransactionViewModel` (35 tests), `AccountSelectorViewModel`, `SubcategorySelectorViewModel`, `TagSelectorViewModel` |
| Services | `TransactionService`, `TransactionUpdateService` |
| Models | `TransactionFormModels` |

### Issues encontrados

#### ALTA (5)

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G5-SV-01 | `TransactionService.swift:180` | `bulkAddTags` no llama `WidgetDataCache.updateCache` — widgets quedan desactualizados |
| G5-SV-02 | `TransactionService.swift:195` | `bulkRemoveTags` idem — falta cache invalidation |
| G5-SV-03 | `NewTransactionViewModel.swift:649,665` | Transfer creation usa `.category` pero edit usa `.safeCategory` — inconsistencia, posible category nil |
| G5-TV-02 | `NewTransactionView.swift:1015` | `accessibilityHint("Para guardar, completa monto...")` hardcodeado en español |
| G5-TV-03 | `NumericKeypadView.swift:97` | `"Borrar"` hardcodeado en `accessibilityText` |

#### MEDIA (12)

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G5-TV-05 | `TransactionFormRow.swift:247` | DateFormatter inline en `formattedDate` |
| G5-TV-06 | `TransactionSuccessView.swift:308` | DateFormatter inline en `formattedDate` |
| G5-TC-01 | `SaveAsRecurringSheet.swift:680` | DateFormatter inline en `monthName()` + `Locale.current` en vez de `AppLocale.current` |
| G5-TC-04 | `SaveAsRecurringSheet.swift:682` | `monthSymbols[month - 1]` sin bounds check — crash si month fuera de 1-12 |
| G5-SV-05 | TransactionService + RecordsViewModel | 6 métodos bulk duplicados entre ambos archivos — SSOT no definida |
| G5-SV-06 | `NewTransactionViewModel.swift:750,823` | `context.save()` intermedio en `ensureTransferCategory` falla silenciosamente |
| G5-DC-01 | `DetailContainerView.swift:486` | `accessibilityHint` hardcodeado español (repetido de G4) |
| G5-PC-02 | `PeriodComparisonChartView.swift:238` | `"Sin datos"`, `"Periodo actual vs anterior"` sin L10n |
| G5-RV-04 | `RecordsFiltersView.swift:558,641,661` | `"Atrás"` hardcodeado ×3 — `L10n.Action.back` existe |
| G5-RV-10 | `RecordsStandaloneView.swift:323` | `accessibilityHint` hardcodeado español |
| G5-RV-06 | `BulkEditSheet.swift:444,695` | `"Completa la selección requerida"` sin L10n |
| G5-RV-01 | `RecordDateSectionView.swift:30` | DateFormatter inline |

#### BAJA (~8)

| ID | Archivo:Línea | Descripción |
|----|---------------|-------------|
| G5-TC-07 | `TransactionTypeSelectorView.swift:43` | `DS.Chip.paddingH` usado para vertical padding |
| G5-TC-08 | `SaveAsRecurringSheet.swift:308` | Toggle sin accessibilityLabel |
| G5-TV-14 | `TransactionTypeSegmentedView.swift:58` | Font sin DS.Typography |
| G5-SV-08 | `NewTransactionViewModel.swift:413` | Comentario duplicado |
| G5-RV-05 | `RecordsFiltersView.swift:277,610` | Circle sizes hardcodeados |
| G5-RV-07 | `BulkEditSheet.swift:309` | Icon frame 36×36 sin DS token |

### Fixes aplicados (2026-02-23)

5 ALTA + 7 MEDIA resueltos:
- G5-SV-01/02: `WidgetDataCache.updateCache` en `bulkAddTags`/`bulkRemoveTags`
- G5-SV-03: `.category` → `.safeCategory` en transfer creation
- G5-TV-02: Hint → `L10n.Accessibility.completeFormHint`
- G5-TV-03: `"Borrar"` → `L10n.Action.delete`
- G5-TV-05: DateFormatter inline → `static let dateFormatter` (DateFormRow)
- G5-TV-06: DateFormatter inline → `static let dateFormatter` (TransactionSuccessView)
- G5-TC-01/04: `monthName()` → Calendar.monthSymbols + guard + AppLocale
- G5-DC-01, G5-PC-02, G5-RV-04, G5-RV-10, G5-RV-06, G5-RV-01: (resueltos en G4 fixes arriba)

**SKIP (refactor futuro):**
- G5-SV-05: Bulk methods duplicados TransactionService vs RecordsViewModel — requiere consolidar 6 métodos
- G5-SV-06: Intermediate save en `ensureTransferCategory` — funciona correctamente, optimización no bug

### Hallazgos positivos

- `NewTransactionViewModel` tiene 35 tests — excelente cobertura
- Error handling correcto con do/catch en todos los saves
- `requireContext()` pattern en TransactionService
- L10n extensivo en >95% de strings visibles
- Transfer pair management con `transferPairID` bidireccional
- `MerchantMemoryService` integrado para auto-categorización
- Validación de campos antes de save (`canSave` computed property)

---

## Archivos limpios (sin issues)

Estos archivos fueron revisados y **no presentaron issues**:

| Grupo | Archivo |
|-------|---------|
| G3 | `TopCategoriesWidget.swift` |
| G3 | `RecentRecordsWidget.swift` |
| G3 | `BudgetsWidget.swift` |
| G3 | `BudgetWidgetRow.swift` |
| G3 | `WidgetPreferencesView.swift` |
| G3 | `BalanceStatusIndicator.swift` |
| G3 | `PieChartVariationHeader.swift` |
| G3 | `NatureCompactLegendItem.swift` |
| G4 | `StatisticsView.swift` |
| G4 | `RecordRowView.swift` |
| G5 | `AccountSelectorSheet.swift` |
| G5 | `SubcategorySelectorSheet.swift` |
| G5 | `TagSelectorSheet.swift` |
| G5 | `SaveAsFavoriteSheet.swift` |
| G5 | `TransactionAmountInputView.swift` |
| G5 | `TransferAmountInputView.swift` |
| G5 | `NatureSelectorSheet.swift` |
| G5 | `NatureEditChip.swift` |
| G5 | `DatePickerSheet.swift` |
| G5 | `DescriptionAutocomplete.swift` |
| G5 | `TransactionUpdateService.swift` |
| G5 | `TransactionFormModels.swift` |

---

## Hallazgos positivos destacados

### Grupo 1
- Onboarding bien estructurado en 8 pasos con TabView paginado
- Guard contra duplicados en notifications y categories seeding
- iCloud sync detection con debounce de 5s para remote wipe
- Biometric auth con timeout configurable y Keychain storage

### Grupo 3
- Manejo de errores correcto: todos los `try` en SwiftData están en `do/catch` con `#if DEBUG`
- Sin force unwraps en lógica de negocio
- Empty states presentes en InboxView (pending y archived)
- DS tokens consistentes en ~90% del código
- L10n extensivo para textos (salvo excepciones documentadas)
- `accessibilityLabel` y `accessibilityHint` en botones principales
- `reduceMotion` respetado en todas las animaciones
- Feature gating correcto para Voice e Image (Pro features)
- Edge cases de permisos manejados (micrófono denegado, sin API key, sin conexión)
- Draft deduplication con snapshot previo en Voice e Image

---

## Grupo 4: Statistics — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 4.1 | Statistics Root | Tab principal con sub-tabs via chips |
| 4.2 | Trends Sub-tab | Chart de tendencia, selector de métrica, lista de records |
| 4.3 | Categories Sub-tab | Pie charts de categorías/subcategorías con filtro interactivo |
| 4.4 | Records Sub-tab | Lista filtrable y ordenable de transacciones, bulk edit, delete |
| 4.5 | Records Filters | Sheet con pickers de accounts, categories, tags, currency |
| 4.6 | Bulk Edit | Edición múltiple: cambiar account, subcategory, tag, note, amount |
| 4.7 | Edit Transaction | Tap en fila → NewTransactionView en modo edit |
| 4.8 | Records Standalone | Records como tab independiente (si promovido) |
| 4.9 | Period Comparison | Chart de comparación entre períodos |

### Archivos a revisar

#### Views (13)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Statistics/StatisticsView.swift` | 4.1 Root |
| `App/Views/Statistics/DetailContainerView.swift` | 4.1 Container |
| `App/Views/Statistics/TrendsTabView.swift` | 4.2 Trends |
| `App/Views/Statistics/CategoriesTabView.swift` | 4.3 Categories |
| `App/Views/Statistics/RecordsTabView.swift` | 4.4 Records |
| `App/Views/Statistics/PeriodComparisonChartView.swift` | 4.9 Period comparison |
| `App/Views/Records/BulkEditSheet.swift` | 4.6 Bulk edit |
| `App/Views/Records/RecordsFiltersView.swift` | 4.5 Filters |
| `App/Views/Records/RecordsStandaloneView.swift` | 4.8 Standalone |
| `App/Views/Records/Components/RecordRowView.swift` | Shared row |
| `App/Views/Records/Components/RecordDateSectionView.swift` | Shared section header |
| `App/Views/Statistics/Components/RecordRowView.swift` | Shared row (dup?) |
| `App/Views/Statistics/Components/RecordDateSectionView.swift` | Shared section header (dup?) |

#### ViewModels (5)
| Archivo | Propósito |
|---------|-----------|
| `App/ViewModels/StatisticsViewModel.swift` | Cálculos statistics |
| `App/ViewModels/DetailContainerViewModel.swift` | Container state |
| `App/ViewModels/RecordsViewModel.swift` | Records list, sort, filter |
| `App/ViewModels/RecordsFiltersViewModel.swift` | Filter state management |
| `App/ViewModels/BulkEditViewModel.swift` | Bulk edit operations |

#### Models y Helpers (8)
| Archivo | Propósito |
|---------|-----------|
| `App/Models/StatisticsContext.swift` | Contexto de statistics |
| `App/Models/RecordsModels.swift` | Modelos de records |
| `App/ViewModels/PanelCalculationContext.swift` | Contexto compartido |
| `App/Logic/Helpers/PreviousPeriodHelper.swift` | Cálculo período anterior |
| `App/Logic/Helpers/TrendProcessingHelper.swift` | Procesamiento trends |
| `App/Logic/Helpers/NatureTrendHelper.swift` | Trends por naturaleza |
| `App/Logic/Helpers/FilterChipHelper.swift` | Helper de chips |
| `App/Logic/Calculators/BalanceTrendCalculator.swift` | Calculador balance |

### Puntos de atención
- Verificar que los filtros de Records sean consistentes con los del Panel (G3-PV-W11 reportó duplicación x4)
- Revisar RecordRowView duplicado entre Records/ y Statistics/ — posible código muerto
- Verificar PeriodComparisonChart con filtros de currency/amount/search
- Bulk edit: verificar transaccionalidad (todas o ninguna)

---

## Grupo 5: Transaction CRUD — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 5.1 | Create Transaction | FAB → form completo con keypad, pickers, autocomplete |
| 5.2 | Edit Transaction | Tap en record → mismo form precargado |
| 5.3 | Duplicate / Create Another | Post-save: crear otro o duplicar |
| 5.4 | Selector de categoría | Sheet con categorías → subcategorías |
| 5.5 | Selector de cuenta | Sheet con lista de cuentas |
| 5.6 | Selector de tags | Sheet multi-select de tags |
| 5.7 | Selector de fecha | Sheet DatePicker |
| 5.8 | Selector de naturaleza | Sheet essential/priority/optional |
| 5.9 | Favoritos | Cargar template / guardar como favorito |
| 5.10 | Guardar como recurrente | Post-save → crear scheduled payment |
| 5.11 | Success flow | Vista de éxito con opciones |

### Archivos a revisar

#### Views (20)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Transactions/NewTransactionView.swift` | 5.1, 5.2 Form principal |
| `App/Views/Transactions/TransactionTypeSegmentedView.swift` | Selector expense/income/transfer |
| `App/Views/Transactions/NumericKeypadView.swift` | Teclado numérico custom |
| `App/Views/Transactions/SubcategorySelectorSheet.swift` | 5.4 Picker categorías |
| `App/Views/Transactions/AccountSelectorSheet.swift` | 5.5 Picker cuentas |
| `App/Views/Transactions/TagSelectorSheet.swift` | 5.6 Picker tags |
| `App/Views/Transactions/DescriptionAutocomplete.swift` | Autocomplete de merchant |
| `App/Views/Transactions/SaveAsFavoriteSheet.swift` | 5.9 Guardar favorito |
| `App/Views/Transactions/SaveAsRecurringSheet.swift` | 5.10 Guardar recurrente |
| `App/Views/Transactions/TransactionSuccessView.swift` | 5.11 Vista éxito |
| `App/Views/Transactions/TransactionFormRow.swift` | Fila reutilizable |
| `App/Views/Transactions/Components/TransactionAmountInputView.swift` | Input monto expense/income |
| `App/Views/Transactions/Components/TransferAmountInputView.swift` | Input monto transfer |
| `App/Views/Transactions/Components/TransactionTypeSelectorView.swift` | Selector tipo |
| `App/Views/Transactions/Components/DatePickerSheet.swift` | 5.7 Picker fecha |
| `App/Views/Transactions/Components/NatureSelectorSheet.swift` | 5.8 Picker naturaleza |
| `App/Views/Transactions/Components/NatureEditChip.swift` | Chip de naturaleza |
| `App/Views/Transactions/Components/SelectionChip.swift` | Chip genérico |
| `App/Views/Favorites/FavoritesListView.swift` | 5.9 Lista favoritos (mode: .select) |
| `App/Views/Categories/SubcategoryNatureSelectorView.swift` | Naturaleza subcategoría |

#### ViewModels (7)
| Archivo | Propósito |
|---------|-----------|
| `App/ViewModels/NewTransactionViewModel.swift` | Lógica del form (35 tests) |
| `App/ViewModels/AccountSelectorViewModel.swift` | Selector cuentas |
| `App/ViewModels/SubcategorySelectorViewModel.swift` | Selector categorías |
| `App/ViewModels/TagSelectorViewModel.swift` | Selector tags |
| `App/ViewModels/FavoritesListViewModel.swift` | Lista favoritos |
| `App/ViewModels/SaveAsFavoriteViewModel.swift` | Guardar favorito |
| `App/ViewModels/SaveAsRecurringViewModel.swift` | Guardar recurrente |

#### Models
| Archivo | Propósito |
|---------|-----------|
| `App/Models/TransactionFormModels.swift` | Modelos del form |

### Puntos de atención
- **Flujo más crítico de la app** — es el core de registro de datos
- Verificar validación de monto (0, negativo, overflow, decimales)
- Transfer: verificar que cuenta origen ≠ destino
- Edit: verificar que cambios se persisten correctamente
- Currency conversion en transfers entre cuentas de distinta divisa
- MerchantMemory: verificar auto-categorización
- Favoritos: verificar que template carga todos los campos

---

## Grupo 6: Inbox (Smart Recording) — Revisado + fixes

### Archivos revisados (deep-dive G6)

| Archivo | Propósito |
|---------|-----------|
| `Yala/Services/DraftService.swift` | Service layer — approve, bulkApprove, reject, delete |
| `Yala/App/ViewModels/InboxViewModel.swift` | ViewModel inbox list |
| `Yala/App/Views/Inbox/InboxView.swift` | Vista principal inbox |
| `Yala/App/Views/Inbox/InboxDraftEditSheet.swift` | Edición de borrador |
| `Yala/App/Views/Inbox/InboxApproveSuccessView.swift` | Vista éxito al aprobar |

### Issues encontrados

#### ALTA (1) — CORREGIDO

| ID | Archivo:Línea | Descripción | Estado |
|----|---------------|-------------|--------|
| G6-SV-01 | `DraftService.swift:289` | `bulkApprove` missing MerchantMemory update (single approve has it at line 203) | CORREGIDO — added MerchantMemoryService.updateMemory in bulk loop |

#### MEDIA (6) — TODOS CORREGIDOS

| ID | Archivo:Línea | Descripción | Estado |
|----|---------------|-------------|--------|
| G6-TV-01 | `InboxView.swift:267` | `accessibilityHint` hardcodeado en español | CORREGIDO → `L10n.Accessibility.selectAtLeastOneDraft` |
| G6-TV-02 | `InboxDraftEditSheet.swift:705` | `accessibilityHint` hardcodeado en español | CORREGIDO → `L10n.Accessibility.approveCompleteHint` |
| G6-TV-03 | `InboxView.swift:206` | `Button("OK")` hardcodeado | CORREGIDO → `L10n.Common.ok` |
| G6-TV-04 | `InboxDraftEditSheet.swift:213` | `Button("OK")` hardcodeado | CORREGIDO → `L10n.Common.ok` |
| G6-TV-05 | `InboxView.swift:362` | DateFormatter inline | CORREGIDO → `static let sectionDateFormatter` |
| G6-TV-06 | `InboxApproveSuccessView.swift:234` | DateFormatter inline | CORREGIDO → `static let dateFormatter` |

#### Batch fix: `Button("OK")` → `L10n.Common.ok` (5 archivos adicionales)

| Archivo | Estado |
|---------|--------|
| `ProfileView.swift:163` | CORREGIDO |
| `ProTrialOfferSheet.swift:141` | CORREGIDO |
| `BiometricSecurityView.swift:144` | CORREGIDO |
| `SubscriptionView.swift:48` | CORREGIDO |
| `ExportSummaryStepView.swift:66` | CORREGIDO |

### SKIPs (falsos positivos)

- **SessionState/WidgetDataCache en reject/delete/returnToPending/saveDraft**: Estas operaciones solo modifican InboxDraft (no TransactionItem). Widgets no muestran counts de drafts. Inbox se refresca via `loadData()`. NO necesario.
- **Error feedback para draft ops**: Actualmente `#if DEBUG print` only. Válido pero es enhancement, no bug — drafts son transitorios y el patrón es consistente con el resto del codebase.
- **G6-SV-02 MARK comments**: Verificado — todos los `// MARK:` son correctos, fue artifact de lectura del agente.

### Issues ya encontrados en G3 (previos)
- G3-FAB-01: `try?` en InboxApproveSuccessView — CORREGIDO
- G3-FAB-02: `superview?.superview?` en InboxAlertModal — CORREGIDO
- G3-FAB-04: Timer leak en VoiceRecordingView — CORREGIDO
- G3-FAB-05: Task leak en VoiceRecordingView — CORREGIDO
- G3-FAB-06: Task leak en ImageSelectionView — CORREGIDO
- G3-FAB-07: `asyncAfter(0.3)` frágil en InboxView — NO CAMBIAR (funcional, riesgo alto)

### Hallazgos positivos
- DraftService bien estructurado con `requireContext()` pattern
- Error handling correcto con do/catch en todos los saves
- Single approve tiene MerchantMemory integration (bug was only in bulk)
- DraftDeduplicationService con 15 tests — buena cobertura
- InboxViewModel con 10 tests
- Scheduled payment draft association correcto en ambos paths

---

## Grupo 7: Planning — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 7.1 | Planning Root | Tab con sub-tabs: Budgets, Scheduled Payments |
| 7.2 | Budgets List | Lista filtrada por período, limit banner free tier |
| 7.3 | Create/Edit Budget | Editor con pickers de categoría, período, alertas |
| 7.4 | Budget Favorites | Configuración de budgets favoritos para widget |
| 7.5 | Scheduled Payments List | Lista con sub-tabs expense/income/transfer/all |
| 7.6 | Scheduled Payment Detail | Detalle con ocurrencias pasadas/futuras |
| 7.7 | Create/Edit Scheduled Payment | Editor con pickers de período, categoría |
| 7.8 | Scheduled Payments Filters | Filtros de pagos planificados |

### Archivos a revisar

#### Views (17)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Planning/PlanningView.swift` | 7.1 Root |
| `App/Views/Planning/BudgetsListView.swift` | 7.2 Budgets list |
| `App/Views/Planning/BudgetEditorView.swift` | 7.3 Budget editor |
| `App/Views/Planning/BudgetRowView.swift` | Fila de budget |
| `App/Views/Planning/ScheduledPaymentsView.swift` | 7.5 Container |
| `App/Views/Planning/ScheduledPaymentsListView.swift` | 7.5 List |
| `App/Views/Planning/ScheduledPaymentDetailView.swift` | 7.6 Detail |
| `App/Views/Planning/ScheduledPaymentEditorView.swift` | 7.7 Editor |
| `App/Views/Planning/ScheduledPaymentRowView.swift` | Fila de payment |
| `App/Views/Planning/ScheduledPaymentsFiltersView.swift` | 7.8 Filters |
| `App/Views/Planning/Components/BudgetProgressBar.swift` | Barra de progreso |
| `App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift` | Picker período |
| `App/Views/Planning/Components/ScheduledPaymentPeriodSelectorSheet.swift` | Picker período SP |
| `App/Views/Planning/Components/TransactionAssociationSheet.swift` | Asociar transaction |
| `App/Views/Settings/BudgetsFavoritesSettingsView.swift` | 7.4 Favorites |
| `App/Views/Settings/ScheduledPaymentsSettingsView.swift` | Settings SP |
| `App/Views/Panel/ScheduledPaymentsWidget.swift` | Widget (ya revisado en G3) |

#### ViewModels (6)
| Archivo | Propósito |
|---------|-----------|
| `App/ViewModels/BudgetsViewModel.swift` | Budgets list (11 tests) |
| `App/ViewModels/BudgetEditorViewModel.swift` | Budget editor (1 test) |
| `App/ViewModels/BudgetsFavoritesSettingsViewModel.swift` | Favorites config |
| `App/ViewModels/ScheduledPaymentsViewModel.swift` | SP list |
| `App/ViewModels/ScheduledPaymentEditorViewModel.swift` | SP editor |
| `App/ViewModels/ScheduledPaymentsSettingsViewModel.swift` | SP settings |

#### Models, Services, Utils (7)
| Archivo | Propósito |
|---------|-----------|
| `App/Models/BudgetModels.swift` | Modelos budget |
| `App/Models/ScheduledPaymentModels.swift` | Modelos SP |
| `App/Services/ScheduledPaymentDraftService.swift` | Draft service SP |
| `Utils/ScheduledPaymentDateCalculator.swift` | Cálculo fechas (17 tests) |
| `Models/ScheduledPayment.swift` | Modelo SwiftData |
| `Services/ScheduledPaymentNotificationService.swift` | Notifs SP |
| `Services/ScheduledPaymentNotificationTracker.swift` | Tracker notifs |

### Puntos de atención
- Verificar cálculo de progreso de budget (G3-PV-W12 reportó bug de conversión de divisa)
- ScheduledPaymentDateCalculator: verificar skip dates, edge cases
- Budget alerts: verificar que se disparan correctamente en umbrales
- Period boundaries: budget semanal/mensual/anual/único
- Free tier limits: verificar gates correctos

---

## Grupo 8: Global Search — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 8.1 | Search Tab | Búsqueda real-time con chips de filtro |
| 8.2 | Navigate to Records | "Ver todo" → Statistics → Records con search |
| 8.3 | Edit from Search | Tap resultado → NewTransactionView edit mode |

### Archivos a revisar

Ya revisado parcialmente en `ContentView.swift` (GlobalSearchView, SearchContentView, SearchResultRow, SearchDateSectionHeader están inline).

| Archivo | Propósito |
|---------|-----------|
| `App/ContentView.swift` (líneas 700-1060) | GlobalSearchView, SearchContentView, SearchResultRow |

### Puntos de atención
- **Performance**: `@Query` carga TODAS las transacciones sin límite
- Filtrado duplicado entre `filteredResults` y `totalMatchingCount` (misma lógica 2x)
- Search no usa FetchDescriptor con predicate — filtra en memoria
- Verificar que "Ver todo" pasa correctamente el filtro a Statistics

---

## Grupo 9: Profile & Settings — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 9.1 | Profile Root | Sheet con NavigationStack, acceso a todas las settings |
| 9.2 | Personal Details | Nombre, avatar image/icon |
| 9.3 | Accounts Settings | Lista reorderable, archivados, CRUD |
| 9.4 | Create/Edit Account | Form con tipo, ajuste, currency (20 tests) |
| 9.5 | Categories Settings | Lista activas/ocultas |
| 9.6 | Category Detail | Nombre, icon/color, subcategorías, transferencia |
| 9.7 | Tags Settings | Lista de tags |
| 9.8 | Create/Edit Tag | Form nombre, color, icon (8 tests) |
| 9.9 | Favorites Management | Lista de templates, CRUD |
| 9.10 | Budget Favorites | Config budgets en widget |
| 9.11 | Scheduled Payments Settings | Config pagos planificados |
| 9.12 | Personalization | Período, icons, weekday, tabs, idioma, expenses-only |
| 9.13 | Notifications | 7 tipos, editor individual |
| 9.14 | Currency & Exchange | Preferred, secondary, rates |
| 9.15 | App Icon | Selector de app icon |
| 9.16 | Theme | Selector de tema |
| 9.17 | Biometric Security | Enable/disable, timeout |
| 9.18 | Subscription | Paywall / manage subscription |
| 9.19 | iCloud Sync | Estado y config iCloud |
| 9.20 | Siri Shortcuts | Configuración Siri |
| 9.21 | Tutorials | Lista y detalle |
| 9.22 | FAQ | Preguntas frecuentes |
| 9.23 | Data Import | Wizard CSV import |
| 9.24 | Data Export | Wizard 3 pasos (filtros → columnas → preview) |
| 9.25 | Data Wipe | Reset completo con confirmación |

### Archivos a revisar

#### Views — Profile (2)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Profile/ProfileView.swift` | 9.1 Root |
| `App/Views/Profile/PersonalDetailsView.swift` | 9.2 Personal details |

#### Views — Accounts (4)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/AccountsSettingsListView.swift` | 9.3 List |
| `App/Views/Accounts/AccountFormView.swift` | 9.4 Form |
| `App/Views/Accounts/AccountTypeSelectorView.swift` | 9.4 Type selector |
| `App/Views/Accounts/AdjustmentModeSelectorView.swift` | 9.4 Adjustment |

#### Views — Categories (5)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/CategoriesSettingsListView.swift` | 9.5 List |
| `App/Views/Categories/CategoryDetailView.swift` | 9.6 Detail |
| `App/Views/Categories/SubcategoryDetailView.swift` | 9.6 Subcategory |
| `App/Views/Categories/SubcategoryTransferSheet.swift` | 9.6 Transfer txns |
| `App/Views/Categories/SubcategoryNatureSelectorView.swift` | 9.6 Nature |

#### Views — Tags (2)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/TagsSettingsListView.swift` | 9.7 List |
| `App/Views/Tags/TagFormView.swift` | 9.8 Form |

#### Views — Favorites (3)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Favorites/FavoritesListView.swift` | 9.9 List |
| `App/Views/Favorites/FavoriteEditorView.swift` | 9.9 Editor |
| `App/Views/Favorites/FavoriteRowView.swift` | 9.9 Row |

#### Views — Personalization & Appearance (4)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/PersonalizationSettingsView.swift` | 9.12 |
| `App/Views/Settings/TabBarConfigView.swift` | 9.12 Tab config |
| `App/Views/Settings/AppIconSettingsView.swift` | 9.15 |
| `App/Views/Settings/ThemeSettingsView.swift` | 9.16 |

#### Views — Notifications (2)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/NotificationsSettingsView.swift` | 9.13 |
| `App/Views/Settings/NotificationEditorSheet.swift` | 9.13 Editor |

#### Views — Currency & Exchange (4)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/CurrencySettingsView.swift` | 9.14 |
| `App/Views/Settings/CurrencyPickerSheet.swift` | 9.14 Picker |
| `App/Views/Settings/SecondaryCurrencyPickerSheet.swift` | 9.14 Secondary |
| `App/Views/Settings/ExchangeRatesSheet.swift` | 9.14 Rates |

#### Views — Security & Subscription (3)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/BiometricSecurityView.swift` | 9.17 |
| `App/Views/Settings/SubscriptionView.swift` | 9.18 |
| `App/Views/Subscription/SubscriptionSuccessView.swift` | 9.18 Success |

#### Views — iCloud & Siri (2)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/iCloudSyncSettingsView.swift` | 9.19 |
| `App/Views/Settings/SiriShortcutsView.swift` | 9.20 |

#### Views — Tutorials & FAQ (4)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/TutorialsListView.swift` | 9.21 |
| `App/Views/Settings/TutorialDetailView.swift` | 9.21 Detail |
| `App/Views/Settings/TutorialCompletionView.swift` | 9.21 Completion |
| `App/Views/Settings/FAQView.swift` | 9.22 |

#### Views — Import / Export (7)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Import/ImportIntroSheet.swift` | 9.23 Intro |
| `App/Views/Import/ImportAccountPickerSheet.swift` | 9.23 Account picker |
| `App/Views/Import/ImportCurrencyMappingSheet.swift` | 9.23 Currency map |
| `App/Views/ExportWizard/ExportFiltersStepView.swift` | 9.24 Step 1 |
| `App/Views/ExportWizard/ExportColumnsStepView.swift` | 9.24 Step 2 |
| `App/Views/ExportWizard/ExportSummaryStepView.swift` | 9.24 Step 3 |
| `App/Views/ExportWizard/FilterComponents.swift` | 9.24 Shared |

#### Views — Reset & Shared (4)
| Archivo | Flujo |
|---------|-------|
| `App/Views/Settings/UserDataResetView.swift` | 9.25 |
| `App/Views/Shared/IconColorPickerSheet.swift` | Shared picker |
| `App/Views/Shared/ProfileToolbarButton.swift` | Shared button |
| `App/Views/Settings/SettingsPlaceholderView.swift` | Placeholder |

#### ViewModels (12)
| Archivo | Propósito |
|---------|-----------|
| `App/ViewModels/ProfileViewModel.swift` | Profile state |
| `App/ViewModels/AccountsSettingsListViewModel.swift` | Accounts list |
| `App/ViewModels/Accounts/AccountFormViewModel.swift` | Account form (20 tests) |
| `App/ViewModels/CategoriesSettingsListViewModel.swift` | Categories list |
| `App/ViewModels/CategoryDetailViewModel.swift` | Category detail (9 tests) |
| `App/ViewModels/SubcategoryTransferViewModel.swift` | Transfer txns |
| `App/ViewModels/TagsSettingsListViewModel.swift` | Tags list |
| `App/ViewModels/TagFormViewModel.swift` | Tag form (8 tests) |
| `App/ViewModels/FavoriteEditorViewModel.swift` | Favorite editor |
| `App/ViewModels/NotificationsSettingsViewModel.swift` | Notifications |
| `App/ViewModels/ExportFiltersStepViewModel.swift` | Export filters |
| `App/ViewModels/ImportIntroViewModel.swift` | Import logic |

#### Models & Utils (3)
| Archivo | Propósito |
|---------|-----------|
| `App/Models/TabBarConfiguration.swift` | Config tabs |
| `App/Models/TutorialCatalog.swift` | Catálogo tutoriales |
| `Utils/ProfileImageStorage.swift` | Storage avatar |

### Puntos de atención
- **Grupo más grande** (~50 archivos) — revisar por sub-secciones
- Account form: validación de nombre, currency, tipo, initial balance
- Category detail: verificar que delete cascade funciona (transactions, budgets)
- SubcategoryTransfer: verificar integridad de datos al mover transacciones
- Import CSV: parsing robusto, edge cases (encoding, separadores, campos vacíos)
- Export: verificar que respeta filtros y columnas seleccionadas
- Data Wipe: verificar que limpia TODO (SwiftData + UserDefaults + Keychain)
- Notifications: verificar schedule/cancel correcto
- Subscription: verificar restore purchases, estados de error

---

## Grupo 10: Upgrade / Paywall — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 10.1 | Upgrade Prompt | Sheet Pro-gated (voice, image, accounts limit, budgets limit) |
| 10.2 | Downgrade Resolution | Resolver exceso de accounts/budgets al perder Pro |
| 10.3 | Trial Banner | Banner durante período trial |
| 10.4 | Limit Reached Banner | Banner cuando se alcanza límite free tier |

### Archivos a revisar (6 + 2 services)

| Archivo | Flujo |
|---------|-------|
| `App/Views/Shared/UpgradePromptSheet.swift` | 10.1 |
| `App/Views/Subscription/DowngradeResolutionSheet.swift` | 10.2 |
| `App/Views/Shared/TrialBanner.swift` | 10.3 |
| `App/Views/Shared/LimitReachedBanner.swift` | 10.4 |
| `App/Views/Subscription/SubscriptionSuccessView.swift` | Success post-compra |
| `App/Views/Subscription/ProTrialOfferSheet.swift` | Ya revisado en G1 |
| `App/Services/FeatureGateService.swift` | Gates Pro/Free |
| `App/Services/StoreKitManager.swift` | StoreKit 2 |

### Puntos de atención
- Verificar que TODOS los feature gates están correctamente aplicados
- Downgrade resolution: verificar que no se pierden datos, solo se archivan
- StoreKit: verificar restore purchases, sandbox testing, receipt validation
- Trial: verificar que el banner desaparece correctamente al suscribirse

---

## Grupo 11: More Tab — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 11.1 | More Screen | Tabs ocultos + botón Profile |

### Archivos a revisar

| Archivo | Flujo |
|---------|-------|
| `App/ContentView.swift` (MorePlaceholderView, líneas 549-698) | Ya revisado en G1 |

### Puntos de atención
- Verificar que temporary tab se limpia al cambiar de tab
- Verificar navegación con `asyncAfter(0.05)` timing

---

## Grupo 12: Widget Deep Links — PENDIENTE

### Flujos a revisar

| # | Flujo | Destino |
|---|-------|---------|
| 12.1 | `.panel` | Panel tab |
| 12.2 | `.statistics` | Statistics tab |
| 12.3 | `.records` | Statistics → Records sub-tab |
| 12.4 | `.categories` | Statistics → Categories sub-tab |
| 12.5 | `.planning` | Planning tab |
| 12.6 | `.budgets` | Planning → Budgets |
| 12.7 | `.scheduledPayments` | Planning → Scheduled Payments |
| 12.8 | `.inbox` | Panel + Inbox sheet |
| 12.9 | `.recordsStandalone` | Records como temporary tab |

### Archivos a revisar

| Archivo | Flujo |
|---------|-------|
| `App/ContentView.swift` (MainTabView, líneas 384-534) | Deep link handling |
| `App/Models/SessionState.swift` | deepLinkDestination enum |
| `YalaWidgets/` (12 widget files) | Widget intent → deep link |

### Puntos de atención
- Verificar que cada deep link navega correctamente
- Verificar cleanup de `deepLinkDestination` (no se queda atascado)
- Verificar que temporary tab se limpia

---

## Grupo 13: Share Extension — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 13.1 | Share Image → Inbox | Usuario comparte imagen desde otra app |

### Archivos a revisar

| Archivo | Propósito |
|---------|-----------|
| `YalaShare/ShareViewController.swift` | Extension entry point |

### Puntos de atención
- Verificar que la imagen se pasa correctamente al app principal
- Verificar manejo de memoria (imágenes grandes)
- Verificar que funciona con la app en background/killed

---

## Grupo 14: Siri / Shortcuts — PENDIENTE

### Flujos a revisar

| # | Flujo | Descripción |
|---|-------|-------------|
| 14.1 | Quick Expense Shortcut | Siri "Quick Expense" → crear transacción |
| 14.2 | Control Center Intents | Intents desde Control Center |

### Archivos a revisar

| Archivo | Propósito |
|---------|-----------|
| `App/Intents/AppShortcutsProvider.swift` | Provider de shortcuts |
| `App/Intents/QuickExpenseIntent.swift` | Intent de gasto rápido |
| `Shared/ControlCenterIntents.swift` | Intents CC (archivo canónico) |

### Puntos de atención
- Verificar que los intents crean transacciones correctamente
- Verificar que respetan la currency preferida del usuario
- Verificar permisos y entitlements

---

## Convenciones de IDs

- `G{grupo}-{área}-{número}` — Ejemplo: `G3-PV-W12`
- Áreas: PV (PanelView/ViewModel), WG (Widgets), FAB (FAB/Inbox/Voice/Image), DS (Design System), A11Y (Accessibility), PERF (Performance), MAINT (Mantenibilidad), UX (User Experience), TEST (Testabilidad), ST (Statistics), TX (Transaction), PL (Planning), SR (Search), PR (Profile), UP (Upgrade), SH (Share), SI (Siri)
- Severidades: ALTA (bug funcional o crash potencial), MEDIA (correctness/UX/performance), BAJA (polish/refactoring)
