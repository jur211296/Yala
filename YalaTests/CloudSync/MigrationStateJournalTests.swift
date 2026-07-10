//
//  MigrationStateJournalTests.swift
//  YalaTests / CloudSync
//
//  Journal DURABLE de la máquina de migración (I10-wiring, ciclo A / w1). Ancla:
//   (a) ESTABILIDAD DE WIRE — un fixture JSON literal por CADA case de `MigrationPhase` (incl. los 5
//       `cutover(sub)`) decodifica al case esperado. Los cases son APPEND-ONLY una vez shippeados:
//       renombrar/borrar uno rompe este test ANTES de shippear (mitiga el decode-fallback a `.notStarted`
//       que en mid-cutover real leería "estable" y engañaría al gate §i.9).
//   (b) Round-trip fase + efectos vía el codec de `MigrationState` (`setPhase`/`readPhase`,
//       `setPendingEffects`/`readPendingEffects`).
//   (c) `readPhase()` puro: nil ⇒ `.notStarted` sin fallo; blob corrupto ⇒ `.notStarted` + `decodeFailed`.
//   (d) Single-row `loadOrCreate` idempotente + durabilidad de los campos tras save + re-fetch.
//
//  Container ON-DISK temp con los 3 stores (patrón CloudSyncRuntimeTests). `.serialized` (usa container).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("MigrationState · journal (I10-wiring w1)", .serialized)
@MainActor
struct MigrationStateJournalTests {

