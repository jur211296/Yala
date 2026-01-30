# Estrategia de Testing - ViewModels

Documento que define la estrategia para agregar unit tests a los ViewModels después del refactoring arquitectural D.8.

---

## Estado Actual

### Tests Existentes
| Test File | Cobertura | Tipo |
|-----------|-----------|------|
| `CalculatorTests` | Cálculos financieros | Lógica pura |
| `FilterServiceTests` | FilterCriteria, AmountCondition | Lógica pura |
| `TagTests` | Operaciones con tags | Lógica pura |
| `TrendProcessingTests` | Procesamiento de tendencias | Lógica pura |
| `TrendGroupingTests` | Agrupación de tendencias | Lógica pura |

### ViewModels Sin Tests (35 total)
Todos los ViewModels creados en el refactoring D.8 no tienen tests automatizados.

---

## Estrategia por Tiers

### Tier 1: Lógica Pura (Sin SwiftData)
**Complejidad**: Baja
**Valor**: Alto
**Prioridad**: Inmediata

Testear métodos que no requieren ModelContext:

#### NewTransactionViewModel
```swift
// Testeable sin SwiftData:
- appendDigit(_ digit: String)      // Lógica del teclado numérico
- deleteLastDigit()                 // Borrado
- clearAmount()                     // Reset
- amount: Double (computed)         // Parsing
- formattedAmount: String           // Formateo
- isAmountValid: Bool              // Validación
- needsExchangeRate: Bool          // Lógica de transferencias
- updateDestinationAmount()        // Cálculo tipo de cambio
- updateExchangeRateFromDestination()
```

#### InboxViewModel
```swift
// Testeable sin SwiftData (pasando datos mock):
- filteredDrafts(for filter:)      // Filtrado
- groupedDrafts(for filter:)       // Agrupación por fecha
- countForFilter(_ filter:)        // Conteo
```

#### BudgetsViewModel
```swift
// Testeable con datos mock:
- getBudgetStatus(budget:spending:)           // Determinación de estado
- getDaysRemaining(budget:)                   // Cálculo días restantes
- getBudgetDateInterval(budget:)              // Intervalos de fecha
- getBudgetDisplayProperties(budget:)         // Icono/color
- getBudgetSpending(budget:transactions:...)  // Cálculo de gasto
```

### Tier 2: Tests con In-Memory SwiftData
**Complejidad**: Media
**Valor**: Alto
**Prioridad**: Fase siguiente

Requiere configurar ModelContainer in-memory:

```swift
// Test helper para crear contexto in-memory
@MainActor
func makeTestContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: TransactionItem.self, Account.self, Category.self,
            Subcategory.self, Tag.self, Budget.self, InboxDraft.self,
        configurations: config
    )
    return container.mainContext
}
```

#### ViewModels para Tier 2:
| ViewModel | Qué testear |
|-----------|-------------|
| `NewTransactionViewModel` | `save()`, `prefill()`, validación completa |
| `InboxViewModel` | `loadData()`, lookup methods |
| `BudgetsViewModel` | `refreshBudgetData()`, cálculos completos |
| `RecordsFiltersViewModel` | Aplicación de filtros |
| `PanelViewModel` | Carga y agregación de datos |

### Tier 3: Tests de Integración
**Complejidad**: Alta
**Valor**: Medio
**Prioridad**: Futura

Flujos completos que cruzan múltiples ViewModels:
- Crear transacción → verificar en Panel
- Crear presupuesto → verificar cálculo de consumo
- Aprobar draft → verificar transacción creada

---

## Plan de Implementación

### Fase 1: Foundation (Inmediato)
**Objetivo**: Establecer patterns y probar lógica pura

1. **Crear `TestHelpers.swift`**
   - Factory methods para crear modelos mock
   - Helper para ModelContext in-memory
   - Extensions útiles para tests

2. **Crear `NewTransactionViewModelTests.swift`**
   - Tests de teclado numérico (Tier 1)
   - Tests de validación (Tier 1)
   - Tests de cálculo de tipo de cambio (Tier 1)

3. **Crear `BudgetsViewModelTests.swift`**
   - Tests de `getBudgetStatus()` (Tier 1)
   - Tests de `getDaysRemaining()` (Tier 1)
   - Tests de `getBudgetDateInterval()` (Tier 1)

### Fase 2: SwiftData Tests (Siguiente)
**Objetivo**: Testear interacción con datos

4. **Crear `InboxViewModelTests.swift`**
   - Tests con drafts mock in-memory
   - Tests de filtrado y agrupación

