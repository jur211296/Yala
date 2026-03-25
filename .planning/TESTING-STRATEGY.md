# Testing — Referencia y Estrategia

Documento de referencia para los tests de Yala. Consultar antes de agregar, modificar o depurar tests.

**Actualizado:** 2026-03-24 | **Total:** 1085 tests, 93 suites

---

## Inventario Completo

### Por archivo

| Archivo | Tests | Tipo | Componente |
|---------|-------|------|------------|
| NewTransactionViewModelTests | 35 | ViewModel | Teclado, validación, tipos |
| PreviousPeriodHelperTests | 24 | Logic | Periodos anteriores, variación |
| AmountParserTests | 15 | Parser/OCR | Parsing montos de texto |
| AccountFormViewModelTests | 15 | ViewModel | Validación nombre/moneda/balance |
| DraftDeduplicationServiceTests | 15 | Service | Normalización, similitud, dedup |
| TrendGroupingTests | 13 | Logic | Agrupación día/semana/mes |
| MerchantCanonicalizerTests | 12 | Service | Canonicalización merchants |
| BudgetsViewModelTests | 11 | ViewModel | Status presupuestos |
| FilterServiceTests | 10 | Service | Filtros, condiciones de monto |
| TagTests | 10 | Model | Colores, next available |
| DateParserTests | 10 | Parser/OCR | Parsing fechas de texto |
| MoneyParsingTests | 10 | Utils | parseDecimal() formatos |
| InboxViewModelTests | 10 | ViewModel | Filtrado/agrupación drafts |
| CategoryDetailViewModelTests | 9 | ViewModel | Cambios, canSave, sistema |
| TagFormViewModelTests | 8 | ViewModel | Validación nombre/unicidad |
| CurrencyConverterTests | 8 | Service | Conversión con fallback rates |
| AccountBalanceCalculatorTests | 6 | Utils | Balance actual, batch |
| FeatureGateTests | 6 | Service | Límites free, features Pro |
| ViewModelFilterTests | 6 | ViewModel | Filtros ScheduledPayments |
| TrendProcessingTests | 5 | Logic | Moving average, yDomain |
| DateContextProviderTests | 5 | Service | Contexto de fechas para AI |
| ExchangeRateWidgetHelperTests | 4 | Logic | Cálculo rates para widgets |
| CurrencyCodeTests | 4 | Model | Enum CurrencyCode |
| CurrencyDefaultsTests | 3 | Utils | Defaults de moneda |
| RecordsFiltersViewModelTests | 3 | ViewModel | Texto selección filtros |
| BudgetEditorViewModelTests | 1 | ViewModel | Texto categorías vacías |
| YalaTests | 1 | Placeholder | Test de ejemplo |
| CalculatorTests | 3 | Logic | Agrupación cashflow/balance |

### Por categoría

| Categoría | Suites | Tests | % del total |
|-----------|--------|-------|-------------|
| ViewModels | 10 | 104 | 41% |
| Services | 5 | 51 | 20% |
| Parsers/OCR | 2 | 25 | 10% |
| Logic/Helpers | 4 | 45 | 18% |
| Models/Utils | 5 | 29 | 11% |
| Otro | 2 | 1 | <1% |

---

## Regla Fundamental: NUNCA usar makeTestContext()

### El problema

`makeTestContext()` crea un `ModelContainer` in-memory. Al ejecutar tests, el **host de la app** (Yala.app) inicializa su propio `ModelContainer` con CloudKit. Crear un segundo container causa un **race condition** en la metadata de SwiftData que produce `EXC_BREAKPOINT` (crash).

### La solución

Crear objetos `@Model` **sin insertarlos en un contexto**. Las propiedades y `persistentModelID` funcionan sin contexto:

```swift
// MAL — crashea por CloudKit race condition
@MainActor @Test func test() throws {
    let ctx = try makeTestContext()                    // CRASH
    let account = makeTestAccount(context: ctx)
    // ...
}

// BIEN — sin ModelContext, sin crash
@Test func test() {
    let account = Account(name: "Test", currencyCode: "PEN",
                          colorHex: "#000", iconName: "creditcard", type: "bank")
    let vm = SomeViewModel()
    vm.selectedAccounts.insert(account.persistentModelID)  // funciona
    #expect(account.name == "Test")                         // funciona
}
```

### Cuándo NO se puede evitar el contexto

Algunos métodos requieren `setContext()` para cargar datos con `FetchDescriptor`. En esos casos:
- Si la lógica es trivial (string formatting), **no testear** — el costo/beneficio no justifica el riesgo
- Si la lógica es compleja, considerar **extraer un método puro** que acepte datos primitivos

### Tests existentes que SÍ usan contexto (legacy)

`NewTransactionViewModelTests`, `InboxViewModelTests`, `BudgetsViewModelTests`, `FilterServiceTests` — funcionan porque **no crean `ModelContainer`** (usan lógica pura expuesta por los ViewModels).

---

## Patrones y Convenciones

### Framework

```swift
import Testing
@testable import Yala

struct MiComponenteTests {
    @Test func descripcion_del_test() {
        // arrange → act → assert con #expect
    }
}
```

- **Swift Testing** (`@Test`, `#expect`), NO XCTest
- **structs** para suites, NO classes
- Un archivo = un componente
- Nombre: `{Componente}Tests.swift`

### Nomenclatura de tests

```
metodo_condicion_resultado()
```

