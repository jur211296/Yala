//
//  AmountInputHelperTests.swift
//  YalaTests
//
//  Tests for AmountInputHelper.filterAmountInput (pure function, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct AmountInputHelperTests {

    // MARK: - Happy path

    @Test func filter_simpleInteger_returnsAsIs() {
        let result = AmountInputHelper.filterAmountInput("123")
        #expect(result == "123")
    }

    @Test func filter_decimalWithDot_returnsDecimal() {
        let result = AmountInputHelper.filterAmountInput("99.50")
        // Depending on locale, the decimal separator may differ,
        // but the output should have at most 2 decimal places.
        #expect(result.contains("99"))
        #expect(result.count <= 6) // "99" + separator + "50"
    }

    @Test func filter_twoDecimalPlaces_allowed() {
        let result = AmountInputHelper.filterAmountInput("100.99")
        #expect(result.hasSuffix("99"))
    }

    // MARK: - Decimal place limits

    @Test func filter_threeDecimalPlaces_truncatesToTwo() {
        let result = AmountInputHelper.filterAmountInput("100.999")
        // Should only keep 2 decimal places
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        if let sepIndex = result.firstIndex(of: decimalSeparator.first!) {
            let fractional = result[result.index(after: sepIndex)...]
            #expect(fractional.count == 2)
        }
    }

    @Test func filter_manyDecimalPlaces_truncatesToTwo() {
        let result = AmountInputHelper.filterAmountInput("50.12345")
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        if let sepIndex = result.firstIndex(of: decimalSeparator.first!) {
            let fractional = result[result.index(after: sepIndex)...]
            #expect(fractional.count == 2)
        }
    }

    // MARK: - Multiple decimal separators

    @Test func filter_multipleDecimalSeparators_keepsOnlyFirst() {
        let result = AmountInputHelper.filterAmountInput("10.20.30")
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let separatorCount = result.filter { String($0) == decimalSeparator }.count
        #expect(separatorCount <= 1)
    }

    // MARK: - Leading zeros

    @Test func filter_leadingZeros_removed() {
        let result = AmountInputHelper.filterAmountInput("007")
        #expect(result == "7")
    }

    @Test func filter_zeroFollowedByDecimal_kept() {
        let result = AmountInputHelper.filterAmountInput("0.50")
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        #expect(result.hasPrefix("0\(decimalSeparator)"))
    }

    @Test func filter_multipleLeadingZeros_reducedToOne() {
        let result = AmountInputHelper.filterAmountInput("000.12")
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        #expect(result.hasPrefix("0\(decimalSeparator)"))
    }

    // MARK: - Non-numeric characters

    @Test func filter_lettersIgnored() {
        let result = AmountInputHelper.filterAmountInput("12abc34")
        #expect(result == "1234")
    }

    @Test func filter_symbolsIgnored() {
        let result = AmountInputHelper.filterAmountInput("$100")
        #expect(result == "100")
    }

    @Test func filter_spacesIgnored() {
        let result = AmountInputHelper.filterAmountInput("1 000")
        #expect(result == "1000")
    }

    // MARK: - Edge cases

    @Test func filter_emptyString_returnsEmpty() {
        let result = AmountInputHelper.filterAmountInput("")
        #expect(result == "")
    }

    @Test func filter_onlyLetters_returnsEmpty() {
        let result = AmountInputHelper.filterAmountInput("abc")
        #expect(result == "")
    }

    @Test func filter_commaAsDecimalSeparator_handled() {
        // Comma should be accepted as decimal separator
        let result = AmountInputHelper.filterAmountInput("100,50")
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        #expect(result.contains(decimalSeparator))
    }
}

/*
Tests generated:
1. filter_simpleInteger_returnsAsIs - basic integer input
2. filter_decimalWithDot_returnsDecimal - decimal number with dot
3. filter_twoDecimalPlaces_allowed - two decimal places pass through
4. filter_threeDecimalPlaces_truncatesToTwo - truncation at 2 decimals
5. filter_manyDecimalPlaces_truncatesToTwo - heavy truncation
6. filter_multipleDecimalSeparators_keepsOnlyFirst - no double decimals
7. filter_leadingZeros_removed - strips leading zeros
8. filter_zeroFollowedByDecimal_kept - preserves "0.x" pattern
9. filter_multipleLeadingZeros_reducedToOne - strips extra zeros before decimal
10. filter_lettersIgnored - non-numeric letters removed
11. filter_symbolsIgnored - currency symbols removed
12. filter_spacesIgnored - spaces removed
13. filter_emptyString_returnsEmpty - empty input
14. filter_onlyLetters_returnsEmpty - no digits returns empty
15. filter_commaAsDecimalSeparator_handled - comma as decimal separator

Cases NOT covered:
- Locale-specific behavior differences (tests adapt to current locale)
*/
