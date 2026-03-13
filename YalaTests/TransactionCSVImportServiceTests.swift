//
//  TransactionCSVImportServiceTests.swift
//  YalaTests
//
//  Tests for TransactionCSVImportService pure logic:
//  - normalizeCurrencyInput (public static)
//  - ImportError descriptions
//  - ImportColumn raw values
//
//  NOTE: importCSV(), importXLSX(), scanCurrencies() and validateAndCreateDraft()
//  require ModelContext and are NOT tested here. Those need integration tests.
//

import Foundation
import Testing

@testable import Yala

struct TransactionCSVImportServiceTests {

    // MARK: - normalizeCurrencyInput

    @Test func normalizeCurrency_PEN_variants() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("PEN") == "PEN")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("pen") == "PEN")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("S/") == "PEN")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("S/.") == "PEN")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("S") == "PEN")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("PEN.") == "PEN")
    }

    @Test func normalizeCurrency_USD_variants() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("USD") == "USD")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("usd") == "USD")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("$") == "USD")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("US$") == "USD")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("USD.") == "USD")
    }

    @Test func normalizeCurrency_EUR_variants() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("EUR") == "EUR")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("eur") == "EUR")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("\u{20AC}") == "EUR") // €
        #expect(TransactionCSVImportService.normalizeCurrencyInput("EUR.") == "EUR")
    }

    @Test func normalizeCurrency_otherCodes_uppercase() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("gbp") == "GBP")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("JPY") == "JPY")
        #expect(TransactionCSVImportService.normalizeCurrencyInput("brl") == "BRL")
    }

    @Test func normalizeCurrency_emptyString_returnsEmpty() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("") == "")
    }

    @Test func normalizeCurrency_whitespace_returnsEmpty() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("   ") == "")
    }

    @Test func normalizeCurrency_withWhitespacePadding_trimmed() {
        #expect(TransactionCSVImportService.normalizeCurrencyInput("  USD  ") == "USD")
        #expect(TransactionCSVImportService.normalizeCurrencyInput(" PEN ") == "PEN")
    }

    // MARK: - ImportError descriptions

    @Test func importError_invalidFileExtension_hasDescription() {
        let error = ImportError.invalidFileExtension
        #expect(error.errorDescription != nil)
        #expect(!error.errorDescription!.isEmpty)
    }

    @Test func importError_unreadableFile_hasDescription() {
        let error = ImportError.unreadableFile
        #expect(error.errorDescription != nil)
    }

    @Test func importError_emptyFile_hasDescription() {
        let error = ImportError.emptyFile
        #expect(error.errorDescription != nil)
    }

    @Test func importError_invalidHeader_includesFoundValue() {
        let error = ImportError.invalidHeader(found: "col1,col2,col3")
        #expect(error.errorDescription?.contains("col1,col2,col3") == true)
    }

    @Test func importError_invalidColumnCount_includesDetails() {
        let error = ImportError.invalidColumnCount(row: 5, expected: 7, found: 4)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("5"))
        #expect(desc.contains("7"))
        #expect(desc.contains("4"))
    }

    @Test func importError_invalidDate_includesRowAndValue() {
        let error = ImportError.invalidDate(row: 3, value: "not-a-date")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("3"))
        #expect(desc.contains("not-a-date"))
    }

    @Test func importError_invalidAmount_includesRowAndValue() {
        let error = ImportError.invalidAmount(row: 7, value: "abc")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("7"))
        #expect(desc.contains("abc"))
    }

    @Test func importError_currencyMismatch_includesBothCurrencies() {
        let error = ImportError.currencyMismatchWithAccount(
            row: 2, fileCurrency: "USD", accountCurrency: "PEN"
        )
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("USD"))
        #expect(desc.contains("PEN"))
    }

    // MARK: - ImportColumn raw values

    @Test func importColumn_rawValues_matchExpected() {
        #expect(ImportColumn.date.rawValue == "date")
        #expect(ImportColumn.amount.rawValue == "amount")
        #expect(ImportColumn.currency.rawValue == "currency")
        #expect(ImportColumn.category.rawValue == "category")
        #expect(ImportColumn.subcategory.rawValue == "subcategory")
        #expect(ImportColumn.tags.rawValue == "tags")
        #expect(ImportColumn.note.rawValue == "note")
    }
}

/*
Tests generated:
1. normalizeCurrency_PEN_variants - PEN and its synonyms (S/, S/., S)
2. normalizeCurrency_USD_variants - USD and its synonyms ($, US$)
3. normalizeCurrency_EUR_variants - EUR and its synonyms (euro sign)
4. normalizeCurrency_otherCodes_uppercase - unknown codes get uppercased
5. normalizeCurrency_emptyString_returnsEmpty - empty input
6. normalizeCurrency_whitespace_returnsEmpty - whitespace-only input
7. normalizeCurrency_withWhitespacePadding_trimmed - trimming
8. importError_invalidFileExtension_hasDescription - error desc exists
9. importError_unreadableFile_hasDescription - error desc exists
10. importError_emptyFile_hasDescription - error desc exists
11. importError_invalidHeader_includesFoundValue - found value in desc
12. importError_invalidColumnCount_includesDetails - row/expected/found
13. importError_invalidDate_includesRowAndValue - row and value in desc
14. importError_invalidAmount_includesRowAndValue - row and value
15. importError_currencyMismatch_includesBothCurrencies - currencies in desc
16. importColumn_rawValues_matchExpected - enum raw values

Cases NOT covered (require ModelContext):
- importCSV() full flow (reads file, validates, creates transactions)
- importXLSX() full flow
- importCSVMultiCurrency() full flow
- scanCurrencies() (reads file)
- validateAndCreateDraft() (resolves categories via context)
- parseDate() (private)
- normalizeAmountString() (private)
- detectDelimiter() (private)
- splitCSVIntoRows() (private)
*/
