//
//  MoneyParsingTests.swift
//  YalaTests
//
//  Unit tests for parseDecimal(from:) (pure function, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct MoneyParsingTests {

    @Test func parseDecimal_simpleInteger() {
        #expect(parseDecimal(from: "100") == 100)
    }

    @Test func parseDecimal_withDot() {
        #expect(parseDecimal(from: "1234.56") == Decimal(string: "1234.56"))
    }

    @Test func parseDecimal_americanFormat() {
        #expect(parseDecimal(from: "1,234.56") == Decimal(string: "1234.56"))
    }

    @Test func parseDecimal_europeanFormat() {
        #expect(parseDecimal(from: "1.234,56") == Decimal(string: "1234.56"))
    }

    @Test func parseDecimal_negativePrefijo() {
        #expect(parseDecimal(from: "-100") == -100)
    }

    @Test func parseDecimal_negativeSufijo() {
        #expect(parseDecimal(from: "100-") == -100)
    }

    @Test func parseDecimal_negativeParentesis() {
        #expect(parseDecimal(from: "(123.45)") == Decimal(string: "-123.45"))
    }

    @Test func parseDecimal_currencySymbolSoles() {
        #expect(parseDecimal(from: "S/ 100") == 100)
    }

    @Test func parseDecimal_currencySymbolDollar() {
        #expect(parseDecimal(from: "$1,234.56") == Decimal(string: "1234.56"))
    }

    @Test func parseDecimal_empty() {
        #expect(parseDecimal(from: "") == nil)
    }
}
