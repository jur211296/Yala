# Codebase Concerns

**Analysis Date:** 2026-01-15

## Tech Debt

**Hardcoded API Key Fallback:**
- Issue: Fallback API key `c06401ad1af737edd8345b27b5304c36` exposed in source
- File: `Neto/Services/ExchangeRateAPIService.swift:75`
- Why: Quick fallback during development
- Impact: Security vulnerability; key can be compromised
- Fix approach: Remove hardcoded key; require `Secrets.xcconfig` configuration

**DispatchQueue Instead of Task API:**
- Issue: Old-style `DispatchQueue.main.asyncAfter()` with hardcoded delays
- Files:
  - `Neto/App/Views/Statistics/DetailContainerView.swift` (2 instances)
  - `Neto/App/Views/Import/ImportIntroSheet.swift` (7 instances)
  - `Neto/App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift` (3 instances)
  - `Neto/App/Views/Profile/ProfileView.swift` (1 instance)
- Impact: Less efficient, harder to cancel, mixing async paradigms
- Fix approach: Replace with `Task` API and `try? await Task.sleep()`

**Debug Print Statements in Production:**
- Issue: 37 print statements found, many without `#if DEBUG` guards
- Files:
  - `Neto/Services/ExchangeRateAPIService.swift` (3 prints)
  - `Neto/Services/BackgroundJobs.swift` (1 print)
  - `Neto/App/Views/Import/ImportIntroSheet.swift` (7 prints)
  - `Neto/App/Views/Statistics/DetailContainerView.swift` (4 prints)
- Impact: Performance overhead; potential data leakage
- Fix approach: Remove or guard with `#if DEBUG`

## Known Bugs

**None explicitly identified in code comments.**

Potential issues observed:
- Exchange rate fallback may silently return stale data
- Background budget check not implemented (see Incomplete Features)

## Security Considerations

**API Key Exposure:**
- Risk: Hardcoded fallback API key in source code
- File: `Neto/Services/ExchangeRateAPIService.swift:75`
- Current mitigation: Key is for free tier API
- Recommendations: Remove entirely; fail gracefully if `Secrets.xcconfig` missing

**No Input Validation in Forms:**
- Risk: Invalid data entering SwiftData
- Files: `Neto/App/Views/Accounts/AccountFormView.swift`, `Neto/App/Views/Planning/BudgetEditorView.swift`
- Current mitigation: None detected
- Recommendations: Add length limits, character validation

## Performance Bottlenecks

**Large View Files with Heavy Calculations:**
- Problem: Complex calculations happening during view rendering
- Files and lines:
  - `Neto/App/Views/Statistics/TrendsTabView.swift` (1,193 lines)
  - `Neto/App/Views/Statistics/CategoriesTabView.swift` (1,188 lines)
  - `Neto/App/ViewModels/PanelViewModel.swift` (970 lines)
- Cause: Mixed UI and business logic; multiple `@onChange` handlers
- Improvement path: Extract calculations to services; add debouncing

**Excessive State Observers:**
- Problem: 8+ `.onChange` handlers in single views
- File: `Neto/App/Views/Statistics/TrendsTabView.swift:87-130`
- Cause: Each filter change triggers full recalculation
- Improvement path: Consolidate filters; debounce heavy operations

## Fragile Areas

**App Initialization:**
- File: `Neto/App/NetoApp.swift:38`
- Why fragile: `fatalError()` on ModelContainer failure
- Common failures: SwiftData corruption, migration issues
- Safe modification: Add graceful error handling with recovery UI
- Test coverage: None

**CSV Import Service:**
- File: `Neto/Utils/TransactionCSVImportService.swift` (733 lines)
- Why fragile: Complex parsing, multiple file formats, no tests
- Common failures: Malformed dates, invalid amounts, encoding issues
- Safe modification: Add comprehensive unit tests first
- Test coverage: None

## Scaling Limits

**SwiftData Performance:**
- Current capacity: Unknown (local-only app)
- Limit: Large transaction volumes may slow queries
- Symptoms at limit: UI lag, slow filtering
- Scaling path: Add pagination, optimize `@Query` predicates

## Dependencies at Risk

**CoreXLSX:**
- Risk: External dependency for Excel import
- Impact: If unmaintained, Excel import breaks
- Migration plan: Could fallback to CSV-only import

## Missing Critical Features

**Budget Monitoring:**
- Problem: TODO in `Neto/Services/BackgroundJobs.swift:24`
- Status: Background task runs but doesn't check budget thresholds
- Current workaround: None
- Blocks: No proactive budget alerts

**Alias Functionality:**
- Problem: TODO in `Neto/App/Views/Profile/PersonalDetailsView.swift:214`
- Status: UI placeholder exists, feature incomplete
- Current workaround: None
- Blocks: Future personalization feature

## Test Coverage Gaps

**CSV Import Service:**
- What's not tested: `TransactionCSVImportService` (733 lines)
- File: `Neto/Utils/TransactionCSVImportService.swift`
- Risk: Silent data corruption during import
- Priority: High
- Difficulty to test: Need fixtures for various CSV formats

**ViewModels:**
- What's not tested: Most ViewModels (PanelViewModel, StatisticsViewModel, etc.)
- Risk: State management bugs undetected
- Priority: Medium
- Difficulty to test: Need SwiftData mocking strategy

**Exchange Rate Service:**
- What's not tested: `ExchangeRateService`, `CurrencyConverter`
- Files: `Neto/Services/ExchangeRateService.swift`, `Neto/Services/CurrencyConverter.swift`
- Risk: Incorrect currency conversions
- Priority: High
- Difficulty to test: Need mock API responses

**Overall Metrics:**
- Total test lines: ~388
- Test files: 6 with meaningful tests
- Source files: 149 Swift files
- Coverage: Estimated <10%

## SwiftData Concerns

**Missing Inverse Relationships:**
- Issue: `TransactionItem` relationships don't have explicit inverses
- File: `Neto/Models/TransactionItem.swift`
- Impact: Orphaned records possible; cascade delete unclear
- Recommendation: Add inverse relationships or `.deleteRule(.cascade)`

**Migration Strategy - Partially Addressed:**
- Issue: No version tracking or migration handlers documented
- File: `Neto/App/NetoApp.swift:16-40`
- Impact: Future schema changes risky
- Recent: `Tag.iconName` added with default `"tag.fill"` for safe migration
- Recommendation: Document formal migration approach for future changes

**Provisional Exchange Rate Flag:**
- Issue: `isExchangeRateProvisional` set but no UI indicator
- File: `Neto/Models/TransactionItem.swift:33`
- Impact: Users unaware rates may be estimates
- Recommendation: Show visual indicator for provisional rates

**Tag-Budget Relationship:**
- Status: ✅ Implemented (2026-01-15)
- Relationship: Many-to-many via `budgets: [Budget]` in Tag
- No cascade delete issues detected

---

*Concerns audit: 2026-01-15*
*Update as issues are fixed or new ones discovered*
