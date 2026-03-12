//
//  SubcategorySelectorViewModelTests.swift
//  YalaTests
//
//  Tests for SubcategorySelectorViewModel state management and transaction type handling.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct SubcategorySelectorViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_allSubcategoriesEmpty() {
        let vm = SubcategorySelectorViewModel()
        #expect(vm.allSubcategories.isEmpty)
    }

    @MainActor @Test func initialState_recentTransactionsEmpty() {
        let vm = SubcategorySelectorViewModel()
        #expect(vm.recentTransactions.isEmpty)
    }

    @MainActor @Test func initialState_transactionTypeExpense() {
        let vm = SubcategorySelectorViewModel()
        #expect(vm.transactionType == .expense)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = SubcategorySelectorViewModel()
        #expect(vm.isEmpty == true)
    }

    // MARK: - Transaction Type

    @MainActor @Test func transactionType_canBeSetToIncome() {
        let vm = SubcategorySelectorViewModel()
        vm.transactionType = .income
        #expect(vm.transactionType == .income)
    }

    @MainActor @Test func transactionType_canBeSetToTransfer() {
        let vm = SubcategorySelectorViewModel()
        vm.transactionType = .transfer
        #expect(vm.transactionType == .transfer)
    }

    // MARK: - Computed Properties with Empty Data

    @MainActor @Test func groupedSubcategories_emptyData_returnsEmpty() {
        let vm = SubcategorySelectorViewModel()
        #expect(vm.groupedSubcategories.isEmpty)
    }

    @MainActor @Test func recentSubcategories_emptyData_returnsEmpty() {
        let vm = SubcategorySelectorViewModel()
        #expect(vm.recentSubcategories.isEmpty)
    }

    // MARK: - Transfer Type

    @MainActor @Test func isEmpty_transferType_alwaysTrue() {
        // Transfers don't show subcategories, so groupedSubcategories always returns empty
        let vm = SubcategorySelectorViewModel()
        vm.transactionType = .transfer
        #expect(vm.isEmpty == true)
        #expect(vm.groupedSubcategories.isEmpty)
    }
}

/*
Tests generated:
1. initialState_allSubcategoriesEmpty - Subcategories start empty
2. initialState_recentTransactionsEmpty - Recent transactions start empty
3. initialState_transactionTypeExpense - Default type is expense
4. initialState_isEmptyTrue - isEmpty true initially
5. transactionType_canBeSetToIncome - Set type to income
6. transactionType_canBeSetToTransfer - Set type to transfer
7. groupedSubcategories_emptyData_returnsEmpty - Empty grouped list
8. recentSubcategories_emptyData_returnsEmpty - Empty recent list
9. isEmpty_transferType_alwaysTrue - Transfer type shows no subcategories

Cases NOT covered (require ModelContext or private(set) data):
- recentSubcategories dedup logic with actual transactions (recentTransactions is private(set))
- recentSubcategories limit of 8 (recentTransactions is private(set))
- recentSubcategories filtering by transaction type (recentTransactions is private(set))
- groupedSubcategories filtering by income/expense (allSubcategories is private(set))
- groupedSubcategories sorting by category sortOrder (allSubcategories is private(set))
- loadData / loadSubcategories / loadRecentTransactions (requires ModelContext)

RECOMMENDATION: Extract recentSubcategories and groupedSubcategories into static functions
accepting [Subcategory], [TransactionItem], and TransactionType parameters.
This would enable comprehensive testing of the dedup, filtering, grouping, and limit logic.
*/
