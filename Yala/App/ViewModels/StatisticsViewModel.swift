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

    // Check if any category/subcategory/need filters are active
    var hasCategoryFilters: Bool {
        guard !isExcludeMode else { return false }
        return !selectedCategories.isEmpty || !selectedSubcategories.isEmpty || !selectedNeeds.isEmpty
    }

    /// Enforce metric logic based on filters
    /// Simple rule: chip is source of truth, category/need filters auto-create expense chip
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
        } else if selectedTransactionNatures.isEmpty && !hasCategoryFilters {
            // No chip and no category filters = balance
            selectedMetric = .balance
        }
        // Note: if hasCategoryFilters, the chip should have been set by the view's onChange
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

    /// Selected needs for filtering
    var selectedNeeds: Set<SubcategoryNeed> {
        get { SessionState.shared.selectedNeeds }
        set { SessionState.shared.selectedNeeds = newValue }
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

    var sharedExpenseFilter: SharedExpenseFilter = .all

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
    var currentInterval: DateInterval = DateInterval(start: Date.now, end: Date.now)

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

        if let need = context.need {
            self.selectedNeeds = [need]
        }

        if let interval = context.dateInterval {
            self.currentInterval = interval
        }
    }

    // MARK: - Computed Properties

    /// Whether any filters are active (delegates to Filterable.filterCriteria)
    var hasActiveFilters: Bool { filterCriteria.hasActiveFilters }

    /// Whether transaction nature filter shows a chip (exactly 1 selected)
    var hasTransactionNatureFilter: Bool {
        selectedTransactionNatures.count == 1
    }

    /// Number of active filter types (delegates to Filterable.filterCriteria)
    var activeFilterCount: Int { filterCriteria.activeFilterCount }

    /// Clear all active filters
    func clearFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedTags.removeAll()
        selectedNeeds.removeAll()
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
        defaultCurrencyCode: String
    ) {
        // Enforce metric lock based on filters
        enforceMetricLock()

        // Always use day grouping so chart data reaches today
        trendGrouping = .day

        // Get interval
        let interval = panelDateInterval
        currentInterval = interval

        // Build filter criteria and apply
        let criteria = buildTrendFilterCriteria(interval: interval)

        let filtered = FilterService.filterForTrends(
            transactions: transactions,
            accounts: accounts,
            criteria: criteria
        )

        let eligibleAccounts = computeEligibleAccounts(from: accounts)

        // Calculate totals from filtered data
        calculateTotals(
            filtered: filtered,
            eligibleAccounts: eligibleAccounts,
            allTransactions: transactions
        )

        // Calculate trend points based on metric using unified TrendDataProcessor
        if isAggregatedView {
            let result = TrendDataProcessor.processTrendData(
                transactions: filtered,
                accounts: eligibleAccounts,
                metric: mapMetricToTrendType(selectedMetric),
                period: detailPeriod,
                grouping: trendGrouping,
                interval: interval,
                currencyCode: defaultCurrencyCode
            )
            if result.points != trendPoints { trendPoints = result.points }
            if result.rawPoints != rawTrendPoints { rawTrendPoints = result.rawPoints }
            yDomain = result.yDomain
            if result.totalIncome != totalIncome { totalIncome = result.totalIncome }
            if result.totalExpense != totalExpense { totalExpense = result.totalExpense }
            dataMetric = selectedMetric
        } else {
            calculatePerAccountTrend(
                transactions: filtered,
                accounts: eligibleAccounts,
                interval: interval,
                defaultCurrencyCode: defaultCurrencyCode
            )
        }

        // Calculate recent records
        buildRecentRecords(from: filtered)
    }

    // MARK: - Calculation Helpers

    /// Build FilterCriteria for trend calculations
    private func buildTrendFilterCriteria(interval: DateInterval) -> FilterCriteria {
        let isBalanceMetric = selectedMetric == .balance
        return FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNeeds: selectedNeeds,
            selectedCurrencies: selectedCurrencies,
            isExcludeMode: isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: isBalanceMetric ? nil : interval
        )
    }

    /// Compute eligible accounts for trend calculations (archived accounts still count)
    private func computeEligibleAccounts(from accounts: [Account]) -> [Account] {
        accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            if selectedAccounts.isEmpty { return true }
            if isExcludeMode {
                return !selectedAccounts.contains(account.persistentModelID)
            } else {
                return selectedAccounts.contains(account.persistentModelID)
            }
        }
    }

    /// Calculate total income, expense, and current balance
    private func calculateTotals(
        filtered: [TransactionItem],
        eligibleAccounts: [Account],
        allTransactions: [TransactionItem]
    ) {
        let newIncome =
            filtered
            .filter { $0.amountInPreferredCurrency > 0 && $0.balanceAdjustmentType == nil }
            .reduce(0) { $0 + $1.amountInPreferredCurrency }
        if newIncome != totalIncome { totalIncome = newIncome }

        let newExpense =
            filtered
            .filter { $0.amountInPreferredCurrency < 0 && $0.balanceAdjustmentType == nil }
            .reduce(0) { $0 + abs($1.amountInPreferredCurrency) }
        if newExpense != totalExpense { totalExpense = newExpense }

        let newBalance = eligibleAccounts.reduce(0.0) { total, account in
            let transactionSum =
                allTransactions
                .filter { $0.account?.persistentModelID == account.persistentModelID }
                .reduce(0.0) { $0 + $1.amountInPreferredCurrency }
            return total + transactionSum
        }
        if newBalance != currentBalance { currentBalance = newBalance }
    }

    /// Build recent records filtered by selected metric
    private func buildRecentRecords(from filtered: [TransactionItem]) {
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
        let newRecent = Array(
            metricFiltered.sorted {
                return $0.createdAt > $1.createdAt
            }.prefix(maxRecentRecords)
        )
        if newRecent != recentRecords { recentRecords = newRecent }
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
        defaultCurrencyCode: String
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

        if allSeries != accountSeries { accountSeries = allSeries }

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
            need: selectedNeeds.first,
            transactionType: transactionType,
            period: detailPeriod
        )
    }

}

// MARK: - Account Trend Series

/// Represents a trend series for a single account
struct AccountTrendSeries: Identifiable, Equatable {
    let id: PersistentIdentifier
    let accountName: String
    let color: Color
    let points: [PanelViewModel.BarPoint]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.accountName == rhs.accountName
            && lhs.points == rhs.points
    }
}
