//
//  TransactionsExportServiceTests.swift
//  YalaTests
//
//  Tests for TransactionsExportService pure logic methods:
//  csvEscaped, makeCSVData, makeExportData, applyInMemoryFilters.
//  These methods were extracted from private to internal for testability.
//

import Foundation
import Testing

@testable import Yala

struct TransactionsExportServiceTests {

    // MARK: - csvEscaped

    @Test func csvEscaped_emptyString_returnsEmpty() {
        #expect(TransactionsExportService.csvEscaped("") == "")
    }

    @Test func csvEscaped_simpleString_returnsUnchanged() {
        #expect(TransactionsExportService.csvEscaped("hello") == "hello")
    }

    @Test func csvEscaped_stringWithComma_wrapsInQuotes() {
        let result = TransactionsExportService.csvEscaped("hello, world")
        #expect(result == "\"hello, world\"")
    }

    @Test func csvEscaped_stringWithQuotes_doublesAndWraps() {
        let result = TransactionsExportService.csvEscaped("say \"hi\"")
        #expect(result == "\"say \"\"hi\"\"\"")
    }

    @Test func csvEscaped_stringWithNewline_wrapsInQuotes() {
        let result = TransactionsExportService.csvEscaped("line1\nline2")
        #expect(result == "\"line1\nline2\"")
    }

    @Test func csvEscaped_stringWithCarriageReturn_wrapsInQuotes() {
        let result = TransactionsExportService.csvEscaped("line1\rline2")
        #expect(result == "\"line1\rline2\"")
    }

    @Test func csvEscaped_stringWithCommaAndQuotes_handlesAll() {
        let result = TransactionsExportService.csvEscaped("a,\"b\"")
        #expect(result == "\"a,\"\"b\"\"\"")
    }

    @Test func csvEscaped_plainNumber_noQuotes() {
        #expect(TransactionsExportService.csvEscaped("42.50") == "42.50")
    }

    // MARK: - makeCSVData

    @Test @MainActor func makeCSVData_emptyTransactions_returnsOnlyHeader() {
        let columns = ExportColumns(activeColumns: [.date, .amount])
        let data = TransactionsExportService.makeCSVData(transactions: [], columns: columns)
        let string = extractCSVString(from: data)
        #expect(string == "date,amount")
    }

    @Test @MainActor func makeCSVData_singleTransaction_generatesCorrectRow() {
        let tx = TransactionItem(date: makeDate(2025, 3, 15), amount: -50.0, currencyCode: "USD")
        let columns = ExportColumns(activeColumns: [.date, .amount, .currency])
        let data = TransactionsExportService.makeCSVData(transactions: [tx], columns: columns)
        let lines = extractCSVLines(from: data)

        #expect(lines.count == 2)
        #expect(lines[0] == "date,amount,currency")
        #expect(lines[1].contains("2025-03-15"))
        #expect(lines[1].contains("-50.00"))
    }

    @Test @MainActor func makeCSVData_amountFormat_twoDecimals() {
        let tx = TransactionItem(date: Date(), amount: 100.0, currencyCode: "USD")
        let columns = ExportColumns(activeColumns: [.amount])
        let data = TransactionsExportService.makeCSVData(transactions: [tx], columns: columns)
        let lines = extractCSVLines(from: data)

        #expect(lines[1] == "100.00")
    }

    @Test @MainActor func makeCSVData_noteWithComma_escapesCorrectly() {
        let tx = TransactionItem(date: Date(), amount: 10.0, currencyCode: "USD")
        tx.note = "Groceries, bakery"
        let columns = ExportColumns(activeColumns: [.note])
        let data = TransactionsExportService.makeCSVData(transactions: [tx], columns: columns)
        let lines = extractCSVLines(from: data)

        #expect(lines[1] == "\"Groceries, bakery\"")
    }

