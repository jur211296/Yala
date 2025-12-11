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
    var widgetConfigs: [WidgetConfig] = []

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

    enum TrendPeriod: String, CaseIterable, Identifiable {
        case week = "Esta semana"
        case month = "Este mes"
        case year = "Este año"

        var id: String { rawValue }
    }

    // Trend Locking Logic
    var isTrendLockedToExpense: Bool {
        selectedCategoryID != nil || selectedSubcategoryID != nil
    }

    private func enforceTrendLock() {
        if isTrendLockedToExpense {
            trendType = .expense
        }
    }

    // MARK: - Dependencies / Configuration

    init() {
        loadWidgetConfigs()
    }

    // MARK: - Widget Logic

    func loadWidgetConfigs() {
        if let data = UserDefaults.standard.data(forKey: widgetConfigsKey),
            var decoded = try? JSONDecoder().decode([WidgetConfig].self, from: data)
        {
            // Enforce Locked Properties (Healing Logic)
            for index in decoded.indices {
                if decoded[index].isLocked {
                    decoded[index].isVisible = true
                    decoded[index].size = .large
                }
            }

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

        // Enforce Trend is always first
        if let trendIndex = newConfigs.firstIndex(where: { $0.type == .trend }), trendIndex != 0 {
            let trend = newConfigs.remove(at: trendIndex)
            newConfigs.insert(trend, at: 0)
        } else if !newConfigs.contains(where: { $0.type == .trend }) {
            // Fallback if somehow lost
            newConfigs.insert(
                WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .large), at: 0)
        }

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
    func totalBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        // Optimized: Calculate all balances in one pass
        let balances = AccountBalanceCalculator.batchCalculateBalances(
            accounts: eligibleAccounts,
            transactions: transactions
        )

        let totalDecimal: Decimal = eligibleAccounts.reduce(0) { partial, account in
            let currentBalance = balances[account.persistentModelID] ?? 0

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalance,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return partial + converted
        }

        return (totalDecimal as NSDecimalNumber).doubleValue
    }

    /// Calculates the displayed balance (either total or selected account).
    func displayedBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        if let selectedID = selectedAccountID,
            let account = accounts.first(where: { $0.persistentModelID == selectedID }),
            !account.isArchived,
            !account.excludeFromStatistics
        {
            let currentBalanceDecimal = AccountBalanceCalculator.currentBalance(
                for: account,
                allTransactions: transactions
            )

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalanceDecimal,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return (converted as NSDecimalNumber).doubleValue
        }

        return totalBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode
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
        to target: CurrencyCode
    ) -> Decimal {
        if source == target {
            return amount
        }

        // Tasas de ejemplo (mismas que en PanelView original)
        let usdToPen = Decimal(string: "3.54") ?? Decimal(3.54)
        let eurToPen = Decimal(string: "3.89") ?? Decimal(3.89)

        func penToUsd(_ pen: Decimal) -> Decimal {
            guard usdToPen != 0 else { return pen }
            return pen / usdToPen
        }

        func penToEur(_ pen: Decimal) -> Decimal {
            guard eurToPen != 0 else { return pen }
            return pen / eurToPen
        }

        let amountInPen: Decimal
        switch source {
        case .pen:
            amountInPen = amount
        case .usd:
            amountInPen = amount * usdToPen
        case .eur:
            amountInPen = amount * eurToPen
        }

        switch target {
        case .pen:
            return amountInPen
        case .usd:
            return penToUsd(amountInPen)
        case .eur:
            return penToEur(amountInPen)
        }
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
    var trendType: TrendType = .balance
    var focusedDate: Date? = nil  // Global Focus State

    /// Calculates trend data and status based on the current period, selected account, and selected category.
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
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
        case .week, .month, .year:
            trendGrouping = .day
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
            currencyCode: defaultCurrencyCode
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

            return true
        }

        // 1. Chart Data
        self.chartTransactions = BalanceTrendCalculator.calculateTrend(
            transactions: filtered,
            grouping: self.trendGrouping,
            interval: self.panelDateInterval,
            currencyCode: defaultCurrencyCode
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

        // Apply Subcategory Filter locally for Category Calculation
        // If a subcategory is selected, the Category widget should only show the parent category
        // and the value should be filtered to that subcategory.
        let finalCategoryTransactions: [TransactionItem]
        if let subID = selectedSubcategoryID {
            finalCategoryTransactions = finalContextTransactions.filter {
                $0.subcategory?.name == subID
            }
        } else {
            finalCategoryTransactions = finalContextTransactions
        }

        self.topSpendingCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: finalCategoryTransactions,
            interval: panelDateInterval,
            currencyCode: defaultCurrencyCode
        )

        // 3. Top Subcategories
        // Always prioritize the active 'selectedCategoryID' (whether Explicit or Implicit)
        // This ensures that if we are in "Shopping" context, picking a subcategory keeps us in "Shopping" list.
        // Fallback to 'subcategoriesWidgetFilter' only if there's no global context (e.g. browsing "All" -> Local Filter)
        let effectiveCategoryFilter = selectedCategoryID ?? subcategoriesWidgetFilter

        self.topSubcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: finalContextTransactions,  // Base set (Time + Account)
            interval: panelDateInterval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter  // Pass the effective filter
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
        defaultCurrencyCode: String
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
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    private func initialBalanceForTrend(
        accounts: [Account],
        transactions: [TransactionItem],
        before date: Date,
        preferredCurrency: CurrencyCode,
        categoryFilter: PersistentIdentifier? = nil
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
                to: preferredCurrency
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
            let amount = convertToPreferredCurrency(
                amount: Decimal(tx.amount),
                from: sourceCurrency,
                to: preferredCurrency
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
        currentInterval: DateInterval
    ) {
        // Historical Threshold: Average balance of the PREVIOUS period of same duration.

        let previousEnd = currentInterval.start

        // We need the average daily balance of that period? Or the End Balance?
        // Requirement says: "umbral de gasto promedio en periodos inmediatamente pasados"
        // (average spending threshold in immediately past periods) OR "saldo actual ... respecto a un umbral histórico"

        // Let's interpret "Historical Threshold" as the Average End-of-Period Balance of the last 3 periods?
        // Or simply the Balance at the end of the previous period?

        // Let's try: Average Daily Balance of the previous period.
        // This represents the "normal" level of funds the user has.

        // Simplified approach for MVP: Compare Current Balance vs Balance exactly 1 period ago.
        let balanceOnePeriodAgo = initialBalanceForTrend(
            accounts: accounts,
            transactions: transactions,
            before: previousEnd,
            preferredCurrency: preferredCurrency
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
}
