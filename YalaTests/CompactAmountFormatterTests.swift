//
//  CompactAmountFormatterTests.swift
//  YalaTests
//
//  Unit tests for CompactAmountFormatter (compact amount strings, no currency symbol).
//

import Foundation
import Testing

@testable import Yala

struct CompactAmountFormatterTests {
    private let en = Locale(identifier: "en_US")
    private let es = Locale(identifier: "es_ES")

    @Test func zero() {
        #expect(CompactAmountFormatter.string(0, locale: en) == "0")
    }

    @Test func belowThousand_isInteger() {
        #expect(CompactAmountFormatter.string(85, locale: en) == "85")
        #expect(CompactAmountFormatter.string(340, locale: en) == "340")
        #expect(CompactAmountFormatter.string(999, locale: en) == "999")
    }

    @Test func thousands_oneDecimal() {
        #expect(CompactAmountFormatter.string(1234, locale: en) == "1.2k")
        #expect(CompactAmountFormatter.string(1500, locale: en) == "1.5k")
    }

    @Test func thousands_trimsTrailingZero() {
        #expect(CompactAmountFormatter.string(1000, locale: en) == "1k")
        #expect(CompactAmountFormatter.string(12000, locale: en) == "12k")
    }

    @Test func millions() {
        #expect(CompactAmountFormatter.string(1_000_000, locale: en) == "1M")
        #expect(CompactAmountFormatter.string(1_200_000, locale: en) == "1.2M")
    }

    @Test func magnitude_ignoresSign() {
        #expect(CompactAmountFormatter.string(-1234, locale: en) == "1.2k")
    }

    @Test func localizedDecimalSeparator() {
        // Español usa coma como separador decimal.
        #expect(CompactAmountFormatter.string(1234, locale: es) == "1,2k")
    }
}
