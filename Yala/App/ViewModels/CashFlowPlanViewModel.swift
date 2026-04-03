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

    // Cash flow comment state
    private(set) var cashFlowComment: String?
    private(set) var isLoadingComment: Bool = false
    private var lastCommentProjectionHash: Int = 0
    private var lastCommentWasAI: Bool = false

    // Deviation comment state
    private(set) var deviationComment: String?
    private(set) var isLoadingDeviationComment: Bool = false
    private var lastDeviationKey: String = ""

    // UI state
    var selectedLine: CashFlowLine?
    var showLineConfig: Bool = false
    var showChartsSheet: Bool = false
    var showOthersBreakdown: Bool = false
    var showOthersIncomeBreakdown: Bool = false
    var showAddLine: Bool = false
    var addLineIsIncome: Bool = false
    var showEditStartingBalance: Bool = false

    // Month selection (strip + detail)
    var selectedMonthKey: String = CashFlowProjectionCalculator.monthKey(for: .now, calendar: .current)

    var selectedMonth: CashFlowMonth? {
        projection?.months.first { $0.monthKey == selectedMonthKey }
    }

    func line(for lineID: UUID) -> CashFlowLine? {
        plan?.lines?.first { $0.id == lineID }
    }

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
            isIncome: category.isIncome,
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

    func setOverrideAndUpdateFuture(line: CashFlowLine, monthKey: String, amount: Double, note: String) {
        setOverride(line: line, monthKey: monthKey, amount: amount, note: note)

        // Update line to manual estimation for all future months
        line.estimationMethod = EstimationMethod.manual.rawValue
        line.manualAmount = amount

        do {
            try modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error updating future estimation: \(error)")
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
        allIncomeCategories: [Category] = [],
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
            allIncomeCategories: allIncomeCategories,
            scheduledPayments: scheduledPayments,
            monthsBack: monthsBack,
            monthsAhead: monthsAhead,
            currencyCode: currencyCode,
            converter: converter
        )
    }

    // MARK: - Update Starting Balance

    func updateStartingBalance(_ newBalance: Double, date: Date? = nil) {
        guard let plan else { return }
        plan.startingBalance = newBalance
        plan.startingBalanceDate = date
        do {
            try plan.modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error updating starting balance: \(error)")
            #endif
        }
    }

    func updateHorizon(monthsAhead: Int, monthsBack: Int) {
        guard let plan else { return }
        plan.defaultMonthsAhead = monthsAhead
        plan.defaultMonthsBack = monthsBack
        do {
            try plan.modelContext?.save()
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error updating horizon: \(error)")
            #endif
        }
    }

    // MARK: - Reset

    func resetPlan() {
        guard let ctx = modelContext, let plan else { return }

        // .cascade deleteRule handles lines and overrides automatically
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

    // MARK: - Cash Flow Comment

    func loadCashFlowComment(currencyCode: String) async {
        guard let projection else { return }

        let hash = InsightsLLMService.projectionHash(projection)
        let needsReload = cashFlowComment == nil || hash != lastCommentProjectionHash || !lastCommentWasAI
        guard needsReload else { return }

        isLoadingComment = true
        do {
            cashFlowComment = try await InsightsLLMService.shared.generateCashFlowInsight(
                projection: projection,
                currencyCode: currencyCode
            )
            lastCommentWasAI = true
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: LLM error: \(error)")
            #endif
            cashFlowComment = nil
            lastCommentWasAI = false
        }
        isLoadingComment = false
        lastCommentProjectionHash = hash
    }

    func loadDeviationComment(
        deviations: [(name: String, planned: Double, actual: Double, excess: Double)],
        currencyCode: String
    ) async {
        let key = deviations.map(\.name).joined(separator: ",")
        guard !deviations.isEmpty, key != lastDeviationKey || deviationComment == nil else { return }

        isLoadingDeviationComment = true
        do {
            deviationComment = try await InsightsLLMService.shared.generateDeviationInsight(
                deviations: deviations,
                currencyCode: currencyCode
            )
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Deviation LLM error: \(error)")
            #endif
            deviationComment = nil
        }
        isLoadingDeviationComment = false
        lastDeviationKey = key
    }

    static func generateRuleBasedComment(_ projection: CashFlowProjection, currencyCode: String) -> String {
        let months = projection.months
        guard !months.isEmpty else { return "" }

        let negativeMonths = months.filter { $0.accumulatedBalance < 0 }
        let currentMonth = months.first(where: { $0.isCurrent })

        // Check for months going negative
        if let firstNegative = negativeMonths.first {
            let monthName = firstNegative.date.formatted(.dateTime.month(.wide)).lowercased()
            return L10n.CashFlowPlan.commentNegative(monthName)
        }

        // Current month tight (net < 10% of income)
        if let current = currentMonth, current.totalIncome > 0,
           current.netFlow < current.totalIncome * 0.1 {
            let margin = YalaFormatter.currency(value: current.netFlow, currencyCode: currencyCode)
            return L10n.CashFlowPlan.commentTight(margin)
        }

        // All positive — good health
        if negativeMonths.isEmpty, let lastMonth = months.last {
            let endBalance = YalaFormatter.currency(value: lastMonth.accumulatedBalance, currencyCode: currencyCode)
            return L10n.CashFlowPlan.commentHealthy(endBalance)
        }

        // Default
        return L10n.CashFlowPlan.commentDefault(months.count)
    }

    static func generateDeviationRuleComment(
        _ deviations: [(name: String, amount: Double)],
        currencyCode: String
    ) -> String {
        guard !deviations.isEmpty else { return "" }

        let top = deviations[0]
        let topFormatted = YalaFormatter.currency(value: top.amount, currencyCode: currencyCode)

        if deviations.count == 1 {
            return L10n.CashFlowPlan.deviationCommentSingle(top.name, topFormatted)
        }

        let totalExcess = deviations.reduce(0.0) { $0 + $1.amount }
        let totalFormatted = YalaFormatter.currency(value: totalExcess, currencyCode: currencyCode)
        return L10n.CashFlowPlan.deviationCommentMultiple(top.name, topFormatted, totalFormatted)
    }

    static func generateCombinedComment(
        _ projection: CashFlowProjection,
        savings: [(actual: Double, planned: Double)],
        currencyCode: String
    ) -> String {
        let months = projection.months
        guard !months.isEmpty else { return "" }

        let negativeMonths = months.filter { $0.accumulatedBalance < 0 }
        let currentMonth = months.first(where: { $0.isCurrent })
        let hasSavings = !savings.isEmpty
        let avgActual = hasSavings ? savings.map(\.actual).reduce(0, +) / Double(savings.count) : 0
        let avgPlanned = hasSavings ? savings.map(\.planned).reduce(0, +) / Double(savings.count) : 0

        // 1. Balance goes negative
        if let firstNegative = negativeMonths.first {
            let monthName = firstNegative.date.formatted(.dateTime.month(.wide)).lowercased()
            return L10n.CashFlowPlan.commentNegative(monthName)
        }

        // 2. Actual savings consistently below plan
        if hasSavings, avgPlanned > 0, avgActual < avgPlanned * 0.8 {
            let diff = YalaFormatter.currency(value: avgPlanned - avgActual, currencyCode: currencyCode)
            return L10n.CashFlowPlan.commentSavingsBelow(diff)
        }

        // 3. Current month tight (net < 10% of income)
        if let current = currentMonth, current.totalIncome > 0,
           current.netFlow < current.totalIncome * 0.1 {
            let margin = YalaFormatter.currency(value: current.netFlow, currencyCode: currencyCode)
            return L10n.CashFlowPlan.commentTight(margin)
        }

        // 4. Actual savings beat plan
        if hasSavings, avgActual >= avgPlanned, avgPlanned > 0, let lastMonth = months.last {
            let diff = YalaFormatter.currency(value: avgActual - avgPlanned, currencyCode: currencyCode)
            let endBalance = YalaFormatter.currency(value: lastMonth.accumulatedBalance, currencyCode: currencyCode)
            return L10n.CashFlowPlan.commentSavingsAbove(diff, endBalance)
        }

        // 5. Healthy plan
        if negativeMonths.isEmpty, let lastMonth = months.last {
            if hasSavings {
                let avgFormatted = YalaFormatter.currency(value: avgActual, currencyCode: currencyCode)
                let endBalance = YalaFormatter.currency(value: lastMonth.accumulatedBalance, currencyCode: currencyCode)
                return L10n.CashFlowPlan.commentHealthyWithSavings(avgFormatted, endBalance)
            }
            let endBalance = YalaFormatter.currency(value: lastMonth.accumulatedBalance, currencyCode: currencyCode)
            return L10n.CashFlowPlan.commentHealthy(endBalance)
        }

        // 6. Default
        return L10n.CashFlowPlan.commentDefault(months.count)
    }

}
