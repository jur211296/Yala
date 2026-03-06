//
//  WeekdaySpendingCalculator.swift
//  Yala
//
//  Groups expenses by weekday (1=Sunday through 7=Saturday) and returns totals.
//

import Foundation
import SwiftData

struct WeekdaySpending: Identifiable {
    let weekday: Int        // 1=Sunday ... 7=Saturday (Calendar weekday)
    let total: Double
    let count: Int

    var id: Int { weekday }

    /// Localized short weekday name (Mon, Tue, etc.)
    var shortName: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1, weekday <= 7 else { return "" }
        return symbols[weekday - 1]
    }
}

struct WeekdaySpendingCalculator {

    /// Groups expense transactions by weekday and returns totals in preferred currency.
    /// - Parameters:
    ///   - transactions: Filtered expense transactions (already filtered by period/filters)
    ///   - currencyCode: Target currency code for conversion
    ///   - context: ModelContext for currency conversion
    /// - Returns: Array of 7 WeekdaySpending entries (one per weekday), sorted by Calendar weekday
    static func calculate(
        transactions: [TransactionItem],
        currencyCode: String,
        context: ModelContext
    ) -> [WeekdaySpending] {
        let calendar = Calendar.current
        var totals: [Int: Double] = [:]
        var counts: [Int: Int] = [:]

        for tx in transactions {
            guard let category = tx.category, !category.isIncome else { continue }
            guard tx.balanceAdjustmentType == nil else { continue }

            let weekday = calendar.component(.weekday, from: tx.date)

            let amount: Double
            if tx.preferredCurrencyCode == currencyCode {
                amount = abs(tx.amountInPreferredCurrency)
            } else {
                let converted = CurrencyConverter.shared.convert(
                    Decimal(abs(tx.amount)),
                    from: tx.currencyCode,
                    to: currencyCode,
                    on: tx.date,
                    context: context
                )
                amount = NSDecimalNumber(decimal: converted).doubleValue
            }

            totals[weekday, default: 0] += amount
            counts[weekday, default: 0] += 1
        }

        // Return all 7 weekdays
        return (1...7).map { day in
            WeekdaySpending(
                weekday: day,
                total: totals[day, default: 0],
                count: counts[day, default: 0]
            )
        }
    }
}
