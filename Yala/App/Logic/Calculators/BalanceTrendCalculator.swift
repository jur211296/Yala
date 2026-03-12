//
//  BalanceTrendCalculator.swift
//  Yala
//
//  Created for Trend Chart logic.
//

import Foundation

struct BalanceTrendCalculator {
    static func calculateTrend(
        transactions: [TransactionItem],
        grouping: TrendGrouping,
        interval: DateInterval,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [ChartTransaction] {
        let calendar = Calendar.current
        var groupedData: [Date: (income: Double, expense: Double)] = [:]

        // 1. Accumulate data
        for tx in transactions {
            // Must have category
            guard let category = tx.category else { continue }

            // Amount conversion
            let val: Double
            if tx.preferredCurrencyCode == currencyCode {
                val = tx.amountInPreferredCurrency
            } else {
                let amountDecimal = Decimal(abs(tx.amount))
                let converted = converter.convert(
                    amountDecimal,
                    from: tx.currencyCode,
                    to: currencyCode,
                    on: tx.date
                )
                let magnitude = NSDecimalNumber(decimal: converted).doubleValue
                val = (tx.amount < 0) ? -magnitude : magnitude
            }

            let isIncome = category.isIncome
            let dateKey = grouping.dateKey(for: tx.date, calendar: calendar)

            var current = groupedData[dateKey] ?? (0.0, 0.0)
            if isIncome {
                current.income += val
            } else {
                // Store positive magnitude for expense
                current.expense += abs(val)
            }
            groupedData[dateKey] = current
        }

        // 2. Fill gaps and generate result with RUNNING BALANCE
        var result: [ChartTransaction] = []
        var currentDate = interval.start
        let component = grouping.calendarComponent
        var runningBalance: Double = 0.0  // Track cumulative balance

        while currentDate < interval.end {
            let keyDate = grouping.dateKey(for: currentDate, calendar: calendar)
            let values = groupedData[keyDate] ?? (0.0, 0.0)

            // For ChartTransaction:
            // income: positive (daily)
            // expense: positive magnitude (daily)
            // balance: RUNNING BALANCE (cumulative sum of income - expense)
            let dailyNet = values.income - values.expense
            runningBalance += dailyNet

            result.append(
                ChartTransaction(
                    id: UUID(),
                    date: keyDate,
                    income: values.income,
                    expense: values.expense,
                    balance: runningBalance  // Now cumulative!
                ))

            // Next Date
            guard let next = calendar.date(byAdding: component, value: 1, to: currentDate) else {
                break
            }
            currentDate = next
            if currentDate <= keyDate { break }  // Safety
        }

        return result.sorted { $0.date < $1.date }
    }
}
