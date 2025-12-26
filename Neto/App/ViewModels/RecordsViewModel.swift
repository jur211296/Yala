//
//  RecordsViewModel.swift
//  Neto
//
//  Created by Neto - Records Feature.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Records ViewModel

/// ViewModel for the Records list view
/// Manages filter state, selection, and computed data
@Observable
final class RecordsViewModel {

    // MARK: - Filter State

    /// Selected accounts for filtering
    var selectedAccounts: Set<PersistentIdentifier> = []

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> = []

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> = []

    /// Selected natures for filtering
    var selectedNatures: Set<SubcategoryNature> = []

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> = []

    /// Transaction type filter
    var transactionTypeFilter: TransactionTypeFilter = .all

    /// Amount filter condition
    var amountCondition: AmountFilterCondition = .any

    /// Period filter
    var period: RecordsPeriod = .thisMonth

    /// Custom date range start
    var customStartDate: Date =
        Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

    /// Custom date range end
    var customEndDate: Date = Date()

    /// Selected currencies for filtering
    var selectedCurrencies: Set<CurrencyCode> = Set(CurrencyCode.allCases)

    /// Search text for note filtering
    var searchText: String = ""

    // MARK: - UI State

    /// Whether search bar is expanded
    var isSearchExpanded: Bool = false

    /// Whether selection mode is active
    var isSelectionMode: Bool = false

    /// Selected record IDs for bulk actions
    var selectedRecordIDs: Set<PersistentIdentifier> = []

    /// Sheet states
    var showFiltersSheet: Bool = false
    var showNewTransaction: Bool = false
    var showEditTransaction: Bool = false
    var editingTransaction: TransactionItem?

    // MARK: - Computed Data

    /// Grouped records by date (pre-computed for performance)
    var groupedRecords: [(date: Date, records: [TransactionItem])] = []

    /// Total count of filtered records
    var filteredCount: Int {
        groupedRecords.reduce(0) { $0 + $1.records.count }
    }

    // MARK: - Computed Properties

    /// Whether any filter is active (for UI indicator)
    var hasActiveFilters: Bool {
        !selectedAccounts.isEmpty || !selectedCategories.isEmpty || !selectedSubcategories.isEmpty
            || !selectedNatures.isEmpty || !selectedTags.isEmpty || transactionTypeFilter != .all
            || amountCondition.isActive || period != .thisMonth
            || !selectedCurrencies.isEmpty || !searchText.isEmpty
    }

    /// Number of active filter types (for badge)
    var activeFilterCount: Int {
        var count = 0
        if !selectedAccounts.isEmpty { count += 1 }
        if !selectedCategories.isEmpty || !selectedSubcategories.isEmpty { count += 1 }
        if !selectedNatures.isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if transactionTypeFilter != .all { count += 1 }
        if amountCondition.isActive { count += 1 }
        if period != .thisMonth { count += 1 }
        if !selectedCurrencies.isEmpty { count += 1 }
        return count
    }

    // MARK: - Initialization

    init() {}

    /// Initialize with context from Panel
    init(context: RecordsFilterContext) {
        if let accountID = context.accountID {
            selectedAccounts = [accountID]
        }
        if let categoryID = context.categoryID {
            selectedCategories = [categoryID]
        }
        if let nature = context.nature {
            selectedNatures = [nature]
        }
        if let period = context.period {
            self.period = period
        }
    }

    // MARK: - Filter Application

