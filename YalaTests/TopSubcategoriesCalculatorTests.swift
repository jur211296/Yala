//
//  TopSubcategoriesCalculatorTests.swift
//  YalaTests
//
//  Unit tests for TopSubcategoriesCalculator pure logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct TopSubcategoriesCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeSubcategory(name: String, category: YalaCategory) -> Subcategory {
        Subcategory(
            name: name,
            colorHex: "#00FF00",
            category: category
        )
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        currencyCode: String = "USD",
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            subcategory: subcategory,
            tags: [],
            amountInPreferredCurrency: amount
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

    // MARK: - Tests

    @Test func empty_returnsEmpty() {
        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func singleSubcategory_100PercentOfTotalAndCategory() {
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Restaurants", category: cat)
        let tx = makeTransaction(amount: -100, category: cat, subcategory: sub)

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].subcategoryName == "Restaurants")
        #expect(result[0].amount == 100)
        #expect(result[0].percentageOfTotal == 100)
        #expect(result[0].percentageOfCategory == 100)
    }

    @Test func noSubcategory_usesNoSubcategoryName() {
        let cat = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -100, category: cat) // No subcategory

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].subcategoryName == L10n.Subcategory.noSubcategory)
        #expect(result[0].subcategory == nil)
    }

    @Test func twoSubcategories_sameCategory_correctPercentages() {
        let cat = makeCategory(name: "Food")
        let subA = makeSubcategory(name: "Restaurants", category: cat)
        let subB = makeSubcategory(name: "Groceries", category: cat)
        let tx1 = makeTransaction(amount: -300, category: cat, subcategory: subA)
        let tx2 = makeTransaction(amount: -200, category: cat, subcategory: subB)

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 2)
        // Total = 500; Restaurants = 300 (60%), Groceries = 200 (40%)
        #expect(result[0].subcategoryName == "Restaurants")
        #expect(result[0].percentageOfTotal == 60)
        #expect(result[0].percentageOfCategory == 60) // Same category, so same as total

        #expect(result[1].subcategoryName == "Groceries")
        #expect(result[1].percentageOfTotal == 40)
        #expect(result[1].percentageOfCategory == 40)
    }

    @Test func sortedByAmountDescending() {
        let cat = makeCategory(name: "Food")
        let subSmall = makeSubcategory(name: "Coffee", category: cat)
        let subBig = makeSubcategory(name: "Restaurants", category: cat)
        let tx1 = makeTransaction(amount: -50, category: cat, subcategory: subSmall)
        let tx2 = makeTransaction(amount: -500, category: cat, subcategory: subBig)

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result[0].subcategoryName == "Restaurants")
        #expect(result[1].subcategoryName == "Coffee")
    }

    @Test func balanceAdjustments_excluded() {
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Restaurants", category: cat)
        let tx = makeTransaction(
            amount: -100,
            category: cat,
            subcategory: sub,
            balanceAdjustmentType: TransactionItem.adjustmentTypeTransfer
        )

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func multiCurrency_conversionApplied() {
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Restaurants", category: cat)
        let tx = makeTransaction(amount: -50, currencyCode: "EUR", category: cat, subcategory: sub)
        tx.preferredCurrencyCode = "EUR" // Different from target "USD"

        var converter = MockCurrencyConverter()
        converter.fixedRate = 2.0

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: converter
        )

        #expect(result.count == 1)
        #expect(result[0].amount == 100) // 50 * 2.0
    }

    @Test func categoryFilter_percentageOfTotal_usesGlobalTotal() throws {
        // Two categories: Food ($500) and Transport ($200) → global total = $700
        let foodCat = makeCategory(name: "Food")
        let transportCat = makeCategory(name: "Transport")
        let subRestaurants = makeSubcategory(name: "Restaurants", category: foodCat)
        let subGroceries = makeSubcategory(name: "Groceries", category: foodCat)
        let subGas = makeSubcategory(name: "Gas", category: transportCat)

        let tx1 = makeTransaction(amount: -300, category: foodCat, subcategory: subRestaurants)
        let tx2 = makeTransaction(amount: -200, category: foodCat, subcategory: subGroceries)
        let tx3 = makeTransaction(amount: -200, category: transportCat, subcategory: subGas)

        // Filter by Food category only
        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx1, tx2, tx3],
            interval: defaultInterval,
            currencyCode: "USD",
            categoryFilter: foodCat.persistentModelID,
            converter: MockCurrencyConverter()
        )

        // Should only return Food subcategories
        #expect(result.count == 2)

        // Restaurants: $300 of $500 Food = 60% of category, $300 of $700 global ≈ 42.86% of total
        let restaurants = try #require(result.first { $0.subcategoryName == "Restaurants" })
        #expect(restaurants.percentageOfCategory == 60)
        #expect(abs(restaurants.percentageOfTotal - 42.857) < 0.01)

        // Groceries: $200 of $500 Food = 40% of category, $200 of $700 global ≈ 28.57% of total
        let groceries = try #require(result.first { $0.subcategoryName == "Groceries" })
        #expect(groceries.percentageOfCategory == 40)
        #expect(abs(groceries.percentageOfTotal - 28.571) < 0.01)

        // Key assertion: percentageOfTotal != percentageOfCategory
        #expect(restaurants.percentageOfTotal != restaurants.percentageOfCategory)
    }

    @Test func categoryFilter_noFilter_percentagesMatch() {
        // With single category and no filter, percentageOfTotal == percentageOfCategory
        let cat = makeCategory(name: "Food")
        let subA = makeSubcategory(name: "Restaurants", category: cat)
        let subB = makeSubcategory(name: "Groceries", category: cat)
        let tx1 = makeTransaction(amount: -300, category: cat, subcategory: subA)
        let tx2 = makeTransaction(amount: -200, category: cat, subcategory: subB)

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        // With single category, both percentages should be the same
        #expect(result[0].percentageOfTotal == result[0].percentageOfCategory)
        #expect(result[1].percentageOfTotal == result[1].percentageOfCategory)
    }

    @Test func incomeExcludedByDefault() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let sub = makeSubcategory(name: "Wages", category: incomeCat)
        let tx = makeTransaction(amount: 5000, category: incomeCat, subcategory: sub)

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }
}

/*
Tests (10):
1. empty_returnsEmpty - Empty input returns empty array
2. singleSubcategory_100PercentOfTotalAndCategory - Single subcategory gets 100% on both axes
3. noSubcategory_usesNoSubcategoryName - Missing subcategory shows localized "No subcategory" name
4. twoSubcategories_sameCategory_correctPercentages - Correct percentages for multiple subcategories
5. sortedByAmountDescending - Results sorted by amount descending
6. balanceAdjustments_excluded - Balance adjustments are filtered out
7. multiCurrency_conversionApplied - Currency conversion uses MockCurrencyConverter rate
8. incomeExcludedByDefault - Income categories excluded when no transactionNatures specified
9. categoryFilter_percentageOfTotal_usesGlobalTotal - With categoryFilter, pctTotal uses global total
10. categoryFilter_noFilter_percentagesMatch - Without filter, pctTotal == pctCategory for single category
*/
