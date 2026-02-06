//
//  DetailContainerViewModel.swift
//  Yala
//
//  ViewModel para DetailContainerView - maneja carga de datos para Statistics tabs.
//  Refactor D.8: @Query → ViewModel
//

import Foundation
import SwiftData

@MainActor
@Observable
final class DetailContainerViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTransactions: [TransactionItem] = []
    private(set) var accounts: [Account] = []
    private(set) var categories: [Category] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var tags: [Tag] = []

    // MARK: - Setup

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    func loadData() {
        guard let context = modelContext else { return }

        // Load transactions
        let transactionsDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        do {
            allTransactions = try context.fetch(transactionsDescriptor)
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading transactions: \(error)")
            #endif
        }

        // Load accounts
        let accountsDescriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            accounts = try context.fetch(accountsDescriptor)
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading accounts: \(error)")
            #endif
        }

        // Load categories
        let categoriesDescriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            categories = try context.fetch(categoriesDescriptor)
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading categories: \(error)")
            #endif
        }

        // Load subcategories
        let subcategoriesDescriptor = FetchDescriptor<Subcategory>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            allSubcategories = try context.fetch(subcategoriesDescriptor)
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading subcategories: \(error)")
            #endif
        }

        // Load tags
        let tagsDescriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            tags = try context.fetch(tagsDescriptor)
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading tags: \(error)")
            #endif
        }
    }

    // MARK: - Computed Properties

    /// Check if voice input can be used (requires accounts and subcategories)
    var canUseVoiceInput: Bool {
        let hasActiveAccounts = accounts.contains { !$0.isArchived }
        let hasVisibleSubcategories = allSubcategories.contains { $0.isVisible }
        return hasActiveAccounts && hasVisibleSubcategories
    }

    /// Compute date range of all transactions (for custom period picker limits)
    func computeTransactionDateRange() -> (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        return (start, end)
    }
}
