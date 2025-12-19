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

    // Persistence Key
    private let widgetConfigsKey = "panel_widget_configs_v1"
    // Use a direct UserDefaults access helper or just load on init.
    // Since this is a ViewModel, loading on init is fine.

    var topSpendingCategories: [CategorySpendingSummary] = []
    var chartTransactions: [ChartTransaction] = []

    // Subcategory Widget State
    var topSubcategories: [SubcategorySpendingSummary] = []
    var selectedSubcategoryID: String? {
        didSet {
            enforceTrendLock()
        }
    }
    var subcategoriesWidgetFilter: PersistentIdentifier?

    // Nature filter state
    var selectedNature: SubcategoryNature? {
        didSet {
            enforceTrendLock()
        }
    }

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
    struct BarPoint: Identifiable, Equatable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    var processedTrendPoints: [BarPoint] = []
    var processedYDomain: ClosedRange<Double> = 0...100

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
    /// Uses date-specific exchange rates for each transaction for accuracy.
    func totalBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        var totalDecimal: Decimal = 0

        // 1. Sum initial balances (converted at today's rate since they don't have a date)
        for account in eligibleAccounts {
            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let initialConverted = CurrencyConverter.shared.convertWithLatestRate(
                Decimal(account.initialBalance),
                from: sourceCurrency.rawValue,
                to: preferredCurrency.rawValue,
                context: context
            )
            totalDecimal += initialConverted
        }

        // 2. Sum each transaction converted at its specific date's rate
        for tx in transactions {
            guard let account = tx.account,
                eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                ?? preferredCurrency

            let converted = CurrencyConverter.shared.convert(
                Decimal(tx.amount),
                from: sourceCurrency.rawValue,
                to: preferredCurrency.rawValue,
                on: tx.date,
                context: context
            )

            totalDecimal += converted
        }

        return (totalDecimal as NSDecimalNumber).doubleValue
    }

    /// Calculates the displayed balance (either total or selected account).
    /// Uses date-specific exchange rates for each transaction for accuracy.
    func displayedBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        if let selectedID = selectedAccountID,
            let account = accounts.first(where: { $0.persistentModelID == selectedID }),
            !account.isArchived,
            !account.excludeFromStatistics
        {
            // Use date-specific rates for single account balance
            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            // 1. Initial balance at today's rate (no specific date)
            var totalDecimal = CurrencyConverter.shared.convertWithLatestRate(
                Decimal(account.initialBalance),
                from: sourceCurrency.rawValue,
                to: preferredCurrency.rawValue,
                context: context
            )

            // 2. Each transaction at its date-specific rate
            let accountTransactions = transactions.filter {
                $0.account?.persistentModelID == selectedID
            }
            for tx in accountTransactions {
                let txSourceCurrency =
                    CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                    ?? preferredCurrency

                let converted = CurrencyConverter.shared.convert(
                    Decimal(tx.amount),
                    from: txSourceCurrency.rawValue,
                    to: preferredCurrency.rawValue,
                    on: tx.date,
                    context: context
                )
                totalDecimal += converted
            }

            return (totalDecimal as NSDecimalNumber).doubleValue
        }

        return totalBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
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

    var selectedCategoryID: PersistentIdentifier? {
        didSet {
            enforceTrendLock()
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
    var focusedDate: Date? = nil  // Global Focus State

    /// Calculates trend data and status based on the current period, selected account, and selected category.
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext
    ) {

        let calendar = Calendar.current
        let now = Date()

        // 1. Determine Period Interval
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

        // Update Trend Grouping based on Period
        switch selectedPeriod {
        case .week:
            trendGrouping = .day
        case .month:
            trendGrouping = .day  // Detailed daily view for Month
        case .year:
            trendGrouping = .month  // Monthly view for Year
        }

        // Cash Flow Specific Grouping Logic
        // User Requirement: "This Month" -> Weeks.
        switch selectedPeriod {
        case .month:
            cashFlowGrouping = .week
            natureGrouping = .week
        default:
            cashFlowGrouping = trendGrouping
            natureGrouping = trendGrouping
        }

        // 2. Determine Eligible Accounts
        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
                && (selectedAccountID == nil || account.persistentModelID == selectedAccountID)
        }
        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        // 3. Filter Transactions (Base Filter: Account + Period)
        // This set is used for Top Spending calculation (unaffected by category filter)
        let baseFilteredTransactions = transactions.filter { tx in
            // Filter by Account Eligibility
            guard let account = tx.account, eligibleAccountIDs.contains(account.persistentModelID)
            else {
                return false
            }
            // Filter by Period
            return interval.contains(tx.date)
        }

        // 4. Calculate Top Spending (Base Context)
        self.topSpendingCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: baseFilteredTransactions,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 0. Filter transactions by Account + Date + Global Filters
        let filtered = transactions.filter { transaction in
            // Basic Account Filter
            guard let account = transaction.account else { return false }

            // Check if account is active (not hidden/archived) - this logic usually handled by `activeAccounts` pass
            // but we double check persistent ID match against eligible accounts (Which respects selectedAccountID)
            if !eligibleAccountIDs.contains(account.persistentModelID) {
                return false
            }

            // Period Filter
            if !panelDateInterval.contains(transaction.date) {
                return false
            }

            // Focused Date Filter (from Chart Tap)
            // If focusedDate is set, restrict to that specific day/period unit
            if let focus = focusedDate {
                // Determine granularity based on period
                let calendar = Calendar.current
                if !calendar.isDate(transaction.date, inSameDayAs: focus) {
                    return false
                }
            }

            // Category Filter (Triggered by Top Spending Widget)
            if let catID = selectedCategoryID {
                if transaction.category?.persistentModelID != catID {
                    return false
                }
            }

            // Subcategory Filter (Triggered by Top Subcategories Widget)
            if let subName = selectedSubcategoryID {
                // Check if transaction matches this subcategory name
                // Since ID is name-based for subcategories in summary:
                if let sub = transaction.subcategory {
                    if sub.name != subName { return false }
                } else {
                    // Check for "Sin subcategoría"
                    if subName == "Sin subcategoría" {
                        if transaction.subcategory != nil { return false }
                    } else {
                        return false
                    }
                }
            }

            // Nature Filter
            if let nature = selectedNature {
                // If transaction subcategory matches nature
                if let sub = transaction.subcategory {
                    if sub.nature != nature { return false }
                } else {
                    // Unclassified logic: No subcategory OR subcategory with unclassified nature (though enum default handles it?)
                    // If filter is .unclassified, accept tx with NO subcategory or nil nature (if that existed).
                    if nature == .unclassified {
                        // Accept if no subcategory
                        if transaction.subcategory != nil
                            && transaction.subcategory!.nature != .unclassified
                        {
                            return false
                        }
                    } else {
                        // Filter is specific nature (e.g. Essential), but tx has no subcategory -> reject
                        return false
                    }
                }
            }

            return true
        }

        // 1. Chart Data
        self.chartTransactions = BalanceTrendCalculator.calculateTrend(
            transactions: filtered,
            grouping: self.trendGrouping,
            interval: self.panelDateInterval,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 2. Top Spending Categories
        // We reuse the filtered context logic from before (Time + Account Only)
        // because Top Spending usually GIVES context, doesn't just reflect it (unless drilled down).

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

        // Apply Nature Filter to context transactions (for category/subcategory widgets)
        let natureFilteredContextTransactions: [TransactionItem]
        if let nature = selectedNature {
            natureFilteredContextTransactions = finalContextTransactions.filter { txn in
                if let sub = txn.subcategory {
                    return sub.nature == nature
                } else {
                    // Transaction has no subcategory -> treat as unclassified
                    return nature == .unclassified
                }
            }
        } else {
            natureFilteredContextTransactions = finalContextTransactions
        }

        // Apply Subcategory Filter locally for Category Calculation
        // If a subcategory is selected, the Category widget should only show the parent category
        // and the value should be filtered to that subcategory.
        let finalCategoryTransactions: [TransactionItem]
        if let subID = selectedSubcategoryID {
            finalCategoryTransactions = natureFilteredContextTransactions.filter {
                $0.subcategory?.name == subID
            }
        } else {
            finalCategoryTransactions = natureFilteredContextTransactions
        }

        self.topSpendingCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: finalCategoryTransactions,
            interval: panelDateInterval,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 3. Top Subcategories
        // Always prioritize the active 'selectedCategoryID' (whether Explicit or Implicit)
        // This ensures that if we are in "Shopping" context, picking a subcategory keeps us in "Shopping" list.
        // Fallback to 'subcategoriesWidgetFilter' only if there's no global context (e.g. browsing "All" -> Local Filter)
        let effectiveCategoryFilter = selectedCategoryID ?? subcategoriesWidgetFilter

        self.topSubcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: natureFilteredContextTransactions,  // Base set (Time + Account + Nature)
            interval: panelDateInterval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter,  // Pass the effective filter
            context: context
        )

        // 4. Cash Flow
        // Use global context (filtered by Category/Subcategory if present)
        // Similar to chartTransactions context but including Category/Subcategory filtering?
        // User requirements: "Respect global filters (Account, Period, Category, Subcategory)".
        // So we use `finalCategoryTransactions` which has Subcategory filter applied IF active,
        // OR `finalContextTransactions` filtered by `selectedCategoryID`.

        // Actually, `finalContextTransactions` filters: Account, Period, Focus.
        // `finalCategoryTransactions` further filters by Subcategory IF selected.
        // What about `selectedCategoryID`?
        // `finalContextTransactions` does NOT seem to filter by category ID in lines 519-532.
        // Wait, line 482 filters `filtered` by category/subcategory.
        // `chartTransactions` uses `filtered` (line 508). `filtered` includes ALL filters.
        // `topSpendingCategories` uses `finalCategoryTransactions`.

        // `chartsTransactions` (Balance Trend) respects ALL filters.
        // The prompt says Cash Flow respects "Category / subcategory ... if active".
        // so we should use `filtered` (the one with ALL filters applied).
        // Let's verify `filtered` variable availability. It is defined at line 456.
        // Yes, `filtered` is available in scope.

        self.cashFlowSummary = CashFlowCalculator.calculateCashFlow(
            transactions: filtered,
            interval: panelDateInterval,
            grouping: cashFlowGrouping,
            currencyCode: defaultCurrencyCode,
            context: context
        )

        // 6. Latest Records (sorted by date, most recent first)
        self.latestRecords = Array(
            filtered.sorted { $0.date > $1.date }.prefix(5)
        )

        // 6. Latest Records (sorted by date, most recent first)
        self.latestRecords = Array(
            filtered.sorted { $0.date > $1.date }.prefix(5)
        )

        // 7. Calculate Nature Trend (using 'filtered' might be too restrictive if we want to show distribution even when filtered?)
        // Requirement: "Panel filters... Nature (when filtered)".
        // If Nature is filtered, the chart should show only that nature?
        // Usually "Expenses by Nature" widget shows distribution.
        // If I filter by "Essential", the widget should probably show only Essential bars? Or allow unfiltering?
        // Behavior defined: "Si ya hay naturaleza filtrada = N... se elimina el filtro".
        // Use 'finalContextTransactions' (Time + Account + Focus) to calculate distribution always,
        // UNLESS we explicitly want to show only the selected one.
        // Standard Panel practice: Widget reflects global context.
        // BUT if I filter by "Food", I might want to see Nature OF Food.
        // So use 'filtered' context (which includes Category/Subcategory).
        // Does 'filtered' include 'selectedNature'? Yes.
        // If I filter by "Essential", 'filtered' only has Essential. So Chart is single color. This is consistent.
        // But for the Widget Content calculation, we usually want to show the breakdown of the CURRENT context.
        // If Nature IS filtered, we might want to show all natures to allow switching?
        // The spec says: "Chevron... respects ALL filters".
        // The Widget itself: "Tap... applies filter".
        // If I am filtered by Essential, and I see only Essential bar, I can tap it to unfilter.
        // If I want to see others, I unfilter first.
        // So strict filtering is fine.

        self.natureTrendPoints = calculateNatureTrend(
            transactions: filtered,  // Includes Category, Subcategory, Date, Account filters. What about Nature filter?
            // If selectedNature is set, 'filtered' only contains that nature.
            // If we want the widget to still show other natures (disabled/dimmed or just 0?) or just the one?
            // "Si solo hay 1 o 2 naturalezas presentes, las restantes se muestran en cero".
            // So relying on filtered data is correct behavior.
            grouping: self.natureGrouping,
            interval: self.panelDateInterval
        )

        // 8. Calculate Exchange Rate Widget Data
        calculateExchangeRateData(
            preferredCurrencyCode: defaultCurrencyCode,
            context: context
        )

        // 9. Process Trend Data for View (Smoothing & Domain)
        updateProcessedTrendData()
    }

    private func updateProcessedTrendData() {
        // Convert ChartTransaction to BarPoint
        let rawPoints = chartTransactions.map { tx in
            let val = (trendType == .balance) ? tx.balance : tx.expense
            return BarPoint(date: tx.date, value: val)
        }

        // Apply Smoothing if needed
        let smoothedPoints: [BarPoint]
        if selectedPeriod == .year && rawPoints.count > 30 {
            smoothedPoints = movingAverage(for: rawPoints, window: 14)
        } else {
            smoothedPoints = rawPoints
        }

        self.processedTrendPoints = smoothedPoints

        // Calculate Domain
        let values = smoothedPoints.map(\.value)
        let maxVal = values.max() ?? 0
        let minVal = values.min() ?? 0

        let topBuffer = max(abs(maxVal) * 0.05, 100)

        if trendType == .expense {
            self.processedYDomain = 0...(maxVal + topBuffer)
        } else {
            let bottomBuffer = (minVal < 0) ? abs(minVal) * 0.05 : 0
            self.processedYDomain = (minVal - bottomBuffer)...(maxVal + topBuffer)
        }
    }

    private func movingAverage(for data: [BarPoint], window: Int) -> [BarPoint] {
        guard !data.isEmpty else { return [] }
        var result: [BarPoint] = []
        let sorted = data.sorted { $0.date < $1.date }

        for i in 0..<sorted.count {
            let start = max(0, i - window + 1)
            let chunk = sorted[start...i]
            let sum = chunk.map(\.value).reduce(0, +)
            let avg = sum / Double(chunk.count)
            result.append(BarPoint(date: sorted[i].date, value: avg))
        }
        return result
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

    private func calculateNatureTrend(
        transactions: [TransactionItem],
        grouping: TrendGrouping,
        interval: DateInterval
    ) -> [NatureTrendPoint] {
        // Group transactions by Date bucket
        var grouped: [Date: [TransactionItem]] = [:]
        let calendar = Calendar.current

        for tx in transactions {
            // Only consider Expenses for Nature
            if tx.amount >= 0 { continue }  // Income is positive, Expense is negative (usually).
            // Wait, Neto convention: Expense is usually negative.
            // But let's check TrendChartView usage. 'expense' is usually positive magnitude or negative?
            // ChartTransaction.expense is Double.
            // Let's check 'BalanceTrendCalculator'.
            // Usually in Neto: Income +, Expense -.
            // We want positive values for the bar chart height.

            let dateKey: Date
            switch grouping {
            case .day:
                dateKey = calendar.startOfDay(for: tx.date)
            case .week:
                // Start of week
                let components = calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear], from: tx.date)
                dateKey = calendar.date(from: components) ?? tx.date
            case .month:
                // Start of month
                let components = calendar.dateComponents([.year, .month], from: tx.date)
                dateKey = calendar.date(from: components) ?? tx.date
            }

            grouped[dateKey, default: []].append(tx)
        }

        // Create points filling the interval? Or just present ones?
        // Widget usually cleaner if it shows continuous headers or just present?
        // Trend chart shows continuous. Let's try to match existing keys or fill gaps if necessary.
        // For simplicity first pass: just present keys.

        var points: [NatureTrendPoint] = []
        for (date, txs) in grouped {
            var essential: Double = 0
            var priority: Double = 0
            var optional: Double = 0
            var unclassified: Double = 0

            for tx in txs {
                let amount = abs(tx.amount)
                let nature = tx.subcategory?.nature ?? .unclassified

                switch nature {
                case .essential: essential += amount
                case .priority: priority += amount
                case .optional: optional += amount
                case .unclassified: unclassified += amount
                }
            }

            points.append(
                NatureTrendPoint(
                    date: date,
                    essential: essential,
                    priority: priority,
                    optional: optional,
                    unclassified: unclassified
                ))
        }

        return points.sorted { $0.date < $1.date }
    }

    private func initialBalanceForTrend(
        accounts: [Account],
        transactions: [TransactionItem],
        before date: Date,
        preferredCurrency: CurrencyCode,
        categoryFilter: PersistentIdentifier? = nil,
        context: ModelContext
    ) -> Double {
        // Calculate balance of all eligible accounts up to 'date'
        // This is expensive if done naively.
        // Optimization: Use AccountBalanceCalculator logic but filtered by date.

        // For now, let's reuse the batch calculator but we need it to support a cutoff date.
        // Since AccountBalanceCalculator might not support cutoff, we do a manual sum here.
        // Or better: Current Balance - Transactions AFTER date.

        // Let's go with: Sum of initial balances + Sum of all transactions BEFORE date.

        var total: Decimal = 0

        for account in accounts {
            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            // Initial Balance
            let initial = convertToPreferredCurrency(
                amount: Decimal(account.initialBalance),
                from: sourceCurrency,
                to: preferredCurrency,
                context: context
            )
            total += initial
        }

        let pastTransactions = transactions.filter { $0.date < date }
        let eligibleAccountIDs = Set(accounts.map { $0.persistentModelID })

        for tx in pastTransactions {
            guard let account = tx.account, eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode)) ?? preferredCurrency
            let amount = CurrencyConverter.shared.convert(
                Decimal(tx.amount),
                from: sourceCurrency.rawValue,
                to: preferredCurrency.rawValue,
                on: tx.date,
                context: context
            )

            // Logic: Income adds, Expense subtracts.
            // If amount is signed in DB, just add. If absolute, check category.
            // Assuming signed storage for now based on standard practices,
            // BUT `TransactionItem` doesn't seem to enforce sign.
            // Let's check `Category.isIncome`.

            let isIncome = tx.category?.isIncome ?? (tx.amount >= 0)

            // Apply Category Filter if present
            if let categoryID = categoryFilter {
                if tx.category?.persistentModelID != categoryID {
                    continue
                }
            }

            if isIncome {
                total += abs(amount)
            } else {
                total -= abs(amount)
            }
        }

        return (total as NSDecimalNumber).doubleValue
    }

    private func calculateStatus(
        accounts: [Account],
        transactions: [TransactionItem],
        currentBalance: Double,
        preferredCurrency: CurrencyCode,
        currentInterval: DateInterval,
        context: ModelContext
    ) {
        // Historical Threshold: Average balance of the PREVIOUS period of same duration.

        let previousEnd = currentInterval.start

        // We need the average daily balance of that period? Or the End Balance?
        // For simplicity: Let's compute the total balance at the END of the historical period.
        // "previousEnd" is the START of current period = END of previous period.

        // Or simply the Balance at the end of the previous period?

        // Let's try: Average Daily Balance of the previous period.
        // This represents the "normal" level of funds the user has.

        // Simplified approach for MVP: Compare Current Balance vs Balance exactly 1 period ago.
        let balanceOnePeriodAgo = initialBalanceForTrend(
            accounts: accounts,
            transactions: transactions,
            before: previousEnd,
            preferredCurrency: preferredCurrency,
            context: context
        )

        self.historicalThreshold = balanceOnePeriodAgo

        // Status Logic
        // Green (Good): > Threshold + 5%
        // Red (Critical): < Threshold - 5%
        // Normal: Within +/- 5%

        let diff = currentBalance - historicalThreshold
        let percentage = historicalThreshold == 0 ? 0 : (diff / abs(historicalThreshold))

        if percentage > 0.05 {
            balanceStatus = .good
        } else if percentage < -0.05 {
            balanceStatus = .critical
        } else {
            balanceStatus = .normal
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
        let currentRates = calculateRatesFromPreferred(
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
        let chartPoints = buildExchangeRateChartPoints(
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

    /// Converts exchange rates so they're expressed as: 1 targetCurrency = X preferredCurrency
    /// Example: If preferred is PEN, returns "1 USD = 3.72 PEN"
    private func calculateRatesFromPreferred(
        preferredCurrency: String,
        targetCurrencies: [String],
        exchangeRate: ExchangeRate
    ) -> [String: Double] {
        let rates = exchangeRate.decodedRates()

        // The stored rates are based on USD (e.g., USD=1, PEN=3.72, EUR=0.95)
        // This means: 1 USD = 3.72 PEN, 1 USD = 0.95 EUR
        // We need to express as: 1 targetCurrency = X preferredCurrency

        // Get the rate of the preferred currency (relative to USD)
        let preferredRate = rates[preferredCurrency] ?? (preferredCurrency == "USD" ? 1.0 : 0)

        guard preferredRate > 0 else { return [:] }

        var result: [String: Double] = [:]
        for currency in targetCurrencies where currency != preferredCurrency {
            // Get the target currency rate (relative to USD)
            let targetRate = rates[currency] ?? (currency == "USD" ? 1.0 : 0)

            guard targetRate > 0 else { continue }

            // Formula: 1 target = (preferredRate / targetRate) preferred
            // Example with preferred=PEN, target=USD:
            //   preferredRate = 3.72 (1 USD = 3.72 PEN)
            //   targetRate = 1.0 (1 USD = 1 USD)
            //   So: 1 USD = 3.72/1.0 = 3.72 PEN ✓
            // Example with preferred=PEN, target=EUR:
            //   preferredRate = 3.72
            //   targetRate = 0.95 (1 USD = 0.95 EUR)
            //   So: 1 EUR = 3.72/0.95 = 3.92 PEN ✓
            result[currency] = preferredRate / targetRate
        }
        return result
    }

    /// Builds chart points for the exchange rate trend.
    private func buildExchangeRateChartPoints(
        interval: DateInterval,
        grouping: TrendGrouping,
        preferredCurrency: String,
        targetCurrencies: [String],
        context: ModelContext
    ) -> [ExchangeRateChartPoint] {
        let calendar = Calendar.current
        var points: [ExchangeRateChartPoint] = []

        // Generate date buckets based on grouping
        var currentDate = interval.start

        while currentDate <= interval.end {
            let bucketEnd: Date
            switch grouping {
            case .day:
                bucketEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .week:
                bucketEnd =
                    calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case .month:
                bucketEnd =
                    calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }

            // Get rates for this bucket (average if multiple days)
            let bucketRates = getAverageRatesForBucket(
                start: currentDate,
                end: min(bucketEnd, interval.end),
                preferredCurrency: preferredCurrency,
                targetCurrencies: targetCurrencies,
                context: context
            )

            if !bucketRates.isEmpty {
                points.append(ExchangeRateChartPoint(date: currentDate, rates: bucketRates))
            }

            currentDate = bucketEnd
        }

        return points
    }

    /// Gets average exchange rates for a date bucket.
    private func getAverageRatesForBucket(
        start: Date,
        end: Date,
        preferredCurrency: String,
        targetCurrencies: [String],
        context: ModelContext
    ) -> [String: Double] {
        let calendar = Calendar.current
        var allRates: [[String: Double]] = []

        var currentDate = start
        while currentDate < end {
            // Try to get rate for this specific date
            if let rate = ExchangeRateService.shared.getRate(for: currentDate, context: context) {
                let convertedRates = calculateRatesFromPreferred(
                    preferredCurrency: preferredCurrency,
                    targetCurrencies: targetCurrencies,
                    exchangeRate: rate
                )
                if !convertedRates.isEmpty {
                    allRates.append(convertedRates)
                }
            } else if let fallbackRate = ExchangeRateService.shared.getMostRecentRate(
                onOrBefore: currentDate, context: context)
            {
                // Use fallback rate
                let convertedRates = calculateRatesFromPreferred(
                    preferredCurrency: preferredCurrency,
                    targetCurrencies: targetCurrencies,
                    exchangeRate: fallbackRate
                )
                if !convertedRates.isEmpty {
                    allRates.append(convertedRates)
                }
            }

            currentDate =
                calendar.date(byAdding: .day, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(86400)
        }

        // Calculate averages
        guard !allRates.isEmpty else { return [:] }

        var averages: [String: Double] = [:]
        for currency in targetCurrencies {
            let values = allRates.compactMap { $0[currency] }
            if !values.isEmpty {
                averages[currency] = values.reduce(0, +) / Double(values.count)
            }
        }

        return averages
    }

    /// Updates the selected comparison currencies.
    func updateComparisonCurrencies(_ currencies: [CurrencyCode]) {
        // Limit to max 2
        selectedComparisonCurrencies = Array(currencies.prefix(2))
    }
}
