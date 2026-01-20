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
final class RecordsViewModel: Filterable {

    // MARK: - Filter State

    /// Selected accounts for filtering
    var selectedAccounts: Set<PersistentIdentifier> = []

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> = []

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> = []

    /// Selected natures for filtering
    var selectedNatures: Set<SubcategoryNature> = []

    /// Selected transaction natures for filtering (empty = all)
    /// Used for income/expense filter chips
    var selectedTransactionNatures: Set<TransactionNature> = []

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> = []

    /// Transaction type filter
    var transactionTypeFilter: TransactionTypeFilter = .all

    /// Amount filter condition
    var amountCondition: AmountFilterCondition = .any

    /// Period filter (unified with Trends)
    var period: DetailPeriod = .thisMonth

    /// Custom date range (synced from SessionState)
    var customDateRange: DateInterval?

    /// Custom date range start (for backward compat, deprecated)
    var customStartDate: Date =
        Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

    /// Custom date range end (for backward compat, deprecated)
    var customEndDate: Date = Date()

    /// Selected currencies for filtering
    var selectedCurrencies: Set<CurrencyCode> = []

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

    /// Cached summary (balance, income, expense) - updated when groupedRecords changes
    var recordsSummary: (balance: Double, income: Double, expense: Double) = (0, 0, 0)

    /// Total count of filtered records
    var filteredCount: Int {
        groupedRecords.reduce(0) { $0 + $1.records.count }
    }

    // MARK: - Computed Properties

    /// Whether any filter is active (for UI indicator)
    var hasActiveFilters: Bool {
        !selectedAccounts.isEmpty || !selectedCategories.isEmpty || !selectedSubcategories.isEmpty
            || !selectedNatures.isEmpty || !selectedTags.isEmpty || transactionTypeFilter != .all
            || amountCondition.isActive
            || !selectedCurrencies.isEmpty || !searchText.isEmpty
            || hasTransactionNatureFilter
    }

    /// Whether transaction nature filter shows a chip (exactly 1 selected)
    var hasTransactionNatureFilter: Bool {
        selectedTransactionNatures.count == 1
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
        // Exclude period from filters count as it's a primary control
        if !selectedCurrencies.isEmpty { count += 1 }
        if hasTransactionNatureFilter { count += 1 }
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
        if let type = context.transactionType {
            self.transactionTypeFilter = type
        }
        if let search = context.searchText, !search.isEmpty {
            self.searchText = search
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
        // Build FilterCriteria from current state
        let criteria = FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNatures: selectedNatures,
            selectedTransactionNatures: selectedTransactionNatures,
            selectedCurrencies: selectedCurrencies,
            transactionTypeFilter: transactionTypeFilter,
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: effectiveDateInterval()
        )

        // Use FilterService for filtering and grouping
        groupedRecords = FilterService.filterAndGroup(
            transactions: transactions,
            criteria: criteria
        )

        // Update cached summary (calculated once per filter change, not per render)
        calculateSummary()
    }

    /// Calculate summary from grouped records (called once when data changes)
    private func calculateSummary() {
        var income: Double = 0
        var expense: Double = 0
        var balance: Double = 0

        for group in groupedRecords {
            for record in group.records {
                guard let account = record.account else { continue }
                if account.isArchived || account.excludeFromStatistics { continue }

                let amount = record.amountInPreferredCurrency
                balance += amount

                let isBalanceAdjustment = record.balanceAdjustmentType != nil
                if !isBalanceAdjustment {
                    if amount > 0 {
                        income += amount
                    } else {
                        expense += abs(amount)
                    }
                }
            }
        }

        recordsSummary = (balance, income, expense)
    }

    /// Get effective date interval from current period
    private func effectiveDateInterval() -> DateInterval? {
        // DetailPeriod always has a valid dateInterval
        return period.dateInterval(customRange: customDateRange)
    }

    // MARK: - SessionState Synchronization

    /// Sync custom date range and period FROM SessionState
    func syncCustomRangeFromSessionState(_ sessionState: SessionState) {
        self.customDateRange = sessionState.customDateRange
        self.period = sessionState.selectedPeriod
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
        selectedTransactionNatures.removeAll()
        selectedTags.removeAll()
        transactionTypeFilter = .all
        amountCondition = .any
        // period = .thisMonth // Do not reset period
        customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        customEndDate = Date()
        selectedCurrencies = []
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
