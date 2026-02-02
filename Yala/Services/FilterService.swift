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

// MARK: - Filter Criteria

/// Unified filter criteria used across all views that filter transactions.
/// This eliminates the need for each ViewModel to define its own filter state separately.
struct FilterCriteria: Equatable {

    // MARK: - Entity Filters

    /// Selected accounts for filtering (empty = all accounts)
    var selectedAccounts: Set<PersistentIdentifier> = []

    /// Selected categories for filtering (empty = all categories)
    var selectedCategories: Set<PersistentIdentifier> = []

    /// Selected subcategories for filtering (empty = all subcategories)
    var selectedSubcategories: Set<PersistentIdentifier> = []

    /// Selected tags for filtering (empty = all tags)
    var selectedTags: Set<PersistentIdentifier> = []

    /// Selected natures for filtering (empty = all natures)
    var selectedNatures: Set<SubcategoryNature> = []

    /// Selected transaction natures for filtering (empty = all, income/expense)
    var selectedTransactionNatures: Set<TransactionNature> = []

    /// Selected currencies for filtering (empty = all currencies)
    var selectedCurrencies: Set<CurrencyCode> = []

    // MARK: - Value Filters

    /// Transaction type filter (all, income, expense, transfer)
    var transactionTypeFilter: TransactionTypeFilter = .all

    /// Amount condition filter
    var amountCondition: AmountFilterCondition = .any

    /// Search text for note filtering
    var searchText: String = ""

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
            || !selectedNatures.isEmpty
            || !selectedTags.isEmpty
            || transactionTypeFilter != .all
            || amountCondition.isActive
            || !selectedCurrencies.isEmpty
            || !searchText.isEmpty
            || hasTransactionNatureFilter
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
        if !selectedCurrencies.isEmpty { count += 1 }
        if hasTransactionNatureFilter { count += 1 }
        return count
    }

    // MARK: - Factory

    /// Empty filter criteria (no filters applied)
    static let empty = FilterCriteria()

    // MARK: - Mutation

    /// Clear all filters
    mutating func clearAll() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedNatures.removeAll()
        selectedTransactionNatures.removeAll()
        selectedTags.removeAll()
        selectedCurrencies.removeAll()
        transactionTypeFilter = .all
        amountCondition = .any
        searchText = ""
        // Note: dateInterval is NOT cleared as it's typically controlled by period selector
    }
}

// MARK: - Filter Type Enum

/// Types of filters for UI callbacks (e.g., when removing a filter chip)
enum FilterType {
    case accounts
    case categories
    case subcategories
    case tags
    case natures
    case currencies
    case transactionType
    case amount
    case search
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
            .map { (date: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
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

        // Account filter
        if !criteria.selectedAccounts.isEmpty {
            guard let accountID = transaction.account?.persistentModelID,
                criteria.selectedAccounts.contains(accountID)
            else { return false }
        }

        // Category filter
        if !criteria.selectedCategories.isEmpty {
            guard let categoryID = transaction.category?.persistentModelID,
                criteria.selectedCategories.contains(categoryID)
            else { return false }
        }

        // Subcategory filter
        if !criteria.selectedSubcategories.isEmpty {
            guard let subcategoryID = transaction.subcategory?.persistentModelID,
                criteria.selectedSubcategories.contains(subcategoryID)
            else { return false }
        }

        // Nature filter
        if !criteria.selectedNatures.isEmpty {
            guard let subcategory = transaction.subcategory,
                criteria.selectedNatures.contains(subcategory.nature)
            else { return false }
        }

        // Tags filter (match if ANY selected tag is present)
        if !criteria.selectedTags.isEmpty {
            let transactionTagIDs = Set((transaction.tags ?? []).map { $0.persistentModelID })
            guard !transactionTagIDs.isDisjoint(with: criteria.selectedTags) else { return false }
        }

        // Transaction type filter
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
        // Empty = all, both selected = all, exactly 1 = filter
        if criteria.selectedTransactionNatures.count == 1 {
            if criteria.selectedTransactionNatures.contains(.income) {
                // Only income: positive amounts (category.isIncome == true)
                guard transaction.category?.isIncome == true else { return false }
            } else if criteria.selectedTransactionNatures.contains(.expense) {
                // Only expense: negative amounts (category.isIncome == false)
                guard transaction.category?.isIncome == false else { return false }
            }
        }

        // Amount filter (absolute value)
        let amount = Decimal(transaction.amount)
        guard criteria.amountCondition.matches(abs(amount)) else { return false }

        // Currency filter
        if !criteria.selectedCurrencies.isEmpty {
            guard let currencyCode = CurrencyCode(rawValue: transaction.currencyCode),
                criteria.selectedCurrencies.contains(currencyCode)
            else { return false }
        }

        // Search text filter (searches in note, category, subcategory, account, tags)
        if !criteria.searchText.isEmpty {
            let search = criteria.searchText.lowercased()
            let noteMatch = (transaction.note ?? "").lowercased().contains(search)
            let categoryMatch = (transaction.category?.name ?? "").lowercased().contains(search)
            let subcategoryMatch = (transaction.subcategory?.name ?? "").lowercased().contains(
                search)
            let accountMatch = (transaction.account?.name ?? "").lowercased().contains(search)
            let tagMatch = (transaction.tags ?? []).contains { $0.name.lowercased().contains(search) }

            guard noteMatch || categoryMatch || subcategoryMatch || accountMatch || tagMatch else {
                return false
            }
        }

        return true
    }

    // MARK: - Filter for Trends (Accounts Pre-filtering)

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
        criteria: FilterCriteria
    ) -> [TransactionItem] {
        // Determine eligible accounts (not excluded from statistics, not archived)
        let eligibleAccounts = accounts.filter { account in
            !account.excludeFromStatistics
                && !account.isArchived
                && (criteria.selectedAccounts.isEmpty
                    || criteria.selectedAccounts.contains(account.persistentModelID))
        }
        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        return transactions.filter { transaction in
            // First check account eligibility
            guard let account = transaction.account,
                eligibleAccountIDs.contains(account.persistentModelID)
            else { return false }

            // Then apply remaining filters
            return matchesCriteria(transaction, criteria: criteria)
        }
    }
}
