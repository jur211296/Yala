//
//  CurrencyConverterCacheTests.swift
//  YalaTests
//
//  Tests síncronos del cache de `latestRates` en `CurrencyConverter`.
//  Evita NotificationCenter (flaky) usando el accesor _testCacheState
//  expuesto solo en builds DEBUG.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct CurrencyConverterCacheTests {

    // MARK: - Helpers

    /// Crea un ModelContext aislado con un ExchangeRate "hoy" persistido,
    /// suficiente para que `convertWithLatestRate` encuentre rates.
    private func makeContextWithTodayRate() throws -> ModelContext {
        let schema = Schema([ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let todayKey = dateFormatter.string(from: Date.now)

        let rate = try ExchangeRate(
            dateKey: todayKey,
            base: "USD",
            ratesDictionary: ["USD": 1.0, "PEN": 3.5, "EUR": 0.92]
        )
        context.insert(rate)
        try context.save()

        return context
    }

    // MARK: - Tests

    @Test func convertWithLatestRate_populatesCache() throws {
        let converter = CurrencyConverter()
        let context = try makeContextWithTodayRate()

        // Estado inicial: cache vacío.
        #expect(converter._testCacheState == nil)

        // Primera llamada: poblará el cache.
        _ = converter.convertWithLatestRate(
            Decimal(100), from: "USD", to: "PEN", context: context
        )

        #expect(converter._testCacheState != nil)
        #expect(converter._testCacheState?["PEN"] == 3.5)
    }

    @Test func invalidateLatestRatesCache_clearsCache() throws {
        let converter = CurrencyConverter()
        let context = try makeContextWithTodayRate()

        // Poblamos el cache.
        _ = converter.convertWithLatestRate(
            Decimal(100), from: "USD", to: "PEN", context: context
        )
        #expect(converter._testCacheState != nil)

        // Invalidamos.
        converter.invalidateLatestRatesCache()

        #expect(converter._testCacheState == nil)
    }

    @Test func convertWithLatestRate_reusesCacheAcrossCalls() throws {
        let converter = CurrencyConverter()
        let context = try makeContextWithTodayRate()

        let first = converter.convertWithLatestRate(
            Decimal(100), from: "USD", to: "PEN", context: context
        )
        let cacheAfterFirst = converter._testCacheState

        let second = converter.convertWithLatestRate(
            Decimal(200), from: "USD", to: "PEN", context: context
        )
        let cacheAfterSecond = converter._testCacheState

        // Mismas rates, solo se "fetchearon" una vez (la cache no cambió de identidad
        // de contenido).
        #expect(cacheAfterFirst?["PEN"] == cacheAfterSecond?["PEN"])
        // Resultado matemático coherente: segundo es exactamente 2x el primero.
        #expect(second == first * 2)
    }
}
