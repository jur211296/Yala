# Progreso Refactoring Arquitectural

**Inicio:** 2026-01-29
**Objetivo:** Mejorar testabilidad y separación de capas

## Estado Actual

**Fase:** D - @Query → ViewModels 🔄 EN PROGRESO
**Progreso:** 28 Views migradas (D.3-D.7 completados)
**Status:** Fases A, B, C completadas. D.3, D.4, D.5, D.6, D.7 completados. D.8 pendiente.

## Resumen de Fases

| Fase | Descripción | Incrementos | Estado |
|------|-------------|-------------|--------|
| A | Singletons → @Environment | 3 | ✅ Completada |
| B | SessionState consistente | 2 | ✅ Completada |
| C | Services para ModelContext | 3 | ✅ Completada |
| D | @Query → ViewModels | 20 | 🔄 D.3-D.7 parcial (20 views) |

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

### D.3.4: CategoriesSettingsListView
- **Estado:** ✅ Completado (fcd71f6)
- **Archivos creados:** `Yala/App/ViewModels/CategoriesSettingsListViewModel.swift`
- **@Query migrado:** categories
- **Beneficios:** Lógica de ordenamiento, filtrado active/hidden, y operaciones CRUD encapsuladas

### D.3.5: CategoryDetailView
- **Estado:** ✅ Completado (929abf9)
- **Archivos creados:** `Yala/App/ViewModels/CategoryDetailViewModel.swift`
- **@Query migrado:** allSubcategories
- **Beneficios:** Lógica de save/delete, validación, y manejo de subcategorías encapsuladas

### D.3.6: BudgetsListView
- **Estado:** ✅ Completado (d73bd91)
- **Archivos modificados:** `Yala/App/ViewModels/BudgetsViewModel.swift`
- **@Query migrado:** allBudgets, allTransactions, accounts
- **Beneficios:** ViewModel existente ahora maneja toda la carga de datos

### D.3.7: FavoritesListView
- **Estado:** ✅ Completado (dfdf33a)
- **Archivos creados:** `Yala/App/ViewModels/FavoritesListViewModel.swift`
- **@Query migrado:** favorites
- **Beneficios:** Lógica de delete/move/reorder encapsulada en ViewModel

### D.4.1: ScheduledPaymentsSettingsView
- **Estado:** ✅ Completado (5c4ff02)
- **Archivos creados:** `Yala/App/ViewModels/ScheduledPaymentsSettingsViewModel.swift`
- **@Query migrado:** allPayments (scheduled payments)
- **Beneficios:** Lógica de filtrado por tab y delete encapsulada en ViewModel

### D.4.2: NotificationsSettingsView
- **Estado:** ✅ Completado (6e7635b)
- **Archivos creados:** `Yala/App/ViewModels/NotificationsSettingsViewModel.swift`
- **@Query migrado:** notifications
- **Beneficios:** Lógica de insert/save/delete encapsulada en ViewModel

### D.4.3: BudgetsFavoritesSettingsView
- **Estado:** ✅ Completado (929372b)
- **Archivos creados:** `Yala/App/ViewModels/BudgetsFavoritesSettingsViewModel.swift`
- **@Query migrado:** activeBudgets (con predicate isActive)
- **Beneficios:** Lógica de favoritos (toggle, move, reindex) encapsulada en ViewModel

### D.5.1: AccountSelectorSheet
- **Estado:** ✅ Completado (92e2d12)
- **Archivos creados:** `Yala/App/ViewModels/AccountSelectorViewModel.swift`
- **@Query migrado:** accounts
- **Beneficios:** Lógica de filtrado de cuentas activas encapsulada

### D.5.2: TagSelectorSheet
- **Estado:** ✅ Completado (7271955)
- **Archivos creados:** `Yala/App/ViewModels/TagSelectorViewModel.swift`
- **@Query migrado:** tags
- **Beneficios:** Lógica de filtrado y UI state para creación de tags encapsulada

### D.5.3: SubcategorySelectorSheet
- **Estado:** ✅ Completado (b22e6b0)
- **Archivos creados:** `Yala/App/ViewModels/SubcategorySelectorViewModel.swift`
- **@Query migrado:** allSubcategories, recentTransactions
- **Beneficios:** Lógica de agrupación y recientes encapsulada

