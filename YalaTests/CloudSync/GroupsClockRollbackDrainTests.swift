//
//  GroupsClockRollbackDrainTests.swift
//  YalaTests / CloudSync
//
//  Ticket `groups-clock-rollback-wedges-the-drain-forever`. La hora del iPhone estuvo adelantada, se apuntó un gasto de
//  grupo y la hora volvió: el reloj lógico persistido (`GroupSyncCursor.clockLatestHLC`) queda por delante de todo lo que
//  se apunte después. El drain estampaba con `clock.send(now: tx.timestamp)`, cuya guarda de deriva lanzaba con más de
//  5 min de adelanto; la fecha de la transacción no cambia y el reloj lógico no baja, así que cortaba en el mismo gasto
//  en cada vuelta, para siempre. Nada de lo apuntado después subía, y desde #257 cerrar sesión, desasociar y «Empezar de
//  cero» se paraban con un «inténtalo en un rato» que esperando no se cumplía.
//
//  Aquí se siembra ese reloj adelantado (un día) SIN volver a tocarlo, con stores en disco y el cliente real:
//   - el drain termina y el gasto llega al outbox, y lo de después también, ordenado DESPUÉS;
//   - un re-drain del mismo History no duplica (el estampado sigue siendo determinista);
//   - la captura previa a una salida termina, la subida vacía el outbox y la salida queda `.drained`.
//
//  Control: `send` —lo que el drain usaba— sigue lanzando con ese reloj (`HLCTests.sendLocal_eventFarBehind_…`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · un reloj que retrocede no encalla el drain", .serialized)
@MainActor
struct GroupsClockRollbackDrainTests {

