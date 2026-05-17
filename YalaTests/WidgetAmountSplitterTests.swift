//
//  WidgetAmountSplitterTests.swift
//  YalaTests
//
//  Unit tests para `WidgetAmountSplitter.split(...)`. Pure-logic helper
//  compartido con el target widget vía pbxproj membership exception.
//

import Foundation
import Testing

@testable import Yala

struct WidgetAmountSplitterTests {

    @Test func positive_noDecimals_returnsIntegerAndNilDecimal() {
        let result = WidgetAmountSplitter.split(
            value: 1234,
            symbol: "$",
            fractionDigits: 0
        )
        #expect(result.symbol == "$")
        #expect(result.sign == "")
        #expect(result.integer == "1,234")
        #expect(result.decimal == nil)
    }

    @Test func positive_withDecimals_returnsIntegerAndDecimal() {
        let result = WidgetAmountSplitter.split(
            value: 1234.56,
            symbol: "$",
            fractionDigits: 2
        )
        #expect(result.symbol == "$")
        #expect(result.sign == "")
        #expect(result.integer == "1,234")
        #expect(result.decimal == "56")
    }

    @Test func negative_producesMinusSign() {
        let result = WidgetAmountSplitter.split(
            value: -1234.56,
            symbol: "$",
            fractionDigits: 2
        )
        #expect(result.sign == "-")
        #expect(result.integer == "1,234")
        #expect(result.decimal == "56")
    }

    @Test func forceSign_positive_producesPlus() {
        let result = WidgetAmountSplitter.split(
            value: 45.50,
            symbol: "S/",
            fractionDigits: 2,
            forceSign: true
        )
        #expect(result.sign == "+")
        #expect(result.integer == "45")
        #expect(result.decimal == "50")
    }

    @Test func forceSign_zero_noPlusSign() {
        let result = WidgetAmountSplitter.split(
            value: 0,
            symbol: "$",
            fractionDigits: 2,
            forceSign: true
        )
        #expect(result.sign == "")
        #expect(result.integer == "0")
        #expect(result.decimal == "00")
    }

    @Test func isEstimate_prefixesSymbolWithApprox() {
        let result = WidgetAmountSplitter.split(
            value: 1234,
            symbol: "$",
            fractionDigits: 0,
            isEstimate: true
        )
        #expect(result.symbol == "≈ $")
        #expect(result.sign == "")
        #expect(result.integer == "1,234")
    }

    @Test func zero_returnsZeroInteger() {
        let result = WidgetAmountSplitter.split(
            value: 0,
            symbol: "$",
            fractionDigits: 2
        )
        #expect(result.integer == "0")
        #expect(result.decimal == "00")
        #expect(result.sign == "")
    }

    @Test func localeCommaDecimal_handlesEsAR() {
        let result = WidgetAmountSplitter.split(
            value: 2266.37,
            symbol: "$",
            fractionDigits: 2,
            decimalSeparator: ","
        )
        // Con sep="," el formatter usa "." como thousands.
        #expect(result.integer == "2.266")
        #expect(result.decimal == "37")
    }

    @Test func jpyNoDecimals_returnsNilDecimal() {
        let result = WidgetAmountSplitter.split(
            value: 1234,
            symbol: "¥",
            fractionDigits: 0
        )
        #expect(result.symbol == "¥")
        #expect(result.integer == "1,234")
        #expect(result.decimal == nil)
    }

    @Test func accessibilityFormat_isCanonical() {
        // Valida el formato canónico: "<≈ optional><sign><symbol> <number>"
        // Alineado con CurrencyFormattingHelper del app principal.
        let result = WidgetAmountSplitter.split(
            value: -1234.56,
            symbol: "$",
            fractionDigits: 2,
            forceSign: true,
            isEstimate: true
        )
        #expect(result.accessibilityFormatted == "≈ -$ 1,234.56")
    }

    @Test func largeNumber_includesThousandsSeparator() {
        let result = WidgetAmountSplitter.split(
            value: 1_234_567.89,
            symbol: "S/",
            fractionDigits: 2
        )
        #expect(result.integer == "1,234,567")
        #expect(result.decimal == "89")
    }

    @Test func symbolPassesThroughVerbatim() {
        // El splitter NO conoce currencies — usa el symbol como recibió.
        let result = WidgetAmountSplitter.split(
            value: 100,
            symbol: "PEN",
            fractionDigits: 0
        )
        #expect(result.symbol == "PEN")
        #expect(result.integer == "100")
    }
}
