//
//  TagSpendingCalculatorTests.swift
//  YalaTests
//
//  Unit tests for TagSpendingCalculator pure logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct TagSpendingCalculatorTests {

    // MARK: - Helpers

    private func makeTag(name: String) -> YalaTag {
        YalaTag(name: name, colorHex: "#000000")
    }

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        category: YalaCategory? = nil,
        tags: [YalaTag]? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            tags: tags ?? [],
            amountInPreferredCurrency: amount
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private var defaultInterval: DateInterval {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }

    // MARK: - Tests

    @Test func emptyTransactions_returnsEmpty() {
        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }

    @Test func singleExpense_singleTag() {
        let tag = makeTag(name: "Food")
        let cat = makeCategory(name: "Groceries")
        let tx = makeTransaction(amount: -100, category: cat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.count == 1)
        #expect(result[0].tag.name == "Food")
        #expect(result[0].percentage == 100)
    }

    @Test func sameTag_sumsAmounts() {
        let tag = makeTag(name: "Food")
        let cat = makeCategory(name: "Groceries")
        let tx1 = makeTransaction(amount: -100, category: cat, tags: [tag])
        let tx2 = makeTransaction(amount: -200, category: cat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.count == 1)
        #expect(result[0].amount == 300)
    }

    @Test func differentTags_sortedDescending() {
        let tagA = makeTag(name: "Small")
        let tagB = makeTag(name: "Big")
        let cat = makeCategory(name: "General")
        let tx1 = makeTransaction(amount: -100, category: cat, tags: [tagA])
        let tx2 = makeTransaction(amount: -500, category: cat, tags: [tagB])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.count == 2)
        #expect(result[0].tag.name == "Big")
        #expect(result[1].tag.name == "Small")
    }

    @Test func percentageCalculation() {
        let tagA = makeTag(name: "A")
        let tagB = makeTag(name: "B")
        let cat = makeCategory(name: "General")
        let tx1 = makeTransaction(amount: -300, category: cat, tags: [tagA])
        let tx2 = makeTransaction(amount: -200, category: cat, tags: [tagB])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result[0].percentage == 60)
        #expect(result[1].percentage == 40)
    }

    @Test func multipleTagsPerTransaction() {
        let tagA = makeTag(name: "A")
        let tagB = makeTag(name: "B")
        let cat = makeCategory(name: "General")
        let tx = makeTransaction(amount: -100, category: cat, tags: [tagA, tagB])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.count == 2)
        #expect(result[0].amount == 100)
        #expect(result[1].amount == 100)
    }

    @Test func outsideInterval_excluded() {
        let tag = makeTag(name: "Food")
        let cat = makeCategory(name: "Groceries")
        let oldDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let tx = makeTransaction(amount: -100, date: oldDate, category: cat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }

    @Test func noCategory_excluded() {
        let tag = makeTag(name: "Food")
        let tx = makeTransaction(amount: -100, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }

    @Test func noTags_excluded() {
        let cat = makeCategory(name: "Groceries")
        let tx = makeTransaction(amount: -100, category: cat)

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }

    @Test func balanceAdjustment_excluded() {
        let tag = makeTag(name: "Food")
        let cat = makeCategory(name: "Groceries")
        let tx = makeTransaction(amount: -100, category: cat, tags: [tag], balanceAdjustmentType: "transfer")

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }

    @Test func incomeExcludedByDefault() {
        let tag = makeTag(name: "Salary")
        let cat = makeCategory(name: "Work", isIncome: true)
        let tx = makeTransaction(amount: 5000, category: cat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }

    @Test func incomeIncludedWhenSpecified() {
        let tag = makeTag(name: "Salary")
        let cat = makeCategory(name: "Work", isIncome: true)
        let tx = makeTransaction(amount: 5000, category: cat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            transactionNatures: [.income]
        )
        #expect(result.count == 1)
    }

    @Test func mixedNatures_bothIncluded() {
        let tag = makeTag(name: "Mixed")
        let expCat = makeCategory(name: "Food")
        let incCat = makeCategory(name: "Work", isIncome: true)
        let tx1 = makeTransaction(amount: -100, category: expCat, tags: [tag])
        let tx2 = makeTransaction(amount: 200, category: incCat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            transactionNatures: [.income, .expense]
        )
        #expect(result.count == 1)
        #expect(result[0].amount == 300)
    }

    @Test func usesAbsoluteAmounts() {
        let tag = makeTag(name: "Food")
        let cat = makeCategory(name: "Groceries")
        let tx = makeTransaction(amount: -250, category: cat, tags: [tag])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result[0].amount == 250)
    }

    @Test func emptyTagsArray_excluded() {
        let cat = makeCategory(name: "Groceries")
        let tx = makeTransaction(amount: -100, category: cat, tags: [])

        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD"
        )
        #expect(result.isEmpty)
    }
}
