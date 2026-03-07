import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class PanelViewModel {

    // MARK: - Constants

    // MARK: - Static Formatters

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    /// Exchange rate service - injected or falls back to shared singleton
    private var exchangeRateService: ExchangeRateService = .shared

    /// Currency converter - injected or falls back to shared singleton
    private var currencyConverter: CurrencyConverter = .shared

    // MARK: - Loaded Data

    private(set) var accounts: [Account] = []
    private(set) var tags: [Tag] = []
    private(set) var categories: [Category] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var transactions: [TransactionItem] = []
    private(set) var budgets: [Budget] = []
    private(set) var scheduledPayments: [ScheduledPayment] = []
    private(set) var pendingDrafts: [InboxDraft] = []

    // MARK: - State

    // UI State (not filters)
    var leadingColumnIndex: Int? = 0

    // MARK: - Filter Properties (SSOT: Read/Write from SessionState)

    var selectedAccountID: PersistentIdentifier? {
        get { SessionState.shared.selectedAccountIDs.first }
        set {
            SessionState.shared.selectedAccountIDs.removeAll()
            if let id = newValue { SessionState.shared.selectedAccountIDs.insert(id) }
        }
    }

    var selectedPeriod: DetailPeriod {
        get { SessionState.shared.selectedPeriod }
        set { SessionState.shared.selectedPeriod = newValue }
    }

    var customDateRange: DateInterval? {
        get { SessionState.shared.customDateRange }
        set { SessionState.shared.customDateRange = newValue }
    }

    // Widget Configuration Manager (delegated)
    let widgetConfig = WidgetConfigManager()

    // Computed properties for backward compatibility with views
    var widgetConfigs: [WidgetConfig] {
        get { widgetConfig.configs }
        set { widgetConfig.configs = newValue }
    }

    var layoutRows: [WidgetConfigManager.WidgetRow] {
        widgetConfig.layoutRows
    }

    // MARK: - Constants

    /// Minimum data points before applying moving average smoothing (avoids over-smoothing sparse data)
    private let movingAverageSmoothingThreshold = 30
    /// Window size for moving average calculation (14-day rolling average for yearly view)
    private let movingAverageWindowSize = 14

    // Note: Widget config persistence now handled by WidgetConfigManager

    // MARK: - Context Setup

    /// Sets the model context and optionally injects services.
    /// - Parameters:
    ///   - context: The SwiftData ModelContext
    ///   - exchangeRateService: Optional service injection (defaults to .shared)
    ///   - currencyConverter: Optional service injection (defaults to .shared)
    func setContext(
        _ context: ModelContext,
        exchangeRateService: ExchangeRateService? = nil,
        currencyConverter: CurrencyConverter? = nil
    ) {
        self.modelContext = context
        if let service = exchangeRateService {
            self.exchangeRateService = service
        }
        if let converter = currencyConverter {
            self.currencyConverter = converter
        }
        loadData()
    }

    func loadData() {
        guard let context = modelContext else { return }

        // Load accounts
        let accountsDesc = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)])
        do {
            accounts = try context.fetch(accountsDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading accounts: \(error)")
            #endif
        }

        // Load tags
        let tagsDesc = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        do {
            tags = try context.fetch(tagsDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading tags: \(error)")
            #endif
        }

        // Load categories
        let categoriesDesc = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)])
        do {
            categories = try context.fetch(categoriesDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading categories: \(error)")
            #endif
        }

        // Load subcategories
        let subcategoriesDesc = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\.name)])
        do {
            allSubcategories = try context.fetch(subcategoriesDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading subcategories: \(error)")
            #endif
        }

        // Load transactions
        let transactionsDesc = FetchDescriptor<TransactionItem>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        do {
            transactions = try context.fetch(transactionsDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading transactions: \(error)")
            #endif
        }

        // Load active budgets
        let budgetsDesc = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            budgets = try context.fetch(budgetsDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading budgets: \(error)")
            #endif
        }

        // Load scheduled payments
        let paymentsDesc = FetchDescriptor<ScheduledPayment>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        do {
            scheduledPayments = try context.fetch(paymentsDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading scheduled payments: \(error)")
            #endif
        }

        // Load pending inbox drafts
        let draftsDesc = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" }
        )
        do {
            pendingDrafts = try context.fetch(draftsDesc)
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading pending drafts: \(error)")
            #endif
        }
    }

    var topSpendingCategories: [CategorySpendingSummary] = []
    var chartTransactions: [ChartTransaction] = []

    // Previous period totals (for widget headers)
    // These are the ACTUAL totals from the previous period, not derived from current items
    var previousCategoriesTotalAmount: Double? = nil
    var previousSubcategoriesTotalAmount: Double? = nil

    // Subcategory Widget State
    var topSubcategories: [SubcategorySpendingSummary] = []
    var subcategoriesWidgetFilter: PersistentIdentifier?

    var selectedSubcategoryIDs: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedSubcategoryIDs }
        set { SessionState.shared.selectedSubcategoryIDs = newValue }
    }

    var selectedBudgetID: PersistentIdentifier? {
        SessionState.shared.selectedBudgetID
    }

    var selectedNature: SubcategoryNature? {
        get { SessionState.shared.selectedNatures.first }
        set {
            SessionState.shared.selectedNatures.removeAll()
            if let n = newValue { SessionState.shared.selectedNatures.insert(n) }
        }
    }

    var selectedTags: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedTags }
        set { SessionState.shared.selectedTags = newValue }
    }

    var selectedCurrencies: Set<CurrencyCode> {
        get { SessionState.shared.selectedCurrencies }
        set { SessionState.shared.selectedCurrencies = newValue }
    }

    var amountCondition: AmountFilterCondition {
        get { SessionState.shared.amountCondition }
        set { SessionState.shared.amountCondition = newValue }
    }

    var searchText: String {
        get { SessionState.shared.searchText }
        set { SessionState.shared.searchText = newValue }
    }

    var selectedTransactionNatures: Set<TransactionNature> {
        get { SessionState.shared.selectedTransactionNatures }
        set { SessionState.shared.selectedTransactionNatures = newValue }
    }

    var isExcludeMode: Bool {
        get { SessionState.shared.isExcludeMode }
        set { SessionState.shared.isExcludeMode = newValue }
    }

    // Nature Widget State
    var natureTrendPoints: [NatureTrendPoint] = []
    var previousNatureTotalAmount: Double? = nil
    var previousNatureAmounts: [SubcategoryNature: Double] = [:]

    // Cash Flow State
    var cashFlowSummary: CashFlowSummary?

    // Latest Records State
    var latestRecords: [TransactionItem] = []

    // Budgets Widget State
    var topBudgetSummaries: [BudgetSummary] = []
    var hasBudgetsButNoFavorites: Bool = false

    // Scheduled Payments Widget State
    var scheduledPaymentsWidgetFilter: ScheduledPaymentsWidgetFilter = .all

    // MARK: - Exchange Rate Widget State
    var exchangeRateWidgetData: ExchangeRateWidgetData?
    var exchangeRateGrouping: TrendGrouping = .day
    /// Tracks the last period for which exchange rate was calculated (to avoid redundant recalculations)
    private var lastExchangeRatePeriod: DetailPeriod?

    /// Selected currencies to compare against the preferred currency (max 2).
    var selectedComparisonCurrencies: [CurrencyCode] = []

    // MARK: - Processed Chart Data
    typealias BarPoint = Yala.BarPoint

    var processedTrendPoints: [BarPoint] = []
    /// Original unsmoothed points for hover display
    var rawTrendPoints: [BarPoint] = []
    var processedYDomain: ClosedRange<Double> = 0...100

    // Stored interval - updated in batch with chart data to stay in sync
    var currentInterval: DateInterval = DateInterval(start: Date(), end: Date())

    // Stored period - updated in batch with chart data to stay in sync
    var currentPeriod: DetailPeriod = .thisYear

    // KPI values for trends - from TrendDataProcessor for unified calculation
    var trendTotalIncome: Double = 0
    var trendTotalExpense: Double = 0
    /// Actual final balance before smoothing - use for KPI instead of last smoothed point
    var trendFinalBalance: Double = 0

    // Loading State - tracks when heavy calculations are in progress
    var isCalculating: Bool = false

    /// Derive trendType from chip (single source of truth)
    /// Note: Auto-expense logic for category/subcategory filters is handled in PanelView onChange handlers
    /// which properly check if categories are expense-only before setting the filter.
    private func enforceTrendLock(sessionState: SessionState) {
        // In expenses-only mode, always force expense
        if sessionState.isExpensesOnlyMode {
            trendType = .expense
            return
        }
        // Derive trendType from chip (single source of truth)
        if sessionState.selectedTransactionNatures.count == 1 {
            if sessionState.selectedTransactionNatures.contains(.income) {
                trendType = .income
            } else if sessionState.selectedTransactionNatures.contains(.expense) {
                trendType = .expense
            }
        } else if sessionState.selectedTransactionNatures.isEmpty {
            // No chip = balance
            trendType = .balance
        }
    }

    /// Called when user manually selects a trend type
    func setTrendTypeManually(_ type: TrendType, sessionState: SessionState) {
        trendType = type
        // Mark as manual selection (not automatic)
        sessionState.isExpenseAutomatic = false
    }

    // MARK: - SessionState Synchronization (SSOT: Filters are now computed properties)
    // These functions are kept for backward compatibility but do minimal work
    // since filter properties now read/write directly to SessionState

    /// Sync non-filter state FROM SessionState (call on appear/resume)
    func syncFromSessionState(_ sessionState: SessionState) {
        // Trend Metric - convert TrendMetric to TrendType
        self.trendType = convertMetricToTrendType(sessionState.selectedTrendMetric)

        // Apply trend lock logic
        enforceTrendLock(sessionState: sessionState)
    }

    /// Sync non-filter state TO SessionState (call after changes)
    func syncToSessionState(_ sessionState: SessionState) {
        // Trend Metric - convert TrendType to TrendMetric
        sessionState.selectedTrendMetric = convertTrendTypeToMetric(self.trendType)
    }

    /// Convert TrendMetric to TrendType
    private func convertMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    /// Convert TrendType to TrendMetric
    private func convertTrendTypeToMetric(_ type: TrendType) -> TrendMetric {
        switch type {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    // MARK: - Dependencies / Configuration

    init() {
        // WidgetConfigManager loads its own configs in init
        loadExchangeRateCurrencySelection()
    }

    // MARK: - Widget Logic (Delegated to WidgetConfigManager)

    func loadWidgetConfigs() {
        widgetConfig.load()
    }

    func saveWidgetConfigs() {
        widgetConfig.save()
    }

    func resetWidgetConfigs() {
        widgetConfig.reset()
    }

    func activeWidgets() -> [WidgetConfig] {
        return widgetConfig.activeWidgets()
    }

    func toggleWidgetVisibility(id: UUID) {
        widgetConfig.toggleVisibility(id: id)
    }

    func updateWidgetSize(id: UUID, newSize: WidgetSize) {
        widgetConfig.updateSize(id: id, newSize: newSize)
    }

    func updateScheduledPaymentsMode(id: UUID, mode: ScheduledPaymentsWidgetMode) {
        widgetConfig.updateScheduledPaymentsMode(id: id, mode: mode)
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        widgetConfig.move(from: source, to: destination)
    }

    // We keep these as simple properties or computed ones based on what the View passes
    // or we can load them if we want to move AppStorage here (requires a wrapper or passing values).
    // For simplicity in MVVM with SwiftUI, we can keep AppStorage in View and sync,
    // OR use a PersistenceController.
    // However, to strictly follow the plan: "Move state variables... Move logic".

    // Let's handle the logic that doesn't depend on View-specific property wrappers like @Query directly,
    // or accept the data in methods.

    // MARK: - Computed Logic

    /// Returns active accounts sorted by the user's custom order.
    func orderedActiveAccounts(from accounts: [Account], sortOrderNames: [String]) -> [Account] {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let indexByName = Dictionary(
            uniqueKeysWithValues: sortOrderNames.enumerated().map { ($1, $0) })

        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    /// Calculates the total balance in the default currency.
    /// Uses pre-calculated amountInPreferredCurrency for optimal performance.
    func totalBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) -> Double {
        return BalanceHelper.totalBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: defaultCurrencyCode,
            context: context
        )
    }

    /// Calculates the displayed balance (either total or selected account).
    /// Uses date-specific exchange rates for each transaction for accuracy.
    func displayedBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) -> Double {
        return BalanceHelper.displayedBalance(
            accounts: accounts,
            transactions: transactions,
            selectedAccountID: self.selectedAccountID,
            preferredCurrencyCode: defaultCurrencyCode,
            context: context
        )
    }

    /// Calculates the total expense for the currently displayed period (Year).
    func totalExpenseInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {

        // Use the calculated chartTransactions which are already filtered for Year & Eligible Accounts
        // But chartTransactions are 'ChartTransaction' type. We need the raw value.
        // Actually, 'chartTransactions' contains daily summaries.
        // We can just sum the 'expense' property of chartTransactions.

        return chartTransactions.reduce(0) { $0 + $1.expense }
    }

    /// Calculates total expenses for a specific account in the current period.
    /// Used in expenses-only mode to show "Spent" instead of balance.
    func expenseForPeriod(
        for account: Account,
        allTransactions: [TransactionItem]
    ) -> Double {
        let interval = panelDateInterval
        let total = allTransactions
            .filter { transaction in
                guard transaction.account?.persistentModelID == account.persistentModelID else { return false }
                guard interval.contains(transaction.date) else { return false }
                guard transaction.balanceAdjustmentType == nil else { return false }
                guard transaction.category?.isIncome == false else { return false }
                return true
            }
            .reduce(0.0) { $0 + abs($1.amount) }
        return total
    }

    /// Returns transactions filtered by the focused date, or all transactions if no focus.
    func transactions(filteredBy focusedDate: Date?, from allTransactions: [TransactionItem])
        -> [TransactionItem]
    {
        guard let focusedDate = focusedDate else {
            return allTransactions
        }
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, inSameDayAs: focusedDate)
        }
    }

    // MARK: - Layout Logic

    // Note: computeLayoutRows is now handled by WidgetConfigManager

    func ensureAccountsSortOrderConsistency(
        accounts: [Account],
        currentOrderRaw: String
    ) -> String {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let activeNames = activeAccounts.map { $0.name }

        if activeNames.isEmpty {
            return ""
        }

        let currentOrder = currentOrderRaw.split(separator: "|").map(String.init)
        var newOrder = currentOrder.filter { activeNames.contains($0) }

        for name in activeNames where !newOrder.contains(name) {
            newOrder.append(name)
        }

        return newOrder.joined(separator: "|")
    }

    private func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode,
        context: ModelContext
    ) -> Decimal {
        if source == target {
            return amount
        }

        // Use CurrencyConverter with API rates for consistency with chart calculations
        return currencyConverter.convertWithLatestRate(
            amount,
            from: source.rawValue,
            to: target.rawValue,
            context: context
        )
    }

    // MARK: - Trend Logic (Year Only - Tight Range)

    // MARK: - Trend Logic (Dynamic Period)

    /// Intervalo de fecha calculado basado en el periodo seleccionado:
    var panelDateInterval: DateInterval {
        // Use the centralized date interval logic from DetailPeriod models
        return selectedPeriod.dateInterval(customRange: customDateRange)
    }

    // MARK: - Trend & Balance Status Logic

    var selectedCategoryID: PersistentIdentifier? {
        get { SessionState.shared.selectedCategoryIDs.first }
        set {
            SessionState.shared.selectedCategoryIDs.removeAll()
            if let id = newValue { SessionState.shared.selectedCategoryIDs.insert(id) }
        }
    }

    // Trend State

    // Restored Properties
    var balanceStatus: BalanceStatus = .unknown
    var historicalThreshold: Double = 0
    var trendGrouping: TrendGrouping = .day
    var cashFlowGrouping: TrendGrouping = .day  // Explicit grouping for Cash Flow widget
    var natureGrouping: TrendGrouping = .day  // Explicit grouping for Nature widget
    var trendType: TrendType = .balance
    /// Tracks the trendType for which current data was calculated.
    /// Used to prevent rendering stale data with wrong colors during metric transitions.
    var dataTrendType: TrendType = .balance
    var focusedDate: Date? = nil  // Global Focus State

    /// Calculates trend data and status based on the current period, selected account, and selected category.
    /// Refactored for smooth UX - all calculations done first, then state updated in one batch.
    /// Optimized with lazy evaluation - only calculates visible widgets.
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext,
        sessionState: SessionState
    ) {
        // 1. Build shared calculation context
        let calcContext = buildCalculationContext(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            modelContext: context
        )

        // 2. Calculate ALL widget data (unconditionally to ensure data is ready when widgets are added)

        // Trend chart - use unified TrendDataProcessor
        let newProcessedData:
            (points: [BarPoint], rawPoints: [BarPoint], yDomain: ClosedRange<Double>)
        var newTrendTotalIncome = trendTotalIncome
        var newTrendTotalExpense = trendTotalExpense
        var newTrendFinalBalance = trendFinalBalance
        // For balance, use all transactions (no date filter) to calculate running balance
        let transactionsForTrend = trendType == .balance
            ? calcContext.balanceTransactions
            : calcContext.filteredTransactions
        let result = TrendDataProcessor.processTrendData(
            transactions: transactionsForTrend,
            accounts: calcContext.eligibleAccounts,
            metric: trendType,
            period: calcContext.period,
            grouping: calcContext.trendGrouping,
            interval: calcContext.effectiveInterval,
            currencyCode: calcContext.defaultCurrencyCode,
            context: calcContext.modelContext
        )
        newProcessedData = (result.points, result.rawPoints, result.yDomain)
        newTrendTotalIncome = result.totalIncome
        newTrendTotalExpense = result.totalExpense
        newTrendFinalBalance = result.finalBalance

        // Categories - used by both topSpending and categoriesPie widgets
        let categoriesResult = calculateCategoriesWidget(context: calcContext)
        let newTopSpendingCategories = categoriesResult.categories
        let newPreviousCategoriesTotal = categoriesResult.previousTotal

        // Subcategories - used by both topSubcategories and subcategoriesPie widgets
        let subcategoriesResult = calculateSubcategoriesWidget(context: calcContext)
        let newTopSubcategories = subcategoriesResult.subcategories
        let newPreviousSubcategoriesTotal = subcategoriesResult.previousTotal

        // Cash Flow
        let newCashFlowSummary = calculateCashFlowWidget(context: calcContext)

        // Latest Records
        let newLatestRecords = calculateLatestRecordsWidget(context: calcContext)

        // Nature Trend
        let natureResult = calculateNatureWidget(context: calcContext)
        let newNatureTrendPoints = natureResult.points
        let newPreviousNatureTotal = natureResult.previousTotal
        let newPreviousNatureAmounts = natureResult.previousAmounts

        // 3. BATCH STATE UPDATE - Single render cycle
        enforceTrendLock(sessionState: sessionState)

        self.trendGrouping = calcContext.trendGrouping
        self.cashFlowGrouping = calcContext.cashFlowGrouping
        self.natureGrouping = calcContext.natureGrouping
        self.topSpendingCategories = newTopSpendingCategories
        self.previousCategoriesTotalAmount = newPreviousCategoriesTotal
        self.topSubcategories = newTopSubcategories
        self.previousSubcategoriesTotalAmount = newPreviousSubcategoriesTotal
        self.cashFlowSummary = newCashFlowSummary
        self.latestRecords = newLatestRecords
        self.natureTrendPoints = newNatureTrendPoints
        self.previousNatureTotalAmount = newPreviousNatureTotal
        self.previousNatureAmounts = newPreviousNatureAmounts
        self.processedTrendPoints = newProcessedData.points
        self.rawTrendPoints = newProcessedData.rawPoints
        self.processedYDomain = newProcessedData.yDomain
        self.currentInterval = calcContext.effectiveInterval
        self.currentPeriod = self.selectedPeriod
        self.trendTotalIncome = newTrendTotalIncome
        self.trendTotalExpense = newTrendTotalExpense
        self.trendFinalBalance = newTrendFinalBalance
        // Track the metric for which data was calculated (prevents stale data rendering)
        self.dataTrendType = self.trendType

        // 4. Calculate Exchange Rate Widget Data (only if period changed, has error, or needs refresh)
        let periodChanged = lastExchangeRatePeriod != selectedPeriod
        let hasError = exchangeRateWidgetData?.hasError == true
        let needsRefresh = SessionState.shared.needsExchangeRateWidgetRefresh
        let needsExchangeRateData = exchangeRateWidgetData == nil || periodChanged || hasError || needsRefresh
        if needsExchangeRateData {
            lastExchangeRatePeriod = selectedPeriod
            if needsRefresh {
                SessionState.shared.needsExchangeRateWidgetRefresh = false
                // Reload currencies from secondaryCurrencies when settings change
                reloadCurrenciesFromSettings()
            }
            calculateExchangeRateData(
                preferredCurrencyCode: defaultCurrencyCode,
                context: context
            )
        }
    }

    // MARK: - Filter Criteria Builder

    /// Builds FilterCriteria from SessionState for use with FilterService.
    /// Accounts NOT included — pre-filtered by eligibleAccountIDs (handles excludeFromStatistics).
    func buildFilterCriteria(
        dateInterval: DateInterval? = nil,
        includeCategories: Bool = true
    ) -> FilterCriteria {
        var criteria = FilterCriteria()
        criteria.selectedTags = selectedTags
        criteria.selectedCurrencies = selectedCurrencies
        criteria.isExcludeMode = isExcludeMode
        criteria.amountCondition = amountCondition
        criteria.searchText = searchText
        criteria.dateInterval = dateInterval

        if includeCategories {
            criteria.selectedCategories = SessionState.shared.selectedCategoryIDs
            criteria.selectedSubcategories = selectedSubcategoryIDs
            criteria.selectedNatures = SessionState.shared.selectedNatures
        }

        return criteria
    }

    // MARK: - Calculation Context Builder

    /// Builds the shared context for all widget calculations
    private func buildCalculationContext(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        modelContext: ModelContext
    ) -> PanelCalculationContext {
        let calendar = Calendar.current

        // Determine groupings based on period
        // NOTE: TrendWidget (line chart) always uses day for smooth interpolation
        // But CashFlow and Nature (bar charts) need coarser grouping for long periods
        let newTrendGrouping = selectedPeriod.chartGrouping
        let (newCashFlowGrouping, newNatureGrouping): (TrendGrouping, TrendGrouping) = {
            switch selectedPeriod {
            case .thisWeek, .last7Days:
                return (.day, .day)  // Daily bars for week
            case .thisMonth, .lastMonth, .last30Days:
                return (.day, .day)  // Daily bars for month (smart axis handles labels)
            case .thisYear, .lastYear, .allTime, .custom:
                return (.month, .month)  // Monthly bars for year/all-time/custom
            }
        }()

        // Determine eligible accounts (archived accounts still count for calculations)
        let eligibleAccounts = accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            guard let selectedID = selectedAccountID else { return true }
            if isExcludeMode {
                return account.persistentModelID != selectedID
            } else {
                return account.persistentModelID == selectedID
            }
        }
        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        // Filter transactions by account + date + global filters
        let fullCriteria = buildFilterCriteria(dateInterval: panelDateInterval)
        let filtered = transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }

            // Focused Date Filter (PanelVM-specific: chart scrubbing)
            if let focus = focusedDate {
                if !calendar.isDate(transaction.date, inSameDayAs: focus) { return false }
            }

            return FilterService.matchesCriteria(transaction, criteria: fullCriteria)
        }

        // Transactions filtered by all criteria EXCEPT date and categories (for previous period comparison)
        // Excludes adjustments like expenseFiltered does
        let comparisonCriteria = buildFilterCriteria(includeCategories: false)
        let transactionsWithoutDateFilter = transactions.filter { transaction in
            guard transaction.balanceAdjustmentType == nil else { return false }
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            return FilterService.matchesCriteria(transaction, criteria: comparisonCriteria)
        }

        // Balance transactions: same filters as filtered BUT without date filter
        // INCLUDES adjustments (needed for running balance calculation)
        let balanceCriteria = buildFilterCriteria()  // dateInterval = nil → no date filter
        let balanceTransactions = transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            return FilterService.matchesCriteria(transaction, criteria: balanceCriteria)
        }

        // Expense-filtered transactions (excludes adjustments and initial balances)
        let expenseFiltered = filtered.filter { $0.balanceAdjustmentType == nil }

        // Calculate effective interval (optimized for All Time)
        let effectiveInterval: DateInterval
        if selectedPeriod == .allTime {
            if let firstTxDate = filtered.map(\.date).min() {
                let start =
                    calendar.date(
                        from: calendar.dateComponents([.year, .month], from: firstTxDate))
                    ?? firstTxDate
                effectiveInterval = DateInterval(start: start, end: Date())
            } else {
                let startOfYear = calendar.date(
                    from: calendar.dateComponents([.year], from: Date())) ?? Date()
                effectiveInterval = DateInterval(start: startOfYear, end: Date())
            }
        } else {
            effectiveInterval = self.panelDateInterval
        }

        // Context transactions for other widgets (respects all filters including category/subcategory)
        let contextTransactions = expenseFiltered.filter { txn in
            effectiveInterval.contains(txn.date)
        }

        let finalContextTransactions: [TransactionItem]
        if let focus = focusedDate {
            finalContextTransactions = contextTransactions.filter {
                Calendar.current.isDate($0.date, inSameDayAs: focus)
            }
        } else {
            finalContextTransactions = contextTransactions
        }

        // Pie chart transactions: filtered WITHOUT category/subcategory (for dimming behavior)
        // These transactions are used by pie widgets to show ALL categories with visual dimming
        let pieContextTransactions = transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            if !effectiveInterval.contains(transaction.date) { return false }
            guard transaction.balanceAdjustmentType == nil else { return false }

            // Focused Date Filter
            if let focus = focusedDate {
                if !calendar.isDate(transaction.date, inSameDayAs: focus) { return false }
            }

            // Category/Subcategory filters excluded for pie dimming behavior,
            // EXCEPT when filtering comes from a budget selection (must show only budget categories)
            // or when in exclude mode (must remove excluded items from pie data)
            if selectedBudgetID != nil && !selectedSubcategoryIDs.isEmpty {
                guard let subID = transaction.subcategory?.persistentModelID,
                    selectedSubcategoryIDs.contains(subID)
                else { return false }
            } else if isExcludeMode {
                // Exclude selected categories from pie data
                if let selectedCatID = selectedCategoryID,
                   transaction.category?.persistentModelID == selectedCatID {
                    return false
                }
                // Exclude selected subcategories from pie data
                if !selectedSubcategoryIDs.isEmpty,
                   let subID = transaction.subcategory?.persistentModelID,
                   selectedSubcategoryIDs.contains(subID) {
                    return false
                }
            }

            // Nature Filter (still applies to pie charts)
            if let nature = selectedNature {
                if let sub = transaction.subcategory {
                    if sub.nature != nature { return false }
                } else {
                    if nature != .unclassified { return false }
                }
            }

            // Tag Filter
            if !selectedTags.isEmpty {
                let transactionTagIDs = Set((transaction.tags ?? []).map { $0.persistentModelID })
                if transactionTagIDs.isDisjoint(with: selectedTags) { return false }
            }

            // Currency Filter
            if !selectedCurrencies.isEmpty {
                guard let txCurrency = CurrencyCode(rawValue: transaction.currencyCode) else {
                    return false
                }
                if !selectedCurrencies.contains(txCurrency) { return false }
            }

            // Amount Filter
            if amountCondition.isActive {
                let amountDecimal = Decimal(transaction.amount)
                if !amountCondition.matches(amountDecimal) { return false }
            }

            // Search/Note Filter
            if !searchText.isEmpty {
                let noteMatches = transaction.note?.localizedCaseInsensitiveContains(searchText) ?? false
                if !noteMatches { return false }
            }

            return true
        }

        // Pre-compute nature-filtered transactions for pie widgets
        // Uses pieContextTransactions (excludes category/subcategory filters) for dimming behavior
        let natureFiltered: [TransactionItem]
        if let nature = selectedNature {
            natureFiltered = pieContextTransactions.filter { txn in
                if let sub = txn.subcategory {
                    return sub.nature == nature
                } else {
                    return nature == .unclassified
                }
            }
        } else {
            natureFiltered = pieContextTransactions
        }

        // Pre-compute fully-filtered transactions (nature + subcategory)
        let fullyFiltered: [TransactionItem]
        if !selectedSubcategoryIDs.isEmpty {
            fullyFiltered = natureFiltered.filter { tx in
                guard let subID = tx.subcategory?.persistentModelID else { return false }
                return selectedSubcategoryIDs.contains(subID)
            }
        } else {
            fullyFiltered = natureFiltered
        }

        // Transactions for nature widget - has cat/subcat filters but NO nature filter
        // This allows the nature widget to show ALL natures with visual dimming
        let natureWidgetTxns = expenseFiltered.filter { txn in
            effectiveInterval.contains(txn.date)
        }

        return PanelCalculationContext(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            modelContext: modelContext,
            eligibleAccounts: eligibleAccounts,
            eligibleAccountIDs: eligibleAccountIDs,
            filteredTransactions: filtered,
            expenseFilteredTransactions: expenseFiltered,
            contextTransactions: finalContextTransactions,
            natureFilteredTransactions: natureFiltered,
            fullyFilteredTransactions: fullyFiltered,
            natureWidgetTransactions: natureWidgetTxns,
            transactionsWithoutDateFilter: transactionsWithoutDateFilter,
            balanceTransactions: balanceTransactions,
            period: selectedPeriod,
            effectiveInterval: effectiveInterval,
            trendGrouping: newTrendGrouping,
            cashFlowGrouping: newCashFlowGrouping,
            natureGrouping: newNatureGrouping,
            focusedDate: focusedDate,
            selectedCategoryID: selectedCategoryID,
            selectedSubcategoryIDs: selectedSubcategoryIDs,
            selectedNature: selectedNature,
            subcategoriesWidgetFilter: subcategoriesWidgetFilter,
            selectedTransactionNatures: selectedTransactionNatures
        )
    }

    // MARK: - Widget Calculations

    /// Calculate trend chart data
    private func calculateTrendWidget(context: PanelCalculationContext) -> [ChartTransaction] {
        return BalanceTrendCalculator.calculateTrend(
            transactions: context.filteredTransactions,
            grouping: context.trendGrouping,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode,
            context: context.modelContext
        )
    }

    /// Process trend points for chart rendering
    private func processTrendPoints(
        chartTransactions: [ChartTransaction],
        context: PanelCalculationContext
    ) -> (points: [BarPoint], yDomain: ClosedRange<Double>) {
        let rawTrendPoints = chartTransactions.map { tx in
            let val: Double
            switch self.trendType {
            case .balance: val = tx.balance
            case .income: val = tx.income
            case .expense: val = tx.expense
            }
            return BarPoint(date: tx.date, value: val)
        }

        // For income/expense, filter out days with zero values to create a connected line
        // This matches StatisticsViewModel behavior where zero-days are excluded
        let filteredPoints: [BarPoint]
        if trendType == TrendType.balance {
            // Keep all points for balance (running total)
            filteredPoints = rawTrendPoints
        } else {
            // For income/expense, only keep dates with actual data
            filteredPoints = rawTrendPoints.filter { $0.value != 0 }
        }

        let processedPoints: [BarPoint]
        // Only smooth balance metric - income/expense are discrete data points
        let shouldSmooth =
            (context.period == .thisYear || context.period == .lastYear
                || context.period == .allTime)
            && filteredPoints.count > movingAverageSmoothingThreshold
            && trendType == TrendType.balance

        if shouldSmooth {
            processedPoints = TrendProcessingHelper.movingAverage(
                for: filteredPoints, window: movingAverageWindowSize)
        } else {
            processedPoints = filteredPoints
        }

        let yDomain = TrendProcessingHelper.calculateYDomain(
            for: processedPoints,
            isExpense: trendType == .expense
        )

        return (processedPoints, yDomain)
    }

    /// Calculate top spending categories with period comparison
    /// Uses natureFilteredTransactions (not fullyFiltered) so that subcategory selection
    /// only dims categories visually, rather than filtering out other categories' data
    /// Returns: (categories, previousPeriodTotal)
    private func calculateCategoriesWidget(context: PanelCalculationContext)
        -> (categories: [CategorySpendingSummary], previousTotal: Double?)
    {
        // Calculate current period data using nature-filtered transactions
        // This ensures category pie shows ALL categories (selection = visual dim, not data filter)
        // Pass transactionNatures filter - empty means show expenses only (default)
        let naturesFilter: Set<TransactionNature>? = context.selectedTransactionNatures.isEmpty
            ? nil
            : context.selectedTransactionNatures

        var currentData = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: context.natureFilteredTransactions,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode,
            transactionNatures: naturesFilter,
            context: context.modelContext
        )

        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard context.period != .allTime else {
            return (currentData, nil)
        }

        // Calculate previous period data for comparison
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,  // Default to -1 period comparison
            customRange: nil
        )

        // Filter transactions for previous period (using date-independent filter)
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }

        let previousData = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: previousTransactions,
            interval: previousInterval,
            currencyCode: context.defaultCurrencyCode,
            transactionNatures: naturesFilter,
            context: context.modelContext
        )

        // Calculate the ACTUAL previous period total (sum of ALL categories from previous period)
        let previousTotal = previousData.reduce(0) { $0 + $1.amount }

        // Create lookup dictionary for previous amounts by category ID
        let previousAmounts = Dictionary(
            uniqueKeysWithValues: previousData.map { ($0.category.persistentModelID, $0.amount) }
        )

        // Assign previousAmount to current data
        for index in currentData.indices {
            let categoryID = currentData[index].category.persistentModelID
            currentData[index].previousAmount = previousAmounts[categoryID]
        }

        return (currentData, previousTotal > 0 ? previousTotal : nil)
    }

    /// Calculate top subcategories with period comparison
    /// Uses natureFilteredTransactions (not fullyFiltered) so that subcategory selection
    /// only dims subcategories visually, rather than filtering out other subcategories' data
    /// Returns: (subcategories, previousPeriodTotal)
    private func calculateSubcategoriesWidget(context: PanelCalculationContext)
        -> (subcategories: [SubcategorySpendingSummary], previousTotal: Double?)
    {
        // Use pre-filtered transactions from context (nature already applied)
        let effectiveCategoryFilter =
            context.selectedCategoryID ?? context.subcategoriesWidgetFilter

        // Use nature-filtered transactions (category filter applies separately)
        // This ensures subcategory pie shows ALL subcategories (selection = visual dim, not data filter)
        // Pass transactionNatures filter - empty means show expenses only (default)
        let naturesFilter: Set<TransactionNature>? = context.selectedTransactionNatures.isEmpty
            ? nil
            : context.selectedTransactionNatures

        var currentData = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: context.natureFilteredTransactions,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter,
            transactionNatures: naturesFilter,
            context: context.modelContext
        )

        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard context.period != .allTime else {
            return (currentData, nil)
        }

        // Calculate previous period data for comparison
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,  // Default to -1 period comparison
            customRange: nil
        )

        // Filter transactions for previous period (using date-independent filter)
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }

        let previousData = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: previousTransactions,
            interval: previousInterval,
            currencyCode: context.defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter,
            transactionNatures: naturesFilter,
            context: context.modelContext
        )

        // Calculate the ACTUAL previous period total (sum of ALL subcategories from previous period)
        let previousTotal = previousData.reduce(0) { $0 + $1.amount }

        // Create lookup dictionary for previous amounts by subcategory ID (more reliable than name)
        let previousAmounts = Dictionary(
            uniqueKeysWithValues: previousData.compactMap { summary -> (PersistentIdentifier, Double)? in
                guard let id = summary.persistentID else { return nil }
                return (id, summary.amount)
            }
        )

        // Assign previousAmount to current data
        for index in currentData.indices {
            if let id = currentData[index].persistentID {
                currentData[index].previousAmount = previousAmounts[id]
            }
        }

        return (currentData, previousTotal > 0 ? previousTotal : nil)
    }

    /// Calculate cash flow summary (excludes adjustments/initial balances)
    private func calculateCashFlowWidget(context: PanelCalculationContext) -> CashFlowSummary? {
        return CashFlowCalculator.calculateCashFlow(
            transactions: context.expenseFilteredTransactions,
            interval: context.effectiveInterval,
            grouping: context.cashFlowGrouping,
            currencyCode: context.defaultCurrencyCode,
            context: context.modelContext
        )
    }

    /// Calculate latest records (excludes adjustments/initial balances)
    /// In expenses-only mode, also excludes income transactions.
    private func calculateLatestRecordsWidget(context: PanelCalculationContext) -> [TransactionItem]
    {
        var filtered = context.expenseFilteredTransactions
            .filter { context.effectiveInterval.contains($0.date) }

        // In expenses-only mode, exclude income transactions
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.category?.isIncome != true }
        }

        return Array(
            filtered
                .sorted {
                    return $0.createdAt > $1.createdAt
                }
                .prefix(5)
        )
    }

    /// Calculate nature trend points with period comparison
    /// Uses natureWidgetTransactions (has cat/subcat filters but NO nature filter)
    /// This allows the nature widget to show ALL natures with visual dimming
    /// Returns: (points, previousTotal, previousAmountsByNature)
    private func calculateNatureWidget(context: PanelCalculationContext)
        -> (points: [NatureTrendPoint], previousTotal: Double?, previousAmounts: [SubcategoryNature: Double])
    {
        let preferredCurrency = CurrencyCode(rawValue: context.defaultCurrencyCode) ?? .pen

        let currentPoints = NatureTrendHelper.calculateTrend(
            transactions: context.natureWidgetTransactions,
            grouping: context.natureGrouping,
            interval: context.effectiveInterval,
            preferredCurrency: preferredCurrency,
            context: context.modelContext
        )

        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard context.period != .allTime else {
            return (currentPoints, nil, [:])
        }

        // Calculate previous period data for comparison
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,
            customRange: nil
        )

        // Filter transactions for previous period
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }

        let previousPoints = NatureTrendHelper.calculateTrend(
            transactions: previousTransactions,
            grouping: context.natureGrouping,
            interval: previousInterval,
            preferredCurrency: preferredCurrency,
            context: context.modelContext
        )

        // Calculate totals by nature for previous period
        var prevNatureAmounts: [SubcategoryNature: Double] = [:]
        var prevNatureTotal: Double = 0
        for point in previousPoints {
            prevNatureAmounts[.essential, default: 0] += point.essential
            prevNatureAmounts[.priority, default: 0] += point.priority
            prevNatureAmounts[.optional, default: 0] += point.optional
            prevNatureAmounts[.unclassified, default: 0] += point.unclassified
            prevNatureTotal += point.total
        }

        return (currentPoints, prevNatureTotal > 0 ? prevNatureTotal : nil, prevNatureAmounts)
    }

    // State for Filter Logic
    var isCategorySelectionImplicit: Bool = false

    // Helper to toggle Category explicitly (from Widget)
    func toggleCategoryFilter(_ id: PersistentIdentifier) {
        if selectedCategoryID == id {
            selectedCategoryID = nil
            isCategorySelectionImplicit = false
        } else {
            selectedCategoryID = id
            isCategorySelectionImplicit = false
        }
    }

    // Helper to toggle subcategory (single-select behavior for widget interaction)
    // Changed from String (name) to PersistentIdentifier to handle duplicate names across categories
    func toggleSubcategoryFilter(
        _ subcategoryID: PersistentIdentifier,
        transactions: [TransactionItem],
        accounts: [Account],
        defaultCurrencyCode: String,
        context: ModelContext,
        sessionState: SessionState
    ) {
        if selectedSubcategoryIDs.contains(subcategoryID) && selectedSubcategoryIDs.count == 1 {
            // Deselect Subcategory (only if it's the only one selected)
            selectedSubcategoryIDs.removeAll()

            if isCategorySelectionImplicit {
                // If category was auto-selected (Scenario 1), clear it too -> "All"
                selectedCategoryID = nil
                isCategorySelectionImplicit = false
            }
            // If category was explicitly selected (Scenario 2), KEEP it -> "Category X"
        } else {
            // Select New Subcategory (single-select: clear others first)
            selectedSubcategoryIDs = [subcategoryID]

            // Find parent category for this subcategory by persistentID
            if let summary = topSubcategories.first(where: { $0.persistentID == subcategoryID }),
                let cat = summary.category
            {

                if selectedCategoryID == cat.persistentModelID {
                    // We are already in this category.
                    // Keep implicit state as is (if explicit, it stays explicit. matches "Scenario 2")
                } else {
                    // Switching to a NEW category context (Scenario 3 / 1)
                    self.selectedCategoryID = cat.persistentModelID
                    self.isCategorySelectionImplicit = true
                }
            }
        }

        // Recalculate immediately to ensure UI is in sync
        calculateTrendData(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            context: context,
            sessionState: sessionState
        )
    }

    func toggleNatureFilter(_ nature: SubcategoryNature) {
        if selectedNature == nature {
            selectedNature = nil
        } else {
            selectedNature = nature
        }
    }

    // MARK: - Exchange Rate Widget Logic

    /// Loads currency selection from secondaryCurrencies (onboarding/settings).
    /// This is the single source of truth for which currencies to display.
    private func loadExchangeRateCurrencySelection() {
        if let secondaryCurrenciesRaw = UserDefaults.standard.string(forKey: "secondaryCurrencies"),
           !secondaryCurrenciesRaw.isEmpty {
            let currencies = secondaryCurrenciesRaw
                .split(separator: ",")
                .compactMap { CurrencyCode(rawValue: String($0)) }

            selectedComparisonCurrencies = Array(currencies.prefix(2))
        } else {
            selectedComparisonCurrencies = []
        }
    }

    /// Reloads currencies from secondaryCurrencies when settings change
    private func reloadCurrenciesFromSettings() {
        loadExchangeRateCurrencySelection()
    }


    /// Calculates exchange rate data for the widget.
    func calculateExchangeRateData(
        preferredCurrencyCode: String,
        context: ModelContext
    ) {
        let preferredCurrency = CurrencyCode(rawValue: preferredCurrencyCode) ?? .pen

        // Only calculate rates for user-selected secondary currencies (2-3 max)
        // instead of all 47 currencies — huge performance win
        let targetCurrencies = selectedComparisonCurrencies.filter { $0 != preferredCurrency }

        // Determine grouping based on period
        switch selectedPeriod {
        case .thisWeek, .last7Days:
            exchangeRateGrouping = .day
        case .thisMonth, .lastMonth, .last30Days:
            exchangeRateGrouping = .week
        default:
            exchangeRateGrouping = .month
        }

        // For "All Time", use the actual stored data range instead of 10 years
        // This prevents iterating through years of dates with no data
        let interval: DateInterval
        if selectedPeriod == .allTime {
            if let storedRange = exchangeRateService.getStoredDateRange(context: context) {
                interval = storedRange
            } else {
                interval = panelDateInterval
            }
        } else {
            interval = panelDateInterval
        }

        // Get the latest rate for current display
        let latestRate = exchangeRateService.getLatestRate(context: context)

        guard let latestRate = latestRate else {
            // No data available
            exchangeRateWidgetData = ExchangeRateWidgetData(
                preferredCurrency: preferredCurrencyCode,
                errorMessage: L10n.ExchangeRate.loadError
            )
            return
        }

        // Calculate current rates for selected comparison currencies only
        let currentRates = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: preferredCurrencyCode,
            targetCurrencies: targetCurrencies.map { $0.rawValue },
            exchangeRate: latestRate
        )

        // Use API timestamp if available, otherwise fall back to parsing dateKey
        let currentRatesDate: Date =
            latestRate.timestamp
            ?? {
                Self.dateKeyFormatter.date(from: latestRate.dateKey) ?? Date()
            }()

        // Build chart points for selected comparison currencies only
        let chartPoints = ExchangeRateWidgetHelper.buildChartPoints(
            interval: interval,
            grouping: exchangeRateGrouping,
            preferredCurrency: preferredCurrencyCode,
            targetCurrencies: targetCurrencies.map { $0.rawValue },
            context: context
        )

        exchangeRateWidgetData = ExchangeRateWidgetData(
            preferredCurrency: preferredCurrencyCode,
            currentRates: currentRates,
            currentRatesDate: currentRatesDate,
            chartPoints: chartPoints
        )
    }

    /// Updates the selected comparison currencies.
    func updateComparisonCurrencies(_ currencies: [CurrencyCode]) {
        // Limit to max 2
        selectedComparisonCurrencies = Array(currencies.prefix(2))
    }

    // MARK: - Budgets Widget Calculation

    /// Calculate budget summaries for the widget (favorite budgets first, then active)
    func calculateBudgetsWidget(
        budgets: [Budget],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) {
        // Check if there are budgets but none are favorites
        let hasBudgets = !budgets.isEmpty
        let favoriteBudgets = budgets.filter { $0.isFavorite }
        hasBudgetsButNoFavorites = hasBudgets && favoriteBudgets.isEmpty

        // Get budgets to display: favorites first (sorted by order), then fill with active non-favorites
        let sortedFavorites = favoriteBudgets.sorted { $0.favoriteOrder < $1.favoriteOrder }

        // Calculate summaries for favorite budgets
        let summaries = sortedFavorites.compactMap { budget -> BudgetSummary? in
            calculateBudgetSummary(
                budget: budget,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCode
            )
        }

        topBudgetSummaries = summaries
    }

    /// Calculate summary for a single budget
    private func calculateBudgetSummary(
        budget: Budget,
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> BudgetSummary? {
        // Get budget period date interval
        let interval = getBudgetDateInterval(budget: budget)

        // Filter transactions by date
        var filtered = transactions.filter { interval.contains($0.date) }

        // Apply budget filters

        // Account filter
        if let accounts = budget.accounts, !accounts.isEmpty {
            let accountIDs = Set(accounts.map { $0.persistentModelID })
            filtered = filtered.filter { transaction in
                if let accountID = transaction.account?.persistentModelID {
                    return accountIDs.contains(accountID)
                }
                return false
            }
        }

        // Subcategory filter
        if let subcategories = budget.subcategories, !subcategories.isEmpty {
            let subIDs = Set(subcategories.map { $0.persistentModelID })
            filtered = filtered.filter { transaction in
                if let subID = transaction.subcategory?.persistentModelID {
                    return subIDs.contains(subID)
                }
                return false
            }
        }

        // Tag filter
        if let budgetTags = budget.tags, !budgetTags.isEmpty {
            let tagIDs = Set(budgetTags.map { $0.persistentModelID })
            filtered = filtered.filter { transaction in
                let transactionTagIDs = Set((transaction.tags ?? []).map { $0.persistentModelID })
                return !transactionTagIDs.isDisjoint(with: tagIDs)
            }
        }

        // Nature filter
        if let naturesString = budget.natures, !naturesString.isEmpty {
            let natures = naturesString.split(separator: ",")
                .compactMap { SubcategoryNature(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }

            filtered = filtered.filter { transaction in
                natures.contains(transaction.effectiveNature)
            }
        }

        // Only count expenses (not income)
        filtered = filtered.filter { $0.category?.isIncome == false }

        // Sum amounts in budget's currency
        let spent = filtered.reduce(0.0) { sum, transaction in
            let amount: Double
            if transaction.currencyCode == budget.currencyCode {
                // Same currency as budget — use original amount
                amount = transaction.amount
            } else if transaction.preferredCurrencyCode == budget.currencyCode {
                // Preferred currency matches budget — use pre-converted amount
                amount = transaction.amountInPreferredCurrency
            } else if let context = modelContext,
                      let fromCode = CurrencyCode(rawValue: transaction.currencyCode),
                      let toCode = CurrencyCode(rawValue: budget.currencyCode) {
                // Different currency — convert using latest rates
                let converted = convertToPreferredCurrency(
                    amount: Decimal(transaction.amount),
                    from: fromCode,
                    to: toCode,
                    context: context
                )
                amount = NSDecimalNumber(decimal: converted).doubleValue
            } else {
                amount = transaction.amount
            }
            return sum + abs(amount)
        }

        let percentage = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100.0 : 0.0
        let daysRemaining = getBudgetDaysRemaining(budget: budget, interval: interval)
        let status = getBudgetStatus(budget: budget, spending: spent)
        let (icon, color) = getBudgetDisplayProperties(budget: budget)

        return BudgetSummary(
            budget: budget,
            spent: spent,
            percentage: percentage,
            daysRemaining: daysRemaining,
            status: status,
            icon: icon,
            color: color
        )
    }

    /// Get date interval for a budget period
    private func getBudgetDateInterval(budget: Budget) -> DateInterval {
        let calendar = Calendar.current

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            let start = calendar.startOfMonth(for: Date())
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }

        switch periodType {
        case .weekly:
            let weekStart = calendar.startOfWeek(for: Date())
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)

        case .monthly:
            let monthStart = calendar.startOfMonth(for: Date())
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)

        case .yearly:
            let year = calendar.component(.year, from: Date())
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)

        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                let monthStart = calendar.startOfMonth(for: Date())
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                return DateInterval(start: monthStart, end: monthEnd)
            }
            return DateInterval(start: start, end: end)
        }
    }

    /// Calculate days remaining in budget period
    private func getBudgetDaysRemaining(budget: Budget, interval: DateInterval) -> Int {
        let calendar = Calendar.current
        let today = Date()

        if today > interval.end {
            return -1  // Period has ended
        }

        guard interval.contains(today) else { return 0 }

        let components = calendar.dateComponents([.day], from: today, to: interval.end)
        return max(0, components.day ?? 0)
    }

    /// Determine budget status
    private func getBudgetStatus(budget: Budget, spending: Double) -> BudgetStatus {
        guard budget.isActive else { return .inactive }
        return spending >= budget.limitAmount ? .exceeded : .active
    }

    /// Get display properties for budget
    private func getBudgetDisplayProperties(budget: Budget) -> (icon: String, color: String) {
        let subcategories = budget.subcategories ?? []
        guard !subcategories.isEmpty else {
            return ("chart.pie.fill", AppConstants.defaultColorHex)
        }

        if subcategories.count == 1, let subcategory = subcategories.first {
            let icon = subcategory.iconName ?? subcategory.safeCategory.iconName ?? "tag.fill"
            let color = subcategory.colorHex ?? subcategory.safeCategory.colorHex
            return (icon, color)
        }

        let uniqueCategories = Set(subcategories.map { $0.safeCategory.persistentModelID })

        if uniqueCategories.count == 1, let firstSubcategory = subcategories.first {
            let category = firstSubcategory.safeCategory
            let icon = category.iconName ?? "tag.fill"
            let color = category.colorHex
            return (icon, color)
        } else {
            return ("chart.pie.fill", AppConstants.defaultColorHex)
        }
    }
}

// MARK: - Calendar Extension for Budget Calculations

