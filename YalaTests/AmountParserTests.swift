//
//  AmountParserTests.swift
//  YalaTests
//
//  Unit tests for AmountParser (pure functions, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct AmountParserTests {

    // MARK: - Parentheses negative

    @Test func parse_parenthesesNegative() {
        let result = AmountParser.parse("($100.00)")
        #expect(result != nil)
        #expect(result!.amount == -100)
        #expect(result!.confidence == 0.95)
    }

    // MARK: - Explicit negative

    @Test func parse_explicitNegative() {
        let result = AmountParser.parse("-$50.00")
        #expect(result != nil)
        #expect(result!.amount == -50)
        #expect(result!.confidence == 0.95)
    }

    // MARK: - Currency symbols

    @Test func parse_dollarSign() {
        let result = AmountParser.parse("$1,234.56")
        #expect(result != nil)
        #expect(result!.amount == Decimal(string: "1234.56"))
        #expect(result!.confidence == 0.90)
    }

    @Test func parse_euroSign() {
        let result = AmountParser.parse("€100")
        #expect(result != nil)
        #expect(result!.amount == 100)
        #expect(result!.confidence == 0.90)
    }

    @Test func parse_poundSign() {
        let result = AmountParser.parse("£50.00")
        #expect(result != nil)
        #expect(result!.amount == 50)
        #expect(result!.confidence == 0.90)
    }

    // MARK: - Number formats

    @Test func parse_europeanFormat() {
        let result = AmountParser.parse("1.234,56")
        #expect(result != nil)
        #expect(result!.amount == Decimal(string: "1234.56"))
    }

    @Test func parse_simpleDecimal() {
        let result = AmountParser.parse("100.50")
        #expect(result != nil)
        #expect(result!.amount == Decimal(string: "100.50"))
    }

    @Test func parse_wholeNumber() {
        let result = AmountParser.parse("100")
        #expect(result != nil)
        #expect(result!.amount == 100)
    }

    // MARK: - Edge cases

    @Test func parse_noAmount() {
        let result = AmountParser.parse("hello")
        #expect(result == nil)
    }

    @Test func parse_negativeWithSpace() {
        let result = AmountParser.parse("- $50")
        #expect(result != nil)
        #expect(result!.amount == -50)
    }

    @Test func parse_zeroAmount() {
        let result = AmountParser.parse("$0.00")
        #expect(result != nil)
        #expect(result!.amount == 0)
    }

    @Test func parse_singleDigitRejected() {
        let result = AmountParser.parse("5")
        #expect(result == nil)
    }

    @Test func parse_europeanNoDecimal() {
        let result = AmountParser.parse("$1.234")
        #expect(result != nil)
        // With $ prefix, "1.234" is parsed as 1.234 (American format with 3 decimal places)
        // or 1234 (European thousands separator) — depends on parser logic
    }

    @Test func parse_largeNumber() {
        let result = AmountParser.parse("$99,999.99")
        #expect(result != nil)
        #expect(result!.amount == Decimal(string: "99999.99"))
    }

    @Test func parse_multipleAmounts_returnsFirst() {
        let result = AmountParser.parse("$100 y $200")
        #expect(result != nil)
        #expect(result!.amount == 100)
    }
}
