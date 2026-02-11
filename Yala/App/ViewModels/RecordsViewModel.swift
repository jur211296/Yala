//
//  RecordsViewModel.swift
//  Yala
//
//  Created by Yala - Records Feature.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Records ViewModel

/// ViewModel for the Records list view
/// Manages filter state, selection, and computed data
@MainActor
@Observable
final class RecordsViewModel: Filterable {

    // MARK: - Filter State (SSOT: Read/Write from SessionState.shared)

    /// Selected accounts for filtering
    var selectedAccounts: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedAccountIDs }
        set { SessionState.shared.selectedAccountIDs = newValue }
    }

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedCategoryIDs }
        set { SessionState.shared.selectedCategoryIDs = newValue }
    }

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedSubcategoryIDs }
        set { SessionState.shared.selectedSubcategoryIDs = newValue }
    }

    /// Selected natures for filtering
    var selectedNatures: Set<SubcategoryNature> {
        get { SessionState.shared.selectedNatures }
        set { SessionState.shared.selectedNatures = newValue }
    }

    /// Selected transaction natures for filtering (empty = all)
    /// Used for income/expense filter chips
    var selectedTransactionNatures: Set<TransactionNature> {
        get { SessionState.shared.selectedTransactionNatures }
        set { SessionState.shared.selectedTransactionNatures = newValue }
    }

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedTags }
        set { SessionState.shared.selectedTags = newValue }
    }

    /// Transaction type filter (local - not shared between views)
    var transactionTypeFilter: TransactionTypeFilter = .all

    /// Amount filter condition
    var amountCondition: AmountFilterCondition {
        get { SessionState.shared.amountCondition }
        set { SessionState.shared.amountCondition = newValue }
    }

    /// Period filter (unified with Trends)
    var period: DetailPeriod {
        get { SessionState.shared.selectedPeriod }
        set { SessionState.shared.selectedPeriod = newValue }
    }

    /// Custom date range (synced from SessionState)
    var customDateRange: DateInterval? {
        get { SessionState.shared.customDateRange }
        set { SessionState.shared.customDateRange = newValue }
    }

    /// Custom date range start (for backward compat, deprecated)
    var customStartDate: Date =
        Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

    /// Custom date range end (for backward compat, deprecated)
    var customEndDate: Date = Date()

    /// Selected currencies for filtering
    var selectedCurrencies: Set<CurrencyCode> {
        get { SessionState.shared.selectedCurrencies }
        set { SessionState.shared.selectedCurrencies = newValue }
    }

    /// Search text for note filtering
    var searchText: String {
        get { SessionState.shared.searchText }
        set { SessionState.shared.searchText = newValue }
    }

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
        // Note: period is NOT set here because it's a computed property that writes to SessionState.
        // Setting it would overwrite the user's period selection. The period comes from SessionState directly.
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
        // In expenses-only mode, force expense transaction nature filter
        let effectiveTransactionNatures: Set<TransactionNature> =
            SessionState.shared.isExpensesOnlyMode ? [.expense] : selectedTransactionNatures

        // Build FilterCriteria from current state
        let criteria = FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNatures: selectedNatures,
            selectedTransactionNatures: effectiveTransactionNatures,
            selectedCurrencies: selectedCurrencies,
            transactionTypeFilter: transactionTypeFilter,
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: effectiveDateInterval()
        )

        // Pre-filter: hide transactions from accounts excluded from statistics
        let eligibleTransactions = transactions.filter { tx in
            guard let account = tx.account else { return true }
            return !account.excludeFromStatistics
        }

        // Use FilterService for filtering and grouping
        groupedRecords = FilterService.filterAndGroup(
            transactions: eligibleTransactions,
            criteria: criteria
        )

        // Update cached summary (calculated once per filter change, not per render)
        calculateSummary()
    }

    /// Calculate summary from grouped records (called once when data changes)
    /// Balance = Income - Expense (excludes adjustments and transfers for consistency)
    private func calculateSummary() {
        var income: Double = 0
        var expense: Double = 0

        for group in groupedRecords {
            for record in group.records {
                guard let account = record.account else { continue }
                if account.excludeFromStatistics { continue }

                // Exclude balance adjustments and transfers from summary
                let isBalanceAdjustment = record.balanceAdjustmentType != nil
                if !isBalanceAdjustment {
                    let amount = record.amountInPreferredCurrency
                    if amount > 0 {
                        income += amount
                    } else {
                        expense += abs(amount)
                    }
                }
            }
        }

        // Balance is simply the difference (cash flow)
        recordsSummary = (income - expense, income, expense)
    }

    /// Get effective date interval from current period
    private func effectiveDateInterval() -> DateInterval? {
        // DetailPeriod always has a valid dateInterval
        return period.dateInterval(customRange: customDateRange)
    }

    // MARK: - SessionState Synchronization (SSOT - Most sync is now via computed properties)

    /// No-op: customDateRange and period are now SSOT computed properties
    /// Kept for backward compatibility with existing callers
    func syncCustomRangeFromSessionState(_ sessionState: SessionState) {
        // No-op: customDateRange and period are now SSOT computed properties
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
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("Error deleting records: \(error)")
            #endif
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
        // In expenses-only mode, keep expense filter forced
        if SessionState.shared.isExpensesOnlyMode {
            selectedTransactionNatures = [.expense]
        } else {
            selectedTransactionNatures.removeAll()
        }
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

    // MARK: - Bulk Edit Operations

    /// Update account for all selected transactions
    func bulkUpdateAccount(_ account: Account, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        for transaction in transactions {
            transaction.account = account
            // Update currency to match the new account
            transaction.currencyCode = account.currencyCode
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving bulk account update: \(error)")
            #endif
        }
    }

    /// Update subcategory for all selected transactions
    func bulkUpdateSubcategory(_ subcategory: Subcategory, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        for transaction in transactions {
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving bulk subcategory update: \(error)")
            #endif
        }
    }

    /// Add tags to all selected transactions
    func bulkAddTags(_ tags: [Tag], context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        for transaction in transactions {
            var currentTags = transaction.tags ?? []
            for tag in tags {
                if !currentTags.contains(where: { $0.persistentModelID == tag.persistentModelID }) {
                    currentTags.append(tag)
                }
            }
            transaction.tags = currentTags
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving bulk tags update: \(error)")
            #endif
        }
    }

    /// Remove tags from all selected transactions
    func bulkRemoveTags(_ tags: [Tag], context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        let tagIDsToRemove = Set(tags.map { $0.persistentModelID })
        for transaction in transactions {
            var currentTags = transaction.tags ?? []
            currentTags.removeAll { tagIDsToRemove.contains($0.persistentModelID) }
            transaction.tags = currentTags
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving bulk tags removal: \(error)")
            #endif
        }
    }

    /// Update note for all selected transactions
    func bulkUpdateNote(_ note: String, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        for transaction in transactions {
            transaction.note = note
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving bulk note update: \(error)")
            #endif
        }
    }

    /// Update amount for all selected transactions
    func bulkUpdateAmount(_ amount: Double, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        for transaction in transactions {
            transaction.amount = amount
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving bulk amount update: \(error)")
            #endif
        }
    }

    /// Get tags for all selected transactions (for bulk tag editing UI)
    func getSelectedTransactionTags() -> [[Tag]] {
        let flatTransactions = groupedRecords.flatMap { $0.records }
        return selectedRecordIDs.compactMap { id in
            flatTransactions.first { $0.persistentModelID == id }?.tags
        }
    }

    /// Detect the transaction type of selected records for bulk edit filtering
    /// Returns .income if all non-transfer selections are income,
    /// .expense if all are expense, nil if mixed or only transfers
    func getSelectedTransactionType() -> TransactionType? {
        let flatTransactions = groupedRecords.flatMap { $0.records }
        let selected = flatTransactions.filter { selectedRecordIDs.contains($0.persistentModelID) }

        var hasIncome = false
        var hasExpense = false

        for transaction in selected {
            // Skip transactions without subcategory and transfers (system subcategory)
            guard let subcategory = transaction.subcategory else { continue }
            if subcategory.isSystemSubcategory { continue }

            if subcategory.safeCategory.isIncome {
                hasIncome = true
            } else {
                hasExpense = true
            }
            // Early exit if mixed
            if hasIncome && hasExpense { return nil }
        }

        if hasIncome && !hasExpense { return .income }
        if hasExpense && !hasIncome { return .expense }
        return nil  // Mixed or only transfers
    }

    /// Helper to fetch selected transactions from context
    private func getSelectedTransactions(context: ModelContext) -> [TransactionItem] {
        var transactions: [TransactionItem] = []
        for id in selectedRecordIDs {
            if let transaction = context.model(for: id) as? TransactionItem {
                transactions.append(transaction)
            }
        }
        return transactions
    }
}
