//
//  PersonalClockRollbackDrainTests.swift
//  YalaTests / CloudSync
//
//  Ticket `personal-clock-rollback-wedges-the-drain-forever`, gemelo personal de
//  `groups-clock-rollback-wedges-the-drain-forever`. La hora del iPhone estuvo adelantada, se apuntó algo y la hora
//  volvió: el reloj lógico persistido (`SyncCursor.clockLatestHLC`) queda por delante de todo lo que se apunte después.
//  El drain personal estampaba con `clock.send(now: tx.timestamp)`, cuya guarda de deriva lanzaba con más de 5 min de
//  adelanto; la fecha de la transacción no cambia y el reloj lógico no baja, así que la traducción se cortaba en la misma
//  transacción en cada vuelta, para siempre. La vuelta devolvía `true` y nada se bloqueaba: los cambios simplemente no
//  salían del teléfono.
//
//  Aquí se siembra ese reloj adelantado (un día) SIN volver a tocarlo, con stores en disco y el motor real:
//   - el drain captura el cambio y avanza el cursor, y lo de después también, ordenado DESPUÉS;
//   - un re-drain del mismo History desde el mismo reloj no duplica (el estampado sigue siendo determinista).
//
//  Por qué el oráculo son las filas y el cursor, no el `Bool`: el drain personal devuelve `true` también con la
//  traducción cortada (`drainOnce`), así que ese valor no distingue el bug del arreglo.
//
//  Control: `send` —lo que el drain usaba— sigue lanzando con ese reloj (`HLCTests.sendLocal_eventFarBehind_…`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Canal personal · un reloj que retrocede no encalla el drain", .serialized)
@MainActor
struct PersonalClockRollbackDrainTests {

