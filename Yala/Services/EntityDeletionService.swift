//
//  EntityDeletionService.swift
//  Yala
//
//  Service for standardized entity deletion operations.
//  Fase C.2: Arquitectura - Services para ModelContext
//

import Foundation
import SwiftData

// MARK: - EntityDeletionService

/// Service for managing entity deletion with consistent error handling
@MainActor
@Observable
final class EntityDeletionService {

    // MARK: - Singleton

    static let shared = EntityDeletionService()

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
            throw EntityDeletionError.noContext
        }
        return context
    }

    // MARK: - Basic Deletion

    /// Deletes an entity and saves the context
    /// - Parameter entity: The entity to delete
    func delete<T: PersistentModel>(_ entity: T) throws {
        let context = try requireContext()
        context.delete(entity)
        try context.save()
        // Process pending changes to ensure @Query views update immediately
        context.processPendingChanges()
        SessionState.shared.incrementDataVersion()
    }

    /// Deletes multiple entities and saves the context
    /// - Parameter entities: The entities to delete
    func deleteMultiple<T: PersistentModel>(_ entities: [T]) throws {
        let context = try requireContext()
        for entity in entities {
            context.delete(entity)
        }
        try context.save()
        context.processPendingChanges()
        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Account Deletion

    /// Deletes an account
    /// - Parameter account: The account to delete
    func deleteAccount(_ account: Account) throws {
        try delete(account)
    }

    // MARK: - Category Deletion

    /// Deletes a category and all its subcategories
    /// - Parameter category: The category to delete
    /// - Parameter subcategories: The category's subcategories (pass from @Query)
    /// - Note: This will orphan any transactions using these subcategories
    func deleteCategory(_ category: Category, withSubcategories subcategories: [Subcategory]) throws {
        let context = try requireContext()

        // Delete subcategories first to avoid SwiftUI @Query conflicts
        for subcategory in subcategories {
            context.delete(subcategory)
        }

        // Then delete the category
        context.delete(category)

        try context.save()
        context.processPendingChanges()
    }

    // MARK: - Subcategory Deletion

    /// Deletes a subcategory
    /// - Parameter subcategory: The subcategory to delete
    func deleteSubcategory(_ subcategory: Subcategory) throws {
        try delete(subcategory)
    }

    // MARK: - Tag Deletion

    /// Deletes a tag
    /// - Parameter tag: The tag to delete
    func deleteTag(_ tag: Tag) throws {
        try delete(tag)
    }

    // MARK: - Budget Deletion

    /// Deletes a budget
    /// - Parameter budget: The budget to delete
    func deleteBudget(_ budget: Budget) throws {
        try delete(budget)
    }

    // MARK: - ScheduledPayment Deletion

    /// Deletes a scheduled payment, cleaning up tracker entries and orphan drafts
    /// - Parameter payment: The scheduled payment to delete
    func deleteScheduledPayment(_ payment: ScheduledPayment) throws {
        let context = try requireContext()
        let paymentID = payment.id.uuidString

        // 1. Clean tracker entries (UserDefaults keys: scheduledPaymentNotif_UUID_*)
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let trackerKeys = allKeys.filter { $0.hasPrefix("scheduledPaymentNotif_\(paymentID)") }
        for key in trackerKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 2. Clean orphan pending drafts linked to this payment
        let draftDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.sourceScheduledPaymentID == paymentID }
        )
        do {
            let orphanDrafts = try context.fetch(draftDescriptor)
            for draft in orphanDrafts where draft.statusRaw == "pending" {
                context.delete(draft)
            }
        } catch {
            #if DEBUG
            print("EntityDeletionService: Error fetching orphan drafts: \(error)")
            #endif
        }

        // 3. Delete payment
        try delete(payment)
    }

    // MARK: - Transaction Count Check

    /// Counts transactions linked to a category
    /// - Parameter category: The category to check
    /// - Returns: The number of transactions
    func transactionCount(forCategory category: Category) -> Int {
        guard let context = modelContext else { return 0 }

        let categoryID = category.persistentModelID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.category?.persistentModelID == categoryID
            }
        )

        do {
            return try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("EntityDeletionService: Error counting transactions for category: \(error)")
            #endif
            return 0
        }
    }

    /// Counts transactions linked to a subcategory
    /// - Parameter subcategory: The subcategory to check
    /// - Returns: The number of transactions
    func transactionCount(forSubcategory subcategory: Subcategory) -> Int {
        guard let context = modelContext else { return 0 }

        let subcategoryID = subcategory.persistentModelID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.subcategory?.persistentModelID == subcategoryID
            }
        )

        do {
            return try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("EntityDeletionService: Error counting transactions for subcategory: \(error)")
            #endif
            return 0
        }
    }

    /// Counts transactions linked to an account
    /// - Parameter account: The account to check
    /// - Returns: The number of transactions
    func transactionCount(forAccount account: Account) -> Int {
        guard let context = modelContext else { return 0 }

        let accountID = account.persistentModelID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.account?.persistentModelID == accountID
            }
        )

        do {
            return try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("EntityDeletionService: Error counting transactions for account: \(error)")
            #endif
            return 0
        }
    }

    /// Checks if a subcategory has any linked transactions
    /// - Parameter subcategory: The subcategory to check
    /// - Returns: True if transactions exist
    func hasTransactions(forSubcategory subcategory: Subcategory) -> Bool {
        transactionCount(forSubcategory: subcategory) > 0
    }

    /// Checks if a category has any linked transactions
    /// - Parameter category: The category to check
    /// - Returns: True if transactions exist
    func hasTransactions(forCategory category: Category) -> Bool {
        transactionCount(forCategory: category) > 0
    }
}

// MARK: - Errors

enum EntityDeletionError: LocalizedError {
    case noContext
    case deletionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "EntityDeletionService: No ModelContext available"
        case .deletionFailed(let error):
            return "EntityDeletionService: Deletion failed - \(error.localizedDescription)"
        }
    }
}
