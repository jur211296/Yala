//
//  FilterServiceTests.swift
//  YalaTests
//
//  Tests for FilterService unified filtering logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct FilterServiceTests {

    // MARK: - FilterCriteria Tests

    @Test func emptyCriteriaHasNoActiveFilters() throws {
        let criteria = FilterCriteria.empty
        #expect(!criteria.hasActiveFilters)
        #expect(criteria.activeFilterCount == 0)
    }

    @Test func criteriaWithSearchTextIsActive() throws {
        var criteria = FilterCriteria.empty
        criteria.searchText = "groceries"
        #expect(criteria.hasActiveFilters)
    }

    @Test func criteriaActiveFilterCountIsCorrect() throws {
        var criteria = FilterCriteria.empty
        criteria.searchText = "test"
        #expect(criteria.activeFilterCount == 1)  // searchText counts as active filter

        criteria.selectedNeeds.insert(.essential)
        #expect(criteria.activeFilterCount == 2)

        criteria.transactionTypeFilter = .expense
        #expect(criteria.activeFilterCount == 3)
    }

    @Test func clearAllResetsCriteria() throws {
        var criteria = FilterCriteria.empty
        criteria.searchText = "test"
        criteria.selectedNeeds.insert(.essential)
        criteria.transactionTypeFilter = .expense
        criteria.amountCondition = .greaterThan(100)

        let originalInterval = criteria.dateInterval
        criteria.clearAll()

        #expect(!criteria.hasActiveFilters)
        #expect(criteria.activeFilterCount == 0)
        #expect(criteria.searchText.isEmpty)
        #expect(criteria.selectedNeeds.isEmpty)
        #expect(criteria.transactionTypeFilter == .all)
        #expect(criteria.amountCondition == .any)
        // dateInterval should NOT be cleared
        #expect(criteria.dateInterval == originalInterval)
    }

    // MARK: - FilterService Static Methods

    @Test func groupByDateGroupsCorrectly() throws {
        // This test verifies the groupByDate function logic
        // Since we can't easily create TransactionItem without SwiftData context,
        // we test the function signature and empty case
        let empty: [TransactionItem] = []
        let grouped = FilterService.groupByDate(empty)
        #expect(grouped.isEmpty)
    }

    // MARK: - AmountFilterCondition Tests

    @Test func amountConditionAnyMatchesAll() throws {
        let condition = AmountFilterCondition.any
        #expect(condition.matches(0))
        #expect(condition.matches(100))
        #expect(condition.matches(1_000_000))
    }

    @Test func amountConditionGreaterThanWorks() throws {
        let condition = AmountFilterCondition.greaterThan(100)
        #expect(!condition.matches(50))
        #expect(!condition.matches(100))
        #expect(condition.matches(150))
    }

    @Test func amountConditionLessThanWorks() throws {
        let condition = AmountFilterCondition.lessThan(100)
        #expect(condition.matches(50))
        #expect(!condition.matches(100))
        #expect(!condition.matches(150))
    }

    @Test func amountConditionBetweenWorks() throws {
        let condition = AmountFilterCondition.between(min: 50, max: 150)
        #expect(!condition.matches(25))
        #expect(condition.matches(50))
        #expect(condition.matches(100))
        #expect(condition.matches(150))
        #expect(!condition.matches(200))
    }

    @Test func amountConditionIsActiveProperty() throws {
        #expect(!AmountFilterCondition.any.isActive)
        #expect(AmountFilterCondition.greaterThan(100).isActive)
        #expect(AmountFilterCondition.lessThan(100).isActive)
        #expect(AmountFilterCondition.between(min: 50, max: 150).isActive)
    }

    // MARK: - Exclude Mode: FilterCriteria Tests

    @Test func excludeModeAloneDoesNotActivateFilters() throws {
        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        #expect(!criteria.hasActiveFilters)
        #expect(criteria.activeFilterCount == 0)
    }

    @Test func excludeModePreservedWithActiveFilters() throws {
        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        criteria.selectedAccounts.insert(account.persistentModelID)
        #expect(criteria.hasActiveFilters)
        #expect(criteria.isExcludeMode)
    }

    @Test func activeFilterCountNotAffectedByExcludeMode() throws {
        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let tag = Tag(name: "Tag1", colorHex: "#000", iconName: "tag")
        criteria.selectedAccounts.insert(account.persistentModelID)
        criteria.selectedTags.insert(tag.persistentModelID)
        #expect(criteria.activeFilterCount == 2)
    }

    @Test func clearAllResetsExcludeMode() throws {
        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedNeeds.insert(.essential)
        criteria.selectedAccounts.insert(Account(name: "A", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank").persistentModelID)
        criteria.clearAll()
        #expect(!criteria.isExcludeMode)
        #expect(!criteria.hasActiveFilters)
    }

    // MARK: - Exclude Mode: matchesCriteria Tests

    @Test func excludeAccountFiltersOutMatchingTransaction() throws {
        let accountA = Account(name: "A", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let accountB = Account(name: "B", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let txA = makeTransaction(account: accountA)
        let txB = makeTransaction(account: accountB)

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedAccounts.insert(accountA.persistentModelID)

        #expect(!FilterService.matchesCriteria(txA, criteria: criteria))
        #expect(FilterService.matchesCriteria(txB, criteria: criteria))
    }

    @Test func excludeCategoryFiltersOutMatchingTransaction() throws {
        let catA = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
        let catB = YalaCategory(name: "Transport", colorHex: "#000", isIncome: false)
        let txA = makeTransaction(category: catA)
        let txB = makeTransaction(category: catB)

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedCategories.insert(catA.persistentModelID)

        #expect(!FilterService.matchesCriteria(txA, criteria: criteria))
        #expect(FilterService.matchesCriteria(txB, criteria: criteria))
    }

    @Test func excludeSubcategoryFiltersOutMatchingTransaction() throws {
        let cat = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
        let subA = Subcategory(name: "SubA", colorHex: nil, iconName: "cart", category: cat)
        let subB = Subcategory(name: "SubB", colorHex: nil, iconName: "cart", category: cat)
        let txA = makeTransaction(subcategory: subA)
        let txB = makeTransaction(subcategory: subB)

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedSubcategories.insert(subA.persistentModelID)

        #expect(!FilterService.matchesCriteria(txA, criteria: criteria))
        #expect(FilterService.matchesCriteria(txB, criteria: criteria))
    }

    @Test func excludeNeedFiltersOutMatchingTransaction() throws {
        let cat = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
        let subEssential = Subcategory(name: "SubE", colorHex: nil, natureRawValue: "esencial", iconName: "cart", category: cat)
        let subOptional = Subcategory(name: "SubO", colorHex: nil, natureRawValue: "opcional", iconName: "cart", category: cat)
        let txE = makeTransaction(subcategory: subEssential)
        let txO = makeTransaction(subcategory: subOptional)

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedNeeds.insert(.essential)

        #expect(!FilterService.matchesCriteria(txE, criteria: criteria))
        #expect(FilterService.matchesCriteria(txO, criteria: criteria))
    }

    @Test func excludeTagFiltersOutIfAnyTagMatches() throws {
        let tagA = Tag(name: "TagA", colorHex: "#000", iconName: "tag")
        let tagB = Tag(name: "TagB", colorHex: "#000", iconName: "tag")
        let txAB = makeTransaction(tags: [tagA, tagB])
        let txB = makeTransaction(tags: [tagB])

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedTags.insert(tagA.persistentModelID)
        criteria.populateTagUUIDs(from: [tagA])  // CSV-mirror SSOT

        #expect(!FilterService.matchesCriteria(txAB, criteria: criteria))
        #expect(FilterService.matchesCriteria(txB, criteria: criteria))
    }

    @Test func excludeCurrencyFiltersOutMatchingTransaction() throws {
        let txUSD = makeTransaction(currencyCode: "USD")
        let txPEN = makeTransaction(currencyCode: "PEN")

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.selectedCurrencies.insert(.usd)

        #expect(!FilterService.matchesCriteria(txUSD, criteria: criteria))
        #expect(FilterService.matchesCriteria(txPEN, criteria: criteria))
    }

    @Test func amountConditionNotAffectedByExcludeMode() throws {
        let txSmall = makeTransaction(amount: 50)
        let txBig = makeTransaction(amount: 150)

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.amountCondition = .greaterThan(100)

        // Amount uses inclusion semantics always
        #expect(!FilterService.matchesCriteria(txSmall, criteria: criteria))
        #expect(FilterService.matchesCriteria(txBig, criteria: criteria))
    }

    @Test func searchTextNotAffectedByExcludeMode() throws {
        let txGrocery = makeTransaction(note: "grocery store")
        let txGas = makeTransaction(note: "gas station")

        var criteria = FilterCriteria.empty
        criteria.isExcludeMode = true
        criteria.searchText = "grocery"

        // Search uses inclusion semantics always
        #expect(FilterService.matchesCriteria(txGrocery, criteria: criteria))
        #expect(!FilterService.matchesCriteria(txGas, criteria: criteria))
    }

    // MARK: - Helper

    private func makeTransaction(
        amount: Double = 100,
        currencyCode: String = "PEN",
        note: String? = nil,
        account: Account? = nil,
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        tags: [Yala.Tag] = []
    ) -> TransactionItem {
        TransactionItem(
            date: Date(),
            amount: amount,
            currencyCode: currencyCode,
            note: note,
            category: category,
            subcategory: subcategory,
            account: account,
            tags: tags
        )
    }

    // MARK: - Shared Expense Filter Tests

    @Test func sharedExpenseFilter_personal_excludesShared() {
        let personal = makeTransaction(amount: 100, note: "personal")
        let shared = makeTransaction(amount: 200, note: "shared")
        shared.splitExpenseID = "some-expense"

        var criteria = FilterCriteria()
        criteria.sharedExpenseFilter = .personal

        #expect(FilterService.matchesCriteria(personal, criteria: criteria) == true)
        #expect(FilterService.matchesCriteria(shared, criteria: criteria) == false)
    }

    @Test func sharedExpenseFilter_shared_excludesPersonal() {
        let personal = makeTransaction(amount: 100, note: "personal")
        let shared = makeTransaction(amount: 200, note: "shared")
        shared.splitExpenseID = "some-expense"

        var criteria = FilterCriteria()
        criteria.sharedExpenseFilter = .shared

        #expect(FilterService.matchesCriteria(personal, criteria: criteria) == false)
        #expect(FilterService.matchesCriteria(shared, criteria: criteria) == true)
    }

    @Test func sharedExpenseFilter_all_includesEverything() {
        let personal = makeTransaction(amount: 100, note: "personal")
        let shared = makeTransaction(amount: 200, note: "shared")
        shared.splitExpenseID = "some-expense"

        var criteria = FilterCriteria()
        criteria.sharedExpenseFilter = .all

        #expect(FilterService.matchesCriteria(personal, criteria: criteria) == true)
        #expect(FilterService.matchesCriteria(shared, criteria: criteria) == true)
    }

    @Test func hasActiveFilters_trueWhenSharedFilterSet() {
        var criteria = FilterCriteria()
        #expect(criteria.hasActiveFilters == false)

        criteria.sharedExpenseFilter = .personal
        #expect(criteria.hasActiveFilters == true)
    }

    @Test func clearAll_resetsSharedFilter() {
        var criteria = FilterCriteria()
        criteria.sharedExpenseFilter = .shared
        criteria.clearAll()
        #expect(criteria.sharedExpenseFilter == .all)
    }
}
