//
//  GroupBalanceRowGroupingTests.swift
//  YalaTests
//
//  Tests para GroupBalanceRowGrouping — agrupación multi-moneda de balances y deudas.
//

import Foundation
import Testing

@testable import Yala

struct GroupBalanceRowGroupingTests {

    private func bal(_ member: String, _ name: String, _ net: Double, _ currency: String) -> MemberBalance {
        MemberBalance(memberID: member, displayName: name, totalPaid: 0, totalOwes: 0, netBalance: net, currencyCode: currency)
    }
    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String) -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    // MARK: - groupByMember

    @Test func groupByMember_twoMembersTwoCurrencies_collapsesToTwoRows() {
        let balances = [
            bal("ana", "Ana", 112.91, "PEN"),
            bal("ana", "Ana", 246.23, "USD"),
            bal("bob", "Bob", -112.91, "PEN"),
            bal("bob", "Bob", -246.23, "USD"),
        ]
        let groups = GroupBalanceRowGrouping.groupByMember(balances)
        #expect(groups.count == 2)
        #expect(groups[0].displayName == "Ana")                       // orden por nombre
        #expect(groups[0].amounts.count == 2)
        #expect(groups[0].amounts.map(\.currencyCode) == ["PEN", "USD"]) // orden por código
        #expect(groups[1].amounts.count == 2)
        // signo preservado
        #expect(groups[1].amounts.first(where: { $0.currencyCode == "PEN" })?.net == -112.91)
    }

    @Test func groupByMember_singleCurrency_oneAmountEach() {
        let groups = GroupBalanceRowGrouping.groupByMember([bal("ana", "Ana", 50, "PEN")])
        #expect(groups.count == 1)
        #expect(groups[0].amounts.count == 1)
        #expect(groups[0].amounts[0].net == 50)
    }

    @Test func groupByMember_orderByName() {
        let groups = GroupBalanceRowGrouping.groupByMember([
            bal("z", "Zoe", 10, "PEN"),
            bal("a", "Ana", 20, "PEN"),
        ])
        #expect(groups.map(\.displayName) == ["Ana", "Zoe"])
    }

    // MARK: - groupByPair

    @Test func groupByPair_samePairTwoCurrencies_oneGroupTwoDebts() {
        let groups = GroupBalanceRowGrouping.groupByPair([
            debt("ana", "bob", 100, "PEN"),
            debt("ana", "bob", 50, "USD"),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].fromMemberID == "ana")
        #expect(groups[0].toMemberID == "bob")
        #expect(groups[0].debts.count == 2)
        #expect(groups[0].debts.map(\.currencyCode) == ["PEN", "USD"])
    }

    @Test func groupByPair_distinctPairs_separateGroups() {
        let groups = GroupBalanceRowGrouping.groupByPair([
            debt("ana", "bob", 100, "PEN"),
            debt("carl", "ana", 30, "PEN"),
        ])
        #expect(groups.count == 2)
    }

    @Test func groupByPair_eachDebtPreservedForSeparateSettle() {
        // Cada Debt mantiene su id (from-to-currency) → se liquida por separado.
        let groups = GroupBalanceRowGrouping.groupByPair([
            debt("ana", "bob", 100, "PEN"),
            debt("ana", "bob", 50, "USD"),
        ])
        #expect(Set(groups[0].debts.map(\.id)).count == 2)
    }
}
