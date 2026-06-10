# Release readiness — Yala 2.0 (build 19)

**Fecha:** 2026-06-10 · **Branch:** `2.0` · Auditoría completa: build + tests + 14 dimensiones de código/QA/higiene.

## Veredicto: LISTO PARA RELEASE

Sin bloqueantes. Build limpio, 2766 tests verdes y los 31 fallos son crashes del bucket R8 conocido y documentado (no aserciones reales). Quedan **56 hallazgos de severidad alta** (ninguno bloqueante por sí solo) y una deuda significativa de device-QA pre-release listada en [Pendientes de QA](#pendientes-de-qa-pre-release).

**Total: 296 hallazgos** (295 únicos — `YalaWidgets/Widgets/CategoriesPieWidget.swift:103` fue reportado por 2 especialistas con el mismo fix) → 0 bloqueantes · 56 altos · 143 medios · 97 bajos.

---

## Dashboard

| Area | Estado | Bloqueantes | Altos | Medios | Bajos |
|---|:-:|:-:|:-:|:-:|:-:|
| Build | ✓ | 0 | 0 | 0 | 0 |
| Tests | ⚠ | 0 | 0 | 0 | 0 |
| Errores y unwraps (`errores`) | ⚠ | 0 | 11 | 20 | 22 |
| Performance (`performance`) | ⚠ | 0 | 2 | 23 | 10 |
| Fechas no inyectables (`fechas`) | ⚠ | 0 | 0 | 23 | 3 |
| SwiftData uso (`swiftdata-uso`) | ⚠ | 0 | 5 | 14 | 5 |
| SwiftData modelo (`swiftdata-modelo`) | ⚠ | 0 | 0 | 1 | 0 |
| State management (`state`) | ⚠ | 0 | 6 | 19 | 2 |
| L10n hardcoded (`l10n-hardcoded`) | ⚠ | 0 | 20* | 1 | 7 |
| L10n recursos/keys (`l10n`) | ⚠ | 0 | 1 | 2 | 11 |
| Gotchas conocidos (`gotchas`) | ⚠ | 0 | 6 | 1 | 1 |
| Concurrencia (`concurrencia`) | ⚠ | 0 | 0 | 11 | 11 |
| Privacy / compliance (`privacy`) | ⚠ | 0 | 0 | 2 | 0 |
| Dead code (`dead-code`) | ⚠ | 0 | 0 | 1 | 24 |
| QA coverage (`qa-coverage`) | ⚠ | 0 | 5 | 8 | 0 |
| Release hygiene (`release-hygiene`) | ⚠ | 0 | 0 | 17 | 1 |
| **TOTAL** | | **0** | **56** | **143** | **97** |

\* 20 reportes / 19 únicos (duplicado CategoriesPieWidget:103).

**Notas de build/tests:**

- **Build:** `BUILD SUCCEEDED`, 1 solo warning de tooling (`appintentsmetadataprocessor: Metadata extraction skipped` — sin dependencia AppIntents.framework, inofensivo).
- **Tests:** 2766 passed / 31 failed. Los 31 son **crashes SIGTRAP del bucket R8 conocido** (`makeTestContext()` + race CloudKit), concentrados en 3 suites context-based documentadas como "crashean local, válidos en CI": `CategoryDeduplicationServiceTests` (15), `BudgetFilterRegressionTests` (5), `ICloudAccountSummaryTests` (11). **Cero fallos de aserción reales.** Justificados → no bloquean.
- **Entorno (advertencias del run):** (1) el device set de simuladores quedó roto tras migrar `~/Library/Developer` al disco externo (TCC/EPERM) — reparado con symlinks al disco interno y sim iPhone 17 Pro (iOS 26.5) recreado; (2) `-parallel-testing-enabled YES` crashea el host en cascada (1340 falsos fails) — el run final usó `NO` (fallback documentado en CLAUDE.md); (3) `YalaUITests` excluido (`-only-testing:YalaTests`; XCUITests corren con scheme Yala Dev). Logs: `/tmp/yala_build.log`, `/tmp/yala_unittest_serial.log`.

---

## Bloqueantes

**Ninguno.** No hay fallos de build, los tests fallidos están justificados (bucket R8) y ningún hallazgo tiene severidad bloqueante.

---

## Criticos (alta)

### Gotchas — crashes latentes documentados (6) — ✅ RESUELTOS (Tanda 1, 2026-06-10)

El gotcha `AmountText` (lee `@Environment(AppPreferences)`) dentro de `.annotation{}` de Swift Charts **NO propaga environment → SIGTRAP en runtime** — es la misma causa raíz del crash del chip Estadísticas (`8bb5ace8`). Fix en todos: `Text` con el valor ya resuelto en el callsite (`appPreferences.currency(...)` / `YalaFormatter`).

| # | Ubicación | Detalle |
|---|---|---|
| 1 | ✅ `Yala/App/Views/Planning/BudgetChartsView.swift:311` | RESUELTO — `Text` pre-resuelto + lineLimit/minimumScaleFactor (data labels en serie). Device-QA: 6 labels renderizados |
| 2 | ✅ `Yala/App/Views/Planning/BudgetChartsView.swift:442` | RESUELTO — device-QA: tooltip "6 jun. S/ 325.00" en vivo sin crash |
| 3 | ✅ `Yala/App/Views/Reports/CashFlow/CashFlowCellMiniChart.swift:89` | RESUELTO — `Text(appPreferences.currency(...))` (la vista ya inyectaba AppPreferences); no-crash con gestos en device-QA |
| 4 | ✅ `Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:410` | RESUELTO — 2× `Text` pre-resueltos (el de netFlow conserva `forceSign: true`); no-crash en device-QA |
| 5 | ✅ `Yala/App/Views/Statistics/PeriodComparisonChartView.swift:178` | RESUELTO (también L195) — `YalaFormatterStatic.currency` (vista sin `@Environment(AppPreferences)`). Device-QA: tooltip dual "S/ 80,324.00 / S/ 71,107.30" en vivo |
| 6 | ✅ `Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift:331` | RESUELTO — `.dismissKeyboardOnTap()` en el VStack del ScrollView. Device-QA: teclado baja (3× verificado vía nodo keyboard del AX tree) |

### Errores y unwraps (11) — ✅ RESUELTOS (#1 Tanda 1; #2-12 Tanda 2, 2026-06-10)

| # | Ubicación | Regla | Fix |
|---|---|---|---|
| 1 | ✅ `Yala/App/Views/Subscription/ProTrialOfferSheet.swift:103` | **RESUELTO (Tanda 1, 06-10)** — botón Restaurar replicado de `SubscriptionView:104-110` (`.thPrimaryText`), tras "Quizás después". Device-QA: tap dispara `AppStore.sync`, el alert de error existente captura el fallo | — |
| 2 | ✅ `Yala/App/ContentView.swift:1215` | **RESUELTO (Tanda 2, 06-10, `9c8618d7`)** — do/catch envolviendo ambos fetches + log; no presenta downgrade con datos parciales (el productor re-encola al siguiente cold launch) | — |
| 3 | ✅ `Yala/Services/Groups/GroupTransactionBridge.swift:556` | **RESUELTO (Tanda 2, 06-10, `722fe8db`)** — D-A opción (a) confirmada por owner: do/catch + log DEBUG + telemetría `bridgeVirtualLentTxFailed` (falla degradada, la TX1 real sobrevive) | — |
| 4 | ✅ `Yala/Services/ChatAssistantService.swift:216` (dim. swiftdata-uso, ver abajo) | — | — |
| 5 | ✅ `Yala/App/Views/Accounts/AccountFormView.swift:637` | **RESUELTO (Tanda 2, 06-10, `9c8618d7`)** — el catch setea `deleteErrorMessage` + `isShowingDeleteError`; el alert cableado por fin se activa | — |
| 6 | ✅ `Yala/App/Views/Groups/FullModeActivationView.swift:67` | **RESUELTO (Tanda 2, 06-10, `9c8618d7`)** — do/catch cubre fetch (L62) Y save (L70); cleanup defensivo no bloquea la activación | — |
| 7 | ✅ `Yala/App/Views/Onboarding/WelcomeHeroView.swift:406` | **RESUELTO (Tanda 2, 06-10, `9c8618d7`)** — do/catch + log; `markFetchCompleted()` corre en ambos paths | — |
| 8 | ✅ `Yala/Models/Budget.swift:135` | **RESUELTO (Tanda 2, 06-10, `95d396f9`)** — do/catch + log; el catch cae al fallback M2M existente | — |
| 9 | ✅ `Yala/App/Services/ChatSuggestionsLLMService.swift:245` | **RESUELTO (Tanda 2, 06-10, `233822ea`)** — `try` directo; el catch externo que ya loggea lo captura | — |
| 10 | ✅ `Yala/Utils/TransactionsExportService.swift:114` | **RESUELTO (Tanda 2, 06-10, `95d396f9`)** — do/catch + log + `allTags = []` (export degrada sin nombres de tags, no aborta) | — |
| 11 | ✅ `Yala/Utils/TransactionsExportService.swift:183` | **RESUELTO (Tanda 2, 06-10, `95d396f9`)** — ídem L114 | — |
| 12 | ✅ `Yala/App/Logic/Calculators/WeekdaySpendingCalculator.swift:113` | **RESUELTO (Tanda 2, 06-10, `95d396f9`)** — `guard let next = ... else { break }` | — |

### SwiftData uso (5) — ✅ RESUELTOS (Tanda 2, 2026-06-10)

| # | Ubicación | Regla | Fix |
|---|---|---|---|
| 1 | ✅ `Yala/Services/ChatAssistantService.swift:216` | **RESUELTO (Tanda 2, 06-10, `233822ea`)** — do/catch + log + re-throw: el catch genérico del VM lo envuelve en `.networkError` → banner `errorGeneric` (ya no responde "no hay cuentas" siendo falso) | — |
| 2 | ✅ `Yala/Services/Chat/FullFinancialContextBuilder.swift:867` | **RESUELTO (Tanda 2, 06-10, `233822ea`)** — los 5 fetchers (867/871/875/879/883) con do/catch + log DEBUG + `return []` | — |
| 3 | ✅ `Yala/App/ViewModels/ChatAssistantViewModel.swift:644` | **RESUELTO (Tanda 2, 06-10, `233822ea`)** — do/catch + log DEBUG (comportamiento preservado, con diagnóstico) | — |
| 4 | ✅ `Yala/App/ViewModels/GroupDetailViewModel.swift:152` | **RESUELTO (Tanda 2, 06-10, `722fe8db`)** — do/catch + log + `txBridgeMap = [:]`; `mySharesByExpense` no depende del fetch y sigue | — |
| 5 | ✅ `Yala/Utils/TransactionsExportService.swift:90` | **RESUELTO (Tanda 2, 06-10, `95d396f9`)** — `@MainActor` en `exportToCSV`, `export`, `applyInMemoryFilters`, `makeExportData`; cascada: `TransactionItem.recalculatePreferredCurrency` también anotada (sus 3 callers ya eran @MainActor) | — |

### State management (6) — ✅ RESUELTOS (Tanda 2, 2026-06-10)

| # | Ubicación | Regla | Fix |
|---|---|---|---|
| 1 | ✅ `Yala/Services/CurrencyConverter.swift:37` | **RESUELTO (Tanda 2, 06-10, `95d396f9`)** — clase anotada `@MainActor` (callsites verificados todos main: CSV import usa funcs @MainActor, calculators con Mock en tests); suite `CurrencyConverterTests` anotada | — |
| 2 | ✅ `YalaTests/ChatAssistantViewModelTests.swift:106` | **RESUELTO (Tanda 2, 06-10, `36bb7f9c`)** — `ChatAssistantViewModel.init(defaults: = .standard)` + test siembra/lee en `makeIsolatedDefaults()` | — |
| 3 | ✅ `YalaTests/ChatAssistantViewModelTests.swift:153` | **RESUELTO (Tanda 2, 06-10, `36bb7f9c`)** — ídem (`clearPersistedSession` opera sobre el aislado inyectado) | — |
| 4 | ✅ `YalaTests/ChatAssistantViewModelTests.swift:291` | **RESUELTO (Tanda 2, 06-10, `36bb7f9c`)** — ídem (`stripsLegacyToolPayload`) | — |
| 5 | ✅ `YalaTests/ChatSuggestionsLLMServiceTests.swift:143` | **RESUELTO (Tanda 2, 06-10, `36bb7f9c`)** — `cachedSuggestions`/`setCached` aceptan `defaults:` (default `.standard`); los 3 tests de cache usan aislado y `clearCacheKeys()` se eliminó. Nota: la suite **ya era** `.serialized` (el audit estaba desactualizado en eso) | — |
| 6 | ✅ `YalaTests/ChatSuggestionsLLMServiceTests.swift:178` | **RESUELTO (Tanda 2, 06-10, `36bb7f9c`)** — la siembra corrupta va al mismo defaults aislado que lee el service | — |

### L10n hardcoded — UI visible sin localizar (19 únicos) — ✅ RESUELTOS (Tanda 3, 2026-06-10)

13 keys nuevas × 16 locales (voseo es-AR, Sie de, vouvoiement fr, です/ます ja, 你 zh-Hans, tu pt-PT/você pt-BR) + 1 key del target widgets × 16 + reuso de 4 accessors existentes. Bloque `/* MARK: Release 2.0 — a11y & UI keys */` al final de cada `Localizable.strings`.

| # | Ubicación | String | Resolución |
|---|---|---|---|
| 1 | ✅ `NewTransactionViewModel.swift:868` | Categoría `"Otros"` persistida | `L10n.Category.other` (accessor existente) |
| 2 | ✅ `NewTransactionViewModel.swift:932` | Categoría `"Ingresos"` persistida | `L10n.Category.incomeCategory` (existente) |
| 3 | ✅ `CategoriesPieWidget.swift:103` | `"Otros"` en widget | Key nueva `widget.ui.others` × 16 en el bundle del TARGET widgets (`String(localized:bundle:)`, patrón `widget.ui.categorias` del mismo archivo) |
| 4 | ✅ `SubcategoriesPieWidget.swift:103` | `"Otros"` ídem | Misma key `widget.ui.others` compartida |
| 5 | ✅ `TransactionDetailSheet.swift:493` | `"TC: "` | Key nueva `transaction.exchangeRateShort %@` ("Rate:"/"Kurs:"/"レート:"…) |
| 6 | ✅ `CashFlowChartsSheet.swift:466` | Chip `"IA"` | Key nueva `cashFlowPlan.aiChipLabel` (AI en/ja/zh/nl/pl, KI de, IA es/fr/it/pt) |
| 7 | ✅ `TrendsTabView.swift:932` | Título `"Total"` | `L10n.CashFlowViewType.total` (existente) |
| 8 | ✅ `PieChartVariationHeader.swift:84` | `Text("vs")` | Key nueva `common.vs` — migradas las **4 instancias** del patrón (también `TrendsTabView:420/:542` y `CashFlowWidget:437`, listadas como bajos) |
| 9 | ✅ `BudgetsListView.swift:137` | `Picker("Period Type")` | Key nueva `budgets.period.typeLabel` |
| 10 | ✅ `BudgetEditorView.swift:406` | Placeholder `"1–100"` | Key nueva `budgets.alerts.thresholdPlaceholder` (valor universal ×16) |
| 11 | ✅ `WelcomeHeroView.swift:265` | a11yLabel `"Card X of Y"` | Reuso `L10n.Accessibility.pageIndicator(_:_:)` existente ("Página %1$d de %2$d") — 0 keys |
| 12 | ✅ `VariationChip.swift:109` | `"Aumento"/"Disminución"` | Keys nuevas `accessibility.variationIncrease/Decrease %@` |
| 13 | ✅ `UserDataResetView.swift:71` | a11yHint `"Procesando"` | Key nueva `accessibility.processing` (namespace a11y, no Common) |
| 14 | ✅ `TabBarConfigView.swift:155` | `String(localized: "Quitar \(...)")` roto | Key nueva `accessibility.removeTab %@` + accessor con `String(format:)` |
| 15 | ✅ `ExportColumnsStepView.swift:65` | a11yHint columna | Key nueva `accessibility.selectAtLeastOneColumn` (voseo es-AR "Seleccioná") |
| 16 | ✅ `ExportFiltersStepView.swift:173` | a11yHint filtros | Key nueva `accessibility.completeRequiredFilters` ("Completá" es-AR) |
| 17 | ✅ `ExportSummaryStepView.swift:190` | a11yHint exportación | Key nueva `accessibility.exportingHint` (pt-PT "em curso") |
| 18 | ✅ `ImportIntroSheet.swift:167` | `disabledHint` import | Reuso `L10n.Accessibility.importingHint` existente — 0 keys |
| 19 | ✅ `ImportCurrencyMappingSheet.swift:229` | `disabledHint` divisas | Key nueva `accessibility.assignAllCurrencies` ("Asigná" es-AR, tu pt-PT "Atribui") |

### L10n recursos/keys (1) — ✅ RESUELTO (Tanda 3, 2026-06-10) + 1 hallazgo nuevo cerrado

| # | Ubicación | Regla | Resolución |
|---|---|---|---|
| 1 | ✅ `Yala/App/Intents/QuickExpenseIntent.swift:625` | `String(localized:)` con interpolación busca `…partial %lld %lld` que no existe → key cruda | La key **sin sufijo** ya existía en los 16 locales (el audit estaba desactualizado) con `%1$lld/%2$lld` de contenido. Fix: accessor `L10n.Shortcut.successPartial(_:_:)` con `String(format:)` + `Int64` y callsite migrado. Las hermanas `single %@`/`multiple %lld`/`offline %@` resuelven por sufijo en el nombre — no se tocan |
| 2 | ✅ **NUEVO (destapado en Tanda 3)** — `YalaWidgets/Resources/{es-ES,es-AR,en-GB,pt-PT}.lproj` | Las 4 variantes del **target widgets** existían "overrides-only" (0 keys) — el patrón marker-only FALSO documentado en CLAUDE.md: con la variante como idioma de sistema, los widgets renderizaban **las 116 keys crudas** | Materializadas las 116 keys desde el padre (es-419/en/pt-BR) en las 4 variantes + suite nueva `WidgetLocalizationParityTests` (2 tests vía `#filePath` — los recursos del widget no están en `Bundle.main` y `LocalizationParityTests` no los cubría) |

### Performance — hot paths (2) — ✅ RESUELTOS (Tanda 1, 2026-06-10)

| # | Ubicación | Regla | Fix |
|---|---|---|---|
| 1 | ✅ `Yala/App/Views/Shared/UIHelpers.swift:317` | RESUELTO — `private static let compactTableFormatter` cacheado (patrón AccountsSettingsListViewModel:134). Paridad validada por `amountCashFlowCell_parity` (45/45 verdes) | — |
| 2 | ✅ `Yala/Utils/CategoryImportHelper.swift:48` | RESUELTO — `descriptor.fetchLimit = 1` (el resultado solo se usa con `.first`; el 2º fetch de la función necesita todas las categorías y no se tocó) | — |

### QA coverage — áreas críticas stale (5)

Consolidadas también como checklist en [Pendientes de QA](#pendientes-de-qa-pre-release).

| # | Ubicación | Área | Detalle |
|---|---|---|---|
| 1 | `qa/coverage-index.json:333` | `groups-bridge-personal` | **coverage=none + 7 fixes del 06-09** post-lastVerified (GroupTransactionBridge/DraftService/GroupDraftFinalizationLogic) → `/device-qa` F-S2-02..05, F-S2-11, F-S3-04 |
| 2 | `qa/coverage-index.json:1389` | `groups-cross-device-sync` | lastVerified=06-01 pero SplitSyncManager tocado 06-08/09 → re-verificar F-S4-*/F-S5-01 |
| 3 | `qa/coverage-index.json:1414` | `groups-notifications-deeplinks` | AppRouter tocado 06-08 (invite re-emit) → re-verificar F-S4-01/F-S5-03 |
| 4 | `qa/coverage-index.json:1541` | `migration-csv-mirror` | AppBootstrapper (host de la migración V3) tocado 5× tras lastVerified → re-verificar F-IMP-04 |
| 5 | `qa/coverage-index.json:1431` | `icloud-sync-multi-device` | iCloudSyncService + AppBootstrapper tocados tras lastVerified → re-verificar F-ICL-01..04 |

---

## Medios

Los 8 medios de `qa-coverage` y los 16 de `release-hygiene` con regla "device QA pendiente" están consolidados en [Pendientes de QA pre-release](#pendientes-de-qa-pre-release). El resto (119) a continuación.

### errores (20)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Logic/OnboardingResetHelper.swift:26` | Keys UserDefaults stringly-typed duplican `AppPreferences.Keys` | Usar `AppPreferences.Keys.userName`/`.defaultCurrencyCode` |
| `Yala/App/Services/ChatSuggestionsLLMService.swift:264` | catch silencioso sin log (fetch Budget) | `print` en `#if DEBUG` |
| `Yala/App/Services/ChatSuggestionsLLMService.swift:272` | catch silencioso sin log (fetch ScheduledPayment) | `print` en `#if DEBUG` |
| `Yala/App/Services/DraftBuilder.swift:123` | `try?` silencia fetch (matchSubcategoryByHint) | do/catch + log DEBUG (patrón del archivo) |
| `Yala/App/Services/DraftBuilder.swift:233` | catch silencioso sin log (matchTags) | log DEBUG en el catch |
| `Yala/App/Services/PanelPreferencesMigration.swift:85` | `try?` decode descarta config v1.x del usuario sin diagnóstico | do/catch + log DEBUG |
| `Yala/App/Views/Groups/FullModeActivationView.swift:39` | `try?` fetchCount sin log | do/catch + log DEBUG |
| `Yala/App/Views/Profile/PersonalDetailsView.swift:75` | `try?` loadTransferable (foto) sin log | do/catch + log DEBUG |
| `Yala/Services/Chat/ChatIntentClassifierService.swift:186` | `try?` NSRegularExpression silencia regex corrupta | Pre-compilar `static let` (+ perf) o log/assert DEBUG |
| `Yala/Services/Groups/BridgeModeResolver.swift:123` | `try?` fetch en función `throws` — 0 borrados sin señal | do/catch + log DEBUG |
| `Yala/Services/Groups/GroupBridgeRaceCleaner.swift:51` | `try?` fetch TXs reales — no limpia drafts sin log | do/catch + log DEBUG (paridad con el fetch de drafts) |
| `Yala/Services/Groups/GroupExpenseService.swift:376` | `try?` unbridgeSettlement — TX/draft huérfana sin log | do/catch + log DEBUG |
| `Yala/Services/Groups/GroupTransactionBridge.swift:802` | `try?` subcat settlementSent → nil silencioso | do/catch + nil explícito con log |
| `Yala/Services/Groups/GroupTransactionBridge.swift:837` | `try?` subcat settlementReceived → nil silencioso | do/catch + nil explícito con log |
| `Yala/Services/Groups/SplitSyncManager.swift:782` | `try?` fetch isAdmin → false sin log (admin invisible para notifs) | do/catch + log + return false explícito |
| `YalaTests/AmountParserTests.swift:20` | Force unwrap tras `#expect` (no aborta en Swift Testing) | `let parsed = try #require(result)` |
| `YalaTests/DataWipeServiceTests.swift:41` | `UserDefaults.standard` en test | `UserDefaults(suiteName: "test.\(UUID())")!` |
| `YalaTests/DataWipeServiceTests.swift:68` | Ídem; cleanup solo en happy path | Defaults aislado + cleanup garantizado |
| `YalaTests/DateParserTests.swift:20` | `#expect != nil` + force unwrap en 8 funcs | `try #require` (idiom ya en L116 del mismo archivo) |
| `YalaTests/GroupNotificationServiceTests.swift:132` | Force unwrap `destination!` | `guard let` + `Issue.record` |

### performance (23)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Logic/Helpers/PreviousPeriodHelper.swift:154` | DateFormatter per-render (5 widgets/vistas) | `static let` |
| `Yala/App/Logic/Helpers/PreviousPeriodHelper.swift:240` | NumberFormatter per-render (`VariationChip.body`) | `static let` |
| `Yala/App/Services/ImageOCR/Extractors/AmountParser.swift:39` | NSRegularExpression compilado en loop | 6 patrones `static let` pre-compilados |
| `Yala/App/Services/ImageOCR/Extractors/DateParser.swift:57` | NSRegularExpression en for loop | `static let` indexados por patrón |
| `Yala/App/Services/ImageOCR/Extractors/DateParser.swift:65` | DateFormatter por iteración | Cache por formato o instancia única reconfigurada |
| `Yala/App/Services/ImageOCR/Extractors/ScreenshotSingleExtractor.swift:83` | NSRegularExpression por iteración (merchant) | 4 patrones `static let` |
| `Yala/App/Services/ImageVision/VisionDraftFactory.swift:130` | DateFormatter por transacción (loop makeDrafts) | `static` privada |
| `Yala/App/Services/MerchantMemoryService.swift:148` | Fetch sin fetchLimit con `.first` | `fetchLimit = 1` |
| `Yala/App/Views/Categories/SubcategoryDetailView.swift:392` | Full scan Subcategory + filter en memoria | Predicate por `persistentModelID` del parent |
| `Yala/App/Views/Filters/PeriodSelectorComponents.swift:94` | DateFormatter por render del body | `static let` cacheado |
| `Yala/App/Views/Groups/GroupsContainerView.swift:295` | Fetch sin fetchLimit con `.first` | `fetchLimit = 1` |
| `Yala/App/Views/Settings/iCloudSyncSettingsView.swift:277` | RelativeDateTimeFormatter por render | `static let` |
| `Yala/App/Views/Transactions/NewTransactionView.swift:1578` | Fetch sin predicate/limit + `.first(where:)` | `#Predicate { $0.id == uuid }` + `fetchLimit = 1` (patrón ScheduledPaymentEditorView:1143) |
| `Yala/Models/NotificationItem.swift:305` | DateFormatter en computed por fila (invocada 2×/fila) | `static let timeFormatter` |
| `Yala/Services/ExchangeRateService.swift:296` | `getMostRecentRate` sin fetchLimit (puede traer cientos) | `fetchLimit = 1` (paridad getLatestRate/getOldestRate) |
| `Yala/Services/TranscriptionParserService.swift:335` | DateFormatter por item en `.map` | Elevar a cacheado (como `dateFormatter` L115) |
| `Yala/Services/WidgetDataCache.swift:621` | O(n²): períodos (≤120) × scan lineal de transactionsByDay | Pre-agrupar por período → O(n+m) |
| `Yala/Utils/TransactionCSVImportService.swift:835` | DateFormatter por fila (3 bucles: 419/669/1283) | `static` cached |
| `Yala/Utils/TransactionCSVImportService.swift:491` | Fetch Category/Subcategory sin limit por fila (6 sitios) | `fetchLimit = 1` en 491/509/724/736/1346/1358 |
| `Yala/Utils/XLSXReader.swift:254` | DateFormatter por celda de fecha XLSX | `static` privada |
| `YalaWidgets/Utils/SmartAxisHelper.swift:133` | DateFormatter por tick de eje en widget | `static let` / NSCache por dateFormat |
| `YalaWidgets/Widgets/BudgetsWidget.swift:269` | NumberFormatter por fila en computed | `static let amountFormatter` |
| `YalaWidgets/Widgets/ScheduledPaymentsWidget.swift:289` | DateFormatter por fila (ForEach) | `static let dateFormatter` |

### fechas (23) — patrón canónico: inyectar `now: Date = .now` / `calendar: Calendar = .current`

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Logic/Calculators/CashFlowProjectionCalculator.swift:142` | `Date.now` en entry point `calculate` | Params `now`/`calendar` (patrón FinancialScoreCalculator:84) |
| `Yala/App/Logic/Calculators/InsightsCalculator.swift:244` | `Calendar.current` en `calculate()` (y L289) | Param `calendar` |
| `Yala/App/Logic/Calculators/InsightsCalculator.swift:489` | `Date.now` en calculateSubscriptionsTotal | Propagar `now` desde `calculate()` |
| `Yala/App/Logic/Calculators/InsightsCalculator.swift:505` | `Date.now` en `currentBudgetInterval(for:)` pública | Params `now`/`calendar` + 2 callsites |
| `Yala/App/Logic/Calculators/InsightsCalculator.swift:546` | `Date.now` en calculateCommitments | Propagar `now` |
| `Yala/App/Logic/Calculators/LiveBalanceCalculator.swift:117` | `Date.now` en `liveBalanceOverride` | Param `now` + actualizar callsites |
| `Yala/App/Logic/Calculators/WeekdaySpendingCalculator.swift:55` | `Calendar.current` en calculator testeable | Param `calendar` en `calculate()` |
| `Yala/App/Logic/Calculators/WeekdaySpendingCalculator.swift:97` | `Calendar.current` releído en weekdayOccurrences | Recibir el `calendar` propagado |
| `Yala/App/Models/ChatAssistantModels.swift:115` | `Date.now`/`Calendar.current` en `toDateInterval` | Params `now`/`calendar` (3 tests existentes se vuelven deterministas) |
| `Yala/App/Models/SetupChecklistManager.swift:97` | Expiración 3 días con `.now` no testeable | Param `now` en `shouldShow` |
| `Yala/App/Services/ImageOCR/Extractors/DateParser.swift:21` | `Date.now` en `parse(_:)` ("hoy") | Param `now` |
| `Yala/App/Services/ImageOCR/Extractors/DateParser.swift:24` | `Calendar.current` + `Date.now` ("ayer") | Params `now`/`calendar` |
| `Yala/App/Services/DraftBuilder.swift:211` | `Date.now` como fallback de fecha | Param `now` en `build(...)` |
| `Yala/App/Services/DraftDeduplicationService.swift:52` | `Calendar.current` en `datesMatch` | Param `calendar` en datesMatch/isDuplicate |
| `Yala/App/Services/ScheduledPaymentDraftService.swift:22` | `Date.now` en `processDuePayments` (predicado vencidos no testeable) | Param `now` |
| `Yala/App/Services/ReviewPromptService.swift:47` | Umbrales install/cooldown 120d con `.now`; sin tests | Param `now` en `shouldPrompt` |
| `Yala/Services/BudgetAlertTracker.swift:42` | `Date.now` en `periodKey(for:)` | Param `now` (sibling `getCurrentPeriodInterval` ya lo tiene) |
| `Yala/Services/BudgetAlertTracker.swift:107` | `Date.now` ×2 en `cleanupOldEntries` | Param `now` (patrón ScheduledPaymentNotificationTracker) |
| `Yala/Services/BudgetAlertService.swift:61` | `Calendar.current`+`Date.now` en `checkBudgetsAndNotify` | Param `now` propagado a earliestDate |
| `Yala/Services/InitialBalanceService.swift:64` | Rama "sin transacciones" no determinista (L64/76/79-80) | Param `now` en `calculateInitialBalanceDate` |
| `Yala/Services/ReportNotificationService.swift:79` | `Date.now`/`Calendar.current` en `shouldSendNow` | Param `now` |
| `Yala/Services/ReportNotificationService.swift:198` | Ídem en `getIntervalForReportType` | Param `now` |
| `Yala/Services/WidgetDataCache.swift:443` | `Date.now`/`Calendar.current` en `calculateBudgetSpent` | Param `now` |

### swiftdata-uso (14)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Logic/Helpers/ExchangeRateWidgetHelper.swift:77` | `buildChartPoints` manipula ModelContext sin `@MainActor` | Anotar `@MainActor` |
| `Yala/App/Logic/Helpers/ExchangeRateWidgetHelper.swift:123` | `getAverageRatesForBucket` ídem | Anotar `@MainActor` (ambas, mismo invariante) |
| `Yala/App/ViewModels/CashFlowPlanViewModel.swift:360` | `try modelContext?.save()` — nil-context silencia el save (reorderLines) | `guard let ctx` + `try ctx.save()` |
| `Yala/App/ViewModels/CashFlowPlanViewModel.swift:440` | Ídem en setOverrideAndUpdateFuture — mutaciones sin persistir | `guard let ctx` antes de mutar |
| `Yala/App/Views/Inbox/GroupExpenseDraftFinalizationSheet.swift:93` | `try?` fetch group sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupExpenseDraftFinalizationSheet.swift:101` | `try?` fetch expense sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupExpenseAccountFinalizationSheet.swift:123` | `try?` fetch expense sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupExpenseAccountFinalizationSheet.swift:130` | `try?` fetch group sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupExpenseAccountAndSubcategoryFinalizationSheet.swift:141` | `try?` fetch expense sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupExpenseAccountAndSubcategoryFinalizationSheet.swift:148` | `try?` fetch group sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupSettlementDraftFinalizationSheet.swift:105` | `try?` fetch group sin log | do/catch + log DEBUG |
| `Yala/App/Views/Inbox/GroupSettlementDraftFinalizationSheet.swift:113` | `try?` fetch settlement sin log | do/catch + log DEBUG |
| `Yala/App/Views/Planning/ScheduledPaymentEditorView.swift:1143` | Fetch sin fetchLimit con `.first` | `fetchLimit = 1` |
| `Yala/App/Views/Reports/CashFlow/CashFlowOthersSheet.swift:125` | Fetch de toda la tabla Category para un lookup | Predicate name+isIncome + `fetchLimit = 1` |

### swiftdata-modelo (1)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/Models/Category.swift:36` | `.nullify` con semántica cascade — el placeholder `safeCategory` enmascara Subcategory huérfanas | Mantener `.nullify` (decisión por @Query) pero añadir reparenteo/limpieza boot-time + garantizar borrado solo vía `EntityDeletionService.deleteCategory` |

### state (19)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Views/Groups/GroupReconnectView.swift:15` | `@AppStorage` directo en View | `@Environment(AppPreferences.self)` → `hasCompletedOnboarding` (AppPreferences:371) |
| `Yala/App/Views/Groups/GroupSettingsView.swift:899` | `UserDefaults.standard` directo en View | `appPreferences.userName` (ya inyectado) |
| `Yala/App/Views/Inbox/InboxDraftEditSheet.swift:387` | `Binding(get:set:)` en computed de body | `@State effectiveNeed` + `.onChange(of: selectedSubcategory)` |
| `Yala/App/Views/Panel/PanelSheetsModifier.swift:85` | `Binding(get:set:)` en `.sheet` | `$sheets.showNewTransactionFromChat` + `.onChange` limpia prefill |
| `Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift:182` | `Binding(get:set:)` en @ViewBuilder | Helper `makeVisibilityBinding(for:)` fuera del builder |
| `Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift:231` | Ídem (size selector) | Helper `makeSizeBinding(for:)` |
| `Yala/App/Views/Panel/PanelSectionsConfigView.swift:135` | `Binding(get:set:)` mutando Set en @ViewBuilder | Helper no-@ViewBuilder o método dedicado en AppPreferences |
| `Yala/App/Views/Panel/PanelView.swift:364` | `Binding(get:set:)` en body (SiriTipCard) | `@Bindable var prefs` + `$prefs.showSiriTip` (patrón CategoriesTabView:570) |
| `Yala/App/Views/Planning/ScheduledPaymentDetailView.swift:322` | `Binding(get:set:)` en función de ForEach | Sub-View con `@Binding` o `.confirmationDialog(item:)` |
| `Yala/App/Views/Planning/ScheduledPaymentEditorView.swift:859` | `Binding(get:set:)` en computed de body | `defaultEndDate` computado + `.onChange(of: paymentDate)` + `$endDate` |
| `Yala/App/Views/Records/BulkEditSheet.swift:198` | `Binding(get:set:)` en body (alert) | `@State showBulkUpdateErrorAlert` + `.onChange` |
| `Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift:45` | `Binding(get:set:)` en `.sheet(isPresented:)` | `.sheet(item: $selectedCellLineID)` |
| `Yala/App/Views/Settings/UserDataResetView.swift:109` | `Binding(get:set:)` en body (errorMessage) | `@State showErrorAlert` + `.onChange(of: errorMessage)` |
| `YalaTests/ChatAssistantViewModelTests.swift:78` | `UserDefaults.standard` en helpers de test | Inyectar `UserDefaults` en el VM (init param) |
| `YalaTests/InitialBalanceServiceTests.swift:217` | Test muta `UserDefaults.standard` (preferredCurrency) | `makeIsolatedDefaults()` + inyección en CurrencyDefaults/servicio |
| `YalaTests/ScheduledPaymentNotificationTrackerTests.swift:23` | `UserDefaults.standard` en tracker test | Init inyectable / `_testReset(defaults:)` + suite aislada |
| `YalaTests/SetupChecklistManagerTests.swift:21` | `UserDefaults.standard` — resetAll no aísla | `makeIsolatedDefaults()` + init inyectable |
| `YalaTests/SetupChecklistManagerTests.swift:168` | Key `pro.upsell.sessionCount` escrita en `.standard` sin cleanup | Confinaría con defaults aislado |
| `YalaTests/TrendGroupingTests.swift:90` | `CurrencyDefaults.currentPreferred` lee `.standard` | Aislar/inyectar o rediseñar el assert sin leer `.standard` |

### l10n-hardcoded (1)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Views/Groups/GroupSettingsView.swift:900` | Fallback `"Usuario"` hardcodeado | `L10n.Profile.defaultName` (patrón GroupDetailViewModel:249) |

### l10n recursos/keys (2)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/Resources/es-419.lproj/Localizable.strings:459` | 31 keys duplicadas en los 13 locales base; **11 con valores en conflicto** (gana la última: `settings.theme` "Tema" vs "Temas", `widget.size`, `common.none`, `subcategory.balanceAdjustment` con 8 callsites, etc.) | Dedupe consciente del bloque legacy (~L455-1700) eligiendo valor correcto por key; variantes es-ES/en-GB/pt-PT ya limpias |
| `Yala/Resources/es-419.lproj/Localizable.strings:768` | `widget.size` duplicada con placeholder divergente ("Tamaño" vs "Tamaño: %@") en 13 locales | Eliminar una declaración; borrar accessors muertos `L10n.Widget.size/preferences` (`Yala/Utils/L10n.swift:3888-3890`) |

### gotchas (1) — ✅ RESUELTO (Tanda 1, 2026-06-10)

| Ubicación | Regla | Fix |
|---|---|---|
| ✅ `Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift:586` | RESUELTO — `.dismissKeyboardOnTap()` en el VStack de CashFlowAddFromScheduledView (paridad con hermanas L229/L676). Device-QA: keyboard 1→0 con tap en label | — |

### concurrencia (11)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Views/ExportWizard/ExportSummaryStepView.swift:292` | `Task.sleep(0.5s)` para visibilidad de spinner | Señal de completado real en el VM |
| `Yala/App/Views/Favorites/FavoriteEditorView.swift:169` | `Task.sleep(500ms)` para focus de UI | `.onAppear` directo o diferir un tick |
| `Yala/App/Views/Panel/PanelSheetsModifier.swift:232` | `Task.sleep(300ms)` en onDismiss (innecesario) | Asignar `showImageSelection = true` directo |
| `Yala/App/Views/Settings/UserDataResetView.swift:146` | `Task.sleep(500ms)` espera desmontaje de @Query (>50ms permitidos) | Señal determinística (flag @Observable + `.onDisappear`) |
| `Yala/App/Views/SplashScreenView.swift:93` | `Task{}` con sleep no cancelado — Timer puede crearse tras onDisappear | `@State entranceTask` + cancel, o modifier `.task{}` |
| `YalaTests/AppPreferencesTests.swift:660` | `UserDefaults.standard` sin cleanup en test serializado | `defer { removeObject }` ×2 keys |
| `YalaTests/AppPreferencesTests.swift:683` | Ídem (`currencyDisplayFormat`; también ~L700) | `defer { removeObject }` |
| `YalaTests/AppRouterTests.swift:17` | Singleton `AppRouter.shared._testReset()` sin `@Suite(.serialized)` | Añadir `@Suite(.serialized)` |
| `YalaTests/FeatureGateTests.swift:45` | `FeatureGateService.shared` mutado sin `.serialized` | `@Suite(.serialized)` |
| `YalaTests/GroupNotificationServiceTests.swift:124` | `AppRouter.shared._testReset()` sin `.serialized` | `@Suite(.serialized)` |
| `YalaTests/GroupExpenseViewModelTests.swift:246` | `_testResetContext()` sin `defer { restore }` — context queda nil para suites externas | Capturar prev + `defer` restore |

### privacy / Apple compliance (2)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/Resources/PrivacyInfo.xcprivacy:9` | `NSPrivacyCollectedDataTypes` solo declara Audio/Fotos; el chat IA envía **contexto financiero** (montos, notas, tags) a OpenAI | Añadir `FinancialInfo` (y/u `OtherUserContent`), Linked=false, Tracking=false, purpose AppFunctionality — alineado con la nutrition label de ASC |
| `Yala/Resources/Info.plist:20` | `OPENAI_API_KEY` resuelta queda **extraíble del IPA** (`plutil`) | Proxy backend / gateway con App Attest y sacar keys del plist; mientras tanto, rate-limit y cuota en el dashboard de OpenAI |

### dead-code (1)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/App/Views/Transactions/Components/TransactionAmountInputView.swift:12` | Archivo entero sin referencias (extraído de NewTransactionView, nunca cableado) | Eliminar el archivo completo |

### release-hygiene (1 — el resto en §Pendientes de QA)

| Ubicación | Regla | Fix |
|---|---|---|
| `Yala/Services/iCloudSyncService.swift:240` | TODO crítico duplicado en código (ya existe ticket `Backlog/debounce-transactions-imported-from-sync-observer.md`) | Eliminar el marker o implementar el debounce 1s |

---

## Bajos

**97 hallazgos** — counts por dimensión:

| Dimensión | Bajos | Nota |
|---|:-:|---|
| dead-code | 24 | structs/funcs sin referencias listos para borrar (SkeletonView ×5, FilterChipsSection ×2, Groups services ×9, etc.) |
| errores | 22 | mayormente force unwraps en tests (`#expect` + `!`) y `try?` best-effort sin log |
| l10n (recursos) | 11 | ~1000+ strings huérfanos en 16 locales (familias `setup.*`, `control.*`, `scheduled.*`, `subscriptions.*`, `weekday.*`, `budgets.*`, `tips.*`, `filters.*`) + InfoPlist en-GB ausente |
| concurrencia | 11 | Tasks con sleep sin cancelación, DispatchQueue donde hay API estructurada |
| performance | 10 | fetch sin fetchLimit y formatters no cacheados en paths fríos |
| l10n-hardcoded | 7 | `Text("vs")` ×3, paréntesis literales, badge "Beta", labels CSV/Excel |
| swiftdata-uso | 5 | seeds sin `@MainActor`, `try?` fetchCount, M2M sin inverse |
| fechas | 3 | `Date.now` en decay/ventanas de notificación |
| state | 2 | literales UserDefaults en OnboardingView |
| gotchas | 1 | XCUITest verifica por texto visible en vez de identifier |
| release-hygiene | 1 | inventario TODO restante (5 markers no críticos) |

**Los 10 más útiles:**

1. `Yala/Resources/es-419.lproj/Localizable.strings:3329` (+183/574/1635/1645/2194/2545/2888/4043/3544) — barrido único de ~1000+ strings huérfanos × 16 locales (la familia `setup.*` sola son ~448).
2. `Yala/Models/TransactionItem.swift:34` — M2M `tags` sin `inverse:` en este lado — añadir `inverse: \Tag.transactions` (regla SwiftData del proyecto).
3. `Yala/App/AppBootstrapper.swift:594` — fetch de TODOS los SplitGroup dentro de un loop por expense en **cold launch** — `fetchLimit = 1`.
4. `Yala/Services/Groups/SplitSyncManager.swift:576` — `retryQuotaFailedRecords()` con docstring "Call from sceneDidBecomeActive" pero **nadie la llama** — cablear o eliminar.
5. `Yala/Services/Groups/GroupBridgeSystemEntities.swift:184` — `archiveSystemAccountIfEmpty` documentado (auto-archive A0-Bridge) pero nunca cableado — cablear o eliminar.
6. `Yala/App/Views/Onboarding/OnboardingView.swift:1809` — literal `"hasCompletedOnboarding"` → `AppPreferences.Keys.hasCompletedOnboarding` (SSOT; ídem `notificationsSeeded` L1909).
7. `Yala/Seed/CategorySeed.swift:328` y `:514` — seeds que manipulan ModelContext sin `@MainActor` — anotar para enforcement del compilador.
8. `Yala/App/Views/WhatsNew/WhatsNewSheet.swift:89` — Task con sleep en onAppear sin cancelación — migrar a `.task{}` (se cancela solo).
9. `Yala/App/Views/More/MoreView.swift:217` — badge `"Beta"` sin key ni marker — key L10n o comentario justificando el tecnicismo universal.
10. `Yala/Resources/en-GB.lproj/InfoPlist.strings` — ausente (es-ES/es-AR/pt-PT sí lo tienen) — copiar de `en.lproj` para paridad (3 keys de permisos).

---

## Pendientes de QA pre-release

Consolidación de `release-hygiene` (device QA pendiente) + `qa-coverage`. **El gap más grande del release no es código: es verificación.** El validador pasa (exit 0, ratchet OK) pero hay drift sistémico: 81/94 áreas del coverage-index con código tocado después de su `lastVerified` (`qa/coverage-index.json`).

### Áreas críticas stale del coverage-index (altas)

- [ ] **groups-bridge-personal** — `/device-qa` F-S2-02..05, F-S2-11, F-S3-04 (TX duplicadas, freeze, bulkApprove, opt-in); 7 fixes del 06-09 sin verificar y coverage=none → poner `coverage=device-qa` + lastVerified (`qa/coverage-index.json:333`)
- [ ] **groups-cross-device-sync** — F-S4-*/F-S5-01 manual cross-device (SplitSyncManager tocado 06-08/09) (`qa/coverage-index.json:1389`)
- [ ] **groups-notifications-deeplinks** — F-S4-01/F-S5-03 (AppRouter: invite persiste y se re-emite tras background) (`qa/coverage-index.json:1414`)
- [ ] **migration-csv-mirror** — F-IMP-04 cold launch con cuenta poblada (AppBootstrapper tocado 5×) (`qa/coverage-index.json:1541`)
- [ ] **icloud-sync-multi-device** — F-ICL-01..04 manual multi-device (`qa/coverage-index.json:1431`)

### Áreas stale del coverage-index (medias)

- [ ] **apple-pay-automation** — F-WCS-03 en device físico con pantalla bloqueada; recién entonces actualizar lastVerified (`qa/coverage-index.json:1296`)
- [ ] **inbox-crud** — re-correr `InboxCrudUITests` (InboxView/InboxDraft tocados 06-08/09) (`qa/coverage-index.json:492`)
- [ ] **whats-new-sheet** — F-PRO-05 con el contenido 2.0 reescrito (`qa/coverage-index.json:1231`)
- [ ] **transactions-core-crud** — re-correr `TransactionsCrudUITests` (detalle read-only nuevo 06-09) (`qa/coverage-index.json:833`)
- [ ] **cashflow-waterfall-chart** — F-STA-03 render del waterfall post-fix de Chart builders (`qa/coverage-index.json:947`)
- [ ] **panel-dashboard-logic** — `PanelDashboardUITests` + refresh del toggle `includeGroupTransactionsInStats` (`qa/coverage-index.json:571`)
- [ ] **form-help-banners** — corregir glob roto `Yala/App/Views/Budgets/**` → `Yala/App/Views/Planning/Budget*.swift` (`qa/coverage-index.json:319`)
- [ ] **Drift sistémico** — correr `/qa-sync` para re-verificar por lotes y actualizar lastVerified (81/94 áreas); reforzar el contrato "mismo commit actualiza el área" (`qa/coverage-index.json`)

### Device-QA acumulado documentado en CLAUDE.md

- [ ] **Apple Pay pantalla bloqueada** — pago real → draft + notif de éxito sin "No se pudo ejecutar el atajo"; atajo mal configurado → notif de error; regresión SiriNatural mantiene snippet (CLAUDE.md:190; irreproducible en simulador)
- [ ] **PIN-01..10 invite CKShare real** — background/kill durante invite, path nativo `userDidAcceptCloudKitShareWith`, retry de red (CLAUDE.md:192; el simulador no acepta shares reales)
- [ ] **SUB-DEDUP-01..12 dedup subcategorías** — update encima sobre estado duplicado + telemetría TelemetryDeck (model=Subcategory/Account/Tag). **Crítico: usuarios 1.0→2.0 corren la migración V3 por primera vez** (CLAUDE.md:194)
- [ ] **Routing F12** — validar el bug del owner: notif tap → Inbox sheet → aprobar → el alert "automatizaciones" NO debe aparecer (CLAUDE.md:198)
- [ ] **MIG-V2-FLASH-01..12** — cuenta poblada (5k+ TXs, 30+ tags, 10+ budgets) + cross-device + `sawRace=false` >95% en TelemetryDeck (CLAUDE.md:200)
- [ ] **MIG-V2-01..08** — cold launch sobre estado roto (presupuestos 1416%, tags colapsados), cross-device, cuenta 1-entity (CLAUDE.md:202)
- [ ] **BG-CSV-01..06 + TX-CSV-07/08** — budgets filtrados cold start, bulk add tags con M2M lazy; monitorear `budgetFiltersAppearEmpty` <1% (CLAUDE.md:204)
- [ ] **T-01..T-17 transfer pairs** + extras del code-review: toggle expense↔income foreign-currency preserva rate, orphans seeded, CSV opposite-sign, bulk-edit cross-currency (CLAUDE.md:206)
- [ ] **B3-29..39 + B3-23..28 + B21-10 grupos** — freeze huérfanos, leave/remove cleanup, soft-delete cross-device con retap link + schema isArchived/isHiddenForAll en CloudKit Dashboard (CLAUDE.md:208)
- [ ] **GR-OB-01..13 onboarding tab Grupos** — iPhone + iPad sidebar, VoiceOver, Reduce Motion, USD/EUR/PEN, seed diferido en fresh install (CLAUDE.md:212)
- [ ] **Stats polish (3 tabs)** — Tendencias T-01..T-33 (+iPad T-20), Insights I-01..I-24 (matriz Free/Pro), Registros R-01..R-18 (DT XXL, VoiceOver) (CLAUDE.md:216)
- [ ] **OB-VS-01..29 + DL-01..08** — restyle onboarding (SE, AX5, VoiceOver, 5 temas) + deeplinks a tabs ocultos en Más incl. iPad sidebar (CLAUDE.md:226)
- [ ] **M6-01..14 bridge** — M6-04/07/14 críticos con 2 devices misma Apple ID (sync personal TX cuenta real, race cleaner, edit parcial) (CLAUDE.md:240)
- [ ] **AI-OB-01..20 Yala AI onboarding** — simulador, mínimo 5 temas (CLAUDE.md:242)
- [ ] **Épico Groups acumulado** — 21 F16 A0-Bridge + 9 A3 + 12 A4 + 15 SP3 (borrar app + reinstalar antes por schema change); la deuda de QA más antigua del release (CLAUDE.md:256)
- [ ] **Menores consolidados** — paywall solidCard (default + 2 temas Pro), QA visual nl/pl/zh-Hans/ja, cold launch >100 tx (log pre-import), log "SplitGroupDedup: removed N" (CLAUDE.md:224)

---

## Quick wins

Máximo impacto / mínimo riesgo — ordenados por ROI:

1. ✅ **RESUELTO (Tanda 1)** — Botón "Restaurar compras" en `ProTrialOfferSheet.swift:103`.
2. ✅ **RESUELTO (Tanda 1)** — Los SIGTRAP de `AmountText` en `.annotation{}` (`BudgetChartsView:311/442`, `CashFlowCellMiniChart:89`, `CashFlowChartsSheet:410`, `PeriodComparisonChartView:178/195`).
3. ✅ **RESUELTO (Tanda 1)** — `dismissKeyboardOnTap()` en `CashFlowSetupView:331` y `CashFlowAddLineSheet:586`.
4. ✅ **RESUELTO (Tanda 3)** — `"Otros"`/`"Ingresos"` → L10n en `NewTransactionViewModel:868/932`.
5. ✅ **RESUELTO (Tanda 3)** — Key `widget.ui.others` para los 2 pie widgets.
6. ✅ **RESUELTO (Tanda 3)** — Siri `success.partial` vía accessor `L10n.Shortcut.successPartial` (la key ya existía ×16; lo roto era el callsite interpolado).
7. ✅ **RESUELTO (Tanda 1)** — `UIHelpers.swift:317` NumberFormatter → `static let`.
8. ✅ **RESUELTO (Tanda 1)** — `CategoryImportHelper.swift:48` `fetchLimit = 1`.
9. **`ContentView.swift:1215` `try?` → do/catch** — corta el loop silencioso e infinito de `.presentDowngradeResolution`.
10. **`qa/coverage-index.json:319` glob roto** de form-help-banners → `Yala/App/Views/Planning/` — 1 línea, el área vuelve a mapear código.

---

## Fuera de alcance

- **Design System / UI-tokens y accesibilidad visual** (tokens DS, tipografía, botones, backgrounds, glass, color, áreas táctiles, Dynamic Type/Dark Mode visual): se auditan con `/ui-audit` — épico **cerrado** con sus 8 dimensiones remediadas; ver `AUDIT-UI-patterns.md` (raíz del repo). Este informe cubre el resto: errores/unwraps, concurrencia, performance, SwiftData (uso y modelo), state management, fechas inyectables, l10n (hardcoded + recursos), gotchas del proyecto, privacy/compliance, dead code, cobertura QA e higiene de release.
- **YalaUITests** no corrió en este pase (timeout en la corrida full; el scheme documentado es Yala Dev) — la re-corrida de XCUITests por área está incluida en la checklist de QA.
