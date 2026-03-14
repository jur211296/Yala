//
//  PivotTableCalculatorTests.swift
//  YalaTests
//
//  Unit tests for PivotTableCalculator.
//

import Foundation
import Testing

@testable import Yala

struct PivotTableCalculatorTests {

    // MARK: - Helpers

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeTag(name: String) -> YalaTag {
        YalaTag(name: name, colorHex: "#FF0000")
    }

    private func makeAccount(name: String, currencyCode: String = "USD") -> Account {
        Account(name: name, currencyCode: currencyCode, colorHex: "#000000", iconName: "creditcard", type: "bank")
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        currencyCode: String = "USD",
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        account: Account? = nil,
        tags: [YalaTag] = [],
        amountInPreferredCurrency: Double? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            subcategory: subcategory,
            account: account,
            tags: tags,
            amountInPreferredCurrency: amountInPreferredCurrency ?? amount
        )
        tx.preferredCurrencyCode = "USD"
        return tx
    }

    // MARK: - Single Dimension Tests

    @Test("Single dimension: tipo groups into income and expense")
    func singleDimensionTipo() throws {
        let income = makeCategory(name: "Salary", isIncome: true)
        let expense = makeCategory(name: "Food", isIncome: false)

        let txns = [
            makeTransaction(amount: 1000, category: income),
            makeTransaction(amount: -200, category: expense),
            makeTransaction(amount: -150, category: expense),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: txns,
            previousTransactions: [],
            hierarchy: [.tipo],
            preferredCurrency: "USD"
        )

        #expect(result.count == 2)
        // Income first (sorted by isIncome priority)
        let incomeNode = result.first { $0.isIncome }
        let expenseNode = result.first { !$0.isIncome }
        let incomeResult = try #require(incomeNode)
        let expenseResult = try #require(expenseNode)
        #expect(incomeResult.amount == 1000)
        #expect(expenseResult.amount == -350)
    }

    @Test("Single dimension: categoria groups by category")
    func singleDimensionCategoria() {
        let food = makeCategory(name: "Food", isIncome: false)
        let transport = makeCategory(name: "Transport", isIncome: false)

        let txns = [
            makeTransaction(amount: -100, category: food),
            makeTransaction(amount: -50, category: food),
            makeTransaction(amount: -30, category: transport),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: txns,
            previousTransactions: [],
            hierarchy: [.categoria],
            preferredCurrency: "USD"
        )

        #expect(result.count == 2)
        let foodNode = result.first { $0.label == "Food" }
        #expect(foodNode?.amount == -150)
    }

    // MARK: - Multi-Level Tests

    @Test("Multi-level: tipo > categoria creates nested tree")
    func multiLevelTipoCategoria() {
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food", isIncome: false)
        let transport = makeCategory(name: "Transport", isIncome: false)

        let txns = [
            makeTransaction(amount: 2000, category: salary),
            makeTransaction(amount: -300, category: food),
            makeTransaction(amount: -100, category: transport),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: txns,
            previousTransactions: [],
            hierarchy: [.tipo, .categoria],
            preferredCurrency: "USD"
        )

        #expect(result.count == 2)  // Income + Expense groups
        let incomeNode = result.first { $0.isIncome }
        #expect(incomeNode?.children.count == 1)  // Only Salary
        #expect(incomeNode?.children.first?.label == "Salary")

        let expenseNode = result.first { !$0.isIncome }
        #expect(expenseNode?.children.count == 2)  // Food + Transport
    }

    // MARK: - Tag Fan-out Tests

    @Test("Tag fan-out: transaction with multiple tags appears in each tag group")
    func tagFanOut() {
        let tag1 = makeTag(name: "Work")
        let tag2 = makeTag(name: "Personal")

        let txns = [
            makeTransaction(amount: -100, tags: [tag1, tag2]),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: txns,
            previousTransactions: [],
            hierarchy: [.etiqueta],
            preferredCurrency: "USD"
        )

        #expect(result.count == 2)  // Work + Personal
        let workNode = result.first { $0.label == "Work" }
        let personalNode = result.first { $0.label == "Personal" }
        #expect(workNode?.amount == -100)
        #expect(personalNode?.amount == -100)
    }

    // MARK: - Previous Period Comparison

    @Test("Previous period data shows variation")
    func previousPeriodVariation() throws {
        let food = makeCategory(name: "Food", isIncome: false)

        let currentTxns = [
            makeTransaction(amount: -150, category: food),
        ]
        let previousTxns = [
            makeTransaction(amount: -100, category: food),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: currentTxns,
            previousTransactions: previousTxns,
            hierarchy: [.categoria],
            preferredCurrency: "USD"
        )

        #expect(result.count == 1)
        let foodNode = try #require(result.first)
        #expect(foodNode.amount == -150)
        #expect(foodNode.previousAmount == -100)
        let variation = try #require(foodNode.variation)
        // Variation = ((-150) - (-100)) / abs(-100) * 100 = -50%
        #expect(variation == -50.0)
    }

    @Test("Missing previous data shows nil previousAmount")
    func missingPreviousData() throws {
        let food = makeCategory(name: "Food", isIncome: false)

        let txns = [
            makeTransaction(amount: -100, category: food),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: txns,
            previousTransactions: [],
            hierarchy: [.categoria],
            preferredCurrency: "USD"
        )

        let foodNode = try #require(result.first)
        #expect(foodNode.previousAmount == nil)
        #expect(foodNode.variation == nil)
    }

    // MARK: - Empty Transactions

    @Test("Empty transactions returns empty tree")
    func emptyTransactions() {
        let result = PivotTableCalculator.buildTree(
            currentTransactions: [],
            previousTransactions: [],
            hierarchy: [.tipo],
            preferredCurrency: "USD"
        )

        #expect(result.isEmpty)
    }

    // MARK: - Currency Grouping

    @Test("Grouping by divisa uses original amounts")
    func currencyGrouping() {
        let txns = [
            makeTransaction(amount: -100, currencyCode: "USD", amountInPreferredCurrency: -380),
            makeTransaction(amount: -200, currencyCode: "EUR", amountInPreferredCurrency: -760),
        ]

        let result = PivotTableCalculator.buildTree(
            currentTransactions: txns,
            previousTransactions: [],
            hierarchy: [.divisa],
            preferredCurrency: "PEN"
        )

        #expect(result.count == 2)
        let usdNode = result.first { $0.label == "USD" }
        let eurNode = result.first { $0.label == "EUR" }
        // When grouped by currency, amounts should be in original currency
        #expect(usdNode?.amount == -100)
        #expect(eurNode?.amount == -200)
        #expect(usdNode?.currencyCode == "USD")
        #expect(eurNode?.currencyCode == "EUR")
    }

    // MARK: - Flatten Tests

    @Test("Flatten produces correct levels")
    func flattenLevels() {
        let child = PivotNode(
            label: "Child", iconName: nil, colorHex: nil,
            amount: -50, previousAmount: nil, variation: nil,
            currencyCode: nil, children: [], isIncome: false,
            dimension: .categoria
        )
        let parent = PivotNode(
            label: "Parent", iconName: nil, colorHex: nil,
            amount: -100, previousAmount: nil, variation: nil,
            currencyCode: nil, children: [child], isIncome: false,
            dimension: .tipo
        )

        let rows = PivotTableCalculator.flatten(nodes: [parent])
        #expect(rows.count == 2)
        #expect(rows[0].level == 0)
        #expect(rows[0].node.label == "Parent")
        #expect(rows[1].level == 1)
        #expect(rows[1].node.label == "Child")
    }

    // MARK: - Net Flow Tests

    @Test("Net flow calculation sums root nodes")
    func netFlowCalculation() {
        let incomeNode = PivotNode(
            label: "Income", iconName: nil, colorHex: nil,
            amount: 1000, previousAmount: 800, variation: 25,
            currencyCode: nil, children: [], isIncome: true,
            dimension: .tipo
        )
        let expenseNode = PivotNode(
            label: "Expense", iconName: nil, colorHex: nil,
            amount: -600, previousAmount: -500, variation: 20,
            currencyCode: nil, children: [], isIncome: false,
            dimension: .tipo
        )

        let (current, previous, variation) = PivotTableCalculator.calculateNetFlow(
            currentNodes: [incomeNode, expenseNode],
            previousNodes: [
                PivotNode(label: "Income", iconName: nil, colorHex: nil, amount: 800, previousAmount: nil, variation: nil, currencyCode: nil, children: [], isIncome: true, dimension: .tipo),
                PivotNode(label: "Expense", iconName: nil, colorHex: nil, amount: -500, previousAmount: nil, variation: nil, currencyCode: nil, children: [], isIncome: false, dimension: .tipo),
            ]
        )

        #expect(current == 400)  // 1000 - 600
        #expect(previous == 300)  // 800 - 500
        #expect(variation != nil)
    }
}
