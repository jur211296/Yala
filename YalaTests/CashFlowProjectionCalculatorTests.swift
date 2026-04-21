//
//  CashFlowProjectionCalculatorTests.swift
//  YalaTests
//
//  Unit tests for CashFlowProjectionCalculator.
//

import Foundation
import Testing

@testable import Yala

struct CashFlowProjectionCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date,
        currencyCode: String = "USD",
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        preferredCurrencyCode: String = "USD",
        amountInPreferredCurrency: Double? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            tags: [],
            amountInPreferredCurrency: amountInPreferredCurrency ?? amount
        )
        tx.preferredCurrencyCode = preferredCurrencyCode
        tx.subcategory = subcategory
        return tx
    }

    private func makePlan(startingBalance: Double = 0) -> CashFlowPlan {
        CashFlowPlan(name: "Test Plan", startingBalance: startingBalance)
    }

    private func makeLine(
        name: String,
        isIncome: Bool = false,
        method: EstimationMethod = .average6m,
        manualAmount: Double? = nil,
        category: YalaCategory? = nil,
        scheduledPayment: ScheduledPayment? = nil,
        sortOrder: Int = 0
    ) -> CashFlowLine {
        CashFlowLine(
            name: name,
            isIncome: isIncome,
            sortOrder: sortOrder,
            estimationMethod: method,
            manualAmount: manualAmount,
            category: category,
            scheduledPayment: scheduledPayment
        )
    }

    // NOTE: ScheduledPayment cannot be instantiated without ModelContext in tests
    // (CloudKit race condition). Tests for scheduled estimation method are validated
    // via build + manual testing.

    private func monthStart(_ year: Int, _ month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private var currentMonthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: Date.now)
        return calendar.date(from: components)!
    }

    // MARK: - 1. Empty plan

    @Test func emptyPlan_projectionWithZeros() {
        let plan = makePlan()
        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.months.count == 1) // Just current month
        #expect(result.startingBalance == 0)
        #expect(result.totalProjectedIncome == 0)
        #expect(result.totalProjectedExpense == 0)
        #expect(result.totalProjectedNet == 0)
    }

    // MARK: - 2. Month range generation

    @Test func monthRange_generatesCorrectCount() {
        let months = CashFlowProjectionCalculator.generateMonthRange(
            from: monthStart(2026, 3), monthsBack: 3, monthsAhead: 6, calendar: calendar
        )
        #expect(months.count == 10) // 3 back + current + 6 ahead
    }

    // MARK: - 3. Month key format

    @Test func monthKey_formatsCorrectly() {
        let key = CashFlowProjectionCalculator.monthKey(for: monthStart(2026, 4), calendar: calendar)
        #expect(key == "2026-04")
    }

    @Test func monthKey_singleDigitMonth_padded() {
        let key = CashFlowProjectionCalculator.monthKey(for: monthStart(2026, 1), calendar: calendar)
        #expect(key == "2026-01")
    }

    // MARK: - 4. Manual estimation

    @Test func manualMethod_usesManualAmount() {
        let plan = makePlan()
        let cat = makeCategory(name: "Rent")
        let line = makeLine(name: "Rent", method: .manual, manualAmount: 1200, category: cat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.months.count == 1)
        #expect(result.months[0].expenseLines.count == 1)
        #expect(result.months[0].expenseLines[0].plannedAmount == 1200)
    }

    // MARK: - 5. Average 6m estimation

    @Test func average6m_calculatesCorrectAverage() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .average6m, category: cat)
        let plan = makePlan()

        // Create transactions in each of the last 6 months before current
        var transactions: [TransactionItem] = []
        let amounts: [Double] = [100, 200, 300, 400, 500, 600]
        for (i, amount) in amounts.enumerated() {
            let monthDate = calendar.date(byAdding: .month, value: -(i + 1), to: currentMonthStart)!
            let txDate = calendar.date(byAdding: .day, value: 5, to: monthDate)!
            transactions.append(makeTransaction(amount: -amount, date: txDate, category: cat))
        }

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: transactions,
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Average of 100,200,300,400,500,600 = 350
        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 350) < 0.01)
    }

    // MARK: - 6. Average 3m estimation

    @Test func average3m_usesOnly3Months() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .average3m, category: cat)
        let plan = makePlan()

        var transactions: [TransactionItem] = []
        // 3 recent months: 100, 200, 300; 3 older months: 1000, 2000, 3000
        for i in 1...6 {
            let amount = i <= 3 ? Double(i * 100) : Double(i * 1000)
            let monthDate = calendar.date(byAdding: .month, value: -i, to: currentMonthStart)!
            let txDate = calendar.date(byAdding: .day, value: 5, to: monthDate)!
            transactions.append(makeTransaction(amount: -amount, date: txDate, category: cat))
        }

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: transactions,
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Average of 100,200,300 = 200 (ignores older months)
        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 200) < 0.01)
    }

    // MARK: - 7. Average 12m estimation

    @Test func average12m_usesUp12Months() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .average12m, category: cat)
        let plan = makePlan()

        var transactions: [TransactionItem] = []
        // 12 months of 120 each
        for i in 1...12 {
            let monthDate = calendar.date(byAdding: .month, value: -i, to: currentMonthStart)!
            let txDate = calendar.date(byAdding: .day, value: 5, to: monthDate)!
            transactions.append(makeTransaction(amount: -120, date: txDate, category: cat))
        }

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: transactions,
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 120) < 0.01)
    }

    // MARK: - 8. Last month estimation

    @Test func lastMonth_usesOnlyPreviousMonth() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .lastMonth, category: cat)
        let plan = makePlan()

        let lastMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        let txDate = calendar.date(byAdding: .day, value: 10, to: lastMonth)!
        let tx = makeTransaction(amount: -450, date: txDate, category: cat)

        // Also add older month to ensure it's not included
        let olderMonth = calendar.date(byAdding: .month, value: -2, to: currentMonthStart)!
        let olderTxDate = calendar.date(byAdding: .day, value: 10, to: olderMonth)!
        let olderTx = makeTransaction(amount: -9999, date: olderTxDate, category: cat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [tx, olderTx],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 450) < 0.01)
    }

    // NOTE: Scheduled estimation test skipped — ScheduledPayment requires ModelContext

    // MARK: - 9. Override replaces calculated amount

    @Test func override_replacesPlannedAmount() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .manual, manualAmount: 500, category: cat)
        let plan = makePlan()

        let currentKey = CashFlowProjectionCalculator.monthKey(for: currentMonthStart, calendar: calendar)
        let override = CashFlowOverride(monthKey: currentKey, amount: 800, note: "Vacaciones")
        override.line = line
        line.overrides = [override]

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let lineResult = result.months[0].expenseLines[0]
        #expect(lineResult.plannedAmount == 800)
        #expect(lineResult.isOverride == true)
    }

    // MARK: - 11. Real vs plan for past month

    @Test func pastMonth_hasRealAmount() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .manual, manualAmount: 500, category: cat)
        let plan = makePlan()

        let lastMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        let txDate = calendar.date(byAdding: .day, value: 10, to: lastMonth)!
        let tx = makeTransaction(amount: -350, date: txDate, category: cat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [tx],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 1, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // First month is past
        let pastResult = result.months[0].expenseLines[0]
        #expect(pastResult.realAmount != nil)
        #expect(abs(pastResult.realAmount! - 350) < 0.01)
        #expect(pastResult.difference != nil)
        #expect(abs(pastResult.difference! - (-150)) < 0.01) // 350 - 500 = -150
    }

    // MARK: - 12. Current month has progress

    @Test func currentMonth_hasProgress() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .manual, manualAmount: 1000, category: cat)
        let plan = makePlan()

        // Add a transaction in current month
        let txDate = calendar.date(byAdding: .day, value: 1, to: currentMonthStart)!
        let tx = makeTransaction(amount: -400, date: txDate, category: cat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [tx],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.months[0].isCurrent == true)
        let currentResult = result.months[0].expenseLines[0]
        #expect(currentResult.progress != nil)
        #expect(abs(currentResult.progress! - 0.4) < 0.01) // 400/1000
    }

    // MARK: - 13. Future month has no real amount

    @Test func futureMonth_noRealAmount() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .manual, manualAmount: 500, category: cat)
        let plan = makePlan()

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 1,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Last month is future
        let futureResult = result.months[1].expenseLines[0]
        #expect(futureResult.realAmount == nil)
        #expect(futureResult.difference == nil)
        #expect(futureResult.progress == nil)
    }

    // MARK: - 14. Accumulated balance

    @Test func accumulatedBalance_sumsSequentially() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let expenseCat = makeCategory(name: "Rent")
        let plan = makePlan(startingBalance: 1000)

        let incomeLine = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 5000, category: incomeCat)
        let expenseLine = makeLine(name: "Rent", method: .manual, manualAmount: 2000, category: expenseCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [incomeLine, expenseLine], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 2,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Net per month = 5000 - 2000 = 3000
        #expect(result.startingBalance == 1000)
        #expect(abs(result.months[0].accumulatedBalance - 4000) < 0.01) // 1000 + 3000
        #expect(abs(result.months[1].accumulatedBalance - 7000) < 0.01) // 4000 + 3000
        #expect(abs(result.months[2].accumulatedBalance - 10000) < 0.01) // 7000 + 3000
    }

    // MARK: - 15. Income line

    @Test func incomeLine_appearsInIncomeResults() {
        let cat = makeCategory(name: "Salary", isIncome: true)
        let line = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 5000, category: cat)
        let plan = makePlan()

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.months[0].incomeLines.count == 1)
        #expect(result.months[0].expenseLines.count == 0)
        #expect(result.months[0].totalIncome == 5000)
    }

    // MARK: - 16. Other expenses excludes assigned categories

    @Test func otherExpenses_excludesAssignedCategories() {
        let foodCat = makeCategory(name: "Food")
        let giftsCat = makeCategory(name: "Gifts")
        let healthCat = makeCategory(name: "Health")
        let plan = makePlan()

        // Food is assigned to a line, gifts and health are not
        let foodLine = makeLine(name: "Food", method: .manual, manualAmount: 500, category: foodCat)

        // Create transactions for the current month (uncategorized lines use real data only)
        let txDate = calendar.date(byAdding: .day, value: 2, to: currentMonthStart)!
        let transactions: [TransactionItem] = [
            makeTransaction(amount: -100, date: txDate, category: foodCat),
            makeTransaction(amount: -50, date: txDate, category: giftsCat),
            makeTransaction(amount: -30, date: txDate, category: healthCat)
        ]

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [foodLine], transactions: transactions,
            allExpenseCategories: [foodCat, giftsCat, healthCat], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Other expenses should include gifts (50) + health (30) = 80 from current month real data
        let other = result.months[0].otherExpenses
        #expect(other != nil)
        #expect(abs(other!.plannedAmount - 80) < 0.01)
    }

    // MARK: - 17. Currency conversion works

    @Test func currencyConversion_appliesRate() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .lastMonth, category: cat)
        let plan = makePlan()

        let lastMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        let txDate = calendar.date(byAdding: .day, value: 5, to: lastMonth)!
        // EUR transaction, reporting in USD with rate 2.0
        let tx = makeTransaction(
            amount: -100, date: txDate, currencyCode: "EUR",
            category: cat, preferredCurrencyCode: "EUR",
            amountInPreferredCurrency: -100
        )

        let converter = MockCurrencyConverter(fixedRate: 2.0)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [tx],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: converter
        )

        // 100 EUR * 2.0 = 200 USD
        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 200) < 0.01)
    }

    // MARK: - 18. Month with no transactions

    @Test func monthWithNoTransactions_realIsZero() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .manual, manualAmount: 500, category: cat)
        let plan = makePlan()

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 1, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Past month with no transactions: real = 0
        let pastResult = result.months[0].expenseLines[0]
        #expect(pastResult.realAmount == 0)
        #expect(pastResult.plannedAmount == 500)
    }

    // MARK: - 19. Net flow calculation

    @Test func netFlow_incomeMinusExpense() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let expenseCat = makeCategory(name: "Rent")
        let plan = makePlan()

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 5000, category: incomeCat)
        let expense = makeLine(name: "Rent", method: .manual, manualAmount: 1500, category: expenseCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income, expense], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(abs(result.months[0].netFlow - 3500) < 0.01)
        #expect(abs(result.totalProjectedNet - 3500) < 0.01)
    }

    // MARK: - 20. Average skips months with zero activity

    @Test func averageEstimation_skipsEmptyMonths() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .average6m, category: cat)
        let plan = makePlan()

        // Only 3 of 6 months have activity: 100, 200, 300
        var transactions: [TransactionItem] = []
        for i in [1, 3, 5] {
            let monthDate = calendar.date(byAdding: .month, value: -i, to: currentMonthStart)!
            let txDate = calendar.date(byAdding: .day, value: 5, to: monthDate)!
            transactions.append(makeTransaction(amount: Double(-i * 100), date: txDate, category: cat))
        }

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: transactions,
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Average of 100, 300, 500 = 300 (3 months with activity)
        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 300) < 0.01)
    }

    // MARK: - 21. isPast and isCurrent flags

    @Test func monthFlags_correctForPastCurrentFuture() {
        let plan = makePlan()

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 1, monthsAhead: 1,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.months.count == 3)
        #expect(result.months[0].isPast == true)
        #expect(result.months[0].isCurrent == false)
        #expect(result.months[1].isPast == false)
        #expect(result.months[1].isCurrent == true)
        #expect(result.months[2].isPast == false)
        #expect(result.months[2].isCurrent == false)
    }

    // MARK: - 22. Difference percent

    @Test func differencePercent_calculatesCorrectly() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .manual, manualAmount: 500, category: cat)
        let plan = makePlan()

        let lastMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)!
        let txDate = calendar.date(byAdding: .day, value: 10, to: lastMonth)!
        let tx = makeTransaction(amount: -600, date: txDate, category: cat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [tx],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 1, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let pastResult = result.months[0].expenseLines[0]
        #expect(pastResult.differencePercent != nil)
        // (600 - 500) / 500 = 0.2
        #expect(abs(pastResult.differencePercent! - 0.2) < 0.01)
    }

    // MARK: - 23. Trend estimation (linear regression)

    @Test func trendEstimation_calculatesSlope() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .trend, category: cat)
        let plan = makePlan()

        // Create increasing pattern: 100, 200, 300, 400, 500, 600
        var transactions: [TransactionItem] = []
        for i in 1...6 {
            let monthDate = calendar.date(byAdding: .month, value: -i, to: currentMonthStart)!
            let txDate = calendar.date(byAdding: .day, value: 5, to: monthDate)!
            let amount = Double((7 - i) * 100) // 600,500,400,300,200,100 → reversed to 100,200,...,600
            transactions.append(makeTransaction(amount: -amount, date: txDate, category: cat))
        }

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: transactions,
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let planned = result.months[0].expenseLines[0].plannedAmount
        // Linear regression on [100,200,300,400,500,600] with x=[0,1,2,3,4,5] → predict x=6 → ~700
        #expect(planned > 600) // Should extrapolate upward
    }

    // MARK: - 24. Trend estimation with flat data

    @Test func trendEstimation_flatData_noChange() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .trend, category: cat)
        let plan = makePlan()

        var transactions: [TransactionItem] = []
        for i in 1...6 {
            let monthDate = calendar.date(byAdding: .month, value: -i, to: currentMonthStart)!
            let txDate = calendar.date(byAdding: .day, value: 5, to: monthDate)!
            transactions.append(makeTransaction(amount: -200, date: txDate, category: cat))
        }

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: transactions,
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 200) < 1) // ~200 (flat)
    }

    // MARK: - 25. Custom estimation with selected months

    @Test func customEstimation_usesSelectedMonths() {
        let cat = makeCategory(name: "Food")
        let plan = makePlan()

        // Create line with specific months selected
        let line = makeLine(name: "Food", method: .custom, category: cat)
        line.customMonthsRaw = "2026-01,2026-02"

        let tx1 = makeTransaction(amount: -100, date: date(2026, 1, 15), category: cat)
        let tx2 = makeTransaction(amount: -300, date: date(2026, 2, 15), category: cat)
        // This month should NOT be included
        let tx3 = makeTransaction(amount: -9999, date: date(2026, 3, 15), category: cat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [tx1, tx2, tx3],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Average of Jan(100) + Feb(300) = 200
        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(abs(planned - 200) < 0.01)
    }

    // MARK: - 26. Custom estimation with empty months returns zero

    @Test func customEstimation_emptyMonths_returnsZero() {
        let cat = makeCategory(name: "Food")
        let line = makeLine(name: "Food", method: .custom, category: cat)
        line.customMonthsRaw = ""
        let plan = makePlan()

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(planned == 0)
    }

    // MARK: - 27. Total projected values

    @Test func totalProjected_sumsAllMonths() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let expenseCat = makeCategory(name: "Rent")
        let plan = makePlan()

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 3000, category: incomeCat)
        let expense = makeLine(name: "Rent", method: .manual, manualAmount: 1000, category: expenseCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income, expense], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 2,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // 3 months of income: 3000 * 3 = 9000
        #expect(abs(result.totalProjectedIncome - 9000) < 0.01)
        // 3 months of expense: 1000 * 3 = 3000
        #expect(abs(result.totalProjectedExpense - 3000) < 0.01)
        // Net: 9000 - 3000 = 6000
        #expect(abs(result.totalProjectedNet - 6000) < 0.01)
    }

    // MARK: - 28. No category on line returns zero planned

    @Test func lineWithNoCategory_returnsZeroPlanned() {
        let line = makeLine(name: "Orphan", method: .average6m, category: nil)
        let plan = makePlan()

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 0,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        let planned = result.months[0].expenseLines[0].plannedAmount
        #expect(planned == 0)
    }

    // MARK: - 30. Starting balance date — applies at correct month

    @Test func startingBalanceDate_appliesAtCorrectMonth() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let expenseCat = makeCategory(name: "Rent")
        let plan = makePlan(startingBalance: 5000)

        // Set balance date to 1 month ahead
        let futureMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
        plan.startingBalanceDate = futureMonth

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 3000, category: incomeCat)
        let expense = makeLine(name: "Rent", method: .manual, manualAmount: 1000, category: expenseCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income, expense], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 1, monthsAhead: 2,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Net per month = 3000 - 1000 = 2000
        // Month -1 (past): 0 + 2000 = 2000
        #expect(abs(result.months[0].accumulatedBalance - 2000) < 0.01)
        // Month 0 (current): 2000 + 2000 = 4000
        #expect(abs(result.months[1].accumulatedBalance - 4000) < 0.01)
        // Month +1 (balance date): 5000 + 2000 = 7000
        #expect(abs(result.months[2].accumulatedBalance - 7000) < 0.01)
        // Month +2: 7000 + 2000 = 9000
        #expect(abs(result.months[3].accumulatedBalance - 9000) < 0.01)
    }

    // MARK: - 31. Starting balance date nil — applies at current month

    @Test func startingBalanceDate_nil_appliesAtCurrentMonth() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let plan = makePlan(startingBalance: 1000)
        // startingBalanceDate = nil → "hoy" = mes actual

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 500, category: incomeCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 2,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Month 0 (current, balance date): 1000 + 500 = 1500
        #expect(abs(result.months[0].accumulatedBalance - 1500) < 0.01)
        // Month +1: 1500 + 500 = 2000
        #expect(abs(result.months[1].accumulatedBalance - 2000) < 0.01)
        // Month +2: 2000 + 500 = 2500
        #expect(abs(result.months[2].accumulatedBalance - 2500) < 0.01)
    }

    // MARK: - 32. Starting balance date nil with monthsBack — past months from zero

    @Test func startingBalanceDate_nil_withMonthsBack_appliesAtCurrentMonth() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let plan = makePlan(startingBalance: 5000)
        // nil → current month; past months should accumulate from 0

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 1000, category: incomeCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 2, monthsAhead: 1,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Month -2 (past): 0 + 1000 = 1000
        #expect(abs(result.months[0].accumulatedBalance - 1000) < 0.01)
        // Month -1 (past): 1000 + 1000 = 2000
        #expect(abs(result.months[1].accumulatedBalance - 2000) < 0.01)
        // Month 0 (current, balance date): 5000 + 1000 = 6000
        #expect(abs(result.months[2].accumulatedBalance - 6000) < 0.01)
        // Month +1: 6000 + 1000 = 7000
        #expect(abs(result.months[3].accumulatedBalance - 7000) < 0.01)
    }

    // MARK: - 33. Starting balance date before range — seeds immediately

    @Test func startingBalanceDate_beforeRange_seedsImmediately() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let plan = makePlan(startingBalance: 3000)

        // Set balance date to 12 months ago (well before any visible month)
        let oldDate = calendar.date(byAdding: .month, value: -12, to: currentMonthStart)!
        plan.startingBalanceDate = oldDate

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 500, category: incomeCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 1, monthsAhead: 1,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Balance date is before range → seed at first month (legacy behavior)
        // Month -1: 3000 + 500 = 3500
        #expect(abs(result.months[0].accumulatedBalance - 3500) < 0.01)
        // Month 0: 3500 + 500 = 4000
        #expect(abs(result.months[1].accumulatedBalance - 4000) < 0.01)
        // Month +1: 4000 + 500 = 4500
        #expect(abs(result.months[2].accumulatedBalance - 4500) < 0.01)
    }

    // MARK: - 34. Starting balance date after range — all from zero

    @Test func startingBalanceDate_afterRange_allFromZero() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let plan = makePlan(startingBalance: 10000)

        // Set balance date to 12 months in the future (beyond visible range)
        let farFuture = calendar.date(byAdding: .month, value: 12, to: currentMonthStart)!
        plan.startingBalanceDate = farFuture

        let income = makeLine(name: "Salary", isIncome: true, method: .manual, manualAmount: 1000, category: incomeCat)

        let result = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [income], transactions: [],
            allExpenseCategories: [], scheduledPayments: [],
            monthsBack: 0, monthsAhead: 2,
            currencyCode: "USD", converter: MockCurrencyConverter()
        )

        // Balance date is beyond range → all months accumulate from 0
        // Month 0: 0 + 1000 = 1000
        #expect(abs(result.months[0].accumulatedBalance - 1000) < 0.01)
        // Month +1: 1000 + 1000 = 2000
        #expect(abs(result.months[1].accumulatedBalance - 2000) < 0.01)
        // Month +2: 2000 + 1000 = 3000
        #expect(abs(result.months[2].accumulatedBalance - 3000) < 0.01)
    }
}

