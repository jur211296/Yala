//
//  GroupExpenseService.swift
//  Yala
//
//  CRUD for shared expenses, shares, and settlements.
//  Enqueues changes to CKSyncEngine via SplitSyncManager.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupExpenseService {

    // MARK: - Singleton

    static let shared = GroupExpenseService()

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw GroupExpenseServiceError.noContext
        }
        return context
    }

    // MARK: - Expense CRUD

    /// Create an expense with its shares, enqueue sync, and bridge to personal transaction.
    @discardableResult
    func createExpense(
        in group: SplitGroup,
        amount: Double,
        currencyCode: String,
        description: String,
        note: String?,
        date: Date,
        paidByMemberID: String,
        splitType: String,
        subcategoryName: String?,
        shares: [(memberID: String, amount: Double)]
    ) throws -> SplitExpense {
        let context = try requireContext()

        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard !shares.isEmpty else { throw GroupExpenseServiceError.noShares }
        guard !paidByMemberID.isEmpty else { throw GroupExpenseServiceError.noPayer }

        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID,
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: description,
            note: note,
            date: date,
            paidByMemberID: paidByMemberID,
            splitType: splitType,
            subcategoryName: subcategoryName
        )
        context.insert(expense)

        // Create shares
        for share in shares {
            let splitShare = SplitShare(
                expenseID: expense.id,
                memberID: share.memberID,
                amount: share.amount
            )
            context.insert(splitShare)
            SplitSyncManager.shared.enqueueSave(modelID: splitShare.id, group: group)
        }

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: expense.id, group: group)

        // Bridge to personal transaction/draft (guard: bridge may not be initialized yet)
        if GroupTransactionBridge.shared.isReady {
            try? GroupTransactionBridge.shared.bridgeExpense(expense, in: group, shouldSave: false)
        }

        return expense
    }

    /// Update an existing expense. Deletes old shares and creates new ones.
    func updateExpense(
        _ expense: SplitExpense,
        in group: SplitGroup,
        amount: Double,
        currencyCode: String,
        description: String,
        note: String?,
        date: Date,
        paidByMemberID: String,
        splitType: String,
        subcategoryName: String?,
        shares: [(memberID: String, amount: Double)]
    ) throws {
        let context = try requireContext()

        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard !shares.isEmpty else { throw GroupExpenseServiceError.noShares }

        // Delete old shares
        let oldShares = try fetchShares(for: expense)
        for oldShare in oldShares {
            SplitSyncManager.shared.enqueueDeletion(modelID: oldShare.id, group: group)
            context.delete(oldShare)
        }

        // Update expense fields
        expense.amount = amount
        expense.currencyCode = currencyCode
        expense.expenseDescription = description
        expense.note = note
        expense.date = date
        expense.paidByMemberID = paidByMemberID
        expense.splitType = splitType
        expense.subcategoryName = subcategoryName

        // Create new shares
        for share in shares {
            let splitShare = SplitShare(
                expenseID: expense.id,
                memberID: share.memberID,
                amount: share.amount
            )
            context.insert(splitShare)
            SplitSyncManager.shared.enqueueSave(modelID: splitShare.id, group: group)
        }

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: expense.id, group: group)

        // Update bridged record
        if GroupTransactionBridge.shared.isReady {
            try? GroupTransactionBridge.shared.bridgeExpense(expense, in: group, shouldSave: false)
        }
    }

    /// Delete an expense and its shares.
    func deleteExpense(_ expense: SplitExpense, in group: SplitGroup) throws {
        let context = try requireContext()

        // Delete shares first
        let shares = try fetchShares(for: expense)
        for share in shares {
            SplitSyncManager.shared.enqueueDeletion(modelID: share.id, group: group)
            context.delete(share)
        }

        // Unbridge personal transaction/draft
        if GroupTransactionBridge.shared.isReady {
            try? GroupTransactionBridge.shared.unbridgeExpense(expenseID: expense.id.uuidString)
        }

        SplitSyncManager.shared.enqueueDeletion(modelID: expense.id, group: group)
        context.delete(expense)

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Settlement CRUD

    /// Create a settlement (payment from one member to another).
    @discardableResult
    func createSettlement(
        in group: SplitGroup,
        fromMemberID: String,
        toMemberID: String,
        amount: Double,
        currencyCode: String,
        note: String?,
        date: Date
    ) throws -> SplitSettlement {
        let context = try requireContext()

        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard fromMemberID != toMemberID else { throw GroupExpenseServiceError.selfSettlement }

        let settlement = SplitSettlement(
            groupZoneID: group.cloudKitZoneID,
            fromMemberID: fromMemberID,
            toMemberID: toMemberID,
            amount: amount,
            currencyCode: currencyCode,
            note: note,
            date: date
        )
        context.insert(settlement)

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: settlement.id, group: group)

        return settlement
    }

    /// Confirm a settlement (mark as paid).
    func confirmSettlement(_ settlement: SplitSettlement, in group: SplitGroup) throws {
        let context = try requireContext()
        settlement.isConfirmed = true

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: settlement.id, group: group)
    }

    /// Delete a settlement.
    func deleteSettlement(_ settlement: SplitSettlement, in group: SplitGroup) throws {
        let context = try requireContext()

        SplitSyncManager.shared.enqueueDeletion(modelID: settlement.id, group: group)
        context.delete(settlement)

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Fetch Helpers

    func fetchExpenses(for group: SplitGroup) throws -> [SplitExpense] {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchShares(for expense: SplitExpense) throws -> [SplitShare] {
        let context = try requireContext()
        let expenseID = expense.id
        let descriptor = FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseID }
        )
        return try context.fetch(descriptor)
    }

    func fetchSettlements(for group: SplitGroup) throws -> [SplitSettlement] {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitSettlement>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}

// MARK: - Errors

enum GroupExpenseServiceError: LocalizedError {
    case noContext
    case invalidAmount
    case noShares
    case noPayer
    case selfSettlement
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupExpenseService: No ModelContext available"
        case .invalidAmount:
            return "GroupExpenseService: Amount must be greater than zero"
        case .noShares:
            return "GroupExpenseService: At least one share is required"
        case .noPayer:
            return "GroupExpenseService: Payer member ID is required"
        case .selfSettlement:
            return "GroupExpenseService: Cannot settle with yourself"
        case .saveFailed(let error):
            return "GroupExpenseService: Save failed - \(error.localizedDescription)"
        }
    }
}