### D.6.1: AccountFormView
- **Estado:** ✅ Completado (d1db7cd)
- **Archivos modificados:** `Yala/App/ViewModels/Accounts/AccountFormViewModel.swift`
- **@Query migrado:** allTransactions
- **Beneficios:** ViewModel existente ahora carga transacciones internamente

### D.6.2: SubcategoryTransferSheet
- **Estado:** ✅ Completado (bc47f51)
- **Archivos creados:** `Yala/App/ViewModels/SubcategoryTransferViewModel.swift`
- **@Query migrado:** allSubcategories, allCategories
- **Beneficios:** Lógica de transferencia y creación de "Sin asignar" encapsulada

### D.6.3: SaveAsFavoriteSheet
- **Estado:** ✅ Completado (85e4889)
- **Archivos creados:** `Yala/App/ViewModels/SaveAsFavoriteViewModel.swift`
- **@Query migrado:** allTags
- **Beneficios:** Lógica de guardado de favorito encapsulada

### D.6.4: SaveAsRecurringSheet
- **Estado:** ✅ Completado (e9c0fd8)
- **Archivos creados:** `Yala/App/ViewModels/SaveAsRecurringViewModel.swift`
- **@Query migrado:** allTags
- **Beneficios:** Lógica de tags activos encapsulada

### D.7.1: TopSubcategoriesWidget
- **Estado:** ✅ Completado (26df674)
- **Archivos creados:** `Yala/App/ViewModels/TopSubcategoriesWidgetViewModel.swift`
- **@Query migrado:** allCategories
- **Beneficios:** Lógica de selector de categorías encapsulada

### D.7.2: ProfileView
- **Estado:** ✅ Completado (9cdd696)
- **Archivos creados:** `Yala/App/ViewModels/ProfileViewModel.swift`
- **@Query migrado:** allTransactions, accounts, categories
- **Beneficios:** Datos para import/export y estado de botones encapsulados

### D.7.3: FavoriteEditorView
- **Estado:** ✅ Completado (5be22d1)
- **Archivos creados:** `Yala/App/ViewModels/FavoriteEditorViewModel.swift`
- **@Query migrado:** favorites (para validación de límites)
- **Beneficios:** Lógica de save y validación encapsulada

### D.7.4: BudgetEditorView
- **Estado:** ✅ Completado (0e74b65)
- **Archivos creados:** `Yala/App/ViewModels/BudgetEditorViewModel.swift`
- **@Query migrado:** accounts, tags, subcategories, categories
- **Beneficios:** Lógica de filtros y save/delete encapsulada

### D.7.5: ScheduledPaymentEditorView
- **Estado:** ✅ Completado (6c1286c)
- **Archivos creados:** `Yala/App/ViewModels/ScheduledPaymentEditorViewModel.swift`
- **@Query migrado:** accounts, tags
- **Beneficios:** Lógica de save/delete encapsulada

### D.7.6: ExportFiltersStepView
- **Estado:** ✅ Completado (f5ee072)
- **Archivos creados:** `Yala/App/ViewModels/ExportFiltersStepViewModel.swift`
- **@Query migrado:** accounts, categories, tags, subcategories
- **Beneficios:** Lógica de filtros de export encapsulada

### D.7.7: ImportIntroSheet
- **Estado:** ✅ Completado (50e444a)
- **Archivos creados:** `Yala/App/ViewModels/ImportIntroViewModel.swift`
- **@Query migrado:** subcategories (para template generation)
- **Beneficios:** Lógica de generación de template encapsulada

### D.7.8: RecordsFiltersView
- **Estado:** ✅ Completado (64d2670)
- **Archivos creados:** `Yala/App/ViewModels/RecordsFiltersViewModel.swift`
- **@Query migrado:** accounts, categories, tags, subcategories
- **Beneficios:** Lógica de filtros encapsulada con helpers de texto

### D.7.9: BulkEditSheet
- **Estado:** ✅ Completado (03b395c)
- **Archivos creados:** `Yala/App/ViewModels/BulkEditViewModel.swift`
- **@Query migrado:** tags
- **Beneficios:** Lógica de carga de tags encapsulada

### D.7.10: InboxBulkActionsSheet
- **Estado:** ✅ Completado (b032d3f)
- **Archivos modificados:** Solo View (sin nuevo ViewModel)
- **@Query eliminado:** accounts (no se usaba, AccountSelectorSheet tiene su propio ViewModel)
- **Beneficios:** Cleanup de query no utilizado

