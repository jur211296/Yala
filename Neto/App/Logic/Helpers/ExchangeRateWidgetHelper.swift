//
//  ExchangeRateWidgetHelper.swift
//  Neto
//
//  Helper struct for exchange rate widget calculations.
//  Extracted from PanelViewModel to reduce God Class complexity.
//

import Foundation
import SwiftData

/// Pure calculation helper for exchange rate widget data.
/// Contains no state - all methods are static or pure functions.
struct ExchangeRateWidgetHelper {

    /// Converts exchange rates to be expressed relative to the preferred currency.
    ///
    /// - Parameters:
    ///   - preferredCurrency: The currency code to convert to (e.g., "PEN").
    ///   - targetCurrencies: List of currency codes to compare against.
    ///   - exchangeRate: The source exchange rate data (base USD).
    /// - Returns: A dictionary where keys are currency codes and values are the rate relative to preferred currency.
    ///
    /// Example: If preferred is PEN (3.72/USD) and target is USD (1.0/USD):
    /// Returns ["USD": 3.72] meaning 1 USD = 3.72 PEN.
    static func calculateRatesFromPreferred(
        preferredCurrency: String,
        targetCurrencies: [String],
        exchangeRate: ExchangeRate
    ) -> [String: Double] {
        let rates = exchangeRate.decodedRates()

        // The stored rates are based on USD (e.g., USD=1, PEN=3.72, EUR=0.95)
        // This means: 1 USD = 3.72 PEN, 1 USD = 0.95 EUR
        // We need to express as: 1 targetCurrency = X preferredCurrency

        // Get the rate of the preferred currency (relative to USD)
        let preferredRate = rates[preferredCurrency] ?? (preferredCurrency == "USD" ? 1.0 : 0)

        guard preferredRate > 0 else { return [:] }

        var result: [String: Double] = [:]
        for currency in targetCurrencies where currency != preferredCurrency {
            // Get the target currency rate (relative to USD)
            let targetRate = rates[currency] ?? (currency == "USD" ? 1.0 : 0)

            guard targetRate > 0 else { continue }

            // Formula: 1 target = (preferredRate / targetRate) preferred
            // Example with preferred=PEN, target=USD:
            //   preferredRate = 3.72 (1 USD = 3.72 PEN)
            //   targetRate = 1.0 (1 USD = 1 USD)
            //   So: 1 USD = 3.72/1.0 = 3.72 PEN ✓
            // Example with preferred=PEN, target=EUR:
            //   preferredRate = 3.72
            //   targetRate = 0.95 (1 USD = 0.95 EUR)
            //   So: 1 EUR = 3.72/0.95 = 3.92 PEN ✓
            result[currency] = preferredRate / targetRate
        }
        return result
    }

    /// Builds the chart points for the exchange rate trend graph.
    ///
    /// - Parameters:
    ///   - interval: The date interval to cover.
    ///   - grouping: The granularity of data points (day, week, month).
    ///   - preferredCurrency: The user's preferred currency code.
    ///   - targetCurrencies: List of currencies to display in the chart.
    ///   - context: SwiftData context for fetching rates.
    /// - Returns: An array of `ExchangeRateChartPoint` ready for charting.
    static func buildChartPoints(
        interval: DateInterval,
        grouping: TrendGrouping,
        preferredCurrency: String,
        targetCurrencies: [String],
        context: ModelContext
    ) -> [ExchangeRateChartPoint] {
        let calendar = Calendar.current
        var points: [ExchangeRateChartPoint] = []

        // Generate date buckets based on grouping
        var currentDate = interval.start

        while currentDate <= interval.end {
            let bucketEnd: Date
            switch grouping {
            case .day:
                bucketEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .week:
                bucketEnd =
                    calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case .month:
                bucketEnd =
                    calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }

            // Get rates for this bucket (average if multiple days)
            let bucketRates = getAverageRatesForBucket(
                start: currentDate,
                end: min(bucketEnd, interval.end),
                preferredCurrency: preferredCurrency,
                targetCurrencies: targetCurrencies,
                context: context
            )

            if !bucketRates.isEmpty {
                points.append(ExchangeRateChartPoint(date: currentDate, rates: bucketRates))
            }

            currentDate = bucketEnd
        }

        return points
    }

    /// Gets average exchange rates for a date bucket.
    static func getAverageRatesForBucket(
        start: Date,
        end: Date,
        preferredCurrency: String,
        targetCurrencies: [String],
        context: ModelContext
    ) -> [String: Double] {
        let calendar = Calendar.current
        var allRates: [[String: Double]] = []

        // Use <= to include the end date when start == end (edge case for last bucket)
        let effectiveEnd = max(end, calendar.date(byAdding: .day, value: 1, to: start) ?? start)

        var currentDate = start
        while currentDate < effectiveEnd {
            // Try to get rate for this specific date
            if let rate = ExchangeRateService.shared.getRate(for: currentDate, context: context) {
                let convertedRates = calculateRatesFromPreferred(
                    preferredCurrency: preferredCurrency,
                    targetCurrencies: targetCurrencies,
                    exchangeRate: rate
                )
                if !convertedRates.isEmpty {
                    allRates.append(convertedRates)
                }
            } else if let fallbackRate = ExchangeRateService.shared.getMostRecentRate(
                onOrBefore: currentDate, context: context)
            {
                // Use fallback rate
                let convertedRates = calculateRatesFromPreferred(
                    preferredCurrency: preferredCurrency,
                    targetCurrencies: targetCurrencies,
                    exchangeRate: fallbackRate
                )
                if !convertedRates.isEmpty {
                    allRates.append(convertedRates)
                }
            }

            currentDate =
                calendar.date(byAdding: .day, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(86400)
        }

        // Calculate averages
        guard !allRates.isEmpty else { return [:] }

        var averages: [String: Double] = [:]
        for currency in targetCurrencies {
            let values = allRates.compactMap { $0[currency] }
            if !values.isEmpty {
                averages[currency] = values.reduce(0, +) / Double(values.count)
            }
        }

        return averages
    }
}
