//
//  SankeyFlowCalculatorTests.swift
//  YalaTests
//
//  Unit tests for SankeyFlowCalculator pure logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct SankeyFlowCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(
        name: String,
        isIncome: Bool = false,
        colorHex: String = "#FF0000"
    ) -> YalaCategory {
        YalaCategory(name: name, colorHex: colorHex, isIncome: isIncome)
    }

    private func makeSubcategory(
        name: String,
        category: YalaCategory,
        colorHex: String? = "#00FF00"
    ) -> Subcategory {
        Subcategory(name: name, colorHex: colorHex, category: category)
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        category: YalaCategory?,
        subcategory: Subcategory? = nil,
        balanceAdjustmentType: String? = nil,
        amountInPreferred: Double? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            subcategory: subcategory,
            tags: [],
            amountInPreferredCurrency: amountInPreferred ?? amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private var defaultInterval: DateInterval {
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: now)!
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }

    // MARK: - Empty / hasFlow

    @Test func compute_emptyTransactions_returnsEmpty() {
        let result = SankeyFlowCalculator.compute(
            transactions: [],
            interval: defaultInterval
        )
        #expect(result == .empty)
        #expect(result.hasFlow == false)
    }

    @Test func compute_hasFlow_trueWhenAnyData() {
        let cat = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -100, category: cat)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        #expect(result.hasFlow == true)
    }

    @Test func compute_hasFlow_falseWhenEmpty() {
        let result = SankeyFlowCalculator.compute(
            transactions: [],
            interval: defaultInterval
        )
        #expect(result.hasFlow == false)
    }

    // MARK: - Column population

    @Test func compute_onlyIncome_fillsCol0AndAvailable() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let base = makeSubcategory(name: "Base", category: salary)
        let bonus = makeSubcategory(name: "Bonus", category: salary)
        let txs = [
            makeTransaction(amount: 1000, category: salary, subcategory: base),
            makeTransaction(amount: 500, category: salary, subcategory: bonus)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )

        #expect(result.totalIncome == 1500)
        #expect(result.totalExpense == 0)
        #expect(result.pool == 0)
        // Col 0 = 2 income subcats. Col 1 = "Disponible" only (no "Gastos", pool == 0).
        #expect(result.nodes(in: .income).count == 2)
        let poolNodes = result.nodes(in: .pool)
        #expect(poolNodes.count == 1)
        #expect(poolNodes.first?.name == L10n.Statistics.Sankey.available)
        #expect(poolNodes.first?.amount == 1500)
        #expect(result.nodes(in: .expenseCategory).isEmpty)
        #expect(result.nodes(in: .expenseSubcategory).isEmpty)
        // Links: income → Disponible (2 links).
        #expect(result.links.count == 2)
    }

    @Test func compute_onlyExpense_fillsCol2AndCol3() {
        let food = makeCategory(name: "Food")
        let restaurants = makeSubcategory(name: "Restaurants", category: food)
        let txs = [
            makeTransaction(amount: -100, category: food, subcategory: restaurants)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 100)
        #expect(result.pool == 0)
        // No income, no pool nodes (pool == 0 and surplus == 0).
        #expect(result.nodes(in: .income).isEmpty)
        #expect(result.nodes(in: .pool).isEmpty)
        #expect(result.nodes(in: .expenseCategory).count == 1)
        #expect(result.nodes(in: .expenseSubcategory).count == 1)
        // Only cat→subcat link.
        #expect(result.links.count == 1)
    }

    // MARK: - Income column — subcategories + orphans

    @Test func compute_incomeBySubcategory_usesSubcatName() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let base = makeSubcategory(name: "Base", category: salary)
        let tx = makeTransaction(amount: 1000, category: salary, subcategory: base)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        let incomeNode = result.nodes(in: .income).first
        #expect(incomeNode?.name == "Base")
    }

    @Test func compute_incomeWithoutSubcategory_usesParentCatName() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let tx = makeTransaction(amount: 1000, category: salary, subcategory: nil)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        let incomeNode = result.nodes(in: .income).first
        #expect(incomeNode?.name == "Salary")
        #expect(incomeNode?.persistentID == nil) // orphan node
    }

    @Test func compute_mixedIncome_includesBothSubcatsAndOrphans() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let base = makeSubcategory(name: "Base", category: salary)
        let freelance = makeCategory(name: "Freelance", isIncome: true)
        let txs = [
            makeTransaction(amount: 800, category: salary, subcategory: base),
            makeTransaction(amount: 300, category: freelance, subcategory: nil)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        let names = result.nodes(in: .income).map(\.name).sorted()
        #expect(names == ["Base", "Freelance"])
    }

    // MARK: - Pool — Gastos + Disponible

    @Test func compute_expenseEqualsIncome_onlyGastosNoAvailable() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 500, category: salary),
            makeTransaction(amount: -500, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        let pool = result.nodes(in: .pool)
        #expect(pool.count == 1)
        #expect(pool.first?.name == L10n.Statistics.Sankey.expenses)
    }

    @Test func compute_surplus_createsAvailableNode() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        let pool = result.nodes(in: .pool)
        #expect(pool.count == 2)
        #expect(pool.first { $0.name == L10n.Statistics.Sankey.expenses }?.amount == 300)
        #expect(pool.first { $0.name == L10n.Statistics.Sankey.available }?.amount == 700)
    }

    @Test func compute_expenseGreaterThanIncome_noAvailableNode() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 500, category: salary),
            makeTransaction(amount: -800, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        let pool = result.nodes(in: .pool)
        #expect(pool.count == 1)
        #expect(pool.first?.name == L10n.Statistics.Sankey.expenses)
        #expect(pool.first?.amount == 500) // capped at income
        #expect(result.totalIncome == 500)
        #expect(result.totalExpense == 800)
    }

    // MARK: - Guards

    @Test func compute_ignoresBalanceAdjustments() {
        let food = makeCategory(name: "Food")
        let salary = makeCategory(name: "Salary", isIncome: true)
        let txs = [
            makeTransaction(amount: -100, category: food, balanceAdjustmentType: "manual"),
            makeTransaction(amount: 200, category: salary, balanceAdjustmentType: "manual"),
            makeTransaction(amount: -50, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 50)
    }

    @Test func compute_ignoresTxOutsideInterval() {
        let food = makeCategory(name: "Food")
        let oldDate = calendar.date(byAdding: .day, value: -60, to: Date())!
        let recentDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let txs = [
            makeTransaction(amount: -1000, date: oldDate, category: food),
            makeTransaction(amount: -100, date: recentDate, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        #expect(result.totalExpense == 100)
    }

    @Test func compute_ignoresTxWithoutCategory() {
        let tx = makeTransaction(amount: -100, category: nil)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        #expect(result.hasFlow == false)
    }

    // MARK: - Top-N + "Otros"

    @Test func compute_topN_groupsRemainderInOtros() {
        // 14 expense categories (top 12 + 2 in "Otros").
        let categories = (0..<14).map { makeCategory(name: "Cat\($0)") }
        let txs = categories.enumerated().map { (i, cat) in
            makeTransaction(amount: -Double(100 - i), category: cat)
        }
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            maxPerColumn: 12
        )
        let expenseNodes = result.nodes(in: .expenseCategory)
        #expect(expenseNodes.count == 13)
        #expect(expenseNodes.last?.isOtros == true)
        // Top 12 = Cat0..Cat11 (amounts 100..89). Remainder = Cat12 (88) + Cat13 (87) = 175.
        #expect(expenseNodes.last?.amount == 175)
    }

    @Test func compute_topN_noRemainder_noOtrosNode() {
        let categories = (0..<5).map { makeCategory(name: "Cat\($0)") }
        let txs = categories.map { makeTransaction(amount: -100, category: $0) }
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            maxPerColumn: 12
        )
        let expenseNodes = result.nodes(in: .expenseCategory)
        #expect(expenseNodes.count == 5)
        #expect(expenseNodes.contains(where: { $0.isOtros }) == false)
    }

    // MARK: - Pool semantics (totals)

    @Test func compute_poolEqualsMinIncomeExpense() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        #expect(result.pool == 300)
    }

    // MARK: - Sorting & colors

    @Test func compute_nodes_sortedByAmountDescending() {
        let small = makeCategory(name: "Small")
        let big = makeCategory(name: "Big")
        let txs = [
            makeTransaction(amount: -50, category: small),
            makeTransaction(amount: -200, category: big)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        let nodes = result.nodes(in: .expenseCategory)
        #expect(nodes.first?.name == "Big")
        #expect(nodes.last?.name == "Small")
    }

    @Test func compute_nodeColors_fromCategoryHex() {
        let food = makeCategory(name: "Food", colorHex: "#ABC123")
        let tx = makeTransaction(amount: -100, category: food)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        let node = result.nodes(in: .expenseCategory).first
        #expect(node?.colorHex == "#ABC123")
    }

    @Test func compute_subcategoryColor_fallbackToParent() {
        let food = makeCategory(name: "Food", colorHex: "#AAAAAA")
        let sub = makeSubcategory(name: "Sub", category: food, colorHex: nil)
        let tx = makeTransaction(amount: -100, category: food, subcategory: sub)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        let subNode = result.nodes(in: .expenseSubcategory).first
        #expect(subNode?.colorHex == "#AAAAAA")
    }

    // MARK: - Links

    @Test func compute_linkCatToSubcat_usesSubcatAmount() {
        let food = makeCategory(name: "Food")
        let restaurants = makeSubcategory(name: "Restaurants", category: food)
        let tx = makeTransaction(amount: -75, category: food, subcategory: restaurants)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        // Without income there's no pool → only cat→subcat link.
        #expect(result.links.count == 1)
        #expect(result.links.first?.amount == 75)
    }

    @Test func compute_incomeLinks_splitBetweenGastosAndAvailable() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -400, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        // Expect 1 income node with 2 outgoing links (to Gastos and to Disponible).
        let incToGastos = result.links.first { $0.targetID == "pool_expenses" }
        let incToAvailable = result.links.first { $0.targetID == "pool_available" }
        #expect(incToGastos?.amount == 400)
        #expect(incToAvailable?.amount == 600)
    }

    @Test func compute_gastosToExpenseLinks_sumToPool() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let transport = makeCategory(name: "Transport")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food),
            makeTransaction(amount: -200, category: transport)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        let gastosToExpense = result.links.filter { $0.sourceID == "pool_expenses" }
        let sum = gastosToExpense.reduce(0.0) { $0 + $1.amount }
        #expect(abs(sum - result.pool) < 0.01)
    }

    // MARK: - Tappability

    @Test func compute_incomeNodes_notTappable() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let tx = makeTransaction(amount: 1000, category: salary)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        let incomeNode = result.nodes(in: .income).first
        #expect(incomeNode?.isTappable == false)
    }

    @Test func compute_expenseNodes_areTappable() {
        let food = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Sub", category: food)
        let tx = makeTransaction(amount: -100, category: food, subcategory: sub)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        #expect(result.nodes(in: .expenseCategory).first?.isTappable == true)
        #expect(result.nodes(in: .expenseSubcategory).first?.isTappable == true)
    }

    @Test func compute_poolNodes_notTappable() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -400, category: food)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval
        )
        for p in result.nodes(in: .pool) {
            #expect(p.isTappable == false)
        }
    }

    @Test func compute_otrosNode_notTappable() {
        let categories = (0..<14).map { makeCategory(name: "C\($0)") }
        let txs = categories.enumerated().map { (i, cat) in
            makeTransaction(amount: -Double(100 - i), category: cat)
        }
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            maxPerColumn: 12
        )
        let otros = result.nodes(in: .expenseCategory).first { $0.isOtros }
        #expect(otros?.isTappable == false)
    }

    // MARK: - Snapshot-based amount

    // MARK: - Parent linking (view-filter enabler)

    @Test func compute_subcatNodes_carryParentCategoryID() {
        let food = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Restaurants", category: food)
        let tx = makeTransaction(amount: -100, category: food, subcategory: sub)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        let subNode = result.nodes(in: .expenseSubcategory).first
        let parentNode = result.nodes(in: .expenseCategory).first
        #expect(subNode?.parentCategoryID != nil)
        #expect(subNode?.parentCategoryID == parentNode?.persistentID)
    }

    @Test func compute_usesAmountInPreferredCurrencySnapshot() {
        let food = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -100, category: food, amountInPreferred: -250)
        let result = SankeyFlowCalculator.compute(
            transactions: [tx],
            interval: defaultInterval
        )
        #expect(result.totalExpense == 250)
    }

    // MARK: - Planificados branch (unified)

    @Test func compute_plannedDefault_emptyArrayMatchesBaseline() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let baseline = SankeyFlowCalculator.compute(transactions: txs, interval: defaultInterval)
        let withEmptyPlanned = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: []
        )
        #expect(baseline == withEmptyPlanned)
    }

    @Test func compute_plannedSingle_underSurplus_addsPlannedNode() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let planned = [PlannedOccurrence(amount: 200, kind: .recurring, categoryID: nil)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned
        )
        let pool = result.nodes(in: .pool)
        let plannedNode = pool.first { $0.id == "pool_planned" }
        let availableNode = pool.first { $0.id == "pool_available" }
        #expect(plannedNode?.amount == 200)
        // surplus was 700, planned took 200 → available 500
        #expect(availableNode?.amount == 500)
    }

    @Test func compute_plannedExceedsSurplus_caps_disponibleZero() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let planned = [PlannedOccurrence(amount: 1500, kind: .recurring, categoryID: nil)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned
        )
        let pool = result.nodes(in: .pool)
        let plannedNode = pool.first { $0.id == "pool_planned" }
        let availableNode = pool.first { $0.id == "pool_available" }
        // Cap at surplus = 700
        #expect(plannedNode?.amount == 700)
        // Disponible = 0 → no node emitted (amount-zero nodes are filtered)
        #expect(availableNode == nil)
    }

    @Test func compute_plannedEqualsSurplus_disponibleNotEmitted() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let planned = [PlannedOccurrence(amount: 700, kind: .recurring, categoryID: nil)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned
        )
        let pool = result.nodes(in: .pool)
        #expect(pool.first { $0.id == "pool_planned" }?.amount == 700)
        #expect(pool.first { $0.id == "pool_available" } == nil)
    }

    @Test func compute_planned_noIncome_producesNoLinks() {
        let food = makeCategory(name: "Food")
        let txs = [makeTransaction(amount: -100, category: food)]
        let planned = [PlannedOccurrence(amount: 50, kind: .recurring, categoryID: nil)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned
        )
        // No income → surplus=0 → plannedShown=0 → no planned node, no income→planned links
        #expect(result.nodes(in: .pool).first { $0.id == "pool_planned" } == nil)
        let plannedLinks = result.links.filter { $0.targetID == "pool_planned" }
        #expect(plannedLinks.isEmpty)
    }

    // MARK: - Planificados branch (split by kind)

    @Test func compute_plannedSplitByKind_producesTwoNodes() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let planned = [
            PlannedOccurrence(amount: 100, kind: .recurring, categoryID: nil),
            PlannedOccurrence(amount: 50, kind: .subscription, categoryID: nil)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned,
            plannedSplit: .byKind
        )
        let pool = result.nodes(in: .pool)
        #expect(pool.first { $0.id == "pool_planned_recurring" }?.amount == 100)
        #expect(pool.first { $0.id == "pool_planned_subscription" }?.amount == 50)
        // Unified node should NOT exist when split is byKind.
        #expect(pool.first { $0.id == "pool_planned" } == nil)
    }

    @Test func compute_plannedSplitByKind_singleKind_producesSingleNode() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let planned = [PlannedOccurrence(amount: 100, kind: .recurring, categoryID: nil)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned,
            plannedSplit: .byKind
        )
        let pool = result.nodes(in: .pool)
        #expect(pool.first { $0.id == "pool_planned_recurring" }?.amount == 100)
        #expect(pool.first { $0.id == "pool_planned_subscription" } == nil)
    }

    @Test func compute_plannedSplitByKind_capPreservesRatio() {
        // surplus = 100, planned = 200 (recurring 150 + subscription 50)
        // Expected: cap to 100, preserve ratio recurring:subscription = 3:1
        // → recurringShown = 75, subscriptionShown = 25
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -900, category: food)
        ]
        let planned = [
            PlannedOccurrence(amount: 150, kind: .recurring, categoryID: nil),
            PlannedOccurrence(amount: 50, kind: .subscription, categoryID: nil)
        ]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned,
            plannedSplit: .byKind
        )
        let pool = result.nodes(in: .pool)
        let recurring = pool.first { $0.id == "pool_planned_recurring" }?.amount ?? 0
        let subscription = pool.first { $0.id == "pool_planned_subscription" }?.amount ?? 0
        #expect(abs(recurring - 75) < 0.01)
        #expect(abs(subscription - 25) < 0.01)
        #expect(abs((recurring + subscription) - 100) < 0.01)
    }

    // MARK: - Planificados branch (propagation to categories)

    @Test func compute_plannedPropagation_createsLinkToExistingCat() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        let foodID = food.persistentModelID
        let planned = [PlannedOccurrence(amount: 100, kind: .recurring, categoryID: foodID)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned,
            propagatePlannedToCategories: true
        )
        let foodCatNode = result.nodes(in: .expenseCategory).first { $0.persistentID == foodID }
        #expect(foodCatNode != nil)
        let plannedToFood = result.links.first {
            $0.sourceID == "pool_planned" && $0.targetID == foodCatNode?.id
        }
        #expect(plannedToFood?.amount == 100)
    }

    @Test func compute_plannedPropagation_categoryWithoutExpenses_doesNotCreateNode() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")
        let entertainment = makeCategory(name: "Entertainment")
        let txs = [
            makeTransaction(amount: 1000, category: salary),
            makeTransaction(amount: -300, category: food)
        ]
        // Planned points at "entertainment" which has no real expense → category node should NOT spawn.
        let entertainmentID = entertainment.persistentModelID
        let planned = [PlannedOccurrence(amount: 100, kind: .recurring, categoryID: entertainmentID)]
        let result = SankeyFlowCalculator.compute(
            transactions: txs,
            interval: defaultInterval,
            plannedPending: planned,
            propagatePlannedToCategories: true
        )
        let entertainmentCatNode = result.nodes(in: .expenseCategory).first {
            $0.persistentID == entertainmentID
        }
        #expect(entertainmentCatNode == nil)
        // Branch terminates at column 1 (no link to expense cats from the planned node).
        let danglingLinks = result.links.filter { $0.sourceID == "pool_planned" }
        #expect(danglingLinks.isEmpty)
    }
}
