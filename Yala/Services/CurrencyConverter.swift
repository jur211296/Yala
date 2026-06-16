//
//  CurrencyConverter.swift
//  Yala
//
//  Central converter for all currency conversions in the app.
//  Uses stored exchange rates from ExchangeRateService.
//

import Foundation
import Observation
import SwiftData
import os.lock

// MARK: - Notification

extension Notification.Name {
    /// Posted by ExchangeRateService after persisting fresh today's exchange rates.
    /// Subscribers should invalidate any cached "latest rate" data and reload UI.
    static let yalaExchangeRatesUpdated = Notification.Name("yalaExchangeRatesUpdated")
}

// MARK: - Currency Converting Protocol

/// Protocol for currency conversion without ModelContext dependency.
/// Enables dependency injection and testing of calculators/helpers.
protocol CurrencyConverting {
    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal
}

// MARK: - Currency Converter

/// Central currency converter that uses stored exchange rates.
/// All conversions in the app should go through this class.
/// Supports @Environment injection in SwiftUI views.
@MainActor
@Observable
final class CurrencyConverter: CurrencyConverting {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    /// `nonisolated`: lets nonisolated pure-logic calculators/helpers reference it as a default
    /// argument (`converter: CurrencyConverting = CurrencyConverter.shared`). The conversion path
    /// is already engineered for cross-actor reads (lock-protected rates cache).
    nonisolated static let shared = CurrencyConverter()

    /// `nonisolated` initializer so the `nonisolated` `shared` singleton can be constructed off
    /// any actor. Every stored property has a default (or is optional → nil) and none require the
    /// main actor, so an empty nonisolated init is sound.
    nonisolated init() {}

    // MARK: - Properties

    @ObservationIgnored private var modelContext: ModelContext?
    private let baseCurrency = "USD"

    /// Thread-safe cache of latest exchange rates (TC actual). Read on every
    /// `convertWithLatestRate` to avoid hitting SwiftData per call. Invalidated
    /// cuando `ExchangeRateService` persiste rates frescos (via
    /// `.yalaExchangeRatesUpdated`) y al cambiar de día (sin esa invalidación
    /// implícita, una sesión que cruza medianoche seguiría usando los rates
    /// del día anterior aunque `Date.now` ya apunte a uno nuevo).
    @ObservationIgnored
    private let latestRatesCache = OSAllocatedUnfairLock<CachedRates?>(initialState: nil)

    private struct CachedRates {
        let rates: [String: Double]
        let dayKey: String  // dateKey (yyyy-MM-dd UTC) usado para la lectura
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Fallback Rates (used when no stored rate available)

    /// Static fallback rates for when API data is unavailable.
    /// IMPORTANT: These are APPROXIMATE rates and should only be used
    /// as a last resort when: no API data, no internet, and no cached rates.
    /// All rates are relative to USD (base currency).
    /// Derived from CurrencyCode enum (single source of truth).
    private var fallbackRates: [String: Double] { CurrencyCode.fallbackRates }

    // MARK: - Context Setup

    /// Sets the ModelContext for database-backed conversions.
    /// Called from AppBootstrapper during app initialization.
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - CurrencyConverting (context-free)

    /// Converts using the stored ModelContext, falling back to static rates if unavailable.
    func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
        guard let context = modelContext else {
            return convertWithFallback(amount, from: from, to: to)
        }
        return convert(amount, from: from, to: to, on: date, context: context)
    }

