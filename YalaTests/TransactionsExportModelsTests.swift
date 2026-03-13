//
//  TransactionsExportModelsTests.swift
//  YalaTests
//
//  Tests for export-related models: ExportColumns, AmountFilterCondition,
//  ExportFormat, ExportColumn. All pure logic, no SwiftData needed.
//

import Foundation
import Testing

@testable import Yala

struct TransactionsExportModelsTests {

    // MARK: - AmountFilterCondition.matches

    @Test func amountFilter_any_matchesEverything() {
        let condition = AmountFilterCondition.any
        #expect(condition.matches(0))
        #expect(condition.matches(100))
        #expect(condition.matches(-50))
        #expect(condition.matches(Decimal(string: "999999.99")!))
    }

    @Test func amountFilter_greaterThan_matchesAboveThreshold() {
        let condition = AmountFilterCondition.greaterThan(100)
        #expect(condition.matches(101) == true)
        #expect(condition.matches(100) == false)
        #expect(condition.matches(99) == false)
        #expect(condition.matches(Decimal(string: "100.01")!) == true)
    }

    @Test func amountFilter_lessThan_matchesBelowThreshold() {
        let condition = AmountFilterCondition.lessThan(50)
        #expect(condition.matches(49) == true)
        #expect(condition.matches(50) == false)
        #expect(condition.matches(51) == false)
        #expect(condition.matches(-10) == true)
    }

    @Test func amountFilter_between_matchesInclusive() {
        let condition = AmountFilterCondition.between(min: 10, max: 100)
        #expect(condition.matches(10) == true)   // min inclusive
        #expect(condition.matches(100) == true)  // max inclusive
        #expect(condition.matches(50) == true)   // middle
        #expect(condition.matches(9) == false)   // below
        #expect(condition.matches(101) == false)  // above
    }

    @Test func amountFilter_between_singleValue() {
        let condition = AmountFilterCondition.between(min: 42, max: 42)
        #expect(condition.matches(42) == true)
        #expect(condition.matches(41) == false)
        #expect(condition.matches(43) == false)
    }

    // MARK: - AmountFilterCondition.isActive

    @Test func amountFilter_isActive_anyIsFalse() {
        #expect(AmountFilterCondition.any.isActive == false)
    }

    @Test func amountFilter_isActive_othersAreTrue() {
        #expect(AmountFilterCondition.greaterThan(10).isActive == true)
        #expect(AmountFilterCondition.lessThan(10).isActive == true)
        #expect(AmountFilterCondition.between(min: 1, max: 100).isActive == true)
    }

    // MARK: - AmountFilterCondition.displayText

    @Test func amountFilter_displayText_anyIsEmpty() {
        #expect(AmountFilterCondition.any.displayText == "")
    }

    @Test func amountFilter_displayText_greaterThan() {
        let text = AmountFilterCondition.greaterThan(100).displayText
        #expect(text.contains(">"))
        #expect(text.contains("100"))
    }

    @Test func amountFilter_displayText_lessThan() {
        let text = AmountFilterCondition.lessThan(50).displayText
        #expect(text.contains("<"))
        #expect(text.contains("50"))
    }

    @Test func amountFilter_displayText_between() {
        let text = AmountFilterCondition.between(min: 10, max: 500).displayText
        #expect(text.contains("10"))
        #expect(text.contains("500"))
        #expect(text.contains("-"))
    }

    // MARK: - ExportColumns

    @Test func exportColumns_default_hasAllColumns() {
        let columns = ExportColumns.default
        #expect(columns.hasAtLeastOneActiveColumn == true)
        #expect(columns.orderedActiveColumns.count == ExportColumn.allCases.count)
    }

    @Test func exportColumns_empty_hasNoActiveColumn() {
        let columns = ExportColumns(activeColumns: [])
        #expect(columns.hasAtLeastOneActiveColumn == false)
        #expect(columns.orderedActiveColumns.isEmpty)
        #expect(columns.csvHeaderTitles.isEmpty)
    }

    @Test func exportColumns_activateDeactivate_togglesColumn() {
        var columns = ExportColumns(activeColumns: [.date, .amount])
        #expect(columns.orderedActiveColumns.count == 2)

        columns.deactivate(.amount)
        #expect(columns.orderedActiveColumns == [.date])

        columns.activate(.note)
        #expect(columns.orderedActiveColumns == [.date, .note])
    }

    @Test func exportColumns_set_activatesAndDeactivates() {
        var columns = ExportColumns(activeColumns: [.date])

        columns.set(.currency, isActive: true)
        #expect(columns.orderedActiveColumns.contains(.currency))

        columns.set(.date, isActive: false)
        #expect(!columns.orderedActiveColumns.contains(.date))
    }

    @Test func exportColumns_orderedActiveColumns_respectsDefaultOrder() {
        // Activate columns in reverse order; they should come out in default order.
        let columns = ExportColumns(activeColumns: [.note, .tags, .date, .amount])
        let ordered = columns.orderedActiveColumns
        #expect(ordered == [.date, .amount, .tags, .note])
    }

