//
//  CashFlowProjectionCalculator.swift
//  Yala
//
//  Calculates cash flow projections: planned vs real amounts per line per month.
//

import Foundation

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
    let totalIncome: Double
    let totalExpense: Double                 // Positive magnitude
    let netFlow: Double                      // income - expense
    let accumulatedBalance: Double
}

struct CashFlowLineResult {
    let lineID: UUID
    let name: String
    let plannedAmount: Double
    let realAmount: Double?
    let difference: Double?
    let differencePercent: Double?
    let progress: Double?
    let isOverride: Bool
    let estimationMethod: String
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

// MARK: - Calculator

struct CashFlowProjectionCalculator {

    static func calculate(
        plan: CashFlowPlan,
        lines: [CashFlowLine],
        transactions: [TransactionItem],
        allExpenseCategories: [Category],
        scheduledPayments: [ScheduledPayment],
        monthsBack: Int,
        monthsAhead: Int,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> CashFlowProjection {
        let calendar = Calendar.current
        let now = Date.now
        let currentComponents = calendar.dateComponents([.year, .month], from: now)
        let currentMonthStart = calendar.date(from: currentComponents)!

        // Generate month range
        let months = generateMonthRange(
            from: currentMonthStart,
            monthsBack: monthsBack,
            monthsAhead: monthsAhead,
            calendar: calendar
        )

        // Filter valid transactions (exclude balance adjustments, transfers, uncategorized)
        let validTransactions = transactions.filter { tx in
            tx.category != nil && tx.balanceAdjustmentType == nil
        }

        // Assigned category IDs for "other expenses" calculation
        let assignedCategoryIDs = Set(
            lines.filter { $0.isEnabled && !$0.isIncome && $0.category != nil }
                .compactMap { $0.category?.persistentModelID }
        )

        let incomeLines = lines.filter { $0.isEnabled && $0.isIncome }
            .sorted { $0.sortOrder < $1.sortOrder }
        let expenseLines = lines.filter { $0.isEnabled && !$0.isIncome }
            .sorted { $0.sortOrder < $1.sortOrder }

        var accumulatedBalance = plan.startingBalance
        var projectedMonths: [CashFlowMonth] = []
        var totalProjectedIncome: Double = 0
        var totalProjectedExpense: Double = 0

        for monthDate in months {
            let monthKey = Self.monthKey(for: monthDate, calendar: calendar)
            let isPast = monthDate < currentMonthStart
            let isCurrent = calendar.isDate(monthDate, equalTo: currentMonthStart, toGranularity: .month)

            let incomeResults = incomeLines.map { line in
                calculateLineResult(
                    line: line,
                    monthDate: monthDate,
                    monthKey: monthKey,
                    isPast: isPast,
                    isCurrent: isCurrent,
                    transactions: validTransactions,
                    scheduledPayments: scheduledPayments,
                    currencyCode: currencyCode,
                    converter: converter,
                    calendar: calendar
                )
            }

            let expenseResults = expenseLines.map { line in
                calculateLineResult(
                    line: line,
                    monthDate: monthDate,
                    monthKey: monthKey,
                    isPast: isPast,
                    isCurrent: isCurrent,
                    transactions: validTransactions,
                    scheduledPayments: scheduledPayments,
                    currencyCode: currencyCode,
                    converter: converter,
                    calendar: calendar
                )
            }

            let otherExpenses: CashFlowOtherResult?
            if plan.showOtherExpenses {
                otherExpenses = calculateOtherExpenses(
                    transactions: validTransactions,
                    allExpenseCategories: allExpenseCategories,
                    assignedCategoryIDs: assignedCategoryIDs,
                    monthDate: monthDate,
                    monthKey: monthKey,
                    isPast: isPast,
                    isCurrent: isCurrent,
                    currencyCode: currencyCode,
                    converter: converter,
                    calendar: calendar
                )
            } else {
                otherExpenses = nil
            }

            let totalIncome = incomeResults.reduce(0.0) { $0 + $1.plannedAmount }
            let totalExpense = expenseResults.reduce(0.0) { $0 + $1.plannedAmount }
                + (otherExpenses?.plannedAmount ?? 0)
            let netFlow = totalIncome - totalExpense

            accumulatedBalance += netFlow
            totalProjectedIncome += totalIncome
            totalProjectedExpense += totalExpense

            projectedMonths.append(CashFlowMonth(
                monthKey: monthKey,
                date: monthDate,
                isPast: isPast,
                isCurrent: isCurrent,
                incomeLines: incomeResults,
                expenseLines: expenseResults,
                otherExpenses: otherExpenses,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                netFlow: netFlow,
                accumulatedBalance: accumulatedBalance
            ))
        }

        return CashFlowProjection(
            months: projectedMonths,
            startingBalance: plan.startingBalance,
            totalProjectedIncome: totalProjectedIncome,
            totalProjectedExpense: totalProjectedExpense,
            totalProjectedNet: totalProjectedIncome - totalProjectedExpense
        )
    }

    // MARK: - Month Range

    static func generateMonthRange(
        from currentMonth: Date,
        monthsBack: Int,
        monthsAhead: Int,
        calendar: Calendar
    ) -> [Date] {
        var months: [Date] = []
        for offset in -monthsBack...monthsAhead {
            if let date = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
                months.append(date)
            }
        }
        return months
    }

