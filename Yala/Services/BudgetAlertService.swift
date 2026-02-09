//
//  BudgetAlertService.swift
//  Yala
//
//  Service for checking budgets and sending alerts when thresholds are crossed.
//

import Foundation
import SwiftData

/// Service for checking budgets and sending alerts when thresholds are crossed
@MainActor
@Observable
final class BudgetAlertService {
    static let shared = BudgetAlertService()

    private var modelContext: ModelContext?
    private var isChecking = false
    private let tracker = BudgetAlertTracker.shared

    private init() {}

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Main Check Method

    /// Check all budgets with alerts enabled and notify if thresholds crossed
    func checkBudgetsAndNotify() async {
        // Check global toggle first (default false, enabled via onboarding)
        let globalEnabled = UserDefaults.standard.bool(forKey: "budgetAlertsEnabled")
        guard globalEnabled else { return }

        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard let context = modelContext else { return }

        // 1. Fetch budgets with alerts enabled
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.isActive && $0.alertEnabled }
        )

        let budgets: [Budget]
        do {
            budgets = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BudgetAlertService: Error fetching budgets: \(error)")
            #endif
            return
        }

        guard !budgets.isEmpty else { return }

        // 2. Fetch all transactions
        let txDescriptor = FetchDescriptor<TransactionItem>()
        let transactions: [TransactionItem]
        do {
            transactions = try context.fetch(txDescriptor)
        } catch {
            #if DEBUG
            print("BudgetAlertService: Error fetching transactions: \(error)")
            #endif
            return
        }

        // 3. Check each budget
        for budget in budgets {
            await checkBudget(budget, transactions: transactions)
        }
    }

    // MARK: - Budget Check

    private func checkBudget(_ budget: Budget, transactions: [TransactionItem]) async {
        // Parse configured thresholds
        guard let thresholdsString = budget.alertThresholds else { return }
        let configuredThresholds = Set(
            thresholdsString.split(separator: ",").compactMap { Int($0) }
        )
        guard !configuredThresholds.isEmpty else { return }

        // Calculate spending
        let interval = getCurrentPeriodInterval(for: budget)
        let spending = calculateSpending(budget: budget, transactions: transactions, interval: interval)

        guard budget.limitAmount > 0 else { return }
        let percentage = (spending / budget.limitAmount) * 100.0

        // Get period key and check for new thresholds
        let periodKey = tracker.periodKey(for: budget)
        let newThresholds = tracker.getNewThresholds(
            budgetID: budget.id,
            periodKey: periodKey,
            currentPercentage: percentage,
            configuredThresholds: configuredThresholds
        )

        // Get currency for notification
        let currencyCode = budget.accounts?.first?.currencyCode
            ?? CurrencyDefaults.currentPreferred

        // Send notifications for new thresholds
        for threshold in newThresholds {
            await sendNotification(
                budgetName: budget.name,
                threshold: threshold,
                spent: spending,
                limit: budget.limitAmount,
                currencyCode: currencyCode
            )
            tracker.markNotified(budgetID: budget.id, periodKey: periodKey, threshold: threshold)
        }
    }

    // MARK: - Period Interval (uses current date, not ViewModel state)

    private func getCurrentPeriodInterval(for budget: Budget) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            let monthStart = calendar.startOfMonth(for: now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)
        }

        switch periodType {
        case .weekly:
            let weekStart = calendar.startOfWeek(for: now)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)
        case .monthly:
            let monthStart = calendar.startOfMonth(for: now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)
        case .yearly:
            let year = calendar.component(.year, from: now)
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)
        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                let monthStart = calendar.startOfMonth(for: now)
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                return DateInterval(start: monthStart, end: monthEnd)
            }
            return DateInterval(start: start, end: end)
        }
    }

    // MARK: - Spending Calculation (copied from BudgetsViewModel)

    private func calculateSpending(
        budget: Budget,
        transactions: [TransactionItem],
        interval: DateInterval
    ) -> Double {
        var filtered = transactions.filter { interval.contains($0.date) }

        // Account filter
        if let accounts = budget.accounts, !accounts.isEmpty {
            let accountIDs = Set(accounts.map { $0.persistentModelID })
            filtered = filtered.filter { tx in
                tx.account.map { accountIDs.contains($0.persistentModelID) } ?? false
            }
        }

        // Subcategory filter
        if let subcategories = budget.subcategories, !subcategories.isEmpty {
            let subIDs = Set(subcategories.map { $0.persistentModelID })
            filtered = filtered.filter { tx in
                tx.subcategory.map { subIDs.contains($0.persistentModelID) } ?? false
            }
        }

        // Tag filter
        if let budgetTags = budget.tags, !budgetTags.isEmpty {
            let tagIDs = Set(budgetTags.map { $0.persistentModelID })
            filtered = filtered.filter { tx in
                !Set((tx.tags ?? []).map { $0.persistentModelID }).isDisjoint(with: tagIDs)
            }
        }

        // Nature filter
        if let naturesString = budget.natures, !naturesString.isEmpty {
            let natures = naturesString.split(separator: ",")
                .compactMap { SubcategoryNature(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }
            filtered = filtered.filter { natures.contains($0.effectiveNature) }
        }

        // Only expenses
        filtered = filtered.filter { $0.category?.isIncome == false }

        // Sum amounts
        let useBudgetCurrency = (budget.accounts?.count ?? 0) == 1
        return filtered.reduce(0.0) { sum, tx in
            let amount = useBudgetCurrency ? tx.amount : tx.amountInPreferredCurrency
            return sum + abs(amount)
        }
    }

    // MARK: - Notifications

    private func sendNotification(
        budgetName: String,
        threshold: Int,
        spent: Double,
        limit: Double,
        currencyCode: String
    ) async {
        let symbol = CurrencyUtils.symbol(for: currencyCode)
        let spentStr = "\(symbol)\(spent.formatted(.number.precision(.fractionLength(0...2))))"
        let limitStr = "\(symbol)\(limit.formatted(.number.precision(.fractionLength(0...2))))"

        let message: String
        switch threshold {
        case 50: message = L10n.Budgets.alertMessage50(budgetName, spentStr, limitStr)
        case 75: message = L10n.Budgets.alertMessage75(budgetName, spentStr, limitStr)
        case 90: message = L10n.Budgets.alertMessage90(budgetName, spentStr, limitStr)
        case 100: message = L10n.Budgets.alertMessage100(budgetName, spentStr, limitStr)
        default: message = "\(budgetName): \(threshold)%"
        }

        await NotificationService.shared.sendNotification(
            title: budgetName,
            body: message,
            deepLink: "budgets"
        )
    }
}

// MARK: - Calendar Extensions

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
