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
    let subcategory: Subcategory?
    let scheduledPayment: ScheduledPayment?
    let name: String
    let isIncome: Bool
    var suggestedAmount: Double
    var estimationMethod: EstimationMethod
    let monthsWithActivity: Int
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
    var addLineIsIncome: Bool = false
    var showEditStartingBalance: Bool = false

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

    /// Cached index for recalculating estimation methods without re-fetching
    private var cachedIndex: TransactionIndex?
    private var cachedReferenceDate: Date?
    private var cachedCurrencyCode: String?

    func generateSuggestions(
        transactions: [TransactionItem],
        scheduledPayments: [ScheduledPayment],
        categories: [Category],
        currencyCode: String = ""
    ) {
        let calendar = Calendar.current
        let now = Date.now
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let currentMonthStart = calendar.date(from: components) else { return }

        // Build and cache TransactionIndex for method recalculation
        let validTransactions = transactions.filter { $0.category != nil && $0.balanceAdjustmentType == nil }
        let resolvedCurrency = currencyCode.isEmpty ? "USD" : currencyCode
        let index = TransactionIndex(
            transactions: validTransactions, currencyCode: resolvedCurrency,
            converter: CurrencyConverter.shared, calendar: calendar
        )
        cachedIndex = index
        cachedReferenceDate = currentMonthStart
        cachedCurrencyCode = resolvedCurrency

        // Group key: subcategory ID if available, otherwise category ID
        struct ActivityKey: Hashable {
            let subcategoryID: PersistentIdentifier?
            let categoryID: PersistentIdentifier?
        }

        var activity: [ActivityKey: (months: Set<String>, name: String, isIncome: Bool, category: Category, subcategory: Subcategory?)] = [:]

        for tx in validTransactions {
            guard let category = tx.category else { continue }
            let txMonthStart = calendar.dateComponents([.year, .month], from: tx.date)
            guard let txDate = calendar.date(from: txMonthStart) else { continue }

            let monthDiff = calendar.dateComponents([.month], from: txDate, to: currentMonthStart).month ?? 0
            guard monthDiff >= 0 && monthDiff < 6 else { continue }

            let monthKey = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)

            let key: ActivityKey
            let displayName: String
            let subcategory: Subcategory?

            if let sub = tx.subcategory {
                key = ActivityKey(subcategoryID: sub.persistentModelID, categoryID: category.persistentModelID)
                displayName = sub.name
                subcategory = sub
            } else {
                key = ActivityKey(subcategoryID: nil, categoryID: category.persistentModelID)
                displayName = category.name
                subcategory = nil
            }

            var entry = activity[key] ?? (
                months: Set<String>(),
                name: displayName, isIncome: category.isIncome,
                category: category, subcategory: subcategory
            )
            entry.months.insert(monthKey)
            activity[key] = entry
        }

        var suggestions: [SuggestedLine] = []

        for (_, entry) in activity {
            let monthCount = entry.months.count
            guard monthCount >= 2 else { continue }

            // Calculate amount using the real calculator (converted currency, same logic as projection)
            let tempLine = CashFlowLine(
                name: entry.name,
                isIncome: entry.isIncome,
                estimationMethod: .average6m,
                category: entry.category,
                subcategory: entry.subcategory
            )
            let calculatedAmount = CashFlowProjectionCalculator.estimateAverage(
                months: 6, line: tempLine, referenceDate: currentMonthStart,
                index: index, calendar: calendar
            )

            suggestions.append(SuggestedLine(
                category: entry.category,
                subcategory: entry.subcategory,
                scheduledPayment: nil,
                name: entry.name,
                isIncome: entry.isIncome,
                suggestedAmount: calculatedAmount,
                estimationMethod: .average6m,
                monthsWithActivity: monthCount,
                isSelected: monthCount >= 4
            ))
        }

        // ScheduledPayment-based suggestions
        let existingSubKeys = Set(suggestions.compactMap { $0.subcategory?.persistentModelID })
        let existingCatKeys = Set(suggestions.compactMap { $0.category?.persistentModelID })

        for payment in scheduledPayments where payment.isActive {
            let paymentSubKey = payment.subcategory?.persistentModelID
            let paymentCatKey = payment.subcategory?.category?.persistentModelID

            // Skip if subcategory or category already covered by transaction-based suggestions
            if let subKey = paymentSubKey, existingSubKeys.contains(subKey) { continue }
            if let catKey = paymentCatKey, existingCatKeys.contains(catKey) { continue }

            suggestions.append(SuggestedLine(
                category: payment.subcategory?.category,
                subcategory: payment.subcategory,
                scheduledPayment: payment,
                name: payment.name,
                isIncome: payment.transactionType == "income",
                suggestedAmount: abs(payment.amount),
                estimationMethod: .scheduled,
                monthsWithActivity: 6,
                isSelected: true
            ))
        }

        suggestions.sort { a, b in
            if a.isIncome != b.isIncome { return a.isIncome }
            return a.suggestedAmount > b.suggestedAmount
        }

        suggestedLines = suggestions
    }

    // MARK: - Select All

    func selectAllSuggestedLines() {
        for index in suggestedLines.indices {
            suggestedLines[index].isSelected = true
        }
    }

    // MARK: - Update Estimation Method

    func updateEstimationMethod(for lineID: UUID, to method: EstimationMethod, manualAmount: Double? = nil) {
        guard let idx = suggestedLines.firstIndex(where: { $0.id == lineID }) else { return }
        suggestedLines[idx].estimationMethod = method
        suggestedLines[idx].suggestedAmount = calculateAmount(
            for: suggestedLines[idx], method: method, manualAmount: manualAmount
        )
    }

    /// Preview amount for a method without mutating state
    func previewAmount(for line: SuggestedLine, method: EstimationMethod, manualAmount: Double? = nil) -> Double {
        calculateAmount(for: line, method: method, manualAmount: manualAmount)
    }

    private func calculateAmount(for line: SuggestedLine, method: EstimationMethod, manualAmount: Double? = nil) -> Double {
        if method == .manual {
            return manualAmount ?? line.suggestedAmount
        }
        if method == .scheduled, let payment = line.scheduledPayment {
            return abs(payment.amount)
        }
        guard let index = cachedIndex, let refDate = cachedReferenceDate else {
            return line.suggestedAmount
        }
        let calendar = Calendar.current
        let tempLine = CashFlowLine(
            name: line.name,
            isIncome: line.isIncome,
            estimationMethod: method,
            category: line.category,
            subcategory: line.subcategory
        )
        switch method {
        case .average3m:
            return CashFlowProjectionCalculator.estimateAverage(months: 3, line: tempLine, referenceDate: refDate, index: index, calendar: calendar)
        case .average6m:
            return CashFlowProjectionCalculator.estimateAverage(months: 6, line: tempLine, referenceDate: refDate, index: index, calendar: calendar)
        case .average12m:
            return CashFlowProjectionCalculator.estimateAverage(months: 12, line: tempLine, referenceDate: refDate, index: index, calendar: calendar)
        case .lastMonth:
            return CashFlowProjectionCalculator.estimateLastMonth(line: tempLine, referenceDate: refDate, index: index, calendar: calendar)
        case .trend:
            return CashFlowProjectionCalculator.estimateTrend(line: tempLine, referenceDate: refDate, index: index, calendar: calendar)
        default:
            return line.suggestedAmount
        }
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
                subcategory: suggestion.subcategory,
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
        converter: CurrencyConverting
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

    // MARK: - Update Starting Balance

    func updateStartingBalance(_ newBalance: Double) {
        guard let plan else { return }
        plan.startingBalance = newBalance
        do {
            try plan.modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error updating starting balance: \(error)")
            #endif
        }
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
