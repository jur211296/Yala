//
//  MigrationPhaseStoreTests.swift
//  YalaTests
//
//  SSOT de fase (§i.9): sin override → `.notStarted` (comportamiento de producción); con override DEBUG
//  → la fase mapeada. Guarda el mapeo del espejo PLANO → `MigrationPhase` (en especial el único
//  transitorio con associated value, `cutover(.localModeSet)`) y el round-trip persistido.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Migration Phase Store (§i.9)")
struct MigrationPhaseStoreTests {

    @Test func noOverride_isNotStarted() {
        let store = MigrationPhaseStore(defaults: makeIsolatedDefaults(prefix: "s7.none"))
        #expect(store.simulatedPhase == nil)
        #expect(store.currentPhaseRead == .phase(.notStarted))
    }

    @Test func override_mapsToPhase_andPersists() {
        let defaults = makeIsolatedDefaults(prefix: "s7.set")
        let store = MigrationPhaseStore(defaults: defaults)

        store.setSimulatedPhase(.cutoverLocalModeSet)
        #expect(store.simulatedPhase == .cutoverLocalModeSet)
        #expect(store.currentPhaseRead == .phase(.cutover(.localModeSet)))

        // Round-trip: un store nuevo sobre los MISMOS defaults recupera el override persistido.
        let reopened = MigrationPhaseStore(defaults: defaults)
        #expect(reopened.currentPhaseRead == .phase(.cutover(.localModeSet)))
    }

    @Test func clearOverride_returnsToNotStarted() {
        let store = MigrationPhaseStore(defaults: makeIsolatedDefaults(prefix: "s7.clear"))
        store.setSimulatedPhase(.verifying)
        #expect(store.currentPhaseRead == .phase(.verifying))
        store.setSimulatedPhase(nil)
        #expect(store.simulatedPhase == nil)
        #expect(store.currentPhaseRead == .phase(.notStarted))
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

// MARK: - Journal-backed (I10-wiring w6)

/// `configure(container:)` conecta el journal REAL: `currentPhaseRead` refleja la fase journaleada y la
/// derivación al boot enciende `identityCaptureEnabled` en la ventana de captura. Toca ese flag global →
/// `.serialized` + `defer { restore }`.
@MainActor
@Suite("Migration Phase Store · journal-backed (§i.9, I10-wiring w6)", .serialized)
struct MigrationPhaseStoreJournalTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MPStore-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "MPS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "MPS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "MPS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    private func seedJournal(_ container: ModelContainer, phase: MigrationPhase) throws {
        let context = ModelContext(container)
        let state = MigrationState()
        state.setPhase(phase)
        context.insert(state)
        try context.save()
    }

    private func makeStore() -> MigrationPhaseStore {
        MigrationPhaseStore(defaults: makeIsolatedDefaults(prefix: "mps.journal"))
    }

    @Test func noConfigure_isNotStarted() {
        #expect(makeStore().currentPhaseRead == .phase(.notStarted))
    }

