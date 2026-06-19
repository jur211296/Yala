//
//  BridgeBranchLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `BridgeBranchLogic.decideCaseAPath`. Sin SwiftData (R8).
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — branch logic")
struct BridgeBranchLogicTests {

    @Test
    func groupInvite_alwaysReturnsVirtualPair_regardlessOfEffective() {
        // .groupInvite tiene prioridad sobre el opt-out: no hay cuentas reales en ese flow.
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: true, effectiveBridgeEnabled: true
        ) == .groupInviteVirtualPair)
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: true, effectiveBridgeEnabled: false
        ) == .groupInviteVirtualPair)
    }

    @Test
    func nonGroupInvite_effectiveOff_returnsOptoutVirtualOnly() {
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: false, effectiveBridgeEnabled: false
        ) == .optoutVirtualOnly)
    }

    @Test
    func nonGroupInvite_effectiveOn_returnsFullPair() {
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: false, effectiveBridgeEnabled: true
        ) == .fullPair)
    }

    // MARK: - decideVirtualReconciliation (B6-25)

    @Test
    func noRealTx_returnsMyShareCost() {
        // Bridge-OFF puro sin opt-in: el virtual -myShare ES mi costo (correcto).
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: false, lentAmount: 20
        ) == .myShareCost)
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: false, lentAmount: 0
        ) == .myShareCost)
    }

    @Test
    func realTx_withLent_returnsLendingToCompensate() {
        // 2 miembros: total 40, myShare 20, lent 20. Con real -40, el virtual debe ser +20
        // → net = -20 = mi parte (no -60). Idéntico a bridge-ON Caso A.
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: true, lentAmount: 20
        ) == .lendingToCompensateReal)
    }

    @Test
    func realTx_zeroLent_returnsNoVirtual() {
        // Solo-yo: total 40, myShare 40, lent 0. Con real -40, sin virtual → net = -40 (no -80).
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: true, lentAmount: 0
        ) == .noVirtual)
    }

    @Test
    func realTx_negativeLent_returnsNoVirtual() {
        // Borde defensivo: lent negativo (data inconsistente) no debe crear un virtual.
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: true, lentAmount: -5
        ) == .noVirtual)
    }
}
