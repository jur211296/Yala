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
            return grouping.dateKey(for: tx.date, calendar: calendar)
        }

        // Accumulator for "Running Balance" during this period
        // Note: Real balance would need specific account Initial Balance + History.
        // Here we track the "Trend" of the filtered transactions (flow).
        var runningBalance: Double = 0

        // Generate date stride
        let component = grouping.calendarComponent

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
            let keyDate = grouping.dateKey(for: currentDate, calendar: calendar)

            let txs = grouped[keyDate] ?? []

            var income: Double = 0
            var expense: Double = 0

            for tx in txs {
                // Strict Filter:
                // Must have a category (excludes Transfers)
                guard let category = tx.category else { continue }

                let absAmt = abs(tx.amount)
                let decimalAmt = Decimal(absAmt)

                // Convert using the transaction's date for accurate historical rate
                let val: Double
                if tx.preferredCurrencyCode == currencyCode {
                    // Use signed amount
                    val = tx.amountInPreferredCurrency
                } else {
                    let converted = CurrencyConverter.shared.convert(
                        decimalAmt,
                        from: tx.currencyCode,
                        to: currencyCode,
                        on: tx.date,
                        context: context
                    )
                    // Restore sign from original amount
                    let magnitude = NSDecimalNumber(decimal: converted).doubleValue
                    val = (tx.amount < 0) ? -magnitude : magnitude
                }

                if category.isIncome {
                    income += val
                    runningBalance += val
                } else {
                    expense += val
                    runningBalance += val  // Expense is negative, so adding it reduces balance
                }
            }

            points.append(
                ChartTransaction(
                    id: UUID(),
                    date: currentDate,
                    income: abs(income),  // Positive magnitude for chart bar
                    expense: abs(expense),  // Positive magnitude for chart bar
                    balance: runningBalance  // Net balance (can be negative)
                ))

            currentDate = nextDate
        }

        return points
    }
}
