//
//  DrainIndexesOnlyWhatItTranslatesTests.swift
//  YalaTests / CloudSync
//
//  YALA-IOS-2 (Sentry, 2.2 (5)): la app se congelaba varios segundos con Core Data en el hilo principal. El drenaje de
//  sync —personal y de Grupos— es `@MainActor` y síncrono, corre cada 60 s, tras cada pull y en cada página de la
//  subida de la migración, y en CADA vuelta cargaba e indexaba todas las filas de sus tipos (16 personales, 4 de
//  Grupos) antes de mirar si el History traía algo. Desde el arreglo indexa solo las entidades que la ventana va a
//  traducir.
//
//  El oráculo es el testigo `lastDrainIndexedEntities` (qué índices cargó la vuelta) más lo que de verdad importa: que
//  las filas del outbox sigan saliendo. Un índice que falte se lee como «borrada» y su cambio no sale, así que cada
//  caso positivo comprueba también la fila.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Drain · indexa solo lo que traduce (YALA-IOS-2)", .serialized)
@MainActor
struct DrainIndexesOnlyWhatItTranslatesTests {

    // MARK: - Infra (molde de `CloudSyncEngineTests`: 3 stores on-disk, el History es por-container)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DrainIndexes-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "DIW-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "DIW-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "DIW-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func personalRows(_ context: ModelContext, entity: String) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.entityType == entity }
    }

    /// `Account`: la entidad sin escrituras laterales (insertar una TX dispara el backfill asíncrono del CSV mirror,
    /// que guarda por su cuenta y mete una transacción más en la ventana). Ver `PersonalDrainHistoryStoreAnchorTests`.
    private func addAccount(_ context: ModelContext, name: String) throws {
        context.insert(Account(name: name, currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "checking"))
        try context.save()
    }

    /// Drena hasta que una vuelta no indexa nada (o 4 vueltas): el arranque crea el cursor y barre todo, y la vuelta
    /// siguiente puede ver el eco de la anterior.
    private func settle(_ engine: CloudSyncEngine, _ context: ModelContext) {
        for _ in 0..<4 {
            engine.drainOnce(context: context)
            if engine.lastDrainIndexedEntities == [] { return }
        }
    }

    // MARK: - Canal personal

    /// El arranque (sin token) lee el History entero e indexa solo lo que aparece en él; la fila sale igual.
    @Test func personal_bootstrap_indexesWhatTheWholeHistoryTouches() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try addAccount(context, name: "Caja")

        let engine = CloudSyncEngine()
        #expect(engine.drainOnce(context: context))
        #expect(engine.lastDrainIndexedEntities.contains(SyncEntityType.account))
        #expect(!engine.lastDrainIndexedEntities.contains(SyncEntityType.transactionItem))
        #expect(try personalRows(context, entity: SyncEntityType.account).count == 1)
    }

    /// El caso de Sentry: una vuelta sin nada nuevo no carga ningún modelo y no produce filas.
    @Test func personal_idleDrain_indexesNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try addAccount(context, name: "Caja")
        let engine = CloudSyncEngine()
        settle(engine, context)
        let before = try context.fetchCount(FetchDescriptor<SyncOutbox>())

        #expect(engine.drainOnce(context: context))
        #expect(engine.lastDrainIndexedEntities == [])
        #expect(!engine.lastDrainReadOutboxKeys, "sin nada que traducir no se lee la cola entera para deduplicar")
        #expect(try context.fetchCount(FetchDescriptor<SyncOutbox>()) == before)
    }

    /// Un cambio nuevo indexa solo su entidad y SALE: el índice que falta no se come la fila.
    @Test func personal_newRow_indexesOnlyItsEntity_andIsEmitted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try addAccount(context, name: "Caja")
        let engine = CloudSyncEngine()
        settle(engine, context)

        try addAccount(context, name: "Banco")
        #expect(engine.drainOnce(context: context))
        #expect(engine.lastDrainIndexedEntities == [SyncEntityType.account])
        #expect(engine.lastDrainReadOutboxKeys, "con algo que traducir, el dedup lee la cola como siempre")
        #expect(try personalRows(context, entity: SyncEntityType.account).count == 2)
    }

    /// Una fila de los tipos de `syncID` acuñado que nace SIN él (el hub de creación no lo acuña en producción): el
    /// barrido se lo pone en la MISMA vuelta y la fila sale con él. Es lo que el barrido hacía antes del fetch.
    @Test func personal_rowBornWithoutSyncID_getsItAndIsEmittedInTheSameDrain() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try addAccount(context, name: "Caja")
        let engine = CloudSyncEngine()
        settle(engine, context)

        let category = Category(name: "Gym", colorHex: "#6366F1", isIncome: false, isDefaultSeed: false)
        category.syncID = nil
        context.insert(category)
        try context.save()

        #expect(engine.drainOnce(context: context))
        #expect(engine.lastDrainIndexedEntities.contains(SyncEntityType.category))
        let syncID = try #require(category.syncID)
        let rows = try personalRows(context, entity: SyncEntityType.category)
        #expect(rows.contains { $0.syncID == syncID })
        // Y el cambio de syncID se consumió en ESTA vuelta: la sonda del cierre de sesión no lo ve como pendiente, y la
        // vuelta siguiente no tiene nada que indexar (la review de YALA-IOS-2 cazó que, guardado tras leer el History,
        // quedaba detrás del token y bloqueaba el cierre con el motor parado).
        #expect(engine.hasUncapturedPersonalChanges(context: context) == false)
        #expect(engine.drainOnce(context: context))
        #expect(engine.lastDrainIndexedEntities == [])
    }

    /// Una fila sin syncID que el History NO trae en la ventana (nació antes del ancla: el caso del snapshot de la
    /// migración tras su `fastForwardHistoryBaseline`) también sale del drain con syncID: el snapshot y el Merkle lo dan
    /// por hecho. Sin indexar su tabla.
    @Test func personal_rowWithoutSyncIDOutsideTheWindow_stillGetsOne() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try addAccount(context, name: "Caja")
        let engine = CloudSyncEngine()
        settle(engine, context)

        let category = Category(name: "Gym", colorHex: "#6366F1", isIncome: false, isDefaultSeed: false)
        category.syncID = nil
        context.insert(category)
        try context.save()
        // El cursor salta por encima de su insert (lo que hace el baseline de la migración), y el ancla por timestamp
        // también, para que ni el token ni el guard 3-bis la devuelvan en la ventana.
        let last = try #require(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).last {
            $0.changes.contains { $0.changedPersistentIdentifier.entityName == SyncEntityType.category }
        })
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        cursor.historyTokenData = try JSONEncoder().encode(last.token)
        cursor.lastDrainedTxAt = last.timestamp.addingTimeInterval(3600)
        try context.save()

        #expect(engine.drainOnce(context: context))
        #expect(category.syncID != nil)
    }

    /// Lo que el contexto tiene SIN guardar al empezar la vuelta se guarda antes de leer el History y sale en esa
    /// misma vuelta (lo hacía el barrido, que antes iba delante del fetch).
    @Test func personal_unsavedEditAtDrainTime_isCapturedInTheSameDrain() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try addAccount(context, name: "Caja")
        let engine = CloudSyncEngine()
        settle(engine, context)

        context.insert(Account(name: "Sin guardar", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "checking"))
        #expect(context.hasChanges)

        #expect(engine.drainOnce(context: context))
        #expect(!context.hasChanges)
        #expect(try personalRows(context, entity: SyncEntityType.account).count == 2)
    }

    /// El filtro es el del bucle de traducción: fuera el eco del motor y fuera lo que no es del store personal.
    @Test func personal_entitiesToTranslate_matchesTheTranslationFilter() {
        let names = CloudSyncEngine.entitiesToTranslate(authorsAndEntities: [
            (author: CloudSyncEngine.outboxSaveAuthor, entities: ["Category"]),
            (author: nil, entities: ["TransactionItem", "SplitExpense", "SyncCursor"]),
            (author: "NSCloudKitMirroringDelegate.import", entities: ["Budget"]),
        ])
        #expect(names == ["TransactionItem", "Budget"])
    }

    // MARK: - Canal de Grupos

    private func groupRows(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>()).filter { $0.entityType == GroupSyncEntityType.splitExpense }
    }

    private func makeBackendGroup(_ context: ModelContext) throws -> SplitGroup {
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        context.insert(group)
        try context.save()
        return group
    }

    @Test func groups_idleDrain_indexesNothing_andANewExpenseIndexesOnlyItsEntity() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()
        let group = try makeBackendGroup(context)
        for _ in 0..<3 { client.drainOnce(context: context) }

        #expect(client.drainOnce(context: context))
        #expect(client.lastDrainIndexedEntities == [])
        #expect(!client.lastDrainReadOutboxKeys)

        context.insert(SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 20, currencyCode: "USD",
                                    expenseDescription: "Cena", paidByMemberID: "m1"))
        try context.save()
        #expect(client.drainOnce(context: context))
        #expect(client.lastDrainIndexedEntities == [GroupSyncEntityType.splitExpense])
        #expect(client.lastDrainReadOutboxKeys)
        #expect(try groupRows(context).count == 1)
    }

    @Test func groups_entitiesToTranslate_matchesTheTranslationFilter() {
        let names = GroupsSyncClient.entitiesToTranslate(authorsAndEntities: [
            (author: GroupsSyncClient.outboxSaveAuthor, entities: ["SplitGroup"]),
            (author: nil, entities: ["SplitShare", "TransactionItem"]),
        ])
        #expect(names == ["SplitShare"])
    }

    // MARK: - Medida (no asierta tiempos: imprime el coste de una vuelta sin cambios con muchas filas)

    @Test func personal_idleDrainCost_withThousandsOfRows() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        for batch in 0..<10 {
            for i in 0..<400 {
                context.insert(TransactionItem(
                    date: Date(timeIntervalSince1970: 1_700_000_000 + Double(batch * 400 + i)),
                    amount: Double(i), currencyCode: "USD"))
            }
            try context.save()
        }
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        try await Task.sleep(for: .milliseconds(300))
        engine.drainOnce(context: context)
        let clock = ContinuousClock()
        var samples: [Duration] = []
        for _ in 0..<3 { samples.append(clock.measure { engine.drainOnce(context: context) }) }
        print("DRAIN-IDLE-MEDIDA: \(samples) indexed=\(engine.lastDrainIndexedEntities)")
        #expect(engine.lastDrainIndexedEntities == [])

        // Una vuelta con UNA edición de una cuenta: indexa solo `Account`, no los 4 000 movimientos.
        context.insert(Account(name: "Nueva", currencyCode: "USD", colorHex: "#6366F1", iconName: "creditcard", type: "checking"))
        try context.save()
        let oneEdit = clock.measure { engine.drainOnce(context: context) }
        print("DRAIN-UNA-EDICION-MEDIDA: \(oneEdit) indexed=\(engine.lastDrainIndexedEntities)")
        #expect(engine.lastDrainIndexedEntities == [SyncEntityType.account])

        // Y una con un movimiento nuevo: indexa `TransactionItem` (la tabla grande). Es el coste que queda por edición.
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_800_000_000), amount: 1, currencyCode: "USD"))
        try context.save()
        let oneTx = clock.measure { engine.drainOnce(context: context) }
        print("DRAIN-UN-MOVIMIENTO-MEDIDA: \(oneTx) indexed=\(engine.lastDrainIndexedEntities)")
    }
}