    typealias Phase = MigrationPhase
    typealias Sub = CutoverSubstate
    typealias Effect = MigrationEffect

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MStateJournal-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "MSJ-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "MSJ-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "MSJ-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Cada case de `MigrationPhase` con su fixture JSON literal CONGELADO (APPEND-ONLY). Verificado
    /// empíricamente contra la síntesis Codable de Swift (cases sin payload ⇒ `{"case":{}}`; `cutover`
    /// ⇒ `{"cutover":{"_0":<rawValue>}}`).
    static let wireFixtures: [(json: String, phase: Phase)] = [
        (#"{"notStarted":{}}"#, .notStarted),
        (#"{"dryRun":{}}"#, .dryRun),
        (#"{"consent":{}}"#, .consent),
        (#"{"authenticating":{}}"#, .authenticating),
        (#"{"waitingForLeader":{}}"#, .waitingForLeader),
        (#"{"claimingMigration":{}}"#, .claimingMigration),
        (#"{"assigningIdentity":{}}"#, .assigningIdentity),
        (#"{"uploadingSnapshot":{}}"#, .uploadingSnapshot),
        (#"{"verifying":{}}"#, .verifying),
        (#"{"cutover":{"_0":0}}"#, .cutover(.pending)),
        (#"{"cutover":{"_0":1}}"#, .cutover(.serverConfirmed)),
        (#"{"cutover":{"_0":2}}"#, .cutover(.localModeSet)),
        (#"{"cutover":{"_0":3}}"#, .cutover(.markerWritten)),
        (#"{"cutover":{"_0":4}}"#, .cutover(.mirrorOff)),
        (#"{"done":{}}"#, .done),
        (#"{"failedRollback":{}}"#, .failedRollback),
    ]

    // MARK: - (a) Estabilidad de wire (fixtures APPEND-ONLY)

    @Test func wireFixtures_coverEveryPhase() {
        // Guardia anti-drift: el número de fixtures == número de cases journalables (14 base + los 5
        // cutover comparten el mismo case padre, así que 9 base + 5 cutover + done + failedRollback = 16).
        #expect(Self.wireFixtures.count == 16)
    }

    @Test func frozenWireLiteral_decodesToExpectedPhase() throws {
        let decoder = JSONDecoder()
        for fixture in Self.wireFixtures {
            let decoded = try decoder.decode(Phase.self, from: Data(fixture.json.utf8))
            #expect(decoded == fixture.phase, "wire literal \(fixture.json) debe decodificar a \(fixture.phase)")
        }
    }

    @Test func frozenWireLiteral_readThroughMigrationStateCodec() {
        for fixture in Self.wireFixtures {
            let state = MigrationState(phaseData: Data(fixture.json.utf8))
            let result = state.readPhase()
            #expect(result.phase == fixture.phase, "readPhase de \(fixture.json) debe dar \(fixture.phase)")
            #expect(result.decodeFailed == false)
        }
    }

    // MARK: - (b) Round-trip fase + efectos vía el codec

    @Test func setPhase_thenReadPhase_roundTripsEveryPhase() {
        for fixture in Self.wireFixtures {
            let state = MigrationState()
            state.setPhase(fixture.phase)
            #expect(state.readPhase().phase == fixture.phase)
            #expect(state.readPhase().decodeFailed == false)
        }
    }

    @Test func setPendingEffects_thenRead_roundTrips() {
        let all: [Effect] = [
            .writeBeacon, .startParallelHistoryCapture, .writeCloudKitMarker,
            .disableMirrorAndRelaunch, .runLeaderReconcileFromFrozenCloudKit,
            .rollback, .adoptBackendAccount,
        ]
        let state = MigrationState()
        state.setPendingEffects(all)
        #expect(state.readPendingEffects() == all, "el orden y contenido de los efectos debe preservarse")
    }

    @Test func setPendingEffects_empty_writesEmptyNotNil() {
        let state = MigrationState()
        state.setPendingEffects([.writeBeacon])
        state.setPendingEffects([])            // journal EXPLÍCITO de "sin pendientes"
        #expect(state.pendingEffectsData != nil, "[] se journalea como blob explícito, no como nil")
        #expect(state.readPendingEffects().isEmpty)
    }

    @Test func effectRawValues_areWireStable() {
        // Los raw values del wire son APPEND-ONLY (los consume pendingEffectsData). Anclados aquí.
        #expect(Effect.writeBeacon.rawValue == "writeBeacon")
        #expect(Effect.startParallelHistoryCapture.rawValue == "startParallelHistoryCapture")
        #expect(Effect.writeCloudKitMarker.rawValue == "writeCloudKitMarker")
        #expect(Effect.disableMirrorAndRelaunch.rawValue == "disableMirrorAndRelaunch")
        #expect(Effect.runLeaderReconcileFromFrozenCloudKit.rawValue == "runLeaderReconcileFromFrozenCloudKit")
        #expect(Effect.rollback.rawValue == "rollback")
        #expect(Effect.adoptBackendAccount.rawValue == "adoptBackendAccount")
    }

    // MARK: - (c) readPhase puro: nil / corrupto

    @Test func readPhase_nilData_isNotStartedNoFailure() {
        let state = MigrationState()
        let result = state.readPhase()
        #expect(result.phase == .notStarted)
        #expect(result.decodeFailed == false)
    }

    @Test func readPhase_corruptData_fallsBackToNotStartedWithFailureFlag() {
        let state = MigrationState(phaseData: Data(#"{"someRemovedCase":{}}"#.utf8))
        let result = state.readPhase()
        #expect(result.phase == .notStarted)
        #expect(result.decodeFailed == true, "un blob presente que no decodifica delata rot del enum")
    }

    @Test func readPendingEffects_nilData_isEmpty() {
        #expect(MigrationState().readPendingEffects().isEmpty)
    }

    // MARK: - (d) Single-row load-or-create + durabilidad

    @Test func loadOrCreate_isIdempotent_singleRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let first = try MigrationState.loadOrCreate(in: context)
        let second = try MigrationState.loadOrCreate(in: context)

        #expect(first.persistentModelID == second.persistentModelID, "loadOrCreate debe reusar la fila única")
        let count = try context.fetchCount(FetchDescriptor<MigrationState>())
        #expect(count == 1, "a lo sumo UNA fila de MigrationState")
    }

    @Test func journalFields_persistAcrossSaveAndRefetch() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = try MigrationState.loadOrCreate(in: context)
        state.setPhase(.cutover(.localModeSet))
        state.setPendingEffects([.writeCloudKitMarker])
        state.snapshotCursorJSON = "cursor-page-7"
        state.verifyMismatchRetries = 2
        state.verifyNetworkRetries = 5
        state.leaderDeviceID = "device-ABC"
        state.serverSeqCut = 4242
        state.startedAt = now
        state.updatedAt = now
        try context.save()

        // Re-fetch en un contexto FRESCO del mismo store (simula re-arranque tras kill).
        let context2 = ModelContext(context.container)
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        let reloaded = try #require(try context2.fetch(descriptor).first)

        #expect(reloaded.readPhase().phase == .cutover(.localModeSet))
        #expect(reloaded.readPendingEffects() == [.writeCloudKitMarker])
        #expect(reloaded.snapshotCursorJSON == "cursor-page-7")
        #expect(reloaded.verifyMismatchRetries == 2)
        #expect(reloaded.verifyNetworkRetries == 5)
        #expect(reloaded.leaderDeviceID == "device-ABC")
        #expect(reloaded.serverSeqCut == 4242)
        #expect(reloaded.startedAt == now)
    }
}