5. **Extender tests existentes**
   - `NewTransactionViewModelTests` + save/edit
   - `BudgetsViewModelTests` + spending calculation

### Fase 3: Coverage Expansion (Futuro)
**Objetivo**: Cobertura amplia

6. **ViewModels de Settings**
   - `AccountsSettingsListViewModel`
   - `CategoriesSettingsListViewModel`
   - `TagsSettingsListViewModel`

7. **ViewModels de Selectors**
   - `AccountSelectorViewModel`
   - `SubcategorySelectorViewModel`
   - `TagSelectorViewModel`

---

## Ejemplos de Tests

### Tier 1: Teclado Numérico (NewTransactionViewModel)

```swift
import Testing
@testable import Yala

struct NewTransactionViewModelTests {

    // MARK: - Numeric Keypad Tests

    @Test func appendDigitReplacesZero() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("5")
        #expect(await vm.amountString == "5")
    }

    @Test func appendDigitAddsToExisting() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        await vm.appendDigit("2")
        await vm.appendDigit("3")
        #expect(await vm.amountString == "123")
    }

    @Test func appendDecimalOnlyOnce() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        await vm.appendDigit(".")
        await vm.appendDigit(".")
        await vm.appendDigit("5")
        #expect(await vm.amountString == "1.5")
    }

    @Test func limitsDecimalsToTwo() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        await vm.appendDigit(".")
        await vm.appendDigit("2")
        await vm.appendDigit("3")
        await vm.appendDigit("4")  // Should be ignored
        #expect(await vm.amountString == "1.23")
    }

    @Test func deleteLastDigitWorks() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        await vm.appendDigit("2")
        await vm.deleteLastDigit()
        #expect(await vm.amountString == "1")
    }

    @Test func deleteLastDigitResetsToZero() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("5")
        await vm.deleteLastDigit()
        #expect(await vm.amountString == "0")
    }

    @Test func clearAmountResetsToZero() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        await vm.appendDigit("2")
        await vm.appendDigit("3")
        await vm.clearAmount()
        #expect(await vm.amountString == "0")
    }

    // MARK: - Validation Tests

    @Test func isAmountValidWhenGreaterThanZero() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        #expect(await vm.isAmountValid == true)
    }

    @Test func isAmountInvalidWhenZero() async {
        let vm = await NewTransactionViewModel()
        #expect(await vm.isAmountValid == false)
    }

    @Test func amountParsesCorrectly() async {
        let vm = await NewTransactionViewModel()
        await vm.appendDigit("1")
        await vm.appendDigit("2")
        await vm.appendDigit(".")
        await vm.appendDigit("5")
        #expect(await vm.amount == 12.5)
    }
}
```

### Tier 1: Budget Status (BudgetsViewModel)

```swift
import Testing
@testable import Yala

struct BudgetsViewModelTests {

    @Test func budgetStatusActiveWhenUnderLimit() async {
        let vm = await BudgetsViewModel()
        let budget = makeMockBudget(limit: 1000, isActive: true)
        let status = await vm.getBudgetStatus(budget: budget, spending: 500)
        #expect(status == .active)
    }

    @Test func budgetStatusExceededWhenOverLimit() async {
        let vm = await BudgetsViewModel()
        let budget = makeMockBudget(limit: 1000, isActive: true)
        let status = await vm.getBudgetStatus(budget: budget, spending: 1200)
        #expect(status == .exceeded)
    }

    @Test func budgetStatusExceededWhenExactlyAtLimit() async {
        let vm = await BudgetsViewModel()
        let budget = makeMockBudget(limit: 1000, isActive: true)
        let status = await vm.getBudgetStatus(budget: budget, spending: 1000)
        #expect(status == .exceeded)
    }

    @Test func budgetStatusInactiveWhenManuallyDisabled() async {
        let vm = await BudgetsViewModel()
        let budget = makeMockBudget(limit: 1000, isActive: false)
        let status = await vm.getBudgetStatus(budget: budget, spending: 500)
        #expect(status == .inactive)
    }

    // MARK: - Days Remaining Tests

    @Test func daysRemainingCalculatesCorrectly() async {
        let vm = await BudgetsViewModel()
        // Set up budget with known period
        let budget = makeMockBudget(periodType: .monthly)
        let days = await vm.getDaysRemaining(budget: budget)
        #expect(days >= 0)
    }

    // Helper
    private func makeMockBudget(
        limit: Double = 1000,
        isActive: Bool = true,
        periodType: BudgetPeriodType = .monthly
    ) -> Budget {
        // Requires SwiftData context for full test
        // For Tier 1, use minimal mock
        fatalError("Implement with test context")
    }
}
```

