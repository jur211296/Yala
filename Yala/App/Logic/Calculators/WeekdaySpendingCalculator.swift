//
//  WeekdaySpendingCalculator.swift
//  Yala
//
//  Groups expenses by weekday (1=Sunday through 7=Saturday) and returns totals.
//

import Foundation

struct WeekdaySpending: Identifiable, Equatable {
    let weekday: Int        // 1=Sunday ... 7=Saturday (Calendar weekday)
    let total: Double
    let count: Int          // Number of transactions
    let dayOccurrences: Int // How many times this weekday appears in the period

    var id: Int { weekday }

    /// Average spending per calendar day (e.g., per Monday), not per transaction
    var average: Double { dayOccurrences > 0 ? total / Double(dayOccurrences) : 0 }

    /// Localized short weekday name (Mon, Tue, etc.)
    var shortName: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1, weekday <= 7 else { return "" }
        return symbols[weekday - 1]
    }
}

struct WeekdaySpendingCalculator {

    /// Groups expense transactions by weekday and returns totals in preferred currency.
    /// Average is computed per calendar day occurrence (e.g., per Monday in the period).
    static func calculate(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
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
                let converted = converter.convert(
                    Decimal(abs(tx.amount)),
                    from: tx.currencyCode,
                    to: currencyCode,
                    on: tx.date
                )
                amount = NSDecimalNumber(decimal: converted).doubleValue
            }

            totals[weekday, default: 0] += amount
            counts[weekday, default: 0] += 1
        }

        // Count how many times each weekday occurs in the interval
        let occurrences = Self.weekdayOccurrences(in: interval)

        return (1...7).map { day in
            WeekdaySpending(
                weekday: day,
                total: totals[day, default: 0],
                count: counts[day, default: 0],
                dayOccurrences: occurrences[day, default: 0]
            )
        }
    }

    /// Counts how many times each weekday (1=Sun..7=Sat) appears in a date interval.
    static func weekdayOccurrences(in interval: DateInterval) -> [Int: Int] {
        let calendar = Calendar.current
        var occurrences: [Int: Int] = [:]
        let totalDays = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        let fullWeeks = totalDays / 7
        let remainder = totalDays % 7

        // Every weekday appears at least fullWeeks times
        for day in 1...7 {
            occurrences[day] = fullWeeks
        }

        // Add partial week
        var current = interval.start
        for _ in 0..<remainder {
            let weekday = calendar.component(.weekday, from: current)
            occurrences[weekday, default: 0] += 1
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return occurrences
    }
}
