//
//  FilterService.swift
//  Yala
//
//  Unified filtering service for transactions across all ViewModels.
//  Eliminates code duplication between PanelViewModel, RecordsViewModel, and TrendsDetailViewModel.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Shared Expense Filter

enum SharedExpenseFilter: String, CaseIterable, Hashable, Sendable {
    case all        // No filter
    case personal   // splitExpenseID == nil
    case shared     // splitExpenseID != nil
}

// MARK: - Filter Criteria

/// Unified filter criteria used across all views that filter transactions.
/// This eliminates the need for each ViewModel to define its own filter state separately.
struct FilterCriteria: Hashable, Sendable {

    // MARK: - Entity Filters

    /// Selected accounts for filtering (empty = all accounts)
    var selectedAccounts: Set<PersistentIdentifier> = []

    /// Selected categories for filtering (empty = all categories)
    var selectedCategories: Set<PersistentIdentifier> = []

    /// Selected subcategories for filtering (empty = all subcategories)
    var selectedSubcategories: Set<PersistentIdentifier> = []

    /// Selected tags for filtering (empty = all tags)
    var selectedTags: Set<PersistentIdentifier> = []

    /// CSV mirror equivalent of `selectedTags` — `Set<UUID>` of Tag.id values.
    /// Cuando está poblado, matchesCriteria lo compara contra `transaction.resolvedTagIDs()`
    /// (CSV-first), evitando el race CloudKit lazy nil donde la M2M `transaction.tags`
    /// está vacía pero el CSV está hidratado.
    /// Caller debe poblar SÓLO si tiene acceso al catálogo `[Tag]` para mapear.
    var selectedTagUUIDs: Set<UUID> = []

    /// Selected natures for filtering (empty = all natures)
    var selectedNeeds: Set<SubcategoryNeed> = []

    /// Selected transaction natures for filtering (empty = all, income/expense)
    var selectedTransactionNatures: Set<TransactionNature> = []

    /// Selected currencies for filtering (empty = all currencies)
    var selectedCurrencies: Set<CurrencyCode> = []

    // MARK: - Mode

    /// When true, selected entity filters act as exclusion (hide matching items)
    /// When false (default), selected entity filters act as inclusion (show only matching items)
    var isExcludeMode: Bool = false

    // MARK: - Value Filters

    /// Transaction type filter (all, income, expense, transfer)
    var transactionTypeFilter: TransactionTypeFilter = .all

    /// Amount condition filter
    var amountCondition: AmountFilterCondition = .any

    /// Search text for note filtering
    var searchText: String = ""

    /// Shared/personal expense filter
    var sharedExpenseFilter: SharedExpenseFilter = .all

    // MARK: - Date Filters

    /// Optional date interval for filtering (nil = no date filter)
    var dateInterval: DateInterval?

    // MARK: - Computed Properties

    /// Whether transaction nature filter is active (exactly 1 selected)
    var hasTransactionNatureFilter: Bool {
        selectedTransactionNatures.count == 1
    }

    /// Whether any filter is active (for UI indicator)
    var hasActiveFilters: Bool {
        !selectedAccounts.isEmpty
            || !selectedCategories.isEmpty
            || !selectedSubcategories.isEmpty
            || !selectedNeeds.isEmpty
            || !selectedTags.isEmpty
            || transactionTypeFilter != .all
            || amountCondition.isActive
            || !selectedCurrencies.isEmpty
            || !searchText.isEmpty
            || hasTransactionNatureFilter
            || sharedExpenseFilter != .all
    }

    /// Number of active filter types (for badge)
    var activeFilterCount: Int {
        var count = 0
        if !selectedAccounts.isEmpty { count += 1 }
        if !selectedCategories.isEmpty || !selectedSubcategories.isEmpty { count += 1 }
        if !selectedNeeds.isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if transactionTypeFilter != .all { count += 1 }
        if amountCondition.isActive { count += 1 }
        if !selectedCurrencies.isEmpty { count += 1 }
        if hasTransactionNatureFilter { count += 1 }
        if !searchText.isEmpty { count += 1 }
        if sharedExpenseFilter != .all { count += 1 }
        return count
    }

    // MARK: - Factory

    /// Empty filter criteria (no filters applied)
    nonisolated static let empty = FilterCriteria()

    // MARK: - Mutation

