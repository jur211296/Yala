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
//   (d) Single-row `loadOrCreate` idempotente + durabilidad de los campos tras save + re-fetch, incluidos
//       los 2 aditivos de C-1 (`markerWrittenSince` / `cutoverICloudVerdictRaw`, schema v3): el reloj del
//       tope del paso 4 y el veredicto del canal iCloud solo sirven si sobreviven al kill Y si limpiarlos
//       llega al disco.
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
        // Reverse (§h, I11-1) — APPEND-ONLY. `reverseConfirm` carries a String-raw `ReverseOrigin`
        // (`_0` = raw string); `reverseReconcile` an Int-raw sub-state (`_0` = raw int, like cutover).
        (#"{"reverseConfirm":{"_0":"done"}}"#, .reverseConfirm(.done)),
        (#"{"reverseConfirm":{"_0":"notStarted"}}"#, .reverseConfirm(.notStarted)),
        (#"{"reverseClaimLeader":{}}"#, .reverseClaimLeader),
        (#"{"reverseDrainAll":{}}"#, .reverseDrainAll),
        (#"{"reverseVerify":{}}"#, .reverseVerify),
        (#"{"reverseFreezeBackend":{}}"#, .reverseFreezeBackend),
        (#"{"reverseMountMirror":{}}"#, .reverseMountMirror),
        (#"{"reverseReconcile":{"_0":0}}"#, .reverseReconcile(.awaitingQuiescence)),
        (#"{"reverseReconcile":{"_0":1}}"#, .reverseReconcile(.deletingZombies)),
        (#"{"reverseReconcile":{"_0":2}}"#, .reverseReconcile(.rebindingUUIDs)),
        (#"{"reverseReconcile":{"_0":3}}"#, .reverseReconcile(.dedupHealed)),
        (#"{"reverseUpload":{}}"#, .reverseUpload),
        (#"{"icloudActive":{}}"#, .icloudActive),
        (#"{"reverseFailedRollback":{}}"#, .reverseFailedRollback),
    ]

    // MARK: - (a) Estabilidad de wire (fixtures APPEND-ONLY)

    @Test func wireFixtures_coverEveryPhase() {
        // Guardia anti-drift: el número de fixtures == número de cases journalables. 16 forward (9 base +
        // 5 cutover que comparten el case padre + done + failedRollback) + 14 reversa (I11-1: reverseConfirm
        // ×2 origins + claimLeader/drainAll/verify/freezeBackend/mountMirror + reconcile ×4 subs + upload +
        // icloudActive + reverseFailedRollback) = 30.
        #expect(Self.wireFixtures.count == 30)
    }

    @Test func wireFixtures_coverEverySubstate_declaredByTheEnums() {
        // C-1 (cutover a prueba de iCloud lleno/ausente) NO añadió NINGUNA fase: solo 2 eventos —que no se
        // journalean— y 3 aristas. `wireFixtures_coverEveryPhase` pinnea el conteo de la LISTA literal, así
        // que no vería un sub-estado nuevo al que nadie le escribió fixture (la lista seguiría en 30 y el
        // case nuevo viajaría sin golden). Esto cierra el hueco por el lado del enum: todo `CutoverSubstate`
        // y todo `ReverseReconcileSubstate` DECLARADO tiene su literal congelado arriba.
        var cutoverSubs: Set<Sub> = []
        var reconcileSubs: Set<ReverseReconcileSubstate> = []
        for fixture in Self.wireFixtures {
            if case .cutover(let sub) = fixture.phase { cutoverSubs.insert(sub) }
            if case .reverseReconcile(let sub) = fixture.phase { reconcileSubs.insert(sub) }
        }
        #expect(cutoverSubs == Set(Sub.allCases),
                "cada CutoverSubstate necesita fixture wire — C-1 no añadió ninguno")
        #expect(reconcileSubs == Set(ReverseReconcileSubstate.allCases),
                "cada ReverseReconcileSubstate necesita fixture wire")
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

    // MARK: - (d·C-1) Durabilidad de los 2 campos del cutover a prueba de iCloud

    @Test func c1CutoverFields_roundTripAcrossSaveAndRefetch_includingNil() throws {
        // `markerWrittenSince` es el RELOJ del tope del paso 4 y `cutoverICloudVerdictRaw` el veredicto que
        // elige el copy del fallo: los dos tienen que sobrevivir al kill, o el limbo vuelve a ser eterno
        // (un `markerWrittenSince` que no persiste = elapsed 0 en cada arranque = presupuesto que nunca
        // vence). Se pinnean las TRES lecturas: default nil, valor tras save+re-fetch, y vuelta a nil
        // (limpiarlos en el rollback tiene que llegar al disco, no solo al objeto en memoria — un valor
        // stale re-usaría el reloj de un intento anterior y vencería el tope antes de empezar).
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let markerSince = Date(timeIntervalSince1970: 1_700_000_500)
        let state = try MigrationState.loadOrCreate(in: context)
        #expect(state.markerWrittenSince == nil, "la fila recién creada no ha alcanzado el paso 4")
        #expect(state.cutoverICloudVerdictRaw == nil, "sin veredicto registrado todavía")

        state.setPhase(.cutover(.markerWritten))
        state.markerWrittenSince = markerSince
        state.cutoverICloudVerdictRaw = ICloudChannelVerdict.quotaExceeded.rawValue
        try context.save()

        // Re-fetch en un contexto FRESCO del mismo store (simula re-arranque tras kill).
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        let context2 = ModelContext(context.container)
        let reloaded = try #require(try context2.fetch(descriptor).first)
        #expect(reloaded.readPhase().phase == .cutover(.markerWritten))
        #expect(reloaded.markerWrittenSince == markerSince)
        // El rawValue journaleado debe RECONSTRUIR el veredicto: si alguien renombra un case del enum, el
        // journal en vuelo se vuelve ilegible y el fallo perdería su copy honesto (cuota vs. sin cuenta).
        #expect(ICloudChannelVerdict(rawValue: reloaded.cutoverICloudVerdictRaw ?? "") == .quotaExceeded)

        // Limpieza (lo que hace el rollback) → nil DURABLE, no el valor viejo pegado.
        reloaded.markerWrittenSince = nil
        reloaded.cutoverICloudVerdictRaw = nil
        try context2.save()

        let context3 = ModelContext(context.container)
        let recleared = try #require(try context3.fetch(descriptor).first)
        #expect(recleared.markerWrittenSince == nil)
        #expect(recleared.cutoverICloudVerdictRaw == nil)
    }
}
