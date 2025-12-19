//
//  BalanceTrendCalculator.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

struct BalanceTrendCalculator {
    /// Calculates trend data for the chart.
    /// Note: This version calculates "Period Balance" (Net Income - Net Expense) cumulatively within the filtered set.
    /// It does not account for previous historical balance unless provided (current signature usually expects just period data).
    static func calculateTrend(
        transactions: [TransactionItem],
        grouping: TrendGrouping,
        interval: DateInterval,
        currencyCode: String,
        context: ModelContext
    ) -> [ChartTransaction] {

        let calendar = Calendar.current
        var points: [ChartTransaction] = []

        // Group by Date component based on grouping
        let grouped = Dictionary(grouping: transactions) { tx -> Date in
            switch grouping {
            case .day:
                return calendar.startOfDay(for: tx.date)
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: tx.date)?.start
                    ?? calendar.startOfDay(for: tx.date)
            case .month:
                return calendar.dateInterval(of: .month, for: tx.date)?.start
                    ?? calendar.startOfDay(for: tx.date)
            }
        }

        // Accumulator for "Running Balance" during this period
        // Note: Real balance would need specific account Initial Balance + History.
        // Here we track the "Trend" of the filtered transactions (flow).
        var runningBalance: Double = 0

        // Generate date stride
        // Determine step
        let component: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        var currentDate = interval.start
        // Align start date to grouping if needed?
        // Assuming interval.start is already aligned or we just iterate.

        while currentDate < interval.end {
            let nextDate =
                calendar.date(byAdding: component, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(86400)

            // Find txs in this bucket
            // Since we grouped by start date, we can lookup.
            // Need robust date key matching.

            // Allow for some slack or normalize currentDate to same start logic
            let keyDate: Date = {
                switch grouping {
                case .day: return calendar.startOfDay(for: currentDate)
                case .week:
                    return calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start
                        ?? currentDate
                case .month:
                    return calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
                }
            }()

            let txs = grouped[keyDate] ?? []

            var income: Double = 0
            var expense: Double = 0

            for tx in txs {
                let absAmt = abs(tx.amount)
                let decimalAmt = Decimal(absAmt)

                // Convert using the transaction's date for accurate historical rate
                let converted = CurrencyConverter.shared.convert(
                    decimalAmt,
                    from: tx.currencyCode,
                    to: currencyCode,
                    on: tx.date,
                    context: context
                )
                let val = NSDecimalNumber(decimal: converted).doubleValue

                // Determine type
                // isIncome logic: (cat.isIncome) OR (amount >= 0 if no cat? usually strict expense/income in Neto)
                let isIncome = tx.category?.isIncome ?? (tx.amount >= 0)

                if isIncome {
                    income += val
                    runningBalance += val
                } else {
                    expense += val
                    runningBalance -= val
                }
            }

            points.append(
                ChartTransaction(
                    id: UUID(),
                    date: currentDate,
                    income: income,
                    expense: expense,
                    balance: runningBalance
                ))

            currentDate = nextDate
        }

        return points
    }
}
