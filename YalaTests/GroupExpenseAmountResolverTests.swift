//
//  GroupExpenseAmountResolverTests.swift
//  YalaTests
//
//  Pure-logic tests for GroupExpenseAmountResolver — perspectiva personal.
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseAmountResolverTests {

    @Test func resolve_returnsYouAreOwed_whenIAmPayer() {
        let me = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: me
        )
        let myShare = SplitShare(expenseID: expense.id, memberID: me, amount: 30)

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: myShare,
            currentMemberID: me
        )

        // Yo pagué 100, me corresponde 30, presté 70
        #expect(result == .youAreOwed(amount: 70))
    }

    @Test func resolve_returnsYouOwe_whenIAmNotPayer() {
        let me = "member-B"
        let other = "member-A"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: other
        )
        let myShare = SplitShare(expenseID: expense.id, memberID: me, amount: 25)

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: myShare,
            currentMemberID: me
        )

        // Otro pagó, me prestó mi parte (25)
        #expect(result == .youOwe(amount: 25))
    }

    @Test func resolve_returnsNotIncluded_whenNoShare() {
        let me = "member-C"
        let expense = SplitExpense(
            groupZoneID: "z-1",
            amount: 100,
            currencyCode: "PEN",
            paidByMemberID: "member-A"
        )

        let result = GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: nil,
            currentMemberID: me
        )

        #expect(result == .notIncluded)
    }
}
