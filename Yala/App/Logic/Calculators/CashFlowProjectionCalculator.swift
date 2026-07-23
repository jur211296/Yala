//
//  CashFlowProjectionCalculator.swift
//  Yala
//
//  Calculates cash flow projections: planned vs real amounts per line per month.
//

import Foundation
import SwiftData

// MARK: - Output Structs

struct CashFlowProjection {
    let months: [CashFlowMonth]
    let startingBalance: Double
    let totalProjectedIncome: Double
    let totalProjectedExpense: Double
    let totalProjectedNet: Double
}

struct CashFlowMonth {
    let monthKey: String                     // "2026-04"
    let date: Date
    let isPast: Bool
    let isCurrent: Bool
    let incomeLines: [CashFlowLineResult]
    let expenseLines: [CashFlowLineResult]
    let otherExpenses: CashFlowOtherResult?
    let otherIncome: CashFlowOtherResult?
    let totalIncome: Double
    let totalExpense: Double                 // Positive magnitude
    let netFlow: Double                      // income - expense
    let accumulatedBalance: Double?           // nil for months before startingBalanceDate
}

struct CashFlowLineResult {
    let lineID: UUID
    let name: String
    let isIncome: Bool
    let plannedAmount: Double
    let realAmount: Double?
    let difference: Double?
    let differencePercent: Double?
    let progress: Double?
    let isOverride: Bool
    let estimationMethod: EstimationMethod
    let subcategoryBreakdown: [SubcategoryLineResult]?
}

struct CashFlowOtherResult {
    let plannedAmount: Double
    let realAmount: Double?
    let categoryBreakdown: [OtherCategoryItem]
}

struct OtherCategoryItem {
    let categoryName: String
    let iconName: String
    let colorHex: String
    let amount: Double
}

struct SubcategoryLineResult {
    let subcategoryName: String
    let plannedAmount: Double
    let realAmount: Double?
}

// MARK: - Pre-grouped Transaction Index

/// O(1) lookup of pre-converted transaction totals by (category, month).
struct TransactionIndex {
    /// Totals by category persistentModelID → monthKey → magnitude sum
    let byCategoryMonth: [PersistentIdentifier: [String: Double]]
    /// Totals by subcategory persistentModelID → monthKey → magnitude sum
    let bySubcategoryMonth: [PersistentIdentifier: [String: Double]]

    init(transactions: [TransactionItem], currencyCode: String, adjustment: GroupBridgeStatsAdjustment = .none, converter: CurrencyConverting, calendar: Calendar) {
        var catMonth: [PersistentIdentifier: [String: Double]] = [:]
        var subMonth: [PersistentIdentifier: [String: Double]] = [:]

        for tx in transactions {
            guard let catID = tx.category?.persistentModelID else { continue }
            // Suprime la pata de préstamo derivada (bridge): no es gasto/ingreso propio.
            if adjustment.isSuppressed(tx) { continue }
            let key = CashFlowProjectionCalculator.monthKey(for: tx.date, calendar: calendar)

            // `adjustment` proyecta el gasto de grupo Caso A a "mi parte" (neto).
            let magnitude: Double
            if tx.preferredCurrencyCode == currencyCode {
                magnitude = abs(adjustment.amountInPreferredCurrency(tx))
            } else {
                let decimalAmt = Decimal(abs(adjustment.amount(tx)))
                let converted = converter.convert(decimalAmt, from: tx.currencyCode, to: currencyCode, on: tx.date)
                magnitude = NSDecimalNumber(decimal: converted).doubleValue
            }

            catMonth[catID, default: [:]][key, default: 0] += magnitude

            if let subID = tx.subcategory?.persistentModelID {
                subMonth[subID, default: [:]][key, default: 0] += magnitude
            }
        }

        self.byCategoryMonth = catMonth
        self.bySubcategoryMonth = subMonth
    }

    func total(for categoryID: PersistentIdentifier, monthKey: String) -> Double {
        byCategoryMonth[categoryID]?[monthKey] ?? 0
    }

    func subcategoryTotal(for subcategoryID: PersistentIdentifier, monthKey: String) -> Double {
        bySubcategoryMonth[subcategoryID]?[monthKey] ?? 0
    }

    func monthKeys(for categoryID: PersistentIdentifier) -> [String: Double] {
        byCategoryMonth[categoryID] ?? [:]
    }
}

// MARK: - Calculator

struct CashFlowProjectionCalculator {

