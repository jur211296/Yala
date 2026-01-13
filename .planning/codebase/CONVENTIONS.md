# Coding Conventions

**Analysis Date:** 2026-01-13

## Naming Patterns

**Files:**
- `{FeatureName}View.swift` - SwiftUI views (e.g., `PanelView.swift`, `AccountFormView.swift`)
- `{Feature}ViewModel.swift` - ViewModels (e.g., `NewTransactionViewModel.swift`)
- `{Name}Service.swift` - Services (e.g., `FilterService.swift`, `ExchangeRateService.swift`)
- `{Name}Calculator.swift` - Pure calculators (e.g., `BalanceTrendCalculator.swift`)
- `{Name}Helper.swift` - Helper functions (e.g., `TrendProcessingHelper.swift`)
- `{Feature}Tests.swift` - Tests (e.g., `FilterServiceTests.swift`)

**Types (PascalCase):**
- Classes: `TransactionItem`, `Category`, `PanelViewModel`
- Structs: `FilterCriteria`, `FilterService`, `BalanceHelper`
- Enums: `TransactionType`, `CurrencyCode`, `SubcategoryNature`
- Protocols: `Filterable`, `ExchangeRateProviderProtocol`

**Functions/Variables (camelCase):**
- Properties: `selectedAccount`, `transactionDate`, `exchangeRate`
- Parameters: `transactions`, `criteria`, `currencyCode`
- Boolean flags: `isIncome`, `isActive`, `hasActiveFilters`, `isArchived`

**Constants:**
- Static properties: `static let defaultValue`
- Design tokens: `DS.Spacing.md`, `DS.Radius.lg`

## Code Style

**Formatting:**
- 4-space indentation (Swift standard)
- Double-space between logical sections
- Consistent spacing around braces and operators
- Line wrapping for long function signatures

**Property Wrappers (iOS 17+):**
- `@Observable` for ViewModels (not `ObservableObject`)
- `@Model` for SwiftData entities
- `@MainActor` for thread-safe services
- `@Query` for reactive data fetching
- `@State`, `@Binding`, `@Environment`, `@AppStorage` for SwiftUI

**Class/Struct Declarations:**
- `final class` for classes (prevents inheritance, performance)
- `struct` for value types and stateless helpers
- Example: `final class TransactionItem`, `struct BalanceHelper`

**Linting:**
- No SwiftLint configuration detected
- Style enforced through conventions and review

## Import Organization

**Order:**
1. Foundation/SwiftUI/SwiftData
2. Platform frameworks (UIKit, PhotosUI, Charts)
3. External packages (CoreXLSX)
4. Local imports (not used - single module)

**Standard Imports:**
```swift
import Foundation
import SwiftData
import SwiftUI
```

## Error Handling

**Patterns:**
- Throw typed errors from services (e.g., `ExchangeRateProviderError`)
- Catch at ViewModel/View boundaries
- Return optionals for parsing failures
- Use `guard` for early returns

**Error Types:**
- Services define domain errors as enums
- Example: `ExchangeRateProviderError.networkError`, `.rateLimited`

## Logging

**Current Approach:**
- `print()` statements for debug logging
- No structured logging framework
- Debug emoji markers in some files (e.g., `ImportIntroSheet.swift`)

**Recommendation:**
- Use `#if DEBUG` guards
- Remove/guard prints before production

## Comments

**MARK Comments:**
- Extensive use: `// MARK: - Section Name`
- Separate properties, computed properties, methods
- Examples:
  - `// MARK: - Filter Criteria`
  - `// MARK: - Entity Filters`
  - `// MARK: - Individual Matching`

**Documentation (///)**
- Triple-slash for public API documentation
- Include parameter and return descriptions
- Example:
```swift
/// Filters transactions based on the provided criteria.
///
/// - Parameters:
///   - transactions: All transactions to filter
///   - criteria: Filter criteria to apply
/// - Returns: Filtered array of transactions
static func filter(...) -> [TransactionItem]
```

**Inline Comments:**
- Explain "why" not "what"
- Include issue references (e.g., `// FIN-56: reason`)

**TODO Comments:**
- Format: `// TODO: description`
- No username (use git blame)
- Example: `// TODO: Check budgets`

## Function Design

**Size:**
- Keep functions focused
- Extract helpers for complex logic
- Large files exist but should be refactored (see CONCERNS.md)

**Parameters:**
- Use labeled parameters (Swift convention)
- Wrap to multiple lines when >3 parameters
- Example:
```swift
static func filter(
    transactions: [TransactionItem],
    criteria: FilterCriteria
) -> [TransactionItem]
```

**Return Values:**
- Explicit returns
- Early return with `guard`
- Optionals for fallible operations

## Module Design

**Exports:**
- Single module (Neto)
- No explicit barrel files
- Types accessed directly

**Access Control:**
- Most types implicitly internal
- `private` for implementation details
- No explicit `public` (single target)

## SwiftUI Patterns

**View Structure:**
```swift
struct FeatureView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    // MARK: - Query
    @Query(...) private var items: [Item]

    // MARK: - State
    @State private var viewModel = FeatureViewModel()

    // MARK: - Body
    var body: some View {
        // ...
    }

    // MARK: - Subviews
    private var someSubview: some View {
        // ...
    }
}
```

**ViewModel Pattern:**
```swift
@Observable
final class FeatureViewModel {
    // State properties
    var selectedItem: Item?
    var isLoading = false

    // Computed properties
    var hasSelection: Bool { selectedItem != nil }

    // Methods
    func loadData() async { }
}
```

## Design System

**Tokens Location:** `Neto/App/Theme/DesignTokens.swift`

**Spacing:**
- `DS.Spacing.xxs` (2pt) through `DS.Spacing.xxxxl` (48pt)

**Radius:**
- `DS.Radius.xs` (4pt) through `DS.Radius.full` (9999pt)

**Opacity:**
- `DS.Opacity.glass` (0.6), `DS.Opacity.overlay` (0.4)

**Colors:**
- `DS.Colors.electricIndigo`, `DS.Colors.hotPink`, etc.

---

*Convention analysis: 2026-01-13*
*Update when patterns change*
