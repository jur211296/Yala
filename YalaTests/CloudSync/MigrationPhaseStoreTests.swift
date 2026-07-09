//
//  MigrationPhaseStoreTests.swift
//  YalaTests
//
//  SSOT de fase (§i.9): sin override → `.notStarted` (comportamiento de producción); con override DEBUG
//  → la fase mapeada. Guarda el mapeo del espejo PLANO → `MigrationPhase` (en especial el único
//  transitorio con associated value, `cutover(.localModeSet)`) y el round-trip persistido.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Migration Phase Store (§i.9)")
struct MigrationPhaseStoreTests {

    @Test func noOverride_isNotStarted() {
        let store = MigrationPhaseStore(defaults: makeIsolatedDefaults(prefix: "s7.none"))
        #expect(store.simulatedPhase == nil)
        #expect(store.currentPhase == .notStarted)
    }

    @Test func override_mapsToPhase_andPersists() {
        let defaults = makeIsolatedDefaults(prefix: "s7.set")
        let store = MigrationPhaseStore(defaults: defaults)

        store.setSimulatedPhase(.cutoverLocalModeSet)
        #expect(store.simulatedPhase == .cutoverLocalModeSet)
        #expect(store.currentPhase == .cutover(.localModeSet))

        // Round-trip: un store nuevo sobre los MISMOS defaults recupera el override persistido.
        let reopened = MigrationPhaseStore(defaults: defaults)
        #expect(reopened.currentPhase == .cutover(.localModeSet))
    }

    @Test func clearOverride_returnsToNotStarted() {
        let store = MigrationPhaseStore(defaults: makeIsolatedDefaults(prefix: "s7.clear"))
        store.setSimulatedPhase(.verifying)
        #expect(store.currentPhase == .verifying)
        store.setSimulatedPhase(nil)
        #expect(store.simulatedPhase == nil)
        #expect(store.currentPhase == .notStarted)
    }

    @Test func everySimulatedPhase_mapsToExpectedMigrationPhase() {
        let expected: [MigrationPhaseStore.SimulatedPhase: MigrationPhase] = [
            .notStarted: .notStarted,
            .assigningIdentity: .assigningIdentity,
            .uploadingSnapshot: .uploadingSnapshot,
            .verifying: .verifying,
            .cutoverLocalModeSet: .cutover(.localModeSet),
            .done: .done
        ]
        // Guard de exhaustividad: cubre TODOS los casos del espejo.
        #expect(expected.count == MigrationPhaseStore.SimulatedPhase.allCases.count)
        for simulated in MigrationPhaseStore.SimulatedPhase.allCases {
            #expect(simulated.migrationPhase == expected[simulated])
        }
    }
}
