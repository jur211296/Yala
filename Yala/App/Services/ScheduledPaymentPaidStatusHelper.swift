//
//  ScheduledPaymentPaidStatusHelper.swift
//  Yala
//
//  Batch load paid status and real amounts for scheduled payments in a given month.
//

import Foundation
import SwiftData

/// Real amount data for a single paid occurrence of a scheduled payment.
struct PaidOccurrenceInfo {
    let amount: Double
    let currencyCode: String
    let date: Date
}

@MainActor
enum ScheduledPaymentPaidStatusHelper {

    /// Returns dictionary [paymentIDString: paidCount] for the given month.
    /// Convenience wrapper — delegates to `loadPaidAmounts` and returns counts only.
    static func loadPaidStatus(for payments: [ScheduledPayment], month: Date, context: ModelContext) -> [String: Int] {
        loadPaidAmounts(for: payments, month: month, context: context).mapValues(\.count)
    }

    /// Returns per-occurrence paid info `[paymentIDString: [PaidOccurrenceInfo]]` for the given month.
    /// Wrapper que mantiene la firma original — delega al overload basado en `interval:`.
    static func loadPaidAmounts(
        for payments: [ScheduledPayment], month: Date, context: ModelContext
    ) -> [String: [PaidOccurrenceInfo]] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [:] }
        return loadPaidAmounts(for: payments, interval: monthInterval, context: context)
    }

    /// Returns per-occurrence paid info for the given interval. Each entry contains the
    /// real transaction amount, currency, and date — sorted ascending by date.
    /// Checks both InboxDraft (approved with sourceScheduledPaymentID) and
    /// TransactionItem (with scheduledPaymentID).
    static func loadPaidAmounts(
        for payments: [ScheduledPayment], interval: DateInterval, context: ModelContext
    ) -> [String: [PaidOccurrenceInfo]] {
        let calendar = Calendar.current
        var result: [String: [PaidOccurrenceInfo]] = [:]
        let paymentIDs = Set(payments.map { $0.id.uuidString })
        let intervalStart = interval.start
        let intervalEnd = interval.end
        var countedPairs: Set<String> = []

        // Query 1: InboxDrafts approved with sourceScheduledPaymentID (filtered by interval)
        do {
            var draftDescriptor = FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { draft in
                    draft.statusRaw == "approved"
                        && draft.sourceScheduledPaymentID != nil
                        && draft.createdAt >= intervalStart && draft.createdAt < intervalEnd
                }
            )
            draftDescriptor.propertiesToFetch = [\.sourceScheduledPaymentID, \.date, \.amount, \.createdAt, \.cachedCurrencyCode]
            let approvedDrafts = try context.fetch(draftDescriptor)

            for draft in approvedDrafts {
                guard let spID = draft.sourceScheduledPaymentID, paymentIDs.contains(spID) else { continue }
                let draftDate = draft.date ?? draft.createdAt
                if draftDate >= intervalStart && draftDate < intervalEnd {
                    let realAmount = draft.amount.map { abs($0) }
                    let realCurrency = draft.cachedCurrencyCode ?? "USD"
                    #if DEBUG
                    if realAmount == nil {
                        print("ScheduledPaymentPaidStatusHelper: Approved draft has no amount — using 0 for payment \(spID)")
                    }
                    #endif
                    result[spID, default: []].append(PaidOccurrenceInfo(
                        amount: realAmount ?? 0,
                        currencyCode: realCurrency,
                        date: draftDate
                    ))
                    // Dedup key: spID + day-level date (avoids relationship access)
                    let dayKey = calendar.startOfDay(for: draftDate)
                    countedPairs.insert("\(spID)_\(dayKey.timeIntervalSince1970)")
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentPaidStatusHelper: Error loading draft paid status: \(error)")
            #endif
        }

        // Query 2: TransactionItems with scheduledPaymentID (filtered by interval, skip already counted from drafts)
        do {
            var txDescriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { tx in
                    tx.scheduledPaymentID != nil
                        && tx.date >= intervalStart && tx.date < intervalEnd
                }
            )
            txDescriptor.propertiesToFetch = [\.scheduledPaymentID, \.date, \.amount, \.currencyCode]
            let linkedTransactions = try context.fetch(txDescriptor)

            for tx in linkedTransactions {
                guard let spID = tx.scheduledPaymentID, paymentIDs.contains(spID) else { continue }
                let dayKey = calendar.startOfDay(for: tx.date)
                let pairKey = "\(spID)_\(dayKey.timeIntervalSince1970)"
                guard !countedPairs.contains(pairKey) else { continue }
                result[spID, default: []].append(PaidOccurrenceInfo(
                    amount: abs(tx.amount),
                    currencyCode: tx.currencyCode,
                    date: tx.date
                ))
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentPaidStatusHelper: Error loading tx paid status: \(error)")
            #endif
        }

        // Sort each payment's occurrences by date ascending for queue-based consumption
        for key in result.keys {
            result[key]?.sort { $0.date < $1.date }
        }

        return result
    }
}