    @Test func exportColumns_csvHeaderTitles_matchColumnOrder() {
        let columns = ExportColumns(activeColumns: [.date, .category, .amount])
        let titles = columns.csvHeaderTitles
        #expect(titles == ["date", "amount", "category"])
    }

    // MARK: - ExportColumn properties

    @Test func exportColumn_csvHeaderTitles_areLowercase() {
        for column in ExportColumn.allCases {
            #expect(column.csvHeaderTitle == column.csvHeaderTitle.lowercased())
        }
    }

    @Test func exportColumn_displayName_notEmpty() {
        for column in ExportColumn.allCases {
            #expect(!column.displayName.isEmpty)
        }
    }

    @Test func exportColumn_id_equalsRawValue() {
        for column in ExportColumn.allCases {
            #expect(column.id == column.rawValue)
        }
    }

    // MARK: - ExportFormat

    @Test func exportFormat_allCases_containsCsvAndXlsx() {
        let cases = ExportFormat.allCases
        #expect(cases.contains(.csv))
        #expect(cases.contains(.xlsx))
    }

    @Test func exportFormat_fileExtension_matchesRawValue() {
        #expect(ExportFormat.csv.fileExtension == "csv")
        #expect(ExportFormat.xlsx.fileExtension == "xlsx")
    }

    @Test func exportFormat_displayName_notEmpty() {
        for format in ExportFormat.allCases {
            #expect(!format.displayName.isEmpty)
        }
    }

    // MARK: - TransactionsExportError

    @Test func exportError_invalidCustomDateRange_hasDescription() {
        let error = TransactionsExportError.invalidCustomDateRange
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test func exportError_noTransactionsToExport_hasDescription() {
        let error = TransactionsExportError.noTransactionsToExport
        #expect(error.errorDescription != nil)
    }

    @Test func exportError_fileWriteFailed_hasDescription() {
        let underlying = NSError(domain: "test", code: 1)
        let error = TransactionsExportError.fileWriteFailed(underlying: underlying)
        #expect(error.errorDescription != nil)
    }

    // MARK: - ExportFilters default

    @Test func exportFilters_default_hasEmptySelections() {
        let filters = ExportFilters.default
        #expect(filters.selectedAccounts.isEmpty)
        #expect(filters.selectedCategories.isEmpty)
        #expect(filters.selectedSubcategories.isEmpty)
        #expect(filters.selectedTagNames.isEmpty)
        #expect(filters.selectedCurrencies.isEmpty)
        #expect(filters.amountCondition == .any)
        #expect(filters.noteContains == nil)
        #expect(filters.isExcludeMode == false)
    }

    @Test func exportFilters_effectiveDateInterval_returnsValidInterval() {
        let filters = ExportFilters.default
        let interval = filters.effectiveDateInterval()
        #expect(interval.start <= interval.end)
    }
}

/*
Tests generated:
1. amountFilter_any_matchesEverything - any always matches
2. amountFilter_greaterThan_matchesAboveThreshold - strict greater than
3. amountFilter_lessThan_matchesBelowThreshold - strict less than
4. amountFilter_between_matchesInclusive - inclusive range
5. amountFilter_between_singleValue - edge case: min == max
6. amountFilter_isActive_anyIsFalse - any is not active
7. amountFilter_isActive_othersAreTrue - filters are active
8. amountFilter_displayText_anyIsEmpty - no text for any
9. amountFilter_displayText_greaterThan - shows > symbol
10. amountFilter_displayText_lessThan - shows < symbol
11. amountFilter_displayText_between - shows range
12. exportColumns_default_hasAllColumns - default has all 8
13. exportColumns_empty_hasNoActiveColumn - empty set
14. exportColumns_activateDeactivate_togglesColumn - toggle behavior
15. exportColumns_set_activatesAndDeactivates - set helper
16. exportColumns_orderedActiveColumns_respectsDefaultOrder - ordering
17. exportColumns_csvHeaderTitles_matchColumnOrder - CSV header generation
18. exportColumn_csvHeaderTitles_areLowercase - consistent casing
19. exportColumn_displayName_notEmpty - localized names exist
20. exportColumn_id_equalsRawValue - Identifiable conformance
21. exportFormat_allCases_containsCsvAndXlsx - enum completeness
22. exportFormat_fileExtension_matchesRawValue - file extensions
23. exportFormat_displayName_notEmpty - display names
24. exportError_invalidCustomDateRange_hasDescription - error desc
25. exportError_noTransactionsToExport_hasDescription - error desc
26. exportError_fileWriteFailed_hasDescription - error desc
27. exportFilters_default_hasEmptySelections - default state
28. exportFilters_effectiveDateInterval_returnsValidInterval - date range

Cases NOT covered (require ModelContext):
- TransactionsExportService.exportToCSV() (fetches data from context)
- TransactionsExportService.export() (fetches data from context)
- applyInMemoryFilters() (private, operates on TransactionItem objects)
- makeCSVData() (private, operates on TransactionItem objects)
- csvEscaped() (private)
*/
