//
//  BudgetsViewModel.swift
//  Yala
//
//  ViewModel for managing budgets, calculations, and UI state
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BudgetsViewModel {

    // MARK: - Static Formatters

    private static let weekDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let monthLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Debounce state

    private var recalculateTask: Task<Void, Never>?
    private var pendingReload = false
    private(set) var isInBackground = false

    // MARK: - Data

    private(set) var allBudgets: [Budget] = []
    private(set) var allTransactions: [TransactionItem] = []
    private(set) var accounts: [Account] = []

    // MARK: - Filter State

    /// Selected period type for filtering budgets
    var selectedPeriodType: BudgetPeriodType = .monthly

    /// Selected week start date (for weekly budgets)
    var selectedWeek: Date = Date.now

    /// Selected month start date (for monthly budgets)
    var selectedMonth: Date = Date.now

    /// Selected year (for yearly budgets)
    var selectedYear: Int = Calendar.current.component(.year, from: Date.now)

    // MARK: - UI State

    /// Whether to show the period selector sheet
    var showPeriodSelector: Bool = false

    /// Whether to show the budget editor sheet
    var showBudgetEditor: Bool = false

    /// The budget being edited (nil for new budget)
    var editingBudget: Budget?

    // MARK: - Computed Data

    /// Budgets grouped by status
    var groupedBudgets: [(status: BudgetStatus, budgets: [BudgetSummary])] = []

    /// Count of active budgets (for Pro tier limit checking)
    var activeBudgetsCount: Int {
        allBudgets.count(where: { $0.isActive })
    }

    // MARK: - Initialization

    init() {
        // Initialize with current period
        let calendar = userConfiguredCalendar()
        self.selectedWeek = calendar.startOfWeek(for: Date.now)
        self.selectedMonth = calendar.startOfMonth(for: Date.now)
        self.selectedYear = calendar.component(.year, from: Date.now)
    }

    // MARK: - Period Navigation

    /// Smart label for the current period (e.g. "Este mes", "Febrero 2026")
    var periodLabel: String {
        let calendar = userConfiguredCalendar()

        switch selectedPeriodType {
        case .weekly:
            let currentWeek = calendar.startOfWeek(for: Date.now)

            if calendar.isDate(selectedWeek, equalTo: currentWeek, toGranularity: .weekOfYear) {
                return L10n.Period.thisWeek
            } else if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek),
                      calendar.isDate(selectedWeek, equalTo: previousWeek, toGranularity: .weekOfYear) {
                return L10n.Period.lastWeek
            } else if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek),
                      calendar.isDate(selectedWeek, equalTo: nextWeek, toGranularity: .weekOfYear) {
                return L10n.Period.nextWeek
            } else {
                let start = Self.weekDateFormatter.string(from: selectedWeek)
                let end = calendar.date(byAdding: .day, value: 6, to: selectedWeek) ?? selectedWeek
                let endString = Self.weekDateFormatter.string(from: end)
                return "\(start) - \(endString)"
            }

        case .monthly:
            let currentMonth = calendar.startOfMonth(for: Date.now)

            if calendar.isDate(selectedMonth, equalTo: currentMonth, toGranularity: .month) {
                return L10n.Period.thisMonth
            } else if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
                      calendar.isDate(selectedMonth, equalTo: previousMonth, toGranularity: .month) {
                return L10n.Period.lastMonth
            } else if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth),
                      calendar.isDate(selectedMonth, equalTo: nextMonth, toGranularity: .month) {
                return L10n.Period.nextMonth
            } else {
                return Self.monthYearFormatter.string(from: selectedMonth).capitalized
            }

        case .yearly:
            let currentYear = calendar.component(.year, from: Date.now)

            if selectedYear == currentYear {
                return L10n.Period.thisYear
            } else if selectedYear == currentYear - 1 {
                return L10n.Period.lastYear
            } else if selectedYear == currentYear + 1 {
                return L10n.Period.nextYear
            } else {
                return "\(selectedYear)"
            }

        case .unique:
            return ""
        }
    }

    /// Navigate to the previous period
    func previousPeriod() {
        let calendar = userConfiguredCalendar()
        switch selectedPeriodType {
        case .weekly:
            if let prev = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedWeek) {
                selectedWeek = prev
            }
        case .monthly:
            if let prev = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                selectedMonth = prev
            }
        case .yearly:
            selectedYear -= 1
        case .unique:
            break
        }
    }

    /// Navigate to the next period
    func nextPeriod() {
        let calendar = userConfiguredCalendar()
        switch selectedPeriodType {
        case .weekly:
            if let next = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeek) {
                selectedWeek = next
            }
        case .monthly:
            if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                selectedMonth = next
            }
        case .yearly:
            selectedYear += 1
        case .unique:
            break
        }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        let isNewContext = self.modelContext !== context
        self.modelContext = context
        if isNewContext { loadData() }
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        // Load budgets
        let budgetDescriptor = FetchDescriptor<Budget>(sortBy: [SortDescriptor(\Budget.createdAt, order: .reverse)])
        do {
            let fetched = try context.fetch(budgetDescriptor)
            if fetched != allBudgets { allBudgets = fetched }
        } catch {
            #if DEBUG
            print("BudgetsViewModel: Error loading budgets: \(error)")
            #endif
            allBudgets = []
        }

        // Load transactions (filtered by earliest budget date to avoid loading all history)
        let earliestDate = allBudgets.compactMap { budget -> Date? in
            if let start = budget.startDate { return start }
            return Calendar.current.date(byAdding: .year, value: -1, to: Date.now)
        }.min() ?? Calendar.current.date(byAdding: .year, value: -1, to: Date.now) ?? Date.now
        let capturedDate = earliestDate
        let transactionDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= capturedDate },
            sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse), SortDescriptor(\TransactionItem.createdAt, order: .reverse)]
        )
        do {
            let fetched = try context.fetch(transactionDescriptor)
            if fetched != allTransactions { allTransactions = fetched }
        } catch {
            #if DEBUG
            print("BudgetsViewModel: Error loading transactions: \(error)")
            #endif
            allTransactions = []
        }

        // Load accounts
        let accountDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            let fetched = try context.fetch(accountDescriptor)
            if fetched != accounts { accounts = fetched }
        } catch {
            #if DEBUG
            print("BudgetsViewModel: Error loading accounts: \(error)")
            #endif
            accounts = []
        }
    }

    /// Check if there are inactive budgets for current period type
    func hasInactiveBudgets(forPeriodTypeIndex segment: Int) -> Bool {
        let budgets = allBudgets.filter { budget in
            if segment == 3 {
                return budget.periodType == BudgetPeriodType.unique.rawValue
            } else {
                return budget.periodType == selectedPeriodType.rawValue
            }
        }
        return budgets.contains { !$0.isActive }
    }

    /// Refresh budget data with current filters
    func refreshBudgetData(hideInactive: Bool, defaultCurrencyCode: String) {
        var filteredBudgets = allBudgets.filter {
            $0.periodType == selectedPeriodType.rawValue
        }

        if hideInactive {
            filteredBudgets = filteredBudgets.filter { $0.isActive }
        }

        calculateBudgetData(
            budgets: filteredBudgets,
            transactions: allTransactions,
            accounts: accounts,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    // MARK: - Budget Calculation

    /// Calculate budget data for display
    func calculateBudgetData(
        budgets: [Budget],
        transactions: [TransactionItem],
        accounts: [Account],
        defaultCurrencyCode: String
    ) {
        // Use budgets as-is (already filtered by BudgetsListView)
        // Calculate summary for each budget
        let summaries = budgets.compactMap { budget -> BudgetSummary? in
            let spent = getBudgetSpending(
                budget: budget,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCode
            )
            let percentage = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100.0 : 0.0
            let daysRemaining = getDaysRemaining(budget: budget)
            let status = getBudgetStatus(budget: budget, spending: spent)
            let (icon, color) = budget.displayProperties

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

        // Group by status
        let grouped = Dictionary(grouping: summaries) { $0.status }

        // Sort by status order and create final array
        groupedBudgets = BudgetStatus.allCases
            .compactMap { status -> (status: BudgetStatus, budgets: [BudgetSummary])? in
                guard let budgets = grouped[status], !budgets.isEmpty else { return nil }
                // Sort budgets within each status by name
                let sortedBudgets = budgets.sorted { $0.budget.name < $1.budget.name }
                return (status: status, budgets: sortedBudgets)
            }
            .sorted { $0.status.sortOrder < $1.status.sortOrder }
    }

    // MARK: - Summary Builder

    /// Build a fresh BudgetSummary for a single budget (used by BudgetDetailView).
    func buildSummary(for budget: Budget, defaultCurrencyCode: String) -> BudgetSummary {
        let spent = getBudgetSpending(
            budget: budget,
            transactions: allTransactions,
            defaultCurrencyCode: defaultCurrencyCode
        )
        let percentage = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100.0 : 0.0
        let daysRemaining = getDaysRemaining(budget: budget)
        let status = getBudgetStatus(budget: budget, spending: spent)
        let (icon, color) = budget.displayProperties

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

    // MARK: - Historical Spending

    /// Returns spending vs limit for N previous periods (for charts).
    /// Returns empty array for `.unique` budgets (no recurring periods).
    func getHistoricalSpending(budget: Budget, periods: Int, defaultCurrencyCode: String) -> [(label: String, spent: Double, limit: Double)] {
        guard let periodType = BudgetPeriodType(rawValue: budget.periodType),
              periodType != .unique else {
            return []
        }

        let calendar = userConfiguredCalendar()
        var results: [(label: String, spent: Double, limit: Double)] = []

        for offset in (1 - periods)...0 {
            let interval: DateInterval
            let label: String

            switch periodType {
            case .weekly:
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedWeek) else { continue }
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                interval = DateInterval(start: weekStart, end: weekEnd)
                label = Self.weekDateFormatter.string(from: weekStart)

            case .monthly:
                guard let monthStart = calendar.date(byAdding: .month, value: offset, to: selectedMonth) else { continue }
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                interval = DateInterval(start: monthStart, end: monthEnd)
                label = Self.monthLabelFormatter.string(from: monthStart)

            case .yearly:
                let year = selectedYear + offset
                guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                      let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { continue }
                interval = DateInterval(start: yearStart, end: yearEnd)
                label = "\(year)"

            case .unique:
                continue
            }

            let spent = Self.calculateSpending(budget: budget, transactions: allTransactions, interval: interval)
            results.append((label: label, spent: spent, limit: budget.limitAmount))
        }

        return results
    }

    /// Returns daily cumulative spending for the current budget period (for area chart).
    func getDailyCumulativeSpending(budget: Budget) -> [(date: Date, cumulative: Double)] {
        getDailyCumulativeSpending(budget: budget, in: getBudgetDateInterval(budget: budget))
    }

    /// Returns daily cumulative spending for an explicit date interval.
    func getDailyCumulativeSpending(budget: Budget, in interval: DateInterval) -> [(date: Date, cumulative: Double)] {
        let calendar = userConfiguredCalendar()
        let today = Date.now
        let endDate = min(today, interval.end)

        guard interval.start <= endDate else { return [] }

        let filtered = Self.filterTransactions(allTransactions, forBudget: budget, in: interval)
        guard !filtered.isEmpty else { return [] }

        // Group by day
        var dailyAmounts: [Date: Double] = [:]
        for tx in filtered {
            let day = calendar.startOfDay(for: tx.date)
            let amount = Self.budgetAmount(of: tx, in: budget.currencyCode)
            dailyAmounts[day, default: 0] += abs(amount)
        }

        // Build cumulative series
        var cumulative = 0.0
        var results: [(date: Date, cumulative: Double)] = []
        var current = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: endDate)

        while current <= end {
            cumulative += dailyAmounts[current] ?? 0
            results.append((date: current, cumulative: cumulative))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return results
    }

    /// Returns spending breakdown by both subcategory and parent category in a single filtering pass.
    func getCombinedBreakdown(budget: Budget) -> (
        subcategories: [(name: String, icon: String, color: String, amount: Double, parentCategoryName: String)],
        parentCategories: [(name: String, icon: String, color: String, amount: Double)]
    ) {
        getCombinedBreakdown(budget: budget, in: getBudgetDateInterval(budget: budget))
    }

    /// Returns spending breakdown for an explicit date interval.
    func getCombinedBreakdown(budget: Budget, in interval: DateInterval) -> (
        subcategories: [(name: String, icon: String, color: String, amount: Double, parentCategoryName: String)],
        parentCategories: [(name: String, icon: String, color: String, amount: Double)]
    ) {
        let filtered = Self.filterTransactions(allTransactions, forBudget: budget, in: interval)
        guard !filtered.isEmpty else { return ([], []) }

        var subBreakdown: [PersistentIdentifier: (name: String, icon: String, color: String, amount: Double, parentCategoryName: String)] = [:]
        var parentBreakdown: [PersistentIdentifier: (name: String, icon: String, color: String, amount: Double)] = [:]

        for tx in filtered {
            guard let sub = tx.subcategory else { continue }
            let absAmount = abs(Self.budgetAmount(of: tx, in: budget.currencyCode))
            let cat = sub.safeCategory

            // Subcategory grouping
            let subKey = sub.persistentModelID
            if var existing = subBreakdown[subKey] {
                existing.amount += absAmount
                subBreakdown[subKey] = existing
            } else {
                let color = sub.colorHex ?? cat.colorHex
                let icon = sub.iconName ?? cat.iconName ?? "tag.fill"
                subBreakdown[subKey] = (name: sub.name, icon: icon, color: color, amount: absAmount, parentCategoryName: cat.name)
            }

            // Parent category grouping
            let catKey = cat.persistentModelID
            if var existing = parentBreakdown[catKey] {
                existing.amount += absAmount
                parentBreakdown[catKey] = existing
            } else {
                let icon = cat.iconName ?? "tag.fill"
                parentBreakdown[catKey] = (name: cat.name, icon: icon, color: cat.colorHex, amount: absAmount)
            }
        }

        return (
            subcategories: subBreakdown.values.sorted { $0.amount > $1.amount },
            parentCategories: parentBreakdown.values.sorted { $0.amount > $1.amount }
        )
    }

    // MARK: - Budget Spending Calculation

    /// Calculate total spending for a budget
    func getBudgetSpending(
        budget: Budget,
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let interval = getBudgetDateInterval(budget: budget)
        return Self.calculateSpending(budget: budget, transactions: transactions, interval: interval)
    }

    /// Filters transactions by budget criteria (accounts, subcategories, tags, natures, expenses only).
    /// Shared by calculateSpending, getDailyCumulativeSpending, and getCategoryBreakdown.
    static func filterTransactions(
        _ transactions: [TransactionItem],
        forBudget budget: Budget,
        in interval: DateInterval
    ) -> [TransactionItem] {
        var filtered = transactions.filter { interval.contains($0.date) }

        if let accounts = budget.accounts, !accounts.isEmpty {
            let accountIDs = Set(accounts.map { $0.persistentModelID })
            filtered = filtered.filter { tx in
                tx.account.map { accountIDs.contains($0.persistentModelID) } ?? false
            }
        }

        if let subcategories = budget.subcategories, !subcategories.isEmpty {
            let subIDs = Set(subcategories.map { $0.persistentModelID })
            filtered = filtered.filter { tx in
                tx.subcategory.map { subIDs.contains($0.persistentModelID) } ?? false
            }
        }

        if let budgetTags = budget.tags, !budgetTags.isEmpty {
            let tagIDs = Set(budgetTags.map { $0.persistentModelID })
            filtered = filtered.filter { tx in
                !Set((tx.tags ?? []).map { $0.persistentModelID }).isDisjoint(with: tagIDs)
            }
        }

        if let naturesString = budget.natures, !naturesString.isEmpty {
            let natures = naturesString.split(separator: ",")
                .compactMap { SubcategoryNeed(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
            filtered = filtered.filter { natures.contains($0.effectiveNeed) }
        }

        // Shared expense inclusion
        if !budget.includeSharedExpenses {
            filtered = filtered.filter { $0.splitExpenseID == nil }
        }

        return filtered.filter { $0.category?.isIncome == false }
    }

    /// Shared spending calculation used by both BudgetsViewModel and BudgetAlertService.
    /// Filters transactions by budget criteria and sums expense amounts en la
    /// moneda del budget (multi-divisa: convierte con TC actual).
    /// `converter` opcional → inyectable en tests.
    static func calculateSpending(
        budget: Budget,
        transactions: [TransactionItem],
        interval: DateInterval,
        converter: CurrencyConverting? = nil
    ) -> Double {
        let filtered = filterTransactions(transactions, forBudget: budget, in: interval)

        return filtered.reduce(0.0) { sum, tx in
            sum + abs(budgetAmount(of: tx, in: budget.currencyCode, converter: converter))
        }
    }

    /// Devuelve el monto de la transacción expresado en la moneda del budget.
    /// Si las monedas coinciden, usa `tx.amount` directo. En multi-divisa,
    /// convierte con TC actual (`convertWithLatestRate`) — coherente con la
    /// semántica "presupuesto consumido HOY". El comportamiento previo
    /// (heurística useBudgetCurrency basada en número de cuentas + fallback
    /// a `amountInPreferredCurrency`) era incorrecto cuando la moneda
    /// preferida del usuario != moneda del budget.
    @MainActor
    static func budgetAmount(
        of tx: TransactionItem,
        in budgetCurrencyCode: String,
        converter: CurrencyConverting? = nil
    ) -> Double {
        if tx.currencyCode == budgetCurrencyCode {
            return tx.amount
        }
        let resolvedConverter = converter ?? CurrencyConverter.shared
        let converted = resolvedConverter.convertWithLatestRate(
            Decimal(tx.amount),
            from: tx.currencyCode,
            to: budgetCurrencyCode
        )
        return NSDecimalNumber(decimal: converted).doubleValue
    }

    // MARK: - Budget Status Determination

    /// Determine budget status based on isActive property and spending
    func getBudgetStatus(budget: Budget, spending: Double) -> BudgetStatus {
        calculateBudgetStatus(isActive: budget.isActive, spending: spending, limit: budget.limitAmount)
    }

    /// Pure logic for budget status calculation (testable without SwiftData)
    func calculateBudgetStatus(isActive: Bool, spending: Double, limit: Double) -> BudgetStatus {
        // If budget is manually set to inactive, it goes to inactive section regardless of spending
        guard isActive else {
            return .inactive
        }

        // For active budgets, determine status based on spending
        let isExceeded = spending >= limit

        if isExceeded {
            return .exceeded
        } else {
            return .active
        }
    }

    // MARK: - Days Remaining Calculation

    /// Calculate days remaining in budget period
    func getDaysRemaining(budget: Budget) -> Int {
        let interval = getBudgetDateInterval(budget: budget)
        let calendar = userConfiguredCalendar()
        let today = Date.now

        // If the period has ended (today is after the period), return -1 to indicate "Past"
        if today > interval.end {
            return -1
        }

        // If today is not in the budget period yet, return 0
        guard interval.contains(today) else { return 0 }

        // Calculate days from today to end of period
        let components = calendar.dateComponents([.day], from: today, to: interval.end)
        return max(0, components.day ?? 0)
    }

    // MARK: - Period Date Interval

    /// Get date interval for a budget period
    func getBudgetDateInterval(budget: Budget) -> DateInterval {
        let calendar = userConfiguredCalendar()

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            // Fallback to selected month if invalid
            let start = selectedMonth
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }

        switch periodType {
        case .weekly:
            // Use selected week for this budget's period
            let weekStart = selectedWeek
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)

        case .monthly:
            // Use selected month for this budget's period
            let monthStart = selectedMonth
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)

        case .yearly:
            // Use selected year for this budget's period
            let year = selectedYear
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date.now
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)

        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                // Fallback to selected month if dates are missing
                let start = selectedMonth
                let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                return DateInterval(start: start, end: end)
            }
            return DateInterval(start: start, end: end)
        }
    }

    // MARK: - Icon and Color Logic

    /// Pure logic for display properties calculation (testable without SwiftData)
    func calculateDisplayProperties(
        subcategoryCount: Int,
        firstSubcategoryIcon: String?,
        firstCategoryColor: String?,
        uniqueCategoryCount: Int,
        firstCategoryIcon: String? = nil
    ) -> (icon: String, color: String) {
        // No subcategories: use neutral app icon/color
        guard subcategoryCount > 0 else {
            return ("chart.pie.fill", AppConstants.defaultColorHex) // Electric indigo
        }

        // Single subcategory: use subcategory icon/color
        if subcategoryCount == 1 {
            let icon = firstSubcategoryIcon ?? "tag.fill"
            let color = firstCategoryColor ?? AppConstants.defaultColorHex
            return (icon, color)
        }

        // Multiple subcategories: check if they're from the same category
        if uniqueCategoryCount == 1 {
            // All from same category: use category icon/color
            let icon = firstCategoryIcon ?? "tag.fill"
            let color = firstCategoryColor ?? AppConstants.defaultColorHex
            return (icon, color)
        } else {
            // Multiple categories: use app icon + electric indigo
            return ("chart.pie.fill", AppConstants.defaultColorHex)
        }
    }

    // MARK: - Debounced Recalculation

    /// Suppresses recalculation when the app leaves active state — prevents 0x8BADF00D.
    func setBackground(_ value: Bool) {
        isInBackground = value
        if value {
            recalculateTask?.cancel()
            recalculateTask = nil
            pendingReload = false
        }
    }

    /// Cancel any pending recalculation (call from `.onDisappear`).
    func cancelRecalculation() {
        recalculateTask?.cancel()
    }

    /// Compute-only debounced (150ms). Use when a filter/UI input changed
    /// but the underlying DB hasn't mutated.
    func recalculateData(hideInactive: Bool, defaultCurrencyCode: String) {
        scheduleRecalculation(reload: false, hideInactive: hideInactive, currency: defaultCurrencyCode)
    }

    /// Reload + compute debounced (150ms). Use when DB mutations could have
    /// occurred (e.g. after editor dismiss or `dataVersion` bump).
    func reloadAndRecalculate(hideInactive: Bool, defaultCurrencyCode: String) {
        scheduleRecalculation(reload: true, hideInactive: hideInactive, currency: defaultCurrencyCode)
    }

    /// Shared debounce (150ms). `pendingReload` ensures a reload request isn't lost
    /// if a subsequent compute-only call arrives within the debounce window.
    private func scheduleRecalculation(reload: Bool, hideInactive: Bool, currency: String) {
        guard !isInBackground else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        if reload { pendingReload = true }
        recalculateTask?.cancel()
        recalculateTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard !Task.isCancelled else { return }
            let shouldReload = pendingReload
            pendingReload = false
            if shouldReload { loadData() }
            refreshBudgetData(hideInactive: hideInactive, defaultCurrencyCode: currency)
        }
    }
}

// MARK: - BudgetStatus Extension

extension BudgetStatus: CaseIterable {
    static var allCases: [BudgetStatus] {
        [.exceeded, .active, .inactive]
    }
}

// MARK: - Calendar Extension

