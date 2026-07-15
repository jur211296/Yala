//
//  CloudSignOutFlowLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Cerrar sesión — camino por modo y visibilidad (H4 + G5-B)")
struct CloudSignOutFlowLogicTests {

    // Helper: la matriz de HOY (flag OFF, sin sesión backend = TODO device prod) debe ser byte-idéntica.
    private func path(_ mode: StorageMode, secondary: Bool) -> CloudSignOutFlowLogic.Path {
        CloudSignOutFlowLogic.path(
            for: mode, secondarySessionActive: secondary,
            hasLiveSession: false, groupsBackendEnabled: false)
    }

    @Test
    func icloud_usesPrivateReset() {
        #expect(path(.icloud, secondary: false) == .privateReset)
    }

    @Test
    func cloud_usesCloudSecureSignOut() {
        #expect(path(.cloud, secondary: false) == .cloudSecureSignOut)
    }

    @Test
    func secondarySession_winsOverBothModes() {
        // M1 — la trampa de la atomicidad: en secundaria el modo EFECTIVO es `.cloud`; sin esta
        // rama el sign-out iría a `.cloudSecureSignOut` → armSignOutWipe → el boot borraría el
        // YalaModel del DUEÑO. La secundaria gana sobre cualquier modo.
        #expect(path(.cloud, secondary: true) == .secondaryCloudSignOut)
        #expect(path(.icloud, secondary: true) == .secondaryCloudSignOut)
    }

    // MARK: - Fila NUEVA (G5-B): solo-grupos + precedencias

    @Test
    func groupsOnly_whenFlagOnAndLiveSessionAndICloud() {
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: false,
            hasLiveSession: true, groupsBackendEnabled: true) == .groupsOnlySignOut)
    }

    @Test
    func groupsOnly_requiresBothFlagAndSession() {
        // Flag ON pero sin sesión → privado (no hay sesión que cerrar).
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: false,
            hasLiveSession: false, groupsBackendEnabled: true) == .privateReset)
        // Sesión viva pero flag OFF (TODO device prod) → privado byte-idéntico.
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: false,
            hasLiveSession: true, groupsBackendEnabled: false) == .privateReset)
    }

    @Test
    func cloud_winsOverGroupsOnly() {
        // Precedencia 2 > 3: en `.cloud` el store personal lo sincroniza el motor → wipe por archivos.
        #expect(CloudSignOutFlowLogic.path(
            for: .cloud, secondarySessionActive: false,
            hasLiveSession: true, groupsBackendEnabled: true) == .cloudSecureSignOut)
    }

    @Test
    func secondary_winsOverGroupsOnly() {
        // Precedencia 1 > 3.
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: true,
            hasLiveSession: true, groupsBackendEnabled: true) == .secondaryCloudSignOut)
    }

    // MARK: - Copy honesto (mapeo path → mensaje)

    @Test
    func confirmMessage_mapsEachPath() {
        #expect(CloudSignOutFlowLogic.confirmMessage(for: .privateReset) == .icloud)
        #expect(CloudSignOutFlowLogic.confirmMessage(for: .cloudSecureSignOut) == .cloud)
        #expect(CloudSignOutFlowLogic.confirmMessage(for: .secondaryCloudSignOut) == .secondary)
        #expect(CloudSignOutFlowLogic.confirmMessage(for: .groupsOnlySignOut) == .groupsOnly)
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
