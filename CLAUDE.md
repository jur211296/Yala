# Yala (iOS)

## Quick Reference

### SwiftData Models (12)
Category, Subcategory, Tag, Account, TransactionItem, Budget, ExchangeRate, FavoritePayment, ScheduledPayment, InboxDraft, MerchantMemory, NotificationItem

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
| CategoryDeduplicationService | App/Services/CategoryDeduplicationService.swift | Merge categorías duplicadas post-sync |
| InsightsLLMService | Services/InsightsLLMService.swift | AI insights via GPT-4o Mini |
| TelemetryService | Services/TelemetryService.swift | Analytics privacy-first via TelemetryDeck |

### Key Calculators
| Calculator | Path | Purpose |
|------------|------|---------|
| InsightsCalculator | App/Logic/Calculators/InsightsCalculator.swift | KPIs, stats, rule-based insights |
| WeekdaySpendingCalculator | App/Logic/Calculators/WeekdaySpendingCalculator.swift | Gasto por día de semana |

### Key ViewModels (35)
| ViewModel | Tests |
|-----------|-------|
| NewTransactionViewModel | 35 |
| BudgetsViewModel | 11 |
| InboxViewModel | 10 |
| PanelViewModel | 10 |
| RecordsViewModel | 12 |
| StatisticsViewModel | 16 |
| ScheduledPaymentsViewModel | 10 |
| ProfileViewModel | — |
| RecordsFiltersViewModel | 3 |
| BudgetEditorViewModel | 1 |
| CategoryDetailViewModel | 9 |
| AccountFormViewModel | 22 |
| TagFormViewModel | 8 |
| AccountSelectorViewModel | — |
| SubcategorySelectorViewModel, TagSelectorViewModel | — |
| InsightsViewModel | 6 |
| BulkEditViewModel | 6 |
| ScheduledPaymentEditorViewModel | 15 |
| SubcategoryTransferViewModel | 8 |
| + 15 ViewModels más en App/ViewModels/ | — |

### Test Suites (54 suites, 526 tests)
FilterServiceTests (22), CalculatorTests (3), TagTests (10), TrendProcessingTests (5), TrendGroupingTests (13), CurrencyCodeTests (4), CurrencyDefaultsTests (3), NewTransactionViewModelTests (35), BudgetsViewModelTests (11), InboxViewModelTests (10), MerchantCanonicalizerTests (12), AmountParserTests (15), DateParserTests (10), MoneyParsingTests (10), PreviousPeriodHelperTests (24), DateContextProviderTests (5), DraftDeduplicationServiceTests (15), AccountFormViewModelTests (22), TagFormViewModelTests (8), CategoryDetailViewModelTests (9), BudgetEditorViewModelTests (1), ViewModelFilterTests (6), CurrencyConverterTests (8), AccountBalanceCalculatorTests (6), FeatureGateTests (6), ExchangeRateWidgetHelperTests (4), RecordsFiltersViewModelTests (6), ScheduledPaymentDateCalculatorTests (17), YalaTests (1), TagSpendingCalculatorTests (15), BudgetAlertTrackerTests (12), BudgetAlertServiceTests (6), ScheduledPaymentsViewModelTests (10), InsightsRuleBasedTests (10), RecordsViewModelTests (12), PanelViewModelTests (10), CashFlowCalculatorTests (18), BalanceTrendCalculatorTests (8), WeekdaySpendingCalculatorTests (8), TopSpendingCategoriesCalculatorTests (10), TopSubcategoriesCalculatorTests (8), BalanceHelperTests (8), NeedTrendHelperTests (8), StatisticsViewModelTests (16), InitialBalanceServiceTests (9), InsightsViewModelTests (6), BulkEditViewModelTests (6), ScheduledPaymentEditorViewModelTests (15), SubcategoryTransferViewModelTests (8), TransactionServiceTests (6), EntityDeletionServiceTests (4), ExchangeRateServiceTests (7), CurrencyChangeServiceTests (6), TransactionUpdateServiceTests (5)

## Product & Stack
Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

- Swift, SwiftUI, SwiftData (.xcodeproj)
- Scheme: Yala | Tests: YalaTests
- **Target iOS 26+** — SIEMPRE usar APIs nativas (Liquid Glass, ToolbarSpacer, etc.)
- **Simulador: iPhone 17 Pro** (builds, tests, simulación)
- ModelContainer via `SwiftDataConfiguration` (12 entidades arriba)
- **Divisas SSOT:** `Yala/Utils/CurrencyUtils.swift` → enum `CurrencyCode` (48 divisas, 7 continentes)

