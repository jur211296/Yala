# Yala (iOS)

## Quick Reference

### SwiftData Models (20)
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment, ScheduledPayment, InboxDraft, MerchantMemory, NotificationItem, CashFlowPlan, CashFlowLine, CashFlowOverride, SplitGroup, SplitMember, SplitExpense, SplitShare, SplitSettlement

### Key Services
| Service | Path | Purpose |
|---------|------|---------|
| FilterService | Services/FilterService.swift | SSOT filtros de transacciones |
| CurrencyConverter | Services/CurrencyConverter.swift | Conversión central de divisas |
| ExchangeRateService | Services/ExchangeRateService.swift | Persistencia y API tipos de cambio |
| TransactionService | Services/TransactionService.swift | CRUD transacciones + widgets |
| DraftService | Services/DraftService.swift | Operaciones InboxDraft |
| EntityDeletionService | Services/EntityDeletionService.swift | Eliminación estandarizada |
| BudgetAlertService | Services/BudgetAlertService.swift | Alertas de umbrales presupuestos |
| NotificationService | Services/NotificationService.swift | Notificaciones locales |
| ScheduledPaymentNotificationService | Services/ScheduledPaymentNotificationService.swift | Notifs pagos planificados |
| ReportNotificationService | Services/ReportNotificationService.swift | Notifs reportes financieros |
| FeatureGateService | App/Services/FeatureGateService.swift | Gates Pro/Free |
| StoreKitManager | App/Services/StoreKitManager.swift | Suscripciones StoreKit 2 |
| MerchantMemoryService | App/Services/MerchantMemoryService.swift | Auto-categorización merchants |
| iCloudSyncService | Services/iCloudSyncService.swift | Observer real de NSPersistentCloudKitContainer events + estados failed/stalled |
| AppRouter | App/Models/AppRouter.swift | Coordinador central de UI intents (deeplinks, notifs, share, monetization, groups, system alerts). Cola FIFO+prioridad con single-intent drain, consumer readiness gating. Reemplaza ~25 flags transient de SessionState. |
| PreferenceSyncService | App/Services/PreferenceSyncService.swift | Sync preferencias via iCloud KV |
| AppPreferences | App/Services/AppPreferences.swift | Preferencias de usuario tipadas (@Environment) |
| CategoryDeduplicationService | App/Services/CategoryDeduplicationService.swift | Merge categorías duplicadas post-sync |
| InsightsLLMService | Services/InsightsLLMService.swift | AI insights via GPT-4.1 Mini |
| TelemetryService | Services/TelemetryService.swift | Analytics privacy-first via TelemetryDeck |
| ProUpsellService | App/Services/ProUpsellService.swift | Upsells proactivos + frequency capping |
| NudgeService | App/Services/NudgeService.swift | Nudges contextuales por segmento + frequency capping |
| AppUpdateService | App/Services/AppUpdateService.swift | Detección versión nueva via iTunes Lookup API |
| SplitSyncManager | Services/Groups/SplitSyncManager.swift | CKSyncEngine dual (private+shared) para grupos |
| SplitZoneManager | Services/Groups/SplitZoneManager.swift | Zone CRUD y CKShare creation para grupos |
| CKRecordTranslator | Services/Groups/CKRecordTranslator.swift | Traducción CKRecord ↔ SwiftData con encryption |
| GroupService | Services/Groups/GroupService.swift | CRUD grupos y miembros + zone management |
| GroupExpenseService | Services/Groups/GroupExpenseService.swift | CRUD gastos, shares y settlements compartidos |
| GroupPersonalPreferences | Services/Groups/GroupPersonalPreferences.swift | Prefs personales por grupo (UserDefaults) |
| GroupTransactionBridge | Services/Groups/GroupTransactionBridge.swift | Puente grupo → TransactionItem/InboxDraft personal |
| GroupNotificationService | Services/Groups/GroupNotificationService.swift | Notificaciones locales de eventos de grupo + rate limiting |
| PanelPreferencesMigration | App/Services/PanelPreferencesMigration.swift | Migración one-shot legacy JSON → keys per-sección (Panel 2.0) |

### Key Calculators
| Calculator | Path | Purpose |
|------------|------|---------|
| InsightsCalculator | App/Logic/Calculators/InsightsCalculator.swift | KPIs, stats, rule-based insights |
| FinancialScoreCalculator | App/Logic/Calculators/FinancialScoreCalculator.swift | Score Panel 2.0 (Salud Financiera) — budget/activity/bills + reweight |
| WeekdaySpendingCalculator | App/Logic/Calculators/WeekdaySpendingCalculator.swift | Gasto por día de semana |
| SplitCalculator | App/Logic/Calculators/SplitCalculator.swift | Cálculo de porción en gastos compartidos |
| CashFlowProjectionCalculator | App/Logic/Calculators/CashFlowProjectionCalculator.swift | Proyección flujo de caja con 7 métodos |
| SankeyFlowCalculator | App/Logic/Calculators/SankeyFlowCalculator.swift | Widget Sankey (4 columnas: ingreso subcats → Gastos/Disponible → gasto cats → gasto subcats). Puro, O(N) |
| DebtSimplificationService | Services/Groups/DebtSimplificationService.swift | Minimum cash flow — simplificación de deudas |
| GroupBalanceService | Services/Groups/GroupBalanceService.swift | Balances por miembro, deudas, resumen global |
| GroupSplitCalculator | App/Logic/Calculators/GroupSplitCalculator.swift | Split por participante para gastos de grupo |

### Key ViewModels (39)
| ViewModel | Tests |
|-----------|-------|
| CashFlowPlanViewModel | 8 |
| NewTransactionViewModel | 45 |
| BudgetsViewModel | 11 |
| InboxViewModel | 10 |
| PanelViewModel | 15 |
| RecordsViewModel | 12 |
| StatisticsViewModel | 16 |
| ScheduledPaymentsViewModel | 10 |
| ProfileViewModel | — |
| RecordsFiltersViewModel | 3 |
| BudgetEditorViewModel | 10 |
| CategoryDetailViewModel | 9 |
| AccountFormViewModel | 22 |
| TagFormViewModel | 8 |
| AccountSelectorViewModel | — |
| SubcategorySelectorViewModel, TagSelectorViewModel | — |
| InsightsViewModel | 6 |
| BulkEditViewModel | 6 |
| ScheduledPaymentEditorViewModel | 15 |
| SubcategoryTransferViewModel | 8 |
| GroupsViewModel | — |
| GroupDetailViewModel | — |
| GroupExpenseViewModel | 18 |
| GroupStatsViewModel | 10 |
| + 15 ViewModels más en App/ViewModels/ | — |

### Test Suites (136 suites, 1653 tests)
AppRouterTests (19), HeroMonthCalculatorTests (19), FinancialScoreCalculatorTests (23), FilterServiceTests (27), CalculatorTests (3), TagTests (10), TrendProcessingTests (6), TrendGroupingTests (13), CurrencyCodeTests (4), CurrencyDefaultsTests (3), NewTransactionViewModelTests (45), SplitCalculatorTests (14), BudgetsViewModelTests (11), InboxViewModelTests (10), MerchantCanonicalizerTests (12), AmountParserTests (15), DateParserTests (10), MoneyParsingTests (10), PreviousPeriodHelperTests (24), DateContextProviderTests (5), DraftDeduplicationServiceTests (15), AccountFormViewModelTests (22), TagFormViewModelTests (8), CategoryDetailViewModelTests (9), BudgetEditorViewModelTests (15), ViewModelFilterTests (6), CurrencyConverterTests (8), AccountBalanceCalculatorTests (6), FeatureGateTests (9), ExchangeRateWidgetHelperTests (4), RecordsFiltersViewModelTests (6), ScheduledPaymentDateCalculatorTests (17), YalaTests (1), TagSpendingCalculatorTests (15), BudgetAlertTrackerTests (12), BudgetAlertServiceTests (6), ScheduledPaymentsViewModelTests (14), InsightsRuleBasedTests (10), RecordsViewModelTests (12), PanelViewModelTests (26), CashFlowCalculatorTests (18), CashFlowProjectionCalculatorTests (39), CashFlowSmallBinnerTests (9), CashFlowPlanViewModelTests (8), BalanceTrendCalculatorTests (8), WeekdaySpendingCalculatorTests (16), TopSpendingCategoriesCalculatorTests (10), TopSubcategoriesCalculatorTests (10), BalanceHelperTests (8), NeedTrendHelperTests (8), StatisticsViewModelTests (17), InitialBalanceServiceTests (9), InsightsViewModelTests (11), BulkEditViewModelTests (6), ScheduledPaymentEditorViewModelTests (15), SubcategoryTransferViewModelTests (8), TransactionServiceTests (6), EntityDeletionServiceTests (4), ExchangeRateServiceTests (7), CurrencyChangeServiceTests (6), TransactionUpdateServiceTests (5), MerchantMemoryServiceTests (14), TranscriptionParserServiceTests (12), DraftServiceTests (6), CategoryDeduplicationServiceTests (6), TransactionsExportServiceTests (26), VisionDraftFactoryTests (19), ScreenshotListExtractorTests (10), ScreenshotSingleExtractorTests (13), ReportNotificationServiceTests (17), SplitModelsTests (14), DebtSimplificationServiceTests (20), GroupBalanceServiceTests (20), GroupExpenseServiceTests (13), GroupServiceTests (12), GroupTransactionBridgeTests (24), GroupPersonalPreferencesTests (15), GroupSplitCalculatorTests (22), GroupExpenseViewModelTests (18), GroupNotificationServiceTests (20), GroupStatsViewModelTests (10), InsightsRuleBasedGroupTests (12), BudgetSharedExpenseTests (3), NudgeTypeTests (8), NudgeTriggerEvaluatorTests (23), NudgeServiceTests (9), AppPreferencesTests (35), PanelPreferencesMigrationTests (6), PanelSectionPreferencesTests (11), iCloudSyncServiceTests (15), SyncStatusBannerTests (7), WidgetConfigManagerTests (7), HeroMessageCacheTests (13), CalendarOrderedWeekdaysTests (6), IntentConsentGateTests (2), AnomalyKeywordsTests (16), AnomalyDetectionCalculatorTests (6), FullFinancialContextBuilderTests (15), SuggestionsRewriterServiceTests (8), + 26 more suites from previous batches