    @Test @MainActor func makeCSVData_nilNote_emptyField() {
        let tx = TransactionItem(date: Date(), amount: 10.0, currencyCode: "USD")
        tx.note = nil
        let columns = ExportColumns(activeColumns: [.note])
        let data = TransactionsExportService.makeCSVData(transactions: [tx], columns: columns)
        let lines = extractCSVLines(from: data)

        #expect(lines[1] == "")
    }

    @Test @MainActor func makeCSVData_multipleTransactions_correctLineCount() {
        let txs = (1...5).map { i in
            TransactionItem(date: Date(), amount: Double(i) * 10, currencyCode: "USD")
        }
        let columns = ExportColumns(activeColumns: [.amount])
        let data = TransactionsExportService.makeCSVData(transactions: txs, columns: columns)
        let lines = extractCSVLines(from: data)

        #expect(lines.count == 6) // 1 header + 5 data
    }

    @Test @MainActor func makeCSVData_startsWithBOM() {
        let columns = ExportColumns(activeColumns: [.date])
        let data = TransactionsExportService.makeCSVData(transactions: [], columns: columns)

        // UTF-8 BOM: EF BB BF
        #expect(data.count >= 3)
        #expect(data[0] == 0xEF)
        #expect(data[1] == 0xBB)
        #expect(data[2] == 0xBF)
    }

    @Test @MainActor func makeCSVData_onlySelectedColumns_included() {
        let tx = TransactionItem(date: makeDate(2025, 1, 1), amount: 25.0, currencyCode: "EUR")
        tx.note = "Test"
        let columns = ExportColumns(activeColumns: [.amount, .note])
        let data = TransactionsExportService.makeCSVData(transactions: [tx], columns: columns)
        let lines = extractCSVLines(from: data)

        #expect(lines[0] == "amount,note")
        #expect(lines[1] == "25.00,Test")
    }

    // MARK: - makeExportData

    @Test @MainActor func makeExportData_emptyTransactions_returnsHeadersOnly() {
        let columns = ExportColumns(activeColumns: [.date, .amount, .currency])
        let (headers, rows) = TransactionsExportService.makeExportData(transactions: [], columns: columns)

        #expect(headers == ["date", "amount", "currency"])
        #expect(rows.isEmpty)
    }

    @Test @MainActor func makeExportData_singleTransaction_correctValues() {
        let tx = TransactionItem(date: makeDate(2025, 6, 20), amount: -75.50, currencyCode: "PEN")
        let columns = ExportColumns(activeColumns: [.date, .amount, .currency])
        let (headers, rows) = TransactionsExportService.makeExportData(transactions: [tx], columns: columns)

        #expect(headers.count == 3)
        #expect(rows.count == 1)
        #expect(rows[0][0] == "2025-06-20")
        #expect(rows[0][1] == "-75.50")
    }

    @Test @MainActor func makeExportData_noEscaping_rawValues() {
        let tx = TransactionItem(date: Date(), amount: 10.0, currencyCode: "USD")
        tx.note = "A, B, C"
        let columns = ExportColumns(activeColumns: [.note])
        let (_, rows) = TransactionsExportService.makeExportData(transactions: [tx], columns: columns)

        // makeExportData does NOT escape — it returns raw values (for XLSX)
        #expect(rows[0][0] == "A, B, C")
    }

    @Test @MainActor func makeExportData_respectsColumnOrder() {
        let tx = TransactionItem(date: Date(), amount: 1.0, currencyCode: "USD")
        // Note and Amount in "wrong" init order — should come out in default order
        let columns = ExportColumns(activeColumns: [.note, .amount])
        let (headers, _) = TransactionsExportService.makeExportData(transactions: [tx], columns: columns)

        #expect(headers == ["amount", "note"])
    }

    // MARK: - applyInMemoryFilters

    @Test @MainActor func applyInMemoryFilters_noFilters_returnsAll() {
        let txs = makeTransactions(count: 3)
        let filters = ExportFilters.default
        let result = TransactionsExportService.applyInMemoryFilters(txs, filters: filters)

        #expect(result.count == 3)
    }

