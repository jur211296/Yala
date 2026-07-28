//
//  GroupPullRescueChannelTests.swift
//  YalaTests / CloudSync
//
//  C-4 (PIEZA 2): las dos piezas del rescate que viven en el CANAL y no en el delegate de CloudKit —
//  la señal «¿está asentado el backend para este grupo?» y el suelo del corte del History.
//
//  Infra al molde de `GroupsSyncClientTests`: container ON-DISK temp con los 3 stores (el History es
//  por-CONTAINER, que es justo el punto del segundo bloque).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("C-4 PIEZA 2 · señal del canal backend y suelo del History", .serialized)
@MainActor
struct GroupPullRescueChannelTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupRescue-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Fila del outbox de Grupos con lo mínimo para que cuente como pendiente de subir.
    private func makeGroupRow(createdAt: Date, rejectedReason: String? = nil) -> GroupSyncOutbox {
        GroupSyncOutbox(
            syncID: UUID(), groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitExpense,
            op: .upsert, hlc: "2021-01-01T00:00:00.000Z-0000-00000000000000b1",
            fieldsJSON: #"{"amount":"1.0000"}"#, author: GroupsSyncClient.outboxSaveAuthor,
            createdAt: createdAt, rejectedReason: rejectedReason)
    }

    // MARK: - backendPullSignal

    /// Sin fila de cursor todavía: nadie ha pulleado nada ⇒ ninguna de las dos señales abre el rescate.
    /// Y —lo que importa para un método que corre en el camino caliente del delegate— la lectura NO crea
    /// la fila: `loadOrCreateCursor` la insertaría y haría `save()` sobre el `mainContext` compartido.
    @Test func withoutACursorRowTheSignalIsClosedAndNothingIsCreated() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        let signal = client.backendPullSignal(groupID: "SplitGroup-A", context: context)
        #expect(!signal.completed)
        #expect(!signal.hasCursor)
        #expect(try context.fetch(FetchDescriptor<GroupSyncCursor>()).isEmpty,
                "backendPullSignal debe ser una LECTURA pura: crear la fila aquí metería un save en el pull de CloudKit")
    }

    /// El cursor por grupo es lo que ata la señal al grupo CONCRETO: un pull completo que listó a A no
    /// dice nada de B.
    @Test func theCursorIsPerGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.insert(GroupSyncCursor(groupCursorsJSON: #"{"SplitGroup-A":42}"#))
        try context.save()

        let client = GroupsSyncClient()
        client._testMarkPullCompleted()

        let a = client.backendPullSignal(groupID: "SplitGroup-A", context: context)
        #expect(a.completed)
        #expect(a.hasCursor)

        let b = client.backendPullSignal(groupID: "SplitGroup-B", context: context)
        #expect(b.completed)
        #expect(!b.hasCursor, "un grupo que el server aún no ha listado no puede abrir el rescate")
    }

    /// Con cursor pero sin un pull COMPLETO en esta sesión (arranque, ciclo transitorio, 401) la señal
    /// sigue cerrada: la cola del server podría tener deltas sin aplicar.
    @Test func aCursorWithoutACompletedPullIsNotEnough() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.insert(GroupSyncCursor(groupCursorsJSON: #"{"SplitGroup-A":7}"#))
        try context.save()

        let signal = GroupsSyncClient().backendPullSignal(groupID: "SplitGroup-A", context: context)
        #expect(!signal.completed)
        #expect(signal.hasCursor)
        // Y el gate, con esa señal, descarta.
        #expect(GroupPullRescueGate.decide(GroupPullRescueGate.Signal(
            flagOn: true, replayingFullCorpus: false, prefetchFailed: false,
            backendPullCompletedThisSession: signal.completed,
            groupHasBackendCursor: signal.hasCursor,
            isRescuableType: true, existsLocally: false)) == .discard)
    }

    /// Un `groupCursorsJSON` corrupto no puede abrir el rescate por accidente.
    @Test func corruptCursorJSONClosesTheSignal() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.insert(GroupSyncCursor(groupCursorsJSON: "no-soy-json"))
        try context.save()

        let client = GroupsSyncClient()
        client._testMarkPullCompleted()
        #expect(!client.backendPullSignal(groupID: "SplitGroup-A", context: context).hasCursor)
    }

    // MARK: - Suelo del corte del History (el History es por CONTAINER)

    /// EL BUG QUE CIERRA: el corte solo miraba el outbox PERSONAL. Con el rescate cableado, eso podía
    /// borrar la transacción de History de una fila recién adoptada antes de que el drain de Grupos —que
    /// lee el MISMO History con su propia ancla— llegara a verla: la fila se quedaba local y jamás subía.
    @Test func theCutNeverOvertakesTheGroupsDrainAnchor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let farFuture = Date(timeIntervalSince1970: 9_999_999)
        let groupsAnchor = Date(timeIntervalSince1970: 1_000)

        context.insert(GroupSyncCursor(lastDrainedTxAt: groupsAnchor))
        try context.save()

        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == groupsAnchor)
    }

    /// Una fila VIVA del outbox de Grupos retiene el corte igual que la del personal: su transacción de
    /// History es el backup del delta hasta el 2xx.
    @Test func aLiveGroupOutboxRowHoldsTheCut() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let farFuture = Date(timeIntervalSince1970: 9_999_999)
        let rowDate = Date(timeIntervalSince1970: 2_000)

        context.insert(makeGroupRow(createdAt: rowDate))
        try context.save()

        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == rowDate)
    }

    /// Una fila en DEAD-LETTER no retiene nada: no va a subir nunca, y retener su History por ella
    /// dejaría el corte clavado para siempre. Mismo criterio que `liveGroupOutboxCount`, del que ya
    /// depende el paso 5 del uploader de la migración.
    @Test func aDeadLetteredGroupRowDoesNotHoldTheCut() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let farFuture = Date(timeIntervalSince1970: 9_999_999)

        context.insert(makeGroupRow(
            createdAt: Date(timeIntervalSince1970: 2_000),
            rejectedReason: "upstream_400:yala_bad_request"))
        try context.save()

        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == farFuture)
    }

    /// El corte es el MÍNIMO de todos los suelos: gana el más conservador, venga del canal que venga.
    @Test func theCutIsTheMinimumAcrossBothChannels() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let farFuture = Date(timeIntervalSince1970: 9_999_999)
        let personalDate = Date(timeIntervalSince1970: 5_000)
        let groupsDate = Date(timeIntervalSince1970: 3_000)

        context.insert(SyncOutbox(
            syncID: UUID(), entityType: SyncEntityType.transactionItem, op: .upsert,
            hlc: "2021-01-01T00:00:00.000Z-0000-00000000000000a1",
            fieldsJSON: #"{"amount":"1.0000"}"#, author: CloudSyncEngine.outboxSaveAuthor,
            createdAt: personalDate))
        context.insert(makeGroupRow(createdAt: groupsDate))
        try context.save()

        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == groupsDate)
    }

    /// NO-REGRESIÓN: sin nada del canal de Grupos, el corte es EXACTAMENTE el de antes del fix.
    @Test func withoutTheGroupsChannelTheCutIsUnchanged() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let personalDate = Date(timeIntervalSince1970: 5_000)

        #expect(try engine.deleteHistorySafeCut(drainedBoundary: nil, context: context) == nil)

        context.insert(SyncOutbox(
            syncID: UUID(), entityType: SyncEntityType.transactionItem, op: .upsert,
            hlc: "2021-01-01T00:00:00.000Z-0000-00000000000000a1",
            fieldsJSON: #"{"amount":"1.0000"}"#, author: CloudSyncEngine.outboxSaveAuthor,
            createdAt: personalDate))
        try context.save()

        #expect(try engine.deleteHistorySafeCut(drainedBoundary: nil, context: context) == personalDate)
        #expect(try engine.deleteHistorySafeCut(
            drainedBoundary: Date(timeIntervalSince1970: 1), context: context) == Date(timeIntervalSince1970: 1))
    }
}
