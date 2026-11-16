//
//  GroupExpenseService.swift
//  Yala
//
//  CRUD for shared expenses, shares, and settlements.
//  Las escrituras que viajan salen por el drain del canal backend; la Fase 3 se llevó el encolado
//  directo a CKSyncEngine.
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

    /// Tras un save local de gasto, pide un ciclo de sync bajo background task. Inyectable para
    /// afirmar que el ciclo se PIDIÓ, no que iOS concedió tiempo.
    @ObservationIgnored
    var requestSyncAfterLocalSave: () -> Void = {
        GroupsSaveSyncTrigger.shared.requestAfterLocalSave()
    }

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext?) {
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
        requestSyncAfterLocalSave = { GroupsSaveSyncTrigger.shared.requestAfterLocalSave() }
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
        }

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        requestSyncAfterLocalSave()
        SessionState.shared.incrementDataVersion()

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
        }

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        requestSyncAfterLocalSave()
        SessionState.shared.incrementDataVersion()

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

    // MARK: - Pasar un registro personal a un grupo (2.3)

    #if DEBUG
    /// Seam de tests: el guardado final de la conversión falla después de que el puente haya escrito, para medir el
    /// `rollback()` (`docs/aprendizajes-tecnicos.md`, «`context.rollback()` aborta la app…»). Estático: resetéalo en `defer`.
    static var _testFailConversionSave = false
    #endif

    /// Si un registro se puede pasar a un grupo desde su editor (`PersonalToGroupConversionLogic`).
    static func conversionVerdict(for transaction: TransactionItem) -> PersonalToGroupConversionLogic.Verdict {
        guard !transaction.isDeleted, transaction.modelContext != nil else { return .notOffered }
        let account = transaction.account
        let hasGroupPointer = transaction.splitExpenseID != nil || transaction.splitSettlementID != nil
            || transaction.splitGroupZoneID != nil
        return PersonalToGroupConversionLogic.verdict(
            PersonalToGroupConversionLogic.Record(
                amount: transaction.amount,
                categoryIsIncome: transaction.category?.isIncome,
                hasGroupPointer: hasGroupPointer,
                isDerivedGroupLeg: GroupSplitLinesBridgeLogic.isDerivedMarker(transaction.splitLinesRaw)
                    || GroupCollectedLegLogic.isBridgeWrittenSaleLeg(
                        adjustmentType: transaction.balanceAdjustmentType, splitLinesRaw: transaction.splitLinesRaw),
                isTransfer: transaction.transferPairID != nil,
                isBalanceAdjustment: transaction.balanceAdjustmentType != nil,
                hasAccount: account != nil,
                accountIsSystem: account?.isSystemAccount == true,
                accountIsArchived: account?.isArchived == true,
                accountCurrencyMatches: account?.currencyCode == transaction.currencyCode,
                usesPersonalSplit: transaction.splitTotalAmount != nil || transaction.splitMyValue != nil,
                isGroupPaymentRecord: transaction.approvedDraft?.sourceType == .groupSettlement,
                isConservedFromDetach: GroupsDetachedBridgeLedger.claimsMovement(transaction)
            ),
            hasPrivateSession: SessionState.shared.hasPrivateSession
        )
    }

    /// Pasa un gasto personal ya registrado a un grupo: crea el gasto (pagaste tú, con el importe, la moneda y la fecha
    /// del registro) y el registro pasa a ser su pata real, como al enlazar un movimiento desde la Bandeja
    /// (`DraftService.linkGroupExpenseDraft`, L13-15). El puente lo conserva (preserve+update: cuenta, nota, etiquetas,
    /// necesidad y subcategoría intactas, importe y fecha iguales) y solo añade el «Préstamo a grupos» de lo que te deben.
    /// No queda un segundo gasto en tus cuentas ni en el grupo.
    ///
    /// **Un solo guardado.** Lo pendiente del contexto se guarda ANTES de empezar, así que un fallo a mitad (del puente o
    /// del guardado) se deshace con `rollback()` sin llevarse ediciones ajenas: no hay `await` entre ese guardado y el
    /// `rollback()`. El registro queda como estaba y no queda un gasto a medias.
    ///
    /// **Un registro que ya apunta a un gasto no se vuelve a pasar**: falla sin tocar nada, sea el mismo grupo o no. El
    /// doble toque lo corta antes el formulario (`GroupExpenseViewModel.save`, que no vuelve a llamar tras convertir);
    /// aquí llega solo un registro enlazado por OTRO camino (otra ventana, la Bandeja), y devolver ese gasto como si fuera
    /// el nuevo descartaría en silencio el reparto que la persona acaba de elegir.
    ///
    /// Sin borrador en la Bandeja al convertir: el puente corre con `withSkippedDraftCleanup`, como el enlace de L13-15.
    /// Un registro sin categoría, con el gasto también sin ella, puede volver a pedirla en un re-puente posterior (una
    /// edición del grupo, el otro dispositivo), igual que cualquier gasto de grupo sin categoría.
    @discardableResult
    func convertPersonalTransaction(
        _ transaction: TransactionItem,
        to group: SplitGroup,
        description: String,
        subcategoryName: String?,
        splitType: String,
        shares: [(memberID: String, amount: Double)]
    ) throws -> SplitExpense {
        let context = try requireContext()

        // Antes de leer nada del registro: borrado con la revisión abierta (otro dispositivo), leerlo aborta en iOS 27.x.
        guard !transaction.isDeleted, transaction.modelContext != nil else { throw GroupExpenseServiceError.notConvertible }
        guard !group.isDeleted, group.modelContext != nil else { throw GroupExpenseServiceError.groupUnavailable }
        guard Self.conversionVerdict(for: transaction) == .eligible,
              let account = transaction.account else { throw GroupExpenseServiceError.notConvertible }

        let amount = abs(transaction.amount)
        guard amount > 0 else { throw GroupExpenseServiceError.invalidAmount }
        guard !shares.isEmpty else { throw GroupExpenseServiceError.noShares }
        try validateSharesSum(shares, amount: amount)
        guard !group.isHiddenForAll, !group.isArchived else { throw GroupExpenseServiceError.groupUnavailable }
        try validateCurrentUserCanWrite(in: group)
        // El pagador es quien pasa el registro: el dinero salió de su cuenta.
        guard let me = try Self.resolveCurrentUserMember(inZone: group.cloudKitZoneID, context: context),
              me.isActive else { throw GroupExpenseServiceError.inactiveMember }
        let myID = me.id.uuidString
        try validateMembersAreSelectable(
            in: group, memberIDs: Set(shares.map(\.memberID) + [myID]), additionalAllowedMemberIDs: [])
        // Sin puente que pueda atenderlo, el gasto existiría sin su registro: se cuenta dos veces o ninguna.
        guard GroupTransactionBridge.shared.isReady, GroupTransactionBridge.isDomainOpenForBridge() else {
            throw GroupExpenseServiceError.bridgeUnavailable
        }
        // Una categoría de ingreso haría del gasto una venta, y el puente borraría el registro (Grupos B · card 8).
        if let matched = GroupTransactionBridge.matchSubcategory(name: subcategoryName, context: context),
           !matched.isAnySystem, matched.safeCategory.isIncome {
            throw GroupExpenseServiceError.notConvertible
        }

        // Las categorías de sistema de Grupos («Préstamo a grupos»), sembradas ANTES de escribir: su siembra guarda el
        // contexto entero, y la primera vez en un teléfono la hacía el puente a mitad de la conversión, dejando el gasto y
        // el enlace en disco aunque el guardado final fallara (medido con `_testFailConversionSave`).
        seedSystemGroupCategoriesIfNeeded(in: context)
        if context.hasChanges {
            do { try context.save() } catch { throw GroupExpenseServiceError.saveFailed(error) }
        }

        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID,
            amount: amount,
            currencyCode: transaction.currencyCode,
            expenseDescription: description,
            note: nil,
            date: transaction.date,
            paidByMemberID: myID,
            splitType: splitType,
            subcategoryName: subcategoryName
        )
        expense.lastEditedByMemberID = currentUserMemberID(in: group)
        context.insert(expense)
        for share in shares {
            context.insert(SplitShare(
                expenseID: expense.id, memberID: share.memberID, amount: share.amount, groupZoneID: group.cloudKitZoneID))
        }
        let expenseID = expense.id.uuidString
        transaction.splitExpenseID = expenseID
        transaction.splitGroupZoneID = group.cloudKitZoneID
        transaction.splitTotalAmount = amount
        transaction.splitType = splitType

        do {
            let attended = try GroupTransactionBridge.shared.withSkippedDraftCleanup {
                try GroupTransactionBridge.shared.bridgeExpense(
                    expense, in: group, accountForCurrentUser: account, isRemoteSync: false, shouldSave: false)
            }
            // El registro tiene que seguir siendo la pata real: si el puente lo hubiera retirado, guardar lo borraría.
            guard attended, !transaction.isDeleted, transaction.splitExpenseID == expenseID,
                  transaction.account?.persistentModelID == account.persistentModelID else {
                context.rollback()
                throw GroupExpenseServiceError.bridgeUnavailable
            }
            #if DEBUG
            if Self._testFailConversionSave { throw CocoaError(.fileWriteUnknown) }
            #endif
            try context.save()
        } catch let error as GroupExpenseServiceError {
            throw error
        } catch {
            #if DEBUG
            print("GroupExpenseService: Error: converting a personal record to a group expense: \(error)")
            #endif
            context.rollback()
            throw GroupExpenseServiceError.saveFailed(error)
        }

        requestSyncAfterLocalSave()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        Task { await BudgetAlertService.shared.checkBudgetsAndNotify() }
        return expense
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

        context.delete(expense)

        do {
            try context.save()
        } catch {
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Opening Balance (saldo inicial / deuda de apertura)

    /// Crea un saldo inicial "deudor le debe a acreedor `amount`" (el dueño o un admin: `validateCurrentUserCanManageOpeningBalances`).
    /// Se modela como un `SplitExpense` con `isOpeningBalance=true`: `paidBy = acreedor`,
    /// una share = `[deudor: amount]`, `splitType = "exact"`, fechado en `date` (card t3fq: la elige quien lo apunta;
    /// hasta el 2026-10-28 era siempre `group.createdAt` y el registro caía al fondo del grupo).
    /// La suma del grupo queda en cero por construcción (la arista crea +amount y −amount).
    ///
    /// **Uno por pareja y moneda** (`OpeningBalanceEdgeLogic.replaceable`): si esas dos personas ya tienen un saldo
    /// inicial en esa moneda, en cualquier sentido, se EDITA ése y se devuelve. Si el guard de liquidaciones no deja
    /// editarlo, el nuevo se crea aparte: es lo que pasaba siempre, y el que estaba no se toca.
    @discardableResult
    func setOpeningBalance(
        in group: SplitGroup,
        debtorMemberID: String,
        creditorMemberID: String,
        amount: Double,
        currencyCode: String,
        date: Date
    ) throws -> SplitExpense {
        // Card jqgy: el freeze primero, como en `removeOpeningBalance`. Antes llegaba tarde (dentro de `createExpense`) y
        // a quien no era admin le salía «solo un administrador…», falso en un grupo que ya no admite cambios de nadie.
        try validateGroupIsWritable(group)
        try validateCurrentUserCanManageOpeningBalances(in: group)
        guard debtorMemberID != creditorMemberID else { throw GroupExpenseServiceError.invalidOpeningBalanceMembers }

        if let existing = try openingBalanceToReplace(
            in: group, memberA: debtorMemberID, memberB: creditorMemberID, currencyCode: currencyCode
        ) {
            do {
                try updateOpeningBalance(
                    existing,
                    in: group,
                    debtorMemberID: debtorMemberID,
                    creditorMemberID: creditorMemberID,
                    amount: amount,
                    currencyCode: currencyCode,
                    date: date
                )
                return existing
            } catch GroupExpenseServiceError.expenseHasAssociatedSettlements {
                // El que había ya no se puede tocar (un pago confirmado de alguno de los dos), así que el nuevo va
                // aparte, como antes de esta regla. Sin esto, «Añadir» se paraba con el aviso de BORRAR un gasto.
                #if DEBUG
                print("GroupExpenseService: opening balance to replace is locked by a confirmed settlement; creating a new one")
                #endif
            }
        }

        let expense = try createExpense(
            in: group,
            amount: amount,
            currencyCode: currencyCode,
            description: L10n.Groups.OpeningBalance.entryDescription,
            note: nil,
            date: OpeningBalanceEdgeLogic.storedDate(date, now: Date.now),
            paidByMemberID: creditorMemberID,
            splitType: "exact",
            subcategoryName: nil,
            shares: [(memberID: debtorMemberID, amount: amount)],
            accountForCurrentUser: nil,
            isOpeningBalance: true
        )
        return expense
    }

    /// El saldo inicial que uno nuevo entre `memberA` y `memberB` en `currencyCode` reemplaza (el más antiguo si
    /// hubiera varios de antes de la regla), o `nil`.
    private func openingBalanceToReplace(
        in group: SplitGroup,
        memberA: String,
        memberB: String,
        currencyCode: String
    ) throws -> SplitExpense? {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID
        let existing = try context.fetch(FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isOpeningBalance == true }
        )).sorted { $0.createdAt < $1.createdAt }
        var byID: [UUID: SplitExpense] = [:]
        var edges: [OpeningBalanceEdgeLogic.Edge] = []
        for expense in existing {
            guard let debtor = try fetchShares(for: expense).first?.memberID else { continue }
            byID[expense.id] = expense
            edges.append(.init(
                id: expense.id,
                debtorMemberID: debtor,
                creditorMemberID: expense.paidByMemberID,
                currencyCode: expense.currencyCode
            ))
        }
        return OpeningBalanceEdgeLogic.replaceable(
            among: edges, memberA: memberA, memberB: memberB, currencyCode: currencyCode
        ).flatMap { byID[$0.id] }
    }

    /// El saldo inicial que `setOpeningBalance` con estos datos EDITARÍA en vez de crear otro, o `nil` (lote 2.3 de Grupos,
    /// 10-nov). El formulario lo pregunta antes de guardar: hasta entonces el reemplazo pasaba sin avisar. Sigue el mismo
    /// camino que `setOpeningBalance`: el de esa pareja y moneda (`openingBalanceToReplace`), salvo que un pago confirmado
    /// no deje editarlo (entonces el nuevo va aparte y no reemplaza nada). Solo lee.
    func openingBalanceThatAddingWouldReplace(
        in group: SplitGroup,
        debtorMemberID: String,
        creditorMemberID: String,
        currencyCode: String
    ) throws -> SplitExpense? {
        // Las mismas comprobaciones que `setOpeningBalance` hace antes de mirar nada: en un grupo congelado o sin permiso,
        // el aviso de por qué no se puede, no la pregunta.
        try validateGroupIsWritable(group)
        try validateCurrentUserCanManageOpeningBalances(in: group)
        guard debtorMemberID != creditorMemberID,
              let existing = try openingBalanceToReplace(
                in: group, memberA: debtorMemberID, memberB: creditorMemberID, currencyCode: currencyCode
              ) else { return nil }
        let locked = try openingBalanceEditIsLocked(
            existing, in: group, debtorMemberID: debtorMemberID, creditorMemberID: creditorMemberID
        )
        return locked ? nil : existing
    }

    /// Quién debe en un saldo inicial: su única share. `nil` si no se puede leer.
    func openingBalanceDebtorMemberID(of expense: SplitExpense) -> String? {
        do {
            return try fetchShares(for: expense).first?.memberID
        } catch {
            #if DEBUG
            print("GroupExpenseService: Error: no se pudo leer el deudor del saldo inicial: \(error)")
            #endif
            return nil
        }
    }

    /// El guard de `updateOpeningBalance`, compartido con la pregunta de reemplazo para que no diverjan: sobre la UNIÓN del
    /// par ORIGINAL (lo que se va a mutar) y el par NUEVO.
    private func openingBalanceEditIsLocked(
        _ expense: SplitExpense,
        in group: SplitGroup,
        debtorMemberID: String,
        creditorMemberID: String
    ) throws -> Bool {
        let oldEdgeMembers = Set(try fetchShares(for: expense).map(\.memberID) + [expense.paidByMemberID])
        let guardMembers = oldEdgeMembers.union([debtorMemberID, creditorMemberID])
        return try confirmedSettlementsBlock(forMembers: guardMembers, in: group)
    }

    /// Actualiza un saldo inicial existente (el dueño o un admin). Guard targeted: bloquea si una
    /// liquidación confirmada involucra al deudor o al acreedor de esta arista.
    /// `date` es la fecha del saldo (card t3fq): editarlo ya no lo devuelve a `group.createdAt`.
    func updateOpeningBalance(
        _ expense: SplitExpense,
        in group: SplitGroup,
        debtorMemberID: String,
        creditorMemberID: String,
        amount: Double,
        currencyCode: String,
        date: Date
    ) throws {
        // Card jqgy: el freeze antes que el permiso y que el guard de liquidaciones (ver `setOpeningBalance`).
        try validateGroupIsWritable(group)
        try validateCurrentUserCanManageOpeningBalances(in: group)
        guard debtorMemberID != creditorMemberID else { throw GroupExpenseServiceError.invalidOpeningBalanceMembers }
        // Guard sobre la UNIÓN del par ORIGINAL (lo que se va a mutar/borrar) y el par NUEVO:
        // editar para alejarse de un par ya saldado corromperia ese neto histórico tanto como
        // editar hacia él. (removeOpeningBalance solo necesita el par original.)
        guard try !openingBalanceEditIsLocked(
            expense, in: group, debtorMemberID: debtorMemberID, creditorMemberID: creditorMemberID
        ) else {
            throw GroupExpenseServiceError.expenseHasAssociatedSettlements
        }

        try updateExpense(
            expense,
            in: group,
            amount: amount,
            currencyCode: currencyCode,
            description: L10n.Groups.OpeningBalance.entryDescription,
            note: nil,
            date: OpeningBalanceEdgeLogic.storedDate(date, now: Date.now),
            paidByMemberID: creditorMemberID,
            splitType: "exact",
            subcategoryName: nil,
            shares: [(memberID: debtorMemberID, amount: amount)],
            accountForCurrentUser: nil
        )
    }

    /// Elimina un saldo inicial existente (el dueño o un admin). Guard targeted (ver `updateOpeningBalance`).
    /// NO usa el guard global de `deleteExpense` (que bloquearía con cualquier liquidación,
    /// porque los saldos de antes de la card t3fq van fechados en `group.createdAt`, y los de después en la
    /// fecha que se eligió, que puede ser anterior a cualquier liquidación).
    func removeOpeningBalance(_ expense: SplitExpense, in group: SplitGroup) throws {
        try validateGroupIsWritable(group)   // G6-3: no pasa por validateCurrentUserCanWrite (guard explícito).
        try validateCurrentUserCanManageOpeningBalances(in: group)
        let context = try requireContext()

        let debtorIDs = try fetchShares(for: expense).map(\.memberID)
        let edgeMembers = Set(debtorIDs + [expense.paidByMemberID])
        guard try !confirmedSettlementsBlock(forMembers: edgeMembers, in: group) else {
            throw GroupExpenseServiceError.expenseHasAssociatedSettlements
        }

        try performExpenseDeletion(expense, in: group, context: context)
    }

    /// Card yd2w (2026-10-31): gestiona los saldos iniciales el dueño o cualquier admin ACTIVO del grupo, no solo el
    /// dueño. Decide `OpeningBalancePermissionLogic`, la misma función que pinta los botones
    /// (`GroupDetailViewModel.isOpeningBalanceManager`): si divergieran, la UI enseñaría algo que el guardado rechaza.
    /// El dueño pasa sin leer los miembros, como antes: así una lectura que falle no le quita lo que ya tenía.
    private func validateCurrentUserCanManageOpeningBalances(in group: SplitGroup) throws {
        if group.isOwner { return }
        // Card hfhs: la misma decisión que el botón, la del servidor en un grupo del backend.
        guard OpeningBalancePermissionLogic.canManage(
            group: group, members: try GroupService.shared.fetchMembers(for: group)
        ) else {
            throw GroupExpenseServiceError.notAdmin
        }
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

    #if DEBUG
    /// Seam de tests: el próximo guardado de un pago nuevo falla, para medir que reintentar no deja dos. Se apaga solo
    /// tras usarse; estático, así que resetéalo en `defer`.
    static var _testFailNextSettlementSave = false
    #endif

    /// Create a settlement (payment from one member to another).
    @discardableResult
    /// Crea un settlement. A0-Bridge: si `accountForCurrentUser` proveído (Caso C proactivo
    /// con cuenta seleccionada en form) Y settlement nace con `isConfirmed=true`,
    /// el bridge se invoca al instante. Sino, el bridge se dispara en `confirmSettlement`.
    ///
    /// `confirmed: true` (ticket `settlement-retry-after-a-failed-confirmation-duplicates-the-payment`): «Apuntar pago»
    /// nace confirmado en un solo guardado. Hasta el 2026-11-10 creaba y luego confirmaba con otro guardado; si fallaba el
    /// segundo, la hoja dejaba reintentar con el pago ya creado y quedaban dos. Si el guardado falla, el pago se retira
    /// del contexto: sin eso seguiría pendiente de insertar y el siguiente guardado (el del reintento) lo escribiría junto
    /// al nuevo.
    func createSettlement(
        in group: SplitGroup,
        fromMemberID: String,
        toMemberID: String,
        amount: Double,
        currencyCode: String,
        note: String?,
        date: Date,
        accountForCurrentUser: Account? = nil,
        confirmed: Bool = false
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
        settlement.isConfirmed = confirmed
        context.insert(settlement)

        do {
            #if DEBUG
            if Self._testFailNextSettlementSave {
                Self._testFailNextSettlementSave = false
                throw CocoaError(.fileWriteUnknown)
            }
            #endif
            try context.save()
        } catch {
            context.delete(settlement)
            throw GroupExpenseServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()

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
    /// El trío opening-balance (dueño o admin, card yd2w) también lo respeta, y desde la card jqgy los tres lo llaman
    /// PRIMERO (alta, edición y borrado), antes del permiso y del guard de liquidaciones: así el rechazo dice «se movió».
    func validateGroupIsWritable(_ group: SplitGroup) throws {
        if group.isMigratedFrozen { throw GroupExpenseServiceError.movedToBackend }
    }

    /// `SplitMember.id.uuidString` del usuario actual en el grupo (para atribuir "quién hizo el cambio"
    /// en las notificaciones y autoexcluir el eco). Resuelto en el contexto del propio servicio
    /// (`GroupService.fetchMembers`, igual que `validateCurrentUserCanWrite`).
    ///
    /// DEBE resolver el MISMO id que el consumidor `GroupNotificationService.currentMemberID(inZone:)`
    /// (resolución CANÓNICA: entre los members `isCurrentUser`, el de `joinedAt` más antiguo — mismo
    /// criterio que su `FetchDescriptor` sortBy joinedAt + fetchLimit 1). Un tie-break distinto (p.ej. `first(where:)` sobre el orden de `fetchMembers`
    /// por displayName) elegiría OTRO id bajo members `isCurrentUser` DUPLICADOS → el write-side y el
    /// clasificador guardarían/compararían ids distintos y el eco NO se autoexcluiría.
    ///
    /// Fallbacks (ventana temprana: 2º device / restore de iCloud, `isCurrentUser` aún no marcado porque es
    /// device-local y `refreshCurrentUserFlags` no ha corrido): por identidad del canal BACKEND
    /// (`userID`/`memberKey == sub`) y por identidad iCloud (`cloudKitUserRecordID == cachedRecordName`),
    /// las MISMAS dos fuentes que `refreshCurrentUserFlags` usa para marcar `isCurrentUser`. Así el eco se
    /// autoexcluye aunque el flag llegue tarde (sin esto, el owner en esa ventana guardaba nil y recibía
    /// "otro actualizó" por su propia edición — el bug reportado).
    /// nil solo si tampoco hay ninguna de las dos identidades (primer arranque sin resolver) ⇒ ahí el
    /// consumidor tampoco resuelve currentMemberID ⇒ `expenseDecision` skipea (sin notif).
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
            cachedRecordName: GroupUserIdentityService.shared.cachedRecordName,
            currentUserID: CloudSyncFlags.groupsBackendEnabled ? CloudAuthService.shared.currentUserID : nil
        )
    }

    /// Selección pura del `SplitMember.id.uuidString` del usuario actual (extraída para test sin contexto).
    /// Resolución CANÓNICA — DEBE espejar `GroupNotificationService.currentMemberID(inZone:)` (isCurrentUser
    /// con `joinedAt` más antiguo). Dos fallbacks para la ventana temprana, en este orden:
    ///
    ///  1. **Canal backend** (2.6): `userID`/`memberKey == sub` de la sesión Yala. `GroupsSyncClient
    ///     .applyMember` NUNCA setea `isCurrentUser` (lo dice `GroupJoinReconciler:115`/`:156`), así que en
    ///     el canal nuevo el flag solo lo enciende `refreshCurrentUserFlags` DESPUÉS — hasta entonces esta
    ///     función devolvía nil y el eco de la propia edición no se autoexcluía. Va ANTES que el fallback
    ///     iCloud porque en un grupo del canal nuevo la identidad autoritativa es el `sub`.
    ///  2. **Identidad iCloud** (`cloudKitUserRecordID == cachedRecordName`), la MISMA fuente que
    ///     `refreshCurrentUserFlags` usa para marcar `isCurrentUser` en el canal CloudKit.
    ///
    /// `isCurrentUser` conserva la PRIMERA posición a propósito: es lo que mantiene la simetría con
    /// `currentMemberID(inZone:)`, que resuelve solo por ese flag. Adelantar el match backend divergiría
    /// de él en una zona con el member legacy Y el backend del mismo humano.
    ///
    /// `currentUserID` nil (flag `groupsBackendEnabled` OFF, o sin sesión) ⇒ el paso 1 no matchea NADA y la
    /// función es byte-idéntica a la de antes. Ver el doc de `currentUserMemberID(in:)` para el resto.
    static func selectCurrentUserMemberID(
        from members: [SplitMember],
        cachedRecordName: String?,
        currentUserID: String? = nil
    ) -> String? {
        selectCurrentUserMember(
            from: members, cachedRecordName: cachedRecordName, currentUserID: currentUserID
        )?.id.uuidString
    }

    /// La PRIMITIVA de la resolución canónica: el mismo orden de criterios y el mismo desempate,
    /// devolviendo el miembro en vez de su id. `selectCurrentUserMemberID` delega aquí para que las
    /// dos no puedan divergir — que es exactamente el modo de fallo que esta tanda vino a cerrar:
    /// once sitios resolviendo identidad de once maneras.
    ///
    /// Existe porque casi todos los consumidores necesitan el MIEMBRO (su `memberStatus`, su
    /// `role`, su `isActive`), no su id, y con solo la variante `...ID` cada uno se fabricaba su
    /// propio `first { $0.isCurrentUser }` para recuperarlo — volviendo al punto de partida.
    static func selectCurrentUserMember(
        from members: [SplitMember],
        cachedRecordName: String?,
        currentUserID: String? = nil
    ) -> SplitMember? {
        if let current = members.filter({ $0.isCurrentUser }).min(by: { $0.joinedAt < $1.joinedAt }) {
            return current
        }
        if let byBackendIdentity = members.filter({
            GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
                memberUserID: $0.userID, memberKey: $0.memberKey, currentUserID: currentUserID)
        }).min(by: { $0.joinedAt < $1.joinedAt }) {
            return byBackendIdentity
        }
        if let recordName = cachedRecordName, !recordName.isEmpty,
           let byIdentity = members.filter({ $0.cloudKitUserRecordID == recordName })
                                   .min(by: { $0.joinedAt < $1.joinedAt }) {
            return byIdentity
        }
        return nil
    }

    /// Resolución canónica de identidad para el proceso vivo, con las dos fuentes ya cableadas.
    /// Es el molde que `GroupSettingsView.hasOutstandingBalance` escribía a mano, extraído para que
    /// los consumidores no tengan que acordarse del gate de `groupsBackendEnabled` — olvidarlo
    /// devuelve nil justo en el canal donde hace falta.
    static func resolveCurrentUserMember(from members: [SplitMember]) -> SplitMember? {
        selectCurrentUserMember(
            from: members,
            cachedRecordName: GroupUserIdentityService.shared.cachedRecordName,
            currentUserID: CloudSyncFlags.groupsBackendEnabled ? CloudAuthService.shared.currentUserID : nil
        )
    }

    /// TODAS mis filas de una zona, sin colapsar. La variante PLURAL de la resolución canónica.
    ///
    /// Existe porque no todos los consumidores preguntan lo mismo. La mayoría pregunta «¿cuál es mi
    /// miembro?» y `resolveCurrentUserMember` contesta con UNO —desempatando por `joinedAt`— para que
    /// el write-side y el read-side no puedan elegir filas distintas. Pero un par de sitios preguntan
    /// «¿cuáles son mis filas?», que es POR FILA, y ahí colapsar no es un detalle: en una zona migrada
    /// el mismo humano tiene su member CloudKit legacy Y el born-backend, y quedarse con uno deja al
    /// otro sin tocar para siempre.
    ///
    /// Mismos tres criterios que `selectCurrentUserMember`, en OR en vez de en cascada. Nunca devuelve
    /// una fila que no sea mía: los dos fallbacks exigen identidad exacta y no vacía.
    static func resolveAllCurrentUserMembers(from members: [SplitMember]) -> [SplitMember] {
        let cachedRecordName = GroupUserIdentityService.shared.cachedRecordName
        let currentUserID = CloudSyncFlags.groupsBackendEnabled
            ? CloudAuthService.shared.currentUserID : nil
        return members.filter { member in
            if member.isCurrentUser { return true }
            if GroupJoinReconcileLogic.backendMemberMatchesCurrentUser(
                memberUserID: member.userID, memberKey: member.memberKey,
                currentUserID: currentUserID) { return true }
            if let recordName = cachedRecordName, !recordName.isEmpty,
               member.cloudKitUserRecordID == recordName { return true }
            return false
        }
    }

    /// La misma resolución canónica, para los consumidores que hasta ahora la escribían como un
    /// `FetchDescriptor` con `isCurrentUser == true` metido en el `#Predicate`.
    ///
    /// Existe porque esa forma NO es convertible: `resolveCurrentUserMember(from:)` lee estado de
    /// sesión (`sub`) y de iCloud (`recordName`), y SwiftData no puede traducir eso a SQL. Sustituir
    /// la línea dentro del predicado es imposible, así que cada consumidor tenía que acordarse de
    /// traerse los members de la zona y resolver en memoria — y ninguno se acordó. El resultado era
    /// que al recién llegado a un grupo, cuyo `SplitMember` baja del pull con `isCurrentUser`
    /// APAGADO (`GroupsSyncClient.applyMember` nunca lo escribe, y `refreshCurrentUserFlags` solo
    /// corre en el arranque), estos consumidores lo daban por no-miembro: su gasto no llegaba a sus
    /// cuentas, su saldo salía vacío y sus avisos de grupo se descartaban en silencio.
    ///
    /// El fetch trae los members de UNA zona (2-10 filas en la práctica), no los del dispositivo:
    /// esto NO es el `refreshCurrentUserFlags` device-wide, no escribe nada y no arrastra su
    /// backfill heurístico por `displayName`. Es una lectura.
    ///
    /// Propaga el error del fetch en vez de tragárselo: los callers no coinciden en qué hacer con él
    /// (`ScheduledPaymentDraftService` reintenta, `GroupNotificationService` evita envenenar su
    /// caché), y decidirlo aquí les quitaría esa distinción.
    static func resolveCurrentUserMember(
        inZone zoneID: String,
        context: ModelContext
    ) throws -> SplitMember? {
        // `sortBy` explícito: el desempate de `selectCurrentUserMember` es `min(by: joinedAt)`, y ante
        // un empate exacto `min` devuelve el primero DEL ARRAY. Sin ordenar, ese primero lo decidía el
        // orden del store, mientras los demás consumidores canónicos resuelven sobre el array ya
        // ordenado de `GroupService.fetchMembers`. Con dos filas mías empatadas al milisegundo, eso
        // bastaba para que el formulario marcara como pagador una fila y el bridge resolviera la otra.
        let members = try context.fetch(FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
        ))
        return resolveCurrentUserMember(from: members)
    }

    private func validateCurrentUserCanWrite(in group: SplitGroup) throws {
        try validateGroupIsWritable(group)
        let members = try GroupService.shared.fetchMembers(for: group)
        // Identidad RESUELTA, no el flag pelado: si la UI ya reconoce al usuario y este gate no,
        // el FAB aparece y el guardado lo rechaza — «ves algo que no funciona», que es peor que no
        // verlo. Los dos lados tienen que decidir con el mismo criterio.
        guard let current = Self.resolveCurrentUserMember(from: members) else {
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
    /// Solo el dueño o un admin del grupo puede gestionar saldos iniciales (card yd2w; hasta el 2026-10-31, solo el dueño).
    case notAdmin
    /// Un saldo inicial necesita dos miembros distintos (deudor ≠ acreedor).
    case invalidOpeningBalanceMembers
    /// G6-3: el grupo se migró a la nube de Yala y está congelado en este device — hay que volver a entrar.
    case movedToBackend
    /// El registro ya no se puede pasar a un grupo (ya es de otro grupo, cambió o dejó de ser un gasto personal).
    case notConvertible
    /// El grupo se eliminó o se archivó con la revisión abierta.
    case groupUnavailable
    /// El puente no puede atender el gasto ahora (Grupos cerrado en este dispositivo, o tu miembro aún sin resolver).
    case bridgeUnavailable
    case saveFailed(Error)

    /// Lo que ve la persona. Los casos de programación (contexto, importes, repartos) y el fallo al
    /// guardar dicen el genérico localizado: hasta el lote 13 eran textos de desarrollo en inglés y
    /// varias pantallas los enseñaban tal cual. El detalle técnico queda en los `print` de DEBUG.
    var errorDescription: String? {
        switch self {
        case .noContext:
            return L10n.Groups.Errors.actionFailed
        case .invalidAmount:
            return L10n.Groups.Errors.actionFailed
        case .noShares:
            return L10n.Groups.Errors.actionFailed
        case .sharesSumMismatch:
            return L10n.Groups.Errors.actionFailed
        case .noPayer:
            return L10n.Groups.Errors.actionFailed
        case .selfSettlement:
            return L10n.Groups.Errors.actionFailed
        case .inactiveMember:
            return L10n.Groups.Errors.actionFailed
        case .pendingApproval:
            return L10n.Groups.Errors.pendingApproval
        case .expenseHasAssociatedSettlements:
            return L10n.Groups.Bridge.deleteExpenseBlocked
        case .notAdmin:
            return L10n.Groups.OpeningBalance.errorNotAdmin
        case .invalidOpeningBalanceMembers:
            return L10n.Groups.OpeningBalance.errorSameMember
        case .movedToBackend:
            return L10n.Groups.Errors.movedToBackend
        case .notConvertible, .groupUnavailable, .bridgeUnavailable:
            return L10n.Groups.Errors.actionFailed
        case .saveFailed:
            return L10n.Groups.Errors.actionFailed
        }
    }
}