    @Test @MainActor func applyInMemoryFilters_amountGreaterThan_filters() {
        let txs = [
            TransactionItem(date: Date(), amount: 50, currencyCode: "USD"),
            TransactionItem(date: Date(), amount: 150, currencyCode: "USD"),
            TransactionItem(date: Date(), amount: 200, currencyCode: "USD"),
        ]
        var filters = ExportFilters.default
        filters.amountCondition = .greaterThan(100)
        let result = TransactionsExportService.applyInMemoryFilters(txs, filters: filters)

        #expect(result.count == 2)
    }

    @Test @MainActor func applyInMemoryFilters_noteContains_filtersCorrectly() {
        let tx1 = TransactionItem(date: Date(), amount: 10, currencyCode: "USD")
        tx1.note = "Groceries at Walmart"
        let tx2 = TransactionItem(date: Date(), amount: 20, currencyCode: "USD")
        tx2.note = "Coffee shop"
        let tx3 = TransactionItem(date: Date(), amount: 30, currencyCode: "USD")
        tx3.note = nil

        var filters = ExportFilters.default
        filters.noteContains = "grocery"  // Case-insensitive partial match
        let result = TransactionsExportService.applyInMemoryFilters([tx1, tx2, tx3], filters: filters)

        // "Groceries" contains "grocery" (lowercased)
        // Wait — "groceries" does NOT contain "grocery" literally. Let me check the code.
        // The code does: noteText.contains(noteFilter) where both are lowercased
        // "groceries at walmart".contains("grocery") → false in Swift (it's "groceries" not "grocery")
        // Let's use "grocer" which will match
        filters.noteContains = "grocer"
        let result2 = TransactionsExportService.applyInMemoryFilters([tx1, tx2, tx3], filters: filters)
        #expect(result2.count == 1)
    }

    @Test @MainActor func applyInMemoryFilters_noteContains_caseInsensitive() {
        let tx = TransactionItem(date: Date(), amount: 10, currencyCode: "USD")
        tx.note = "COFFEE SHOP"
        var filters = ExportFilters.default
        filters.noteContains = "coffee"
        let result = TransactionsExportService.applyInMemoryFilters([tx], filters: filters)

        #expect(result.count == 1)
    }

    @Test @MainActor func applyInMemoryFilters_noteContains_emptyString_noFilter() {
        let tx = TransactionItem(date: Date(), amount: 10, currencyCode: "USD")
        tx.note = nil
        var filters = ExportFilters.default
        filters.noteContains = "  "  // whitespace-only → trimmed to empty → no filter
        let result = TransactionsExportService.applyInMemoryFilters([tx], filters: filters)

        #expect(result.count == 1)
    }

    @Test @MainActor func applyInMemoryFilters_amountBetween_inclusiveRange() {
        let txs = [
            TransactionItem(date: Date(), amount: 10, currencyCode: "USD"),
            TransactionItem(date: Date(), amount: 50, currencyCode: "USD"),
            TransactionItem(date: Date(), amount: 100, currencyCode: "USD"),
            TransactionItem(date: Date(), amount: 200, currencyCode: "USD"),
        ]
        var filters = ExportFilters.default
        filters.amountCondition = .between(min: 50, max: 100)
        let result = TransactionsExportService.applyInMemoryFilters(txs, filters: filters)

        #expect(result.count == 2)
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    @MainActor
    private func makeTransactions(count: Int) -> [TransactionItem] {
        (1...count).map { i in
            TransactionItem(date: Date(), amount: Double(i) * 10, currencyCode: "USD")
        }
    }

    private func extractCSVString(from data: Data) -> String {
        // Skip BOM (3 bytes)
        let csvData = data.count >= 3 ? data.dropFirst(3) : data
        return String(data: csvData, encoding: .utf8) ?? ""
    }

    private func extractCSVLines(from data: Data) -> [String] {
        extractCSVString(from: data).components(separatedBy: "\n")
    }
}
