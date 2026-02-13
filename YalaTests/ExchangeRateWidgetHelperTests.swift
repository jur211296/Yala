//
//  ExchangeRateWidgetHelperTests.swift
//  YalaTests
//
//  Unit tests for ExchangeRateWidgetHelper.calculateRatesFromPreferred.
//  ExchangeRate created without ModelContext to avoid CloudKit race crashes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct ExchangeRateWidgetHelperTests {

    /// Create ExchangeRate without inserting into a ModelContext
    private func makePlainRate(rates: [String: Double]) throws -> ExchangeRate {
        try ExchangeRate(dateKey: "2026-01-15", base: "USD", ratesDictionary: rates)
    }

    @Test func calculateRates_penPreferred_usdTarget() throws {
        let rate = try makePlainRate(rates: ["PEN": 3.75, "USD": 1.0, "EUR": 0.92])
        let result = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: "PEN",
            targetCurrencies: ["USD"],
            exchangeRate: rate
        )
        // 1 USD = 3.75 PEN
        #expect(result["USD"] != nil)
        #expect(result["USD"]! > 3.0)
    }

    @Test func calculateRates_usdPreferred_penTarget() throws {
        let rate = try makePlainRate(rates: ["PEN": 3.75, "USD": 1.0, "EUR": 0.92])
        let result = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: "USD",
            targetCurrencies: ["PEN"],
            exchangeRate: rate
        )
        // 1 PEN = 1.0/3.75 USD ≈ 0.267
        #expect(result["PEN"] != nil)
        #expect(result["PEN"]! < 1.0)
    }

    @Test func calculateRates_excludesSameCurrency() throws {
        let rate = try makePlainRate(rates: ["PEN": 3.75, "USD": 1.0])
        let result = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: "PEN",
            targetCurrencies: ["PEN", "USD"],
            exchangeRate: rate
        )
        // Should not include PEN→PEN
        #expect(result["PEN"] == nil)
        #expect(result["USD"] != nil)
    }

    @Test func calculateRates_multipleTargets() throws {
        let rate = try makePlainRate(rates: ["PEN": 3.75, "USD": 1.0, "EUR": 0.92])
        let result = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: "PEN",
            targetCurrencies: ["USD", "EUR"],
            exchangeRate: rate
        )
        #expect(result.count == 2)
        #expect(result["USD"] != nil)
        #expect(result["EUR"] != nil)
    }
}