    /// Apply all filters and group results by date
    func applyFilters(
        transactions: [TransactionItem],
        accounts: [Account],
        categories: [Category],
        tags: [Tag]
    ) {
        let calendar = Calendar.current

        // Get date interval for period filter
        let dateInterval = effectiveDateInterval()

        // Filter transactions
        let filtered = transactions.filter { transaction in
            // Date filter
            if let interval = dateInterval {
                guard interval.contains(transaction.date) else { return false }
            }

            // Account filter
            if !selectedAccounts.isEmpty {
                guard let accountID = transaction.account?.persistentModelID,
                    selectedAccounts.contains(accountID)
                else { return false }
            }

            // Category filter
            if !selectedCategories.isEmpty {
                guard let categoryID = transaction.category?.persistentModelID,
                    selectedCategories.contains(categoryID)
                else { return false }
            }

            // Subcategory filter
            if !selectedSubcategories.isEmpty {
                guard let subcategoryID = transaction.subcategory?.persistentModelID,
                    selectedSubcategories.contains(subcategoryID)
                else { return false }
            }

            // Nature filter
            if !selectedNatures.isEmpty {
                guard let subcategory = transaction.subcategory,
                    selectedNatures.contains(subcategory.nature)
                else { return false }
            }

            // Tags filter
            if !selectedTags.isEmpty {
                let transactionTagIDs = Set(transaction.tags.map { $0.persistentModelID })
                guard !transactionTagIDs.isDisjoint(with: selectedTags) else { return false }
            }

            // Transaction type filter
            switch transactionTypeFilter {
            case .all:
                break
            case .income:
                guard transaction.category?.isIncome == true else { return false }
            case .expense:
                guard transaction.category?.isIncome == false else { return false }
            case .transfer:
                // Transfers are identified by having a specific note pattern or no category
                // For now, we skip this filter type
                break
            }

            // Amount filter
            let amount = Decimal(transaction.amount)
            guard amountCondition.matches(abs(amount)) else { return false }

            // Currency filter
            if selectedCurrencies.count != CurrencyCode.allCases.count {
                guard let currencyCode = CurrencyCode(rawValue: transaction.currencyCode),
                    selectedCurrencies.contains(currencyCode)
                else { return false }
            }

            // Search text filter (note)
            if !searchText.isEmpty {
                let noteText = transaction.note ?? ""
                guard noteText.localizedCaseInsensitiveContains(searchText) else { return false }
            }

            return true
        }

        // Group by date
        let grouped = Dictionary(grouping: filtered) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        // Sort groups by date (descending) and records within each group by date (descending)
        groupedRecords =
            grouped
            .map { (date: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    /// Get effective date interval considering period and custom dates
    private func effectiveDateInterval() -> DateInterval? {
        if period == .custom {
            let from = customStartDate
            let to = customEndDate
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: from)
            let end =
                calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: to)) ?? to
            return DateInterval(start: start, end: end)
        }

        return period.dateInterval()
    }

    // MARK: - Selection Actions

    /// Toggle selection for a record
    func toggleSelection(_ id: PersistentIdentifier) {
        if selectedRecordIDs.contains(id) {
            selectedRecordIDs.remove(id)
        } else {
            selectedRecordIDs.insert(id)
        }
    }

    /// Select all visible records
    func selectAll() {
        for group in groupedRecords {
            for record in group.records {
                selectedRecordIDs.insert(record.persistentModelID)
            }
        }
    }

    /// Deselect all records
    func deselectAll() {
        selectedRecordIDs.removeAll()
    }

    /// Enter selection mode
    func enterSelectionMode() {
        isSelectionMode = true
        selectedRecordIDs.removeAll()
    }

    /// Exit selection mode
    func exitSelectionMode() {
        isSelectionMode = false
        selectedRecordIDs.removeAll()
    }

    /// Delete selected records
    func deleteSelected(context: ModelContext) {
        // Fetch all transactions matching selected IDs
        for group in groupedRecords {
            for record in group.records {
                if selectedRecordIDs.contains(record.persistentModelID) {
                    context.delete(record)
                }
            }
        }

        do {
            try context.save()
        } catch {
            print("Error deleting records: \(error)")
        }

        exitSelectionMode()
    }

    // MARK: - Filter Actions

    /// Clear all filters
    func clearFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedNatures.removeAll()
        selectedTags.removeAll()
        transactionTypeFilter = .all
        amountCondition = .any
        period = .thisMonth
        customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        customEndDate = Date()
        selectedCurrencies = Set(CurrencyCode.allCases)
        searchText = ""
    }

    /// Clear search
    func clearSearch() {
        searchText = ""
        isSearchExpanded = false
    }

    // MARK: - Edit Actions

    /// Prepare to edit a single record
    func editRecord(_ record: TransactionItem) {
        editingTransaction = record
        showEditTransaction = true
    }

    /// Handle edit action for selected records
    func editSelectedRecords(transactions: [TransactionItem]) -> EditAction {
        guard !selectedRecordIDs.isEmpty else { return .none }

        if selectedRecordIDs.count == 1,
            let id = selectedRecordIDs.first,
            let record = transactions.first(where: { $0.persistentModelID == id })
        {
            return .single(record)
        } else {
            return .multiple(selectedRecordIDs.count)
        }
    }

    enum EditAction {
        case none
        case single(TransactionItem)
        case multiple(Int)
    }
}