## Product & Stack
Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

- Swift, SwiftUI, SwiftData (.xcodeproj)
- Scheme: **Yala** (producción) | **Yala Dev** (pruebas con toggle Pro) | Tests: YalaTests
- **Target iOS 26+** — SIEMPRE usar APIs nativas (Liquid Glass, ToolbarSpacer, etc.)
- **Simulador: iPhone 17 Pro** (builds, tests, simulación)
- ModelContainer via `SwiftDataConfiguration` (12 entidades arriba)
- **Divisas SSOT:** `Yala/Utils/CurrencyUtils.swift` → enum `CurrencyCode` (48 divisas, 7 continentes)

## General Rules
- Hacer SOLO los cambios explícitamente solicitados. No mover elementos UI, refactorizar código adyacente, ni añadir mejoras no pedidas. En caso de duda, proponer el fix mínimo.
- Al referenciar plan files, task docs o backlog items, confirmar que la ruta exacta existe antes de proceder. Si no se encuentra, preguntar al usuario en vez de buscar extensivamente.
- Antes de editar, listar archivos a modificar y qué cambia en cada uno. Esperar aprobación si son más de 3 archivos.

## Obsidian Vault (SSOT de planning)
- **Vault:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/`
- **Abreviatura en este doc:** `$VAULT` = ruta completa del vault
- Claude lee/escribe **directo en el vault** — iCloud sincroniza entre Macs, iPhone y iPad
- **Sin daemon ni sync scripts** — iCloud es el único mecanismo de sync
- **Carpetas:**
  - `$VAULT/Backlog/` — Features con spec (status: open → spec-ready → backlog → in-progress → done)
  - `$VAULT/Ideas/` — Ideas sueltas
  - `$VAULT/Bugs/` — Bug reports
  - `$VAULT/Attachments/` — Imágenes y videos de bugs/features
  - `$VAULT/planning/` — Docs técnicos (PROJECT, ROADMAP, STATE, etc.)
- **Skills:** `/backlog` (listar), `/spec` (desarrollar plan), `/promote` (idea → feature)
- **Flujo:** Usuario escribe en Obsidian → iCloud sync → Claude lee `$VAULT/Backlog/` → `/spec` → escribe plan → iCloud sync → aparece en Obsidian

## iOS 26 Liquid Glass (OBLIGATORIO)
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` — placement es OBLIGATORIO
- `.glassEffect()` para chips, barras flotantes, elementos translúcidos
- Si existe una API de iOS 26 que mejore la integración con el sistema, USARLA

## Workflow
**Referencia completa:** `$VAULT/planning/WORKFLOW.md`

### Flujo estándar (feature)
```
/clear → /next → Plan Mode (Shift+Tab) → /review-plan → Accept edits
→ implementar → /verify-ios → /test-smart → /device-qa → /swift-audit
→ /commit-one → /clear
```

### Flujo rápido (bug fix)
```
/next → implementar → /verify-ios → /device-qa → /commit-one
```

### Flujo autónomo (tarea mecánica con plan claro)
```
/clear → /next → Plan Mode → /review-plan → /yolo
```

### Flujo complejo (modelo core, multi-archivo)
```
/clear → /next → /analyze-impact → Plan Mode → /review-plan → Accept
→ implementar → /verify-ios → /test-smart → /device-qa → /simplify → aplicar
→ /commit-one → /context-snapshot → /clear
```

### Skills por categoría
| Fase | Skills |
|------|--------|
| Orientación | `/next` |
| Planificación | Plan Mode (Shift+Tab), `/review-plan` |
| Análisis | `/analyze-impact` |
| Verificación | `/verify-ios`, `/verify-quick`, `/test-smart`, `/test-ios`, `/device-qa` |
| Calidad Swift | `/swift-audit`, `/swiftdata-check`, `/swift-modernize`, `/simplify` |
| Review | `/review-code`, `/diff-review` |
| Auditoría periódica | `/deep-scan`, `/a11y-audit`, `/ds-compliance`, `/test-coverage`, `/pre-launch`, `/l10n-check`, `/perf-check` |
| Revisión completa | `/full-review` (ejecuta todas las auditorías + reporte consolidado) |
| Limpieza | `/dead-code`, `/todo-scan` |
| Commits | `/commit-one`, `/checkpoint` |
| Generación tests | `/generate-tests` |
| Release | `/release-notes` |
| Contexto | `/context-snapshot`, `/compact`, `/clear` |
| Captura | `/idea` |
| Backlog (Obsidian) | `/backlog`, `/spec`, `/promote` |
| Autónomo | `/yolo` |

**Regla QA-SCENARIOS:** Cada funcionalidad nueva DEBE tener escenarios en `$VAULT/planning/QA-SCENARIOS.md` ANTES del commit.

## Testing
| Tipo de cambio | Comando |
|----------------|---------|
| Cambio en modelo/servicio | `/test-smart` (solo tests relevantes) |
| Cambio en UI (Views) | Solo `/verify-ios` |
| Antes de commit | `/test-smart` siempre |
| Después de merge o refactor grande | `/test-ios` (todos los tests) |

## Build & Verification
Después de implementar cualquier cambio, SIEMPRE ejecutar verificación de build completa (`/verify-ios` o `xcodebuild`) antes de presentar el trabajo como completado. Nunca saltar este paso.

## Device QA (validación visual en simulador)

**SIEMPRE usar scheme `Yala Dev`** para pruebas en simulador. Tiene toggle "Simular Pro" y flag `DEV_BUILD`.

### Setup Yala Dev
```bash
# Build (usa DerivedData separado — config Debug-Dev genera bundle .dev)
xcodebuild -scheme "Yala Dev" -project Yala.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/YalaDevBuild build

# Install + Launch
xcrun simctl install booted "/tmp/YalaDevBuild/Build/Products/Debug-Dev-iphonesimulator/Yala.app"
xcrun simctl launch booted com.jurgenschmidt.yala.dev

# Conectar agent-device
agent-device open com.jurgenschmidt.yala.dev --platform ios
```

### Patrón de interacción con agent-device
```bash
# ✅ CORRECTO: find + click → type (los QA scripts usan este patrón)
agent-device find "accessibility_id_or_text" click
agent-device type "texto a escribir"

# ❌ INCORRECTO: fill (escribe en campo equivocado, refs inválidos)
agent-device fill @e10 "texto"

# Cerrar teclado QWERTY antes de tocar campo cubierto
agent-device press 200 150   # tap fuera del campo

# Navegar entre campos de texto con teclado activo
agent-device snapshot -i | grep "Teclado siguiente"
agent-device press @eN   # botón "Teclado siguiente"
```

### Flujo device-qa para cada feature/fix
1. **Build + install Yala Dev** (si hay cambios de código)
2. **Activar Pro** si la feature lo requiere: Perfil → scroll a "Simular Pro" → toggle ON
3. **Navegar a la pantalla afectada** y verificar visualmente
4. **Tomar screenshot** como evidencia: `agent-device screenshot /tmp/yala-qa-[feature].png`
5. **Actualizar QA-SCENARIOS.md** si la feature es nueva o cambió el flujo esperado

### Onboarding (app fresca)
Ejecutar fixture: `agent-device batch --steps-file qa/fixtures/onboarding-complete.json --json`
O seguir pasos manuales con `find + click + type` (ver fixture para secuencia exacta).

## Self-Maintenance Rule
Después de crear o modificar modelos, servicios o ViewModels:
- Actualizar las tablas de Quick Reference de este archivo
- Actualizar conteo de tests si se agregaron nuevos
- Agregar gotchas descubiertos a la sección Code Rules
- Mantener este archivo como fuente de verdad para cada sesión AI

Después de añadir una preferencia nueva (UserDefaults persistente):
1. Agregar la property tipada en `AppPreferences.swift` en la MARK-section correspondiente (Currency/Identity/Session/Widgets/AI/Budgets/Flags/Tours/Insights), con pattern `didSet` + guard + `persist*(...)`.
2. Añadir la storage key en el `enum Keys` al final del archivo.
3. Cargar el valor en `init(defaults:)` y en `refreshFromDefaults()` (simétricos).
4. Si la preferencia debe sincronizarse cross-device via iCloud KV: añadir caso a `PreferenceSyncService.SyncKey` + pasar `synced: true` en el `persist*` call.
5. Añadir test en `AppPreferencesTests.swift` (persistencia + round-trip).

## Code Rules

### Reglas de cambio
- Evitar refactors grandes si no son necesarios para el feature actual
- No introducir dependencias nuevas sin justificación
- Mantener separación clara entre UI, lógica y capa SwiftData

