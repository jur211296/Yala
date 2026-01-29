# Progreso Refactoring Arquitectural

**Inicio:** 2026-01-29
**Objetivo:** Mejorar testabilidad y separación de capas

## Estado Actual

**Fase:** D - @Query → ViewModels 🔄 EN PROGRESO
**Progreso:** 3/48 Views migradas
**Status:** Fases A, B, C completadas. D en progreso.

## Resumen de Fases

| Fase | Descripción | Incrementos | Estado |
|------|-------------|-------------|--------|
| A | Singletons → @Environment | 3 | ✅ Completada |
| B | SessionState consistente | 2 | ✅ Completada |
| C | Services para ModelContext | 3 | ✅ Completada |
| D | @Query → ViewModels | 7 | 🔄 3/48 migradas |

## Fase A: Servicios Stateless → @Environment

### A.1: CurrencyConverter (33 usos en 17 archivos)
- **Estado:** ✅ Completado (e095c93)
- **Views migradas:** InboxDraftEditSheet, InboxBulkActionsSheet, InboxView, CurrencySettingsView
- **Nota:** Services/ViewModels siguen usando .shared (backward compatible)
- **Archivos a modificar:**
  - [ ] `CurrencyConverter.swift` - Agregar @Observable, remover .shared
  - [ ] `YalaApp.swift` - Agregar .environment(CurrencyConverter())
  - [ ] 17 archivos que usan CurrencyConverter.shared

**Patrón de cambio:**
```swift
// ANTES
CurrencyConverter.shared.convert(...)

// DESPUÉS
@Environment(CurrencyConverter.self) private var currencyConverter
currencyConverter.convert(...)
```

### A.2: ExchangeRateService (16 usos)
- **Estado:** ✅ Completado (451f1dd)
- **Views migradas:** ImportIntroSheet, UserDataResetView, CurrencySettingsView
- **Nota:** Services/ViewModels siguen usando .shared (backward compatible)

### A.3: Vision/Voice Services (3 usos)
- **Estado:** ✅ Completado (d955c88)
- **Services migrados:** ImageVisionService, VoiceTranscriptionService, TranscriptionParserService
- **Views migradas:** ImageSelectionView, VoiceRecordingView
- **Nota:** lazy var → @ObservationIgnored manual cache

## Fase B: SessionState.shared → @Environment

### B.1: Widget refresh flags (5 Views)
- **Estado:** ✅ Completado (c19f0e8)
- **Views migradas:** ImportIntroSheet, UserDataResetView, BudgetsFavoritesSettingsView, BudgetEditorView, PersonalizationSettingsView

### B.2: Otros accesos (2 Views)
- **Estado:** ✅ Completado (c19f0e8)
- **Views migradas:** OnboardingView, StatisticsView

## Fase C: Services para ModelContext

### C.1: DraftService
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/Services/DraftService.swift`
- **Views migradas:** InboxView, InboxBulkActionsSheet, InboxDraftEditSheet
- **Nota:** VoiceRecordingView e ImageSelectionView siguen usando lógica inline por complejidad adicional (Merchant Memory, OCR processing)

### C.2: EntityDeletionService
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/Services/EntityDeletionService.swift`
- **Views migradas:** TagFormView, BudgetEditorView, ScheduledPaymentEditorView, CategoryDetailView, SubcategoryDetailView, AccountFormView
- **Beneficios:** Consistente save()+processPendingChanges(), transaction counting helpers, fix para TagFormView que no guardaba

### C.3: TransactionService
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/Services/TransactionService.swift`
- **Operaciones:** create, delete, bulk update (account, subcategory, tags, note, amount)
- **Nota:** RecordsViewModel y NewTransactionViewModel ya tienen buena separación de lógica; TransactionService disponible para uso futuro

## Fase D: @Query → ViewModels

### D.3.1: TagFormView
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/App/ViewModels/TagFormViewModel.swift`
- **@Query migrado:** existingTags (para validación de unicidad)
- **Beneficios:** Lógica de validación y estado encapsulada en ViewModel, View más limpia

### D.3.2: TagsSettingsListView
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/App/ViewModels/TagsSettingsListViewModel.swift`
- **@Query migrado:** tags (lista de todas las etiquetas)
- **Beneficios:** Lógica de ordenamiento y filtrado encapsulada, recarga manual on dismiss para actualizar después de edición

### D.3.3: AccountsSettingsListView
- **Estado:** ✅ Completado
- **Archivos creados:** `Yala/App/ViewModels/AccountsSettingsListViewModel.swift`
- **@Query migrado:** accounts, transactions (para balance)
- **Beneficios:** Lógica de ordenamiento y balance encapsulada en ViewModel

### D.1-D.7: Resto (45 Views)
- **Estado:** ⏳ Pendiente

## Commits Realizados

### Fase A
- `e095c93` - refactor(arch): migrate CurrencyConverter to @Environment injection (A.1)
- `451f1dd` - refactor(arch): migrate ExchangeRateService to @Environment injection (A.2)
- `d955c88` - refactor(arch): migrate Vision/Voice services to @Environment injection (A.3)

### Fase B
- `c19f0e8` - refactor(arch): migrate SessionState.shared to @Environment (B.1 + B.2)

### Fase C
- `62f0b83` - refactor(arch): create DraftService for inbox draft operations (C.1)
- `cf9a1df` - refactor(arch): create EntityDeletionService for standardized entity deletion (C.2)
- `461cc0e` - refactor(arch): create TransactionService for standardized transaction operations (C.3)

### Fase D
- `5952358` - refactor(arch): migrate Tag views to ViewModels (D.3.1, D.3.2)
- `a248033` - refactor(arch): migrate AccountsSettingsListView to ViewModel (D.3.3)

## Notas Técnicas

- CurrencyConverter es stateless, ideal para @Environment
- Mantener backward compatibility durante migración
- Verificar que no hay dependencias circulares

## Patrón de Migración Fase D (@Query → ViewModel)

```swift
// ANTES (View con @Query)
struct MyView: View {
    @Query var items: [Item]
    var body: some View { ... }
}

// DESPUÉS (ViewModel + View)
@MainActor
@Observable
final class MyViewModel {
    private var modelContext: ModelContext?
    private(set) var items: [Item] = []

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadItems()
    }

    func loadItems() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Item>(sortBy: [...])
        do {
            items = try context.fetch(descriptor)
        } catch {
            print("MyViewModel: Error: \(error)")
        }
    }
}

struct MyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MyViewModel()

    var body: some View {
        content
            .onAppear { viewModel.setContext(modelContext) }
            .sheet(isPresented: ..., onDismiss: { viewModel.loadItems() }) { ... }
    }
}
```

## Para Continuar

**Próximas views a migrar (D.3 Settings - Entities):**
- CategoriesSettingsListView
- CategoryDetailView
- SubcategoryDetailView (ya usa EntityDeletionService)
- BudgetsListView
- FavoritesListView

**Plan de priorización:**
1. Continuar con D.3 (Settings - Entities) - bajo riesgo
2. Luego D.4 (Settings - Other) - bajo riesgo
3. Después D.5-D.7 (Transactions, Editors, Selectors) - medio riesgo
4. Al final D.1-D.2 (Panel, Statistics) - alto riesgo (vistas complejas)

**Archivos clave:**
- ViewModels creados: `Yala/App/ViewModels/`
- Plan original: `.claude/plans/quirky-strolling-map.md`
- Progreso: Este archivo
