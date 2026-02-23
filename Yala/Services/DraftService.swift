//
//  DraftService.swift
//  Yala
//
//  Service for managing InboxDraft operations (create, approve, reject, delete).
//  Fase C.1: Arquitectura - Services para ModelContext
//

import Foundation
import SwiftData
import WidgetKit

// MARK: - DraftService Protocol

/// Protocol for draft management operations
@MainActor
protocol DraftServiceProtocol {
    /// Creates a new draft and inserts it into the context
    func createDraft(_ draft: InboxDraft) throws

    /// Creates multiple drafts (for bulk operations from voice/image)
    func createDrafts(_ drafts: [InboxDraft]) throws

    /// Approves a draft and creates the corresponding transaction
    func approveDraft(
        _ draft: InboxDraft,
        currencyConverter: CurrencyConverter
    ) throws -> TransactionItem

    /// Bulk approves multiple drafts
    func bulkApprove(
        _ drafts: [InboxDraft],
        currencyConverter: CurrencyConverter
    ) throws -> [TransactionItem]

    /// Rejects a draft (marks as rejected, caches display values)
    func rejectDraft(_ draft: InboxDraft) throws

    /// Bulk rejects multiple drafts
    func bulkReject(_ drafts: [InboxDraft]) throws

    /// Permanently deletes a draft
    func deleteDraft(_ draft: InboxDraft) throws

    /// Bulk deletes multiple drafts
    func bulkDelete(_ drafts: [InboxDraft]) throws

    /// Returns a draft from rejected/approved back to pending
    func returnToPending(_ draft: InboxDraft) throws

    /// Bulk returns drafts to pending
    func bulkReturnToPending(_ drafts: [InboxDraft]) throws

    /// Saves changes to a pending draft without approving
    func saveDraft(_ draft: InboxDraft) throws

    /// Updates account for multiple drafts
    func bulkUpdateAccount(_ drafts: [InboxDraft], account: Account) throws

    /// Updates subcategory for multiple drafts
    func bulkUpdateSubcategory(_ drafts: [InboxDraft], subcategory: Subcategory) throws
}

// MARK: - DraftService Implementation

/// Service for managing InboxDraft operations
@MainActor
@Observable
final class DraftService: DraftServiceProtocol {

    // MARK: - Singleton

