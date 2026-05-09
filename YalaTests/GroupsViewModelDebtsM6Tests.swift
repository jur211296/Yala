//
//  GroupsViewModelDebtsM6Tests.swift
//  YalaTests
//
//  M6 D3: tests pure-logic de `GroupsViewModel.computeCurrentUserDebts(...)`.
//  Estilo Splitwise: filtra debts del current user, agrega perspective + counterpartyName.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupsViewModelDebtsM6Tests {

    // MARK: - Helpers

    private func makeMember(id: UUID = UUID(), name: String, isCurrentUser: Bool = false) -> SplitMember {
        let m = SplitMember(displayName: name, isCurrentUser: isCurrentUser)
        m.id = id
        return m
    }

    private func makeExpense(
        id: UUID = UUID(),
        amount: Double,
        currencyCode: String = "PEN",
        paidByMemberID: String
    ) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: "test-zone",
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: "Test",
            paidByMemberID: paidByMemberID
        )
        e.id = id
        return e
    }

    private func makeShare(expenseID: UUID, memberID: String, amount: Double) -> SplitShare {
        SplitShare(expenseID: expenseID, memberID: memberID, amount: amount)
    }

    // MARK: - Empty / no current user

    @Test func computeCurrentUserDebts_emptyWhenNoMembers() {
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [], expenses: [], shares: [], settlements: []
        )
        #expect(result.isEmpty)
    }

    @Test func computeCurrentUserDebts_emptyWhenNoCurrentUser() {
        // Ningún miembro tiene isCurrentUser=true.
        let other = makeMember(name: "Maria")
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [other], expenses: [], shares: [], settlements: []
        )
        #expect(result.isEmpty)
    }

    @Test func computeCurrentUserDebts_emptyWhenNoExpenses() {
        let me = makeMember(name: "Me", isCurrentUser: true)
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me], expenses: [], shares: [], settlements: []
        )
        #expect(result.isEmpty)
    }

    // MARK: - Filter para current user

    @Test func computeCurrentUserDebts_filtersForCurrentUserOnly() {
        // Maria pagó $100, dividido entre Maria, Juan y yo (Me).
        // Debts: Juan→Maria $33.33, Me→Maria $33.33.
        // currentUserDebts solo debe incluir Me→Maria.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")
        let exp = makeExpense(amount: 99, paidByMemberID: maria.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 33),
            makeShare(expenseID: exp.id, memberID: juan.id.uuidString, amount: 33),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 33)
        ]
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp], shares: shares, settlements: []
        )
        #expect(result.count == 1)
        #expect(result.first?.counterpartyName == "Maria")
        #expect(result.first?.perspective == .iOwe)
        #expect(result.first?.amount == 33)
    }

    // MARK: - Perspectiva

    @Test func computeCurrentUserDebts_perspectiveIOweCorrect() {
        // Otro pagó, yo le debo.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let exp = makeExpense(amount: 50, paidByMemberID: maria.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 25)
        ]
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria], expenses: [exp], shares: shares, settlements: []
        )
        #expect(result.first?.perspective == .iOwe)
        #expect(result.first?.counterpartyName == "Maria")
        #expect(result.first?.amount == 25)
    }

    @Test func computeCurrentUserDebts_perspectiveTheyOweMeCorrect() {
        // Yo pagué, ella me debe.
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let exp = makeExpense(amount: 50, paidByMemberID: me.id.uuidString)
        let shares = [
            makeShare(expenseID: exp.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp.id, memberID: maria.id.uuidString, amount: 25)
        ]
        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria], expenses: [exp], shares: shares, settlements: []
        )
        #expect(result.first?.perspective == .theyOweMe)
        #expect(result.first?.counterpartyName == "Maria")
        #expect(result.first?.amount == 25)
    }

    // MARK: - Multi-currency

    @Test func computeCurrentUserDebts_handlesMultiCurrency() {
        // Maria pagó S/100 (dividido), Juan pagó USD 50 (dividido).
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")

        let exp1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: maria.id.uuidString)
        let shares1 = [
            makeShare(expenseID: exp1.id, memberID: me.id.uuidString, amount: 50),
            makeShare(expenseID: exp1.id, memberID: maria.id.uuidString, amount: 50)
        ]

        let exp2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: juan.id.uuidString)
        let shares2 = [
            makeShare(expenseID: exp2.id, memberID: me.id.uuidString, amount: 25),
            makeShare(expenseID: exp2.id, memberID: juan.id.uuidString, amount: 25)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp1, exp2], shares: shares1 + shares2, settlements: []
        )
        #expect(result.count == 2)
        let currencies = Set(result.map(\.currencyCode))
        #expect(currencies == ["PEN", "USD"])
    }

    // MARK: - Sort by amount desc

    @Test func computeCurrentUserDebts_sortedByAmountDesc() {
        let me = makeMember(name: "Me", isCurrentUser: true)
        let maria = makeMember(name: "Maria")
        let juan = makeMember(name: "Juan")

        let exp1 = makeExpense(amount: 200, paidByMemberID: maria.id.uuidString)
        let shares1 = [
            makeShare(expenseID: exp1.id, memberID: me.id.uuidString, amount: 100),
            makeShare(expenseID: exp1.id, memberID: maria.id.uuidString, amount: 100)
        ]

        let exp2 = makeExpense(amount: 80, paidByMemberID: juan.id.uuidString)
        let shares2 = [
            makeShare(expenseID: exp2.id, memberID: me.id.uuidString, amount: 40),
            makeShare(expenseID: exp2.id, memberID: juan.id.uuidString, amount: 40)
        ]

        let result = GroupsViewModel.computeCurrentUserDebts(
            members: [me, maria, juan],
            expenses: [exp1, exp2], shares: shares1 + shares2, settlements: []
        )
        #expect(result.count == 2)
        #expect(result[0].amount == 100)
        #expect(result[1].amount == 40)
    }
}
