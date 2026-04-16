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
| iCloudSyncService | Services/iCloudSyncService.swift | Monitor estado sync iCloud |
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
| WeekdaySpendingCalculator | App/Logic/Calculators/WeekdaySpendingCalculator.swift | Gasto por día de semana |
| SplitCalculator | App/Logic/Calculators/SplitCalculator.swift | Cálculo de porción en gastos compartidos |
| CashFlowProjectionCalculator | App/Logic/Calculators/CashFlowProjectionCalculator.swift | Proyección flujo de caja con 7 métodos |
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

### Test Suites (123 suites, 1452 tests)
FilterServiceTests (27), CalculatorTests (3), TagTests (10), TrendProcessingTests (5), TrendGroupingTests (13), CurrencyCodeTests (4), CurrencyDefaultsTests (3), NewTransactionViewModelTests (45), SplitCalculatorTests (14), BudgetsViewModelTests (11), InboxViewModelTests (10), MerchantCanonicalizerTests (12), AmountParserTests (15), DateParserTests (10), MoneyParsingTests (10), PreviousPeriodHelperTests (24), DateContextProviderTests (5), DraftDeduplicationServiceTests (15), AccountFormViewModelTests (22), TagFormViewModelTests (8), CategoryDetailViewModelTests (9), BudgetEditorViewModelTests (15), ViewModelFilterTests (6), CurrencyConverterTests (8), AccountBalanceCalculatorTests (6), FeatureGateTests (9), ExchangeRateWidgetHelperTests (4), RecordsFiltersViewModelTests (6), ScheduledPaymentDateCalculatorTests (17), YalaTests (1), TagSpendingCalculatorTests (15), BudgetAlertTrackerTests (12), BudgetAlertServiceTests (6), ScheduledPaymentsViewModelTests (14), InsightsRuleBasedTests (10), RecordsViewModelTests (12), PanelViewModelTests (10), CashFlowCalculatorTests (18), CashFlowProjectionCalculatorTests (39), CashFlowPlanViewModelTests (8), BalanceTrendCalculatorTests (8), WeekdaySpendingCalculatorTests (11), TopSpendingCategoriesCalculatorTests (10), TopSubcategoriesCalculatorTests (10), BalanceHelperTests (8), NeedTrendHelperTests (8), StatisticsViewModelTests (17), InitialBalanceServiceTests (9), InsightsViewModelTests (8), BulkEditViewModelTests (6), ScheduledPaymentEditorViewModelTests (15), SubcategoryTransferViewModelTests (8), TransactionServiceTests (6), EntityDeletionServiceTests (4), ExchangeRateServiceTests (7), CurrencyChangeServiceTests (6), TransactionUpdateServiceTests (5), MerchantMemoryServiceTests (14), TranscriptionParserServiceTests (12), DraftServiceTests (6), CategoryDeduplicationServiceTests (6), TransactionsExportServiceTests (26), VisionDraftFactoryTests (19), ScreenshotListExtractorTests (10), ScreenshotSingleExtractorTests (13), ReportNotificationServiceTests (17), SplitModelsTests (14), DebtSimplificationServiceTests (20), GroupBalanceServiceTests (20), GroupExpenseServiceTests (13), GroupServiceTests (12), GroupTransactionBridgeTests (24), GroupPersonalPreferencesTests (15), GroupSplitCalculatorTests (22), GroupExpenseViewModelTests (18), GroupNotificationServiceTests (20), GroupStatsViewModelTests (10), InsightsRuleBasedGroupTests (12), BudgetSharedExpenseTests (3), NudgeTypeTests (8), NudgeTriggerEvaluatorTests (23), NudgeServiceTests (9), AppPreferencesTests (24), PanelPreferencesMigrationTests (6), + 27 more suites from previous batches

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
- [2026-02-18] Skip ocurrencias usa `skippedDatesRaw: String` (comma-separated ISO) en ScheduledPayment — consistente con selectedWeekdays, sin nueva entidad
- [2026-04-16] NUNCA `containerRelativeFrame` en ScrollView vertical con `contentMargins` — deadlock de layout. Usar `onGeometryChange`. Descubierto en Panel iOS 26 modernization (binary search de 10 commits). Documentado en UI-PATTERNS.md sección GOTCHA.
- [2026-04-16] Panel 2.0 foundation (P20-01): secciones temáticas + migración one-shot AppPreferences. Hasta P20-03 el render lee del JSON legacy `panel_widget_configs_v1` como SSOT; las nuevas keys per-sección (`panel{Tendencias,Distribucion,Planificacion}{Order,Hidden}` + `panelSectionsHidden`) se siembran vía `PanelPreferencesMigration` pero no son SSOT todavía. `panelPrefsMigratedV2` es flag per-device (NO synced).
- [2026-04-16] Panel 2.0 P20-02: engranaje en toolbar abre sheet de visibilidad por sección. Secciones ocultas guardadas en `AppPreferences.panelSectionsHidden` (synced iCloud KV); `latestRecords` no toggleable (`canBeHidden == false`). `PanelSectionKind.health`/`.paraTi` son casos reservados para P20-06/P20-10 — ya en el sheet para que el toggle persista antes de que aterricen las secciones.
