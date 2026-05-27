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
}