    private static let customMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static func calculate(
        plan: CashFlowPlan,
        lines: [CashFlowLine],
        transactions: [TransactionItem],
        allExpenseCategories: [Category],
        allIncomeCategories: [Category] = [],
        scheduledPayments: [ScheduledPayment],
        monthsBack: Int,
        monthsAhead: Int,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> CashFlowProjection {
        let calendar = Calendar.current
        let now = Date.now
        let currentComponents = calendar.dateComponents([.year, .month], from: now)
        guard let currentMonthStart = calendar.date(from: currentComponents) else {
            return CashFlowProjection(months: [], startingBalance: plan.startingBalance,
                                       totalProjectedIncome: 0, totalProjectedExpense: 0, totalProjectedNet: 0)
        }

        // Generate month range
        let months = generateMonthRange(
            from: currentMonthStart, monthsBack: monthsBack, monthsAhead: monthsAhead, calendar: calendar
        )

        // Filter valid transactions and build index (single O(n) pass)
        let validTransactions = transactions.filter { tx in
            tx.category != nil && tx.balanceAdjustmentType == nil
        }
        let index = TransactionIndex(
            transactions: validTransactions, currencyCode: currencyCode,
            adjustment: adjustment, converter: converter, calendar: calendar
        )

        // Assigned IDs for "other" calculations — subcategory-level tracking
        let (assignedExpenseSubcategoryIDs, fullyAssignedExpenseCategoryIDs) = buildAssignedIDs(lines: lines, isIncome: false)
        let (assignedIncomeSubcategoryIDs, fullyAssignedIncomeCategoryIDs) = buildAssignedIDs(lines: lines, isIncome: true)

        let currentMKey = Self.monthKey(for: currentMonthStart, calendar: calendar)
        let incomeLines = sortLinesByAmountGrouped(
            lines.filter { $0.isEnabled && $0.isIncome },
            monthKey: currentMKey, monthDate: currentMonthStart, index: index, calendar: calendar
        )
        let expenseLines = sortLinesByAmountGrouped(
            lines.filter { $0.isEnabled && !$0.isIncome },
            monthKey: currentMKey, monthDate: currentMonthStart, index: index, calendar: calendar
        )

        // Resolve starting balance month (nil defaults to current month)
        let startingBalanceMonthKey: String
        if let balanceDate = plan.startingBalanceDate {
            startingBalanceMonthKey = Self.monthKey(for: balanceDate, calendar: calendar)
        } else {
            startingBalanceMonthKey = currentMKey
        }

        let firstMonthKey = Self.monthKey(for: months[0], calendar: calendar)
        let seedImmediately = startingBalanceMonthKey <= firstMonthKey

        var accumulatedBalance: Double = seedImmediately ? plan.startingBalance : 0
        var hasAppliedStartingBalance = seedImmediately
        var projectedMonths: [CashFlowMonth] = []
        var totalProjectedIncome: Double = 0
        var totalProjectedExpense: Double = 0

        for monthDate in months {
            let mKey = Self.monthKey(for: monthDate, calendar: calendar)
            let isPast = monthDate < currentMonthStart
            let isCurrent = calendar.isDate(monthDate, equalTo: currentMonthStart, toGranularity: .month)

            let incomeResults = incomeLines.map { line in
                calculateLineResult(
                    line: line, monthDate: monthDate, monthKey: mKey,
                    isPast: isPast, isCurrent: isCurrent,
                    index: index, calendar: calendar
                )
            }

            let expenseResults = expenseLines.map { line in
                calculateLineResult(
                    line: line, monthDate: monthDate, monthKey: mKey,
                    isPast: isPast, isCurrent: isCurrent,
                    index: index, calendar: calendar
                )
            }

            let otherExpenses: CashFlowOtherResult?
            let otherIncome: CashFlowOtherResult?
            if plan.showOtherExpenses && (isPast || isCurrent) {
                otherExpenses = calculateUncategorizedTotal(
                    categories: allExpenseCategories,
                    fullyAssignedCategoryIDs: fullyAssignedExpenseCategoryIDs,
                    assignedSubcategoryIDs: assignedExpenseSubcategoryIDs,
                    monthKey: mKey, index: index
                )
                otherIncome = calculateUncategorizedTotal(
                    categories: allIncomeCategories,
                    fullyAssignedCategoryIDs: fullyAssignedIncomeCategoryIDs,
                    assignedSubcategoryIDs: assignedIncomeSubcategoryIDs,
                    monthKey: mKey, index: index
                )
            } else {
                otherExpenses = nil
                otherIncome = nil
            }

            let totalIncome = incomeResults.reduce(0.0) { $0 + $1.plannedAmount }
                + (otherIncome?.plannedAmount ?? 0)
            let totalExpense = expenseResults.reduce(0.0) { $0 + $1.plannedAmount }
                + (otherExpenses?.plannedAmount ?? 0)
            let netFlow = totalIncome - totalExpense

            let monthBalance: Double?
            if !hasAppliedStartingBalance && mKey >= startingBalanceMonthKey {
                accumulatedBalance = plan.startingBalance
                hasAppliedStartingBalance = true
                accumulatedBalance += netFlow
                monthBalance = accumulatedBalance
            } else if hasAppliedStartingBalance {
                accumulatedBalance += netFlow
                monthBalance = accumulatedBalance
            } else {
                monthBalance = nil
            }
            totalProjectedIncome += totalIncome
            totalProjectedExpense += totalExpense

            projectedMonths.append(CashFlowMonth(
                monthKey: mKey, date: monthDate, isPast: isPast, isCurrent: isCurrent,
                incomeLines: incomeResults, expenseLines: expenseResults,
                otherExpenses: otherExpenses, otherIncome: otherIncome,
                totalIncome: totalIncome, totalExpense: totalExpense,
                netFlow: netFlow, accumulatedBalance: monthBalance
            ))
        }

        return CashFlowProjection(
            months: projectedMonths, startingBalance: plan.startingBalance,
            totalProjectedIncome: totalProjectedIncome,
            totalProjectedExpense: totalProjectedExpense,
            totalProjectedNet: totalProjectedIncome - totalProjectedExpense
        )
    }

    // MARK: - Month Range

    static func generateMonthRange(
        from currentMonth: Date, monthsBack: Int, monthsAhead: Int, calendar: Calendar
    ) -> [Date] {
        (-monthsBack...monthsAhead).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonth)
        }
    }

    static func monthKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    // MARK: - Line Result

    private static func calculateLineResult(
        line: CashFlowLine,
        monthDate: Date, monthKey: String,
        isPast: Bool, isCurrent: Bool,
        index: TransactionIndex,
        calendar: Calendar
    ) -> CashFlowLineResult {

        let override = line.overrides?.first { $0.monthKey == monthKey }
        let isOverride = override != nil

        let plannedAmount: Double
        if let override {
            plannedAmount = override.amount
        } else {
            plannedAmount = estimatePlannedAmount(
                line: line, monthDate: monthDate, index: index, calendar: calendar
            )
        }

        let realAmount: Double?
        if isPast || isCurrent, (line.subcategory != nil || line.category != nil) {
            realAmount = lookupTotal(line: line, index: index, monthKey: monthKey)
        } else {
            realAmount = nil
        }

        let difference: Double?
        let differencePercent: Double?
        if let realAmount {
            difference = realAmount - plannedAmount
            differencePercent = plannedAmount != 0 ? (realAmount - plannedAmount) / plannedAmount : nil
        } else {
            difference = nil
            differencePercent = nil
        }

        let progress: Double?
        if isCurrent, let realAmount, plannedAmount > 0 {
            progress = realAmount / plannedAmount
        } else {
            progress = nil
        }

        let subcategoryBreakdown: [SubcategoryLineResult]?
        if line.isExpanded, let category = line.category,
           let subcategories = category.subcategories, !subcategories.isEmpty {
            subcategoryBreakdown = subcategories
                .filter { $0.isVisible }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { sub in
                    let subReal: Double?
                    if isPast || isCurrent {
                        subReal = index.subcategoryTotal(for: sub.persistentModelID, monthKey: monthKey)
                    } else {
                        subReal = nil
                    }
                    return SubcategoryLineResult(
                        subcategoryName: sub.name, plannedAmount: 0, realAmount: subReal
                    )
                }
        } else {
            subcategoryBreakdown = nil
        }

        return CashFlowLineResult(
            lineID: line.id, name: line.name, isIncome: line.isIncome,
            plannedAmount: plannedAmount, realAmount: realAmount,
            difference: difference, differencePercent: differencePercent,
            progress: progress, isOverride: isOverride,
            estimationMethod: line.method,
            subcategoryBreakdown: subcategoryBreakdown
        )
    }

    // MARK: - Lookup (subcategory → category fallback)

    static func lookupTotal(line: CashFlowLine, index: TransactionIndex, monthKey: String) -> Double {
        if let subID = line.subcategory?.persistentModelID {
            return index.subcategoryTotal(for: subID, monthKey: monthKey)
        } else if let catID = line.category?.persistentModelID {
            return index.total(for: catID, monthKey: monthKey)
        }
        return 0
    }

    // MARK: - Estimation Methods

    private static func estimatePlannedAmount(
        line: CashFlowLine, monthDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        switch line.method {
        case .average3m:
            return estimateAverage(months: 3, line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .average6m:
            return estimateAverage(months: 6, line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .average12m:
            return estimateAverage(months: 12, line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .lastMonth:
            return estimateLastMonth(line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .manual:
            return line.manualAmount ?? 0
        case .scheduled:
            if let payment = line.scheduledPayment {
                return estimateScheduled(payment: payment, monthDate: monthDate, calendar: calendar)
            }
            return line.manualAmount ?? 0
        case .trend:
            return estimateTrend(line: line, referenceDate: monthDate, index: index, calendar: calendar)
        case .custom:
            return estimateCustom(customMonths: line.customMonths, line: line, index: index, calendar: calendar)
        }
    }

    // MARK: - Average Estimation

    static func estimateAverage(
        months: Int, line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard line.subcategory != nil || line.category != nil else { return 0 }

        var total: Double = 0
        var monthCount = 0

        for offset in 1...months {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let key = Self.monthKey(for: monthStart, calendar: calendar)
            let amount = lookupTotal(line: line, index: index, monthKey: key)
            if amount > 0 {
                total += amount
                monthCount += 1
            }
        }

        return monthCount > 0 ? total / Double(monthCount) : 0
    }

    /// Category-based average (used by calculateOtherExpenses)
    static func estimateAverage(
        months: Int, category: Category?, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard let catID = category?.persistentModelID else { return 0 }

        var total: Double = 0
        var monthCount = 0

        for offset in 1...months {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let key = Self.monthKey(for: monthStart, calendar: calendar)
            let amount = index.total(for: catID, monthKey: key)
            if amount > 0 {
                total += amount
                monthCount += 1
            }
        }

        return monthCount > 0 ? total / Double(monthCount) : 0
    }

    // MARK: - Last Month Estimation

    static func estimateLastMonth(
        line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard line.subcategory != nil || line.category != nil else { return 0 }
        guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: referenceDate) else { return 0 }
        let key = Self.monthKey(for: lastMonthDate, calendar: calendar)
        return lookupTotal(line: line, index: index, monthKey: key)
    }

    // MARK: - Scheduled Estimation

    static func estimateScheduled(
        payment: ScheduledPayment, monthDate: Date, calendar: Calendar
    ) -> Double {
        let params = payment.dateCalculatorParams
        let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
            params: params, month: monthDate, calendar: calendar
        )
        return abs(payment.amount) * Double(dates.count)
    }

    // MARK: - Trend Estimation (Linear Regression)

    static func estimateTrend(
        line: CashFlowLine, referenceDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard line.subcategory != nil || line.category != nil else { return 0 }

        var dataPoints: [(x: Double, y: Double)] = []
        for offset in (1...6).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let key = Self.monthKey(for: monthStart, calendar: calendar)
            let amount = lookupTotal(line: line, index: index, monthKey: key)
            dataPoints.append((x: Double(6 - offset), y: amount))
        }

        guard dataPoints.count >= 2 else { return 0 }

        let n = Double(dataPoints.count)
        let sumX = dataPoints.reduce(0.0) { $0 + $1.x }
        let sumY = dataPoints.reduce(0.0) { $0 + $1.y }
        let sumXY = dataPoints.reduce(0.0) { $0 + $1.x * $1.y }
        let sumX2 = dataPoints.reduce(0.0) { $0 + $1.x * $1.x }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return sumY / n }

        let m = (n * sumXY - sumX * sumY) / denominator
        let b = (sumY - m * sumX) / n

        let predicted = m * n + b
        return max(0, predicted)
    }

    // MARK: - Custom Estimation

    static func estimateCustom(
        customMonths: [String], line: CashFlowLine,
        index: TransactionIndex, calendar: Calendar
    ) -> Double {
        guard (line.subcategory != nil || line.category != nil), !customMonths.isEmpty else { return 0 }

        var total: Double = 0
        var count = 0

        for monthString in customMonths {
            guard let monthDate = customMonthFormatter.date(from: monthString) else { continue }
            let key = Self.monthKey(for: monthDate, calendar: calendar)
            total += lookupTotal(line: line, index: index, monthKey: key)
            count += 1
        }

        return count > 0 ? total / Double(count) : 0
    }

    // MARK: - Uncategorized Totals (Income / Expenses)

    // MARK: - Assigned ID Sets

    private static func buildAssignedIDs(
        lines: [CashFlowLine], isIncome: Bool
    ) -> (subcategoryIDs: Set<PersistentIdentifier>, categoryIDs: Set<PersistentIdentifier>) {
        var subIDs = Set<PersistentIdentifier>()
        var catIDs = Set<PersistentIdentifier>()
        for line in lines where line.isEnabled && line.isIncome == isIncome {
            if let subID = line.subcategory?.persistentModelID {
                subIDs.insert(subID)
            } else if let catID = line.category?.persistentModelID {
                catIDs.insert(catID)
            }
        }
        return (subIDs, catIDs)
    }

    /// Sums real transaction amounts not covered by any plan line (subcategory-level).
    /// For each category: total minus assigned subcategory totals = uncovered.
    /// Categories with a full category-level line are skipped entirely (backward compat).
    /// Called only for past/current months — future months skip this entirely.
    static func calculateUncategorizedTotal(
        categories: [Category],
        fullyAssignedCategoryIDs: Set<PersistentIdentifier>,
        assignedSubcategoryIDs: Set<PersistentIdentifier>,
        monthKey: String,
        index: TransactionIndex
    ) -> CashFlowOtherResult {
        var breakdown: [OtherCategoryItem] = []
        var totalReal: Double = 0

        for cat in categories {
            guard !fullyAssignedCategoryIDs.contains(cat.persistentModelID) else { continue }

            let catTotal = index.total(for: cat.persistentModelID, monthKey: monthKey)
            let assignedSubTotal = (cat.subcategories ?? [])
                .filter { assignedSubcategoryIDs.contains($0.persistentModelID) }
                .reduce(0.0) { $0 + index.subcategoryTotal(for: $1.persistentModelID, monthKey: monthKey) }
            let uncovered = catTotal - assignedSubTotal

            if uncovered > 0 {
                totalReal += uncovered
                breakdown.append(OtherCategoryItem(
                    categoryName: cat.name, iconName: cat.iconName ?? "folder",
                    colorHex: cat.colorHex, amount: uncovered
                ))
            }
        }

        return CashFlowOtherResult(
            plannedAmount: totalReal,
            realAmount: totalReal,
            categoryBreakdown: breakdown.sorted { $0.amount > $1.amount }
        )
    }

    // MARK: - Sort Lines by Amount (grouped by category)

    /// Groups subcategory lines under their parent category, sorts categories by
    /// their top line amount (descending), then sorts lines within each group by amount.
    private static func sortLinesByAmountGrouped(
        _ lines: [CashFlowLine],
        monthKey: String, monthDate: Date,
        index: TransactionIndex, calendar: Calendar
    ) -> [CashFlowLine] {
        // Pre-compute amounts once per line (O(n)) to avoid redundant calls during sort
        let amounts: [UUID: Double] = Dictionary(uniqueKeysWithValues: lines.map { line in
            let amt = line.overrides?.first(where: { $0.monthKey == monthKey })?.amount
                ?? estimatePlannedAmount(line: line, monthDate: monthDate, index: index, calendar: calendar)
            return (line.id, amt)
        })

        // Group by parent category persistentModelID
        var groups: [PersistentIdentifier: [CashFlowLine]] = [:]
        var ungrouped: [CashFlowLine] = []

        for line in lines {
            if let catID = line.category?.persistentModelID {
                groups[catID, default: []].append(line)
            } else {
                ungrouped.append(line)
            }
        }

        // Sort lines within each group by amount descending
        for key in groups.keys {
            groups[key]?.sort { (amounts[$0.id] ?? 0) > (amounts[$1.id] ?? 0) }
        }

        // Sort groups by their top line amount descending
        let sortedGroups = groups.values.sorted { groupA, groupB in
            let maxA = groupA.lazy.compactMap { amounts[$0.id] }.max() ?? 0
            let maxB = groupB.lazy.compactMap { amounts[$0.id] }.max() ?? 0
            return maxA > maxB
        }

        // Flatten: grouped lines first, then ungrouped sorted by amount
        var result: [CashFlowLine] = []
        for group in sortedGroups {
            result.append(contentsOf: group)
        }
        result.append(contentsOf: ungrouped.sorted { (amounts[$0.id] ?? 0) > (amounts[$1.id] ?? 0) })
        return result
    }
}