### D.8: Vistas Complejas (Pendiente)
- **Estado:** ⏳ Pendiente
- **Views:** PanelView, NewTransactionView, InboxView, Statistics tabs, etc.

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
- `fcd71f6` - refactor(arch): migrate CategoriesSettingsListView to ViewModel (D.3.4)
- `929abf9` - refactor(arch): migrate CategoryDetailView to ViewModel (D.3.5)
- `d73bd91` - refactor(arch): migrate BudgetsListView @Query to ViewModel (D.3.6)
- `dfdf33a` - refactor(arch): migrate FavoritesListView to ViewModel (D.3.7)
- `5c4ff02` - refactor(arch): migrate ScheduledPaymentsSettingsView to ViewModel (D.4.1)
- `6e7635b` - refactor(arch): migrate NotificationsSettingsView to ViewModel (D.4.2)
- `929372b` - refactor(arch): migrate BudgetsFavoritesSettingsView to ViewModel (D.4.3)
- `92e2d12` - refactor(arch): migrate AccountSelectorSheet to ViewModel (D.5.1)
- `7271955` - refactor(arch): migrate TagSelectorSheet to ViewModel (D.5.2)
- `b22e6b0` - refactor(arch): migrate SubcategorySelectorSheet to ViewModel (D.5.3)
- `d1db7cd` - refactor(arch): migrate AccountFormView @Query to ViewModel (D.6.1)
- `bc47f51` - refactor(arch): migrate SubcategoryTransferSheet to ViewModel (D.6.2)
- `85e4889` - refactor(arch): migrate SaveAsFavoriteSheet to ViewModel (D.6.3)
- `e9c0fd8` - refactor(arch): migrate SaveAsRecurringSheet to ViewModel (D.6.4)
- `26df674` - refactor(arch): migrate TopSubcategoriesWidget to ViewModel (D.7.1)
- `9cdd696` - refactor(arch): migrate ProfileView to ViewModel (D.7.2)
- `5be22d1` - refactor(arch): migrate FavoriteEditorView to ViewModel (D.7.3)
- `0e74b65` - refactor(arch): migrate BudgetEditorView to ViewModel (D.7.4)
- `6c1286c` - refactor(arch): migrate ScheduledPaymentEditorView to ViewModel (D.7.5)
- `f5ee072` - refactor(arch): migrate ExportFiltersStepView to ViewModel (D.7.6)
- `50e444a` - refactor(arch): migrate ImportIntroSheet to ViewModel (D.7.7)
- `64d2670` - refactor(arch): migrate RecordsFiltersView to ViewModel (D.7.8)
- `03b395c` - refactor(arch): migrate BulkEditSheet to ViewModel (D.7.9)
- `b032d3f` - refactor(arch): remove unused @Query from InboxBulkActionsSheet (D.7.10)

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

**D.3 Settings - Entities:** ✅ COMPLETADO (7 views)
**D.4 Settings - Other:** ✅ COMPLETADO (3 views)
**D.5 Selectors:** ✅ COMPLETADO (3 views)
**D.6 Transaction Sheets:** ✅ COMPLETADO (4 views)
**D.7 Other Views:** ✅ COMPLETADO (10 views)

**Plan de priorización:**
1. ✅ D.3 (Settings - Entities) - COMPLETADO
2. ✅ D.4 (Settings - Other) - COMPLETADO
3. ✅ D.5 (Selectors) - COMPLETADO
4. ✅ D.6 (Transaction Sheets) - COMPLETADO
5. ✅ D.7 (Other views) - COMPLETADO
6. ⏳ D.8 (Panel, Statistics) - alto riesgo (vistas complejas)

**Vistas complejas pendientes (D.8):**
- PanelView (8 @Query)
- NewTransactionView (5 @Query)
- InboxView (2 @Query)
- InboxDraftEditSheet (5 @Query)
- RecordsTabView (2 @Query)
- DetailContainerView (5 @Query)
- TrendsTabView (5 @Query)
- CategoriesTabView (5 @Query)
- ScheduledPaymentsView (4 @Query)

**Archivos clave:**
- ViewModels creados: `Yala/App/ViewModels/`
- Plan original: `.claude/plans/quirky-strolling-map.md`
- Progreso: Este archivo
