//
//  GroupStatsViewModelTests.swift
//  YalaTests
//
//  Unit tests for GroupStatsViewModel calculations.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupStatsViewModelTests {

    // MARK: - Helpers

    private func makeExpense(
        id: UUID = UUID(),
        amount: Double,
        currencyCode: String = "PEN",
        paidByMemberID: String,
        date: Date = Date.now,
        subcategoryName: String? = nil,
        isSettled: Bool = false
    ) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: "test-zone",
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: "Test",
            paidByMemberID: paidByMemberID,
            subcategoryName: subcategoryName
        )
        e.id = id
        e.date = date
        e.isSettled = isSettled
        return e
    }

    private func makeShare(expenseID: UUID, memberID: String, amount: Double) -> SplitShare {
        SplitShare(expenseID: expenseID, memberID: memberID, amount: amount)
    }

    private func makeMember(id: UUID, displayName: String, isCurrentUser: Bool = false) -> SplitMember {
        let m = SplitMember(displayName: displayName)
        m.id = id
        m.isCurrentUser = isCurrentUser
        return m
    }

    private func makeVM(
        expenses: [SplitExpense],
        shares: [SplitShare],
        members: [SplitMember],
        currentUserMemberID: String? = nil,
        currencyCode: String = "PEN",
        period: GroupStatsPeriod = .allTime
    ) -> GroupStatsViewModel {
        let vm = GroupStatsViewModel()
        vm.selectedPeriod = period
        vm.loadStats(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: [],
            currentUserMemberID: currentUserMemberID,
            currencyCode: currencyCode
        )
        return vm
    }

    // MARK: - Total Spent

    @Test func totalSpent_sumsAllExpenses() {
        let e1 = makeExpense(amount: 100, paidByMemberID: "A")
        let e2 = makeExpense(amount: 200, paidByMemberID: "B")

        let vm = makeVM(expenses: [e1, e2], shares: [], members: [])
        #expect(vm.totalSpent == 300)
    }

    @Test func totalSpent_filtersByCurrency() {
        let e1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let e2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")

        let vm = makeVM(expenses: [e1, e2], shares: [], members: [], currencyCode: "PEN")
        #expect(vm.totalSpent == 100)
    }

    // MARK: - My Portion

    @Test func myPortion_sumsSharesForCurrentUser() {
        let e1ID = UUID()
        let e2ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 300, paidByMemberID: "A")
        let e2 = makeExpense(id: e2ID, amount: 200, paidByMemberID: "B")

        let shares = [
            makeShare(expenseID: e1ID, memberID: "A", amount: 150),
            makeShare(expenseID: e1ID, memberID: "B", amount: 150),
            makeShare(expenseID: e2ID, memberID: "A", amount: 100),
            makeShare(expenseID: e2ID, memberID: "B", amount: 100)
        ]

        let vm = makeVM(expenses: [e1, e2], shares: shares, members: [], currentUserMemberID: "A")
        #expect(vm.myPortion == 250)
    }

    @Test func myPortion_nilCurrentUser_returnsZero() {
        let eID = UUID()
        let e = makeExpense(id: eID, amount: 100, paidByMemberID: "A")
        let shares = [makeShare(expenseID: eID, memberID: "A", amount: 50)]

        let vm = makeVM(expenses: [e], shares: shares, members: [], currentUserMemberID: nil)
        #expect(vm.myPortion == 0)
    }

    // MARK: - Member Spending

    @Test func memberSpending_groupsByPayer_sortedDescending() {
        let alice = UUID()
        let bob = UUID()
        let members = [
            makeMember(id: alice, displayName: "Alice"),
            makeMember(id: bob, displayName: "Bob")
        ]
        let e1 = makeExpense(amount: 100, paidByMemberID: alice.uuidString)
        let e2 = makeExpense(amount: 300, paidByMemberID: bob.uuidString)
        let e3 = makeExpense(amount: 50, paidByMemberID: alice.uuidString)

        let vm = makeVM(expenses: [e1, e2, e3], shares: [], members: members)

        #expect(vm.memberSpending.count == 2)
        #expect(vm.memberSpending[0].displayName == "Bob")
        #expect(vm.memberSpending[0].totalPaid == 300)
        #expect(vm.memberSpending[1].displayName == "Alice")
        #expect(vm.memberSpending[1].totalPaid == 150)
    }

    // MARK: - Category Breakdown

    @Test func categoryBreakdown_groupsBySubcategoryName() {
        let e1 = makeExpense(amount: 200, paidByMemberID: "A", subcategoryName: "Comida")
        let e2 = makeExpense(amount: 100, paidByMemberID: "A", subcategoryName: "Transporte")
        let e3 = makeExpense(amount: 100, paidByMemberID: "B", subcategoryName: "Comida")

        let vm = makeVM(expenses: [e1, e2, e3], shares: [], members: [])

        #expect(vm.categoryBreakdown.count == 2)
        #expect(vm.categoryBreakdown[0].subcategoryName == "Comida")
        #expect(vm.categoryBreakdown[0].amount == 300)
        #expect(vm.categoryBreakdown[0].percentage == 75)
        #expect(vm.categoryBreakdown[1].subcategoryName == "Transporte")
    }

    @Test func categoryBreakdown_nilSubcategoryGroupedAsUncategorized() {
        let e1 = makeExpense(amount: 100, paidByMemberID: "A", subcategoryName: nil)

        let vm = makeVM(expenses: [e1], shares: [], members: [])

        #expect(vm.categoryBreakdown.count == 1)
        #expect(vm.categoryBreakdown[0].subcategoryName == L10n.Groups.Stats.uncategorized)
    }

    // MARK: - Monthly Trend

    @Test func monthlyTrend_groupsByMonth() {
        let cal = Calendar.current
        let jan = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let feb = cal.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        let feb2 = cal.date(from: DateComponents(year: 2026, month: 2, day: 20))!

        let e1 = makeExpense(amount: 100, paidByMemberID: "A", date: jan)
        let e2 = makeExpense(amount: 200, paidByMemberID: "A", date: feb)
        let e3 = makeExpense(amount: 50, paidByMemberID: "B", date: feb2)

        let vm = makeVM(expenses: [e1, e2, e3], shares: [], members: [])

        #expect(vm.monthlyTrend.count == 2)
        #expect(vm.monthlyTrend[0].totalSpent == 100) // Jan
        #expect(vm.monthlyTrend[1].totalSpent == 250) // Feb
    }

    // MARK: - Empty Data

    @Test func emptyExpenses_returnsZeros() {
        let vm = makeVM(expenses: [], shares: [], members: [])

        #expect(vm.totalSpent == 0)
        #expect(vm.myPortion == 0)
        #expect(vm.memberSpending.isEmpty)
        #expect(vm.categoryBreakdown.isEmpty)
        #expect(vm.monthlyTrend.isEmpty)
    }

    // MARK: - Period Filter

    @Test func periodFilter_thisMonth_filtersCorrectly() {
        let now = Date.now
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!

        let e1 = makeExpense(amount: 100, paidByMemberID: "A", date: now)
        let e2 = makeExpense(amount: 200, paidByMemberID: "A", date: lastMonth)

        let vm = makeVM(
            expenses: [e1, e2], shares: [], members: [],
            period: .thisMonth
        )

        #expect(vm.totalSpent == 100)
    }
}