    private static let oneDay: TimeInterval = 86_400

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCClockRollback-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "PCR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "PCR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "PCR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    @discardableResult
    private func addTransaction(_ context: ModelContext, amount: Double) throws -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: "USD")
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(tx)
        try context.save()
        return tx
    }

    private func transactionRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.entityType == SyncEntityType.transactionItem }
    }

    private func cursor(_ context: ModelContext) throws -> SyncCursor {
        try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
    }

    /// El reloj lógico persistido un día por delante: lo que deja un cambio apuntado con la hora adelantada. Se guarda con
    /// el autor del motor, como el cursor de producción, y ningún test lo vuelve a tocar.
    @discardableResult
    private func seedClockAheadByOneDay(_ engine: CloudSyncEngine, _ context: ModelContext) throws -> HLC {
        let cursor = try engine.loadOrCreateCursor(context)
        let ahead = try HLC(physicalMs: Int64((Date().timeIntervalSince1970 + Self.oneDay) * 1000),
                            counter: 0, nodeID: NodeID.generate())
        let previousAuthor = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        cursor.clockLatestHLC = ahead.description
        try context.save()
        context.author = previousAuthor
        return ahead
    }

    // MARK: - El drain

    /// **Criterio 1 del ticket.** Con el reloj lógico un día por delante, un cambio personal nuevo llega al outbox y el
    /// drain no corta: el cursor avanza hasta esa transacción. Su HLC queda por encima del reloj adelantado.
    @Test func drain_withTheClockAheadByADay_capturesTheChange_andAdvancesTheCursor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let ahead = try seedClockAheadByOneDay(engine, context)
        try addTransaction(context, amount: 30)

        #expect(engine.drainOnce(context: context))
        let rows = try transactionRows(context)
        #expect(rows.count == 1, "el reloj adelantado ya no corta la traducción")
        #expect(try HLC.parse(try #require(rows.first).hlc) > ahead)

        let personalTx = try #require(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).last { tx in
            tx.changes.contains { $0.changedPersistentIdentifier.entityName == "TransactionItem" }
        })
        #expect(try cursor(context).lastDrainedTxAt == personalTx.timestamp, "el cursor pasó la transacción: no se re-corta")
    }

    /// **Criterio 2 del ticket.** Vuelta tras vuelta con el mismo `SyncCursor` y sin tocar `clockLatestHLC`: cada cambio
    /// nuevo sale, y una edición de después gana a la de antes (HLC mayor), aunque todo se apuntara por detrás del reloj
    /// lógico. El reloj persistido sigue al último estampado.
    @Test func drain_keepsCapturing_turnAfterTurn_withoutTouchingTheClock() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let ahead = try seedClockAheadByOneDay(engine, context)

        let tx = try addTransaction(context, amount: 30)
        #expect(engine.drainOnce(context: context))
        let first = try HLC.parse(try #require(try transactionRows(context).first).hlc)

        tx.amount = 40
        try context.save()
        #expect(engine.drainOnce(context: context))
        try addTransaction(context, amount: 12)
        #expect(engine.drainOnce(context: context))

        let hlcs = try transactionRows(context).map { try HLC.parse($0.hlc) }.sorted()
        #expect(hlcs.count == 3, "el alta, la edición y la segunda transacción")
        #expect(hlcs.first == first)
        #expect(zip(hlcs, hlcs.dropFirst()).allSatisfy { $0 < $1 })
        #expect(first > ahead)

        let persisted = try HLC.parse(try #require(try cursor(context).clockLatestHLC))
        #expect(persisted == hlcs.last, "el reloj persistido sigue al último estampado")
    }

    /// **El HLC sale de la fecha de la TRANSACCIÓN**, con el reloj en régimen normal (sin adelantar). Con el reloj
    /// adelantado `max(l, pt)` da `l` sea cual sea `pt`, así que ese régimen no distingue qué fecha se usa; este sí. Sin
    /// él, un estampado con otra fecha fija (determinista, así que el dedup del re-drain no lo caza) perdería por LWW
    /// frente a escrituras de otros dispositivos. Molde: `GroupsClockRollbackDrainTests.drain_stampsWithTheTransactionTime_notWithNow`.
    @Test func drain_stampsWithTheTransactionTime() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try addTransaction(context, amount: 30)

        #expect(engine.drainOnce(context: context))
        let row = try #require(try transactionRows(context).first)
        // La transacción del ALTA, no la última que toque el movimiento: el barrido del drain le asigna el `syncID` en
        // otra transacción posterior, que no se emite.
        let insertTx = try #require(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).first { tx in
            tx.changes.contains { change in
                guard case .insert(let insert) = change else { return false }
                return insert.changedPersistentIdentifier.entityName == "TransactionItem"
            }
        })
        let stamped = try HLC.parse(row.hlc).physicalMs
        #expect(stamped == CanonicalTime.physicalMillis(from: insertTx.timestamp),
                "estampado \(stamped), alta \(CanonicalTime.physicalMillis(from: insertTx.timestamp))")
    }

    /// **Con el reloj adelantado, un re-drain tampoco duplica.** Una vuelta que no avanza el cursor (un kill entre el save
    /// del outbox y el del token) y otra instancia del mismo nodo que vuelve a leer el mismo History desde el mismo reloj
    /// adelantado estampan los mismos HLC y el dedup `(syncID, hlc, op)` los reconoce. Ojo con lo que NO mide: en este
    /// régimen cualquier fecha por detrás del reloj da el mismo HLC, así que la fecha que se usa la fija
    /// `drain_stampsWithTheTransactionTime` y el determinismo del régimen normal,
    /// `CloudSyncEngineTests.drain_killBetweenOutboxAndToken_replayHasNoDuplicates`.
    @Test func reDrain_fromTheSameClockAhead_doesNotDuplicate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let node = NodeID.generate()
        let first = CloudSyncEngine(nodeID: node)
        try seedClockAheadByOneDay(first, context)
        try addTransaction(context, amount: 30)

        first._testSuppressTokenAdvance = true
        #expect(first.drainOnce(context: context))
        #expect(try transactionRows(context).count == 1, "control: la primera vuelta capturó")

        let second = CloudSyncEngine(nodeID: node)
        #expect(second.drainOnce(context: context))
        #expect(try transactionRows(context).count == 1, "la segunda vuelta repite el mismo HLC y el dedup la para")
    }

    /// **El corte que queda sigue sin consumir la transacción.** Con el estampado lanzando (un año fuera de 0001–9999, lo
    /// único que aún corta), el cambio no sale ni el cursor lo pasa; la vuelta siguiente, sin el seam, lo recupera.
    @Test func clockStampThatThrows_leavesTheTransactionForTheNextTurn() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try addTransaction(context, amount: 30)

        engine._testThrowOnClockStamp = true
        engine.drainOnce(context: context)
        #expect(try transactionRows(context).isEmpty)
        #expect(try cursor(context).lastDrainedTxAt == nil, "el cursor no pasó la transacción cortada")

        engine._testThrowOnClockStamp = false
        #expect(engine.drainOnce(context: context))
        #expect(try transactionRows(context).count == 1)
    }
}
