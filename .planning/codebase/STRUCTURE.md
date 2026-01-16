# Codebase Structure

**Analysis Date:** 2026-01-15

## Directory Layout

```
Neto/
├── Neto/                       # Main application source
│   ├── App/                    # Application layer
│   │   ├── NetoApp.swift       # @main entry, ModelContainer setup
│   │   ├── ContentView.swift   # Tab navigation root
│   │   ├── Views/              # UI components by feature
│   │   ├── ViewModels/         # State management
│   │   ├── Models/             # App-specific models (non-persistent)
│   │   ├── Logic/              # Business calculations
│   │   ├── Protocols/          # Shared protocols
│   │   ├── Components/         # View modifiers
│   │   └── Theme/              # Design tokens
│   ├── Models/                 # SwiftData entities (8 models)
│   ├── Services/               # Business logic, API
│   ├── Utils/                  # Utilities, helpers
│   ├── Seed/                   # Initial data
│   └── Resources/              # Assets, localization
├── NetoTests/                  # Unit tests
├── NetoUITests/                # UI tests
└── Neto.xcodeproj/             # Xcode project
```

## Directory Purposes

**Neto/App/Views/:**
- Purpose: All SwiftUI views organized by feature
- Contains: Feature directories with `*View.swift` files
- Key subdirectories:
  - `Panel/` - Dashboard widgets (18 views, incl. TagsPieWidget)
  - `Statistics/` - Analytics and charts
  - `Planning/` - Budget management
  - `Transactions/` - Transaction forms
  - `Records/` - Transaction history
  - `Accounts/` - Account management
  - `Filters/` - Filter UI components
  - `Shared/` - Reusable components (incl. IconColorPickerSheet)
  - `Import/` - Data import wizard
  - `ExportWizard/` - Data export
  - `Profile/` - User settings
  - `Settings/` - App settings
  - `Tags/` - Tag management (TagFormView)
  - `Categories/` - Category detail and management
  - `Favorites/` - Favorite payments

**Neto/App/ViewModels/:**
- Purpose: State management classes
- Contains: `@Observable` ViewModels
- Key files:
  - `PanelViewModel.swift` - Dashboard state
  - `NewTransactionViewModel.swift` - Transaction form
  - `StatisticsViewModel.swift` - Analytics state
  - `RecordsViewModel.swift` - History filtering
  - `BudgetsViewModel.swift` - Budget management
  - `WidgetConfigManager.swift` - Widget preferences

**Neto/App/Models/:**
- Purpose: App-level models (not SwiftData)
- Contains: SessionState, enums, view-specific types
- Key files:
  - `SessionState.swift` - Global state
  - `SharedModels.swift` - Domain enums (incl. TagSpendingSummary para pie de tags)
  - `WidgetModels.swift` - Widget state
  - `TransactionFormModels.swift` - Form types
  - `BudgetModels.swift` - Budget types

**Neto/App/Logic/:**
- Purpose: Pure business calculations
- Subdirectories:
  - `Calculators/` - Data aggregation
  - `Helpers/` - Utility functions
- Key files:
  - `BalanceTrendCalculator.swift`
  - `CashFlowCalculator.swift`
  - `TopSpendingCategoriesCalculator.swift`
  - `TrendProcessingHelper.swift`

**Neto/Models/:**
- Purpose: SwiftData entities (source of truth)
- Contains: 8 `@Model` classes
- Key files:
  - `Category.swift` - Expense/Income categories
  - `Subcategory.swift` - Category subdivisions
  - `Account.swift` - Bank/wallet accounts
  - `Tag.swift` - Transaction labels (con iconName, colorHex, paleta de 15 colores)
  - `TransactionItem.swift` - Core transactions
  - `Budget.swift` - Budget constraints (relación muchos-a-muchos con Tag)
  - `ExchangeRate.swift` - Currency rates
  - `FavoritePayment.swift` - Payment templates

**Neto/Services/:**
- Purpose: Business operations, API integration
- Contains: Singleton services (`@MainActor`)
- Key files:
  - `ExchangeRateService.swift` - Rate management
  - `ExchangeRateAPIService.swift` - API client
  - `FilterService.swift` - Filtering logic
  - `TransactionUpdateService.swift` - Transaction ops
  - `CurrencyConverter.swift` - Conversion utils
  - `TrendDataProcessor.swift` - Chart data

**Neto/Utils/:**
- Purpose: Utilities and helpers
- Contains: Extensions, parsers, import/export
- Key files:
  - `L10n.swift` - Localization (791 lines)
  - `MoneyParsing.swift` - Currency parsing
  - `CurrencyUtils.swift` - Currency helpers
  - `TransactionCSVImportService.swift` - CSV import
  - `TransactionsExportService.swift` - CSV export
  - `Color+Hex.swift` - Hex color parsing
  - `AccountBalanceCalculator.swift` - Balance calc

**Neto/Resources/:**
- Purpose: Assets and localization
- Contains: xcassets, .lproj folders
- Key files:
  - `Assets.xcassets/` - Images, colors
  - `en.lproj/Localizable.strings` - English
  - `es.lproj/Localizable.strings` - Spanish
  - `Info.plist` - App metadata

## Key File Locations

**Entry Points:**
- `Neto/App/NetoApp.swift` - App entry, SwiftData setup
- `Neto/App/ContentView.swift` - Tab navigation

**Configuration:**
- `Neto.xcodeproj/project.pbxproj` - Build settings, SPM deps
- `Neto/Secrets.xcconfig` - API keys (gitignored)
- `Neto/Resources/Info.plist` - App metadata

**Core Logic:**
- `Neto/Services/` - Business services
- `Neto/App/Logic/` - Calculators
- `Neto/App/ViewModels/` - State management

**Testing:**
- `NetoTests/` - Unit tests
- `NetoUITests/` - UI tests

**Documentation:**
- `CLAUDE.md` - Development instructions

## Naming Conventions

**Files:**
- `*View.swift` - SwiftUI views
- `*ViewModel.swift` - ViewModels
- `*Service.swift` - Services
- `*Calculator.swift` - Pure calculators
- `*Helper.swift` - Helper functions
- `*Tests.swift` - Test files

**Directories:**
- PascalCase for feature directories (e.g., `Transactions/`)
- Plural for collections (e.g., `Views/`, `Models/`)

**Special Patterns:**
- `Components/` subdirectory for feature-specific reusables
- `Shared/` for cross-feature components

## Where to Add New Code

**New Feature:**
- Primary code: `Neto/App/Views/{FeatureName}/`
- ViewModel: `Neto/App/ViewModels/{Feature}ViewModel.swift`
- Tests: `NetoTests/{Feature}Tests.swift`

**New SwiftData Model:**
- Model: `Neto/Models/{ModelName}.swift`
- Update schema in `Neto/App/NetoApp.swift`

**New Service:**
- Implementation: `Neto/Services/{Name}Service.swift`
- Mark `@MainActor` if using ModelContext

**New Calculator/Helper:**
- Calculator: `Neto/App/Logic/Calculators/{Name}Calculator.swift`
- Helper: `Neto/App/Logic/Helpers/{Name}Helper.swift`

**New Utility:**
- Shared helpers: `Neto/Utils/{Name}.swift`

## Special Directories

**Neto/Seed/:**
- Purpose: Initial database data
- Contains: `CategorySeed.swift` - Default categories
- Committed: Yes

**Neto/Resources/:**
- Purpose: App resources
- Contains: Assets, localization strings
- Committed: Yes

---

*Structure analysis: 2026-01-15*
*Update when directory structure changes*