    static func monthKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    // MARK: - Line Result

    private static func calculateLineResult(
        line: CashFlowLine,
        monthDate: Date,
        monthKey: String,
        isPast: Bool,
        isCurrent: Bool,
        transactions: [TransactionItem],
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> CashFlowLineResult {

        // Check for override
        let override = line.overrides?.first { $0.monthKey == monthKey }
        let isOverride = override != nil

        let plannedAmount: Double
        if let override {
            plannedAmount = override.amount
        } else {
            plannedAmount = estimatePlannedAmount(
                line: line,
                monthDate: monthDate,
                transactions: transactions,
                scheduledPayments: scheduledPayments,
                currencyCode: currencyCode,
                converter: converter,
                calendar: calendar
            )
        }

        // Real amount for past/current months
        let realAmount: Double?
        if isPast || isCurrent {
            realAmount = calculateRealAmount(
                transactions: transactions,
                category: line.category,
                monthDate: monthDate,
                isIncome: line.isIncome,
                currencyCode: currencyCode,
                converter: converter,
                calendar: calendar
            )
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

        // Progress for current month only
        let progress: Double?
        if isCurrent, let realAmount, plannedAmount > 0 {
            progress = realAmount / plannedAmount
        } else {
            progress = nil
        }

        // Subcategory breakdown
        let subcategoryBreakdown: [SubcategoryLineResult]?
        if line.isExpanded, let category = line.category,
           let subcategories = category.subcategories, !subcategories.isEmpty {
            subcategoryBreakdown = subcategories
                .filter { $0.isVisible }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { sub in
                    let subReal: Double?
                    if isPast || isCurrent {
                        subReal = calculateRealAmountForSubcategory(
                            transactions: transactions,
                            subcategory: sub,
                            monthDate: monthDate,
                            isIncome: line.isIncome,
                            currencyCode: currencyCode,
                            converter: converter,
                            calendar: calendar
                        )
                    } else {
                        subReal = nil
                    }
                    return SubcategoryLineResult(
                        subcategoryName: sub.name,
                        plannedAmount: 0, // Subcategory plan distribution not implemented yet
                        realAmount: subReal
                    )
                }
        } else {
            subcategoryBreakdown = nil
        }

        return CashFlowLineResult(
            lineID: line.id,
            name: line.name,
            plannedAmount: plannedAmount,
            realAmount: realAmount,
            difference: difference,
            differencePercent: differencePercent,
            progress: progress,
            isOverride: isOverride,
            estimationMethod: line.estimationMethod,
            subcategoryBreakdown: subcategoryBreakdown
        )
    }

    // MARK: - Estimation Methods

    private static func estimatePlannedAmount(
        line: CashFlowLine,
        monthDate: Date,
        transactions: [TransactionItem],
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        switch line.method {
        case .average3m:
            return estimateAverage(
                transactions: transactions, months: 3,
                category: line.category, isIncome: line.isIncome,
                referenceDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
        case .average6m:
            return estimateAverage(
                transactions: transactions, months: 6,
                category: line.category, isIncome: line.isIncome,
                referenceDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
        case .average12m:
            return estimateAverage(
                transactions: transactions, months: 12,
                category: line.category, isIncome: line.isIncome,
                referenceDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
        case .lastMonth:
            return estimateLastMonth(
                transactions: transactions, category: line.category,
                isIncome: line.isIncome, referenceDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
        case .manual:
            return line.manualAmount ?? 0
        case .scheduled:
            if let payment = line.scheduledPayment {
                return estimateScheduled(
                    payment: payment, monthDate: monthDate, calendar: calendar
                )
            }
            return line.manualAmount ?? 0
        case .trend:
            return estimateTrend(
                transactions: transactions, category: line.category,
                isIncome: line.isIncome, referenceDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
        case .custom:
            return estimateCustom(
                transactions: transactions, customMonths: line.customMonths,
                category: line.category, isIncome: line.isIncome,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
        }
    }

    // MARK: - Average Estimation

    static func estimateAverage(
        transactions: [TransactionItem],
        months: Int,
        category: Category?,
        isIncome: Bool,
        referenceDate: Date,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let category else { return 0 }

        var total: Double = 0
        var monthCount = 0

        for offset in 1...months {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let amount = sumTransactions(
                transactions: transactions, category: category,
                isIncome: isIncome, monthDate: monthStart,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
            if amount > 0 {
                total += amount
                monthCount += 1
            }
        }

        return monthCount > 0 ? total / Double(monthCount) : 0
    }

    // MARK: - Last Month Estimation

    static func estimateLastMonth(
        transactions: [TransactionItem],
        category: Category?,
        isIncome: Bool,
        referenceDate: Date,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let category else { return 0 }
        guard let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: referenceDate) else { return 0 }

        return sumTransactions(
            transactions: transactions, category: category,
            isIncome: isIncome, monthDate: lastMonthDate,
            currencyCode: currencyCode, converter: converter, calendar: calendar
        )
    }

    // MARK: - Scheduled Estimation

    static func estimateScheduled(
        payment: ScheduledPayment,
        monthDate: Date,
        calendar: Calendar
    ) -> Double {
        let params = payment.dateCalculatorParams
        let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
            params: params, month: monthDate, calendar: calendar
        )
        return abs(payment.amount) * Double(dates.count)
    }

    // MARK: - Trend Estimation (Linear Regression)

    static func estimateTrend(
        transactions: [TransactionItem],
        category: Category?,
        isIncome: Bool,
        referenceDate: Date,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let category else { return 0 }

        // Collect 6 months of data
        var dataPoints: [(x: Double, y: Double)] = []
        for offset in (1...6).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let amount = sumTransactions(
                transactions: transactions, category: category,
                isIncome: isIncome, monthDate: monthStart,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
            dataPoints.append((x: Double(6 - offset), y: amount))
        }

        guard dataPoints.count >= 2 else { return 0 }

        // Simple linear regression: y = mx + b
        let n = Double(dataPoints.count)
        let sumX = dataPoints.reduce(0.0) { $0 + $1.x }
        let sumY = dataPoints.reduce(0.0) { $0 + $1.y }
        let sumXY = dataPoints.reduce(0.0) { $0 + $1.x * $1.y }
        let sumX2 = dataPoints.reduce(0.0) { $0 + $1.x * $1.x }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return sumY / n }

        let m = (n * sumXY - sumX * sumY) / denominator
        let b = (sumY - m * sumX) / n

        // Extrapolate to next month (x = n)
        let predicted = m * n + b
        return max(0, predicted)
    }

    // MARK: - Custom Estimation

    static func estimateCustom(
        transactions: [TransactionItem],
        customMonths: [String],
        category: Category?,
        isIncome: Bool,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let category, !customMonths.isEmpty else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.timeZone = calendar.timeZone

        var total: Double = 0
        var count = 0

        for monthString in customMonths {
            guard let monthDate = formatter.date(from: monthString) else { continue }
            let amount = sumTransactions(
                transactions: transactions, category: category,
                isIncome: isIncome, monthDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
            total += amount
            count += 1
        }

        return count > 0 ? total / Double(count) : 0
    }

    // MARK: - Real Amount

    static func calculateRealAmount(
        transactions: [TransactionItem],
        category: Category?,
        monthDate: Date,
        isIncome: Bool,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let category else { return 0 }
        return sumTransactions(
            transactions: transactions, category: category,
            isIncome: isIncome, monthDate: monthDate,
            currencyCode: currencyCode, converter: converter, calendar: calendar
        )
    }

    // MARK: - Subcategory Real Amount

    private static func calculateRealAmountForSubcategory(
        transactions: [TransactionItem],
        subcategory: Subcategory,
        monthDate: Date,
        isIncome: Bool,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { return 0 }

        var total: Double = 0
        for tx in transactions {
            guard tx.subcategory?.persistentModelID == subcategory.persistentModelID else { continue }
            guard tx.date >= monthInterval.start && tx.date < monthInterval.end else { continue }

            let magnitude = convertedMagnitude(
                tx: tx, currencyCode: currencyCode, converter: converter
            )
            total += magnitude
        }
        return total
    }

    // MARK: - Other Expenses

    static func calculateOtherExpenses(
        transactions: [TransactionItem],
        allExpenseCategories: [Category],
        assignedCategoryIDs: Set<PersistentIdentifier>,
        monthDate: Date,
        monthKey: String,
        isPast: Bool,
        isCurrent: Bool,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> CashFlowOtherResult {
        let unassignedCategories = allExpenseCategories.filter { cat in
            !cat.isIncome && !assignedCategoryIDs.contains(cat.persistentModelID)
        }

        guard calendar.dateInterval(of: .month, for: monthDate) != nil else {
            return CashFlowOtherResult(plannedAmount: 0, realAmount: nil, categoryBreakdown: [])
        }

        var breakdown: [OtherCategoryItem] = []
        var totalPlanned: Double = 0
        var totalReal: Double = 0

        for cat in unassignedCategories {
            // For planned: use average of last 6 months
            let planned = estimateAverage(
                transactions: transactions, months: 6,
                category: cat, isIncome: false,
                referenceDate: monthDate,
                currencyCode: currencyCode, converter: converter, calendar: calendar
            )
            totalPlanned += planned

            if isPast || isCurrent {
                let real = sumTransactions(
                    transactions: transactions, category: cat,
                    isIncome: false, monthDate: monthDate,
                    currencyCode: currencyCode, converter: converter, calendar: calendar
                )
                totalReal += real

                if real > 0 {
                    breakdown.append(OtherCategoryItem(
                        categoryName: cat.name,
                        iconName: cat.iconName ?? "folder",
                        colorHex: cat.colorHex,
                        amount: real
                    ))
                }
            } else if planned > 0 {
                breakdown.append(OtherCategoryItem(
                    categoryName: cat.name,
                    iconName: cat.iconName ?? "folder",
                    colorHex: cat.colorHex,
                    amount: planned
                ))
            }
        }

        let realAmount: Double? = (isPast || isCurrent) ? totalReal : nil

        return CashFlowOtherResult(
            plannedAmount: totalPlanned,
            realAmount: realAmount,
            categoryBreakdown: breakdown.sorted { $0.amount > $1.amount }
        )
    }

    // MARK: - Shared Helpers

    private static func sumTransactions(
        transactions: [TransactionItem],
        category: Category,
        isIncome: Bool,
        monthDate: Date,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { return 0 }

        var total: Double = 0
        for tx in transactions {
            guard tx.category?.persistentModelID == category.persistentModelID else { continue }
            guard tx.date >= monthInterval.start && tx.date < monthInterval.end else { continue }

            let magnitude = convertedMagnitude(
                tx: tx, currencyCode: currencyCode, converter: converter
            )
            total += magnitude
        }
        return total
    }

    private static func convertedMagnitude(
        tx: TransactionItem,
        currencyCode: String,
        converter: CurrencyConverting
    ) -> Double {
        if tx.preferredCurrencyCode == currencyCode {
            return abs(tx.amountInPreferredCurrency)
        } else {
            let decimalAmt = Decimal(abs(tx.amount))
            let converted = converter.convert(decimalAmt, from: tx.currencyCode, to: currencyCode, on: tx.date)
            return NSDecimalNumber(decimal: converted).doubleValue
        }
    }
}

// MARK: - PersistentIdentifier import

import SwiftData
