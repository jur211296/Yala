import Foundation
import SwiftData
import SwiftUI

@Observable
final class PanelViewModel {

    // MARK: - State

    var selectedAccountID: PersistentIdentifier?
    var leadingColumnIndex: Int? = 0

    // Period Filter State
    var selectedPeriod: TrendPeriod = .year

    // Widget State
    var widgetConfigs: [WidgetConfig] = [] {
        didSet {
            // Recalculate layout rows whenever configs change
            self.layoutRows = computeLayoutRows(widgets: activeWidgets())
        }
    }

    // Layout State (Output for View)
    var layoutRows: [WidgetRow] = []

    // MARK: - Layout Structures

    enum WidgetRowType {
        case fullWidth(WidgetConfig)
        case halfWidthPair(left: WidgetConfig, right: WidgetConfig?)
    }

    struct WidgetRow: Identifiable {
        let id: UUID
        let type: WidgetRowType
    }

    // MARK: - Constants

    /// Minimum data points before applying moving average smoothing (avoids over-smoothing sparse data)
    private let movingAverageSmoothingThreshold = 30
    /// Window size for moving average calculation (14-day rolling average for yearly view)
    private let movingAverageWindowSize = 14

    // Persistence Key
    private let widgetConfigsKey = "panel_widget_configs_v1"

    var topSpendingCategories: [CategorySpendingSummary] = []
    var chartTransactions: [ChartTransaction] = []

    // Subcategory Widget State
    var topSubcategories: [SubcategorySpendingSummary] = []
    var selectedSubcategoryID: String?
    var subcategoriesWidgetFilter: PersistentIdentifier?

    // Nature filter state
    var selectedNature: SubcategoryNature?

    // Nature Widget State
    var natureTrendPoints: [NatureTrendPoint] = []

    // Cash Flow State
    var cashFlowSummary: CashFlowSummary?

    // Latest Records State
    var latestRecords: [TransactionItem] = []

    // MARK: - Exchange Rate Widget State
    var exchangeRateWidgetData: ExchangeRateWidgetData?
    var exchangeRateGrouping: TrendGrouping = .day
    private let exchangeRateCurrencySelectionKey = "panel_exchange_rate_currencies_v1"

    /// Selected currencies to compare against the preferred currency (max 2).
    var selectedComparisonCurrencies: [CurrencyCode] = [] {
        didSet {
            saveExchangeRateCurrencySelection()
        }
    }

    enum TrendPeriod: String, CaseIterable, Identifiable {
        case week = "Esta semana"
        case month = "Este mes"
        case year = "Este año"

        var id: String { rawValue }
    }

    // MARK: - Processed Chart Data
    typealias BarPoint = Neto.BarPoint

    var processedTrendPoints: [BarPoint] = []
    var processedYDomain: ClosedRange<Double> = 0...100

    // Stored interval - updated in batch with chart data to stay in sync
    var currentInterval: DateInterval = DateInterval(start: Date(), end: Date())

    // Stored period - updated in batch with chart data to stay in sync
    var currentPeriod: TrendPeriod = .year

    // Loading State - tracks when heavy calculations are in progress
    var isCalculating: Bool = false

    // Trend Locking Logic
    var isTrendLockedToExpense: Bool {
        selectedCategoryID != nil || selectedSubcategoryID != nil || selectedNature != nil
    }

    private func enforceTrendLock() {
        if isTrendLockedToExpense {
            trendType = .expense
        }
    }

    // MARK: - Dependencies / Configuration

    init() {
        loadWidgetConfigs()
        loadExchangeRateCurrencySelection()
    }

    // MARK: - Widget Logic

    func loadWidgetConfigs() {
        if let data = UserDefaults.standard.data(forKey: widgetConfigsKey),
            var decoded = try? JSONDecoder().decode([WidgetConfig].self, from: data)
        {
            // Enforce Locked Properties (Healing Logic) - REMOVED for Trend Unlock
            // for index in decoded.indices {
            //     if decoded[index].isLocked {
            //         decoded[index].isVisible = true
            //         decoded[index].size = .large
            //     }
            // }

            // Migration: Add missing new widgets
            let defaults = WidgetConfig.defaultConfigs()
            let existingTypes = Set(decoded.map { $0.type })

            for config in defaults {
                if !existingTypes.contains(config.type) {
                    decoded.append(config)
                }
            }

            self.widgetConfigs = decoded
        } else {
            // Default
            self.widgetConfigs = WidgetConfig.defaultConfigs()
        }
        // Force layout update on initial load
        self.layoutRows = computeLayoutRows(widgets: activeWidgets())
    }

    func saveWidgetConfigs() {
        if let encoded = try? JSONEncoder().encode(widgetConfigs) {
            UserDefaults.standard.set(encoded, forKey: widgetConfigsKey)
        }
    }

