//
//  FilterServiceTests.swift
//  NetoTests
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
        #expect(criteria.activeFilterCount == 0)  // searchText doesn't count in activeFilterCount

        criteria.selectedNatures.insert(.essential)
        #expect(criteria.activeFilterCount == 1)

        criteria.transactionTypeFilter = .expense
        #expect(criteria.activeFilterCount == 2)
    }

    @Test func clearAllResetsCriteria() throws {
        var criteria = FilterCriteria.empty
        criteria.searchText = "test"
        criteria.selectedNatures.insert(.essential)
        criteria.transactionTypeFilter = .expense
        criteria.amountCondition = .greaterThan(100)

        let originalInterval = criteria.dateInterval
        criteria.clearAll()

        #expect(!criteria.hasActiveFilters)
        #expect(criteria.activeFilterCount == 0)
        #expect(criteria.searchText.isEmpty)
        #expect(criteria.selectedNatures.isEmpty)
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
}