    /// Converts using the most recent available rate (context-free).
    func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
        guard let context = modelContext else {
            return convertWithFallback(amount, from: from, to: to)
        }
        return convertWithLatestRate(amount, from: from, to: to, context: context)
    }

    // MARK: - Public API (with context)

    /// Converts an amount from one currency to another using the rate for a specific date.
    /// - Parameters:
    ///   - amount: The amount to convert
    ///   - from: Source currency code (will be normalized)
    ///   - to: Target currency code (will be normalized)
    ///   - date: The date to use for the exchange rate
    ///   - context: SwiftData ModelContext for fetching rates
    /// - Returns: The converted amount
    func convert(
        _ amount: Decimal,
        from: String,
        to: String,
        on date: Date,
        context: ModelContext
    ) -> Decimal {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        // Same currency, no conversion needed
        if fromCode == toCode {
            return amount
        }

        // Get rates for the date
        let rates = getRatesForDate(date, context: context)

        return performConversion(amount: amount, from: fromCode, to: toCode, rates: rates)
    }

    /// Converts using the most recent available rate (for "today" calculations).
    /// Uses an in-memory cache invalidated by `.yalaExchangeRatesUpdated` to
    /// avoid SwiftData fetches on every call (LiveBalanceCalculator does
    /// M conversions per render).
    /// - Parameters:
    ///   - amount: The amount to convert
    ///   - from: Source currency code
    ///   - to: Target currency code
    ///   - context: SwiftData ModelContext
    /// - Returns: The converted amount
    func convertWithLatestRate(
        _ amount: Decimal,
        from: String,
        to: String,
        context: ModelContext
    ) -> Decimal {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return amount
        }

        let rates = cachedLatestRates(context: context)
        return performConversion(amount: amount, from: fromCode, to: toCode, rates: rates)
    }

    /// Invalidates the latest-rates cache. Call after `ExchangeRateService`
    /// persists fresh rates so subsequent conversions read updated data.
    /// `nonisolated`: only touches the thread-safe `OSAllocatedUnfairLock`, so it is safe to
    /// call from anywhere — including the `@Sendable` `.yalaExchangeRatesUpdated` observer.
    nonisolated func invalidateLatestRatesCache() {
        latestRatesCache.withLock { $0 = nil }
    }

    #if DEBUG
    /// Test-only accessor for cache state. Avoids flaky NotificationCenter
    /// integration tests by allowing direct inspection.
    var _testCacheState: [String: Double]? {
        latestRatesCache.withLock { $0?.rates }
    }
    #endif

    /// Synchronous conversion using fallback rates (no database access).
    /// Use this only when ModelContext is not available (e.g., in static calculators).
    /// Will be deprecated once all calculators are updated to use async version.
    func convertWithFallback(
        _ amount: Decimal,
        from: String,
        to: String
    ) -> Decimal {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return amount
        }

        return performConversion(amount: amount, from: fromCode, to: toCode, rates: fallbackRates)
    }

    /// Gets the exchange rate between two currencies for display purposes.
    /// Returns format: "1 FROM = X.XX TO"
    func getDisplayRate(
        from: String,
        to: String,
        date: Date = Date.now,
        context: ModelContext
    ) -> Double? {
        let fromCode = normalizeCurrencyCode(from)
        let toCode = normalizeCurrencyCode(to)

        if fromCode == toCode {
            return 1.0
        }

        let rates = getRatesForDate(date, context: context)

        guard let fromRate = rates[fromCode], let toRate = rates[toCode] else {
            return nil
        }

        // Convert 1 unit of 'from' to 'to'
        // If base is USD: 1 FROM in USD = 1 / fromRate
        // Then to 'to': (1 / fromRate) * toRate
        if fromCode == baseCurrency {
            return toRate
        } else if toCode == baseCurrency {
            return fromRate > 0 ? 1.0 / fromRate : nil
        } else {
            return fromRate > 0 ? toRate / fromRate : nil
        }
    }

    /// Checks if an exact exchange rate exists for a specific date.
    /// Used to determine if a transaction's exchange rate is provisional (fallback) or official.
    /// - Parameters:
    ///   - date: The date to check
    ///   - context: SwiftData ModelContext
    /// - Returns: true if an exact rate exists for the date, false if using fallback
    func hasExactRate(for date: Date, context: ModelContext) -> Bool {
        let dateKey = dateFormatter.string(from: date)
        return fetchExchangeRate(for: dateKey, context: context) != nil
    }

    // MARK: - Private Helpers

    private func getRatesForDate(_ date: Date, context: ModelContext) -> [String: Double] {
        let dateKey = dateFormatter.string(from: date)

        // Try exact date first
        if let exactRate = fetchExchangeRate(for: dateKey, context: context) {
            return exactRate.decodedRates()
        }

        // Fall back to most recent rate before the date
        if let fallbackRate = fetchMostRecentRate(onOrBefore: dateKey, context: context) {
            return fallbackRate.decodedRates()
        }

        // Last resort: use static fallback rates
        return fallbackRates
    }

    /// Returns latest rates from cache or fetches and caches them on miss.
    /// Lock-protected for thread-safety (CurrencyConverter is a singleton
    /// reachable from any actor; cache must be safe for concurrent reads).
    private func cachedLatestRates(context: ModelContext) -> [String: Double] {
        let now = Date.now
        let todayKey = dateFormatter.string(from: now)
        if let cached = latestRatesCache.withLock({ $0 }), cached.dayKey == todayKey {
            return cached.rates
        }
        let rates = getRatesForDate(now, context: context)
        latestRatesCache.withLock { $0 = CachedRates(rates: rates, dayKey: todayKey) }
        return rates
    }

    private func performConversion(
        amount: Decimal,
        from fromCode: String,
        to toCode: String,
        rates: [String: Double]
    ) -> Decimal {
        guard let fromRate = rates[fromCode], let toRate = rates[toCode] else {
            // If rates not available, return original amount
            return amount
        }

        guard fromRate > 0 else {
            return amount
        }

        // Convert to base currency (USD), then to target currency
        // Rate represents: 1 USD = X currency
        // So: amountInUSD = amount / fromRate
        // Then: amountInTarget = amountInUSD * toRate

        if fromCode == baseCurrency {
            // Direct: amount * toRate
            return amount * Decimal(toRate)
        } else if toCode == baseCurrency {
            // Direct: amount / fromRate
            return amount / Decimal(fromRate)
        } else {
            // Cross conversion through USD
            let amountInBase = amount / Decimal(fromRate)
            return amountInBase * Decimal(toRate)
        }
    }

    private func fetchExchangeRate(for dateKey: String, context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            #if DEBUG
            print("CurrencyConverter: Error fetching rate: \(error)")
            #endif
            return nil
        }
    }

    private func fetchMostRecentRate(onOrBefore dateKey: String, context: ModelContext)
        -> ExchangeRate?
    {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey <= dateKey },
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )

        do {
            var limitedDescriptor = descriptor
            limitedDescriptor.fetchLimit = 1
            let results = try context.fetch(limitedDescriptor)
            return results.first
        } catch {
            #if DEBUG
            print("CurrencyConverter: Error fetching fallback rate: \(error)")
            #endif
            return nil
        }
    }
}
