//
//  PlannedOccurrenceBuilder.swift
//  Yala
//
//  Builds the [PlannedOccurrence] list consumed by SankeyFlowCalculator
//  for the "Planificados" branch in the Sankey widget.
//

import Foundation
import SwiftData

enum PlannedOccurrenceBuilder {

    /// Build the list of pending planned occurrences for the Sankey widget.
    ///
    /// Cross-references active expense scheduled payments against transactions that
    /// already credit them (`tx.scheduledPaymentID + day-match`) so paid occurrences
    /// — already counted in "Gastos" — are excluded to avoid double counting.
    ///
    /// - Parameters:
    ///   - scheduledPayments: All scheduled payments (active + expense filter applied internally).
    ///   - filteredTransactions: Transactions already filtered by the Sankey criteria.
    ///   - interval: Sankey period interval.
    ///   - selectedAccounts: When non-empty, only SPs whose `account` is in this set are considered.
    ///     Tags/currencies/needs do not filter SPs (they don't categorize the same way as tx).
    ///   - defaultCurrencyCode: User's preferred currency code (target of conversion).
    ///   - converter: Currency converter for non-default-currency SPs.
    /// - Returns: Flat list of `PlannedOccurrence` with amounts in `defaultCurrencyCode`.
    static func build(
        scheduledPayments: [ScheduledPayment],
        filteredTransactions: [TransactionItem],
        interval: DateInterval,
        selectedAccounts: Set<PersistentIdentifier>,
        defaultCurrencyCode: String,
        converter: any CurrencyConverting,
        calendar: Calendar = .current
    ) -> [PlannedOccurrence] {
        #if DEBUG
        let start = Date()
        #endif

        var paidIndex: [String: Set<TimeInterval>] = [:]
        for tx in filteredTransactions {
            guard let spID = tx.scheduledPaymentID else { continue }
            let dayKey = calendar.startOfDay(for: tx.date).timeIntervalSinceReferenceDate
            paidIndex[spID, default: []].insert(dayKey)
        }

        let months = monthsTouched(interval, calendar: calendar)

        let activeExpenses = scheduledPayments.filter {
            $0.isActive && $0.type != .income
        }

        var result: [PlannedOccurrence] = []
        for sp in activeExpenses {
            if !selectedAccounts.isEmpty {
                guard let accountID = sp.account?.persistentModelID,
                      selectedAccounts.contains(accountID) else { continue }
            }

            let kind: PlannedKind = (sp.paymentCategory == "subscription") ? .subscription : .recurring
            let categoryID = sp.subcategory?.category?.persistentModelID
            let paidDays = paidIndex[sp.id.uuidString] ?? []

            for month in months {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: sp.dateCalculatorParams,
                    month: month,
                    calendar: calendar
                )
                for date in dates {
                    guard interval.contains(date) else { continue }
                    guard !sp.isDateSkipped(date) else { continue }
                    let dayKey = calendar.startOfDay(for: date).timeIntervalSinceReferenceDate
                    if paidDays.contains(dayKey) { continue }

                    let amount: Double
                    if sp.currencyCode == defaultCurrencyCode {
                        amount = abs(sp.amount)
                    } else {
                        let converted = converter.convertWithLatestRate(
                            Decimal(abs(sp.amount)),
                            from: sp.currencyCode,
                            to: defaultCurrencyCode
                        )
                        amount = NSDecimalNumber(decimal: converted).doubleValue
                    }
                    guard amount.isFinite, amount > 0 else { continue }

                    result.append(PlannedOccurrence(
                        amount: amount,
                        kind: kind,
                        categoryID: categoryID
                    ))
                }
            }
        }

        #if DEBUG
        let elapsed = Date().timeIntervalSince(start) * 1000
        if elapsed > 50 {
            print("PlannedOccurrenceBuilder: build took \(String(format: "%.1f", elapsed))ms (>50ms threshold)")
        }
        #endif

        return result
    }

    /// Returns the first day of each calendar month touched by `interval`.
    private static func monthsTouched(_ interval: DateInterval, calendar: Calendar) -> [Date] {
        guard let firstMonth = calendar.dateInterval(of: .month, for: interval.start)?.start else {
            return [interval.start]
        }
        var months: [Date] = []
        var cursor = firstMonth
        while cursor < interval.end {
            months.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return months
    }
}
