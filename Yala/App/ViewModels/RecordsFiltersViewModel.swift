//
//  RecordsFiltersViewModel.swift
//  Yala
//
//  ViewModel for RecordsFiltersView - handles data loading for filter options.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class RecordsFiltersViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allAccounts: [Account] = []
    private(set) var allCategories: [Category] = []
    private(set) var allTags: [Tag] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var currenciesWithTransactions: [CurrencyCode] = []

    // MARK: - Computed Properties

    var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        // Load accounts
        let accountDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            allAccounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }

        // Load categories
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        do {
            allCategories = try context.fetch(categoryDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading categories: \(error)")
            #endif
            allCategories = []
        }

        // Load tags
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }

        // Load subcategories
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(subcategoryDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }

        // Load currencies with transactions
        loadCurrenciesWithTransactions()
    }

    private func loadCurrenciesWithTransactions() {
        guard let context = modelContext else { return }

        // Note: SwiftData lacks DISTINCT/projection; full fetch required for currency code extraction
        let descriptor = FetchDescriptor<TransactionItem>()
        do {
            let transactions = try context.fetch(descriptor)
            let uniqueCodes = Set(transactions.map { $0.currencyCode })
            // Maintain consistent order with CurrencyCode.allCases
            currenciesWithTransactions = CurrencyCode.allCases.filter {
                uniqueCodes.contains($0.rawValue)
            }
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading currencies: \(error)")
            #endif
            currenciesWithTransactions = []
        }
    }

    // MARK: - Helper Methods

    func selectedAccountsText(selectedAccounts: Set<PersistentIdentifier>, isExcludeMode: Bool = false) -> String {
        if selectedAccounts.isEmpty {
            return isExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.all
        }
        if !isExcludeMode && selectedAccounts.count == activeAccounts.count {
            return L10n.Filters.all
        }
        return "\(selectedAccounts.count)/\(activeAccounts.count)"
    }

    func selectedCategoriesText(selectedSubcategories: Set<PersistentIdentifier>, isExcludeMode: Bool = false) -> String {
        let subCount = selectedSubcategories.count

        if subCount == 0 {
            return isExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.all
        }

        let allIDs = Set(allSubcategories.map { $0.persistentModelID })
        if !isExcludeMode && selectedSubcategories == allIDs {
            return L10n.Filters.all
        }

        let selectedSubs = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }
        if selectedSubs.isEmpty {
            return isExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.all
        }

        if let firstSub = selectedSubs.first {
            let remainingCount = selectedSubs.count - 1
            if remainingCount > 0 {
                return "\(firstSub.name) +\(remainingCount)"
            } else {
                return firstSub.name
            }
        }

        return isExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.all
    }

    func selectedTagsText(selectedTags: Set<PersistentIdentifier>, isExcludeMode: Bool = false) -> String {
        if selectedTags.isEmpty {
            return isExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.all
        }
        if !isExcludeMode && selectedTags.count == activeTags.count {
            return L10n.Filters.all
        }
        return "\(selectedTags.count)/\(activeTags.count)"
    }

    func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    func subcategorySelectionSummary(for category: Category, selectedSubcategories: Set<PersistentIdentifier>) -> String {
        let subs = subcategories(for: category)
        let total = subs.count
        let selectedCount = subs.filter { selectedSubcategories.contains($0.persistentModelID) }.count

        if total == 0 {
            return L10n.Filters.noSubcategories
        }

        if selectedCount == 0 {
            return L10n.Filters.noneSelected
        }

        if selectedCount == total {
            return L10n.Filters.allSubcategories
        }

        return "\(selectedCount) / \(total)"
    }
}