    static let shared = DraftService()

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    /// Sets the model context (call this from views that use the service)
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Private Helpers

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw DraftServiceError.noContext
        }
        return context
    }

    /// Caches display values on a draft for when relationships are deleted
    private func cacheDisplayValues(_ draft: InboxDraft) {
        if let account = draft.account {
            draft.cachedAccountName = account.name
            draft.cachedCurrencyCode = account.currencyCode
        }
        if let subcategory = draft.subcategory {
            draft.cachedSubcategoryName = subcategory.name
            draft.cachedCategoryColorHex = subcategory.safeCategory.colorHex
            draft.cachedSubcategoryIcon = subcategory.iconName ?? subcategory.safeCategory.iconName
        }
    }

    /// Updates needsUserInput array based on draft state
    private func updateNeedsUserInput(_ draft: InboxDraft) {
        var needs: [String] = []
        if draft.account == nil { needs.append("account") }
        if draft.subcategory == nil { needs.append("subcategory") }
        if draft.amount == nil { needs.append("amount") }
        draft.needsUserInput = needs
    }

    // MARK: - Create Operations

    func createDraft(_ draft: InboxDraft) throws {
        let context = try requireContext()
        context.insert(draft)
        try context.save()
    }

    func createDrafts(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()
        for draft in drafts {
            context.insert(draft)
        }
        try context.save()
    }

    // MARK: - Approve Operations

    func approveDraft(
        _ draft: InboxDraft,
        currencyConverter: CurrencyConverter
    ) throws -> TransactionItem {
        let context = try requireContext()

        // Validate: block future dates
        guard draft.effectiveDate <= Date() else {
            throw DraftServiceError.futureDateNotAllowed
        }

        guard let account = draft.account else {
            throw DraftServiceError.missingAccount
        }
        guard let amount = draft.amount else {
            throw DraftServiceError.missingAmount
        }
        guard let subcategory = draft.subcategory else {
            throw DraftServiceError.missingSubcategory
        }

        // Calculate amount in preferred currency for charts/statistics
        let preferredCode = CurrencyDefaults.currentPreferred
        let amountInPreferred = currencyConverter.convert(
            Decimal(amount),
            from: account.currencyCode,
            to: preferredCode,
            on: draft.effectiveDate,
            context: context
        )

        let exchangeRate: Double
        if abs(amount) > 0.0001 {
            exchangeRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
        } else {
            exchangeRate = 1.0
        }

        // Create TransactionItem
        let transaction = TransactionItem(
            date: draft.effectiveDate,
            amount: amount,
            currencyCode: account.currencyCode
        )
        transaction.note = draft.note.isEmpty ? nil : draft.note
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.category = subcategory.safeCategory
        transaction.tags = draft.tags
        transaction.exchangeRate = abs(exchangeRate)
        transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        transaction.preferredCurrencyCode = preferredCode

        context.insert(transaction)

        // Cache display values BEFORE changing status
        cacheDisplayValues(draft)

        // Update draft status and link to transaction
        draft.status = .approved
        draft.approvedTransaction = transaction
        draft.updatedAt = Date()

        // Update merchant memory (learn from approved drafts)
        if !draft.note.trimmingCharacters(in: .whitespaces).isEmpty {
            let merchantService = MerchantMemoryService(modelContext: context)
            merchantService.updateMemory(
                merchantRaw: draft.note,
                subcategory: subcategory,
                wasCorrection: false
            )
        }

        // Update scheduled payment if this draft came from one
        ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)

        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()

        // Check budget alerts
        Task {
            await BudgetAlertService.shared.checkBudgetsAndNotify()
        }

        return transaction
    }

    func bulkApprove(
        _ drafts: [InboxDraft],
        currencyConverter: CurrencyConverter
    ) throws -> [TransactionItem] {
        let context = try requireContext()
        var transactions: [TransactionItem] = []
        let preferredCode = CurrencyDefaults.currentPreferred

        for draft in drafts where draft.isReadyToApprove {
            // Skip drafts with future dates
            guard draft.effectiveDate <= Date() else { continue }

            guard let account = draft.account,
                  !account.isArchived,
                  let amount = draft.amount,
                  let subcategory = draft.subcategory else { continue }

            // Calculate amount in preferred currency
            let amountInPreferred = currencyConverter.convert(
                Decimal(amount),
                from: account.currencyCode,
                to: preferredCode,
                on: draft.effectiveDate,
                context: context
            )

            let exchangeRate: Double
            if abs(amount) > 0.0001 {
                exchangeRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
            } else {
                exchangeRate = 1.0
            }

            let transaction = TransactionItem(
                date: draft.effectiveDate,
                amount: amount,
                currencyCode: account.currencyCode
            )
            transaction.note = draft.note.isEmpty ? nil : draft.note
            transaction.account = account
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
            transaction.tags = draft.tags
            transaction.exchangeRate = abs(exchangeRate)
            transaction.amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
            transaction.preferredCurrencyCode = preferredCode

            context.insert(transaction)

            // Cache display values
            cacheDisplayValues(draft)

            // Update draft
            draft.status = .approved
            draft.approvedTransaction = transaction
            draft.updatedAt = Date()

            // Update scheduled payment
            ScheduledPaymentDraftService.handleDraftApproved(draft: draft, context: context)

            transactions.append(transaction)
        }

        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()

        // Check budget alerts
        Task {
            await BudgetAlertService.shared.checkBudgetsAndNotify()
        }

        return transactions
    }

    // MARK: - Reject Operations

    func rejectDraft(_ draft: InboxDraft) throws {
        let context = try requireContext()

        // Cache values for display in archived list
        cacheDisplayValues(draft)

        draft.status = .rejected
        draft.updatedAt = Date()

        try context.save()
    }

    func bulkReject(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()

        for draft in drafts {
            cacheDisplayValues(draft)
            draft.status = .rejected
            draft.updatedAt = Date()
        }

        try context.save()
    }

    // MARK: - Delete Operations

    func deleteDraft(_ draft: InboxDraft) throws {
        let context = try requireContext()
        context.delete(draft)
        try context.save()
    }

    func bulkDelete(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()
        for draft in drafts {
            context.delete(draft)
        }
        try context.save()
    }

    // MARK: - Return to Pending

    func returnToPending(_ draft: InboxDraft) throws {
        let context = try requireContext()

        draft.status = .pending
        draft.updatedAt = Date()
        updateNeedsUserInput(draft)

        try context.save()
    }

    func bulkReturnToPending(_ drafts: [InboxDraft]) throws {
        let context = try requireContext()

        for draft in drafts {
            draft.status = .pending
            draft.updatedAt = Date()
            updateNeedsUserInput(draft)
        }

        try context.save()
    }

    // MARK: - Save (without approve)

    func saveDraft(_ draft: InboxDraft) throws {
        let context = try requireContext()

        draft.updatedAt = Date()
        updateNeedsUserInput(draft)

        try context.save()
    }

    // MARK: - Bulk Updates

    func bulkUpdateAccount(_ drafts: [InboxDraft], account: Account) throws {
        let context = try requireContext()

        for draft in drafts {
            draft.account = account
            draft.updatedAt = Date()
            updateNeedsUserInput(draft)
        }

        try context.save()
    }

    func bulkUpdateSubcategory(_ drafts: [InboxDraft], subcategory: Subcategory) throws {
        let context = try requireContext()

        for draft in drafts {
            draft.subcategory = subcategory
            draft.updatedAt = Date()
            updateNeedsUserInput(draft)
        }

        try context.save()
    }
}

// MARK: - Errors

enum DraftServiceError: LocalizedError {
    case noContext
    case missingAccount
    case missingAmount
    case missingSubcategory
    case futureDateNotAllowed
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "DraftService: No ModelContext available"
        case .missingAccount:
            return L10n.Inbox.errorNoAccount
        case .missingAmount:
            return L10n.Inbox.errorNoAmount
        case .missingSubcategory:
            return L10n.Inbox.errorNoSubcategory
        case .futureDateNotAllowed:
            return L10n.Inbox.errorFutureDate
        case .saveFailed(let error):
            return "DraftService: Save failed - \(error.localizedDescription)"
        }
    }
}
