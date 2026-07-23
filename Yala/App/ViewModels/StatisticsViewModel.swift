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

    /// Dot suelto "hoy" con saldo vivo. La View lo renderiza separado de la
    /// curva (PointMark con anillo) cuando la métrica es .balance y el
    /// período cubre hoy. Nil en otros casos.
    var trendLiveAnchor: PanelViewModel.BarPoint? = nil

    /// Desglose por moneda nativa del `trendLiveAnchor`. Habilita el sheet
    /// educativo "Tu saldo hoy" desde la pill "Hoy ⓘ" del chart.
    var trendLiveAnchorBreakdown: [String: Decimal]? = nil

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

    /// Sankey flow data for the Distribution tab widget.
    /// Computed via `calculateSankeyData(...)`; recomputes only when the non-category
    /// deps change (see `sankeyInputKey`). Tap-filtering does NOT invalidate this.
    private(set) var sankeyData: SankeyData = .empty

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

    // MARK: - Sankey Input Key

    /// Snapshot of all filter/period deps that should trigger a Sankey recompute.
    /// Deliberately excludes `selectedCategories`, `selectedSubcategories`, `selectedMetric`
    /// and `selectedTransactionNatures` — tap-filtering and metric switches do NOT alter
    /// the flow structure, only the dimming overlay in the view.
    struct SankeyInputKey: Equatable {
        let interval: DateInterval
        /// Planned-occurrences interval (independent of `interval`). Differs from
        /// `interval` because planned extends to end-of-current-month, while transactions
        /// stay truncated to today. Including it here triggers a recompute when
        /// crossing month boundaries with `.thisYear` active.
        let plannedInterval: DateInterval?
        let accounts: Set<PersistentIdentifier>
        let tags: Set<PersistentIdentifier>
        let currencies: Set<CurrencyCode>
        let needs: Set<SubcategoryNeed>
        let amountCondition: AmountFilterCondition
        let searchText: String
        let isExcludeMode: Bool
    }

    var sankeyInputKey: SankeyInputKey {
        SankeyInputKey(
            interval: panelDateInterval,
            plannedInterval: detailPeriod.plannedInterval(customRange: customDateRange),
            accounts: selectedAccounts,
            tags: selectedTags,
            currencies: selectedCurrencies,
            needs: selectedNeeds,
            amountCondition: amountCondition,
            searchText: searchText,
            isExcludeMode: isExcludeMode
        )
    }

    /// True when the Sankey shows planificados truncated to end-of-current-month.
    /// Drives the hint shown below the chart.
    var shouldShowPlannedHint: Bool {
        detailPeriod.shouldShowPlannedHint(customRange: customDateRange)
    }

    // MARK: - Data Calculation

    /// Calculate trend data based on current filters and metric
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        allTags: [Tag],
        defaultCurrencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) {
        // Enforce metric lock based on filters
        enforceMetricLock()

        // Always use day grouping so chart data reaches today
        trendGrouping = .day

        // Get interval
        let interval = panelDateInterval
        currentInterval = interval

        // Build filter criteria and apply
        let criteria = buildTrendFilterCriteria(interval: interval, allTags: allTags)

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
            allTransactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            adjustment: adjustment
        )

        // Calculate trend points based on metric using unified TrendDataProcessor
        if isAggregatedView {
            let trendType = mapMetricToTrendType(selectedMetric)
            let liveBalanceOverride = LiveBalanceCalculator.liveBalanceOverride(
                for: trendType,
                interval: interval,
                accounts: eligibleAccounts,
                transactions: transactions,
                preferredCurrencyCode: defaultCurrencyCode
            )
            let result = TrendDataProcessor.processTrendData(
                transactions: filtered,
                accounts: eligibleAccounts,
                metric: trendType,
                period: detailPeriod,
                grouping: trendGrouping,
                interval: interval,
                currencyCode: defaultCurrencyCode,
                adjustment: adjustment,
                liveBalanceOverride: liveBalanceOverride
            )
            if result.points != trendPoints { trendPoints = result.points }
            if result.rawPoints != rawTrendPoints { rawTrendPoints = result.rawPoints }
            yDomain = result.yDomain
            if result.totalIncome != totalIncome { totalIncome = result.totalIncome }
            if result.totalExpense != totalExpense { totalExpense = result.totalExpense }
            if result.liveAnchor != trendLiveAnchor { trendLiveAnchor = result.liveAnchor }
            if result.liveAnchorNativeBalances != trendLiveAnchorBreakdown { trendLiveAnchorBreakdown = result.liveAnchorNativeBalances }
            dataMetric = selectedMetric
        } else {
            calculatePerAccountTrend(
                transactions: filtered,
                accounts: eligibleAccounts,
                interval: interval,
                defaultCurrencyCode: defaultCurrencyCode,
                adjustment: adjustment
            )
        }

        // Calculate recent records
        buildRecentRecords(from: filtered)
    }

    // MARK: - Sankey Data

    /// Recompute the Sankey flow data for the Distribution widget.
    ///
    /// Uses a dedicated `FilterCriteria` that **omits** `selectedCategories` /
    /// `selectedSubcategories` so the flow structure remains stable when the user
    /// taps a category or subcategory elsewhere (dimming happens in the view).
    /// Always applies the current `panelDateInterval`, independent of `selectedMetric`.
    ///
    /// The "Planificados" branch is computed via `PlannedOccurrenceBuilder` from the
    /// pending occurrences of active expense scheduled payments within `interval`.
    /// Pass `scheduledPayments: []` to disable the branch (rollback path).
    func calculateSankeyData(
        allTransactions: [TransactionItem],
        accounts: [Account],
        scheduledPayments: [ScheduledPayment],
        allTags: [Tag],
        defaultCurrencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) {
        let interval = panelDateInterval
        let criteria = buildSankeyFilterCriteria(interval: interval, allTags: allTags)
        let filtered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: criteria
        )
        // Use the dedicated planned interval (extends to end-of-current-month for
        // active periods, nil for retrospective ones). Distinct from `interval`
        // which truncates to today for transactions.
        let plannedPending: [PlannedOccurrence]
        if let plannedInterval = detailPeriod.plannedInterval(customRange: customDateRange) {
            plannedPending = PlannedOccurrenceBuilder.build(
                scheduledPayments: scheduledPayments,
                filteredTransactions: filtered,
                interval: plannedInterval,
                selectedAccounts: selectedAccounts,
                defaultCurrencyCode: defaultCurrencyCode,
                converter: CurrencyConverter.shared
            )
        } else {
            plannedPending = []
        }
        let newData = SankeyFlowCalculator.compute(
            transactions: filtered,
            interval: interval,
            maxPerColumn: 15,
            plannedPending: plannedPending,
            plannedSplit: .byKind,
            propagatePlannedToCategories: true,
            adjustment: adjustment
        )
        if newData != sankeyData { sankeyData = newData }
    }

    /// Build a FilterCriteria dedicated to the Sankey widget:
    /// - Excludes `selectedCategories`/`selectedSubcategories` (tap filters don't shrink the flow).
    /// - Always sets `dateInterval: interval` (unlike `buildTrendFilterCriteria`, which sets nil for `.balance`).
    private func buildSankeyFilterCriteria(interval: DateInterval, allTags: [Tag]) -> FilterCriteria {
        var criteria = FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: [],
            selectedSubcategories: [],
            selectedTags: selectedTags,
            selectedNeeds: selectedNeeds,
            selectedCurrencies: selectedCurrencies,
            isExcludeMode: isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: interval
        )
        criteria.populateTagUUIDs(
            from: allTags.filter { selectedTags.contains($0.persistentModelID) }
        )
        return criteria
    }

    // MARK: - Calculation Helpers

    /// Build FilterCriteria for trend calculations
    private func buildTrendFilterCriteria(interval: DateInterval, allTags: [Tag]) -> FilterCriteria {
        let isBalanceMetric = selectedMetric == .balance
        var criteria = FilterCriteria(
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
        criteria.populateTagUUIDs(
            from: allTags.filter { selectedTags.contains($0.persistentModelID) }
        )
        return criteria
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
        allTransactions: [TransactionItem],
        defaultCurrencyCode: String,
        adjustment: GroupBridgeStatsAdjustment
    ) {
        // La categoría decide el bucket; acumulación signed (paridad con
        // TrendDataProcessor/CashFlowCalculator): un reembolso reduce el bucket.
        // `adjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto) y excluye las
        // patas de préstamo derivadas (préstamo a grupos).
        let newIncome =
            filtered
            .filter { $0.balanceAdjustmentType == nil && !adjustment.isSuppressed($0)
                && TransactionClassificationLogic.isIncome($0) }
            .reduce(0) { $0 + adjustment.amountInPreferredCurrency($1) }
        if newIncome != totalIncome { totalIncome = newIncome }

        let newExpense =
            filtered
            .filter { $0.balanceAdjustmentType == nil && !adjustment.isSuppressed($0)
                && !TransactionClassificationLogic.isIncome($0) }
            .reduce(0) { $0 - adjustment.amountInPreferredCurrency($1) }
        if newExpense != totalExpense { totalExpense = newExpense }

        // KPI Saldo Actual: usa LiveBalanceCalculator (TC actual sobre saldo
        // nativo) en vez de sumar snapshots históricos — coherente con la
        // card de Balance Total del Panel.
        let newBalance = LiveBalanceCalculator.liveBalance(
            accounts: eligibleAccounts,
            transactions: allTransactions,
            preferredCurrencyCode: defaultCurrencyCode
        )
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
                $0.balanceAdjustmentType == nil && TransactionClassificationLogic.isIncome($0)
            }
        case .expense:
            metricFiltered = filtered.filter {
                $0.balanceAdjustmentType == nil && !TransactionClassificationLogic.isIncome($0)
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
        defaultCurrencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none
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
                // Clasificación por categoría; signed (paridad con TrendDataProcessor).
                // `adjustment` proyecta el Caso A a "mi parte" y excluye patas de préstamo.
                for txn in accountTransactions
                where txn.balanceAdjustmentType == nil && !adjustment.isSuppressed(txn)
                    && TransactionClassificationLogic.isIncome(txn) {
                    let bucketDate = trendGrouping.dateKey(for: txn.date, calendar: calendar)
                    buckets[bucketDate, default: 0] += adjustment.amountInPreferredCurrency(txn)
                }

            case .expense:
                // Signed: gasto (monto negativo) sube la curva; reembolso la baja.
                for txn in accountTransactions
                where txn.balanceAdjustmentType == nil && !adjustment.isSuppressed(txn)
                    && !TransactionClassificationLogic.isIncome(txn) {
                    let bucketDate = trendGrouping.dateKey(for: txn.date, calendar: calendar)
                    buckets[bucketDate, default: 0] -= adjustment.amountInPreferredCurrency(txn)
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
