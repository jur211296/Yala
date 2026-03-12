//
//  NeedTrendHelper.swift
//  Yala
//
//  Helper struct for need trend calculations.
//  Extracted from PanelViewModel to reduce God Class complexity.
//

import Foundation

/// Pure calculation helper for need trend widget data.
/// Contains no state - all methods are static.
struct NeedTrendHelper {

    /// Calculates need trend points by grouping transactions by date bucket.
    /// Categorizes expenses into essential, priority, optional, and unclassified.
    ///
    /// - Parameters:
    ///   - transactions: List of transactions to process (should be filtered for current view).
    ///   - grouping: The trend grouping (day, week, month).
    ///   - interval: The total date interval for the chart.
    ///   - preferredCurrency: The user's preferred currency.
    ///   - context: SwiftData context.
    /// - Returns: An array of `NeedTrendPoint` sorted by date.
    static func calculateTrend(
        transactions: [TransactionItem],
        grouping: TrendGrouping,
        interval: DateInterval,
        preferredCurrency: CurrencyCode,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [NeedTrendPoint] {
        // Group transactions by Date bucket
        var grouped: [Date: [TransactionItem]] = [:]
        let calendar = Calendar.current

        for tx in transactions {
            // Strict Filter:
            // 1. Exclude balance adjustments and transfers
            // 2. Must have a category
            // 3. Category must NOT be income (Excludes Incomes)
            guard tx.balanceAdjustmentType == nil else { continue }
            guard let category = tx.category, !category.isIncome else { continue }

            // Use TrendGrouping extension for consistent date bucketing
            let dateKey = grouping.dateKey(for: tx.date, calendar: calendar)

            grouped[dateKey, default: []].append(tx)
        }

        var points: [NeedTrendPoint] = []
        for (date, txs) in grouped {
            var essential: Double = 0
            var priority: Double = 0
            var optional: Double = 0
            var unclassified: Double = 0

            for tx in txs {
                // Convert amount to preferred currency
                let currencyCode = preferredCurrency.rawValue
                let doubleAmount: Double

                if tx.preferredCurrencyCode == currencyCode {
                    // Use signed amount
                    doubleAmount = tx.amountInPreferredCurrency
                } else {
                    let sourceCurrency =
                        CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                        ?? preferredCurrency

                    let convertedDecimal = converter.convert(
                        Decimal(abs(tx.amount)),
                        from: sourceCurrency.rawValue,
                        to: currencyCode,
                        on: tx.date
                    )
                    // Restore sign
                    let magnitude = (convertedDecimal as NSDecimalNumber).doubleValue
                    doubleAmount = (tx.amount < 0) ? -magnitude : magnitude
                }

                // Accumulate signed amount (Expenses usually negative, Refunds positive)
                let amount = doubleAmount

                let need = tx.subcategory?.need ?? .unclassified

                switch need {
                case .essential: essential += amount
                case .priority: priority += amount
                case .optional: optional += amount
                case .unclassified: unclassified += amount
                }
            }

            // Store ABSOLUTE magnitude for the chart (Expenses are negative total -> Positive height)
            points.append(
                NeedTrendPoint(
                    date: date,
                    essential: abs(essential),
                    priority: abs(priority),
                    optional: abs(optional),
                    unclassified: abs(unclassified)
                ))
        }

        return points.sorted { $0.date < $1.date }
    }
}
