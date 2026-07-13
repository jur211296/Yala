//
//  CloudSignOutFlowLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Cerrar sesión — camino por modo y visibilidad (H4)")
struct CloudSignOutFlowLogicTests {

    @Test
    func icloud_usesPrivateReset() {
        #expect(CloudSignOutFlowLogic.path(for: .icloud, secondarySessionActive: false) == .privateReset)
    }

    @Test
    func cloud_usesCloudSecureSignOut() {
        #expect(CloudSignOutFlowLogic.path(for: .cloud, secondarySessionActive: false) == .cloudSecureSignOut)
    }

    @Test
    func secondarySession_winsOverBothModes() {
        // M1 — la trampa de la atomicidad: en secundaria el modo EFECTIVO es `.cloud`; sin esta
        // rama el sign-out iría a `.cloudSecureSignOut` → armSignOutWipe → el boot borraría el
        // YalaModel del DUEÑO. La secundaria gana sobre cualquier modo.
        #expect(CloudSignOutFlowLogic.path(for: .cloud, secondarySessionActive: true) == .secondaryCloudSignOut)
        #expect(CloudSignOutFlowLogic.path(for: .icloud, secondarySessionActive: true) == .secondaryCloudSignOut)
    }

    @Test
    func row_alwaysVisible_exceptGroupInviteMode() {
        #expect(CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: false) == true)
        #expect(CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: true) == false)
    }
}

@Suite("Cerrar sesión — veredicto del push-all (.cloud)")
struct CloudSignOutPushAllVerdictTests {

    @Test
    func outboxEmpty_isDrained_regardlessOfCycleOutcome() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleSucceeded: true, iteration: 1, maxIterations: 10
        ) == .drained)
        // Ciclo con error pero outbox ya vacío → drained igual (el objetivo se cumplió).
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleSucceeded: false, iteration: 3, maxIterations: 10
        ) == .drained)
    }

    @Test
    func pendingWithSuccessfulCycle_keepsIterating() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 12, cycleSucceeded: true, iteration: 2, maxIterations: 10
        ) == nil)
    }

    @Test
    func pendingWithFailedCycle_blocks() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 5, cycleSucceeded: false, iteration: 1, maxIterations: 10
        ) == .blocked(pendingCount: 5))
    }

    @Test
    func pendingAtMaxIterations_blocks_evenWithSuccessfulCycle() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 3, cycleSucceeded: true, iteration: 10, maxIterations: 10
        ) == .blocked(pendingCount: 3))
    }
}
