//
//  GroupsHistoryCutFloorTests.swift
//  YalaTests / CloudSync
//
//  El suelo del corte del History del canal de Grupos: `CloudSyncEngine.deleteHistorySafeCut` tiene que
//  respetar las anclas de Grupos (`GroupSyncCursor.lastDrainedTxAt` y la fila VIVA más vieja de
//  `GroupSyncOutbox`), no solo el outbox personal. El History es por-CONTAINER y con 2.1 el backend es el
//  ÚNICO canal de Grupos: sin este suelo, el pruning personal puede comerse la transacción de una fila del
//  outbox de Grupos antes de que suba.
//
//  Infra al molde de `GroupsSyncClientTests`: container ON-DISK temp con los 3 stores.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Suelo del corte del History del canal de Grupos", .serialized)
@MainActor
struct GroupsHistoryCutFloorTests {

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

    // MARK: - Suelo del corte del History (el History es por CONTAINER)

    /// EL BUG QUE CIERRA: el corte solo miraba el outbox PERSONAL, así que podía borrar la transacción de
    /// History de una fila de Grupos antes de que el drain de Grupos —que lee el MISMO History con su
    /// propia ancla— llegara a verla: la fila se quedaba local y jamás subía.
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
    /// dejaría el corte clavado para siempre.
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
