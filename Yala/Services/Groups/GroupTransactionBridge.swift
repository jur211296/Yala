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

    /// A0-Bridge: Create or replace personal TransactionItems for a shared expense (modelo M5).
    ///
    /// Estrategia: idempotency vía delete+recreate. Si ya existen TX/Drafts vinculadas,
    /// se eliminan y se recrean según las reglas A/B actuales (más simple que update
    /// in-place y evita estado inconsistente al cambiar payer/monto/splits).
    ///
    /// **Reglas (TX siempre en cuenta virtual `Grupos [moneda]`):**
    /// - **Caso A** (yo pago): TX1 virtual `-myShare` (subcat manual o nil) +
    ///   TX2 virtual `+totalAmount` con sistema "Préstamo a grupos" (income).
    ///   Skip TX2 si `lentAmount == 0` (yo solo en split).
    /// - **Caso B** (paga otro): TX1 virtual `-myShare` (subcat manual o nil).
    ///
    /// Si `subcategory` queda nil (auto-match falló) Y `autoCreate=true`: TX1 se crea
    /// con `subcategory=nil` + `InboxDraft` source=`.groupExpense` con `targetTransactionID`
    /// apuntando a TX1. Saldo virtual cuadra desde t=0; user finaliza draft → UPDATE subcat.
    ///
    /// Si `autoCreate=false`: comportamiento legacy (1 InboxDraft con monto -myShare),
    /// el user revisa y aprueba manualmente. Sin TX-puntero.
    ///
    /// - Parameters:
    ///   - expense: The shared expense to bridge.
    ///   - group: The group containing the expense.
    ///   - shouldSave: Whether to save the context (false when called from sync batch).
    func bridgeExpense(_ expense: SplitExpense, in group: SplitGroup, shouldSave: Bool = true) throws {
        let context = try requireContext()

        // GC-08: groupInvite users have no personal finance context for legacy drafts —
        // pero SÍ procesan TX virtuales (saldo virtual del grupo es relevante).
        // Se evalúa caso por caso abajo.

        // Find current user's member in this group
        let zoneID = group.cloudKitZoneID
        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
        )
        guard let currentMember = try context.fetch(memberDescriptor).first else { return }

        let currentMemberID = currentMember.id.uuidString

        // Find current user's share in this expense
        let expenseID = expense.id
        let shareDescriptor = FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == currentMemberID }
        )
        guard let myShare = try context.fetch(shareDescriptor).first else { return }

        // Idempotency: @MainActor + sync función garantiza atomicidad fetch+insert.
        // Strategy: delete + recreate (más simple que update in-place y evita estado
        // inconsistente al cambiar payer/monto/splits). Si futuro await: NSLock/actor.
        let expenseIDStr = expense.id.uuidString
        let existingTxs = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))
        for tx in existingTxs { context.delete(tx) }

        let existingDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        ))
        for draft in existingDrafts { context.delete(draft) }

        let shouldAutoCreate = GroupPersonalPreferences.autoCreateTransaction(for: group.cloudKitZoneID) ?? group.autoCreateTransaction

        // Legacy path: autoCreate=false → 1 InboxDraft (no especializado) con cuenta resuelta
        // del flujo previo. User revisa manualmente.
        if !shouldAutoCreate {
            // Skip para .groupInvite users sin contexto personal completo.
            guard !SessionState.shared.isGroupInviteMode else { return }
            let account = try GroupTransactionBridge.resolveAccount(group: group, currencyCode: expense.currencyCode, context: context)
            let subcategory = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)
            let draft = Self.makeBridgedDraft(from: expense, share: myShare, account: account, subcategory: subcategory)
            context.insert(draft)
            if shouldSave {
                try context.save()
                SessionState.shared.incrementDataVersion()
            }
            return
        }

        // Modelo M5 (autoCreate=true): TX siempre en cuenta virtual.
        let virtualAccount = try GroupBridgeSystemEntities.ensureSystemAccount(
            currencyCode: expense.currencyCode,
            colorHint: group.colorHex,
            context: context
        )
        let matchedSubcat = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)
        // Filter: si match es subcat sistema, ignorar (no tiene sentido para mi parte real)
        let realSubcat: Subcategory? = (matchedSubcat?.isAnySystem == true) ? nil : matchedSubcat

        let isCaseA = expense.paidByMemberID == currentMemberID
        let totalAmount = expense.amount
        let mySharedAmount = myShare.amount
        let lentAmount = totalAmount - mySharedAmount  // Solo relevante en Caso A

        // TX1 (común a Caso A y B): -myShare en virtual con subcat real (manual) o nil.
        let tx1 = TransactionItem(
            date: expense.date,
            amount: -mySharedAmount,
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

        // Si auto-match falló: crear InboxDraft groupExpense con targetTransactionID = tx1.id.
        if realSubcat == nil {
            let draft = InboxDraft(
                note: expense.expenseDescription,
                amount: -mySharedAmount,
                date: expense.date,
                account: virtualAccount,
                subcategory: nil,
                sourceType: .groupExpense,
                confidenceAmount: 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: 1.0,
                confidenceSubcategory: nil,
                needsUserInput: ["subcategory"],
                splitExpenseID: expenseIDStr,
                splitGroupZoneID: expense.groupZoneID,
                splitSettlementID: nil,
                targetTransactionID: tx1.persistentModelID.hashValue.description
            )
            // Note: targetTransactionID usa hashValue del persistentModelID porque
            // el persistentModelID en sí no es String. La finalize sheet (F11)
            // refetchará por splitExpenseID → match TX1 sin subcat.
            context.insert(draft)
        }

        // Caso A: TX2 sistema income "Préstamo a grupos" (+totalAmount). Skip si lent=0.
        if isCaseA && lentAmount > 0 {
            let loanSubcat = try GroupBridgeSystemEntities.systemSubcategory(role: .loanToGroups, context: context)
            let tx2 = TransactionItem(
                date: expense.date,
                amount: totalAmount,  // positivo: yo presté al grupo
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

        if shouldSave {
            try context.save()
            SessionState.shared.incrementDataVersion()
            WidgetDataCache.updateCache(context: context)
            Task { await BudgetAlertService.shared.checkBudgetsAndNotify() }
        }
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
                try bridgeExpense(expense, in: group, shouldSave: false)
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
        let zoneID = group.cloudKitZoneID
        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
        )
        guard let currentMember = try context.fetch(memberDescriptor).first else { return }
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
                    // Persistir default account preference para futuros settlements.
                    GroupPersonalPreferences.setDefaultSettlementAccount(account.name, for: zoneID, currencyCode: currencyCode)
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
                        needsUserInput: ["account"],
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
            if userType != .groupInvite {
                let receivedSubcat = try? GroupBridgeSystemEntities.systemSubcategory(role: .settlementReceived, context: context)
                let preselectAccount: Account? = {
                    guard let preferredName = GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: currencyCode),
                          !preferredName.isEmpty else { return nil }
                    let descriptor = FetchDescriptor<Account>(
                        predicate: #Predicate { $0.name == preferredName && !$0.isArchived }
                    )
                    return try? context.fetch(descriptor).first
                }()
                let draft = InboxDraft(
                    note: settlement.note ?? "",
                    amount: amount,
                    date: settlement.date,
                    account: preselectAccount,
                    subcategory: receivedSubcat,
                    sourceType: .groupSettlement,
                    confidenceAmount: 1.0,
                    confidenceDate: 1.0,
                    confidenceMerchant: 1.0,
                    confidenceSubcategory: 1.0,
                    needsUserInput: preselectAccount == nil ? ["account"] : [],
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

    // MARK: - Import Group History (GC-08)

    /// Import all group expenses as InboxDrafts for a user activating full mode.
    /// Creates drafts (not TransactionItems) so the user can review before committing.
    func importGroupHistoryAsDrafts(for groups: [SplitGroup]) throws {
        let context = try requireContext()

        // Batch pre-fetch to avoid N+1 queries
        let allSubcategories = try context.fetch(FetchDescriptor<Subcategory>())
        let allDrafts = try context.fetch(FetchDescriptor<InboxDraft>())
        let bridgedDraftIDs = Set(allDrafts.compactMap(\.splitExpenseID))
        let allTxs = try context.fetch(FetchDescriptor<TransactionItem>())
        let bridgedTxIDs = Set(allTxs.compactMap(\.splitExpenseID))

        for group in groups {
            let zoneID = group.cloudKitZoneID

            let memberDescriptor = FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true }
            )
            guard let currentMember = try context.fetch(memberDescriptor).first else { continue }
            let currentMemberID = currentMember.id.uuidString

            let expenseDescriptor = FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            )
            let expenses = try context.fetch(expenseDescriptor)

            var accountCache: [String: Account?] = [:]
            for expense in expenses {
                let existingID = expense.id.uuidString
                if bridgedDraftIDs.contains(existingID) || bridgedTxIDs.contains(existingID) { continue }

                let expenseID = expense.id
                let shareDescriptor = FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == currentMemberID }
                )
                guard let myShare = try context.fetch(shareDescriptor).first else { continue }

                if accountCache[expense.currencyCode] == nil {
                    // Batch import: a missing account for one currency must NOT block the entire batch.
                    accountCache[expense.currencyCode] = try? Self.resolveAccount(group: group, currencyCode: expense.currencyCode, context: context)
                }
                let account = accountCache[expense.currencyCode] ?? nil
                let subcategory = Self.matchSubcategoryFromList(name: expense.subcategoryName, allSubcategories: allSubcategories)
                let draft = Self.makeBridgedDraft(from: expense, share: myShare, account: account, subcategory: subcategory)
                context.insert(draft)
            }
        }

        try context.save()
        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Draft Factory

    /// Creates a bridged InboxDraft from a shared expense and the user's share.
    static func makeBridgedDraft(
        from expense: SplitExpense,
        share: SplitShare,
        account: Account?,
        subcategory: Subcategory?
    ) -> InboxDraft {
        let needsInput: [String] = subcategory == nil ? ["subcategory"] : []
        let draft = InboxDraft(
            note: expense.expenseDescription,
            amount: -share.amount,
            date: expense.date,
            account: account,
            subcategory: subcategory,
            sourceType: .automation,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            confidenceSubcategory: subcategory != nil ? 0.8 : nil,
            needsUserInput: needsInput
        )
        draft.splitExpenseID = expense.id.uuidString
        draft.splitGroupZoneID = expense.groupZoneID
        return draft
    }

    /// Match subcategory from a pre-fetched list (avoids per-expense refetch).
    static func matchSubcategoryFromList(name: String?, allSubcategories: [Subcategory]) -> Subcategory? {
        guard let name, !name.isEmpty else { return nil }
        if let exact = allSubcategories.first(where: { $0.name.lowercased() == name.lowercased() }) {
            return exact
        }
        if let partial = allSubcategories.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
            return partial
        }
        return nil
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

    // MARK: - Account Resolution

    /// Resolve account: per-currency preference → legacy single preference → first account with matching currency → any first account.
    /// - Throws: `GroupTransactionBridgeError.noAccountsAvailable` when there are no usable accounts (empty fetch or fetch error).
    static func resolveAccount(group: SplitGroup, currencyCode: String, context: ModelContext) throws -> Account {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        let allAccounts: [Account]
        do {
            allAccounts = try context.fetch(descriptor)
        } catch {
            logger.error("Error fetching accounts: \(error.localizedDescription, privacy: .public)")
            throw GroupTransactionBridgeError.noAccountsAvailable
        }

        guard !allAccounts.isEmpty else {
            throw GroupTransactionBridgeError.noAccountsAvailable
        }

        // 1. Per-currency preference
        if let preferredName = GroupPersonalPreferences.accountName(for: group.cloudKitZoneID, currencyCode: currencyCode),
           !preferredName.isEmpty,
           let match = allAccounts.first(where: { $0.name == preferredName }) {
            return match
        }

        // 2. Legacy single-account preference (migration)
        if let legacyName = GroupPersonalPreferences.defaultAccountName(for: group.cloudKitZoneID),
           !legacyName.isEmpty,
           let match = allAccounts.first(where: { $0.name == legacyName }) {
            return match
        }

        // 3. First account matching the expense currency
        if let match = allAccounts.first(where: { $0.currencyCode == currencyCode }) {
            return match
        }

        // 4. Absolute fallback: any first account (guard above ensures non-empty).
        if let first = allAccounts.first { return first }
        throw GroupTransactionBridgeError.noAccountsAvailable
    }

    // MARK: - Private Helpers

    private func updateTransaction(
        _ tx: TransactionItem,
        from expense: SplitExpense,
        share: SplitShare,
        group: SplitGroup,
        context: ModelContext
    ) {
        // Re-resolve account only if currency changed.
        // Resilient: if no account exists for the new currency, skip account update —
        // other fields (note, date, amount) still get updated. NO surface alert here.
        if tx.currencyCode != expense.currencyCode {
            if let newAccount = try? Self.resolveAccount(group: group, currencyCode: expense.currencyCode, context: context) {
                tx.account = newAccount
            }
        }
        // Re-resolve subcategory only if name changed
        if tx.subcategory?.name.lowercased() != expense.subcategoryName?.lowercased() {
            let newSub = Self.matchSubcategory(name: expense.subcategoryName, context: context)
            tx.subcategory = newSub
            tx.category = newSub?.safeCategory
        }
        tx.amount = -share.amount
        tx.currencyCode = expense.currencyCode
        tx.date = expense.date
        tx.note = expense.expenseDescription.isEmpty ? nil : expense.expenseDescription
        tx.splitTotalAmount = expense.amount
        tx.splitType = expense.splitType
        tx.recalculatePreferredCurrency(context: context)
    }

    private func updateDraft(
        _ draft: InboxDraft,
        from expense: SplitExpense,
        share: SplitShare,
        group: SplitGroup,
        context: ModelContext
    ) {
        // Re-resolve account if currency changed (InboxDraft currency comes from account).
        // Resilient: if no account exists for the new currency, skip account update.
        if draft.account?.currencyCode != expense.currencyCode {
            if let newAccount = try? Self.resolveAccount(group: group, currencyCode: expense.currencyCode, context: context) {
                draft.account = newAccount
            }
        }
        // Re-resolve subcategory only if name changed
        if draft.subcategory?.name.lowercased() != expense.subcategoryName?.lowercased() {
            let newSub = Self.matchSubcategory(name: expense.subcategoryName, context: context)
            if let newSub { draft.subcategory = newSub }
        }
        draft.amount = -share.amount
        draft.date = expense.date
        draft.note = expense.expenseDescription
    }
}

// MARK: - Errors

enum GroupTransactionBridgeError: LocalizedError {
    case noContext
    case noAccountsAvailable

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupTransactionBridge: No ModelContext available"
        case .noAccountsAvailable:
            return "GroupTransactionBridge: No accounts available to bridge expense"
        }
    }
}
