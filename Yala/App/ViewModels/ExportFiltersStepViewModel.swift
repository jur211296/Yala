//
//  ExportFiltersStepViewModel.swift
//  Yala
//
//  ViewModel for ExportFiltersStepView - handles data loading for export filters.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ExportFiltersStepViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allAccounts: [Account] = []
    private(set) var allCategories: [Category] = []
    private(set) var allTags: [Tag] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var earliestTransactionDate: Date?

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
            print("ExportFiltersStepViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }

        // Load categories
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        do {
            allCategories = try context.fetch(categoryDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading categories: \(error)")
            #endif
            allCategories = []
        }

        // Load tags
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }

        // Load subcategories
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(subcategoryDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }

        // Load earliest transaction date for allTime period
        var earliestDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .forward)]
        )
        earliestDescriptor.fetchLimit = 1
        do {
            earliestTransactionDate = try context.fetch(earliestDescriptor).first?.date
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error fetching earliest transaction: \(error)")
            #endif
        }
    }

    // MARK: - Helper Methods

    func selectedAccountsText(selectedAccounts: Set<PersistentIdentifier>) -> String {
        if selectedAccounts.isEmpty {
            return L10n.Filters.noneSelected
        }
        if selectedAccounts.count == allAccounts.count {
            return L10n.Filters.allAccounts
        }
        return L10n.Filters.selectedCount(selectedAccounts.count)
    }

    func selectedCategoriesText(selectedSubcategories: Set<PersistentIdentifier>) -> String {
        let visibleSubs = allSubcategories.filter { $0.isVisible }

        if selectedSubcategories.isEmpty {
            return L10n.Filters.allCategories
        }

        if selectedSubcategories.count == visibleSubs.count {
            return L10n.Filters.allCategories
        }

        return L10n.Filters.subcategoriesSelectedCount(selectedSubcategories.count)
    }

    func selectedTagsText(selectedTags: Set<PersistentIdentifier>) -> String {
        if allTags.isEmpty {
            return L10n.Filters.noTags
        }
        if selectedTags.isEmpty || selectedTags.count == allTags.count {
            return L10n.Filters.allTags
        }
        return L10n.Filters.selectedCount(selectedTags.count)
    }

    func availableCurrencies(selectedAccounts: Set<PersistentIdentifier>) -> [CurrencyCode] {
        if selectedAccounts.isEmpty {
            return CurrencyCode.allCases
        }
        let selected = allAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
        let accountCurrencies = Set(selected.map { CurrencyCode(rawValue: $0.currencyCode) ?? .pen })
        return CurrencyCode.allCases.filter { accountCurrencies.contains($0) }
    }

    func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    // MARK: - All-Time Date Range

    /// Returns a date interval from the earliest transaction to end of today
    func allTimeDateInterval() -> DateInterval {
        guard let earliest = earliestTransactionDate else {
            return DetailPeriod.allTime.dateInterval()
        }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        return DateInterval(start: calendar.startOfDay(for: earliest), end: endOfToday)
    }

    // MARK: - Export Filters

    func buildExportFilters(
        selectedAccounts: Set<PersistentIdentifier>,
        selectedSubcategories: Set<PersistentIdentifier>,
        selectedTags: Set<PersistentIdentifier>,
        selectedCurrencies: Set<CurrencyCode>,
        amountCondition: AmountFilterCondition,
        selectedPeriod: DetailPeriod,
        customDateRange: DateInterval?,
        noteContains: String,
        isExcludeMode: Bool = false
    ) -> ExportFilters {
        // Resolve subcategory objects from PersistentIdentifiers
        let selectedSubcategoryObjects = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }

        // Derive categories from the selected subcategories
        let finalCategories = Set(selectedSubcategoryObjects.compactMap { $0.category })

        let selectedTagObjects = allTags.filter { selectedTags.contains($0.persistentModelID) }

        let selectedTagNames: [String]
        if !allTags.isEmpty && selectedTagObjects.count == allTags.count {
            selectedTagNames = []
        } else {
            selectedTagNames = selectedTagObjects.map { $0.name }
        }

        // Convert DetailPeriod to date interval
        let dateInterval: DateInterval
        if selectedPeriod == .custom, let customRange = customDateRange {
            dateInterval = customRange
        } else if selectedPeriod == .allTime {
            dateInterval = allTimeDateInterval()
        } else {
            dateInterval = selectedPeriod.dateInterval()
        }

        return ExportFilters(
            selectedAccounts: allAccounts.filter { selectedAccounts.contains($0.persistentModelID) },
            selectedCategories: Array(finalCategories),
            selectedSubcategories: selectedSubcategoryObjects,
            selectedTagNames: selectedTagNames,
            selectedCurrencies: Array(selectedCurrencies),
            amountCondition: amountCondition,
            dateFrom: dateInterval.start,
            dateTo: dateInterval.end,
            isExcludeMode: isExcludeMode,
            noteContains: noteContains.isEmpty ? nil : noteContains
        )
    }
}
