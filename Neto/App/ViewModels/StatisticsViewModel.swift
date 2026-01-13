//
//  StatisticsViewModel.swift
//  Neto
//
//  ViewModel for the Trends Detail View.
//

import Foundation
import SwiftData
import SwiftUI

/// ViewModel for the Trends Detail View
/// Manages filter state, metric selection, and data calculations
@Observable
final class StatisticsViewModel: Filterable {

    // MARK: - Navigation State

    /// Currently selected tab
    var selectedTab: DetailViewTab = .trends

    // MARK: - Metric State

    /// Currently selected metric (Saldo, Ingreso, Gasto)
    var selectedMetric: TrendMetric = .balance

    /// Whether to show aggregated view (true) or per-account view (false)
    var isAggregatedView: Bool = true

    // MARK: - Trend Locking Logic

    /// Determines if metric should be locked to expense due to active filters
    var isMetricLockedToExpense: Bool {
        !selectedCategories.isEmpty || !selectedSubcategories.isEmpty || !selectedNatures.isEmpty
    }

    /// Track if the current expense selection was automatic (due to filters) or manual (user click)
    private var isExpenseAutomatic: Bool = false

    /// Enforce metric lock: switch to expense when filters applied
    private func enforceMetricLock() {
        if isMetricLockedToExpense {
            // Lock to expense when filters are applied (automatic)
            if selectedMetric != .expense {
                selectedMetric = .expense
                isExpenseAutomatic = true
            }
        } else {
            // When filters are cleared, reset to balance ONLY if expense was automatic
            if selectedMetric == .expense && isExpenseAutomatic {
                selectedMetric = .balance
                isExpenseAutomatic = false
            }
        }
    }

    /// Called when user manually selects a metric
    func setMetricManually(_ metric: TrendMetric) {
        selectedMetric = metric
        // Mark as manual selection (not automatic)
        isExpenseAutomatic = false
    }

    // MARK: - Filter State

    /// Selected accounts for filtering (empty = all)
    var selectedAccounts: Set<PersistentIdentifier> = []

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> = []

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> = []

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> = []

    /// Selected natures for filtering
    var selectedNatures: Set<SubcategoryNature> = []

    /// Selected currencies for filtering (empty = all)
    var selectedCurrencies: Set<CurrencyCode> = []

    /// Amount filter condition
    var amountCondition: AmountFilterCondition = .any

    /// Search text for note filtering
    var searchText: String = ""

    /// Selected period (using DetailPeriod for expanded options)
    var detailPeriod: DetailPeriod = .thisMonth

    /// Custom date range start
    var customStartDate: Date =
        Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

    /// Custom date range end
    var customEndDate: Date = Date()

    // MARK: - Sheet State

    /// Whether to show the filters sheet
    var showFiltersSheet: Bool = false

    /// Focused date for chart scrubbing interaction
    var focusedDate: Date? = nil

    // MARK: - Computed Data

