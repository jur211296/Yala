//
//  CurrencyConverterTests.swift
//  YalaTests
//
//  Unit tests for CurrencyConverter.convertWithFallback (no ModelContext).
//

import Foundation
import Testing

@testable import Yala

struct CurrencyConverterTests {

    private let converter = CurrencyConverter.shared

    @Test func convertWithFallback_sameCurrency() {
        let result = converter.convertWithFallback(100, from: "PEN", to: "PEN")
        #expect(result == 100)
    }

    @Test func convertWithFallback_usdToPen_greaterThanOriginal() {
        let result = converter.convertWithFallback(100, from: "USD", to: "PEN")
        #expect(result > 100) // PEN is worth less than USD
    }

    @Test func convertWithFallback_penToUsd_lessThanOriginal() {
        let result = converter.convertWithFallback(100, from: "PEN", to: "USD")
        #expect(result < 100) // USD is worth more than PEN
    }

    @Test func convertWithFallback_crossCurrency_eurToPen() {
        let result = converter.convertWithFallback(100, from: "EUR", to: "PEN")
        #expect(result > 100) // EUR is stronger than PEN
    }

    @Test func convertWithFallback_zeroAmount() {
        let result = converter.convertWithFallback(0, from: "USD", to: "PEN")
        #expect(result == 0)
    }

    @Test func convertWithFallback_negativeAmount() {
        let result = converter.convertWithFallback(-100, from: "USD", to: "PEN")
        #expect(result < 0)
    }

    @Test func convertWithFallback_unknownCurrency_fallsBackToUSD() {
        // Unknown codes normalize to USD (fallbackCode)
        // So "XXX" → "USD", converting USD→PEN should give > 100
        let result = converter.convertWithFallback(100, from: "XXX", to: "PEN")
        #expect(result > 100)
    }

    @Test func convertWithFallback_caseNormalization() {
        let lower = converter.convertWithFallback(100, from: "pen", to: "PEN")
        #expect(lower == 100)
    }
}
