//
//  ScheduledPaymentPaidStatusHelper.swift
//  Yala
//
//  Batch load paid count for scheduled payments in a given month.
//

import Foundation
import SwiftData

@MainActor
enum ScheduledPaymentPaidStatusHelper {

    /// Returns dictionary [paymentIDString: paidCount] for the given month.
    /// Checks both InboxDraft (approved with sourceScheduledPaymentID) and
    /// TransactionItem (with scheduledPaymentID).
    static func loadPaidStatus(for payments: [ScheduledPayment], month: Date, context: ModelContext) -> [String: Int] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [:] }

        var result: [String: Int] = [:]
        let paymentIDs = Set(payments.map { $0.id.uuidString })
        var countedTransactionIDs: Set<PersistentIdentifier> = []

        // Query 1: InboxDrafts approved with sourceScheduledPaymentID
        do {
            var draftDescriptor = FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { draft in
                    draft.statusRaw == "approved" && draft.sourceScheduledPaymentID != nil
                }
            )
            draftDescriptor.propertiesToFetch = [\.sourceScheduledPaymentID, \.date]
            let approvedDrafts = try context.fetch(draftDescriptor)

            for draft in approvedDrafts {
                guard let spID = draft.sourceScheduledPaymentID, paymentIDs.contains(spID) else { continue }
                let draftDate = draft.approvedTransaction?.date ?? draft.date ?? draft.createdAt
                if draftDate >= monthInterval.start && draftDate < monthInterval.end {
                    result[spID, default: 0] += 1
                    if let tx = draft.approvedTransaction {
                        countedTransactionIDs.insert(tx.persistentModelID)
                    }
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentPaidStatusHelper: Error loading draft paid status: \(error)")
            #endif
        }

        // Query 2: TransactionItems with scheduledPaymentID (skip already counted from drafts)
        do {
            var txDescriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { tx in
                    tx.scheduledPaymentID != nil
                }
            )
            txDescriptor.propertiesToFetch = [\.scheduledPaymentID, \.date]
            let linkedTransactions = try context.fetch(txDescriptor)

            for tx in linkedTransactions {
                guard !countedTransactionIDs.contains(tx.persistentModelID) else { continue }
                guard let spID = tx.scheduledPaymentID, paymentIDs.contains(spID) else { continue }
                if tx.date >= monthInterval.start && tx.date < monthInterval.end {
                    result[spID, default: 0] += 1
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentPaidStatusHelper: Error loading tx paid status: \(error)")
            #endif
        }

        return result
    }
}