    @Test func journalTransitory_reflectsPhase_andGateSuspendsWriter() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .verifying)
        let store = makeStore()
        store.configure(container: container)

        #expect(store.currentPhaseRead == .phase(.verifying))
        // El gate §i.9 con esta fase transitoria SUSPENDE al lector y difiere al escritor sin quiescencia.
        #expect(BGTaskMigrationGate.decide(read: store.currentPhaseRead, isImportQuiescent: false, role: .reader)
                == .suspendAndReschedule)
        #expect(BGTaskMigrationGate.decide(read: store.currentPhaseRead, isImportQuiescent: false, role: .writer)
                == .deferAndReschedule)
    }

    @Test func journalStable_done_runsNormally() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .done)
        let store = makeStore()
        store.configure(container: container)

        #expect(store.currentPhaseRead == .phase(.done))
        #expect(BGTaskMigrationGate.decide(read: store.currentPhaseRead, isImportQuiescent: false, role: .reader) == .run)
    }

    @Test func journalEmpty_isNotStarted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)          // sin fila de journal
        let store = makeStore()
        store.configure(container: container)
        #expect(store.currentPhaseRead == .phase(.notStarted))
    }

    /// Ticket `apple-id-change-check-stays-off-after-a-failed-migration`: la fase y los pendientes salen del MISMO fetch.
    /// Un `failedRollback` con su `.rollback` sin ejecutar no está asentado; tras drenarlo, sí.
    @Test func journalRead_carriesThePendingEffectsOfTheSameRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        let context = ModelContext(container)
        let state = MigrationState()
        state.setPhase(.failedRollback)
        state.setPendingEffects([.rollback])
        context.insert(state)
        try context.save()
        let store = makeStore()
        store.configure(container: container)

        #expect(store.currentJournalRead == .read(phase: .failedRollback, hasPendingEffects: true))
        #expect(store.currentJournalRead.hasPendingEffects)
        #expect(store.currentPhaseRead == .phase(.failedRollback))

        state.setPendingEffects([])
        try context.save()
        #expect(store.currentJournalRead == .read(phase: .failedRollback, hasPendingEffects: false))
        #expect(!store.currentJournalRead.hasPendingEffects)

        // Cualquier efecto cuenta, no solo `.rollback`: el aborto del paso 4 deja `.persistICloudMode` delante, y ese es
        // el que devuelve el modo a `.icloud` (mutante de la review: contar solo `.rollback`).
        state.setPendingEffects([.persistICloudMode])
        try context.save()
        #expect(store.currentJournalRead == .read(phase: .failedRollback, hasPendingEffects: true))
    }

    @Test func journalRead_withoutRowOrContainer_hasNothingPending() throws {
        #expect(makeStore().currentJournalRead == .read(phase: .notStarted, hasPendingEffects: false))
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        let store = makeStore()
        store.configure(container: container)
        #expect(store.currentJournalRead == .read(phase: .notStarted, hasPendingEffects: false))
    }

    /// Ilegible no lleva valores, y quien pregunte por los pendientes recibe el lado que no concede.
    @Test func journalRead_unreadable_countsAsPending() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .failedRollback)
        let store = makeStore()
        store.configure(container: container)
        store._testJournalFetchThrows = true
        #expect(store.currentJournalRead == .unreadable)
        #expect(store.currentJournalRead.hasPendingEffects)
        #expect(store.currentJournalRead.phaseRead == .unreadable)
    }

    @Test func configure_derivesIdentityCaptureEnabled_inWindow() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }
        CloudSyncFlags.identityCaptureEnabled = false

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .uploadingSnapshot)   // fase ≥ assigningIdentity, no terminal
        makeStore().configure(container: container)

        #expect(CloudSyncFlags.identityCaptureEnabled, "la derivación al boot debe encender el gate permanente")
    }

    @Test func configure_doesNotForceFlag_outsideWindow() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }
        CloudSyncFlags.identityCaptureEnabled = false

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .notStarted)   // fuera de la ventana
        makeStore().configure(container: container)

        #expect(CloudSyncFlags.identityCaptureEnabled == false, "notStarted NO enciende el gate")
    }

    @Test func identityCaptureWindow_classification() {
        #expect(MigrationPhaseStore.isIdentityCaptureWindow(.assigningIdentity))
        #expect(MigrationPhaseStore.isIdentityCaptureWindow(.uploadingSnapshot))
        #expect(MigrationPhaseStore.isIdentityCaptureWindow(.verifying))
        #expect(MigrationPhaseStore.isIdentityCaptureWindow(.cutover(.pending)))
        #expect(MigrationPhaseStore.isIdentityCaptureWindow(.cutover(.mirrorOff)))
        #expect(!MigrationPhaseStore.isIdentityCaptureWindow(.notStarted))
        #expect(!MigrationPhaseStore.isIdentityCaptureWindow(.claimingMigration))
        #expect(!MigrationPhaseStore.isIdentityCaptureWindow(.waitingForLeader))
        #expect(!MigrationPhaseStore.isIdentityCaptureWindow(.done))
        #expect(!MigrationPhaseStore.isIdentityCaptureWindow(.failedRollback))
    }
}