    func resetWidgetConfigs() {
        self.widgetConfigs = WidgetConfig.defaultConfigs()
        saveWidgetConfigs()
    }

    func activeWidgets() -> [WidgetConfig] {
        return widgetConfigs.filter { $0.isVisible }
    }

    func toggleWidgetVisibility(id: UUID) {
        if let index = widgetConfigs.firstIndex(where: { $0.id == id }) {
            // Trend is always visible
            if widgetConfigs[index].isLocked { return }

            widgetConfigs[index].isVisible.toggle()
            saveWidgetConfigs()
        }
    }

    func updateWidgetSize(id: UUID, newSize: WidgetSize) {
        if let index = widgetConfigs.firstIndex(where: { $0.id == id }) {
            // Trend size is fixed
            if widgetConfigs[index].isLocked { return }

            widgetConfigs[index].size = newSize
            saveWidgetConfigs()
        }
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        // Prevent moving the locked first item
        // Detailed reorder logic might be needed if user tries to move item 0
        // But the View should disable reordering for item 0.
        // Swift reorder:
        var newConfigs = widgetConfigs
        newConfigs.move(fromOffsets: source, toOffset: destination)

        self.widgetConfigs = newConfigs
        saveWidgetConfigs()
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
    /// Calculates the total balance in the default currency.
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
    /// Calculates the displayed balance (either total or selected account).
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

    /// Computes the layout rows based on widget sizes.
    /// Rules:
    /// - Large: Full Width
    /// - Medium: Full Width
    func computeLayoutRows(widgets: [WidgetConfig]) -> [WidgetRow] {
        var rows: [WidgetRow] = []

        for config in widgets {
            // All widgets (Medium & Large) are Full Width
            rows.append(WidgetRow(id: UUID(), type: .fullWidth(config)))
        }
        return rows
    }

    // MARK: - Helpers

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
        return CurrencyConverter.shared.convertWithLatestRate(
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
        let calendar = Calendar.current
        let now = Date()

        let interval: DateInterval
        switch selectedPeriod {
        case .week:
            interval =
                calendar.dateInterval(of: .weekOfYear, for: now)
                ?? DateInterval(start: now, end: now)
        case .month:
            interval =
                calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        case .year:
            interval =
                calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: now, end: now)
        }

        // 2. Find min and max for tight range if needed, OR return full interval
        // User asked for "Esta semana", "Este mes". Usually implies showing the whole X-axis for that period.
        // Let's return the full calendar interval to ensure the X-axis covers the whole week/month/year.
        return interval
    }

    // MARK: - Trend & Balance Status Logic

    var selectedCategoryID: PersistentIdentifier?

    // Trend State

    // Restored Properties
    var balanceStatus: BalanceStatus = .unknown
    var historicalThreshold: Double = 0
    var trendGrouping: TrendGrouping = .day
    var cashFlowGrouping: TrendGrouping = .day  // Explicit grouping for Cash Flow widget
    var natureGrouping: TrendGrouping = .day  // Explicit grouping for Nature widget
    var trendType: TrendType = .balance
    var focusedDate: Date? = nil  // Global Focus State

