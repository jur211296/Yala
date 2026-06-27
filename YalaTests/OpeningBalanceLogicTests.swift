//
//  OpeningBalanceLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para saldos iniciales (deuda de apertura). Sin SwiftData (R8):
//  OpeningBalanceBridgeLogic, OpeningBalanceRollup, OpeningBalanceGuardLogic.
//

import Foundation
import Testing

@testable import Yala

@Suite("Opening balance — bridge plan")
struct OpeningBalanceBridgeLogicTests {

    @Test func creditor_owedVirtualPositive() {
        let plan = OpeningBalanceBridgeLogic.plan(isCreditor: true, myShare: 0, amount: 80)
        #expect(plan == .init(txAmount: 80, role: .owed))
    }

    @Test func debtor_debtVirtualNegative() {
        let plan = OpeningBalanceBridgeLogic.plan(isCreditor: false, myShare: 50, amount: 50)
        #expect(plan == .init(txAmount: -50, role: .debt))
    }

    @Test func notInvolved_noShareNoCreditor_returnsNil() {
        #expect(OpeningBalanceBridgeLogic.plan(isCreditor: false, myShare: 0, amount: 80) == nil)
    }

    @Test func creditor_zeroAmount_returnsNil() {
        #expect(OpeningBalanceBridgeLogic.plan(isCreditor: true, myShare: 0, amount: 0) == nil)
    }

    @Test func creditor_takesPriorityOverShare() {
        // Defensivo: si por construcción rara el acreedor tuviera share, gana el lado acreedor.
        let plan = OpeningBalanceBridgeLogic.plan(isCreditor: true, myShare: 30, amount: 80)
        #expect(plan?.role == .owed)
        #expect(plan?.txAmount == 80)
    }
}

@Suite("Opening balance — rollup neto por miembro")
struct OpeningBalanceRollupTests {

    private func edge(_ debtor: String, _ creditor: String, _ amount: Double, _ code: String = "PEN") -> OpeningBalanceRollup.Edge {
        .init(debtorMemberID: debtor, creditorMemberID: creditor, amount: amount, currencyCode: code)
    }

    @Test func singleEdge_creditorPositive_debtorNegative() {
        let net = OpeningBalanceRollup.netByMember(edges: [edge("B", "A", 80)])
        #expect(net["A"]?["PEN"] == 80)
        #expect(net["B"]?["PEN"] == -80)
    }

    @Test func multipleEdgesSameCreditor_sum() {
        let net = OpeningBalanceRollup.netByMember(edges: [edge("B", "A", 50), edge("C", "A", 30)])
        #expect(net["A"]?["PEN"] == 80)
        #expect(net["B"]?["PEN"] == -50)
        #expect(net["C"]?["PEN"] == -30)
    }

    @Test func multiCurrency_keptSeparate() {
        let net = OpeningBalanceRollup.netByMember(edges: [edge("B", "A", 80, "PEN"), edge("B", "A", 20, "USD")])
        #expect(net["A"]?["PEN"] == 80)
        #expect(net["A"]?["USD"] == 20)
        #expect(net["B"]?["PEN"] == -80)
        #expect(net["B"]?["USD"] == -20)
    }

    @Test func memberBothDebtorAndCreditor_cancelsToZero_omitted() {
        // A le debe a B 40, B le debe a A 40 → ambos netean a 0 → omitidos.
        let net = OpeningBalanceRollup.netByMember(edges: [edge("A", "B", 40), edge("B", "A", 40)])
        #expect(net["A"] == nil)
        #expect(net["B"] == nil)
    }

    @Test func empty_returnsEmpty() {
        #expect(OpeningBalanceRollup.netByMember(edges: []).isEmpty)
    }
}

@Suite("Opening balance — guard de settlements (targeted)")
struct OpeningBalanceGuardLogicTests {

    @Test func settlementInvolvingEdgeMember_blocks() {
        let blocked = OpeningBalanceGuardLogic.isBlocked(
            edgeMembers: ["A", "B"],
            confirmedSettlementPairs: [(from: "B", to: "C")]
        )
        #expect(blocked)
    }

    @Test func settlementNotInvolvingEdge_doesNotBlock() {
        let blocked = OpeningBalanceGuardLogic.isBlocked(
            edgeMembers: ["A", "B"],
            confirmedSettlementPairs: [(from: "C", to: "D")]
        )
        #expect(!blocked)
    }

    @Test func noSettlements_doesNotBlock() {
        #expect(!OpeningBalanceGuardLogic.isBlocked(edgeMembers: ["A", "B"], confirmedSettlementPairs: []))
    }

    @Test func settlementToEdgeMember_blocks() {
        let blocked = OpeningBalanceGuardLogic.isBlocked(
            edgeMembers: ["A", "B"],
            confirmedSettlementPairs: [(from: "C", to: "A")]
        )
        #expect(blocked)
    }
}