    /// Populate `selectedTagUUIDs` from the resolved Tag objects.
    /// SSOT for tag matching — readers prefer this CSV-aware set over the M2M-bound
    /// `selectedTags` (PersistentIdentifier) which can race with CloudKit lazy hydration.
    /// Callers que construyan FilterCriteria con tags MUST llamar esto.
    mutating func populateTagUUIDs(from tags: [Tag]) {
        selectedTagUUIDs = Set(tags.map(\.id))
    }

    /// Clear all filters
    mutating func clearAll() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedNeeds.removeAll()
        selectedTransactionNatures.removeAll()
        selectedTags.removeAll()
        selectedTagUUIDs.removeAll()
        selectedCurrencies.removeAll()
        transactionTypeFilter = .all
        isExcludeMode = false
        amountCondition = .any
        searchText = ""
        sharedExpenseFilter = .all
        // Note: dateInterval is NOT cleared as it's typically controlled by period selector
    }
}

// MARK: - Filter Service

/// Centralized service for filtering transactions.
/// Provides a single implementation of filtering logic used by all ViewModels.
struct FilterService {

    // MARK: - Main Filtering

    /// Filters transactions based on the provided criteria.
    ///
    /// - Parameters:
    ///   - transactions: All transactions to filter
    ///   - criteria: Filter criteria to apply
    /// - Returns: Filtered array of transactions
    static func filter(
        transactions: [TransactionItem],
        criteria: FilterCriteria
    ) -> [TransactionItem] {
        transactions.filter { transaction in
            matchesCriteria(transaction, criteria: criteria)
        }
    }

    /// Filters transactions and groups them by date (descending).
    ///
    /// - Parameters:
    ///   - transactions: All transactions to filter
    ///   - criteria: Filter criteria to apply
    /// - Returns: Array of tuples (date, records) sorted by date descending
    static func filterAndGroup(
        transactions: [TransactionItem],
        criteria: FilterCriteria
    ) -> [(date: Date, records: [TransactionItem])] {
        let filtered = filter(transactions: transactions, criteria: criteria)
        return groupByDate(filtered)
    }