### Tier 2: In-Memory SwiftData

```swift
import Testing
import SwiftData
@testable import Yala

struct InboxViewModelIntegrationTests {

    @MainActor
    @Test func loadDataFetchesDrafts() async throws {
        // Setup
        let context = try makeTestContext()
        let vm = InboxViewModel()

        // Create test drafts
        let draft1 = InboxDraft(/* ... */)
        let draft2 = InboxDraft(/* ... */)
        context.insert(draft1)
        context.insert(draft2)
        try context.save()

        // Act
        vm.setContext(context)

        // Assert
        #expect(vm.allDrafts.count == 2)
    }

    @MainActor
    @Test func filteredDraftsReturnsPendingOnly() async throws {
        let context = try makeTestContext()
        let vm = InboxViewModel()

        // Create mixed drafts
        let pending = InboxDraft(status: .pending, /* ... */)
        let approved = InboxDraft(status: .approved, /* ... */)
        context.insert(pending)
        context.insert(approved)
        try context.save()

        vm.setContext(context)

        // Assert
        let filtered = vm.filteredDrafts(for: .pending)
        #expect(filtered.count == 1)
    }

    // Helper
    @MainActor
    private func makeTestContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: InboxDraft.self, TransactionItem.self, Account.self,
                Category.self, Subcategory.self, Tag.self,
            configurations: config
        )
        return container.mainContext
    }
}
```

---

## Métricas de Éxito

### Fase 1 Completada Cuando:
- [x] `TestHelpers.swift` creado con factories ✅ (2026-01-29)
- [x] `NewTransactionViewModelTests.swift` con 10+ tests de teclado/validación ✅ (35 tests)
- [ ] `BudgetsViewModelTests.swift` con 5+ tests de status/días ⚠️ (ver Issues Conocidos)
- [ ] Todos los tests pasan en CI

### Fase 2 Completada Cuando:
- [x] In-memory SwiftData helper funcional ✅ (makeTestContext())
- [ ] `InboxViewModelTests.swift` con tests de filtrado
- [ ] Tests de `save()` en NewTransactionViewModel
- [ ] Cobertura de lógica crítica > 60%

### Fase 3 Completada Cuando:
- [ ] Tests para todos los ViewModels de Settings
- [ ] Tests para todos los Selectors
- [ ] Cobertura de lógica crítica > 80%

---

## Issues Conocidos

### Swift Testing + SwiftData + @MainActor
Los tests de BudgetsViewModel (que usan SwiftData in-memory) pasan individualmente pero fallan cuando se ejecutan como suite. Este es un problema conocido con Swift Testing ejecutando tests @MainActor en paralelo con ModelContainers separados.

**Workarounds a investigar:**
1. Usar `@Suite(.serialized)` para forzar ejecución secuencial
2. Migrar a XCTest para tests con SwiftData
3. Usar un ModelContainer compartido con cleanup entre tests

**Estado:** Tests comentados temporalmente en BudgetsViewModelTests.swift

---

## Prioridad de ViewModels por Riesgo/Valor

| Prioridad | ViewModel | Razón |
|-----------|-----------|-------|
| 🔴 Alta | `NewTransactionViewModel` | Core de la app, lógica de validación y guardado |
| 🔴 Alta | `BudgetsViewModel` | Cálculos financieros complejos |
| 🟡 Media | `InboxViewModel` | Filtrado y agrupación de drafts |
| 🟡 Media | `PanelViewModel` | Agregaciones para dashboard |
| 🟡 Media | `RecordsFiltersViewModel` | Filtros combinados |
| 🟢 Baja | `*SelectorViewModel` | Lógica simple de selección |
| 🟢 Baja | `*SettingsViewModel` | CRUD básico |

---

## Notas de Implementación

### MainActor y Async Tests
Los ViewModels usan `@MainActor`, por lo que los tests deben:
```swift
@MainActor
@Test func testSomething() async {
    let vm = SomeViewModel()
    // ...
}
```

### Evitar Tests Frágiles
- No testear strings de UI (pueden cambiar)
- Testear comportamiento, no implementación
- Usar factories para crear datos consistentes

### SwiftData en Tests
- Siempre usar `isStoredInMemoryOnly: true`
- Crear contexto fresco para cada test
- No compartir estado entre tests
