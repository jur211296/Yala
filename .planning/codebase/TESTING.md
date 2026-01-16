# Testing Patterns

**Analysis Date:** 2026-01-15

## Test Framework

**Runner:**
- Swift Testing framework (new `@Test` macro)
- XCTest for UI tests

**Assertion Library:**
- `#expect()` macro (Swift Testing)
- `XCTAssert*` for legacy/UI tests

**Run Commands:**
```bash
# Via Xcode
xcodebuild -scheme Neto -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:NetoTests

# UI Tests
xcodebuild -scheme Neto -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test -only-testing:NetoUITests
```

## Test File Organization

**Location:**
- Unit tests: `NetoTests/` directory
- UI tests: `NetoUITests/` directory
- Co-located with project (not with source files)

**Naming:**
- Unit tests: `{Feature}Tests.swift`
- UI tests: `{Feature}UITests.swift`

**Structure:**
```
NetoTests/
├── NetoTests.swift              # Placeholder (empty)
├── CalculatorTests.swift        # Business logic tests
├── FilterServiceTests.swift     # Filter service tests
├── TrendGroupingTests.swift     # Grouping helper tests
├── TrendProcessingTests.swift   # Trend processing tests
└── TagTests.swift               # Tag model static methods (added 2026-01-15)

NetoUITests/
├── NetoUITests.swift            # Main UI tests
└── FinariaUITestsLaunchTests.swift  # Launch performance
```

## Test Structure

**Suite Organization (Swift Testing):**
```swift
import Testing
@testable import Neto

struct FilterServiceTests {

    // MARK: - FilterCriteria Tests

    @Test func emptyCriteriaHasNoActiveFilters() throws {
        // arrange
        let criteria = FilterCriteria.empty

        // assert
        #expect(!criteria.hasActiveFilters)
        #expect(criteria.activeFilterCount == 0)
    }

    // MARK: - FilterService Static Methods

    @Test func groupByDateGroupsCorrectly() throws {
        // test code
    }
}
```

**Patterns:**
- Use `struct` for test suites (Swift Testing)
- Group with `// MARK: -` comments
- Descriptive test function names
- One focus per test (multiple `#expect` OK)

## Mocking

**Current Approach:**
- Protocol-based dependency injection
- Example: `ExchangeRateProviderProtocol` allows mock rates

**Patterns:**
```swift
// Protocol for abstraction
protocol ExchangeRateProviderProtocol {
    func fetchLiveRates(...) async throws -> [String: Double]
}

// Service accepts protocol
class ExchangeRateService {
    private let provider: ExchangeRateProviderProtocol
}

// Test can inject mock
struct MockExchangeRateProvider: ExchangeRateProviderProtocol {
    func fetchLiveRates(...) async throws -> [String: Double] {
        return ["USD": 1.0, "EUR": 0.92]
    }
}
```

**What to Mock:**
- External APIs (ExchangeRateAPIService)
- File system operations
- Date/time (use fixed dates in tests)

**What NOT to Mock:**
- Pure calculators
- Simple utilities
- SwiftData models (test with in-memory container)

## Fixtures and Factories

**Test Data:**
```swift
// Inline in test
@Test("CashFlow grouping ensures correct monthly buckets")
func cashFlowMonthlyGrouping() {
    // Given
    let grouping = TrendGrouping.month
    let calendar = Calendar.current
    let date = Date()

    // When
    let bucketStart = grouping.dateKey(for: date, calendar: calendar)

    // Then
    let expectedStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
    #expect(bucketStart == expectedStart)
}
```

**Date Fixtures:**
```swift
let components = DateComponents(year: 2024, month: 12, day: 24, hour: 14, minute: 30)
let date = calendar.date(from: components)!
```

**Location:**
- Factory functions: inline in test file
- No separate fixtures directory

## Coverage

**Requirements:**
- No enforced coverage target
- Coverage tracked for awareness
- Focus on critical paths

**Current Coverage:**
- 7 test files with meaningful tests
- ~460 lines total test code
- Main gaps: Import service, ViewModels, ExchangeRateService

**Untested Critical Areas:**
- `TransactionCSVImportService` (733 lines, complex parsing)
- `ExchangeRateService` (currency conversion)
- `PanelViewModel` (970 lines)
- ViewModels in general

## Test Types

**Unit Tests:**
- Test single function/method in isolation
- Mock external dependencies
- Fast execution (<100ms per test)
- Examples: `CalculatorTests.swift`, `FilterServiceTests.swift`

**Integration Tests:**
- Not currently implemented
- Would test: SwiftData operations, service chains

**UI Tests:**
- Location: `NetoUITests/`
- Framework: XCTest with XCUIApplication
- Current: Launch performance tests only

## Common Patterns

**Given/When/Then Structure:**
```swift
@Test("Balance trend grouping handles daily buckets")
func balanceTrendDailyGrouping() {
    // Given
    let grouping = TrendGrouping.day
    let date = Date()

    // When
    let key = grouping.dateKey(for: date, calendar: Calendar.current)

    // Then
    #expect(key != nil)
}
```

**Async Testing:**
```swift
@Test func asyncOperation() async throws {
    let result = await service.fetchData()
    #expect(result.count > 0)
}
```

**Error Testing:**
```swift
@Test func throwsOnInvalidInput() throws {
    #expect(throws: ValidationError.self) {
        try validate(invalidData)
    }
}
```

**Test Descriptions:**
```swift
@Test("Moving Average calculates correctly")
func movingAverageCalculation() { }

@Test("YDomain for Expense starts at 0")
func yDomainExpenseStartsAtZero() { }
```

## UI Test Setup

**Launch Tests:**
```swift
final class FinariaUITestsLaunchTests: XCTestCase {
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
```

**App Interaction:**
```swift
final class NetoUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testNavigateToStatistics() throws {
        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.navigationBars["Statistics"].exists)
    }
}
```

---

*Testing analysis: 2026-01-15*
*Update when test patterns change*
