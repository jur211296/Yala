//
//  GroupExpenseBridgeTraceReader.swift
//  Yala
//
//  Lee qué dejó el puente en el store para un gasto de grupo recién guardado. Lo usa la pantalla de «¡Gasto agregado!»
//  para no afirmar un movimiento que no se escribió (card dx3m). Solo lectura.
//

import Foundation
import SwiftData

@MainActor
enum GroupExpenseBridgeTraceReader {

    static func read(expenseID: String, context: ModelContext) throws -> GroupExpenseBridgeTrace {
        let transactions = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
        let real = transactions.first { tx in
            guard let account = tx.account else { return false }
            return !account.isSystemAccount
        }
        let hasVirtualShare = transactions.contains { tx in
            tx.account?.isSystemAccount == true && tx.amount < 0
        }

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
        let hasPendingOptInDraft = drafts.contains { $0.optInPersonalOnly && $0.status == .pending }

        var bridgePending = false
        if let uuid = UUID(uuidString: expenseID) {
            var descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == uuid })
            descriptor.fetchLimit = 1
            bridgePending = try context.fetch(descriptor).first?.bridgePending ?? false
        }

        return GroupExpenseBridgeTrace(
            realAccountName: real?.account?.name,
            hasVirtualShare: hasVirtualShare,
            hasPendingOptInDraft: hasPendingOptInDraft,
            bridgePending: bridgePending
        )
    }
}
