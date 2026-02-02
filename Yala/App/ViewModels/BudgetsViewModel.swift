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

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allBudgets: [Budget] = []
    private(set) var allTransactions: [TransactionItem] = []
    private(set) var accounts: [Account] = []

    // MARK: - Filter State

    /// Selected period type for filtering budgets
    var selectedPeriodType: BudgetPeriodType = .monthly

    /// Selected week start date (for weekly budgets)
    var selectedWeek: Date = Date()

    /// Selected month start date (for monthly budgets)
    var selectedMonth: Date = Date()

    /// Selected year (for yearly budgets)
    var selectedYear: Int = Calendar.current.component(.year, from: Date())

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

    // MARK: - Initialization

    init() {
        // Initialize with current period
        let calendar = Calendar.current
        self.selectedWeek = calendar.startOfWeek(for: Date())
        self.selectedMonth = calendar.startOfMonth(for: Date())
        self.selectedYear = calendar.component(.year, from: Date())
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        // Load budgets
        let budgetDescriptor = FetchDescriptor<Budget>(sortBy: [SortDescriptor(\Budget.createdAt, order: .reverse)])
        do {
            allBudgets = try context.fetch(budgetDescriptor)
        } catch {
            print("BudgetsViewModel: Error loading budgets: \(error)")
            allBudgets = []
        }

        // Load transactions
        let transactionDescriptor = FetchDescriptor<TransactionItem>(sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)])
        do {
            allTransactions = try context.fetch(transactionDescriptor)
        } catch {
            print("BudgetsViewModel: Error loading transactions: \(error)")
            allTransactions = []
        }

        // Load accounts
        let accountDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            accounts = try context.fetch(accountDescriptor)
        } catch {
            print("BudgetsViewModel: Error loading accounts: \(error)")
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

    // MARK: - Budget Spending Calculation

    /// Calculate total spending for a budget
    func getBudgetSpending(
        budget: Budget,
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        // Get budget period date interval
        let interval = getBudgetDateInterval(budget: budget)

        // Filter transactions by date
        var filtered = transactions.filter { transaction in
            interval.contains(transaction.date)
        }

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
        filtered = filtered.filter { transaction in
            transaction.category?.isIncome == false
        }

        // Sum amounts based on budget account configuration:
        // - If exactly 1 account: use transaction.amount (same currency as budget)
        // - If 0 or multiple accounts: use amountInPreferredCurrency (normalized)
        let useBudgetCurrency = (budget.accounts?.count ?? 0) == 1

        let total = filtered.reduce(0.0) { sum, transaction in
            let amount = useBudgetCurrency ? transaction.amount : transaction.amountInPreferredCurrency
            return sum + abs(amount)
        }

        return total
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
        let calendar = Calendar.current
        let today = Date()

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
        let calendar = Calendar.current

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
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
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

    /// Determine display icon and color for a budget
    func getBudgetDisplayProperties(budget: Budget) -> (icon: String, color: String) {
        // Extract data for pure logic function
        let subcategories = budget.subcategories ?? []
        let subcategoryCount = subcategories.count
        let firstSubcategory = subcategories.first
        let firstSubcategoryIcon = firstSubcategory?.iconName ?? firstSubcategory?.safeCategory.iconName
        let firstCategoryColor = firstSubcategory?.colorHex ?? firstSubcategory?.safeCategory.colorHex
        let firstCategoryIcon = firstSubcategory?.safeCategory.iconName
        let uniqueCategoryCount = Set(subcategories.map { $0.safeCategory.persistentModelID }).count

        return calculateDisplayProperties(
            subcategoryCount: subcategoryCount,
            firstSubcategoryIcon: firstSubcategoryIcon,
            firstCategoryColor: firstCategoryColor,
            uniqueCategoryCount: uniqueCategoryCount,
            firstCategoryIcon: firstCategoryIcon
        )
    }

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
            return ("chart.pie.fill", "#6366F1") // Electric indigo
        }

        // Single subcategory: use subcategory icon/color
        if subcategoryCount == 1 {
            let icon = firstSubcategoryIcon ?? "tag.fill"
            let color = firstCategoryColor ?? "#6366F1"
            return (icon, color)
        }

        // Multiple subcategories: check if they're from the same category
        if uniqueCategoryCount == 1 {
            // All from same category: use category icon/color
            let icon = firstCategoryIcon ?? "tag.fill"
            let color = firstCategoryColor ?? "#6366F1"
            return (icon, color)
        } else {
            // Multiple categories: use app icon + electric indigo
            return ("chart.pie.fill", "#6366F1")
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

private extension Calendar {
    /// Get start of week for a given date (Monday as first day of week)
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    /// Get start of month for a given date
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
