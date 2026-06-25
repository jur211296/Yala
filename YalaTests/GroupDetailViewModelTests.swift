//
//  GroupDetailViewModelTests.swift
//  YalaTests
//
//  Tests for GroupDetailViewModel — initial state, computed properties, helpers.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupDetailViewModelTests {

    // MARK: - Helpers

    private func makeGroup(name: String = "Test", simplifyDebts: Bool = false) -> SplitGroup {
        SplitGroup(name: name, simplifyDebts: simplifyDebts)
    }

    // MARK: - Initial State

    @Test func initialState_hasGroupButNoData() {
        let group = makeGroup(name: "Viaje Lima")
        let vm = GroupDetailViewModel(group: group)

        #expect(vm.group.name == "Viaje Lima")
        #expect(vm.members.isEmpty)
        #expect(vm.expenses.isEmpty)
        #expect(vm.shares.isEmpty)
        #expect(vm.settlements.isEmpty)
        #expect(vm.balances.isEmpty)
        #expect(vm.debts.isEmpty)
        #expect(vm.memberNameLookup.isEmpty)
        #expect(vm.activeSheet == nil)
        #expect(vm.shareURL == nil)
        #expect(vm.isCreatingShare == false)
    }

    // MARK: - Computed Properties

    @Test func currentUserMember_noMembers_returnsNil() {
        let vm = GroupDetailViewModel(group: makeGroup())
        #expect(vm.currentUserMember == nil)
    }

    @Test func isCurrentUserAdmin_noMembers_returnsFalse() {
        let vm = GroupDetailViewModel(group: makeGroup())
        #expect(vm.isCurrentUserAdmin == false)
    }

    // MARK: - memberName Lookup

    @Test func memberName_unknownID_returnsFallback() {
        let vm = GroupDetailViewModel(group: makeGroup())
        let result = vm.memberName(for: "unknown-id")
        #expect(result == "unknown-id")
    }

    // MARK: - sharesForExpense

    @Test func sharesForExpense_noShares_returnsEmpty() {
        let vm = GroupDetailViewModel(group: makeGroup())
        let expense = SplitExpense(groupZoneID: "test", amount: 100, paidByMemberID: "a")
        #expect(vm.sharesForExpense(expense).isEmpty)
    }

    // MARK: - Sheet State

    @Test func activeSheet_settingsID() {
        let vm = GroupDetailViewModel(group: makeGroup())
        vm.activeSheet = .settings
        #expect(vm.activeSheet?.id == "settings")
    }

    @Test func activeSheet_addExpenseID() {
        let vm = GroupDetailViewModel(group: makeGroup())
        vm.activeSheet = .addExpense
        #expect(vm.activeSheet?.id == "addExpense")
    }

    // MARK: - loadData without context

    @Test func loadData_withoutContext_doesNotCrash() {
        let vm = GroupDetailViewModel(group: makeGroup())
        vm.loadData()
        #expect(vm.members.isEmpty)
    }

    // MARK: - Share Link Guard

    @Test func createShareLink_reentryGuard_rejectsWhenInProgress() async {
        let vm = GroupDetailViewModel(group: makeGroup())
        vm.isCreatingShare = true
        await vm.createShareLink()
        // shareURL should remain nil — call was rejected by guard
        #expect(vm.shareURL == nil)
    }

    // MARK: - Expense Detail → Edit Transition

    @Test func activeSheet_expenseDetailID() {
        let vm = GroupDetailViewModel(group: makeGroup())
        let expense = SplitExpense(groupZoneID: "z", amount: 10, paidByMemberID: "a")
        vm.activeSheet = .expenseDetail(expense)
        #expect(vm.activeSheet?.id == "expenseDetail-\(expense.id)")
    }

    @Test func requestEditFromDetail_closesDetailAndConsumesExpenseOnce() {
        // Given: el detalle de un gasto está presentado
        let vm = GroupDetailViewModel(group: makeGroup())
        let expense = SplitExpense(groupZoneID: "z", amount: 10, paidByMemberID: "a")
        vm.activeSheet = .expenseDetail(expense)

        // When: el usuario toca Editar en el detalle
        vm.requestEditFromDetail(expense)

        // Then: el detalle se cierra y el gasto queda pendiente para que el
        // onDismiss del padre presente el editor (consumo one-shot)
        #expect(vm.activeSheet == nil)
        #expect(vm.consumePendingEditFromDetail()?.id == expense.id)
        #expect(vm.consumePendingEditFromDetail() == nil)
    }
}
