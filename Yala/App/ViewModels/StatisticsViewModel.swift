//
//  StatisticsViewModel.swift
//  Yala
//
//  ViewModel for the Trends Detail View.
//

import Foundation
import SwiftData
import SwiftUI

/// ViewModel for the Trends Detail View
/// Manages filter state, metric selection, and data calculations
@MainActor
@Observable
final class StatisticsViewModel: Filterable {

    // MARK: - Navigation State

    /// Currently selected tab
    var selectedTab: DetailViewTab = .trends

    // MARK: - Metric State (SSOT: Read/Write from SessionState.shared)

    /// Currently selected metric (Saldo, Ingreso, Gasto)
    var selectedMetric: TrendMetric {
        get { SessionState.shared.selectedTrendMetric }
        set { SessionState.shared.selectedTrendMetric = newValue }
    }

    /// Whether to show aggregated view (true) or per-account view (false)
    var isAggregatedView: Bool = true

    // MARK: - Trend Locking Logic

    /// Metric lock state based on active filters
    enum MetricLockState {
        case none           // No lock, user can select any metric
        case lockedIncome   // Locked to income (only income filter selected)
        case lockedExpense  // Locked to expense (category/nature filters or only expense filter)
    }

    // Check if category/subcategory/nature filters require expense mode
    var hasExpenseOnlyFilters: Bool {
        !selectedCategories.isEmpty || !selectedSubcategories.isEmpty || !selectedNatures.isEmpty
    }

    /// Enforce metric logic based on filters
    /// Simple rule: chip is source of truth, category/nature filters auto-create expense chip
    private func enforceMetricLock() {
        // In expenses-only mode, always force expense metric
        if SessionState.shared.isExpensesOnlyMode {
            selectedMetric = .expense
            return
        }

        // Derive selectedMetric from selectedTransactionNatures (single source of truth)
        if selectedTransactionNatures.count == 1 {
            if selectedTransactionNatures.contains(.income) {
                selectedMetric = .income
            } else if selectedTransactionNatures.contains(.expense) {
                selectedMetric = .expense
            }
        } else if selectedTransactionNatures.isEmpty && !hasExpenseOnlyFilters {
            // No chip and no expense-only filters = balance
            selectedMetric = .balance
        }
        // Note: if hasExpenseOnlyFilters, the chip should have been set by the view's onChange
    }

    /// Called when user manually selects a metric (legacy - selector now sets chips directly)
    func setMetricManually(_ metric: TrendMetric) {
        selectedMetric = metric
    }

    // MARK: - Filter State (SSOT: Read/Write from SessionState.shared)

