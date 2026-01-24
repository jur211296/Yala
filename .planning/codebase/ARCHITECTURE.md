# Architecture

**Analysis Date:** 2026-01-15

## Pattern Overview

**Overall:** MVVM + Reactive Unidirectional Data Flow

**Key Characteristics:**
- SwiftUI views with `@Observable` ViewModels
- SwiftData as single source of truth for persistence
- `SessionState` for cross-view state synchronization
- Service layer for business logic and API coordination
- Protocol-based abstractions for testability

## Layers

**Presentation Layer (Views):**
- Purpose: UI rendering and user interaction
- Contains: SwiftUI views, reusable components, theme/design tokens
- Location: `Yala/App/Views/`, `Yala/App/Components/`, `Yala/App/Theme/`
- Depends on: ViewModels, Models
- Used by: App entry point

**ViewModel Layer:**
- Purpose: State management and presentation logic
- Contains: `@Observable` classes with screen-specific state
- Location: `Yala/App/ViewModels/`
- Depends on: Services, Models, Logic/Calculators
- Used by: Views

**Logic Layer:**
- Purpose: Pure business calculations (stateless)
- Contains: Calculators, Helpers
- Location: `Yala/App/Logic/Calculators/`, `Yala/App/Logic/Helpers/`
- Depends on: Models only
- Used by: ViewModels, Services

**Service Layer:**
- Purpose: Business operations, API calls, data coordination
- Contains: Singleton services marked `@MainActor`
- Location: `Yala/Services/`
- Depends on: Models, SwiftData context, external APIs
- Used by: ViewModels, Background tasks

**Data Layer (Models):**
- Purpose: Domain entities and SwiftData persistence
- Contains: `@Model` classes (8 core entities)
- Location: `Yala/Models/`
- Depends on: SwiftData framework
- Used by: All layers

**App Models Layer:**
- Purpose: View-specific, non-persistent models and enums
- Contains: SessionState, FilterCriteria, domain enums
- Location: `Yala/App/Models/`
- Depends on: Foundation
- Used by: ViewModels, Views

## Data Flow

**Transaction Creation Flow:**

1. User taps "+" button in Panel
2. `NewTransactionView` opens with `NewTransactionViewModel`
3. User fills form (amount, category, account, etc.)
4. ViewModel validates input, fetches exchange rate from `ExchangeRateService`
5. On submit: creates `TransactionItem` via SwiftData context
6. `@Query` in views automatically updates to reflect new data
7. Balance recalculated by `AccountBalanceCalculator`

**Filter Synchronization Flow:**

1. User changes filter in Panel (period, accounts, etc.)
2. `SessionState.globalFilters` updated
3. Statistics view observes `SessionState` via `@Environment`
4. Both views automatically sync period & filters
5. Calculators recompute derived data

**Pie Chart Interactivity Flow (Tags/Categories):**

1. User taps segment in pie chart (e.g., TagsPieWidget)
2. Widget updates local selection and triggers filter sync
3. `isSyncingFilters` flag prevents infinite loops
4. `SessionState.globalFilters` updated with selected tag/category
5. All views (CategoriesTabView, RecordsTabView) reflect filter
6. Tapping same segment again clears the filter

**State Management:**
- Global: `SessionState` (`@Observable`) passed via `.environment()`
- Screen-local: Individual `@State` and `@Observable` ViewModels
- Persistent: SwiftData `@Query` for reactive data fetching

## Key Abstractions

**SessionState:**
- Purpose: Cross-view synchronization (period, filters, metrics)
- Location: `Yala/App/Models/SessionState.swift`
- Pattern: `@Observable` singleton passed via environment
- Examples: `selectedPeriod`, `globalFilters`, `trendMetric`

**Filterable Protocol:**
- Purpose: Unified filtering interface for ViewModels
- Location: `Yala/App/Protocols/Filterable.swift`
- Pattern: Protocol with default implementations
- Examples: `RecordsViewModel`, `StatisticsViewModel`

**Services (Singleton Pattern):**
- Purpose: Business logic encapsulation
- Pattern: `@MainActor final class` with `.shared` property
- Examples: `ExchangeRateService.shared`, `FilterService`, `CurrencyConverter.shared`

**Calculators (Stateless):**
- Purpose: Pure data transformations
- Pattern: Static methods, no instance state
- Examples: `BalanceTrendCalculator`, `CashFlowCalculator`, `TopSpendingCategoriesCalculator`

## Entry Points

**App Entry:**
- Location: `Yala/App/YalaApp.swift`
- Triggers: App launch
- Responsibilities: SwiftData ModelContainer setup, root view hierarchy, background task registration

**Main Content:**
- Location: `Yala/App/ContentView.swift`
- Triggers: After app initialization
- Responsibilities: Tab-based navigation (Panel, Statistics, Planning, More, Search)

**Background Task:**
- Location: `Yala/Services/BackgroundJobs.swift`
- Triggers: Daily system wake (BGAppRefreshTaskRequest)
- Responsibilities: Exchange rate updates, budget checks (TODO)

## Error Handling

**Strategy:** Errors thrown and caught at boundaries; user-facing feedback via UI

**Patterns:**
- Services throw typed errors (e.g., `ExchangeRateProviderError`)
- ViewModels catch and display error states
- `fatalError()` used only for unrecoverable initialization failures (needs improvement)
- API errors fallback to cached/default values

## Cross-Cutting Concerns

**Logging:**
- Console print statements (debug only)
- No structured logging framework

**Validation:**
- Form validation in ViewModels
- Currency/amount parsing in `Yala/Utils/MoneyParsing.swift`

**Localization:**
- Type-safe L10n enum: `Yala/Utils/L10n.swift`
- NSLocalizedString under the hood
- Supports English and Spanish

**Design System:**
- Centralized tokens: `Yala/App/Theme/DesignTokens.swift`
- `DS.Spacing`, `DS.Radius`, `DS.Opacity`, `DS.Animation`

**Thread Safety:**
- Critical services marked `@MainActor`
- SwiftData context accessed from main thread
- `@Observable` ViewModels implicitly main-thread

---

*Architecture analysis: 2026-01-15*
*Update when major patterns change*