    /// Trend data points for the chart
    var trendPoints: [PanelViewModel.BarPoint] = []

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
        self.detailPeriod = context.period

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
        return count
    }

    /// Clear all active filters
    func clearFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedTags.removeAll()
        selectedNatures.removeAll()
        selectedCurrencies.removeAll()
        searchText = ""
        amountCondition = .any
    }

    // MARK: - Period Interval

    /// Calculate the date interval for the current period
    var panelDateInterval: DateInterval {
        detailPeriod.dateInterval()
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
        let criteria = FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNatures: selectedNatures,
            selectedCurrencies: selectedCurrencies,
            transactionTypeFilter: .all,  // TrendsView handles metric filtering separately
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: interval
        )

        // Use FilterService for filtering with account eligibility
        let filtered = FilterService.filterForTrends(
            transactions: transactions,
            accounts: accounts,
            criteria: criteria
        )

        // Get eligible accounts for trend calculations
        let eligibleAccounts = accounts.filter { account in
            !account.isArchived
                && !account.excludeFromStatistics
                && (selectedAccounts.isEmpty
                    || selectedAccounts.contains(account.persistentModelID))
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
            metricFiltered.sorted { $0.date > $1.date }.prefix(maxRecentRecords)
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

    /// Calculate aggregated trend (single line)
    private func calculateAggregatedTrend(
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        defaultCurrencyCode: String,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        var buckets: [Date: Double] = [:]

        // Find the actual data range - use earliest transaction date to avoid empty buckets
        // For allTime, don't create buckets for years before any transaction exists
        let transactionsInPeriod = transactions.filter { interval.contains($0.date) }

        // If no transactions in period, leave buckets empty (will show empty state)
        guard let earliestTransaction = transactionsInPeriod.min(by: { $0.date < $1.date }),
            let latestTransaction = transactionsInPeriod.max(by: { $0.date < $1.date })
        else {
            // No transactions - trendPoints will be empty
            trendPoints = []
            dataMetric = selectedMetric
            yDomain = 0...100
            return
        }

        // Generate bucket dates starting from earliest transaction (not interval.start)
        let bucketStart = trendGrouping.dateKey(for: earliestTransaction.date, calendar: calendar)
        let bucketEnd = max(interval.end, latestTransaction.date)
        var current = bucketStart

        while current <= bucketEnd {
            buckets[current] = 0.0
            if let next = calendar.date(
                byAdding: trendGrouping.calendarComponent, value: 1, to: current)
            {
                current = next
            } else {
                break
            }
        }

        // Fill buckets based on metric
        switch selectedMetric {
        case .balance:
            // Calculate running balance (initial balance is now a transaction, start from 0)
            var runningBalance = 0.0

            // Add transactions before interval
            for transaction in transactions where transaction.date < interval.start {
                runningBalance += transaction.amountInPreferredCurrency
            }

            // Fill buckets with cumulative balance
            let sortedDates = buckets.keys.sorted()
            let transactionsByBucket = Dictionary(
                grouping: transactions.filter { interval.contains($0.date) }
            ) { transaction in
                trendGrouping.dateKey(for: transaction.date, calendar: calendar)
            }

            for date in sortedDates {
                if let txns = transactionsByBucket[date] {
                    for txn in txns {
                        runningBalance += txn.amountInPreferredCurrency
                    }
                }
                buckets[date] = runningBalance
            }

        case .income:
            // Sum of positive amounts per bucket (exclude balance adjustments)
            for transaction in transactions
            where transaction.amountInPreferredCurrency > 0
                && transaction.balanceAdjustmentType == nil
            {
                let bucketDate = trendGrouping.dateKey(for: transaction.date, calendar: calendar)
                buckets[bucketDate, default: 0] += transaction.amountInPreferredCurrency
            }

        case .expense:
            // Sum of negative amounts (as positive) per bucket (exclude balance adjustments)
            for transaction in transactions
            where transaction.amountInPreferredCurrency < 0
                && transaction.balanceAdjustmentType == nil
            {
                let bucketDate = trendGrouping.dateKey(for: transaction.date, calendar: calendar)
                buckets[bucketDate, default: 0] += abs(transaction.amountInPreferredCurrency)
            }
        }

        // Convert to BarPoints
        // For income/expense, filter out days with no transactions (value = 0)
        let filteredBuckets: [Date: Double]
        if selectedMetric == .balance {
            // Keep all buckets for balance (running total)
            filteredBuckets = buckets
        } else {
            // For income/expense, only keep dates with actual data
            filteredBuckets = buckets.filter { $0.value != 0 }
        }

        let rawPoints = filteredBuckets.map { date, value in
            PanelViewModel.BarPoint(date: date, value: value)
        }.sorted { $0.date < $1.date }

        // Apply moving average smoothing ONLY for balance trend (continuous data)
        // Income/expense are discrete data points - smoothing would distort them
        let yearlyPeriods: [DetailPeriod] = [.thisYear, .lastYear, .allTime]
        let needsSmoothing = yearlyPeriods.contains(detailPeriod) && selectedMetric == .balance
        if needsSmoothing && rawPoints.count > 30 {
            trendPoints = TrendProcessingHelper.movingAverage(for: rawPoints, window: 14)
            dataMetric = selectedMetric
        } else {
            trendPoints = rawPoints
            dataMetric = selectedMetric
        }

        // Calculate Y domain
        if let minVal = trendPoints.map({ $0.value }).min(),
            let maxVal = trendPoints.map({ $0.value }).max()
        {
            let padding = (maxVal - minVal) * 0.1
            yDomain = (minVal - padding)...(maxVal + padding)
        } else {
            yDomain = 0...100
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
    func clearAllFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedTags.removeAll()
        selectedNatures.removeAll()
    }

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

    // MARK: - SessionState Synchronization

    /// Sync trend metric FROM SessionState
    func syncMetricFromSessionState(_ sessionState: SessionState) {
        self.selectedMetric = sessionState.selectedTrendMetric
    }

    /// Sync trend metric TO SessionState
    func syncMetricToSessionState(_ sessionState: SessionState) {
        sessionState.selectedTrendMetric = self.selectedMetric
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
