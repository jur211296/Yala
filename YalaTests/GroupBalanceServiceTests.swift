//
//  GroupBalanceServiceTests.swift
//  YalaTests
//
//  Unit tests for GroupBalanceService balance and debt calculations.
//

import Foundation
import Testing

@testable import Yala

struct GroupBalanceServiceTests {

    // MARK: - Test Helpers

    /// Create a minimal SplitExpense for testing.
    private func makeExpense(
        id: UUID = UUID(),
        amount: Double,
        currencyCode: String = "PEN",
        paidByMemberID: String,
        isSettled: Bool = false
    ) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: "test-zone",
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: "Test",
            paidByMemberID: paidByMemberID
        )
        // Override the auto-generated id
        e.id = id
        e.isSettled = isSettled
        return e
    }

    private func makeShare(
        expenseID: UUID,
        memberID: String,
        amount: Double
    ) -> SplitShare {
        SplitShare(expenseID: expenseID, memberID: memberID, amount: amount)
    }

    private func makeMember(id: UUID, displayName: String) -> SplitMember {
        let m = SplitMember(displayName: displayName)
        m.id = id
        return m
    }

    private func makeSettlement(
        fromMemberID: String,
        toMemberID: String,
        amount: Double,
        currencyCode: String = "PEN",
        isConfirmed: Bool = true
    ) -> SplitSettlement {
        let s = SplitSettlement(
            groupZoneID: "test-zone",
            fromMemberID: fromMemberID,
            toMemberID: toMemberID,
            amount: amount,
            currencyCode: currencyCode
        )
        s.isConfirmed = isConfirmed
        return s
    }

    // MARK: - Balances: Empty

    @Test func balances_noExpenses_returnsEmpty() {
        let result = GroupBalanceService.calculateBalances(
            expenses: [], shares: [], members: [], settlements: []
        )
        #expect(result.isEmpty)
    }

    // MARK: - Balances: Two Members Equal Split

    @Test func balances_twoMembers_equalSplit() {
        let memberAID = UUID()
        let memberBID = UUID()
        let memberA = makeMember(id: memberAID, displayName: "Ana")
        let memberB = makeMember(id: memberBID, displayName: "Bob")

        let expenseID = UUID()
        // Ana pays 100, split equally (50 each)
        let expense = makeExpense(id: expenseID, amount: 100, paidByMemberID: memberAID.uuidString)
        let shareA = makeShare(expenseID: expenseID, memberID: memberAID.uuidString, amount: 50)
        let shareB = makeShare(expenseID: expenseID, memberID: memberBID.uuidString, amount: 50)

        let result = GroupBalanceService.calculateBalances(
            expenses: [expense],
            shares: [shareA, shareB],
            members: [memberA, memberB],
            settlements: []
        )

        let balanceA = result.first { $0.memberID == memberAID.uuidString }
        let balanceB = result.first { $0.memberID == memberBID.uuidString }

        #expect(balanceA != nil)
        #expect(balanceA?.totalPaid == 100)
        #expect(balanceA?.totalOwes == 50)
        #expect(balanceA?.netBalance == 50)  // Bob owes Ana 50
        #expect(balanceA?.displayName == "Ana")

        #expect(balanceB != nil)
        #expect(balanceB?.totalPaid == 0)
        #expect(balanceB?.totalOwes == 50)
        #expect(balanceB?.netBalance == -50)  // Bob owes 50
    }

    // MARK: - Balances: Three Members Unequal

    @Test func balances_threeMembers_unequalSplit() {
        let aID = UUID(), bID = UUID(), cID = UUID()
        let members = [
            makeMember(id: aID, displayName: "A"),
            makeMember(id: bID, displayName: "B"),
            makeMember(id: cID, displayName: "C"),
        ]

        // A pays 300 (split: A=100, B=100, C=100)
        let e1ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 300, paidByMemberID: aID.uuidString)
        let shares1 = [
            makeShare(expenseID: e1ID, memberID: aID.uuidString, amount: 100),
            makeShare(expenseID: e1ID, memberID: bID.uuidString, amount: 100),
            makeShare(expenseID: e1ID, memberID: cID.uuidString, amount: 100),
        ]

        // B pays 150 (split: A=75, B=75)
        let e2ID = UUID()
        let e2 = makeExpense(id: e2ID, amount: 150, paidByMemberID: bID.uuidString)
        let shares2 = [
            makeShare(expenseID: e2ID, memberID: aID.uuidString, amount: 75),
            makeShare(expenseID: e2ID, memberID: bID.uuidString, amount: 75),
        ]

        let result = GroupBalanceService.calculateBalances(
            expenses: [e1, e2],
            shares: shares1 + shares2,
            members: members,
            settlements: []
        )

        // A: paid=300, owes=100+75=175, net=+125
        let balA = result.first { $0.memberID == aID.uuidString }
        #expect(balA?.totalPaid == 300)
        #expect(balA?.totalOwes == 175)
        #expect(balA?.netBalance == 125)

        // B: paid=150, owes=100+75=175, net=-25
        let balB = result.first { $0.memberID == bID.uuidString }
        #expect(balB?.totalPaid == 150)
        #expect(balB?.totalOwes == 175)
        #expect(balB?.netBalance == -25)

        // C: paid=0, owes=100, net=-100
        let balC = result.first { $0.memberID == cID.uuidString }
        #expect(balC?.totalPaid == 0)
        #expect(balC?.totalOwes == 100)
        #expect(balC?.netBalance == -100)
    }

    // MARK: - Balances: Settled Expenses Excluded

    @Test func balances_settledExpenses_excluded() {
        let aID = UUID(), bID = UUID()
        let members = [makeMember(id: aID, displayName: "A"), makeMember(id: bID, displayName: "B")]

        let e1ID = UUID()
        let settled = makeExpense(id: e1ID, amount: 200, paidByMemberID: aID.uuidString, isSettled: true)
        let shares = [
            makeShare(expenseID: e1ID, memberID: aID.uuidString, amount: 100),
            makeShare(expenseID: e1ID, memberID: bID.uuidString, amount: 100),
        ]

        let result = GroupBalanceService.calculateBalances(
            expenses: [settled], shares: shares, members: members, settlements: []
        )

        #expect(result.isEmpty)
    }

    // MARK: - Balances: Settlements Adjust Debt

    @Test func balances_settlement_adjustsNet() {
        let aID = UUID(), bID = UUID()
        let members = [makeMember(id: aID, displayName: "A"), makeMember(id: bID, displayName: "B")]

        let eID = UUID()
        // A pays 100, split 50/50. B owes A 50.
        let expense = makeExpense(id: eID, amount: 100, paidByMemberID: aID.uuidString)
        let shares = [
            makeShare(expenseID: eID, memberID: aID.uuidString, amount: 50),
            makeShare(expenseID: eID, memberID: bID.uuidString, amount: 50),
        ]

        // B settles 30 to A (confirmed)
        let settlement = makeSettlement(
            fromMemberID: bID.uuidString, toMemberID: aID.uuidString, amount: 30
        )

        let result = GroupBalanceService.calculateBalances(
            expenses: [expense], shares: shares, members: members, settlements: [settlement]
        )

        // A: paid=100+0=100, owes=50+30=80, net=+20 (was 50, now 20 after settlement)
        // Actually: settlement adds to payer's paid and creditor's owes
        // A: paid=100, owes=50+30=80 → net=20
        // B: paid=0+30=30, owes=50 → net=-20
        let balA = result.first { $0.memberID == aID.uuidString }
        let balB = result.first { $0.memberID == bID.uuidString }

        #expect(balA?.netBalance == 20)
        #expect(balB?.netBalance == -20)
    }

    // MARK: - Balances: Unconfirmed Settlement Ignored

    @Test func balances_unconfirmedSettlement_ignored() {
        let aID = UUID(), bID = UUID()
        let members = [makeMember(id: aID, displayName: "A"), makeMember(id: bID, displayName: "B")]

        let eID = UUID()
        let expense = makeExpense(id: eID, amount: 100, paidByMemberID: aID.uuidString)
        let shares = [
            makeShare(expenseID: eID, memberID: aID.uuidString, amount: 50),
            makeShare(expenseID: eID, memberID: bID.uuidString, amount: 50),
        ]

        let unconfirmed = makeSettlement(
            fromMemberID: bID.uuidString, toMemberID: aID.uuidString, amount: 50, isConfirmed: false
        )

        let result = GroupBalanceService.calculateBalances(
            expenses: [expense], shares: shares, members: members, settlements: [unconfirmed]
        )

        let balA = result.first { $0.memberID == aID.uuidString }
        #expect(balA?.netBalance == 50) // No adjustment
    }

    // MARK: - Balances: Multi-Currency

    @Test func balances_multiCurrency_separateEntries() {
        let aID = UUID(), bID = UUID()
        let members = [makeMember(id: aID, displayName: "A"), makeMember(id: bID, displayName: "B")]

        // PEN expense: A pays 100
        let e1ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 100, currencyCode: "PEN", paidByMemberID: aID.uuidString)
        let shares1 = [
            makeShare(expenseID: e1ID, memberID: aID.uuidString, amount: 50),
            makeShare(expenseID: e1ID, memberID: bID.uuidString, amount: 50),
        ]

        // USD expense: B pays 60
        let e2ID = UUID()
        let e2 = makeExpense(id: e2ID, amount: 60, currencyCode: "USD", paidByMemberID: bID.uuidString)
        let shares2 = [
            makeShare(expenseID: e2ID, memberID: aID.uuidString, amount: 30),
            makeShare(expenseID: e2ID, memberID: bID.uuidString, amount: 30),
        ]

        let result = GroupBalanceService.calculateBalances(
            expenses: [e1, e2], shares: shares1 + shares2, members: members, settlements: []
        )

        // A in PEN: paid=100, owes=50, net=+50
        let aPEN = result.first { $0.memberID == aID.uuidString && $0.currencyCode == "PEN" }
        #expect(aPEN?.netBalance == 50)

        // A in USD: paid=0, owes=30, net=-30
        let aUSD = result.first { $0.memberID == aID.uuidString && $0.currencyCode == "USD" }
        #expect(aUSD?.netBalance == -30)

        // B in PEN: paid=0, owes=50, net=-50
        let bPEN = result.first { $0.memberID == bID.uuidString && $0.currencyCode == "PEN" }
        #expect(bPEN?.netBalance == -50)

        // B in USD: paid=60, owes=30, net=+30
        let bUSD = result.first { $0.memberID == bID.uuidString && $0.currencyCode == "USD" }
        #expect(bUSD?.netBalance == 30)
    }

    // MARK: - Debts: Basic

    @Test func debts_twoMembers_correctDebt() {
        let aID = UUID(), bID = UUID()

        let eID = UUID()
        let expense = makeExpense(id: eID, amount: 100, paidByMemberID: aID.uuidString)
        let shares = [
            makeShare(expenseID: eID, memberID: aID.uuidString, amount: 50),
            makeShare(expenseID: eID, memberID: bID.uuidString, amount: 50),
        ]

        let result = GroupBalanceService.calculateDebts(
            expenses: [expense], shares: shares, settlements: [], simplifyDebts: false
        )

        #expect(result.count == 1)
        #expect(result[0].fromMemberID == bID.uuidString)
        #expect(result[0].toMemberID == aID.uuidString)
        #expect(result[0].amount == 50)
    }

    // MARK: - Debts: Simplified

    @Test func debts_threeMembers_simplified() {
        let aID = UUID(), bID = UUID(), cID = UUID()

        // A pays 90 (split 30 each), B pays 60 (split 30 each)
        let e1ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 90, paidByMemberID: aID.uuidString)
        let shares1 = [
            makeShare(expenseID: e1ID, memberID: aID.uuidString, amount: 30),
            makeShare(expenseID: e1ID, memberID: bID.uuidString, amount: 30),
            makeShare(expenseID: e1ID, memberID: cID.uuidString, amount: 30),
        ]

        let e2ID = UUID()
        let e2 = makeExpense(id: e2ID, amount: 60, paidByMemberID: bID.uuidString)
        let shares2 = [
            makeShare(expenseID: e2ID, memberID: aID.uuidString, amount: 30),
            makeShare(expenseID: e2ID, memberID: bID.uuidString, amount: 30),
        ]

        let simplified = GroupBalanceService.calculateDebts(
            expenses: [e1, e2], shares: shares1 + shares2, settlements: [], simplifyDebts: true
        )

        let unsimplified = GroupBalanceService.calculateDebts(
            expenses: [e1, e2], shares: shares1 + shares2, settlements: [], simplifyDebts: false
        )

        // Simplified should have <= transfers than unsimplified
        #expect(simplified.count <= unsimplified.count)

        // Both should preserve net amounts
        func netFor(_ debts: [Debt], memberID: String) -> Double {
            let owed = debts.filter { $0.toMemberID == memberID }.reduce(0) { $0 + $1.amount }
            let owes = debts.filter { $0.fromMemberID == memberID }.reduce(0) { $0 + $1.amount }
            return owed - owes
        }

        for id in [aID.uuidString, bID.uuidString, cID.uuidString] {
            let simNet = netFor(simplified, memberID: id)
            let unsimNet = netFor(unsimplified, memberID: id)
            #expect(abs(simNet - unsimNet) < 0.02, "Net mismatch for \(id)")
        }
    }

    // MARK: - Debts: Settlement Reduces Debt

    @Test func debts_settlement_reducesDebt() {
        let aID = UUID(), bID = UUID()

        let eID = UUID()
        let expense = makeExpense(id: eID, amount: 100, paidByMemberID: aID.uuidString)
        let shares = [
            makeShare(expenseID: eID, memberID: aID.uuidString, amount: 50),
            makeShare(expenseID: eID, memberID: bID.uuidString, amount: 50),
        ]

        let settlement = makeSettlement(
            fromMemberID: bID.uuidString, toMemberID: aID.uuidString, amount: 30
        )

        let result = GroupBalanceService.calculateDebts(
            expenses: [expense], shares: shares, settlements: [settlement], simplifyDebts: true
        )

        // B originally owes A 50, settled 30 → owes 20
        #expect(result.count == 1)
        #expect(result[0].fromMemberID == bID.uuidString)
        #expect(result[0].toMemberID == aID.uuidString)
        #expect(result[0].amount == 20)
    }

    // MARK: - Debts: All Settled

    @Test func debts_allSettled_noDebts() {
        let aID = UUID(), bID = UUID()

        let eID = UUID()
        let expense = makeExpense(id: eID, amount: 100, paidByMemberID: aID.uuidString, isSettled: true)
        let shares = [
            makeShare(expenseID: eID, memberID: aID.uuidString, amount: 50),
            makeShare(expenseID: eID, memberID: bID.uuidString, amount: 50),
        ]

        let result = GroupBalanceService.calculateDebts(
            expenses: [expense], shares: shares, settlements: [], simplifyDebts: false
        )

        #expect(result.isEmpty)
    }

    // MARK: - Global Summary

    @Test func globalSummary_twoGroups() {
        let meID = UUID()
        let otherID = UUID()
        let myMemberID = meID.uuidString

        // Group 1: other pays 100, I owe 50 (PEN)
        let e1ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 100, currencyCode: "PEN", paidByMemberID: otherID.uuidString)
        let shares1 = [
            makeShare(expenseID: e1ID, memberID: myMemberID, amount: 50),
            makeShare(expenseID: e1ID, memberID: otherID.uuidString, amount: 50),
        ]

        // Group 2: I pay 200, other owes 100 (USD)
        let e2ID = UUID()
        let e2 = makeExpense(id: e2ID, amount: 200, currencyCode: "USD", paidByMemberID: myMemberID)
        let shares2 = [
            makeShare(expenseID: e2ID, memberID: myMemberID, amount: 100),
            makeShare(expenseID: e2ID, memberID: otherID.uuidString, amount: 100),
        ]

        // One unconfirmed settlement
        let pending = makeSettlement(
            fromMemberID: myMemberID, toMemberID: otherID.uuidString,
            amount: 25, currencyCode: "PEN", isConfirmed: false
        )

        let summary = GroupBalanceService.globalSummary(
            allExpenses: [e1, e2],
            allShares: shares1 + shares2,
            allSettlements: [pending],
            currentUserMemberIDs: [myMemberID]
        )

        // I'm owed 100 USD (from group 2)
        #expect(summary.totalOwedToMe["USD"] == 100)

        // I owe 50 PEN (from group 1)
        #expect(summary.totalIOwe["PEN"] == 50)

        // 1 pending settlement
        #expect(summary.pendingSettlements == 1)
    }

    @Test func globalSummary_empty_returnsZeros() {
        let summary = GroupBalanceService.globalSummary(
            allExpenses: [],
            allShares: [],
            allSettlements: [],
            currentUserMemberIDs: ["me"]
        )

        #expect(summary.totalOwedToMe.isEmpty)
        #expect(summary.totalIOwe.isEmpty)
        #expect(summary.pendingSettlements == 0)
    }

    // MARK: - Edge Cases

    @Test func balances_memberPaidButNoShares_showsFullCredit() {
        let aID = UUID(), bID = UUID()
        let members = [makeMember(id: aID, displayName: "A"), makeMember(id: bID, displayName: "B")]

        let eID = UUID()
        // A pays 100, only B has a share (A paid for B entirely)
        let expense = makeExpense(id: eID, amount: 100, paidByMemberID: aID.uuidString)
        let shares = [makeShare(expenseID: eID, memberID: bID.uuidString, amount: 100)]

        let result = GroupBalanceService.calculateBalances(
            expenses: [expense], shares: shares, members: members, settlements: []
        )

        let balA = result.first { $0.memberID == aID.uuidString }
        #expect(balA?.totalPaid == 100)
        #expect(balA?.totalOwes == 0)
        #expect(balA?.netBalance == 100)

        let balB = result.first { $0.memberID == bID.uuidString }
        #expect(balB?.totalPaid == 0)
        #expect(balB?.totalOwes == 100)
        #expect(balB?.netBalance == -100)
    }

    @Test func debts_selfPayment_noDebtGenerated() {
        let aID = UUID()

        let eID = UUID()
        // A pays 50, only share is A's own (A paid for themselves)
        let expense = makeExpense(id: eID, amount: 50, paidByMemberID: aID.uuidString)
        let shares = [makeShare(expenseID: eID, memberID: aID.uuidString, amount: 50)]

        let result = GroupBalanceService.calculateDebts(
            expenses: [expense], shares: shares, settlements: [], simplifyDebts: false
        )

        #expect(result.isEmpty) // No debt to yourself
    }
}