Ejemplos:
- `isNameValid_empty_false()`
- `convertWithFallback_sameCurrency()`
- `batchCalculateBalances_ignoresUnrelatedAccounts()`

### Cuándo usar @MainActor

Solo cuando el código bajo test requiere `@MainActor` (ViewModels con `@Observable`):

```swift
// ViewModel es @MainActor @Observable → test necesita @MainActor
@MainActor @Test func test() { ... }

// Función estática pura → NO necesita @MainActor
@Test func test() { ... }
```

### Asserts direccionales (para valores que pueden cambiar)

Para tests de conversión o cálculos con rates que pueden actualizarse:

```swift
// MAL — frágil, falla si cambian los rates
#expect(result == 3.75)

// BIEN — direccional, robusto
#expect(result > 100)  // PEN vale menos que USD
#expect(result < 100)  // USD vale más que PEN
```

### Factories disponibles en TestHelpers.swift

| Factory | Parámetros clave | Notas |
|---------|-----------------|-------|
| `makeTestContext()` | — | NO USAR (ver regla arriba) |
| `makeTestAccount()` | name, currencyCode | Requiere context |
| `makeTestCategory()` | name, isIncome | Requiere context |
| `makeTestSubcategory()` | name, category, nature | Requiere context |
| `makeTestTag()` | name | Requiere context |
| `makeTestBudget()` | name, limitAmount, periodType | Requiere context |
| `makeTestTransaction()` | amount, date, account, category, subcategory | Requiere context |
| `makeTestInboxDraft()` | amount, date, note | Requiere context |
| `makeTestExchangeRate()` | dateKey, rates | Requiere context |

**Nota:** Todas estas factories requieren `makeTestContext()` que NO se debe usar. Para tests nuevos, crear objetos directamente:

```swift
let account = Account(name: "Test", currencyCode: "PEN",
                      colorHex: "#000", iconName: "creditcard", type: "bank")
```

---

## Cómo ejecutar tests

```bash
# Todos los tests (recomendado)
xcodebuild test -scheme Yala \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests \
  -parallel-testing-enabled NO

# Tests específicos
xcodebuild test -scheme Yala \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/MerchantCanonicalizerTests \
  -parallel-testing-enabled NO

# Skills disponibles
/test-ios     # Todos los tests + resumen
/test-smart   # Solo tests relevantes a cambios actuales
```

**IMPORTANTE:** Siempre usar `-parallel-testing-enabled NO`. Sin este flag, el simulador iOS 26 crea clones que crashean al inicializar.

---

## Guía para agregar tests

### 1. Identificar el tipo de lógica

| Tipo | Ejemplo | Necesita contexto? |
|------|---------|-------------------|
| Función pura/estática | `AmountParser.parse()` | No |
| Computed property sin datos | `vm.isNameValid` | No |
| Método con datos inyectados | `vm.calculateBudgetStatus(isActive:spending:limit:)` | No |
| Computed property con datos del contexto | `vm.selectedAccountsText()` cuando `allAccounts` viene del contexto | No se puede testear fácilmente |

### 2. Crear el archivo

```swift
//
//  MiComponenteTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

struct MiComponenteTests {

    // MARK: - Grupo de tests

    @Test func metodo_condicion_resultado() {
        // ...
    }
}
```

### 3. Verificar

```bash
xcodebuild test -scheme Yala \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/MiComponenteTests \
  -parallel-testing-enabled NO
```

### 4. Actualizar CLAUDE.md

Agregar la nueva suite a la sección `### Test Suites` con el conteo de tests.

---

## Componentes sin tests (candidatos futuros)

### Alta prioridad (lógica financiera compleja)

| Componente | Archivo | Lógica testeable |
|------------|---------|-----------------|
| PanelViewModel | ViewModels/PanelViewModel.swift | Agregaciones, totales por periodo |
| StatisticsViewModel | ViewModels/StatisticsViewModel.swift | Cálculos estadísticos |
| RecordsViewModel | ViewModels/RecordsViewModel.swift | Filtrado combinado |
| TransactionCSVImportService | Services/TransactionCSVImportService.swift | Parsing CSV |

### Media prioridad

| Componente | Archivo | Lógica testeable |
|------------|---------|-----------------|
| ScheduledPaymentNotificationService | Services/ScheduledPayment*.swift | Cálculo próxima fecha |
| BudgetAlertService | Services/BudgetAlertService.swift | Umbrales de alertas |
| MerchantMemoryService | Services/MerchantMemoryService.swift | Auto-categorización |

### No testear (CRUD puro o requiere frameworks)

- ViewModels de selector (AccountSelector, SubcategorySelector, TagSelector)
- ViewModels de settings (listas CRUD simples)
- BiometricAuthService (requiere LAContext real)
- StoreKitManager (requiere StoreKit sandbox)
- NetworkMonitor (requiere NWPathMonitor)
- iCloudSyncService (requiere CloudKit)

---

## Historial

| Fecha | Cambio | Tests |
|-------|--------|-------|
| 2026-01-15 | Tests iniciales (Calculator, Filter, Tag, Trend) | 41 |
| 2026-01-29 | TestHelpers + NewTransaction + Budgets | 87 |
| 2026-01-30 | Inbox + TrendProcessing actualizado | 97 |
| 2026-02-08 | Cobertura completa: 17 archivos nuevos, refactor sin ModelContext | 255 |
