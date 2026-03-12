//
//  SubcategoryTransferViewModelTests.swift
//  YalaTests
//
//  Unit tests for SubcategoryTransferViewModel state and filtering logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct SubcategoryTransferViewModelTests {

    // MARK: - Helpers

    private func makeCategory(name: String, isIncome: Bool = false, sortOrder: Int = 0) -> YalaCategory {
        let cat = YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
        cat.sortOrder = sortOrder
        return cat
    }

    private func makeSubcategory(
        name: String,
        category: YalaCategory,
        isVisible: Bool = true
    ) -> Subcategory {
        Subcategory(
            name: name,
            colorHex: nil,
            isVisible: isVisible,
            category: category
        )
    }

    // MARK: - Initial State

    @MainActor @Test func initialState_empty() {
        let vm = SubcategoryTransferViewModel()
        #expect(vm.allSubcategories.isEmpty)
        #expect(vm.allCategories.isEmpty)
    }

    // MARK: - loadData without context

    @MainActor @Test func loadData_withoutContext_keepsEmpty() {
        let vm = SubcategoryTransferViewModel()
        vm.loadData()
        #expect(vm.allSubcategories.isEmpty)
        #expect(vm.allCategories.isEmpty)
    }

    // MARK: - transactionCount without context

    @MainActor @Test func transactionCount_withoutContext_returnsZero() {
        let vm = SubcategoryTransferViewModel()
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Groceries", category: cat)
        #expect(vm.transactionCount(for: sub) == 0)
    }

    // MARK: - availableDestinations filtering logic (standalone)

    @Test func filteringLogic_excludesSelf() {
        let cat = makeCategory(name: "Food")
        let sub1 = makeSubcategory(name: "Groceries", category: cat)
        let sub2 = makeSubcategory(name: "Restaurants", category: cat)

        let allSubs = [sub1, sub2]
        let filtered = allSubs.filter { $0.persistentModelID != sub1.persistentModelID }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "Restaurants")
    }

    @Test func filteringLogic_excludesHidden() {
        let cat = makeCategory(name: "Food")
        let visible = makeSubcategory(name: "Groceries", category: cat)
        let hidden = makeSubcategory(name: "Old", category: cat, isVisible: false)

        let allSubs = [visible, hidden]
        let filtered = allSubs.filter { $0.isVisible }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "Groceries")
    }

    @Test func filteringLogic_matchesIncomeType() {
        let expenseCat = makeCategory(name: "Food", isIncome: false)
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let expSub = makeSubcategory(name: "Groceries", category: expenseCat)
        let incSub = makeSubcategory(name: "Job", category: incomeCat)

        // When deleting an expense subcategory, only show other expense subcategories
        let parentIsIncome = false
        let allSubs = [expSub, incSub]
        let filtered = allSubs.filter { $0.safeCategory.isIncome == parentIsIncome }

        #expect(filtered.count == 1)
        #expect(filtered[0].name == "Groceries")
    }

    @Test func filteringLogic_groupsByCategory() {
        let cat1 = makeCategory(name: "Food", sortOrder: 0)
        let cat2 = makeCategory(name: "Transport", sortOrder: 1)
        let sub1 = makeSubcategory(name: "Groceries", category: cat1)
        let sub2 = makeSubcategory(name: "Bus", category: cat2)
        let sub3 = makeSubcategory(name: "Dining", category: cat1)

        let allSubs = [sub1, sub2, sub3]
        let grouped = Dictionary(grouping: allSubs) { $0.safeCategory.persistentModelID }

        #expect(grouped.count == 2)
    }

    // MARK: - getOrCreateUnassignedSubcategory without context

    @MainActor @Test func getOrCreateUnassigned_withoutContext_returnsNil() {
        let vm = SubcategoryTransferViewModel()
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Groceries", category: cat)
        #expect(vm.getOrCreateUnassignedSubcategory(for: sub) == nil)
    }
}
