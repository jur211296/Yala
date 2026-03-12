//
//  TransactionService.swift
//  Yala
//
//  Service for common transaction operations.
//  Fase C.3: Arquitectura - Services para ModelContext
//

import Foundation
import SwiftData
import WidgetKit

// MARK: - TransactionService

/// Service for managing common transaction operations
@MainActor
@Observable
final class TransactionService {

    // MARK: - Singleton

    static let shared = TransactionService()

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
            throw TransactionServiceError.noContext
        }
        return context
    }

    // MARK: - Create Operations

    /// Inserts and saves a new transaction
    /// - Parameter transaction: The transaction to insert
    func create(_ transaction: TransactionItem) throws {
        let context = try requireContext()
        context.insert(transaction)
        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()

        // Check budget alerts
        Task {
            await BudgetAlertService.shared.checkBudgetsAndNotify()
        }
    }

    // MARK: - Update Operations

    /// Saves changes to a transaction (just save, transaction is already in context)
    func save(_ transaction: TransactionItem) throws {
        let context = try requireContext()
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Delete Operations

    /// Deletes a transaction and saves
    /// - Parameter transaction: The transaction to delete
    func delete(_ transaction: TransactionItem) throws {
        let context = try requireContext()
        context.delete(transaction)
        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Deletes multiple transactions and saves
    /// - Parameter transactions: The transactions to delete
    func deleteMultiple(_ transactions: [TransactionItem]) throws {
        let context = try requireContext()
        for transaction in transactions {
            context.delete(transaction)
        }
        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Bulk Update Operations

    /// Updates account for multiple transactions
    /// - Parameters:
    ///   - transactions: The transactions to update
    ///   - account: The new account
    func bulkUpdateAccount(_ transactions: [TransactionItem], account: Account) throws {
        let context = try requireContext()
        for transaction in transactions {
            transaction.account = account
            transaction.currencyCode = account.currencyCode
        }
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Updates subcategory for multiple transactions
    /// - Parameters:
    ///   - transactions: The transactions to update
    ///   - subcategory: The new subcategory
    func bulkUpdateSubcategory(_ transactions: [TransactionItem], subcategory: Subcategory) throws {
        let context = try requireContext()
        for transaction in transactions {
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
        }
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Adds tags to multiple transactions
    /// - Parameters:
    ///   - transactions: The transactions to update
    ///   - tags: The tags to add
    func bulkAddTags(_ transactions: [TransactionItem], tags: [Tag]) throws {
        let context = try requireContext()
        for transaction in transactions {
            var currentTags = transaction.tags ?? []
            for tag in tags {
                if !currentTags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
                    currentTags.append(tag)
                }
            }
            transaction.tags = currentTags
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Removes tags from multiple transactions
    /// - Parameters:
    ///   - transactions: The transactions to update
    ///   - tags: The tags to remove
    func bulkRemoveTags(_ transactions: [TransactionItem], tags: [Tag]) throws {
        let context = try requireContext()
        let tagIDsToRemove = Set(tags.map { $0.persistentModelID })
        for transaction in transactions {
            var currentTags = transaction.tags ?? []
            currentTags.removeAll { tagIDsToRemove.contains($0.persistentModelID) }
            transaction.tags = currentTags
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Updates note for multiple transactions
    /// - Parameters:
    ///   - transactions: The transactions to update
    ///   - note: The new note (empty string becomes nil)
    func bulkUpdateNote(_ transactions: [TransactionItem], note: String) throws {
        let context = try requireContext()
        let finalNote = note.isEmpty ? nil : note
        for transaction in transactions {
            transaction.note = finalNote
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
    }

    /// Updates amount for multiple transactions
    /// - Parameters:
    ///   - transactions: The transactions to update
    ///   - amount: The new amount (will preserve expense/income sign)
    func bulkUpdateAmount(_ transactions: [TransactionItem], amount: Double) throws {
        let context = try requireContext()
        for transaction in transactions {
            // Preserve sign (expense = negative, income = positive)
            let sign: Double = transaction.amount < 0 ? -1 : 1
            transaction.amount = sign * abs(amount)
        }
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }
}

// MARK: - Errors

enum TransactionServiceError: LocalizedError {
    case noContext
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "TransactionService: No ModelContext available"
        case .saveFailed(let error):
            return "TransactionService: Save failed - \(error.localizedDescription)"
        }
    }
}