### Corrección de errores
- SIEMPRE buscar TODAS las instancias del mismo patrón antes de declarar fix completo
- NO confiar ciegamente en "BUILD SUCCEEDED" — verificar todos los casos
- Si el usuario reporta errores después de build exitoso, limpiar cache: `xcodebuild clean`

### Manejo de Errores (NUNCA silenciar)
```swift
// ❌ try? context.save()
// ✅ do { try context.save() } catch { print("Service: Error: \(error)") }
```

### Force Unwraps (NUNCA sin validación)
```swift
// ❌ let x = text.first!
// ✅ guard let x = text.first else { return }
```

### API Keys
- NUNCA hardcodear — usar `Secrets.xcconfig` + `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)`

### Audit Markers
- `// A11Y-DT:` — Dynamic Type: justifica font size hardcodeado (e.g., @ScaledMetric, widget fixed layout)
- `// A11Y-DM:` — Dark Mode: justifica color hardcodeado (e.g., brand bg, decorative animation)

### Logs
- SIEMPRE dentro de `#if DEBUG` — nunca datos sensibles en producción

### SwiftData
- SIEMPRE `@Relationship(inverse:)` en relaciones bidireccionales
- Verificar `deleteRule` en cada relación
- `@MainActor` en servicios que manipulan `ModelContext`
- **CloudKit compatibility:** NUNCA `@Attribute(.unique)`, propiedades con default o optional, relaciones SIEMPRE optional

### State Management (SwiftUI)
- `@Observable` clases SIEMPRE con `@MainActor`
- `@State` SIEMPRE `private` — solo la vista propietaria lo crea
- NUNCA `Binding(get:set:)` en body — usar `@Binding` + `.onChange()`
- NUNCA `@AppStorage` dentro de `@Observable` (no triggerea updates)
- Preferir `@Observable` + `@State`/`@Bindable` sobre `ObservableObject`/`@Published`/`@StateObject`
- **Preferencias persistentes → `AppPreferences` inyectado via `@Environment`** — NUNCA `@AppStorage` directo en views nuevas. Ver `$VAULT/planning/UI-PATTERNS.md` sección "iOS 26 Glass" y sub-sección "Preferencias".

### containerRelativeFrame (PELIGRO en ScrollView vertical)
- **NUNCA** `containerRelativeFrame(.horizontal)` dentro de widgets en un `ScrollView(.vertical)` que use `.contentMargins` o `.scrollViewGlassEdges()` — causa **deadlock de layout** que congela la app sin crash log (el splash nunca se dismissea).
- **SIEMPRE** `onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }` para medir ancho dentro del ScrollView vertical del Panel.
- `containerRelativeFrame` ES safe dentro de `ScrollView(.horizontal)` anidado (p.ej. `AccountsCarouselView`).
- Detalles completos con snippets en `$VAULT/planning/UI-PATTERNS.md` sección "GOTCHA: containerRelativeFrame + contentMargins".

### Modern Swift Idioms
- `Date.now` en vez de `Date()`
- `count(where:)` en vez de `filter().count`
- `replacing("a", with: "b")` en vez de `replacingOccurrences(of:with:)`
- `if let value {` shorthand — no repetir nombre de variable
- `Task.sleep(for: .seconds(1))` en vez de nanoseconds
- Siempre `async/await` sobre completion handlers
- NUNCA Grand Central Dispatch — usar Swift Concurrency

### ViewModel Pattern
```swift
@MainActor @Observable
final class MiViewModel {
    private var modelContext: ModelContext?
    private(set) var items: [MiModelo] = []
    func setContext(_ ctx: ModelContext) { modelContext = ctx; loadData() }
    func loadData() { /* FetchDescriptor + do/catch */ }
}
// Vista: @State private var viewModel = MiViewModel()
// .onAppear { viewModel.setContext(modelContext) }
// Refresh: .onDismiss { viewModel.loadData() }
```
Vistas hijas simples reciben datos como `let` parameters del padre.

### Forms con TextField (OBLIGATORIO)
Cualquier vista nueva con `TextField`, `TextEditor` o `SecureField` (que no use `Form`) DEBE incluir `dismissKeyboardOnTap()` desde el primer commit. Sin esto el teclado queda atrapado. Detalles, anti-patterns y casos especiales en `$VAULT/planning/UI-PATTERNS.md` sección "Formularios con Campos de Texto".

```swift
// ✅ Patrón canónico (con ScrollView)
ScrollView {
    VStack { ... }.padding(...)
        .dismissKeyboardOnTap()           // VStack interior, post-padding
}
.scrollDismissesKeyboard(.interactively)  // complementario, drag down

// ✅ Sin ScrollView: modifier al VStack raíz post-padding
// ✅ Componentes reutilizables: el modifier va en el padre, no en el componente
// ❌ NO al PanelBackgroundView — el ScrollView absorbe los taps
// ❌ NO antes del padding — hit area queda más chico que el contenido
```

## Control de Ejecución

**Después de implementar código:**
1. Mostrar resumen de cambios
2. Sugerir siguiente paso
3. DETENERSE y esperar instrucción del usuario
4. NO ejecutar verificaciones o commits automáticamente

**Git:** Ejecutar cada comando de lectura UNA SOLA VEZ, secuencialmente, nunca en paralelo. No matar shells con git en curso.

**Tags:** SIEMPRE formato semver con prefijo `v` → `v1.0.0`, `v1.0.1`, `v1.1.0`, `v1.1.1`. NUNCA sin prefijo o sin los 3 componentes.

## Design System (OBLIGATORIO para cambios UI)
**Leer antes de modificar vistas:** `$VAULT/planning/UI-PATTERNS.md`
- SIEMPRE `DS.Spacing`, `DS.Radius`, `DS.Typography` — NUNCA valores hardcodeados
- SIEMPRE filas clicables con `Button` + `contentShape(Rectangle())`
- SIEMPRE colores semánticos y componentes estándar (YalaPrimaryButton, YalaEmptyState, etc.)
- SIEMPRE `DS.Semantic.*` para colores de estado (success/warning/error/info/neutral/disabled)
- SIEMPRE `DS.Gradients.*` para gradientes de marca (proBadge/subscription/success/warning)
- Proponer agregar reglas nuevas a UI-PATTERNS.md cuando surjan

### DS.Semantic (colores de estado)
| Token | Uso |
|-------|-----|
| `successBackground/Foreground` | Confirmaciones, checks verdes |
| `warningBackground/Foreground` | Alertas, límites excedidos |
| `errorBackground/Foreground` | Errores, balances negativos |
| `errorBackgroundSubtle/errorBorder` | Validación de formularios |
| `infoBackground` | Banners informativos |
| `neutralBackground` | Fondos neutros (chips, barras) |
| `favoriteIcon` | Estrellas de favorito |
| `disabledForeground` | Estados deshabilitados |

### DS.Gradients (gradientes de marca)
| Token | Uso |
|-------|-----|
| `proBadge` | Badge Pro [yellow→orange] |
| `subscription` | Suscripción [orange→hotPink] |
| `success` | Éxito [green→green85%] |
| `warning` | Advertencia [orange→red] |

## Brand Voice (OBLIGATORIO para textos)
**Leer antes de escribir textos:** `$VAULT/planning/BRAND-VOICE.md`
- Tono cercano ("tú"), español neutro, nunca negativo
- Términos simples: "gasto" no "transacción"
- Proponer actualizaciones a BRAND-VOICE.md cuando se defina nuevo copy

## Localization
- Para cambios de localización: SIEMPRE leer el archivo `.lproj/Localizable.strings` destino antes de editar.
- Verificar que se usan los assets del idioma correcto (no defaults en inglés para otros locales).

## Documentation & Copy
- Al escribir documentación o release notes, describir features desde la perspectiva del USUARIO (qué ve/hace), no desde una perspectiva técnica/código.
- NUNCA fabricar ni asumir que existen features — solo referenciar lo confirmado en scope.

## Project Files
| Archivo | Propósito |
|---------|-----------|
| CLAUDE.md | Memoria operativa (este archivo) |
| `$VAULT/planning/PROJECT.md` | Definición de producto |
| `$VAULT/planning/ROADMAP.md` | Plan de entrega por fases |
| `$VAULT/planning/STATE.md` | Progreso y decisiones |
| `$VAULT/planning/DECISIONS.md` | Registro decisiones arquitectura |
| `$VAULT/planning/UI-PATTERNS.md` | Reglas Design System |
| `$VAULT/planning/BRAND-VOICE.md` | Tono y estilo de marca |
| `$VAULT/planning/QA-SCENARIOS.md` | Escenarios de prueba |

