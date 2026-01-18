//
//  PanelCalculationContext.swift
//  Neto
//
//  Shared context for Panel widget calculations.
//

import Foundation
import SwiftData

/// Shared context data used by all Panel widget calculations.
/// Created once per calculation cycle and passed to each widget's calculate method.
struct PanelCalculationContext {

    // MARK: - Input Data

    /// All accounts from the database
    let accounts: [Account]

    /// All transactions from the database
    let transactions: [TransactionItem]

    /// User's preferred currency code
    let defaultCurrencyCode: String

    /// SwiftData model context for any additional fetches
    let modelContext: ModelContext

    // MARK: - Computed Filter Data

    /// Accounts eligible for statistics (not archived, not excluded)
    let eligibleAccounts: [Account]

    /// IDs of eligible accounts for fast lookup
    let eligibleAccountIDs: Set<PersistentIdentifier>

    /// Transactions filtered by account, date, and global filters (includes adjustments for balance)
    let filteredTransactions: [TransactionItem]

    /// Transactions for expense analysis (excludes adjustments and initial balances)
    let expenseFilteredTransactions: [TransactionItem]

    /// Transactions for category/subcategory widgets (respects focus date, excludes adjustments)
    let contextTransactions: [TransactionItem]

    // MARK: - Pre-Filtered Data (Efficiency Optimization)

    /// Context transactions with nature filter pre-applied (avoids duplicate filtering)
    let natureFilteredTransactions: [TransactionItem]

    /// Nature-filtered transactions with subcategory filter pre-applied
    let fullyFilteredTransactions: [TransactionItem]

    /// Transactions for nature widget - has cat/subcat filters but NO nature filter
    /// Allows nature widget to show ALL natures with dimming behavior
    let natureWidgetTransactions: [TransactionItem]

    /// Transactions with all filters EXCEPT date (for previous period comparison)
    /// Has: account, category, subcategory, nature, tags, currency, amount filters
    /// Does NOT have: date filter
    let transactionsWithoutDateFilter: [TransactionItem]

    /// Transactions for balance calculation (includes adjustments, no date filter)
    /// Same filters as filteredTransactions but without date filter
    /// INCLUDES adjustments (needed for running balance calculation)
    let balanceTransactions: [TransactionItem]

    // MARK: - Period & Interval

    /// The selected display period
    let period: DetailPeriod

    /// Effective date interval (optimized for All Time)
    let effectiveInterval: DateInterval

    // MARK: - Groupings

    /// Grouping for main trend chart
    let trendGrouping: TrendGrouping

    /// Grouping for cash flow widget
    let cashFlowGrouping: TrendGrouping

    /// Grouping for nature trend widget
    let natureGrouping: TrendGrouping

    // MARK: - Active Filters

    /// Currently focused date (from chart scrubbing)
    let focusedDate: Date?

    /// Currently selected category filter
    let selectedCategoryID: PersistentIdentifier?

    /// Currently selected subcategory filters (by PersistentIdentifier, supports multiple)
    let selectedSubcategoryIDs: Set<PersistentIdentifier>

    /// Currently selected nature filter
    let selectedNature: SubcategoryNature?

    /// Subcategories widget category filter
    let subcategoriesWidgetFilter: PersistentIdentifier?
}
