//
//  CashFlowCalculator.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

struct CashFlowData: Identifiable {
    let id = UUID()
    let date: Date
    let income: Double
    let expense: Double
    let net: Double
}

struct CashFlowSummary {
    let totalIncome: Double
    let totalExpense: Double
    let netFlow: Double
    let chartData: [CashFlowData]
    let currencyCode: String
}

struct CashFlowCalculator {

    static func calculateCashFlow(
        transactions: [TransactionItem],
        interval: DateInterval,
        grouping: TrendGrouping,
        currencyCode: String,
        context: ModelContext
    ) -> CashFlowSummary {

        let calendar = Calendar.current
        var groupedData: [Date: (income: Double, expense: Double)] = [:]

        var totalIncome: Double = 0
        var totalExpense: Double = 0

        // 1. Process Transactions and Accumulate
        for tx in transactions {
            // Strict Filter:
            // Must have a category (excludes Transfers)
            // Skip balance adjustments (they affect balance, not cash flow)
            guard let category = tx.category else { continue }
            guard tx.balanceAdjustmentType == nil else { continue }

            let decimalAmt = Decimal(abs(tx.amount))

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

            let isIncome = category.isIncome

            // Date Grouping key
            let dateKey = grouping.dateKey(for: tx.date, calendar: calendar)

            // Accumulate in Group
            var current = groupedData[dateKey] ?? (0.0, 0.0)
            if isIncome {
                current.income += val
                totalIncome += val
            } else {
                // Expenses are negative signed values.
                // We want positive magnitude for the "Expense" bar/total.
                // Subtracting a negative value adds to the magnitude.
                // Subtracting a positive value (refund) reduces the magnitude.
                current.expense -= val
                totalExpense -= val
            }
            groupedData[dateKey] = current
        }

        // 2. Generate Chart Data (filling gaps)
        var chartData: [CashFlowData] = []
        var currentDate = interval.start

        let component = grouping.calendarComponent

        while currentDate < interval.end {
            let keyDate = grouping.dateKey(for: currentDate, calendar: calendar)

            let values = groupedData[keyDate] ?? (0.0, 0.0)
            let net = values.income - values.expense

            chartData.append(
                CashFlowData(
                    date: keyDate,
                    income: values.income,
                    expense: values.expense,
                    net: net
                ))

            // Increment date
            guard let next = calendar.date(byAdding: component, value: 1, to: currentDate) else {
                break
            }
            currentDate = next
            // Safety break if loop goes infinite (e.g. component issue)
            if currentDate <= keyDate { break }
        }

        let netFlow = totalIncome - totalExpense

        return CashFlowSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netFlow: netFlow,
            chartData: chartData,
            currencyCode: currencyCode
        )
    }
}
