//
//  GroupExpenseService.swift
//  Yala
//
//  CRUD for shared expenses, shares, and settlements.
//  Enqueues changes to CKSyncEngine via SplitSyncManager.
//

import Foundation
import OSLog
import SwiftData

@MainActor
@Observable
final class GroupExpenseService {

    // MARK: - Singleton

    static let shared = GroupExpenseService()

    // MARK: - Properties

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.yala", category: "GroupExpense")

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

    #if DEBUG
    /// Resetea el contexto inyectado para tests que validan comportamiento sin contexto.
    /// `AppBootstrapper.setContext` lo poblá durante boot del test runner; los tests que
    /// verifican el branch `noContext` deben llamar este helper antes de ejercer el SUT.
    func _testResetContext() {
        self.modelContext = nil
    }
    #endif

    // MARK: - Expense CRUD

    /// Create an expense with its shares, enqueue sync, and bridge to personal transaction.
    /// M6: `accountForCurrentUser` se pasa al bridge para crear TX cuenta real Caso A.
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
        shares: [(memberID: String, amount: Double)],
        accountForCurrentUser: Account? = nil
    ) throws -> SplitExpense {
        let context = try requireContext()

        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard !shares.isEmpty else { throw GroupExpenseServiceError.noShares }
        guard !paidByMemberID.isEmpty else { throw GroupExpenseServiceError.noPayer }
        try validateSharesSum(shares, amount: amount)
        try validateCurrentUserCanWrite(in: group)
        try validateMembersAreSelectable(
            in: group,
            memberIDs: Set(shares.map { $0.memberID } + [paidByMemberID]),
            additionalAllowedMemberIDs: []
        )

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
                amount: share.amount,
                groupZoneID: group.cloudKitZoneID
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
        TelemetryService.track(.groupExpenseAdded, parameters: [
            "splitType": splitType,
            "memberCount": String(shares.count)
        ])

        // Bridge to personal transaction/draft (guard: bridge may not be initialized yet)
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.bridgeExpense(
                    expense,
                    in: group,
                    accountForCurrentUser: accountForCurrentUser,
                    isRemoteSync: false
                )
            } catch {
                surfaceBridgeError(error, expense: expense, context: context, messageKey: "groups.bridge.errorTransaction")
            }
        }

        return expense
    }

    /// Update an existing expense. Deletes old shares and creates new ones.
    /// M6: `accountForCurrentUser` propaga al bridge — preserve+update TX cuenta real Caso A.
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
        shares: [(memberID: String, amount: Double)],
        accountForCurrentUser: Account? = nil
    ) throws {
        let context = try requireContext()

        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard !shares.isEmpty else { throw GroupExpenseServiceError.noShares }
        try validateSharesSum(shares, amount: amount)
        try validateCurrentUserCanWrite(in: group)

        // Delete old shares
        let oldShares = try fetchShares(for: expense)
        try validateMembersAreSelectable(
            in: group,
            memberIDs: Set(shares.map { $0.memberID } + [paidByMemberID]),
            additionalAllowedMemberIDs: Set(oldShares.map(\.memberID) + [expense.paidByMemberID])
        )
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
                amount: share.amount,
                groupZoneID: expense.groupZoneID
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
            do {
                try GroupTransactionBridge.shared.bridgeExpense(
                    expense,
                    in: group,
                    accountForCurrentUser: accountForCurrentUser,
                    isRemoteSync: false
                )
            } catch {
                surfaceBridgeError(error, expense: expense, context: context, messageKey: "groups.bridge.errorTransactionUpdate")
            }
        }
    }

    /// Delete an expense and its shares.
    func deleteExpense(_ expense: SplitExpense, in group: SplitGroup) throws {
        let context = try requireContext()
        try validateCurrentUserCanWrite(in: group)

        // A0-Bridge F8: bloquea delete si hay settlements confirmed posteriores al expense.
        // Conservador (puede bloquear deletes válidos cuando settlement no involucra members
        // del expense), pero seguro y auditable. Mensaje claro al user.
        let groupZoneID = group.cloudKitZoneID
        let cutoffDate = expense.date
        let settlementsAfterDescriptor = FetchDescriptor<SplitSettlement>(
            predicate: #Predicate {
                $0.groupZoneID == groupZoneID
                    && $0.isConfirmed == true
                    && $0.date >= cutoffDate
            }
        )
        let settlementsAfter = try context.fetch(settlementsAfterDescriptor)
        guard settlementsAfter.isEmpty else {
            throw GroupExpenseServiceError.expenseHasAssociatedSettlements
        }

        // Delete shares first
        let shares = try fetchShares(for: expense)
        for share in shares {
            SplitSyncManager.shared.enqueueDeletion(modelID: share.id, group: group)
            context.delete(share)
        }

        // Unbridge personal transaction/draft
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.unbridgeExpense(expenseID: expense.id.uuidString)
            } catch {
                // expense=nil: the row is being deleted, no point flagging it for retry
                surfaceBridgeError(error, expense: nil, context: context, messageKey: "groups.bridge.errorDelete")
            }
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
    /// Crea un settlement. A0-Bridge: si `accountForCurrentUser` proveído (Caso C proactivo
    /// con cuenta seleccionada en form) Y settlement nace con `isConfirmed=true`,
    /// el bridge se invoca al instante. Sino, el bridge se dispara en `confirmSettlement`.
    func createSettlement(
        in group: SplitGroup,
        fromMemberID: String,
        toMemberID: String,
        amount: Double,
        currencyCode: String,
        note: String?,
        date: Date,
        accountForCurrentUser: Account? = nil
    ) throws -> SplitSettlement {
        let context = try requireContext()

        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard fromMemberID != toMemberID else { throw GroupExpenseServiceError.selfSettlement }
        try validateCurrentUserCanWrite(in: group)

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

        // A0-Bridge: si settlement nace confirmed Y bridge ready, dispara TX.
        // Settlement nace con isConfirmed=false por default — caller debe confirmar.
        if settlement.isConfirmed && GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.bridgeSettlement(
                    settlement,
                    in: group,
                    accountForCurrentUser: accountForCurrentUser
                )
            } catch {
                #if DEBUG
                print("GroupExpenseService: bridgeSettlement failed: \(error)")
                #endif
            }
        }

        return settlement
    }

    /// Confirm a settlement (mark as paid). A0-Bridge: dispara `bridgeSettlement` tras confirmar.
    /// `accountForCurrentUser` permite al caller elegir cuenta (caso C proactivo).
    func confirmSettlement(
        _ settlement: SplitSettlement,
        in group: SplitGroup,
        accountForCurrentUser: Account? = nil
    ) throws {
        let context = try requireContext()
        try validateCurrentUserCanWrite(in: group)
        settlement.isConfirmed = true

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
        SplitSyncManager.shared.enqueueSave(modelID: settlement.id, group: group)

        // A0-Bridge: dispara TX bridgeadas (Caso C/D según from/to).
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.bridgeSettlement(
                    settlement,
                    in: group,
                    accountForCurrentUser: accountForCurrentUser
                )
            } catch {
                #if DEBUG
                print("GroupExpenseService: bridgeSettlement failed: \(error)")
                #endif
            }
        }
    }

    /// Delete a settlement. A0-Bridge: invoca `unbridgeSettlement` para limpiar TX/Drafts.
    func deleteSettlement(_ settlement: SplitSettlement, in group: SplitGroup) throws {
        let context = try requireContext()
        try validateCurrentUserCanWrite(in: group)

        // A0-Bridge: unbridge antes de borrar para que el contexto siga siendo válido.
        let settlementIDStr = settlement.id.uuidString
        if GroupTransactionBridge.shared.isReady {
            try? GroupTransactionBridge.shared.unbridgeSettlement(settlementID: settlementIDStr)
        }

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

    /// Fetch ALL shares for a group via single query on groupZoneID.
    func fetchAllShares(for group: SplitGroup) throws -> [SplitShare] {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.groupZoneID == zoneID }
        )
        return try context.fetch(descriptor)
    }

    /// Returns distinct currency codes used in expenses for a group.
    func fetchDistinctCurrencyCodes(for group: SplitGroup) throws -> [String] {
        let expenses = try fetchExpenses(for: group)
        let codes = Set(expenses.map { $0.currencyCode })
        return codes.sorted()
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

    // MARK: - Validation

    /// Rounding tolerance for shares sum — matches GroupSplitCalculator and GroupExpenseViewModel.
    private static let sharesTolerance: Double = 0.02

    private func validateSharesSum(_ shares: [(memberID: String, amount: Double)], amount: Double) throws {
        let sum = shares.reduce(0.0) { $0 + $1.amount }
        guard abs(sum - amount) < Self.sharesTolerance else {
            throw GroupExpenseServiceError.sharesSumMismatch
        }
    }

    private func validateCurrentUserCanWrite(in group: SplitGroup) throws {
        let members = try GroupService.shared.fetchMembers(for: group)
        guard let current = members.first(where: { $0.isCurrentUser }) else {
            if group.isOwner { return }
            throw GroupExpenseServiceError.inactiveMember
        }
        if current.isPendingApproval {
            throw GroupExpenseServiceError.pendingApproval
        }
        guard current.isActive else { throw GroupExpenseServiceError.inactiveMember }
    }

    private func validateMembersAreSelectable(
        in group: SplitGroup,
        memberIDs: Set<String>,
        additionalAllowedMemberIDs: Set<String>
    ) throws {
        let members = try GroupService.shared.fetchMembers(for: group)
        let activeMemberIDs = Set(members.filter(\.isActive).map { $0.id.uuidString })
        let allowedMemberIDs = activeMemberIDs.union(additionalAllowedMemberIDs)
        guard memberIDs.isSubset(of: allowedMemberIDs) else {
            throw GroupExpenseServiceError.inactiveMember
        }
    }

    /// Logs a bridge failure, optionally marks the expense for retry on next launch,
    /// and surfaces a user-visible alert.
    private func surfaceBridgeError(
        _ error: Error,
        expense: SplitExpense?,
        context: ModelContext,
        messageKey: String.LocalizationValue
    ) {
        logger.error("Bridge failed: \(error.localizedDescription, privacy: .public)")
        if let expense {
            expense.bridgePending = true
            do {
                try context.save()
            } catch {
                logger.error("Persisting bridgePending failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        RouterEntryGate.shared.submit(.showGroupSyncError(String(localized: messageKey)))
    }
}

// MARK: - Errors

enum GroupExpenseServiceError: LocalizedError {
    case noContext
    case invalidAmount
    case noShares
    case sharesSumMismatch
    case noPayer
    case selfSettlement
    case inactiveMember
    /// el current user está esperando aprobación del admin para participar en el grupo.
    case pendingApproval
    /// A0-Bridge F8: el expense no se puede borrar porque hay settlements confirmed
    /// posteriores en el mismo grupo. El user debe regularizar o eliminar settlements primero.
    case expenseHasAssociatedSettlements
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupExpenseService: No ModelContext available"
        case .invalidAmount:
            return "GroupExpenseService: Amount must be greater than zero"
        case .noShares:
            return "GroupExpenseService: At least one share is required"
        case .sharesSumMismatch:
            return "GroupExpenseService: Sum of shares does not match the expense amount"
        case .noPayer:
            return "GroupExpenseService: Payer member ID is required"
        case .selfSettlement:
            return "GroupExpenseService: Cannot settle with yourself"
        case .inactiveMember:
            return "GroupExpenseService: Inactive members cannot create or edit shared expenses"
        case .pendingApproval:
            return L10n.Groups.Errors.pendingApproval
        case .expenseHasAssociatedSettlements:
            return L10n.Groups.Bridge.deleteExpenseBlocked
        case .saveFailed(let error):
            return "GroupExpenseService: Save failed - \(error.localizedDescription)"
        }
    }
}
