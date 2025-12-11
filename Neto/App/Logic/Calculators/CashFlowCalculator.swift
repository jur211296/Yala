//
//  CashFlowCalculator.swift
//  Neto
//
//  Created by Neto Refactoring.
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
        currencyCode: String
    ) -> CashFlowSummary {

        let calendar = Calendar.current
        var groupedData: [Date: (income: Double, expense: Double)] = [:]

        var totalIncome: Double = 0
        var totalExpense: Double = 0

        // 1. Process Transactions and Accumulate
        for tx in transactions {
            let absAmt = abs(tx.amount)
            let decimalAmt = Decimal(absAmt)

            // Convert
            let converted = convert(decimalAmt, from: tx.currencyCode, to: currencyCode)
            let val = NSDecimalNumber(decimal: converted).doubleValue

            let isIncome = tx.category?.isIncome ?? (tx.amount >= 0)

            // Date Grouping key
            let dateKey: Date
            switch grouping {
            case .day:
                dateKey = calendar.startOfDay(for: tx.date)
            case .week:
                dateKey =
                    calendar.dateInterval(of: .weekOfYear, for: tx.date)?.start
                    ?? calendar.startOfDay(for: tx.date)
            case .month:
                dateKey =
                    calendar.dateInterval(of: .month, for: tx.date)?.start
                    ?? calendar.startOfDay(for: tx.date)
            }

            // Accumulate in Group
            var current = groupedData[dateKey] ?? (0.0, 0.0)
            if isIncome {
                current.income += val
                totalIncome += val
            } else {
                current.expense += val
                totalExpense += val
            }
            groupedData[dateKey] = current
        }

        // 2. Generate Chart Data (filling gaps)
        var chartData: [CashFlowData] = []
        var currentDate = interval.start

        let component: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        while currentDate < interval.end {
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

    // MARK: - Currency Helpers (Mirrored from BalanceTrendCalculator for consistency)

    private static func normalizeCurrencyCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "PEN" }

        let upper = trimmed.uppercased()
        switch upper {
        case "PEN", "SOL", "SOLES", "S/", "S/.", "S/. ": return "PEN"
        case "USD", "US$", "US DOLLAR", "$", "$USD", "USD$": return "USD"
        case "EUR", "€", "EURO": return "EUR"
        default: return "PEN"
        }
    }

    private static func rateToPEN(_ rawCode: String) -> Decimal {
        let code = normalizeCurrencyCode(rawCode)
        switch code {
        case "PEN": return 1.0
        case "USD": return 3.54
        case "EUR": return 3.89
        default: return 1.0
        }
    }

    private static func convert(_ amount: Decimal, from rawFrom: String, to rawTo: String)
        -> Decimal
    {
        let fromCode = normalizeCurrencyCode(rawFrom)
        let toCode = normalizeCurrencyCode(rawTo)

        if fromCode == toCode { return amount }

        let fromRate = rateToPEN(fromCode)
        let toRate = rateToPEN(toCode)

        if fromRate == 0 || toRate == 0 { return amount }

        let amountInPEN = amount * fromRate

        if toCode == "PEN" { return amountInPEN }

        return amountInPEN / toRate
    }
}