    private static let oneDay: TimeInterval = 86_400

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSClockRollback-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GCR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GCR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GCR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Responde 200 a la subida con TODAS las filas del cuerpo aplicadas, y cuenta las peticiones.
    private final class ApplyAllSession: SyncHTTPSession, @unchecked Sendable {
        var pushes = 0
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            guard request.url?.path.hasSuffix("groups/push") == true else {
                return (Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[]}".utf8), response)
            }
            pushes += 1
            let body = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
            let deltas = body?["deltas"] as? [[String: Any]] ?? []
            let results = deltas.map { delta -> String in
                let mid = delta["client_mutation_id"] as? String ?? ""
                return "{\"sync_id\":\"s\",\"client_mutation_id\":\"\(mid)\",\"status\":\"applied\"}"
            }.joined(separator: ",")
            return (Data("{\"results\":[\(results)]}".utf8), response)
        }
    }

    private func makeClient(session: SyncHTTPSession = ApplyAllSession(),
                            nodeID: NodeID = NodeID.generate(),
                            now: @escaping () -> Date = { .now }) -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: session, sessionCheck: { true },
            currentUserIDProvider: { "sub-a" }, now: now, nodeID: nodeID, outboxMirror: nil,
            forceRefreshTokenProvider: { nil }, canRenewSession: { true })
    }

    /// El reloj lógico persistido un día por delante: lo que deja un gasto apuntado con la hora adelantada.
    @discardableResult
    private func seedClockAheadByOneDay(_ client: GroupsSyncClient, _ context: ModelContext) throws -> HLC {
        let cursor = try client.loadOrCreateCursor(context)
        let ahead = try HLC(physicalMs: Int64((Date().timeIntervalSince1970 + Self.oneDay) * 1000),
                            counter: 0, nodeID: NodeID.generate())
        cursor.clockLatestHLC = ahead.description
        try context.save()
        return ahead
    }

    private func makeBackendGroup(_ context: ModelContext, zone: String = "SplitGroup-A") throws {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
    }

    @discardableResult
    private func addExpense(_ context: ModelContext, amount: Double, zone: String = "SplitGroup-A") throws -> SplitExpense {
        let expense = SplitExpense(groupZoneID: zone, amount: amount, currencyCode: "PEN",
                                   expenseDescription: "Taxi", paidByMemberID: "m1")
        context.insert(expense)
        try context.save()
        return expense
    }

    private func liveRows(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>(predicate: #Predicate { $0.rejectedReason == nil }))
    }

    private func expenseRows(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        let type = GroupSyncEntityType.splitExpense
        return try liveRows(context).filter { $0.entityType == type }
    }

    // MARK: - El drain

    /// **Criterio 1 del ticket.** Con el reloj lógico un día por delante, el gasto de después llega al outbox y el drain
    /// dice que terminó. Su HLC queda por encima del reloj adelantado: ordenado después de lo apuntado con la hora puesta.
    @Test func drain_withTheClockAheadByADay_capturesTheExpense() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()
        let ahead = try seedClockAheadByOneDay(client, context)
        try makeBackendGroup(context)
        try addExpense(context, amount: 30)

        #expect(client.drainOnce(context: context), "el reloj adelantado ya no corta la traducción")
        let rows = try expenseRows(context)
        #expect(rows.count == 1)
        let hlc = try HLC.parse(try #require(rows.first).hlc)
        #expect(hlc > ahead)
    }

    /// **Criterio 2 del ticket.** Vuelta tras vuelta sin tocar `clockLatestHLC`: cada gasto nuevo sale, y una edición de
    /// después gana a la de antes (HLC mayor), aunque las dos se apuntaran por detrás del reloj lógico.
    @Test func drain_keepsCapturing_turnAfterTurn_withoutTouchingTheClock() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient()
        let ahead = try seedClockAheadByOneDay(client, context)
        try makeBackendGroup(context)

        let expense = try addExpense(context, amount: 30)
        #expect(client.drainOnce(context: context))
        let first = try HLC.parse(try #require(try expenseRows(context).first).hlc)

        expense.amount = 40
        try context.save()
        #expect(client.drainOnce(context: context))
        try addExpense(context, amount: 12)
        #expect(client.drainOnce(context: context))

        let hlcs = try expenseRows(context).map { try HLC.parse($0.hlc) }.sorted()
        #expect(hlcs.count == 3, "el alta, la edición y el segundo gasto")
        #expect(hlcs.first == first)
        #expect(zip(hlcs, hlcs.dropFirst()).allSatisfy { $0 < $1 })
        #expect(first > ahead)

        let cursor = try client.loadOrCreateCursor(context)
        let persisted = try HLC.parse(try #require(cursor.clockLatestHLC))
        #expect(persisted == hlcs.last, "el reloj persistido sigue al último estampado")
    }

    /// **El HLC sale de la fecha de la TRANSACCIÓN, no de la hora de ahora**, con el reloj en régimen normal (sin
    /// adelantar): es lo que hace determinista el re-drain. Con el reloj adelantado `max(l, pt)` da `l` sea cual sea `pt`,
    /// así que ese régimen no distingue las dos variantes; este sí. El `now` del cliente va tres días por delante para que
    /// estampar con él se note.
    @Test func drain_stampsWithTheTransactionTime_notWithNow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient(now: { Date().addingTimeInterval(3 * Self.oneDay) })
        try makeBackendGroup(context)
        try addExpense(context, amount: 30)

        #expect(client.drainOnce(context: context))
        let row = try #require(try expenseRows(context).first)
        let expenseTx = try #require(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).last { tx in
            tx.changes.contains { $0.changedPersistentIdentifier.entityName == "SplitExpense" }
        })
        #expect(try HLC.parse(row.hlc).physicalMs == CanonicalTime.physicalMillis(from: expenseTx.timestamp))
    }

    /// El dedup del re-drain en régimen normal: dos vueltas del mismo nodo desde el mismo reloj, con un `now` que avanza en
    /// cada lectura, dan los mismos HLC. Si el estampado leyera la hora de ahora, la segunda vuelta duplicaría la fila.
    @Test func reDrain_inTheNormalRegime_doesNotDuplicate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let node = NodeID.generate()
        var tick: TimeInterval = 0
        let advancing: () -> Date = { tick += 60; return Date().addingTimeInterval(tick) }
        let first = makeClient(nodeID: node, now: advancing)
        try makeBackendGroup(context)
        try addExpense(context, amount: 30)

        first._testSuppressTokenAdvance = true
        #expect(first.drainOnce(context: context))
        #expect(try expenseRows(context).count == 1, "control: la primera vuelta capturó")

        let second = makeClient(nodeID: node, now: advancing)
        #expect(second.drainOnce(context: context))
        #expect(try expenseRows(context).count == 1)
    }

    /// **El determinismo que el dedup necesita, con el reloj adelantado.** Un drain que no avanza el cursor (un `save` del cursor que falla tras el
    /// del outbox) y otra vuelta del mismo nodo que vuelve a leer el mismo History desde el mismo reloj adelantado estampan
    /// los mismos HLC: el dedup `(syncID, hlc, op)` los reconoce y no hay fila duplicada (el régimen normal lo cubre el caso
    /// de arriba). Mismo `nodeID` a propósito: el HLC lo lleva dentro, y el de producción se genera por proceso, así que el
    /// dedup de un re-drain solo existe dentro de un proceso (tras un kill el backend funde las copias por LWW).
    @Test func reDrain_fromTheSameClock_doesNotDuplicate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let node = NodeID.generate()
        let first = makeClient(nodeID: node)
        try seedClockAheadByOneDay(first, context)
        try makeBackendGroup(context)
        try addExpense(context, amount: 30)

        first._testSuppressTokenAdvance = true
        #expect(first.drainOnce(context: context))
        #expect(try expenseRows(context).count == 1, "control: la primera vuelta capturó")

        let second = makeClient(nodeID: node)
        #expect(second.drainOnce(context: context))
        #expect(try expenseRows(context).count == 1, "la segunda vuelta repite el mismo HLC y el dedup la para")
    }

    // MARK: - La subida y las salidas

    /// **El gasto sube y la salida ya no se bloquea por el reloj.** La captura previa a una salida termina con el gasto en
    /// el outbox (antes: `false` y bloqueo con `.uploadRetryLater`), la subida lo vacía y la re-captura da `.drained`, que
    /// es lo que deja seguir al cierre, al desasociar y a «Empezar de cero».
    @Test func exitCapture_withTheClockAhead_uploads_andSettlesDrained() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = ApplyAllSession()
        let client = makeClient(session: session)
        try seedClockAheadByOneDay(client, context)
        try makeBackendGroup(context)
        try addExpense(context, amount: 30)

        let captured = client.captureLocalWritesForExit(context: context)
        #expect(captured)
        let live = try liveRows(context).count
        #expect(live >= 1, "el gasto llegó al outbox: la salida lo sube en vez de bloquear")

        let outcome = await client.pushPending(context: context)
        guard case .completed(let results) = outcome else {
            Issue.record("la subida tenía que completar: \(outcome)")
            return
        }
        #expect(results.count == live)
        #expect(session.pushes >= 1)
        #expect(try liveRows(context).isEmpty, "todo lo capturado se subió")

        let recaptured = client.captureLocalWritesForExit(context: context)
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: recaptured, livePendingCount: try liveRows(context).count,
            unrehydratedMirrorCount: 0) == .drained)
    }
}