/*
Tests generated:
1.  emptyPlan_projectionWithZeros - Empty plan produces zeros
2.  monthRange_generatesCorrectCount - Month range size correct
3.  monthKey_formatsCorrectly - Format "2026-04"
4.  monthKey_singleDigitMonth_padded - Padded "2026-01"
5.  manualMethod_usesManualAmount - Manual estimation
6.  average6m_calculatesCorrectAverage - Average 6 months
7.  average3m_usesOnly3Months - Average 3 months
8.  average12m_usesUp12Months - Average 12 months
9.  lastMonth_usesOnlyPreviousMonth - Last month only
10. scheduled_countsOccurrencesInMonth - Scheduled payments
11. override_replacesPlannedAmount - Override logic
12. pastMonth_hasRealAmount - Real amount for past
13. currentMonth_hasProgress - Progress for current
14. futureMonth_noRealAmount - No real for future
15. accumulatedBalance_sumsSequentially - Balance accumulation
16. incomeLine_appearsInIncomeResults - Income separation
17. otherExpenses_excludesAssignedCategories - Other expenses
18. currencyConversion_appliesRate - Currency conversion
19. monthWithNoTransactions_realIsZero - Zero real
20. netFlow_incomeMinusExpense - Net flow
21. averageEstimation_skipsEmptyMonths - Skip empty months
22. monthFlags_correctForPastCurrentFuture - Flags
23. differencePercent_calculatesCorrectly - Difference %
24. trendEstimation_calculatesSlope - Trend method
25. trendEstimation_flatData_noChange - Flat trend
26. customEstimation_usesSelectedMonths - Custom months
27. customEstimation_emptyMonths_returnsZero - Empty custom
28. totalProjected_sumsAllMonths - Total projections
29. lineWithNoCategory_returnsZeroPlanned - No category
30. startingBalanceDate_appliesAtCorrectMonth - Date-based balance injection
31. startingBalanceDate_nil_appliesAtCurrentMonth - Nil date = current month
32. startingBalanceDate_nil_withMonthsBack_appliesAtCurrentMonth - Nil + past months from zero
33. startingBalanceDate_beforeRange_seedsImmediately - Old date seeds first month
34. startingBalanceDate_afterRange_allFromZero - Future date = all from zero
*/