    /// Selected accounts for filtering (empty = all)
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

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedTags }
        set { SessionState.shared.selectedTags = newValue }
    }

    /// Selected natures for filtering
    var selectedNatures: Set<SubcategoryNature> {
        get { SessionState.shared.selectedNatures }
        set { SessionState.shared.selectedNatures = newValue }
    }

    /// Selected transaction natures for filtering (empty = all)
    /// Used for income/expense filter chips in Statistics
    var selectedTransactionNatures: Set<TransactionNature> {
        get { SessionState.shared.selectedTransactionNatures }
        set { SessionState.shared.selectedTransactionNatures = newValue }
    }

    /// Selected currencies for filtering (empty = all)
    var selectedCurrencies: Set<CurrencyCode> {
        get { SessionState.shared.selectedCurrencies }
        set { SessionState.shared.selectedCurrencies = newValue }
    }

    /// Amount filter condition
    var amountCondition: AmountFilterCondition {
        get { SessionState.shared.amountCondition }
        set { SessionState.shared.amountCondition = newValue }
    }

    /// Search text for note filtering
    var searchText: String {
        get { SessionState.shared.searchText }
        set { SessionState.shared.searchText = newValue }
    }

    var isExcludeMode: Bool {
        get { SessionState.shared.isExcludeMode }
        set { SessionState.shared.isExcludeMode = newValue }
    }

    /// Selected period (using DetailPeriod for expanded options)
    var detailPeriod: DetailPeriod {
        get { SessionState.shared.selectedPeriod }
        set { SessionState.shared.selectedPeriod = newValue }
    }

    /// Custom date range (synced from SessionState)
    var customDateRange: DateInterval? {
        get { SessionState.shared.customDateRange }
        set { SessionState.shared.customDateRange = newValue }
    }

    // MARK: - Sheet State

    /// Whether to show the filters sheet
    var showFiltersSheet: Bool = false

    /// Focused date for chart scrubbing interaction
    var focusedDate: Date? = nil

    // MARK: - Computed Data

    /// Trend data points for the chart (may be smoothed for visualization)
    var trendPoints: [PanelViewModel.BarPoint] = []
    /// Original unsmoothed points for hover/KPI display
    var rawTrendPoints: [PanelViewModel.BarPoint] = []

    /// The metric that the current trendPoints data corresponds to
    /// Used to prevent rendering stale data with the wrong color during metric switches
    var dataMetric: TrendMetric = .balance

    /// Y-axis domain for the chart
    var yDomain: ClosedRange<Double> = 0...100

    /// Trend grouping based on period
    var trendGrouping: TrendGrouping = .month

    /// Date interval for the current period
    var currentInterval: DateInterval = DateInterval(start: Date(), end: Date())

    /// Per-account trend series (when not aggregated)
    var accountSeries: [AccountTrendSeries] = []

    /// Recent records for the "Últimos registros" section
    var recentRecords: [TransactionItem] = []

    /// Total income for the current period (calculated from transactions)
    var totalIncome: Double = 0

    /// Total expense for the current period (calculated from transactions)
    var totalExpense: Double = 0

    /// Current actual balance (sum of accounts' current balance)
    var currentBalance: Double = 0

    /// Maximum number of records to show
    let maxRecentRecords: Int = 10

    /// Chart X-axis domain derived from actual data points
    var chartDomain: ClosedRange<Date> {
        guard let firstPoint = trendPoints.first?.date,
            let lastPoint = trendPoints.last?.date
        else {
            return currentInterval.start...currentInterval.end
        }
        return firstPoint...lastPoint
    }

    /// Total value for the selected metric (for KPI display)
    var totalMetricValue: Double {
        switch selectedMetric {
        case .balance:
            // For balance, show the latest value (current balance)
            return trendPoints.last?.value ?? 0
        case .income:
            // For income, use pre-calculated sum from transactions
            return totalIncome
        case .expense:
            // For expense, use pre-calculated sum from transactions
            return totalExpense
        }
    }

    // MARK: - Initialization

    init(context: StatisticsContext) {
        self.selectedMetric = context.initialMetric
        // Note: detailPeriod is NOT set here because it's a computed property that writes to SessionState.
        // Setting it would overwrite the user's period selection. The period comes from SessionState directly.

        if let accountID = context.accountID {
            self.selectedAccounts = [accountID]
        }

        if let categoryID = context.categoryID {
            self.selectedCategories = [categoryID]
        }

        if let nature = context.nature {
            self.selectedNatures = [nature]
        }

        if let interval = context.dateInterval {
            self.currentInterval = interval
        }
    }

    // MARK: - Computed Properties

    /// Whether any filters are active
    var hasActiveFilters: Bool {
        !selectedAccounts.isEmpty
            || !selectedCategories.isEmpty
            || !selectedSubcategories.isEmpty
            || !selectedTags.isEmpty
            || !selectedNatures.isEmpty
            || !selectedCurrencies.isEmpty
            || !searchText.isEmpty
            || amountCondition.isActive
            || hasTransactionNatureFilter
    }

    /// Whether transaction nature filter shows a chip (exactly 1 selected)
    var hasTransactionNatureFilter: Bool {
        selectedTransactionNatures.count == 1
    }

    /// Number of active filter types
    var activeFilterCount: Int {
        var count = 0
        if !selectedAccounts.isEmpty { count += 1 }
        if !selectedCategories.isEmpty || !selectedSubcategories.isEmpty { count += 1 }
        if !selectedNatures.isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if !selectedCurrencies.isEmpty { count += 1 }
        if !searchText.isEmpty { count += 1 }
        if amountCondition.isActive { count += 1 }
        if hasTransactionNatureFilter { count += 1 }
        return count
    }

    /// Clear all active filters
    func clearFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedTags.removeAll()
        selectedNatures.removeAll()
        selectedTransactionNatures.removeAll()
        selectedCurrencies.removeAll()
        searchText = ""
        amountCondition = .any
        isExcludeMode = false
    }

    // MARK: - Period Interval

    /// Calculate the date interval for the current period
    var panelDateInterval: DateInterval {
        detailPeriod.dateInterval(customRange: customDateRange)
    }

    // MARK: - Data Calculation

    /// Calculate trend data based on current filters and metric
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) {

        // Enforce metric lock based on filters
        enforceMetricLock()

        // Always use day grouping so chart data reaches today
        // The x-axis display will still show months for yearly view
        trendGrouping = .day

        // Get interval
        let interval = panelDateInterval
        currentInterval = interval

        // Build FilterCriteria from current state
        // For balance: NO date filter - processor needs all transactions to calculate running balance
        // For income/expense: WITH date filter - we only want transactions in the period
        let isBalanceMetric = selectedMetric == .balance

        let criteria = FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNatures: selectedNatures,
            selectedCurrencies: selectedCurrencies,
            isExcludeMode: isExcludeMode,
            transactionTypeFilter: .all,  // TrendsView handles metric filtering separately
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: isBalanceMetric ? nil : interval
        )

        // Use FilterService for filtering with account eligibility
        let filtered = FilterService.filterForTrends(
            transactions: transactions,
            accounts: accounts,
            criteria: criteria
        )

        // Get eligible accounts for trend calculations (archived accounts still count)
        let eligibleAccounts = accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            if selectedAccounts.isEmpty { return true }
            if isExcludeMode {
                return !selectedAccounts.contains(account.persistentModelID)
            } else {
                return selectedAccounts.contains(account.persistentModelID)
            }
        }

        // Calculate total income and expense from filtered transactions
        // Exclude balance adjustments - they only affect balance, not income/expense
        totalIncome =
            filtered
            .filter { $0.amountInPreferredCurrency > 0 && $0.balanceAdjustmentType == nil }
            .reduce(0) { $0 + $1.amountInPreferredCurrency }

        totalExpense =
            filtered
            .filter { $0.amountInPreferredCurrency < 0 && $0.balanceAdjustmentType == nil }
            .reduce(0) { $0 + abs($1.amountInPreferredCurrency) }

        // Calculate current actual balance from eligible accounts
        // This is the TRUE balance, calculated from transactions (initial balance is now a transaction)
        currentBalance = eligibleAccounts.reduce(0.0) { total, account in
            let transactionSum =
                transactions
                .filter { $0.account?.persistentModelID == account.persistentModelID }
                .reduce(0.0) { $0 + $1.amountInPreferredCurrency }
            return total + transactionSum
        }

        // Calculate trend points based on metric using unified TrendDataProcessor
        if isAggregatedView {
            // Use unified TrendDataProcessor for identical results to TrendCardView
            let result = TrendDataProcessor.processTrendData(
                transactions: filtered,
                accounts: eligibleAccounts,
                metric: mapMetricToTrendType(selectedMetric),
                period: detailPeriod,
                grouping: trendGrouping,
                interval: interval,
                currencyCode: defaultCurrencyCode,
                context: context
            )
            trendPoints = result.points
            rawTrendPoints = result.rawPoints
            yDomain = result.yDomain
            totalIncome = result.totalIncome
            totalExpense = result.totalExpense
            dataMetric = selectedMetric
        } else {
            calculatePerAccountTrend(
                transactions: filtered,
                accounts: eligibleAccounts,
                interval: interval,
                defaultCurrencyCode: defaultCurrencyCode,
                context: context
            )
        }

        // Calculate recent records filtered by selected metric
        // For income/expense, exclude balance adjustments
        let metricFiltered: [TransactionItem]
        switch selectedMetric {
        case .balance:
            metricFiltered = filtered
        case .income:
            metricFiltered = filtered.filter {
                $0.amountInPreferredCurrency > 0 && $0.balanceAdjustmentType == nil
            }
        case .expense:
            metricFiltered = filtered.filter {
                $0.amountInPreferredCurrency < 0 && $0.balanceAdjustmentType == nil
            }
        }
        recentRecords = Array(
            metricFiltered.sorted {
                return $0.createdAt > $1.createdAt
            }.prefix(maxRecentRecords)
        )
    }

    /// Convert TrendMetric to TrendType for TrendDataProcessor
    private func mapMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    /// Calculate per-account trend (multiple lines)
    private func calculatePerAccountTrend(
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        defaultCurrencyCode: String,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        var allSeries: [AccountTrendSeries] = []

        // Generate bucket dates
        var bucketDates: [Date] = []
        var current = trendGrouping.dateKey(for: interval.start, calendar: calendar)
        let endDate = interval.end

        while current <= endDate {
            bucketDates.append(current)
            if let next = calendar.date(
                byAdding: trendGrouping.calendarComponent, value: 1, to: current)
            {
                current = next
            } else {
                break
            }
        }

        // Colors for accounts
        let accountColors: [Color] = [
            .electricIndigo, .hotPink, .brandPrimary, .teal, .orange, .purple, .green,
        ]

        for (index, account) in accounts.enumerated() {
            var buckets: [Date: Double] = Dictionary(
                uniqueKeysWithValues: bucketDates.map { ($0, 0.0) })

            let accountTransactions = transactions.filter {
                $0.account?.persistentModelID == account.persistentModelID
            }

            switch selectedMetric {
            case .balance:
                // Initial balance is now a transaction, start from 0
                var runningBalance = 0.0

                // Add transactions before interval
                let allAccountTxns = transactions.filter {
                    $0.account?.persistentModelID == account.persistentModelID
                }
                for txn in allAccountTxns where txn.date < interval.start {
                    runningBalance += txn.amountInPreferredCurrency
                }

                // Fill buckets
                let transactionsByBucket = Dictionary(grouping: accountTransactions) { txn in
                    trendGrouping.dateKey(for: txn.date, calendar: calendar)
                }

                for date in bucketDates.sorted() {
                    if let txns = transactionsByBucket[date] {
                        for txn in txns {
                            runningBalance += txn.amountInPreferredCurrency
                        }
                    }
                    buckets[date] = runningBalance
                }

            case .income:
                // Exclude balance adjustments from income
                for txn in accountTransactions
                where txn.amountInPreferredCurrency > 0 && txn.balanceAdjustmentType == nil {
                    let bucketDate = trendGrouping.dateKey(for: txn.date, calendar: calendar)
                    buckets[bucketDate, default: 0] += txn.amountInPreferredCurrency
                }

            case .expense:
                // Exclude balance adjustments from expense
                for txn in accountTransactions
                where txn.amountInPreferredCurrency < 0 && txn.balanceAdjustmentType == nil {
                    let bucketDate = trendGrouping.dateKey(for: txn.date, calendar: calendar)
                    buckets[bucketDate, default: 0] += abs(txn.amountInPreferredCurrency)
                }
            }

            let points = buckets.map { date, value in
                PanelViewModel.BarPoint(date: date, value: value)
            }.sorted { $0.date < $1.date }

            allSeries.append(
                AccountTrendSeries(
                    id: account.persistentModelID,
                    accountName: account.name,
                    color: accountColors[index % accountColors.count],
                    points: points
                )
            )
        }

        accountSeries = allSeries

        // Calculate Y domain from all series
        let allValues = allSeries.flatMap { $0.points.map { $0.value } }
        if let minVal = allValues.min(), let maxVal = allValues.max() {
            let padding = (maxVal - minVal) * 0.1
            yDomain = (minVal - padding)...(maxVal + padding)
        } else {
            yDomain = 0...100
        }

        // Also update trendPoints for compatibility (use first series or sum)
        if let first = allSeries.first {
            trendPoints = first.points
            dataMetric = selectedMetric
        }
    }

    // MARK: - Filter Actions

    /// Clear all filters
    /// Build filter context for RecordsListView navigation
    func buildRecordsContext() -> RecordsFilterContext {
        var transactionType: TransactionTypeFilter?
        switch selectedMetric {
        case .income:
            transactionType = .income
        case .expense:
            transactionType = .expense
        case .balance:
            transactionType = nil  // or .all, nil allows default behavior
        }

        return RecordsFilterContext(
            accountID: selectedAccounts.first,
            categoryID: selectedCategories.first,
            subcategoryName: nil,
            nature: selectedNatures.first,
            transactionType: transactionType,
            period: detailPeriod
        )
    }

}

// MARK: - Account Trend Series

/// Represents a trend series for a single account
struct AccountTrendSeries: Identifiable {
    let id: PersistentIdentifier
    let accountName: String
    let color: Color
    let points: [PanelViewModel.BarPoint]
}
