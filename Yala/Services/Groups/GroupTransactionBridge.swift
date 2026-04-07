//
//  GroupTransactionBridge.swift
//  Yala
//
//  Bridge between shared expenses and personal TransactionItem/InboxDraft.
//  Creates/updates/removes personal records when group expenses change.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GroupTransactionBridge {

    // MARK: - Singleton

    static let shared = GroupTransactionBridge()

    // MARK: - Properties

    private var modelContext: ModelContext?

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

    /// Create or update a personal TransactionItem/InboxDraft for a shared expense.
    /// - Parameters:
    ///   - expense: The shared expense to bridge.
    ///   - group: The group containing the expense.
    ///   - shouldSave: Whether to save the context (false when called from sync batch).
    func bridgeExpense(_ expense: SplitExpense, in group: SplitGroup, shouldSave: Bool = true) throws {
        let context = try requireContext()

        // GC-08: groupInvite users have no personal finance context — skip bridge
        guard !SessionState.shared.isGroupInviteMode else { return }

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

        // Idempotency: check if already bridged
        let expenseIDStr = expense.id.uuidString
        let txDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        )
        if let existingTx = try context.fetch(txDescriptor).first {
            // Update existing transaction
            updateTransaction(existingTx, from: expense, share: myShare, context: context)
            if shouldSave {
                try context.save()
                SessionState.shared.incrementDataVersion()
            }
            return
        }

        let draftDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseIDStr }
        )
        if let existingDraft = try context.fetch(draftDescriptor).first {
            // Update existing draft
            updateDraft(existingDraft, from: expense, share: myShare)
            if shouldSave {
                try context.save()
                SessionState.shared.incrementDataVersion()
            }
            return
        }

        // Resolve account and subcategory
        let account = GroupTransactionBridge.resolveAccount(group: group, currencyCode: expense.currencyCode, context: context)
        let subcategory = GroupTransactionBridge.matchSubcategory(name: expense.subcategoryName, context: context)

        let shouldAutoCreate = GroupPersonalPreferences.autoCreateTransaction(for: group.cloudKitZoneID) ?? group.autoCreateTransaction
        if shouldAutoCreate {
            let transaction = TransactionItem(
                date: expense.date,
                amount: -myShare.amount,
                currencyCode: expense.currencyCode,
                note: expense.expenseDescription.isEmpty ? nil : expense.expenseDescription,
                subcategory: subcategory,
                account: account
            )
            transaction.category = subcategory?.safeCategory
            transaction.splitExpenseID = expense.id.uuidString
            transaction.splitGroupZoneID = expense.groupZoneID
            transaction.splitTotalAmount = expense.amount
            transaction.splitType = expense.splitType

            context.insert(transaction)
            transaction.recalculatePreferredCurrency(context: context)

            if shouldSave {
                try context.save()
                SessionState.shared.incrementDataVersion()
                WidgetDataCache.updateCache(context: context)
                Task {
                    await BudgetAlertService.shared.checkBudgetsAndNotify()
                }
            }
        } else {
            let draft = Self.makeBridgedDraft(from: expense, share: myShare, account: account, subcategory: subcategory)
            context.insert(draft)

            if shouldSave {
                try context.save()
                SessionState.shared.incrementDataVersion()
            }
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
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Remove the bridged TransactionItem or InboxDraft for a deleted expense.
    func unbridgeExpense(expenseID: String) throws {
        let context = try requireContext()

        let txDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        )
        if let tx = try context.fetch(txDescriptor).first {
            context.delete(tx)
        }

        let draftDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        )
        if let draft = try context.fetch(draftDescriptor).first {
            context.delete(draft)
        }

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

            let account = Self.resolveAccount(group: group, currencyCode: group.currencyCode, context: context)

            for expense in expenses {
                let existingID = expense.id.uuidString
                if bridgedDraftIDs.contains(existingID) || bridgedTxIDs.contains(existingID) { continue }

                let expenseID = expense.id
                let shareDescriptor = FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.expenseID == expenseID && $0.memberID == currentMemberID }
                )
                guard let myShare = try context.fetch(shareDescriptor).first else { continue }

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
        guard let all = try? context.fetch(descriptor) else { return nil }

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
    static func resolveAccount(group: SplitGroup, currencyCode: String, context: ModelContext) -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        let allAccounts: [Account]
        do {
            allAccounts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("GroupTransactionBridge: Error fetching accounts: \(error)")
            #endif
            return nil
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

        // 4. Absolute fallback: any first account
        return allAccounts.first
    }

    // MARK: - Private Helpers

    private func updateTransaction(
        _ tx: TransactionItem,
        from expense: SplitExpense,
        share: SplitShare,
        context: ModelContext
    ) {
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
        share: SplitShare
    ) {
        draft.amount = -share.amount
        draft.date = expense.date
        draft.note = expense.expenseDescription
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
