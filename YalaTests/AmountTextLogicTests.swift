//
//  AmountTextLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para los 2 helpers static de `AmountText`:
//  - `splitFormatted` — parsea el output del formatter en 4 runs visuales.
//  - `symbolFontStyle` — decide (size, weight) del symbol según Size + displayFormat.
//
//  Sin SwiftUI, sin SwiftData, sin singletons. Cubre casos límite (estimate,
//  locale con coma decimal, garbage input) y los 4 ejes del formato.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

struct AmountTextLogicTests {

    // MARK: - splitFormatted

    @Test func split_positiveUSD_returnsSymbolIntegerDecimal() {
        let result = AmountText.splitFormatted("$ 2,266.37", identifier: "$", decimalSeparator: ".")
        #expect(result.symbol == "$")
        #expect(result.sign == "")
        #expect(result.integer == "2,266")
        #expect(result.decimal == "37")
    }

    @Test func split_negative_putsSignBeforeInteger() {
        let result = AmountText.splitFormatted("$ -1,234.56", identifier: "$", decimalSeparator: ".")
        #expect(result.symbol == "$")
        #expect(result.sign == "-")
        #expect(result.integer == "1,234")
        #expect(result.decimal == "56")
    }

    @Test func split_forceSignPositive_putsPlusBeforeInteger() {
        let result = AmountText.splitFormatted("$ +1,234.56", identifier: "$", decimalSeparator: ".")
        #expect(result.symbol == "$")
        #expect(result.sign == "+")
        #expect(result.integer == "1,234")
        #expect(result.decimal == "56")
    }

    @Test func split_zeroDecimals_returnsNilDecimal() {
        let result = AmountText.splitFormatted("¥ 1,234", identifier: "¥", decimalSeparator: ".")
        #expect(result.symbol == "¥")
        #expect(result.sign == "")
        #expect(result.integer == "1,234")
        #expect(result.decimal == nil)
    }

    @Test func split_localeCommaDecimal_handlesEsAR() {
        let result = AmountText.splitFormatted("S/ 2.266,37", identifier: "S/", decimalSeparator: ",")
        #expect(result.symbol == "S/")
        #expect(result.sign == "")
        #expect(result.integer == "2.266")
        #expect(result.decimal == "37")
    }

    @Test func split_estimatePrefix_keepsApproxInSymbolRun() {
        let result = AmountText.splitFormatted("≈ $ 1,234.56", identifier: "$", decimalSeparator: ".")
        #expect(result.symbol == "≈ $")
        #expect(result.sign == "")
        #expect(result.integer == "1,234")
        #expect(result.decimal == "56")
    }

    @Test func split_codeMode_treatsThreeLetterAsSymbol() {
        let result = AmountText.splitFormatted("PEN 2,266.37", identifier: "PEN", decimalSeparator: ".")
        #expect(result.symbol == "PEN")
        #expect(result.sign == "")
        #expect(result.integer == "2,266")
        #expect(result.decimal == "37")
    }

    @Test func split_zeroValue_returnsZeroInteger() {
        let result = AmountText.splitFormatted("$ 0.00", identifier: "$", decimalSeparator: ".")
        #expect(result.symbol == "$")
        #expect(result.sign == "")
        #expect(result.integer == "0")
        #expect(result.decimal == "00")
    }

    @Test func split_garbageInput_returnsGracefulFallback() {
        let result = AmountText.splitFormatted("foo", identifier: "$", decimalSeparator: ".")
        #expect(result.symbol == "$")
        #expect(result.sign == "")
        #expect(result.integer == "foo")
        #expect(result.decimal == nil)
    }

    @Test func split_negativeCodeMode_returnsBothSeparate() {
        let result = AmountText.splitFormatted("PEN -2,266.37", identifier: "PEN", decimalSeparator: ".")
        #expect(result.symbol == "PEN")
        #expect(result.sign == "-")
        #expect(result.integer == "2,266")
        #expect(result.decimal == "37")
    }

    // MARK: - symbolFontStyle

    @Test func symbolFontStyle_heroSymbolMode_returns20Regular() {
        let style = AmountText.symbolFontStyle(for: .hero, displayFormat: .symbol)
        #expect(style.size == 20)
        #expect(style.weight == .regular)
    }

    @Test func symbolFontStyle_heroCodeMode_returns24Medium() {
        let style = AmountText.symbolFontStyle(for: .hero, displayFormat: .code)
        #expect(style.size == 24)
        #expect(style.weight == .medium)
    }

    @Test func symbolFontStyle_kpiCodeMode_isLargerThanSymbol() {
        let symbolStyle = AmountText.symbolFontStyle(for: .kpi, displayFormat: .symbol)
        let codeStyle = AmountText.symbolFontStyle(for: .kpi, displayFormat: .code)
        #expect(codeStyle.size > symbolStyle.size)
        #expect(codeStyle.weight == .medium)
    }
}
