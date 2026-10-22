//
//  SyncQuiescenceCoordinatorTests.swift
//  YalaTests / CloudSync
//
//  SSOT de quiescencia (I9): enrutado por modo + paridad con la fuente icloud + estado del motor
//  (apply en vuelo, primer pull). Sin container (solo closures inyectadas).
//

import Testing

@testable import Yala

@Suite("SyncQuiescenceCoordinator · quiescencia I9", .serialized)
@MainActor
struct SyncQuiescenceCoordinatorTests {

    // MARK: - Paridad en .icloud (regla DARK: fuente EXACTA de iCloudSyncService)

    @Test func icloud_isImportQuiescent_mirrorsSourceExactly_true() {
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud })
        #expect(c.isImportQuiescent == true)
    }

    @Test func icloud_isImportQuiescent_mirrorsSourceExactly_false() {
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { false }, modeProvider: { .icloud })
        #expect(c.isImportQuiescent == false)
    }

    @Test func icloud_ignoresEngineApplyState() {
        // En .icloud la fuente es la de CloudKit; el apply del motor NO la altera.
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud })
        c.markApplyBegan()
        #expect(c.isImportQuiescent == true)  // sigue la fuente icloud, no el apply
    }

    // MARK: - .cloud usa la quiescencia del propio motor

    @Test func cloud_isImportQuiescent_isPersonalApplyQuiescent() {
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { false }, modeProvider: { .cloud })
        #expect(c.isImportQuiescent == true)   // sin apply en vuelo
        c.markApplyBegan()
        #expect(c.isImportQuiescent == false)  // apply en vuelo → no quieto
        c.markApplyEnded()
        #expect(c.isImportQuiescent == true)
    }

    // MARK: - Señal dedicada para saves del propio motor (SERIO-1)

    @Test func cloud_engineSavesGate_openDuringOwnApplyWindow() {
        // SERIO-1: en `.cloud`, con el batch propio EN VUELO (markApplyBegan), el gate de los
        // reconcilers (isQuiescentForEngineSaves) debe estar ABIERTO — usar isImportQuiescent ahí
        // produciría deferral perpetuo (los reconcilers corren DENTRO de esa ventana).
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { false }, modeProvider: { .cloud })
        c.markApplyBegan()
        #expect(c.isQuiescentForEngineSaves == true)   // gate de reconcilers ABIERTO
        #expect(c.isImportQuiescent == false)          // la señal general sigue cerrada para los demás
        c.markApplyEnded()
        #expect(c.isQuiescentForEngineSaves == true)
    }

    @Test func icloud_engineSavesGate_followsICloudSource() {
        // En `.icloud` la señal dedicada sigue a la fuente de CloudKit (import ajeno = peligro real),
        // ignorando el estado del batch propio.
        let closed = SyncQuiescenceCoordinator(icloudQuiescent: { false }, modeProvider: { .icloud })
        #expect(closed.isQuiescentForEngineSaves == false)
        let open = SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud })
        open.markApplyBegan()
        #expect(open.isQuiescentForEngineSaves == true)  // el batch propio no la cierra
    }

    // MARK: - Estado del motor

    @Test func applyBeganEnded_togglesPersonalApplyQuiescent() {
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud })
        #expect(c.isPersonalApplyQuiescent == true)
        c.markApplyBegan()
        #expect(c.isPersonalApplyQuiescent == false)
        c.markApplyEnded()
        #expect(c.isPersonalApplyQuiescent == true)
    }

    @Test func firstPull_latches() {
        let c = SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud })
        #expect(c.hasCompletedFirstPull == false)
        c.markFirstPullCompleted()
        #expect(c.hasCompletedFirstPull == true)
    }
}