    /// Calculates trend data and status based on the current period, selected account, and selected category.
    /// Refactored for smooth UX - all calculations done first, then state updated in one batch.
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) {
        let calendar = Calendar.current

        // Determine Trend Grouping based on Period (local)
        let newTrendGrouping: TrendGrouping
        switch selectedPeriod {
        case .week:
            newTrendGrouping = .day
        case .month:
            newTrendGrouping = .day
        case .year:
            newTrendGrouping = .month
        }

        // Cash Flow Specific Grouping Logic (local)
        let newCashFlowGrouping: TrendGrouping
        let newNatureGrouping: TrendGrouping
        switch selectedPeriod {
        case .month:
            newCashFlowGrouping = .week
            newNatureGrouping = .week
        default:
            newCashFlowGrouping = newTrendGrouping
            newNatureGrouping = newTrendGrouping
        }

        // 2. Determine Eligible Accounts
        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
                && (selectedAccountID == nil || account.persistentModelID == selectedAccountID)
        }
        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        // 3. Filter Transactions by Account + Date + Global Filters
        let filtered = transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            if !panelDateInterval.contains(transaction.date) { return false }

            // Focused Date Filter
            if let focus = focusedDate {
                if !calendar.isDate(transaction.date, inSameDayAs: focus) { return false }
            }

            // Category Filter
            if let catID = selectedCategoryID {
                if transaction.category?.persistentModelID != catID { return false }
            }

            // Subcategory Filter
            if let subName = selectedSubcategoryID {
                if let sub = transaction.subcategory {
                    if sub.name != subName { return false }
                } else {
                    if subName == "Sin subcategoría" {
                        if transaction.subcategory != nil { return false }
                    } else {
                        return false
                    }
                }
            }

            // Nature Filter
            if let nature = selectedNature {
                if let sub = transaction.subcategory {
                    if sub.nature != nature { return false }
                } else {
                    if nature == .unclassified {
                        if transaction.subcategory != nil
                            && transaction.subcategory!.nature != .unclassified
                        {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }

            return true
        }

        // 4. Calculate Chart Data (local)
        let newChartTransactions = BalanceTrendCalculator.calculateTrend(
            transactions: filtered,
            grouping: newTrendGrouping,
            interval: self.panelDateInterval,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 5. Context Transactions for Category/Subcategory widgets
        let contextTransactions = transactions.filter { txn in
            guard let acct = txn.account, eligibleAccountIDs.contains(acct.persistentModelID)
            else { return false }
            return panelDateInterval.contains(txn.date)
        }

        let finalContextTransactions: [TransactionItem]
        if let focus = focusedDate {
            finalContextTransactions = contextTransactions.filter {
                Calendar.current.isDate($0.date, inSameDayAs: focus)
            }
        } else {
            finalContextTransactions = contextTransactions
        }

        // Apply Nature Filter to context transactions
        let natureFilteredContextTransactions: [TransactionItem]
        if let nature = selectedNature {
            natureFilteredContextTransactions = finalContextTransactions.filter { txn in
                if let sub = txn.subcategory {
                    return sub.nature == nature
                } else {
                    return nature == .unclassified
                }
            }
        } else {
            natureFilteredContextTransactions = finalContextTransactions
        }

        // Apply Subcategory Filter for Category Calculation
        let finalCategoryTransactions: [TransactionItem]
        if let subID = selectedSubcategoryID {
            finalCategoryTransactions = natureFilteredContextTransactions.filter {
                $0.subcategory?.name == subID
            }
        } else {
            finalCategoryTransactions = natureFilteredContextTransactions
        }

        // 6. Calculate Top Spending Categories (local)
        let newTopSpendingCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: finalCategoryTransactions,
            interval: panelDateInterval,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 7. Calculate Top Subcategories (local)
        let effectiveCategoryFilter = selectedCategoryID ?? subcategoriesWidgetFilter
        let newTopSubcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: natureFilteredContextTransactions,
            interval: panelDateInterval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter,
            context: context
        )

        // 8. Calculate Cash Flow (local)
        let newCashFlowSummary = CashFlowCalculator.calculateCashFlow(
            transactions: filtered,
            interval: panelDateInterval,
            grouping: newCashFlowGrouping,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 9. Latest Records (local)
        let newLatestRecords = Array(filtered.sorted { $0.date > $1.date }.prefix(5))

        // 10. Calculate Nature Trend (local)
        let newNatureTrendPoints = NatureTrendHelper.calculateTrend(
            transactions: filtered,
            grouping: newNatureGrouping,
            interval: self.panelDateInterval,
            preferredCurrency: CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen,
            context: context
        )

        // 11. Pre-calculate processed trend data (BEFORE batch update to avoid double render)
        let rawTrendPoints = newChartTransactions.map { tx in
            let val = (trendType == .balance) ? tx.balance : tx.expense
            return BarPoint(date: tx.date, value: val)
        }

        let newProcessedTrendPoints: [BarPoint]
        if selectedPeriod == .year && rawTrendPoints.count > movingAverageSmoothingThreshold {
            newProcessedTrendPoints = TrendProcessingHelper.movingAverage(
                for: rawTrendPoints, window: movingAverageWindowSize)
        } else {
            newProcessedTrendPoints = rawTrendPoints
        }

        let newProcessedYDomain = TrendProcessingHelper.calculateYDomain(
            for: newProcessedTrendPoints,
            isExpense: trendType == .expense
        )

        // ============================================
        // BATCH STATE UPDATE - Single render cycle
        // ============================================

        // Enforce trend lock FIRST (before setting other state) to prevent cascade
        enforceTrendLock()

        self.trendGrouping = newTrendGrouping
        self.cashFlowGrouping = newCashFlowGrouping
        self.natureGrouping = newNatureGrouping
        self.chartTransactions = newChartTransactions
        self.topSpendingCategories = newTopSpendingCategories
        self.topSubcategories = newTopSubcategories
        self.cashFlowSummary = newCashFlowSummary
        self.latestRecords = newLatestRecords
        self.natureTrendPoints = newNatureTrendPoints
        self.processedTrendPoints = newProcessedTrendPoints
        self.processedYDomain = newProcessedYDomain
        self.currentInterval = self.panelDateInterval  // Sync interval with data
        self.currentPeriod = self.selectedPeriod  // Sync period with data

        // 12. Calculate Exchange Rate Widget Data (already handles its own state)
        calculateExchangeRateData(
            preferredCurrencyCode: defaultCurrencyCode,
            context: context
        )
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

    // Helper to toggle subcategory
    func toggleSubcategoryFilter(
        _ id: String,
        transactions: [TransactionItem],
        accounts: [Account],
        defaultCurrencyCode: String,
        context: ModelContext
    ) {
        if selectedSubcategoryID == id {
            // Deselect Subcategory
            selectedSubcategoryID = nil

            if isCategorySelectionImplicit {
                // If category was auto-selected (Scenario 1), clear it too -> "All"
                selectedCategoryID = nil
                isCategorySelectionImplicit = false
            }
            // If category was explicitly selected (Scenario 2), KEEP it -> "Category X"
        } else {
            // Select New Subcategory
            selectedSubcategoryID = id

            // Find parent category for this subcategory
            if let summary = topSubcategories.first(where: { $0.id == id }),
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
            context: context
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

    /// Loads persisted currency selection or sets defaults based on preferred currency.
    private func loadExchangeRateCurrencySelection() {
        if let data = UserDefaults.standard.data(forKey: exchangeRateCurrencySelectionKey),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        {
            // Convert string codes back to CurrencyCode enum (case-insensitive)
            var currencies = decoded.compactMap { code -> CurrencyCode? in
                CurrencyCode(rawValue: code.uppercased())
            }

            // Remove duplicates while preserving order
            var seen = Set<CurrencyCode>()
            currencies = currencies.filter { seen.insert($0).inserted }

            // Limit to max 2
            selectedComparisonCurrencies = Array(currencies.prefix(2))
        }
        // Note: Defaults are set when calculating data if selection is empty
    }

    /// Saves the current currency selection.
    private func saveExchangeRateCurrencySelection() {
        let codes = selectedComparisonCurrencies.map { $0.rawValue }
        if let encoded = try? JSONEncoder().encode(codes) {
            UserDefaults.standard.set(encoded, forKey: exchangeRateCurrencySelectionKey)
        }
    }

    /// Sets default comparison currencies based on preferred currency.
    func setDefaultComparisonCurrencies(preferredCurrency: CurrencyCode) {
        guard selectedComparisonCurrencies.isEmpty else { return }

        switch preferredCurrency {
        case .pen:
            selectedComparisonCurrencies = [.usd, .eur]
        case .usd:
            selectedComparisonCurrencies = [.pen, .eur]
        case .eur:
            selectedComparisonCurrencies = [.usd, .pen]
        }
    }

    /// Calculates exchange rate data for the widget.
    func calculateExchangeRateData(
        preferredCurrencyCode: String,
        context: ModelContext
    ) {
        let preferredCurrency = CurrencyCode(rawValue: preferredCurrencyCode) ?? .pen

        // Ensure defaults are set
        setDefaultComparisonCurrencies(preferredCurrency: preferredCurrency)

        // Calculate rates for ALL possible comparison currencies (so selection changes are instant)
        let allCurrencies: [CurrencyCode] = [.pen, .usd, .eur]
        let allComparisonCurrencies = allCurrencies.filter { $0 != preferredCurrency }

        // Determine grouping based on period
        switch selectedPeriod {
        case .week:
            exchangeRateGrouping = .day
        case .month:
            exchangeRateGrouping = .week
        case .year:
            exchangeRateGrouping = .month
        }

        let interval = panelDateInterval

        // Get the latest rate for current display
        let latestRate = ExchangeRateService.shared.getLatestRate(context: context)

        guard let latestRate = latestRate else {
            // No data available
            exchangeRateWidgetData = ExchangeRateWidgetData(
                preferredCurrency: preferredCurrencyCode,
                errorMessage:
                    "No se pudo cargar el tipo de cambio para este periodo. Inténtalo más tarde."
            )
            return
        }

        // Calculate current rates for ALL comparison currencies
        let currentRates = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: preferredCurrencyCode,
            targetCurrencies: allComparisonCurrencies.map { $0.rawValue },
            exchangeRate: latestRate
        )

        // Use API timestamp if available, otherwise fall back to parsing dateKey
        let currentRatesDate: Date =
            latestRate.timestamp
            ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(identifier: "UTC")
                return dateFormatter.date(from: latestRate.dateKey) ?? Date()
            }()

        // Build chart points for ALL comparison currencies
        let chartPoints = ExchangeRateWidgetHelper.buildChartPoints(
            interval: interval,
            grouping: exchangeRateGrouping,
            preferredCurrency: preferredCurrencyCode,
            targetCurrencies: allComparisonCurrencies.map { $0.rawValue },
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
}