## Decisiones Recientes (TTL: hasta cierre de fase)
[Formato: [FECHA] Decisión breve — se archiva en DECISIONS.md al cerrar fase]
- [2026-04-26] Yala IA — pivot arquitectónico a context-rich (Opción B) en commit `ffc6ee59`. Tras 7 bugs reproducibles reportados en device QA del rediseño Yala IA (commits efb12aca..99e1492e), se decidió pivot mayor: eliminar el sistema de function calling (9 tools en `ChatToolExecutor.swift` + `ChatToolDefinitions.swift` JSON Schema) y reemplazarlo por un único LLM call que recibe en el system prompt un `FullFinancialContext` exhaustivo (3-5k tokens minified) con TODA la data financiera del user. **Razón**: 4 fallas convergentes (F1 tool selection brittle, F2 tools incompletos, F3 context pobre en sugerencias, F4 sliding window descarta data cruda) eran imposibles de arreglar incrementalmente — el classification error en intents ambiguas siempre quedaba expuesto. User autorizó explícitamente el pivot ("para esta funcionalidad NO me importa la privacidad, mandémosle TODO el contexto que requiera responder bien"). **Cambios principales**: (1) Pipeline 3-step (classify→execute tool→format) → 1-step. Modelo `gpt-4.1-nano` → `gpt-4.1-mini` (nano ignora partes del prompt con context >5k tokens). System prompt split static (cacheable por OpenAI) + dynamic (JSON del context + DateContext) — colocados en este orden para maximizar prompt caching. Few-shot con 4 ejemplos cubriendo casos #2 (weekday low sample) + #3 (subcat priority) + #6 (recurring paid) + redirect no-finanzas. (2) `FullFinancialContext` shape incluye: metadata (fecha, weekday, locale, excluded accounts), balances (no archivadas/excluded), 9 períodos (hoy → 3 meses ago), top 10 categorías + todas las subcats con tx>0 últimos 3 meses, bucket `uncategorized` explícito, top 20 merchants canonicalizados, TODOS los budgets activos (con enum `BudgetStatus` type-safe), recurring `paid_this_month` + `pending_next_30_days` + totales mensuales, `weekday_pattern_30_days` con `sample_size` + `dayOccurrences` (resuelve bug #2 del weekday dominado por outliers — sample_size visible al LLM + few-shot que advierte), `needs_breakdown_current_month`, top 10 tags, `top_tx_by_subcategory` (10×10 = granular search via context sin tools), `anomalies?` populated solo cuando `AnomalyKeywords.matches(question)`. (3) `FullFinancialContextBuilder` con caché 60s + signature pura `buildFromArrays(...)` que evita el CloudKit race condition documentado de `makeTestContext()` en suite mode (permite tests con arrays in-memory). (4) `SuggestionsRewriterService` con whitelist de cats/subcats/budgets/tags/merchants reales — si una sugerencia menciona un nombre fuera del whitelist (caso #1 "Entretenimiento" alucinado), invoca segunda LLM call que reescribe usando solo nombres reales preservando intención + gramática. Si tras rewrite quedan <3 válidas, fallback rule-based. (5) `AnomalyKeywords` matcher multi-idioma (ES/EN/DE/FR/IT/PT) con stems para cubrir singular/plural/género en romance languages sin listar cada forma. Diacritic-insensitive folding. Falsos positivos aceptados (sobre-incluir es barato). (6) `AnomalyDetectionCalculator` extraído del executor borrado (baseline 90d, threshold 2x). (7) `TransactionItem.chatAmount(in:converter:)` extension shared entre Builder y Calculator (DRY). (8) `buildBudgets` pre-indexa tx por categoryID (N² → O(n+m)). (9) `QAPair.toolName/toolResultJSON` strippeados al rehidratar (sin `schemaVersion` bump — fields opcionales cubren migración natural). (10) Telemetría obsoleta `tool_used` reemplazada por `turn_count`. **Edge cases manejados** en builder: bucket `uncategorized` para tx con `category=nil`, accounts excluded/archived listados en `metadata.excluded_accounts`, multi-currency con `isFinite` guard, `balanceAdjustmentType != nil` filtrado, `tx.date > now` filtrado (drafts en futuro), budget `limitAmount=0` → `status=.noLimit` + `usage_pct=null`, fetch acotado a 13 meses. **Trade-offs documentados**: costo ~10-20x por pregunta vs antes (con cap diario de 75 sigue manejable); latencia P50 estimada 2-4s, P95 5-7s (sin streaming, out of scope); si user agrega tx en otro tab y vuelve dentro de 60s, ve data hasta 60s vieja (aceptable para chat conversacional). **Skipped por proporcionalidad**: pre-bucket por interval (premature sin profiling 5k+ tx), concurrency builders (LLM call domina latencia), `safeDouble` global util, parameter sprawl en `buildFromArrays`, `monthlyMultiplier` a `ScheduledPaymentDateCalculator`. **Tests**: 45 nuevos verdes en 4 suites (AnomalyKeywords 16, AnomalyDetection 6, FullFinancialContextBuilder 15 con `@Suite(.serialized)` incluye caso específico bug #2, SuggestionsRewriter 8) + 2 en ChatAssistantViewModel para strip toolResultJSON. Coverage del executor borrado migrada al builder. **Pendiente post-merge**: device QA con los 7 casos en Yala Dev + retiro de telemetría temporal tras 2 releases.
- [2026-04-25] Plan integrado AI toggles removal completo en 3 commits (`8ca943a3` weekday-order + `f1330873` Fase 2.0+2.1 + `54a118b3` Fase 2.2-2.8). **Mental model unificado**: aceptar consent ↔ feature accesible (sin toggles intermedios). **Cierra**: bug `weekday-order-ignores-firstweekday` (helper `Calendar.orderedWeekdays(firstWeekday:)` centralizado + DateContextProvider migrado para LLM prompts), feature `remove-ai-toggles-relocate-tone-style` (eliminación de los 4 toggles AI de Profile + reubicación tono/estilo a ChatSheet ⚙️ + sub-vista AIPrivacySettingsView en Profile/Seguridad), bug `ai-gates-bypassed-share-extension-fab` (Share Extension respeta consent + FAB ya no toca toggles). **Cambios principales**: (1) Profile pierde la sección AI Features entera (~352 líneas) — los 4 toggles `voiceInputEnabled`/`imageInputEnabled`/`chatAssistantEnabled`/`aiInsightsEnabled` marcados deprecated en `AppPreferences` (storage retained para compat KV). (2) Tono/estilo IA accesibles desde botón ⚙️ del `ChatSheetView` toolbar trailing → nuevo `AIPersonalizationSheet` con `Form` + 2 `Picker.inline` usando `@Bindable + appPreferences` direct (didSet ya hace persist + sync KV). (3) Idioma de voz reubicado a `PersonalizationSettingsView` sección Interfaz, entre TabBar y SmartInsights config. (4) Nueva sub-vista `AIPrivacySettingsView` con 3 switches (data/chat/insights consent) — patrón `@State mirror + .onChange` (sin `Binding(get:set:)`); revoke dispara confirmDialog que al cancelar restaura el toggle; reactivar dispara el modifier de consent correspondiente. Insertada en Profile/Seguridad debajo de Permisos vía nuevo `ProfileDestination.aiPrivacy`. (5) **3 modifiers de consent** en `ViewModifiers.swift`: `AIConsentAlertModifier` (existing) + `ChatConsentAlertModifier` + `InsightsConsentAlertModifier` (nuevos, con extensions `.chatConsentAlert(...)` / `.insightsConsentAlert(...)`); refactorizan 4 callsites inline (`PanelSheetsModifier`, `RecordsStandaloneView`, `InsightsTabView`, `CashFlowChartsSheet`). (6) Gates por consent en flujo automatizado: `VoiceEntryIntent`/`ImageEntryIntent` throw `consentRequired` (App Intents/Siri Shortcuts); `AppBootstrapper.executeAction(.voice/.imageEntry)` y `enqueueSharedImage` enqueue nuevo `RouterIntent.requestAIConsent(PendingAIInput)` si no consent — handler en `PanelShell` setea `pendingAIInput + showAIConsentAlert`; el callback del aiConsentAlert ya abre `showVoiceRecording`/`showImageSelection` (mismo flow del FAB). El `enqueueSharedImage` persiste la URL en `SessionState.pendingSharedImageURL` antes del enqueue para que `ImageSelectionView` la lea post-aceptar consent (cierra el bug Share Extension). (7) Coachmarks `proVoiceInput`/`proImageInput`/`proSmartInsights`/`proChatAssistant` eliminados del Pro Tour profileSteps (anchors desaparecieron con la sección AI Features). (8) **Migración conservadora `aiTogglesRemovedV2`**: si el user tenía `consent ON + toggle OFF` (decisión histórica de pausar feature post-refactor 2026-04-22), revoca el consent también para forzar re-aceptación. Aplica a los 3 consents (data, chat, insights). DataWipeService añade reset del sentinel. **Patrón crítico aprendido**: `@AppStorage` raw strings deben usar `AppPreferences.Keys.*` para centralizar. **Skipped por proporcionalidad** durante simplify: consolidar 3 confirmDialogs en `AIPrivacySettingsView` a helper único (sub-vista poco usada, refactor moderado), unificar `Chat`/`Insights` ConsentAlertModifiers (divergencia mínima), simplificar `acceptAIInsightsConsent()` (deuda silenciosa para Fase 3). **Reverte parcialmente decisión 2026-04-22**: el refactor `aiInsightsConsentAccepted` ↔ `aiInsightsEnabled` separado se simplifica de vuelta a un solo flag (consent). User priorizó coherencia total sobre granularidad reciente. Tests: 5 nuevos `aiTogglesRemovedV2_*` + 2 `IntentConsentGateTests`. Probado en dispositivo físico antes de cada commit. **Cleanup pendiente Fase 3** (`/dead-code` post-merge): L10n keys deprecated (`Settings.voiceInputEnabled`, etc.), `acceptAIInsightsConsent()` simplificación, `AppPreferences` vars deprecated después de 2-3 releases.
- [2026-04-24] PP2-07 polish completo (commit `2a7f8ea8`): el ticket original era solo "picker S/M/L + defaults" pero se expandió a polish completo del Panel 2.0 en una sesión densa de iteración con el user sobre el Hero. **Hero del Panel rediseñado**: el `kpiText` motivacional pasó por 6 iteraciones (texto largo arriba → 2 líneas centradas abajo → bubble revertido → vuelve arriba con padding extra → finalmente termina arriba en `body` 17pt sobre un nuevo card centrado con título "Disponible · Período" + monto + ingresos/gastos tap-to-filter). Decisiones clave del Hero: (1) **frase motivacional sin números** — el AI prompt y rule-based no escriben montos/porcentajes (los cifras viven en el card debajo); permitido mencionar `daysRemaining` cuando aporta. (2) **Género neutro obligatorio** en prompt AI con regla crítica explícita ("NO uses adjetivos con género: NO 'tranquila/tranquilo', usar 'todo bien', 'buen ritmo', etc."). (3) **Sin nombre del user** en mensaje (ya está en saludo arriba). (4) **Card "Disponible · Período"** con monto del period (no del mes calendario), título primary, ingresos/gastos como `Button` con tap-to-filter replicando patrón de `RecordsTabView.summaryRow` — escribe a `sessionState.selectedTransactionNatures` que propaga al resto del Panel. (5) `HeroContext` enriquecido con 6 campos opcionales (`topCategory` + delta usando `CategorySpendingSummary.variation`, `topWeekday`, `monthProgress` reusando `data.daysTotal`); el LLM elige el más llamativo. **Hero compute optimizado**: `calculateHeroWidget` ahora hace single-pass O(N) sobre `transactions` calculando mes calendario + período en buckets paralelos; cuando `monthInterval == panelDateInterval` reusa los buckets del mes (zero overhead). **Pair sync S↔S Planificación**: `setWidgetSize` con bandera privada `isSyncingPair` previene recursión; budgets ↔ scheduledPayments siempre sincronizados (uno → small ⇒ otro small; uno sube de small ⇒ otro sale al primer no-small disponible). 6 tests cubren todos los escenarios incluyendo `otherHidden_stillSyncs` y `noRecursion`. **Defaults nuevo usuario**: Panel denso con paired smalls — Tendencias [trend S | weekdayBar S] + cashFlow M; Distribución [categoriesPie S | subcategoriesPie S] + needs M; Planificación [scheduled S | budgets S]. **Misc renames**: títulos widgets sin "Distribución de…"/"Gastos por…" prefix (Categorías/Subcategorías/Etiquetas/Necesidades/Promedio diario); picker labels Pequeño/Mediano/Grande (era Mini/Compacta/Ampliada); `expensesByNeed` movido de Tendencias a Distribución; Trend large unificado a `viewModel.trendType.displayName` (era `L10n.Trend.{balance,income,expense}Title` solo en large); CashFlow `kpiLabel` simplificado a `customTitle ?? L10n.CashFlow.title`; ScheduledPayments `largeDynamicTitle` con strings full-form; "Tu actualidad" → "Tus finanzas" en 6 locales; plural en `transaction/trendType.{income,expense}` ("Ingresos/Gastos" en vez de "Ingreso/Gasto") en 6 locales. **Aprendizajes UX clave**: (a) en un Hero conversacional el saludo + KPI numérico + frase motivacional compitiendo en la izquierda crean ruptura visual; el card centrado con `solidCard` separa visualmente el dato del cierre emocional. (b) Bubble translucent `thinMaterial` alrededor del kpi text fue rechazado por user — añade chrome innecesario en un Hero ya denso. (c) AI prompts con "FOCO OBLIGATORIO mencionar X e Y" producen outputs muy templated; relajar a "elige UN dato O omite si está raro" (ej. monthStart con expense ≈ 0) genera más variedad. (d) Asumir género del user en español es bug crítico — siempre cláusula explícita en system prompt. (e) Repetir el nombre en el AI cuando el saludo arriba ya lo muestra es ruido — siempre prohibirlo en prompt. **Cierre del épico**: Panel Polish #2 "compactación + tamaños" cierra con este commit (PP2-01 a PP2-07). Los 4 bloques originales del épico `panel-polish-2_widget-copy-info` (InfoHint rediseñado, Rename brand-voice, InfoSheets pedagógicas, Cleanup `onShowDetail`/`onShowMore`) siguen pendientes para pp2-08+ en otro ciclo.
- [2026-04-24] PP2-06d polish densidad CashFlow + Needs `.small` (opción conservadora): user reportó grid 2×2 Tendencias desbalanceado tras PP2-06c — top row chart-based ligeros (Saldo, Promedio diario) vs bottom row list-based densos (CashFlow, Necesidades). Plan original proponía gauge stacked bar + mini donut con 2 componentes nuevos (`StackedRatioBar`, `MiniDonut`); implementado y rechazado por user ("muy pobres" — donut robaba 35% del ancho causando truncation doble "Ese..."/"S/ 4,...", stacked bar saturado). **Pivot a cirugía mínima**: (1) CashFlow elimina bloque `if let insight = smallCashFlowInsight { Text(insight)... }` (8 líneas) + computed var `smallCashFlowInsight` (15 líneas) — footnote brand-voice "Te queda disponible el X%…" duplicaba info del KPI + VariationChip. (2) NeedTrend cambia `label: "\(need.displayName) · \(percent)%"` → `label: need.displayName` — quita truncation de labels largos ("Esencial · 6…") en español. Todo lo demás idéntico al estado PP2-06c: `PanelSmallBarRow` × 2 en CashFlow, × 3-4 en NeedTrend. **Cleanup**: `StackedRatioBar.swift` + `MiniDonut.swift` borrados, `L10n.Panel.CashFlowSmall.{availableFormat,overspentFormat}` y enum removidos de `L10n.swift` + 6 `.strings` (keys huérfanas). **Aprendizaje**: mini-representaciones visuales ricas (donut 60pt, gauge segmentado) no funcionan en cards `.small` de 170×192pt cuando el widget carga montos primarios — el chrome come el espacio y convierte cualquier info en truncada. Para widgets list-based en small, la regla es "menos es más": eliminar ruido redundante antes que introducir signature visual nuevo.
- [2026-04-24] PP2-06c widgets `.small` chart-based: (A) `TrendProcessingHelper.calculateYDomain` rama balance/income ahora adaptativo (`padding = max((max-min)*0.1, 100); min-padding ... max+padding`) — deja de forzar 0 cuando todos los valores son positivos altos. Hereda Statistics + Panel + comparison chart. Rama `isExpense==true` se mantiene (gastos siempre desde 0 es deseable). (B) `WeekdayBarChart` respeta `AppPreferences.firstWeekday` rotando `[1...7]` desde la pref del user; nuevo `WeekdaySpending.axisLabel` (2 letras capitalizadas) evita colisión M/M/M en ES para martes/miércoles. `shortName` (3 letras) sigue en VoiceOver. (C) **Pivot CashFlow.small**: plan original era mini chart temporal con `CashFlowSmallBinner` (re-bin adaptativo día/semana/mes/trimestre/año según duración del `interval`, no del enum `DetailPeriod`); tras 3 rounds de iteración visual ("mil barras mal distribuidas", "se sale del card", "no me ha encantado") se abandonó chart y se adoptó **2 barras horizontales normalizadas estilo `.medium`** + KPI + `VariationChip` + insight brand-voice al pie. El binner queda como helper puro testeado (9 tests), sin uso runtime — reservado para futuras variantes. (D) Picker S/M/L **real** en `PanelSectionPreferencesSheet` (iterando `type.supportedSizes`, no hardcoded), `supportsSize=true` para `.trend` y `.weekdayBar`. `.tagsPie` intencionalmente NO expuesto (scope creep). (E) Nuevo componente compartido `PanelSmallBarRow` reusable en CashFlow/Needs (label + monto + barra + opcional dim/tap). (F) Insights brand-voice: positivo "Te queda disponible el X% de tus ingresos (PEN Z)" / negativo "Gastaste un X% más de lo que ingresaste (PEN Z)" — nunca regaño, 2ª persona. (G) `L10n.Transaction.expense` singular → `L10n.CashFlow.expense` plural en `.medium`/`.large` — unifica inconsistencia "Ingresos/Gasto" detectada por user en la UI.
- [2026-02-18] Skip ocurrencias usa `skippedDatesRaw: String` (comma-separated ISO) en ScheduledPayment — consistente con selectedWeekdays, sin nueva entidad
- [2026-04-16] NUNCA `containerRelativeFrame` en ScrollView vertical con `contentMargins` — deadlock de layout. Usar `onGeometryChange`. Descubierto en Panel iOS 26 modernization (binary search de 10 commits). Documentado en UI-PATTERNS.md sección GOTCHA.
- [2026-04-21] Sync silencioso por defecto: un banner pill global (SyncStatusBanner con `glassEffect(.regular.tint(...))` + `Capsule`) solo aparece cuando hay `.failed` o `.stalled` real. Observer de `NSPersistentCloudKitContainer.eventChangedNotification` expuesto vía `iCloudSyncService.status` + helpers `isFailed`/`isStalled`/`needsAttention`. Offline puro NO dispara events (container pospone tasks) — limitación conocida, backlog separado `cloudkit-offline-indicator`.
- [2026-04-21] Pivot indicator → banner (dos fases): (1) se reemplazó el `SyncStatusIndicator` (botón ☁️❗ en top-bar de cada tab) por `SyncStatusBanner` montado UNA vez en `MainTabView` vía `.safeAreaInset(edge: .top)` — **falló**: colisionó con los nav bars Liquid Glass iOS 26 que cada NavigationStack dibuja en su propia safe area (banner superpuesto al título del nav bar + fondo bleed al status bar). (2) Solución final (Opción B del plan): banner pill montado como **overlay ZStack en `ContentView`** junto al `positiveToast`, con gate `hasCompletedOnboarding && isInitialCheckDone && !showSplash` para alinear timing con la aparición de `MainTabView` y evitar competir con splash/iCloudSyncWaitingView/onboarding/biometric lock. Pill compacto con `glassEffect(.regular.tint(DS.Semantic.errorBackground|warningBackground).interactive())`, clip a `Capsule()`. Tap → Perfil → Sincronización iCloud (`sessionState.pendingProfileDestination + shouldOpenProfile`). `SyncStatusBannerHost` observa servicio vía `@State private var service = iCloudSyncService.shared` + wipe suppression vía `@State private var sessionState = SessionState.shared` (no `@Environment` — el overlay vive fuera del scope donde se inyecta). Copy reusa `L10n.iCloud.SyncIndicator.failed/stalled/hint` — cero cambios en 6 locales.
- [2026-04-16] Panel 2.0 foundation (P20-01): secciones temáticas + migración one-shot AppPreferences. Hasta P20-03 el render lee del JSON legacy `panel_widget_configs_v1` como SSOT; las nuevas keys per-sección (`panel{Tendencias,Distribucion,Planificacion}{Order,Hidden}` + `panelSectionsHidden`) se siembran vía `PanelPreferencesMigration` pero no son SSOT todavía. `panelPrefsMigratedV2` es flag per-device (NO synced).
- [2026-04-16] Panel 2.0 P20-02: engranaje en toolbar abre sheet de visibilidad por sección. Secciones ocultas guardadas en `AppPreferences.panelSectionsHidden` (synced iCloud KV); `latestRecords` no toggleable (`canBeHidden == false`). `PanelSectionKind.health`/`.paraTi` son casos reservados para P20-06/P20-10 — ya en el sheet para que el toggle persista antes de que aterricen las secciones.
- [2026-04-17] Panel 2.0 P20-03: SSOT de widget order/hidden promovido de legacy JSON a `AppPreferences.panel<Section>{Order,Hidden}` (synced iCloud KV). `PanelSectionPreferencesSheet` (adaptive medium/large) reemplaza el mega-sheet `WidgetPreferencesView`. Mutators debounced 200ms + draft state + flush on dismiss. Guards per-widget en `performCalculation` (compute diferido real). `WidgetConfigManager` ahora es store silencioso de `size`/`scheduledPaymentsMode` (0 UI mutators). Affordance de reset en `PanelSectionsConfigView` para edge case "todos los widgets ocultos". Epic Panel 2.0: 3/11 done.
- [2026-04-17] Panel 2.0 P20-06: Salud Financiera — `FinancialScoreCalculator` con sub-scores `Int?` (budget/activity/bills) + reweight dinámico + soft floor 50 en total. Penalties suaves (exceeded −8, overdue −5, upcoming −3) por brand-voice. Sub-score nil cuando no hay data → "—" placeholder, mini-ring apagado, no afecta total. `FinancialScoreView` card con `.solidCard()`; tap mini-ring → `FinancialScoreDetailSheet` (hero ring + headline alentador + CTA navegación). `DS.Gradients.heroFor(score:)` SSOT del threshold 80/60 (reusable P20-04/05). `SessionState.navigateToRecordsStandalone()` via temporaryTab pattern. PaidAmounts fetch compartido entre `.planificacion` y `.health` cuando coincide mes. Epic Panel 2.0: 4/11 done.
- [2026-04-17] Panel 2.0 P20-04: HeroMonthView rule-based — `HeroMonthCalculator` puro (sin @MainActor, sin singletons) clasifica el mes en 5 estados (monthStart/onTrack/neutral/tight/overBudget). Reemplaza el grande `navigationTitle "Panel de Jür"` por un hero dentro de `.solidCard()` al top del scroll; el título del nav se conserva en modo `.inline` para cubrir el gap visual y seguir mostrando identidad al scrollear. El estado solo se manifiesta en el **tint del icon del chip** (paleta cyan/indigo/purple/hotPink). Chip saluda por nombre (`Hola, %@` + sufijo contextual); pills usan `YalaFormatter.currency` respetando prefs de perfil (símbolo/código + decimales). **Gotcha descubierto**: `YalaFormatter` lee prefs de `UserDefaults` directo → SwiftUI no invalida por sí solo cuando cambian. Fix: `@Environment(AppPreferences.self)` en `HeroMonthView` + `let _ = appPreferences.decimalPlaces/currencyDisplayFormat` en body para registrar dependencia. Bug documentado en `$VAULT/Bugs/yalaformatter-prefs-no-auto-refresh.md` (afecta otros widgets que usan el formatter). Presupuestos sumados solo `periodType == "monthly"`. Usa `TransactionItem.amountInPreferredCurrency` (snapshot ya convertido) — cero llamadas a CurrencyConverter. Avatar sigue en toolbar trailing. Copy rule-based en 6 idiomas. Subtext es el slot donde aterriza el LLM de P20-05 (con fallback al rule-based). Epic Panel 2.0: 5/11 done.
- [2026-04-17] Panel 2.0 P20-04b: Hero KPI customization — botón edit top-right del card (padding simétrico al chip, `slider.horizontal.3` + glass-circle) abre `HeroKPIPreferencesSheet` (chrome idéntico a `PanelSectionPreferencesSheet`). 6 KPIs opt-in (`HeroKPI` enum): income/spent/daysLeft (defaults on) + available/dailyAverage/projection (defaults off). **Max 3 pills visibles** — cap vive en `PanelViewModel.activeHeroKPIs(max:)`. UI enforcement: **mínimo 2 / máximo 3 activos** (toggles disabled en bordes con subtítulo). **Reorder sub-sheet solo lista activas**: `moveActiveHeroKPI` preserva posiciones absolutas de las ocultas. **Flag sentinel `panelHeroKPIsCustomized`**: mientras `false` el VM ignora las prefs stored y aplica `HeroKPI.defaultOrder/defaultHidden`; primer move/toggle flipea. Evita ambigüedad "array vacío = nunca tocado" vs "array vacío = todos ON". Draft+200ms debounce local (no genericizado con `scheduleSectionWrite` — set global vs per-section divergen). Computed vars en `HeroMonthData` (`available/dailyAverage/projection/daysTotal`) — los 16 tests existentes siguen verdes. Observation fix en `PanelHeroSection` replica patrón del formatter. Copy en 6 idiomas. Tests: 19 HeroMonthCalculator (3 nuevos) + 8 HeroKPIPreferencesTests.
- [2026-04-17] Panel 2.0 P20-07: Migrar WeekdayBarChart al Panel — nuevo `WidgetType.weekdayBar` full-width en sección Tendencias, opt-out por default. Reusa `WeekdayBarChart` + `WeekdaySpendingCalculator` sin duplicar (chart base intacto, `InsightsTabView` sin cambios). **Periodo dinámico** (ajuste tras feedback del usuario, no 4 semanas fijo como decía el spec): sigue el `selectedPeriod` del Panel vía `context.filteredTransactions` + `context.effectiveInterval`. Compute en `PanelViewModel.calculateWeekdayWidget(context:)` dentro de `calculateTrendData` con guard `isWidgetVisible(.weekdayBar)` (cubre widget + sección oculta). `PanelWeekdayData: Equatable` + guard de asignación — patrón consistente (ninguna View del Panel conforma `Equatable`; el AC se cumple con el struct). `WeekdaySpending` ahora `Equatable` (síntesis automática). Empty state `style: .widget` + `L10n.Widget.noExpensesPeriod` (consistencia con TopCategoriesWidget/NeedTrendWidget). VoiceOver lunes-first. Copy en 6 idiomas. Tests: 4 PanelViewModelTests (pertenencia Tendencias, bootstrap permisivo, guard widget oculto, guard sección oculta). Epic Panel 2.0: 6/11 done.
- [2026-04-20] Panel 2.0 P20-08: TrendsCarouselWidget — unifica el antiguo `TrendWidget` con el chart de comparación de periodos en un único widget con `TabView(.page)` de 2 páginas. Reusa 100% los components existentes (`TrendChartView`, `PeriodComparisonChartView`) sin modificarlos. **Selector de métrica compartido** (balance/income/expense) escribe a `sessionState.selectedTransactionNatures` — mismo SSOT que TrendsTab, sync bidireccional sin código de bridge. Títulos reusan `L10n.Statistics.vsPreviousPeriod` / `vsPreviousYear` (cross-screen consistency). **Mode automático**: `.thisYear → .year` (A-1), resto → `.month` (P-1). **Branch `.balance` vs `.income/.expense`** en `calculatePeriodComparisonWidget` para data source correcto (`balanceTransactions` sin date filter para running balance). Compute gated por `trendVisible` (el guard existente del trend widget). Pivot de decisión tras feedback del usuario: primera iteración fue chart de barras side-by-side → luego chart de líneas standalone → finalmente carrusel unificado. `WidgetType.periodComparison` eliminado del enum — `buildOrderedRawWidgets` self-healing ignora raw values foreign, prefs existentes no rompen. TabView altura 260pt, páginas alineadas al top con `VStack { page; Spacer(minLength: 0) }` (el chart de comparación hardcodea 220pt internamente). Epic Panel 2.0: 7/11 done.
- [2026-04-20] Panel 2.0 P20-09: TagsPieWidget en Distribución — nuevo `WidgetType.tagsPie` full-width en sección Distribución (5º widget tras topSpending/topSubcategories/categoriesPie/subcategoriesPie). Reusa `TagsPieWidget` existente (de CategoriesTabView) + `TagSpendingCalculator.calculateTopSpending` sin modificarlos. **Tap-to-filter global**: tap en un tag lo agrega/quita a `selectedTags` (SessionState) → cableado downstream ya existente (`filteredTransactions:1414-1416` + `FilterCriteria.selectedTags:1492`) propaga el filter a TODOS los widgets del Panel. `toggleTagFilter(_:)` en VM es el único toggle nuevo — multi-select Set-based, mismo pattern que `toggleSubcategoryFilter`. **`calculateTagsWidget` enriquece `TagSpendingSummary.previousAmount` por tag** (mirror Categories/Subcategories) — la segunda llamada al calculator produce valor real (variación por tag en UI), no puro overhead. **Pivot de decisión durante implementación**: plan inicial incluía criterio de availability contextual (≥3 tags + ≥10 tx tagged del mes actual) con cache + `isWidgetAvailable(_:)` filter en `activeWidgets`/`orderedWidgetTypes` → eliminado tras feedback del usuario ("si quiere usarlo así tenga una sola etiqueta"). Widget ahora siempre visible en Distribución, ocultable solo vía sheet de prefs como los hermanos. Reusa `L10n.WidgetType.expensesByTag` — cero strings nuevos en 6 idiomas. Tests: 4 PanelViewModelTests (pertenencia, bootstrap permisivo, guard widget oculto, guard sección oculta). Epic Panel 2.0: 8/11 done.
- [2026-04-20] Panel 2.0 P20-10 **descartado**: sección "Para ti" (AI Insights + QuickStats 2×2) fue implementada + reverted en la misma sesión. Razones del pivot: el Hero IA ya cumple la función de "insight del mes" y duplicar esa señal en una sección aparte se sentía ruidoso. **Sustituto**: Hero card ahora es tap-able en su totalidad → `sessionState.navigateToDetail(.insights)` vía `.contentShape(Rectangle()) + .onTapGesture` en `PanelHeroSection`. Los botones internos (`editButton`, `upsellCTA`) conservan su tap propio — SwiftUI enruta primero al button si el hit cae adentro. **Reversión completa**: enum `PanelSectionKind.paraTi` eliminado (no solo el contenido) → desaparece del sheet "Configurar Panel"; `WidgetType.aiInsights/quickStats`, `AppPreferences.panelParaTi*`, `ParaTiMessageCache`, `InsightsLLMService.generateParaTiInsight`, 5 eventos de telemetry, namespace `L10n.Panel.ParaTi`, 6 archivos de strings, tests y vistas asociadas: todo borrado. Raw values `"paraTi"` que puedan quedar persistidos en `panelSectionsHidden` se ignoran silenciosamente (foreign raw en `PanelSectionKind(rawValue:)`). Epic Panel 2.0: 8/10 done (total reducido a 10 — P20-10 eliminado del roadmap). Nuevo rol del tap hero: drill-down rápido a Resumen de Estadísticas sin widget dedicado.
- [2026-04-20] Panel 2.0 P20-11 extras: eliminado `WidgetType.groupsSummary` por completo del Panel — enum case, `defaultConfigs`, `panelSection` mapping, `supportsSize`, `PanelWidgetSection.swift` case, `PanelThematicSection.planificacionFooter` case, `PanelViewModel.groupGlobalSummary` + `hasGroupsWithPendingBalances` + `loadGroupSummary`, archivo `GroupsSummaryWidget.swift`, `L10n.WidgetType.groupsSummary` + `L10n.Panel.seeGroups` + `L10n.Panel.seeMoreHintGroups`, 3 keys de strings en 6 idiomas (strings sueltos borrados con sed). Raw value `"resumen_grupos"` persistido en prefs legacy queda filtrado por `WidgetType(rawValue:)` retornando nil (self-healing de `buildOrderedRawWidgets`). **Pestaña Estadísticas renombrada**: `statistics.categories` ahora muestra "Distribución" (antes "Categorías") en 6 idiomas — enum `DetailViewTab.categories` conserva su `rawValue = "Categorías"` (es para navigation key, no se muestra al usuario). **CTA "Ver todos" de Últimos registros** cambió de `navigateToStatistics(.records)` (sub-tab de Estadísticas) a `sessionState.navigateToRecordsStandalone()` (tab Registros standalone). Tests: actualizado `migration_noLegacyData_seedsP20_11Defaults` (planificación sin groupsSummary). 130/130 afectados pasan.
- [2026-04-22] PP2-01 Hero Compacto (`panel-polish-2` épico, item 1): rediseño del Hero del Panel edge-to-edge sin card. Top row inline: saludo "Hola, %@" a `DS.Typography.title` + Pro badge (estilo matched al `TrendsPeriodMenu` con `labelSmall` + `md/sm` padding + `glassEffect(.regular, in: Capsule())`) + `TrendsPeriodMenu` a la misma altura. `PanelFilterControlBar` ahora condicional — `EmptyView()` cuando no hay chips activos; period selector migró al Hero. **aiSubtitle LLM es KPI protagonista** vía `Text(AttributedString(markdown: raw))` — parsea `**montos**` a bold inline; fallback rule-based cuando no hay IA: 5 variantes rediseñadas con copy brand-voice rico ("Este mes ingresaste **X** y llevas gastado **Y**, te quedan **Z** para los últimos N días. Tú puedes") en 6 locales, montos en bold markdown. **Font del KPI subió** de `subheadline` a `headline` inicial → bajó a `subheadline` tras feedback (largeTitle se veía gigante con textos largos). **UpsellCTA con flow divergente** — Free → `UpgradePromptSheet(.smartInsightsAI)`; Pro sin consent → `.alert(AIConsent.insightsTitle)` que al aceptar setea `aiInsightsConsentAccepted = true` + llama `viewModel.retriggerHeroAI()` inmediato. `@State upsellDestination: UpsellDestination?` (enum .upgrade/.consent) consolida los 2 booleanos impossible-state. Chip ✨ **siempre golden** `DS.Semantic.favoriteIcon` — eliminado rule-based `stateTint`. `chipText` simplificado a 2 variantes: monthStart (con sufijo de mes "Hola, Jur — empezamos Abril") + default ("Hola, Jur") para los otros 4 estados. **LLM más inteligente con montos + contexto histórico**: `HeroContext` extendido con `income/expense/available` (Double raw + String formatted via YalaFormatter) + `previousExpense/formattedPreviousExpense` + `expenseDelta/formattedExpenseDelta` + `daysElapsed`. Prompt tuneado (`heroSystemPrompt`): **exige 1–3 montos del contexto en markdown bold** (cópialos tal como vienen, sin cambiar símbolo ni número, sin redondear), permite citar comparación vs mes anterior con `previousClause` dinámico por tendencia (down→reconocer mejora, up→sin regañar, flat→normalizar), longitud 160–240 chars, cierre motivador breve opcional, una sola mención del nombre. `contextHash` bucketea montos al centenar (incluye `incomeBucket/expenseBucket/availableBucket/prevExpenseBucket`) evitando invalidar por micro-gastos intradía. **`HeroMessageCache.clear()` incondicional en cada `dataChanged`** dentro de `calculateHeroWidget` → regenera el mensaje con montos actuales aunque el cambio sea sub-bucket (petición explícita del user: "cada transacción = regen"). **Limpieza**: eliminados `HeroKPIPreferencesSheet.swift` + `HeroKPI.swift` enum + `HeroKPIPreferencesTests.swift` (8 tests); métodos KPI removidos del VM (`activeHeroKPIs/orderedHeroKPIs/moveActiveHeroKPI/setHeroKPIHidden/resetHeroKPIPreferences/flushPendingHeroKPIWrites` + drafts + debounce). Keys `panelHeroKPIs*` marcados deprecated en `AppPreferences` (data huérfana iCloud KV inofensiva; no borrar por compat cross-device). **Orden secciones Panel invertido**: `accounts` ahora ANTES que `health` (`WidgetType+PanelSection.PanelSectionKind` declaration order drives visual order). Fixtures `HeroMessageCacheTests` actualizados con 6 nuevos campos. Commit: `9d9073e4`. Siguiente item del épico: PP2-02 Salud Financiera Compacta.
- [2026-04-22] PP2-03 Chrome Compacto de Widgets (`panel-polish-2` épico, item 3): 14 widgets del Panel + 1 componente compartido alineados a un chrome uniforme. Nuevo token `DS.Typography.subheadlineEmphasized = Font.subheadline.weight(.semibold)` en el enum Typography (vecino a `subheadline`/`label`). Patrón aplicado por-caller: padding de card → `DS.Card.paddingCompact` (16pt), título → `subheadlineEmphasized`, spacing VStack header↔body → `DS.Spacing.md` (12pt). **KPIs protagonistas preservados en `headline`**: montos grandes (CashFlow L338, Categories L357/L444, Subcategories/Tags idem), filas de ranking (TopCategories L311, TopSubcategories L435), percentages del selected slice. **Corrección del spec**: el ticket asumía default global `solidCard padding = xl` con riesgo en Profile/Statistics/Records. La realidad (`ViewModifiers.swift:94`) es default `0` — cada caller pasa su padding explícito. Cambios por-caller sin impacto fuera del Panel. **`DS.Card.paddingCompact` en vez de `DS.Spacing.lg`** (mismo valor 16pt, pero namespace semántico correcto — NeedTrend ya lo usaba). **Ternarios size-dependientes colapsados** en TopCategories/TopSubcategories (`size == .small ? md : lg` y `? lg : xl` con ambas ramas iguales tras el cambio) — consecuencia: PP2-05 (widgets small) debe partir sin el condicional. **PieChartVariationHeader incluido (desviación del plan)**: componente compartido por los 3 pie widgets cuando aparece variation chip. Sin este cambio los pie widgets alternarían entre `headline` (con variation) / `subheadlineEmphasized` (sin variation) — inconsistencia visible. Solo el título (L57); el KPI (L64) sigue en `headline`. **CashFlowWidget modos small/medium (L741–779)** ya estaban en `subheadline`+`amountSmall` (verificado) — no requirieron cambio. **Sin tests nuevos** (refactor visual). Ahorro de scroll medido: objetivo 80–100pt vs ~200pt del spec original (cálculo real: 7 widgets × 8pt padding + 5 widgets × 4pt spacing + 13 × ~2pt line-height). Commit: `c4dfba6c`. Siguiente item del épico: PP2-04 Footer Yala sutil.
- [2026-04-22] Refactor consent/feature AI Insights: `aiInsightsConsentAccepted` hacía doble papel (consent legal + feature toggle) → apagar el toggle revocaba el consent y al reencenderlo pedía alert otra vez (inconsistente con voice/image/chat). Nuevo `AppPreferences.aiInsightsEnabled` (feature ON/OFF reversible) + `aiInsightsConsentAccepted` sticky (solo se resetea en `DataWipeService`). **Migración one-shot** en `init` con sentinel `aiInsightsMigratedV1`: usuarios con consent=true preexistente → `enabled=true` automático en primer launch post-upgrade (sin re-preguntar). Helper `AppPreferences.acceptAIInsightsConsent()` centraliza la invariante consent⇒enabled; usado en los 3 acceptance buttons del codebase que tienen `appPreferences` inyectado (PanelHeroSection, InsightsTabView, CashFlowChartsSheet). ProfileView mantiene las 2 líneas directo porque usa `@AppStorage` local (no `AppPreferences` inyectado — sería refactor mayor fuera de scope). **Tabla de reclasificación**: gates LLM (`InsightsViewModel:167`, `PanelViewModel:2557`) chequean `consent && enabled`; UI visibility (toggle/hint/tone/generateAIButton/aiChip) lee `enabled`; **upsell CTA del hero mantiene `consent`** (si user apagó feature a propósito, no re-ofrecerle); `UserSegmentService:125` sigue leyendo `consent` (tracking histórico "probó AI alguna vez"). **PanelHeroSection invalidation reads**: dos `let _ =` consecutivos (consent + enabled) para que SwiftUI reaccione a ambos cambios desde Profile. **Tests**: 3 migración + caso nuevo expresable (`consent=true && enabled=false → hero AI nil`) + `aiInsightsEnabled` en roundtrip; `DataWipeServiceTests` incluye las 2 keys nuevas en `expectedResetKeys`. Commits: `539d350c` (doc PP2-03) + `403ee78e` (refactor). Device QA pendiente en Yala Dev — 6 escenarios: fresh install, desacople toggle, cancel alert, upgrade path, wipe, hero upsell Pro con/sin feature activa.
- [2026-04-22] PP2-05 tamaño `.small` + pilotos TopCategories y CategoriesPie (`panel-polish-2` épico, item 5): nuevo `WidgetSize.small = "S"` con altura TOTAL del card = 192pt (constante `WidgetSize.smallHeight`). `makeLayoutRows` refactor a pasada única con regla `config.size == .small || (columns >= 2 && !isFullWidthOnly)` → widgets `.small` se emparejan **siempre** (iPhone y iPad). **Fix de bug silencioso**: `displaySizeName` cambió de ternario a switch explícito — antes `.small` caía en rama `top5` del ternario. **Fallback defensivo** `.small → .medium` en widgets hermanos que aún no lo implementan (`SubcategoriesPieWidget`, `TagsPieWidget`, `mapWidgetSize`/`mapBudgetsWidgetSize`) previene crashes con configs stale. **Pilotos visuales**: TopCategoriesWidget `.small` = header + top 2 rows (ícono 28pt + nombre + [barra de progreso 6pt + monto + %]) con tap-to-filter + dim en no seleccionadas + chevron de navegación; CategoriesPieWidget `.small` = header + donut decorativo (`.allowsHitTesting(false)`) + bubbles flotantes reutilizando `bubblesLayer`/`connectorLines` del `largeLayout` (tap en bubble filtra la categoría). **Componente compartido**: `PanelSmallWidgetHeader` (título subheadlineEmphasized + chevron opcional). **Aprendizajes críticos para PP2-06/06b/06c** (documentados en [[rvw_pp2-05_infra-small-piloto]]): (A1) `.frame(height: smallHeight)` DESPUÉS del `.solidCard(...)` — nunca antes, resuelve desalineación por distinto padding de card; (A2) `.padding(.top, DS.Spacing.lg)` solo en widgets sin `solidCard(padding:)` externo (pies); (A3) alignment `.topLeading` (no `.leading`); (A4) bubbles radio `chartRadius * 0.55` para dejar espacio alrededor; (A5) patrón `shouldDim` del largeLayout para rows no seleccionadas; (A6) exhaustive switches deben recibir `.small → mediumLayout` fallback en widgets hermanos hasta que implementen su `.small`. **División del scope restante**: el ticket PP2-06 original (7 widgets) se dividió en 3 sub-tickets según anatomía: (06) replica mecánica a hermanos TopSubcategories + SubcategoriesPie + TagsPie, (06b) widgets de lista Budgets + ScheduledPayments + RecentRecords, (06c) widgets chart-based Trend + CashFlow + WeekdayBar + Needs (exploratorio — si un chart no cabe bien en 170×192 se descarta). Tests: 7 nuevos en `WidgetConfigManagerTests` (pairing iPhone/iPad + regresiones `fullWidthOnlyTypes`) + 3 roundtrip Codable en `AppPreferencesTests`. Picker UI sigue hardcoded M/L — se expone `.small` en PP2-07. Commit: `60617d4c`. Simplify review extrajo `PanelSmallWidgetHeader` (Agents 1+2 flagearon el copy-paste del header + chevron entre TopCategories y CategoriesPie).
- [2026-04-20] Panel 2.0 P20-11: cierre del épico — polish + reorder + variantes M/L + defaults + auto-hide. **Reorden del Panel**: Hero → banners → `PanelFilterControlBar` (extraído) → Salud → Cuentas → Tendencias → Distribución → Planificación → Últimos registros → Herramientas. Nuevo `PanelSectionKind.accounts` (toggleable) y `.latestRecords.canBeHidden` flipeado a `true` — ahora todas las secciones son toggleables. **Auto-hide**: `hasAnyVisibleWidget(in:)` combinado con `isSectionVisible(_:)` en `PanelFilterAndWidgetsSection.visibleSections` — multi-widget sections se ocultan cuando todos sus widgets están hidden; single-widget sections solo por section flag. Affordance de restore ya existía en `PanelSectionsConfigView`. **Defaults opinados**: `PanelPreferencesMigration` detecta install fresh (legacy blob ausente + sentinel falso) y llama `AppPreferences.setupDefaultsForNewUser()`. Usuarios v1.x upgrade mantienen su config. `WidgetConfig.defaultConfigs()` ajustado: trend L, cashFlow L, scheduledPayments `.list`. Tabla final: Tendencias `[trend L, cashFlow L]` + Distribución `[categoriesPie L]` + Planificación `[budgets, scheduledPayments lista]`. **Variantes M/L recuperadas**: `WidgetType.supportsSize` marca cuáles exponen el Picker segmentado (Compacta/Ampliada) en `PanelSectionPreferencesSheet.widgetRow`. `PanelViewModel.widgetSize/setWidgetSize` persisten via `WidgetConfigManager.save()` (silent store). **Colapsador Cuentas**: `AppPreferences.panelAccountsCollapsed` (synced iCloud KV), chevron Color.primary, VoiceOver label/value/hint. **Chevrones internos removidos** de 12 widgets (con `TODO(polish#2)` para cleanup de parámetros). CTAs "Ver más" por sección: section-level para Tendencias/Distribución/Latest Records; **per-widget en Planificación** (bloque full-width separado debajo de cada card — rompe pair layout en iPad, trade-off aceptado por semántica). **Icono toolbar**: `slider.horizontal.3` → `slider.horizontal.2.square` (también en `PanelSection.header.onPreferences`). **Color primary** en reset/reorder de mini-sheets (NO `YalaSaveButton`). **Spacing xl** en `PanelSection` + padding vertical xs al header. 6 idiomas nuevos strings en `L10n.Panel` + 6 `.strings` files. Tests: actualizados `PanelPreferencesMigrationTests` (renombrado `noLegacyData_writesEmpty` → `seedsP20_11Defaults` + nuevos `setupDefaultsForNewUser_overwrites`, `withLegacyData_doesNotCallSetupDefaults`), actualizados `PanelSectionPreferencesTests` por weekdayBar P20-07 preexisting fail + nuevos `hasAnyVisibleWidget_*` + `widgetSize_*` + `setWidgetSize_*`, actualizados `PanelViewModelTests` (`latestRecordsNowToggleable`, `toggleableSections_coversAllSections`), añadido `AppPreferencesTests.set_panelAccountsCollapsed_persistsAndReloads`. 50/50 suites afectadas pasan. Nudge "descubre panel" **skipped** (reorder auto-explicativo). Polish #2 creado como item backlog separado (`panel-polish-2_widget-copy-info.md`) con rename de widgets + InfoSheets + cleanup de `onShowDetail`/`onShowMore` vestigios. Epic Panel 2.0: **10/10 done** (8 en QA, P20-10 descartado).