    /// Groups transactions by date.
    ///
    /// - Parameter transactions: Transactions to group
    /// - Returns: Array of tuples (date, records) sorted by date descending
    static func groupByDate(
        _ transactions: [TransactionItem]
    ) -> [(date: Date, records: [TransactionItem])] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        return
            grouped
            .map { (date: $0.key, records: $0.value.sorted {
                return $0.createdAt > $1.createdAt
            }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Individual Matching

    /// Checks if a single transaction matches all criteria.
    ///
    /// - Parameters:
    ///   - transaction: Transaction to check
    ///   - criteria: Criteria to match against
    /// - Returns: True if transaction matches all criteria
    static func matchesCriteria(
        _ transaction: TransactionItem,
        criteria: FilterCriteria
    ) -> Bool {
        // Date filter
        if let interval = criteria.dateInterval {
            guard interval.contains(transaction.date) else { return false }
        }

        let isExclude = criteria.isExcludeMode

        // Entity filters (account, category, subcategory, nature, currency)
        if !matchesEntityFilter(transaction.account?.persistentModelID, selected: criteria.selectedAccounts, isExclude: isExclude) { return false }
        if !matchesEntityFilter(transaction.category?.persistentModelID, selected: criteria.selectedCategories, isExclude: isExclude) { return false }
        if !matchesEntityFilter(transaction.subcategory?.persistentModelID, selected: criteria.selectedSubcategories, isExclude: isExclude) { return false }
        // Transactions without subcategory are treated as .unclassified (consistent with PanelVM behavior)
        if !matchesEntityFilter(transaction.subcategory?.need ?? .unclassified, selected: criteria.selectedNeeds, isExclude: isExclude) { return false }

        // Tags filter (ANY match semantics). CSV-mirror SSOT vía `selectedTagUUIDs`
        // (poblado por `FilterCriteria.populateTagUUIDs(from:)` en cada builder).
        if !criteria.selectedTagUUIDs.isEmpty {
            let txTagUUIDs = transaction.resolvedTagIDs(scheduleBackfill: true) ?? []
            let hasOverlap = !txTagUUIDs.isDisjoint(with: criteria.selectedTagUUIDs)
            if isExclude {
                if hasOverlap { return false }
            } else {
                guard hasOverlap else { return false }
            }
        }

        // Transaction type filter (NOT affected by exclude mode)
        switch criteria.transactionTypeFilter {
        case .all:
            break
        case .income:
            guard transaction.category?.isIncome == true else { return false }
        case .expense:
            guard transaction.category?.isIncome == false else { return false }
        case .transfer:
            // Transfers don't have a category, or have special handling
            break
        }

        // Transaction nature filter (income/expense chips)
        // Always "include" semantics — exclude mode does NOT apply to transaction type
        // Empty = all, both selected = all, exactly 1 = filter
        if criteria.selectedTransactionNatures.count == 1 {
            if criteria.selectedTransactionNatures.contains(.income) {
                guard transaction.category?.isIncome == true else { return false }
            } else if criteria.selectedTransactionNatures.contains(.expense) {
                guard transaction.category?.isIncome == false else { return false }
            }
        }

        // Amount filter (absolute value) — NOT affected by exclude mode
        let amount = Decimal(transaction.amount)
        guard criteria.amountCondition.matches(abs(amount)) else { return false }

        // Currency filter
        if !matchesEntityFilter(CurrencyCode(rawValue: transaction.currencyCode), selected: criteria.selectedCurrencies, isExclude: isExclude) { return false }

        // Search text filter (note only — GlobalSearchView handles broad multi-field search)
        if !criteria.searchText.isEmpty {
            guard (transaction.note ?? "").localizedCaseInsensitiveContains(criteria.searchText) else {
                return false
            }
        }

        // Shared expense filter
        switch criteria.sharedExpenseFilter {
        case .all: break
        case .personal:
            guard transaction.splitExpenseID == nil else { return false }
        case .shared:
            guard transaction.splitExpenseID != nil else { return false }
        }

        return true
    }

    // MARK: - Filter for Trends (Accounts Pre-filtering)

    // MARK: - Entity Filter Helper

    /// Checks if a transaction value matches an entity filter set, respecting exclude mode.
    /// Returns true if the transaction should be included, false if it should be filtered out.
    private static func matchesEntityFilter<T: Hashable>(
        _ value: T?, selected: Set<T>, isExclude: Bool
    ) -> Bool {
        guard !selected.isEmpty else { return true }
        if isExclude {
            if let value, selected.contains(value) { return false }
            return true
        } else {
            guard let value, selected.contains(value) else { return false }
            return true
        }
    }

    /// Filters transactions for trend calculations, considering account eligibility.
    ///
    /// - Parameters:
    ///   - transactions: All transactions
    ///   - accounts: All accounts (used to filter by excludeFromStatistics)
    ///   - criteria: Filter criteria
    /// - Returns: Filtered transactions for trend calculation
    static func filterForTrends(
        transactions: [TransactionItem],
        accounts: [Account],
        criteria: FilterCriteria,
        includeBridgedGroupTx: Bool? = nil
    ) -> [TransactionItem] {
        // Si caller no pasa flag explícito, lee toggle global desde UserDefaults
        // (default true cuando key ausente). Esto evita cablear 15 callsites stats
        // manualmente; cada VM recibe la decisión correcta sin cambios.
        let includeFlag = includeBridgedGroupTx
            ?? (SessionDefaults.current.object(forKey: AppPreferences.Keys.includeGroupTransactionsInStats) as? Bool)
            ?? true
        // Determine eligible accounts (not excluded from statistics; archived accounts still count)
        let eligibleAccounts = accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            if criteria.selectedAccounts.isEmpty { return true }
            if criteria.isExcludeMode {
                return !criteria.selectedAccounts.contains(account.persistentModelID)
            } else {
                return criteria.selectedAccounts.contains(account.persistentModelID)
            }
        }
        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        return transactions.filter { transaction in
            // First check account eligibility
            guard let account = transaction.account,
                eligibleAccountIDs.contains(account.persistentModelID)
            else { return false }

            // Opt-out: cuando bridged group TX excluidas, filtrar antes de criteria.
            guard BridgedTransactionFilter.shouldInclude(
                splitExpenseID: transaction.splitExpenseID,
                splitSettlementID: transaction.splitSettlementID,
                includeGroupsToggle: includeFlag
            ) else { return false }

            // Then apply remaining filters
            return matchesCriteria(transaction, criteria: criteria)
        }
    }
}