## iOS 26 Liquid Glass (OBLIGATORIO)
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` — placement es OBLIGATORIO
- `.glassEffect()` para chips, barras flotantes, elementos translúcidos
- Si existe una API de iOS 26 que mejore la integración con el sistema, USARLA

## Workflow
**Referencia completa:** `.planning/WORKFLOW.md`

### Flujo estándar (feature)
```
/clear → /next → Plan Mode (Shift+Tab) → /review-plan → Accept edits
→ implementar → /verify-ios → /test-smart → /swift-audit
→ /commit-one → /clear
```

### Flujo rápido (bug fix)
```
/next → implementar → /verify-ios → /commit-one
```

### Flujo autónomo (tarea mecánica con plan claro)
```
/clear → /next → Plan Mode → /review-plan → /yolo
```

### Flujo complejo (modelo core, multi-archivo)
```
/clear → /next → /analyze-impact → Plan Mode → /review-plan → Accept
→ implementar → /verify-ios → /test-smart → /review-session → aplicar
→ /swift-audit → /commit-one → /context-snapshot → /clear
```

### Skills por categoría
| Fase | Skills |
|------|--------|
| Orientación | `/next` |
| Planificación | Plan Mode (Shift+Tab), `/review-plan` |
| Análisis | `/analyze-impact`, `/parallel-search` |
| Verificación | `/verify-ios`, `/verify-quick`, `/test-smart`, `/test-ios` |
| Calidad Swift | `/swift-audit`, `/swiftdata-check`, `/swift-modernize` |
| Review | `/review-code`, `/review-session`, `/pre-deploy-check` |
| Auditoría periódica | `/deep-scan`, `/a11y-audit`, `/ds-compliance`, `/test-coverage`, `/pre-launch` |
| Commits | `/commit-one`, `/checkpoint` |
| Generación tests | `/generate-tests` |
| Contexto | `/context-snapshot`, `/compact`, `/clear` |
| Captura | `/idea` |
| Autónomo | `/yolo` |

**Regla QA-SCENARIOS:** Cada funcionalidad nueva DEBE tener escenarios en `.planning/QA-SCENARIOS.md` ANTES del commit.

## Testing
| Tipo de cambio | Comando |
|----------------|---------|
| Cambio en modelo/servicio | `/test-smart` (solo tests relevantes) |
| Cambio en UI (Views) | Solo `/verify-ios` |
| Antes de commit | `/test-smart` siempre |
| Después de merge o refactor grande | `/test-ios` (todos los tests) |

## Self-Maintenance Rule
Después de crear o modificar modelos, servicios o ViewModels:
- Actualizar las tablas de Quick Reference de este archivo
- Actualizar conteo de tests si se agregaron nuevos
- Agregar gotchas descubiertos a la sección Code Rules
- Mantener este archivo como fuente de verdad para cada sesión AI

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

## Control de Ejecución

**Después de implementar código:**
1. Mostrar resumen de cambios
2. Sugerir siguiente paso
3. DETENERSE y esperar instrucción del usuario
4. NO ejecutar verificaciones o commits automáticamente

**Git:** Ejecutar cada comando de lectura UNA SOLA VEZ, secuencialmente, nunca en paralelo. No matar shells con git en curso.

## Design System (OBLIGATORIO para cambios UI)
**Leer antes de modificar vistas:** `.planning/UI-PATTERNS.md`
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
**Leer antes de escribir textos:** `.planning/BRAND-VOICE.md`
- Tono cercano ("tú"), español neutro, nunca negativo
- Términos simples: "gasto" no "transacción"
- Proponer actualizaciones a BRAND-VOICE.md cuando se defina nuevo copy

## Project Files
| Archivo | Propósito |
|---------|-----------|
| CLAUDE.md | Memoria operativa (este archivo) |
| .planning/PROJECT.md | Definición de producto |
| .planning/ROADMAP.md | Plan de entrega por fases |
| .planning/STATE.md | Progreso y decisiones |
| .planning/DECISIONS.md | Registro decisiones arquitectura |
| .planning/UI-PATTERNS.md | Reglas Design System |
| .planning/BRAND-VOICE.md | Tono y estilo de marca |
| .planning/QA-SCENARIOS.md | Escenarios de prueba |

## Decisiones Recientes (TTL: hasta cierre de fase)
[Formato: [FECHA] Decisión breve — se archiva en DECISIONS.md al cerrar fase]
- [2026-02-18] Skip ocurrencias usa `skippedDatesRaw: String` (comma-separated ISO) en ScheduledPayment — consistente con selectedWeekdays, sin nueva entidad
