//
//  GroupTransactionBridge.swift
//  Yala
//
//  Bridge between shared expenses and personal TransactionItem/InboxDraft.
//  Creates/updates/removes personal records when group expenses change.
//

import Foundation
import OSLog
import SwiftData

@MainActor
@Observable
final class GroupTransactionBridge {

    // MARK: - Singleton

    static let shared = GroupTransactionBridge()

    // MARK: - Properties

    private var modelContext: ModelContext?
    private static let logger = Logger(subsystem: "com.yala", category: "GroupBridge")

    /// Whether the bridge has been initialized with a context.
    var isReady: Bool { modelContext != nil }

    /// M6: Flag interno para que `withSkippedDraftCleanup` permita que
    /// `DraftService.approveGroupExpenseAccountDraft` invoque `bridgeExpense` sin que el
    /// bridge borre el draft activo. NO setear directamente — usar el closure helper.
    private(set) var skipDraftCleanup: Bool = false

    /// Ejecuta `body` con `skipDraftCleanup=true` y resetea garantizado vía `defer`,
    /// incluso si `body` lanza. Único path autorizado para mutar el flag.
    func withSkippedDraftCleanup<T>(_ body: () throws -> T) rethrows -> T {
        skipDraftCleanup = true
        defer { skipDraftCleanup = false }
        return try body()
    }

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw GroupTransactionBridgeError.noContext
        }
        return context
    }

    // MARK: - Bridge Operations

    /// M6: Bridge SplitExpense ↔ TransactionItem con preserve+update Caso A.
    ///
    /// **Caso A** (yo pago, modo `.full/.completed`):
    /// - **TX cuenta REAL** (`-totalAmount` con subcat manual): refleja "salió de mi bolsillo"
    ///   en mi cuenta personal. Si ya existe Y currency compatible → **preserve+update** (solo
    ///   monto/fecha/splitTotalAmount/splitType; cuenta/subcat/note/tags/category INTACTOS).
    ///   Si currency incompatible → delete + draft con hint "currencyChanged".
    /// - **TX virtual lent** (`+lentAmount` sistema "Préstamo a grupos"): siempre derivada,
    ///   delete+recreate. Skip si `lentAmount == 0` (yo solo en split).
    ///
    /// **Caso A modo `.groupInvite`** (sin cuentas reales): fallback a M5 puro — TX1 virtual
    /// `-myShare` con subcat manual + TX2 virtual `+totalAmount` sistema. Sin TX cuenta real.
    ///
    /// **Caso B** (paga otro): TX1 virtual `-myShare` con subcat manual o nil. Sin cambios M5.
    ///
    /// **Auto-match subcat**: si falla Y Caso B (o A groupInvite): draft con TX-puntero. En
    /// Caso A `.full/.completed` la TX cuenta real se crea con subcat=nil + draft con puntero
    /// (path heredado M5 para subcat assignment via Inbox).
    ///
    /// **Idempotency Caso A `.full/.completed`**: TX cuenta real preservada cross-reinvocación.
    /// **Idempotency demás**: delete+recreate normal (todas las TX son derivadas).
    ///
    /// **Race race con DraftService.approve**: si `skipDraftCleanup == true`, el cleanup de
    /// `existingPendingDrafts` se omite (DraftService gestiona el draft activo).
    ///
    /// - Parameters:
    ///   - expense: The shared expense to bridge.
    ///   - group: The group containing the expense.
    ///   - accountForCurrentUser: Cuenta real para Caso A `.full/.completed` (form/draft input).
    ///     `nil` cuando el bridge se invoca por sync remoto o cuando user no proveyó (groupInvite, draft pending).
    ///   - isRemoteSync: `true` cuando se invoca desde `bridgeRemoteExpenses` (sync de grupos).
    ///     Distingue path local vs sync para guard defensivo.
    ///   - shouldSave: Whether to save the context (false when called from sync batch).
    func bridgeExpense(
        _ expense: SplitExpense,
        in group: SplitGroup,
        accountForCurrentUser: Account? = nil,
        isRemoteSync: Bool = false,
        shouldSave: Bool = true
    ) throws {
        let context = try requireContext()

        // Find current user's member in this group.
        // pending/rejected members no triguean bridge.
        let zoneID = group.cloudKitZoneID
        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
        )
        guard let currentMember = try context.fetch(memberDescriptor).first,
              currentMember.isActive else { return }
        let currentMemberID = currentMember.id.uuidString

        // Find current user's share in this expense.
        let expenseID = expense.id
        let shareDescriptor = FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == currentMemberID }
        )
        guard let myShare = try context.fetch(shareDescriptor).first else { return }

        // Identidad y cantidades.
        let expenseIDStr = expense.id.uuidString
        let isCaseA = expense.paidByMemberID == currentMemberID
        let isGroupInvite = SessionState.shared.onboardingMode == .groupInvite
        let totalAmount = expense.amount
        let mySharedAmount = myShare.amount
        let lentAmount = totalAmount - mySharedAmount

        // Fetch existing entities.
        let allExistingTxs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))
        let existingVirtualTxs = allExistingTxs.filter { $0.account?.isSystemAccount == true }
        var existingRealTx = allExistingTxs.first { $0.account?.isSystemAccount == false }

        let existingPendingDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))

        // Cleanup: TX virtuales son derivadas, siempre delete+recreate.
        for tx in existingVirtualTxs { context.delete(tx) }
        // Drafts pendientes: cleanup salvo si DraftService los está procesando (race).
        if !skipDraftCleanup {
            for draft in existingPendingDrafts { context.delete(draft) }
        }

        // Resolve cuenta virtual + subcat.
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: expense.currencyCode,
            colorHint: group.colorHex,
            context: context
        )
        let matchedSubcat = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)
        let realSubcat: Subcategory? = (matchedSubcat?.isAnySystem == true) ? nil : matchedSubcat

        // Path Caso B (otro pagó): cleanup TX cuenta real residual + TX virtual -myShare como M5.
        if !isCaseA {
            if let stale = existingRealTx { context.delete(stale) }
            createCaseBVirtualMyShare(
                expense: expense,
                myShareAmount: mySharedAmount,
                realSubcat: realSubcat,
                virtualAccount: virtualAccount,
                context: context
            )
            try saveIfNeeded(shouldSave: shouldSave, context: context)
            return
        }

        // Path Caso A modo .groupInvite: fallback M5 puro (TX1 virtual -myShare + TX2 virtual +totalAmount).
        if isGroupInvite {
            if let stale = existingRealTx { context.delete(stale) }
            createGroupInviteCaseAVirtualPair(
                expense: expense,
                myShareAmount: mySharedAmount,
                lentAmount: lentAmount,
                totalAmount: totalAmount,
                realSubcat: realSubcat,
                virtualAccount: virtualAccount,
                context: context
            )
            try saveIfNeeded(shouldSave: shouldSave, context: context)
            return
        }

        // Path Caso A modo .full/.completed: gestionar TX cuenta real con preserve+update.
        if let realTx = existingRealTx {
            if realTx.currencyCode == expense.currencyCode {
                // PRESERVE+UPDATE: actualizar SOLO campos del grupo.
                realTx.amount = -totalAmount
                realTx.date = expense.date
                realTx.splitTotalAmount = totalAmount
                realTx.splitType = expense.splitType
                // NUNCA tocar: account, subcategory, category, note, tags, currencyCode.
            } else {
                // INCOMPATIBLE currency: delete TX real + draft hint impersonal.
                context.delete(realTx)
                existingRealTx = nil
                createDraftCaseA(
                    expense: expense,
                    reason: .currencyChanged,
                    actorName: nil,  // sync remoto no expone "modifiedBy" → impersonal.
                    groupName: group.name,
                    context: context
                )
            }
        } else if let providedAccount = accountForCurrentUser,
                  providedAccount.currencyCode == expense.currencyCode {
            // PRIMERA VEZ con cuenta proveída (form local crea, o DraftService.approve).
            let realTx = TransactionItem(
                date: expense.date,
                amount: -totalAmount,
                currencyCode: expense.currencyCode,
                note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
                category: realSubcat?.safeCategory,
                subcategory: realSubcat,
                account: providedAccount
            )
            realTx.splitExpenseID = expenseIDStr
            realTx.splitGroupZoneID = expense.groupZoneID
            realTx.splitTotalAmount = totalAmount
            realTx.splitType = expense.splitType
            context.insert(realTx)
            realTx.recalculatePreferredCurrency(context: context)
        } else if isRemoteSync {
            // Sync remoto sin cuenta local: draft pendiente con hint contextual.
            let payerName = resolveMemberDisplayName(memberID: expense.paidByMemberID, in: group, context: context)
            createDraftCaseA(
                expense: expense,
                reason: .remoteCreate,
                actorName: payerName,
                groupName: group.name,
                context: context
            )
        } else {
            // Path local sin cuenta: F4.canSave debió bloquear el form. Defensa profundidad.
            #if DEBUG
            assertionFailure("Caso A local sin cuenta — F4 canSave debió bloquear el form")
            #endif
            createDraftCaseA(
                expense: expense,
                reason: .remoteCreate,  // copy más cercano disponible
                actorName: nil,
                groupName: group.name,
                context: context
            )
        }

        // TX virtual lent (+lentAmount) — siempre regenerada en Caso A `.full/.completed`. Skip si lent==0.
        if lentAmount > 0 {
            let loanSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context)
            let virtualLent = TransactionItem(
                date: expense.date,
                amount: lentAmount,  // M6: lent (no totalAmount como M5).
                currencyCode: expense.currencyCode,
                note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
                category: loanSubcat.safeCategory,
                subcategory: loanSubcat,
                account: virtualAccount
            )
            virtualLent.splitExpenseID = expenseIDStr
            virtualLent.splitGroupZoneID = expense.groupZoneID
            virtualLent.splitTotalAmount = totalAmount  // ref al gasto total origen.
            virtualLent.splitType = expense.splitType
            context.insert(virtualLent)
            virtualLent.recalculatePreferredCurrency(context: context)
        }

        try saveIfNeeded(shouldSave: shouldSave, context: context)
    }

    // MARK: - Helpers (M6)

    /// Caso B (otro pagó): TX virtual -myShare con subcat manual o draft TX-puntero.
    private func createCaseBVirtualMyShare(
        expense: SplitExpense,
        myShareAmount: Double,
        realSubcat: Subcategory?,
        virtualAccount: Account,
        context: ModelContext
    ) {
        let expenseIDStr = expense.id.uuidString
        let tx = TransactionItem(
            date: expense.date,
            amount: -myShareAmount,
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: realSubcat?.safeCategory,
            subcategory: realSubcat,
            account: virtualAccount
        )
        tx.splitExpenseID = expenseIDStr
        tx.splitGroupZoneID = expense.groupZoneID
        tx.splitTotalAmount = expense.amount
        tx.splitType = expense.splitType
        context.insert(tx)
        tx.recalculatePreferredCurrency(context: context)

        // Draft TX-puntero para asignar subcat si auto-match falló (path heredado M5).
        if realSubcat == nil {
            let draft = InboxDraft(
                note: expense.expenseDescription,
                amount: -myShareAmount,
                date: expense.date,
                account: virtualAccount,
                subcategory: nil,
                sourceType: .groupExpense,
                confidenceAmount: 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: 1.0,
                confidenceSubcategory: nil,
                needsUserInput: [DraftInputRequirement.subcategory],
                splitExpenseID: expenseIDStr,
                splitGroupZoneID: expense.groupZoneID,
                splitSettlementID: nil,
                targetTransactionID: nil
            )
            context.insert(draft)
        }
    }

    /// Caso A modo .groupInvite: M5 puro (TX1 virtual -myShare + TX2 virtual +totalAmount sistema).
    private func createGroupInviteCaseAVirtualPair(
        expense: SplitExpense,
        myShareAmount: Double,
        lentAmount: Double,
        totalAmount: Double,
        realSubcat: Subcategory?,
        virtualAccount: Account,
        context: ModelContext
    ) {
        let expenseIDStr = expense.id.uuidString
        // TX1 virtual -myShare.
        let tx1 = TransactionItem(
            date: expense.date,
            amount: -myShareAmount,
            currencyCode: expense.currencyCode,
            note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
            category: realSubcat?.safeCategory,
            subcategory: realSubcat,
            account: virtualAccount
        )
        tx1.splitExpenseID = expenseIDStr
        tx1.splitGroupZoneID = expense.groupZoneID
        tx1.splitTotalAmount = totalAmount
        tx1.splitType = expense.splitType
        context.insert(tx1)
        tx1.recalculatePreferredCurrency(context: context)

        if realSubcat == nil {
            let draft = InboxDraft(
                note: expense.expenseDescription,
                amount: -myShareAmount,
                date: expense.date,
                account: virtualAccount,
                subcategory: nil,
                sourceType: .groupExpense,
                confidenceAmount: 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: 1.0,
                confidenceSubcategory: nil,
                needsUserInput: [DraftInputRequirement.subcategory],
                splitExpenseID: expenseIDStr,
                splitGroupZoneID: expense.groupZoneID,
                splitSettlementID: nil,
                targetTransactionID: nil
            )
            context.insert(draft)
        }

        // TX2 virtual +totalAmount sistema (préstamo). Skip si lent==0.
        if lentAmount > 0 {
            if let loanSubcat = try? GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context) {
                let tx2 = TransactionItem(
                    date: expense.date,
                    amount: totalAmount,
                    currencyCode: expense.currencyCode,
                    note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
                    category: loanSubcat.safeCategory,
                    subcategory: loanSubcat,
                    account: virtualAccount
                )
                tx2.splitExpenseID = expenseIDStr
                tx2.splitGroupZoneID = expense.groupZoneID
                tx2.splitTotalAmount = totalAmount
                tx2.splitType = expense.splitType
                context.insert(tx2)
                tx2.recalculatePreferredCurrency(context: context)
            }
        }
    }

    /// M6: Crea InboxDraft pendiente de cuenta para Caso A cuando bridge no puede crear TX real.
    private func createDraftCaseA(
        expense: SplitExpense,
        reason: DraftOriginReason,
        actorName: String?,
        groupName: String,
        context: ModelContext
    ) {
        let draft = InboxDraft(
            note: expense.expenseDescription,
            amount: -expense.amount,
            date: expense.date,
            account: nil,
            subcategory: nil,
            sourceType: .groupExpense,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            confidenceSubcategory: nil,
            needsUserInput: [DraftInputRequirement.account],
            splitExpenseID: expense.id.uuidString,
            splitGroupZoneID: expense.groupZoneID,
            splitSettlementID: nil,
            targetTransactionID: nil,
            originReasonKey: reason.rawValue,
            originActorName: actorName,
            originGroupName: groupName
        )
        context.insert(draft)
    }

    /// Resolver displayName del miembro pagador (snapshot al crear draft).
    private func resolveMemberDisplayName(memberID: String, in group: SplitGroup, context: ModelContext) -> String? {
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.id.uuidString == memberID }
        )
        return try? context.fetch(descriptor).first?.displayName
    }

    private func saveIfNeeded(shouldSave: Bool, context: ModelContext) throws {
        guard shouldSave else { return }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        Task { await BudgetAlertService.shared.checkBudgetsAndNotify() }
    }

    /// Bridge remote expenses received in a sync batch. Called after context.save().
    func bridgeRemoteExpenses(_ expenses: [SplitExpense]) throws {
        let context = try requireContext()

        for expense in expenses {
            // Find the group for this expense
            let zoneID = expense.groupZoneID
            let groupDescriptor = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            guard let group = try context.fetch(groupDescriptor).first else { continue }

            do {
                // M6: isRemoteSync=true marca path remoto. Sin accountForCurrentUser local
                // → bridge crea draft pendiente con hint si Caso A y no existe TX real.
                try bridgeExpense(expense, in: group, accountForCurrentUser: nil, isRemoteSync: true, shouldSave: false)
            } catch {
                #if DEBUG
                print("GroupTransactionBridge: Failed to bridge expense \(expense.id): \(error)")
                #endif
            }
        }

        try context.save()
        // UI refresh handled by SplitSyncManager's deferred markRemoteChangePending()
    }

    // MARK: - Settlement Bridge (A0-Bridge: Caso C + D)

    /// A0-Bridge: bridge para settlements. Solo procesa si `settlement.isConfirmed == true`.
    ///
    /// **Caso C** (yo `from`): TX1 virtual `+amount` con sistema "Pago de liquidación" (income).
    /// Si `userType ∈ .full|.completed` Y `accountForCurrentUser != nil`:
    ///   TX2 cuenta real `-amount` con sistema "Liquidación enviada" (expense).
    ///   + persiste defaultSettlementAccount preference.
    /// Si cuenta proveída es nil (form skipped): InboxDraft `groupSettlement` con
    ///   subcategory="Liquidación enviada", account=nil, splitSettlementID.
    /// Si `userType == .groupInvite`: solo TX1 virtual; NO draft. UI muestra toast upsell.
    ///
    /// **Caso D** (yo `to`, reactivo): TX1 virtual `-amount` con sistema "Cobro de préstamo" (expense).
    /// Si `.full|.completed`: InboxDraft `groupSettlement` con subcategory="Liquidación recibida",
    ///   amount=+amount, splitSettlementID. User finaliza desde Inbox para crear TX cuenta real.
    /// Si `.groupInvite`: solo TX1 virtual; NO draft.
    ///
    /// Idempotency: delete + recreate (mismo patrón que bridgeExpense).
    func bridgeSettlement(
        _ settlement: SplitSettlement,
        in group: SplitGroup,
        accountForCurrentUser: Account? = nil,
        shouldSave: Bool = true
    ) throws {
        let context = try requireContext()

        // Solo bridge si confirmed.
        guard settlement.isConfirmed else { return }

        // Find current user.
        // pending/rejected members no triguean bridge.
        let zoneID = group.cloudKitZoneID
        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
        )
        guard let currentMember = try context.fetch(memberDescriptor).first,
              currentMember.isActive else { return }
        let currentMemberID = currentMember.id.uuidString

        // Determinar caso C/D. Skip si user no es from ni to (settlement entre otros).
        let isCaseC = settlement.fromMemberID == currentMemberID
        let isCaseD = settlement.toMemberID == currentMemberID
        guard isCaseC || isCaseD else { return }

        // Idempotency: delete previous TX/Drafts.
        let settlementIDStr = settlement.id.uuidString
        let existingTxs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID == settlementIDStr }
        ))
        for tx in existingTxs { context.delete(tx) }

        let existingDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitSettlementID == settlementIDStr }
        ))
        for draft in existingDrafts { context.delete(draft) }

        let amount = settlement.amount
        let currencyCode = settlement.currencyCode
        let userType = SessionState.shared.onboardingMode

        // Cuenta virtual SIEMPRE se crea (representa saldo del grupo).
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: currencyCode,
            colorHint: group.colorHex,
            context: context
        )

        if isCaseC {
            // TX1 virtual: +amount sistema "Pago de liquidación" (income).
            let payoffSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementPayment, context: context)
            let tx1 = TransactionItem(
                date: settlement.date,
                amount: amount,
                currencyCode: currencyCode,
                note: settlement.note,
                category: payoffSubcat.safeCategory,
                subcategory: payoffSubcat,
                account: virtualAccount
            )
            tx1.splitSettlementID = settlementIDStr
            tx1.splitGroupZoneID = zoneID
            context.insert(tx1)
            tx1.recalculatePreferredCurrency(context: context)

            // TX2 cuenta real solo para .full/.completed.
            if userType != .groupInvite {
                if let account = accountForCurrentUser {
                    let sentSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .settlementSent, context: context)
                    let tx2 = TransactionItem(
                        date: settlement.date,
                        amount: -amount,
                        currencyCode: currencyCode,
                        note: settlement.note,
                        category: sentSubcat.safeCategory,
                        subcategory: sentSubcat,
                        account: account
                    )
                    tx2.splitSettlementID = settlementIDStr
                    tx2.splitGroupZoneID = zoneID
                    context.insert(tx2)
                    tx2.recalculatePreferredCurrency(context: context)
                    // M6: NO defaults — eliminada persistencia de defaultSettlementAccount.
                } else {
                    // Sin cuenta proveída: draft pendiente.
                    let draft = InboxDraft(
                        note: settlement.note ?? "",
                        amount: -amount,
                        date: settlement.date,
                        account: nil,
                        subcategory: try? GroupBridgeSystemEntities.systemSubcategory(role: .settlementSent, context: context),
                        sourceType: .groupSettlement,
                        confidenceAmount: 1.0,
                        confidenceDate: 1.0,
                        confidenceMerchant: 1.0,
                        confidenceSubcategory: 1.0,
                        needsUserInput: [DraftInputRequirement.account],
                        splitExpenseID: nil,
                        splitGroupZoneID: zoneID,
                        splitSettlementID: settlementIDStr,
                        targetTransactionID: nil
                    )
                    context.insert(draft)
                }
            }
        } else if isCaseD {
            // TX1 virtual: -amount sistema "Cobro de préstamo" (expense).
            let collectSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .loanCollection, context: context)
            let tx1 = TransactionItem(
                date: settlement.date,
                amount: -amount,
                currencyCode: currencyCode,
                note: settlement.note,
                category: collectSubcat.safeCategory,
                subcategory: collectSubcat,
                account: virtualAccount
            )
            tx1.splitSettlementID = settlementIDStr
            tx1.splitGroupZoneID = zoneID
            context.insert(tx1)
            tx1.recalculatePreferredCurrency(context: context)

            // Para .full/.completed: draft groupSettlement para asignar cuenta real.
            // M6: NO defaults universales — sin preselect, user siempre elige cuenta.
            if userType != .groupInvite {
                let receivedSubcat = try? GroupBridgeSystemEntities.systemSubcategory(role: .settlementReceived, context: context)
                let draft = InboxDraft(
                    note: settlement.note ?? "",
                    amount: amount,
                    date: settlement.date,
                    account: nil,
                    subcategory: receivedSubcat,
                    sourceType: .groupSettlement,
                    confidenceAmount: 1.0,
                    confidenceDate: 1.0,
                    confidenceMerchant: 1.0,
                    confidenceSubcategory: 1.0,
                    needsUserInput: [DraftInputRequirement.account],
                    splitExpenseID: nil,
                    splitGroupZoneID: zoneID,
                    splitSettlementID: settlementIDStr,
                    targetTransactionID: nil
                )
                context.insert(draft)
            }
        }

        if shouldSave {
            try context.save()
            SessionState.shared.incrementDataVersion()
            WidgetDataCache.updateCache(context: context)
        }
    }

    /// Bridge remote settlements received via sync. Llamado desde SplitSyncManager.
    /// Solo procesa settlements confirmed (skipea unconfirmed).
    func bridgeRemoteSettlements(_ settlements: [SplitSettlement]) throws {
        let context = try requireContext()

        for settlement in settlements {
            let zoneID = settlement.groupZoneID
            let groupDescriptor = FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID }
            )
            guard let group = try context.fetch(groupDescriptor).first else { continue }

            do {
                try bridgeSettlement(settlement, in: group, accountForCurrentUser: nil, shouldSave: false)
            } catch {
                #if DEBUG
                print("GroupTransactionBridge: Failed to bridge settlement \(settlement.id): \(error)")
                #endif
            }
        }

        try context.save()
    }

    /// Remove all bridged TransactionItems and InboxDrafts vinculadas a un settlement.
    func unbridgeSettlement(settlementID: String) throws {
        let context = try requireContext()

        let txs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID == settlementID }
        ))
        for tx in txs { context.delete(tx) }

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitSettlementID == settlementID }
        ))
        for draft in drafts { context.delete(draft) }

        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Remove all bridged TransactionItems and InboxDrafts vinculadas a un expense.
    /// A0-Bridge: el modelo M5 puede crear 1-2 TX por expense + un draft groupExpense
    /// con targetTransactionID. Esta función borra TODAS las entidades con `splitExpenseID == X`.
    func unbridgeExpense(expenseID: String) throws {
        let context = try requireContext()

        let txs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
        for tx in txs { context.delete(tx) }

        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
        for draft in drafts { context.delete(draft) }

        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Remove all bridged records for a group (used when deleting/leaving a group).
    func unbridgeExpenses(for group: SplitGroup) throws {
        let context = try requireContext()
        let zoneID = group.cloudKitZoneID

        let txDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitGroupZoneID == zoneID }
        )
        let transactions = try context.fetch(txDescriptor)
        for tx in transactions { context.delete(tx) }

        let draftDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitGroupZoneID == zoneID }
        )
        let drafts = try context.fetch(draftDescriptor)
        for draft in drafts { context.delete(draft) }

        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    // MARK: - Category Matching

    /// Match a subcategory name to a user's personal Subcategory.
    /// Priority: exact (case-insensitive) → contains → nil.
    static func matchSubcategory(name: String?, context: ModelContext) -> Subcategory? {
        guard let name, !name.isEmpty else { return nil }

        let descriptor = FetchDescriptor<Subcategory>()
        guard let all = (try? context.fetch(descriptor)) else {
            #if DEBUG
            print("GroupTransactionBridge: Subcategory fetch failed")
            #endif
            return nil
        }

        // Exact match (case-insensitive)
        if let exact = all.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return exact
        }

        // Contains match
        if let partial = all.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
            return partial
        }

        return nil
    }

}

// MARK: - Errors

enum GroupTransactionBridgeError: LocalizedError {
    case noContext

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupTransactionBridge: No ModelContext available"
        }
    }
}
