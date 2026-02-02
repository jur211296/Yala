//
//  SubcategorySelectorViewModel.swift
//  Yala
//
//  ViewModel for SubcategorySelectorSheet - handles subcategory loading and grouping.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SubcategorySelectorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Configuration

    var transactionType: TransactionType = .expense

    // MARK: - Data

    private(set) var allSubcategories: [Subcategory] = []
    private(set) var recentTransactions: [TransactionItem] = []

    // MARK: - Computed Properties

    /// Last 8 unique subcategories used in recent transactions (2 rows)
    var recentSubcategories: [Subcategory] {
        var seen = Set<PersistentIdentifier>()
        var result: [Subcategory] = []

        for transaction in recentTransactions {
            guard let subcategory = transaction.subcategory else { continue }
            guard subcategory.isVisible else { continue }

            // Check if matches current transaction type
            let category = subcategory.safeCategory
            let matchesType: Bool
            switch transactionType {
            case .expense:
                matchesType = !category.isIncome
            case .income:
                matchesType = category.isIncome
            case .transfer:
                matchesType = false
            }

            guard matchesType else { continue }

            let id = subcategory.persistentModelID
            if !seen.contains(id) {
                seen.insert(id)
                result.append(subcategory)
                if result.count >= 8 { break }
            }
        }

        return result
    }

    /// Groups subcategories by their parent category, filtered by transaction type
    var groupedSubcategories: [(category: Category, subcategories: [Subcategory])] {
        // Filter subcategories by transaction type and visibility
        let filtered = allSubcategories.filter { subcategory in
            guard subcategory.isVisible else { return false }

            let category = subcategory.safeCategory
            guard category.isVisible else { return false }

            switch transactionType {
            case .expense:
                return !category.isIncome
            case .income:
                return category.isIncome
            case .transfer:
                return false  // Transfers don't need subcategories
            }
        }

        // Group by category
        let grouped = Dictionary(grouping: filtered) { $0.safeCategory }

        // Sort by category sortOrder, subcategories alphabetically A-Z
        return
            grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map {
                (category: $0.key, subcategories: $0.value.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })
            }
    }

    var isEmpty: Bool {
        groupedSubcategories.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, transactionType: TransactionType) {
        self.modelContext = context
        self.transactionType = transactionType
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        loadSubcategories()
        loadRecentTransactions()
    }

    private func loadSubcategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(descriptor)
        } catch {
            print("SubcategorySelectorViewModel: Error loading subcategories: \(error)")
            allSubcategories = []
        }
    }

    private func loadRecentTransactions() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<TransactionItem>(
            sortBy: [
                SortDescriptor(\TransactionItem.date, order: .reverse),
                SortDescriptor(\TransactionItem.createdAt, order: .reverse)
            ]
        )
        do {
            recentTransactions = try context.fetch(descriptor)
        } catch {
            print("SubcategorySelectorViewModel: Error loading transactions: \(error)")
            recentTransactions = []
        }
    }
}
