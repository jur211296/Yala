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
        accountForCurrentUser: Account? = nil,
        isOpeningBalance: Bool = false
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
            subcategoryName: subcategoryName,
            isOpeningBalance: isOpeningBalance
        )
        // Autor del cambio = el usuario actual (para atribución + autoexclusión del eco de notifs).
        expense.lastEditedByMemberID = currentUserMemberID(in: group)
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
        // Autor de esta edición = el usuario actual (atribución "X actualizó" + autoexclusión del eco).
        expense.lastEditedByMemberID = currentUserMemberID(in: group)

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

        try performExpenseDeletion(expense, in: group, context: context)
    }

    /// Mecánica de borrado de un expense (shares + unbridge + delete + save), SIN guards.
    /// Compartida por `deleteExpense` (guard global) y `removeOpeningBalance` (guard targeted).
    private func performExpenseDeletion(
        _ expense: SplitExpense,
        in group: SplitGroup,
        context: ModelContext
    ) throws {
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

    // MARK: - Opening Balance (saldo inicial / deuda de apertura)

    /// Crea un saldo inicial "deudor le debe a acreedor `amount`" (owner-only).
    /// Se modela como un `SplitExpense` con `isOpeningBalance=true`: `paidBy = acreedor`,
    /// una share = `[deudor: amount]`, `splitType = "exact"`, fechado en `group.createdAt`.
    /// La suma del grupo queda en cero por construcción (la arista crea +amount y −amount).
    @discardableResult
    func setOpeningBalance(
        in group: SplitGroup,
        debtorMemberID: String,
        creditorMemberID: String,
        amount: Double,
        currencyCode: String
    ) throws -> SplitExpense {
        guard group.isOwner else { throw GroupExpenseServiceError.notOwner }
        guard debtorMemberID != creditorMemberID else { throw GroupExpenseServiceError.invalidOpeningBalanceMembers }

        let expense = try createExpense(
            in: group,
            amount: amount,
            currencyCode: currencyCode,
            description: L10n.Groups.OpeningBalance.entryDescription,
            note: nil,
            date: group.createdAt,
            paidByMemberID: creditorMemberID,
            splitType: "exact",
            subcategoryName: nil,
            shares: [(memberID: debtorMemberID, amount: amount)],
            accountForCurrentUser: nil,
            isOpeningBalance: true
        )
        return expense
    }

    /// Actualiza un saldo inicial existente (owner-only). Guard targeted: bloquea si una
    /// liquidación confirmada involucra al deudor o al acreedor de esta arista.
    func updateOpeningBalance(
        _ expense: SplitExpense,
        in group: SplitGroup,
        debtorMemberID: String,
        creditorMemberID: String,
        amount: Double,
        currencyCode: String
    ) throws {
        guard group.isOwner else { throw GroupExpenseServiceError.notOwner }
        guard debtorMemberID != creditorMemberID else { throw GroupExpenseServiceError.invalidOpeningBalanceMembers }
        // Guard sobre la UNIÓN del par ORIGINAL (lo que se va a mutar/borrar) y el par NUEVO:
        // editar para alejarse de un par ya saldado corromperia ese neto histórico tanto como
        // editar hacia él. (removeOpeningBalance solo necesita el par original.)
        let oldEdgeMembers = Set(try fetchShares(for: expense).map(\.memberID) + [expense.paidByMemberID])
        let guardMembers = oldEdgeMembers.union([debtorMemberID, creditorMemberID])
        guard try !confirmedSettlementsBlock(forMembers: guardMembers, in: group) else {
            throw GroupExpenseServiceError.expenseHasAssociatedSettlements
        }

        try updateExpense(
            expense,
            in: group,
            amount: amount,
            currencyCode: currencyCode,
            description: L10n.Groups.OpeningBalance.entryDescription,
            note: nil,
            date: group.createdAt,
            paidByMemberID: creditorMemberID,
            splitType: "exact",
            subcategoryName: nil,
            shares: [(memberID: debtorMemberID, amount: amount)],
            accountForCurrentUser: nil
        )
    }

    /// Elimina un saldo inicial existente (owner-only). Guard targeted (ver `updateOpeningBalance`).
    /// NO usa el guard global de `deleteExpense` (que bloquearía con cualquier liquidación,
    /// porque los saldos van fechados en `group.createdAt`).
    func removeOpeningBalance(_ expense: SplitExpense, in group: SplitGroup) throws {
        try validateGroupIsWritable(group)   // G6-3: no pasa por validateCurrentUserCanWrite (guard explícito).
        guard group.isOwner else { throw GroupExpenseServiceError.notOwner }
        let context = try requireContext()

        let debtorIDs = try fetchShares(for: expense).map(\.memberID)
        let edgeMembers = Set(debtorIDs + [expense.paidByMemberID])
        guard try !confirmedSettlementsBlock(forMembers: edgeMembers, in: group) else {
            throw GroupExpenseServiceError.expenseHasAssociatedSettlements
        }

        try performExpenseDeletion(expense, in: group, context: context)
    }

    /// Guard targeted: `true` si una liquidación confirmada del grupo involucra a alguno de
    /// los miembros de la arista (deudor o acreedor). Editar/borrar entonces corrompería el
    /// neto histórico que ya se saldó.
    private func confirmedSettlementsBlock(forMembers members: Set<String>, in group: SplitGroup) throws -> Bool {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID
        let confirmed = try context.fetch(FetchDescriptor<SplitSettlement>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isConfirmed == true }
        ))
        return OpeningBalanceGuardLogic.isBlocked(
            edgeMembers: members,
            confirmedSettlementPairs: confirmed.map { ($0.fromMemberID, $0.toMemberID) }
        )
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
        // Quien registra la liquidación = el usuario actual (autoexclusión del eco Caso D: registro
        // "X me pagó" y no me llega "X te pagó"). La atribución "X te pagó" sigue siendo fromMemberID.
        settlement.recordedByMemberID = currentUserMemberID(in: group)
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
            do {
                try GroupTransactionBridge.shared.unbridgeSettlement(settlementID: settlementIDStr)
            } catch {
                logger.error("deleteSettlement: unbridge failed for \(settlementIDStr, privacy: .public); deleting anyway (bridged TX/drafts may be orphaned): \(error.localizedDescription, privacy: .public)")
            }
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

    /// G6-3 (C4, FREEZE — RED de correctness): un grupo migrado y CONGELADO (`movedToBackendAt != nil &&
    /// !isBackendGroup`, con la mitigación #9 del owner reinstall) NO acepta escrituras: sus records irían a la
    /// zona CloudKit congelada y se perderían (R4). El guard central lo lanza ANTES de cualquier check de
    /// participación. Punto de inserción óptimo (ajuste #6): al TOP de `validateCurrentUserCanWrite` (cubre
    /// create/update/deleteExpense/createSettlement/confirmSettlement/deleteSettlement) + `removeOpeningBalance`.
    /// El trío opening-balance es owner-only ⇒ el freeze es inerte para él (defensa en profundidad).
    func validateGroupIsWritable(_ group: SplitGroup) throws {
        if group.isMigratedFrozen { throw GroupExpenseServiceError.movedToBackend }
    }

    /// `SplitMember.id.uuidString` del usuario actual en el grupo (para atribuir "quién hizo el cambio"
    /// en las notificaciones y autoexcluir el eco). Resuelto en el contexto del propio servicio
    /// (`GroupService.fetchMembers`, igual que `validateCurrentUserCanWrite`).
    ///
    /// DEBE resolver el MISMO id que el consumidor `GroupNotificationService.currentMemberID(inZone:)`
    /// (resolución CANÓNICA: entre los members `isCurrentUser`, el de `joinedAt` más antiguo — mismo
    /// criterio que su `FetchDescriptor` sortBy joinedAt + fetchLimit 1, y que `SplitSyncManager
    /// .currentUserMember`). Un tie-break distinto (p.ej. `first(where:)` sobre el orden de `fetchMembers`
    /// por displayName) elegiría OTRO id bajo members `isCurrentUser` DUPLICADOS → el write-side y el
    /// clasificador guardarían/compararían ids distintos y el eco NO se autoexcluiría.
    ///
    /// Fallback (ventana temprana: 2º device / restore de iCloud, `isCurrentUser` aún no marcado porque es
    /// device-local y `refreshCurrentUserFlags` no ha corrido): resolver por identidad iCloud
    /// (`cloudKitUserRecordID == cachedRecordName`), la MISMA fuente que `refreshCurrentUserFlags` usa para
    /// marcar `isCurrentUser`. Así el eco se autoexcluye aunque el flag llegue tarde (sin esto, el owner en
    /// esa ventana guardaba nil y recibía "otro actualizó" por su propia edición — el bug reportado).
    /// nil solo si tampoco hay identidad iCloud cacheada (primer arranque sin resolver) ⇒ ahí el consumidor
    /// tampoco resuelve currentMemberID ⇒ `expenseDecision` skipea (sin notif).
    private func currentUserMemberID(in group: SplitGroup) -> String? {
        let members: [SplitMember]
        do {
            members = try GroupService.shared.fetchMembers(for: group)
        } catch {
            #if DEBUG
            print("GroupExpenseService: Error resolviendo el miembro actual para atribución: \(error)")
            #endif
            return nil
        }
        return Self.selectCurrentUserMemberID(
            from: members,
            cachedRecordName: GroupUserIdentityService.shared.cachedRecordName
        )
    }

    /// Selección pura del `SplitMember.id.uuidString` del usuario actual (extraída para test sin contexto).
    /// Resolución CANÓNICA — DEBE espejar `GroupNotificationService.currentMemberID(inZone:)` (isCurrentUser
    /// con `joinedAt` más antiguo). Fallback por identidad iCloud para la ventana temprana (isCurrentUser
    /// aún no marcado en 2º device / restore). Ver el doc de `currentUserMemberID(in:)` para el porqué.
    static func selectCurrentUserMemberID(from members: [SplitMember], cachedRecordName: String?) -> String? {
        if let current = members.filter({ $0.isCurrentUser }).min(by: { $0.joinedAt < $1.joinedAt }) {
            return current.id.uuidString
        }
        if let recordName = cachedRecordName, !recordName.isEmpty,
           let byIdentity = members.filter({ $0.cloudKitUserRecordID == recordName })
                                   .min(by: { $0.joinedAt < $1.joinedAt }) {
            return byIdentity.id.uuidString
        }
        return nil
    }

    private func validateCurrentUserCanWrite(in group: SplitGroup) throws {
        try validateGroupIsWritable(group)
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
    /// Solo el owner del grupo puede gestionar saldos iniciales.
    case notOwner
    /// Un saldo inicial necesita dos miembros distintos (deudor ≠ acreedor).
    case invalidOpeningBalanceMembers
    /// G6-3: el grupo se migró a la nube de Yala y está congelado en este device — hay que volver a entrar.
    case movedToBackend
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
        case .notOwner:
            return L10n.Groups.OpeningBalance.errorNotOwner
        case .invalidOpeningBalanceMembers:
            return L10n.Groups.OpeningBalance.errorSameMember
        case .movedToBackend:
            return L10n.Groups.Errors.movedToBackend
        case .saveFailed(let error):
            return "GroupExpenseService: Save failed - \(error.localizedDescription)"
        }
    }
}
