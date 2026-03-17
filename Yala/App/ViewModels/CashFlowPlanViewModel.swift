//
//  CashFlowPlanViewModel.swift
//  Yala
//
//  ViewModel for cash flow plan management: setup, CRUD, projection.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Suggested Line

struct SuggestedLine: Identifiable {
    let id = UUID()
    let category: Category?
    let scheduledPayment: ScheduledPayment?
    let name: String
    let isIncome: Bool
    let suggestedAmount: Double
    let estimationMethod: EstimationMethod
    let monthsWithActivity: Int
    let isRecommended: Bool
    var isSelected: Bool
}

// MARK: - ViewModel

@MainActor @Observable
final class CashFlowPlanViewModel {
    private var modelContext: ModelContext?

    // State
    private(set) var plan: CashFlowPlan?
    var hasPlan: Bool { plan != nil }
    private(set) var projection: CashFlowProjection?
    var suggestedLines: [SuggestedLine] = []
    private(set) var isLoading: Bool = false

    // UI state
    var selectedLine: CashFlowLine?
    var showLineConfig: Bool = false
    var showChartsSheet: Bool = false
    var showOthersBreakdown: Bool = false
    var showAddLine: Bool = false

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
        loadPlan()
    }

    func loadPlan() {
        guard let ctx = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<CashFlowPlan>()
            descriptor.fetchLimit = 1
            let plans = try ctx.fetch(descriptor)
            plan = plans.first
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error loading plan: \(error)")
            #endif
        }
    }

    // MARK: - Setup Suggestions

    func generateSuggestions(
        transactions: [TransactionItem],
        scheduledPayments: [ScheduledPayment],
        categories: [Category]
    ) {
        let calendar = Calendar.current
        let now = Date.now
        let components = calendar.dateComponents([.year, .month], from: now)
        let currentMonthStart = calendar.date(from: components)!

        // Analyze last 6 months of transactions
        var categoryActivity: [PersistentIdentifier: (months: Set<String>, totalAmount: Double, name: String, isIncome: Bool, category: Category)] = [:]

        for tx in transactions {
            guard let category = tx.category, tx.balanceAdjustmentType == nil else { continue }
            let monthKey = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)
            let txMonthStart = calendar.dateComponents([.year, .month], from: tx.date)
            guard let txDate = calendar.date(from: txMonthStart) else { continue }

            // Only consider last 6 months
            let monthDiff = calendar.dateComponents([.month], from: txDate, to: currentMonthStart).month ?? 0
            guard monthDiff >= 0 && monthDiff < 6 else { continue }

            let id = category.persistentModelID
            var entry = categoryActivity[id] ?? (
                months: Set<String>(), totalAmount: 0,
                name: category.name, isIncome: category.isIncome, category: category
            )
            entry.months.insert(monthKey)
            entry.totalAmount += abs(tx.amount)
            categoryActivity[id] = entry
        }

        var suggestions: [SuggestedLine] = []

        // Category-based suggestions
        for (_, activity) in categoryActivity {
            let monthCount = activity.months.count
            guard monthCount >= 2 else { continue } // Skip 1-month categories

            let avgAmount = activity.totalAmount / Double(monthCount)
            let isRecommended = monthCount >= 4

            suggestions.append(SuggestedLine(
                category: activity.category,
                scheduledPayment: nil,
                name: activity.name,
                isIncome: activity.isIncome,
                suggestedAmount: avgAmount,
                estimationMethod: .average6m,
                monthsWithActivity: monthCount,
                isRecommended: isRecommended,
                isSelected: isRecommended
            ))
        }

        // ScheduledPayment-based suggestions (always recommended)
        let existingCategoryIDs = Set(suggestions.compactMap { $0.category?.persistentModelID })
        for payment in scheduledPayments where payment.isActive {
            // Skip if already covered by a category suggestion linked to same subcategory parent
            if let sub = payment.subcategory, let parentCat = sub.category,
               existingCategoryIDs.contains(parentCat.persistentModelID) {
                continue
            }

            suggestions.append(SuggestedLine(
                category: payment.subcategory?.category,
                scheduledPayment: payment,
                name: payment.name,
                isIncome: payment.transactionType == "income",
                suggestedAmount: abs(payment.amount),
                estimationMethod: .scheduled,
                monthsWithActivity: 6,
                isRecommended: true,
                isSelected: true
            ))
        }

        // Sort: income first, then by amount descending
        suggestions.sort { a, b in
            if a.isIncome != b.isIncome { return a.isIncome }
            return a.suggestedAmount > b.suggestedAmount
        }

        suggestedLines = suggestions
    }

    // MARK: - Create Plan

    func createPlan(startingBalance: Double) {
        guard let ctx = modelContext else { return }

        let newPlan = CashFlowPlan(name: "", startingBalance: startingBalance)
        ctx.insert(newPlan)

        let selectedSuggestions = suggestedLines.filter(\.isSelected)
        for (index, suggestion) in selectedSuggestions.enumerated() {
            let method = suggestion.estimationMethod
            let line = CashFlowLine(
                name: suggestion.name,
                isIncome: suggestion.isIncome,
                sortOrder: index,
                estimationMethod: method,
                manualAmount: method == .manual ? suggestion.suggestedAmount : nil,
                category: suggestion.category,
                scheduledPayment: suggestion.scheduledPayment
            )
            ctx.insert(line)
            line.plan = newPlan
        }

        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error creating plan: \(error)")
            #endif
        }

        plan = newPlan
    }

    // MARK: - CRUD

    func addLine(_ line: CashFlowLine) {
        guard let ctx = modelContext, let plan else { return }
        ctx.insert(line)
        line.plan = plan
        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error adding line: \(error)")
            #endif
        }
    }

    func removeLine(_ line: CashFlowLine) {
        guard let ctx = modelContext else { return }
        ctx.delete(line)
        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error removing line: \(error)")
            #endif
        }
    }

    func reorderLines(_ offsets: IndexSet, to destination: Int) {
        guard let plan, var lines = plan.lines else { return }
        lines.sort { $0.sortOrder < $1.sortOrder }
        lines.move(fromOffsets: offsets, toOffset: destination)
        for (index, line) in lines.enumerated() {
            line.sortOrder = index
        }
        do {
            try modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error reordering: \(error)")
            #endif
        }
    }

    func promoteFromOthers(_ category: Category) {
        guard let plan else { return }
        let maxOrder = (plan.lines ?? []).map(\.sortOrder).max() ?? 0
        let line = CashFlowLine(
            name: category.name,
            isIncome: false,
            sortOrder: maxOrder + 1,
            estimationMethod: .average6m,
            category: category
        )
        addLine(line)
    }

    // MARK: - Overrides

    func setOverride(line: CashFlowLine, monthKey: String, amount: Double, note: String) {
        guard let ctx = modelContext else { return }

        // Remove existing override for same monthKey
        if let existing = line.overrides?.first(where: { $0.monthKey == monthKey }) {
            ctx.delete(existing)
        }

        let override = CashFlowOverride(monthKey: monthKey, amount: amount, note: note)
        ctx.insert(override)
        override.line = line

        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error setting override: \(error)")
            #endif
        }
    }

    func removeOverride(line: CashFlowLine, monthKey: String) {
        guard let ctx = modelContext else { return }
        if let existing = line.overrides?.first(where: { $0.monthKey == monthKey }) {
            ctx.delete(existing)
            do {
                try ctx.save()
            } catch {
                #if DEBUG
                print("CashFlowPlanViewModel: Error removing override: \(error)")
                #endif
            }
        }
    }

    // MARK: - Recalculate

    func recalculate(
        transactions: [TransactionItem],
        allExpenseCategories: [Category],
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) {
        guard let plan else {
            projection = nil
            return
        }

        let lines = (plan.lines ?? []).filter(\.isEnabled)

        let monthsAhead: Int
        if FeatureGateService.shared.canAccess(.cashFlowAdvanced) {
            monthsAhead = plan.defaultMonthsAhead
        } else {
            monthsAhead = min(3, plan.defaultMonthsAhead)
        }

        let monthsBack: Int
        if FeatureGateService.shared.canAccess(.cashFlowAdvanced) {
            monthsBack = plan.defaultMonthsBack
        } else {
            monthsBack = 0 // Free: only current month
        }

        projection = CashFlowProjectionCalculator.calculate(
            plan: plan,
            lines: lines,
            transactions: transactions,
            allExpenseCategories: allExpenseCategories,
            scheduledPayments: scheduledPayments,
            monthsBack: monthsBack,
            monthsAhead: monthsAhead,
            currencyCode: currencyCode,
            converter: converter
        )
    }

    // MARK: - Reset

    func resetPlan() {
        guard let ctx = modelContext, let plan else { return }

        // Delete all lines and overrides
        if let lines = plan.lines {
            for line in lines {
                if let overrides = line.overrides {
                    for override in overrides {
                        ctx.delete(override)
                    }
                }
                ctx.delete(line)
            }
        }
        ctx.delete(plan)

        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error resetting plan: \(error)")
            #endif
        }

        self.plan = nil
        projection = nil
    }

    // MARK: - New Scheduled Payment Detection

    func checkNewScheduledPayments(payments: [ScheduledPayment]) -> [ScheduledPayment] {
        guard let plan else { return [] }
        let linkedPaymentIDs = Set(
            (plan.lines ?? []).compactMap { $0.scheduledPayment?.persistentModelID }
        )
        return payments.filter { payment in
            payment.isActive && !linkedPaymentIDs.contains(payment.persistentModelID)
        }
    }
}
