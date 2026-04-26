//
//  FullFinancialContextBuilderTests.swift
//  YalaTests
//
//  Cobertura del builder principal del context-rich pipeline. Usa el entry point
//  `buildFromArrays` (signature pura) para evitar el CloudKit race condition de
//  `makeTestContext()` en suite mode (documentado en CLAUDE.md).
//
//  Incluye:
//  - Coverage migrada de ChatToolExecutorTests (filter, group, budget, compare, overview)
//  - Coverage específica del bug #2 (weekday low sample size)
//  - Edge cases: 0 tx, uncategorized bucket, multi-currency, budget zero limit
//

import Testing
import Foundation
@testable import Yala

@Suite(.serialized)
struct FullFinancialContextBuilderTests {

    // MARK: - Helpers (in-memory factories — no ModelContext)

    private func makeAccount(
        name: String = "Main",
        currencyCode: String = "USD",
        excludeFromStatistics: Bool = false,
        isArchived: Bool = false
    ) -> Account {
        let account = Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#000",
            iconName: "creditcard",
            type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
        account.isArchived = isArchived
        return account
    }

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000", isIncome: isIncome)
    }

    private func makeSubcategory(name: String, category: YalaCategory, need: SubcategoryNeed = .essential) -> Subcategory {
        Subcategory(
            name: name,
            colorHex: nil,
            natureRawValue: need.rawValue,
            iconName: "cart.fill",
            category: category
        )
    }

    private func makeTx(
        amount: Double,
        date: Date,
        currencyCode: String = "USD",
        category: YalaCategory?,
        subcategory: Subcategory? = nil,
        account: Account? = nil,
        note: String? = nil,
        balanceAdjustmentType: String? = nil,
        amountInPreferredCurrency: Double? = nil,
        preferredCurrencyCode: String = "USD"
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: note,
            category: category,
            amountInPreferredCurrency: amountInPreferredCurrency ?? amount
        )
        tx.preferredCurrencyCode = preferredCurrencyCode
        tx.subcategory = subcategory
        tx.account = account
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private func makeBudget(
        name: String = "Test Budget",
        limitAmount: Double,
        category: YalaCategory? = nil,
        isActive: Bool = true
    ) -> Budget {
        let budget = Budget(
            currencyCode: "USD",
            limitAmount: limitAmount,
            name: name,
            isActive: isActive
        )
        budget.category = category
        return budget
    }

    private func currentMonthDate(offset: Int = 1) -> Date {
        let cal = Calendar.current
        let monthStart = cal.dateInterval(of: .month, for: Date.now)?.start ?? Date.now
        return cal.date(byAdding: .day, value: offset, to: monthStart) ?? Date.now
    }

    private func lastMonthDate(offset: Int = 1) -> Date {
        let cal = Calendar.current
        let monthStart = cal.dateInterval(of: .month, for: Date.now)?.start ?? Date.now
        let lastMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart) ?? Date.now
        return cal.date(byAdding: .day, value: offset, to: lastMonthStart) ?? Date.now
    }

    @MainActor
    private func buildContext(
        transactions: [TransactionItem] = [],
        budgets: [Budget] = [],
        accounts: [Account] = [],
        tags: [YalaTag] = [],
        scheduledPayments: [ScheduledPayment] = [],
        currencyCode: String = "USD",
        includeAnomalies: Bool = false,
        now: Date = .now
    ) -> FullFinancialContext {
        FullFinancialContextBuilder().buildFromArrays(
            transactions: transactions,
            budgets: budgets,
            accounts: accounts,
            tags: tags,
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode,
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: includeAnomalies,
            now: now
        )
    }

    // MARK: - Empty data

    @MainActor @Test func emptyData_returnsValidShape() {
        let result = buildContext()

        #expect(result.balances.accounts.isEmpty)
        #expect(result.categories.isEmpty)
        #expect(result.merchantsTop20.isEmpty)
        #expect(result.budgets.isEmpty)
        #expect(result.anomalies == nil)
        #expect(result.periods.currentMonth.expense == 0)
        #expect(result.periods.currentMonth.txCount == 0)
        #expect(result.uncategorized.txCountCurrentMonth == 0)
    }

    // MARK: - Categories ranking (migrated from spending_summary tests)

    @MainActor @Test func categoriesRanking_topByAmountDesc() {
        let food = makeCategory(name: "Food")
        let transport = makeCategory(name: "Transport")
        let txs = [
            makeTx(amount: -100, date: currentMonthDate(), category: food),
            makeTx(amount: -80, date: currentMonthDate(offset: 2), category: food),
            makeTx(amount: -50, date: currentMonthDate(offset: 3), category: transport)
        ]

        let result = buildContext(transactions: txs)

        #expect(result.categories.count == 2)
        #expect(result.categories.first?.name == "Food")
        #expect(result.categories.first?.totalCurrentMonth == 180.0)
        #expect(result.categories.last?.name == "Transport")
        #expect(result.categories.last?.totalCurrentMonth == 50.0)
    }

    // MARK: - Budgets

    @MainActor @Test func budgetActive_withLimit_includesUsagePct() {
        let food = makeCategory(name: "Food")
        let budget = makeBudget(name: "Food Budget", limitAmount: 500, category: food)
        let txs = [makeTx(amount: -200, date: currentMonthDate(), category: food)]

        let result = buildContext(transactions: txs, budgets: [budget])

        #expect(result.budgets.count == 1)
        let bud = result.budgets.first!
        #expect(bud.name == "Food Budget")
        #expect(bud.limit == 500)
        #expect(bud.spent == 200)
        #expect(bud.usagePercent == 40.0)
        #expect(bud.status == .onTrack)
    }

    @MainActor @Test func budgetActive_zeroLimit_statusNoLimit() {
        let food = makeCategory(name: "Food")
        let budget = makeBudget(name: "Open Budget", limitAmount: 0, category: food)

        let result = buildContext(budgets: [budget])

        #expect(result.budgets.count == 1)
        #expect(result.budgets.first?.status == .noLimit)
        #expect(result.budgets.first?.usagePercent == nil)
    }

    // MARK: - Period comparison

    @MainActor @Test func periodComparison_currentVsLastMonth() {
        let food = makeCategory(name: "Food")
        let txs = [
            makeTx(amount: -200, date: currentMonthDate(), category: food),
            makeTx(amount: -150, date: lastMonthDate(), category: food)
        ]

        let result = buildContext(transactions: txs)

        #expect(result.periods.currentMonth.expense == 200.0)
        #expect(result.periods.lastMonth.expense == 150.0)
        let variation = result.categories.first?.variationPercentVsLastMonth ?? 0
        #expect(abs(variation - 33.33) < 0.5)
    }

    // MARK: - Top tx by subcategory

    @MainActor @Test func topTxBySubcategory_orderedByAmount() {
        let food = makeCategory(name: "Food")
        let restaurants = makeSubcategory(name: "Restaurants", category: food)
        let txs = [
            makeTx(amount: -50, date: currentMonthDate(offset: 1), category: food, subcategory: restaurants, note: "Lunch"),
            makeTx(amount: -120, date: currentMonthDate(offset: 2), category: food, subcategory: restaurants, note: "Dinner"),
            makeTx(amount: -30, date: currentMonthDate(offset: 3), category: food, subcategory: restaurants, note: "Coffee")
        ]

        let result = buildContext(transactions: txs)

        let entry = result.topTxBySubcategory.first { $0.subcategoryName == "Restaurants" }
        #expect(entry != nil)
        #expect(entry?.transactions.count == 3)
        #expect(entry?.transactions.first?.amount == 120)
        #expect(entry?.transactions.last?.amount == 30)
    }

    // MARK: - Anomalies gating

    @MainActor @Test func anomalies_excludedByDefault() {
        let result = buildContext(includeAnomalies: false)
        #expect(result.anomalies == nil)
    }

    @MainActor @Test func anomalies_includedWhenRequested() {
        let food = makeCategory(name: "Food")
        let cal = Calendar.current
        var txs: [TransactionItem] = []
        for i in 1...10 {
            let d = cal.date(byAdding: .day, value: -(20 + i * 3), to: Date.now) ?? Date.now
            txs.append(makeTx(amount: -20, date: d, category: food))
        }
        txs.append(makeTx(amount: -250, date: currentMonthDate(), category: food, note: "Big"))

        let result = buildContext(transactions: txs, includeAnomalies: true)
        #expect(result.anomalies != nil)
        #expect((result.anomalies?.count ?? 0) >= 1)
    }

    // MARK: - Multi-currency

    @MainActor @Test func multiCurrency_usesPreferredCurrencyAmounts() {
        let food = makeCategory(name: "Food")
        // tx in PEN with preferredCurrency=USD already converted to -100
        let tx = makeTx(
            amount: -370,
            date: currentMonthDate(),
            currencyCode: "PEN",
            category: food,
            amountInPreferredCurrency: -100
        )

        let result = buildContext(transactions: [tx])

        #expect(result.periods.currentMonth.expense == 100.0)
    }

    // MARK: - Bug #2: weekday with low sample size

    @MainActor @Test func weekdayPattern_singleLargeTx_lowSampleSize() {
        let transport = makeCategory(name: "Transport")
        let cal = Calendar.current
        let recent = cal.date(byAdding: .day, value: -3, to: Date.now) ?? Date.now
        let txs = [makeTx(amount: -3400, date: recent, category: transport, note: "Bus")]

        let result = buildContext(transactions: txs)

        let txWeekday = cal.component(.weekday, from: recent)
        let symbols = cal.weekdaySymbols
        let expectedName = symbols[txWeekday - 1]

        let entry = result.patterns.weekdayPattern30Days.first { $0.weekday == expectedName }
        #expect(entry != nil)
        #expect(entry?.sampleSize == 1)
        #expect(entry?.total == 3400.0)
        #expect((entry?.dayOccurrences ?? 0) >= 4)
    }

    // MARK: - Merchants top 20

    @MainActor @Test func merchantsTop20_orderedByTotalDesc() {
        let food = makeCategory(name: "Food")
        let txs = [
            makeTx(amount: -50, date: currentMonthDate(offset: 1), category: food, note: "Starbucks Coffee"),
            makeTx(amount: -150, date: currentMonthDate(offset: 2), category: food, note: "McDonalds"),
            makeTx(amount: -200, date: currentMonthDate(offset: 3), category: food, note: "McDonalds")
        ]

        let result = buildContext(transactions: txs)

        let mcd = result.merchantsTop20.first { $0.name.localizedCaseInsensitiveContains("mcdonald") }
        let starb = result.merchantsTop20.first { $0.name.localizedCaseInsensitiveContains("starbuck") }
        #expect(mcd != nil)
        #expect(starb != nil)
        #expect((mcd?.totalCurrentMonth ?? 0) > (starb?.totalCurrentMonth ?? 0))
        #expect(mcd?.txCount == 2)
    }

    // MARK: - Needs breakdown

    @MainActor @Test func needsBreakdown_sumsCorrectly() {
        let food = makeCategory(name: "Food")
        let groceries = makeSubcategory(name: "Groceries", category: food, need: .essential)
        let snacks = makeSubcategory(name: "Snacks", category: food, need: .optional)
        let txs = [
            makeTx(amount: -100, date: currentMonthDate(offset: 1), category: food, subcategory: groceries),
            makeTx(amount: -30, date: currentMonthDate(offset: 2), category: food, subcategory: snacks)
        ]

        let result = buildContext(transactions: txs)

        #expect(result.patterns.needsBreakdownCurrentMonth.essential == 100)
        #expect(result.patterns.needsBreakdownCurrentMonth.optional == 30)
        #expect(result.patterns.needsBreakdownCurrentMonth.total == 130)
    }

    // MARK: - Uncategorized bucket

    @MainActor @Test func uncategorizedBucket_explicit() {
        let txs = [makeTx(amount: -42, date: currentMonthDate(), category: nil)]

        let result = buildContext(transactions: txs)

        #expect(result.uncategorized.txCountCurrentMonth == 1)
        #expect(result.uncategorized.totalCurrentMonth == 42)
    }

    // MARK: - Excluded accounts metadata

    @MainActor @Test func excludedAccounts_listedInMetadata() {
        let normal = makeAccount(name: "Checking")
        let excluded = makeAccount(name: "Savings", excludeFromStatistics: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTx(amount: -100, date: currentMonthDate(), category: food, account: normal),
            makeTx(amount: -500, date: currentMonthDate(), category: food, account: excluded)
        ]

        let result = buildContext(
            transactions: txs,
            accounts: [normal, excluded]
        )

        #expect(result.metadata.excludedAccounts.contains("Savings"))
        // The excluded tx should NOT count
        #expect(result.periods.currentMonth.expense == 100)
    }

    // MARK: - Cache TTL

    @MainActor @Test func cache_within60s_returnsSameContent() {
        let food = makeCategory(name: "Food")
        let firstTxs = [makeTx(amount: -50, date: currentMonthDate(), category: food)]
        let secondTxs = firstTxs + [makeTx(amount: -100, date: currentMonthDate(), category: food)]

        let builder = FullFinancialContextBuilder()
        let now = Date.now
        let first = builder.buildFromArrays(
            transactions: firstTxs,
            budgets: [],
            accounts: [],
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            now: now
        )
        // Second call dentro del TTL — debería retornar cache hit (ignorando secondTxs)
        let second = builder.buildFromArrays(
            transactions: secondTxs,
            budgets: [],
            accounts: [],
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            now: now.addingTimeInterval(30) // dentro del TTL
        )
        #expect(first.periods.currentMonth.expense == second.periods.currentMonth.expense)
        #expect(second.periods.currentMonth.expense == 50)
    }

    // MARK: - Balance adjustments filtered

    @MainActor @Test func balanceAdjustments_excludedFromAggregates() {
        let food = makeCategory(name: "Food")
        let txs = [
            makeTx(amount: -50, date: currentMonthDate(), category: food),
            makeTx(amount: 1000, date: currentMonthDate(), category: food, balanceAdjustmentType: "initial_balance")
        ]

        let result = buildContext(transactions: txs)

        #expect(result.periods.currentMonth.expense == 50)
        #expect(result.periods.currentMonth.income == 0)
    }
}
