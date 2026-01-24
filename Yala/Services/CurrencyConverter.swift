//
//  CurrencyConverter.swift
//  Yala
//
//  Central converter for all currency conversions in the app.
//  Uses stored exchange rates from ExchangeRateService.
//

import Foundation
import SwiftData

// MARK: - Currency Converter

/// Central currency converter that uses stored exchange rates.
/// All conversions in the app should go through this class.
final class CurrencyConverter {

    // MARK: - Singleton

    static let shared = CurrencyConverter()

    // MARK: - Properties

    private let baseCurrency = "USD"

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // MARK: - Fallback Rates (used when no stored rate available)

    /// Static fallback rates for when API data is unavailable.
    /// These are approximate rates and should only be used as last resort.
    private let fallbackRates: [String: Double] = [
        "USD": 1.0,
        "PEN": 3.72,
        "EUR": 0.95,
        "MXN": 17.0,
        "COP": 4100.0,
        "BRL": 4.95,
        "GBP": 0.79,
    ]

    // MARK: - Public API

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
        return convert(amount, from: from, to: to, on: Date(), context: context)
    }

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
        date: Date = Date(),
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
            return nil
        }
    }
}
