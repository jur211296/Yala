//
//  OpeningBalanceRejectionSettleTests.swift
//  YalaTests / CloudSync
//
//  Card e6fd (2026-11-01) · cuando el servidor rechaza para siempre un saldo inicial (g27_01), el teléfono lo descarta:
//   (1) qué dead-letters se descartan (los tres códigos, solo de la sesión) y cuáles no;
//   (2) el descarte borra la fila del outbox, la copia local y su puente, pone a 0 el cursor de ESE grupo para volver a
//       bajarlo y deja el aviso; un grupo con cambios por subir (o recién editados en el History) espera al ciclo siguiente;
//   (3) sin la dead-letter, el Merkle del grupo deja de saltarse;
//   (4) el descarte no vuelve a subir nada (el drain no lo captura), con su control: el mismo borrado sin el autor del
//       canal SÍ sube un tombstone;
//   (5) un save fallido no deja el borrado sucio en el contexto;
//   (6) el ciclo lo hace entre el push y el pull, y el pull vuelve a bajar el grupo; un error de red no descarta nada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldos iniciales · descartar el rechazo del servidor (card e6fd)", .serialized)
@MainActor
struct OpeningBalanceRejectionSettleTests {

    private static let notAdmin = "upstream_400:yala_opening_balance_not_admin"
    private static let locked = "upstream_400:yala_opening_balance_locked"
    private static let closed = "upstream_400:yala_opening_balance_group_closed"

    // MARK: - (1) Lógica

    @Test func settlesDeadLetter_onlyTheThreeCodes_ofThisSession() {
        typealias L = OpeningBalanceServerRejectionLogic
        for reason in [Self.notAdmin, Self.locked, Self.closed] {
            #expect(L.settlesDeadLetter(rejectedReason: reason, rowOwner: "sub-a", sessionOwner: "sub-a"), "\(reason)")
            // Otra cuenta, sin dueño probado o sin sesión: no se toca.
            #expect(!L.settlesDeadLetter(rejectedReason: reason, rowOwner: "sub-b", sessionOwner: "sub-a"))
            #expect(!L.settlesDeadLetter(rejectedReason: reason, rowOwner: nil, sessionOwner: "sub-a"))
            #expect(!L.settlesDeadLetter(rejectedReason: reason, rowOwner: "sub-a", sessionOwner: nil))
            #expect(!L.settlesDeadLetter(rejectedReason: reason, rowOwner: "", sessionOwner: ""))
        }
        // El resto de rechazos sigue como estaba.
        for other in ["upstream_400:yala_not_authorized", "upstream_400:yala_bad_request", "upstream_400",
                      "malformed_delta", "yala_opening_balance_locked", "upstream_500:yala_opening_balance_locked"] {
            #expect(!L.settlesDeadLetter(rejectedReason: other, rowOwner: "sub-a", sessionOwner: "sub-a"), "\(other)")
        }
        #expect(!L.settlesDeadLetter(rejectedReason: nil, rowOwner: "sub-a", sessionOwner: "sub-a"))
    }

    // MARK: - (2) El descarte

    @Test func settle_dropsTheRowAndTheLocalCopy_andResetsOnlyThatGroup() throws {
        let notices = OpeningBalanceServerRejectionNotices.shared
        notices._testReset(); defer { notices._testReset() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fx = try seedScenario(context)
        try seedBridgedTx(context, expenseID: fx.expenseID)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))

        var settled = 0
        withBridge(context) { settled = client.settleRejectedOpeningBalances(context: context) }

        #expect(settled == 2)
        let fresh = try freshContext(dir)
        // La copia local del saldo y su reparto ya no están.
        #expect(try expenses(fresh, fx.expenseID).isEmpty)
        #expect(try shares(fresh, fx.shareID).isEmpty)
        // El gasto normal del mismo grupo no se toca.
        #expect(try expenses(fresh, fx.otherExpenseID).count == 1)
        // Del outbox solo salen las dos filas descartadas.
        let reasons = try fresh.fetch(FetchDescriptor<GroupSyncOutbox>()).map { $0.rejectedReason ?? "vivo" }.sorted()
        #expect(reasons == ["upstream_400:yala_not_authorized", Self.locked, "vivo"].sorted())
        // El grupo A vuelve a bajar entero; el B, no.
        let cursors = try cursorMap(fresh)
        #expect(cursors["SplitGroup-A"] == 0)
        #expect(cursors["SplitGroup-B"] == 7)
        // Ese re-pull no avisa de «gasto modificado».
        #expect(client.capabilityRepullZones == ["SplitGroup-A"])
        // El puente del saldo (su movimiento en la cuenta virtual) se va con él; el re-pull lo rehace si el saldo existe.
        #expect(try bridgedTxCount(fresh, expenseID: fx.expenseID) == 0)
        // Un aviso por grupo, con el motivo que más explica (not_admin gana a locked); nada para el grupo B.
        #expect(notices.peek(groupID: "SplitGroup-A") == .notAdmin)
        #expect(notices.peek(groupID: "SplitGroup-B") == nil)
    }

    /// Lo editado mientras el push volaba vive solo en el History: el descarte lo drena, ve el grupo con un cambio por subir
    /// y espera. Sin esa espera, el re-pull desde 0 pisaría la edición de «Cena» con la versión del servidor.
    @Test func settle_groupWithAnEditStillInHistory_waitsForTheNextCycle() throws {
        let notices = OpeningBalanceServerRejectionNotices.shared
        notices._testReset(); defer { notices._testReset() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fx = try seedScenario(context)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))
        client.drainOnce(context: context)
        let cena = try #require(try expenses(context, fx.otherExpenseID).first)
        cena.amount = 45          // la edición de la persona, con el autor por defecto: queda en el History
        try context.save()

        #expect(client.settleRejectedOpeningBalances(context: context) == 0)

        let fresh = try freshContext(dir)
        #expect(try expenses(fresh, fx.expenseID).count == 1)
        #expect(try expenses(fresh, fx.otherExpenseID).first?.amount == 45)
        #expect(try fresh.fetch(FetchDescriptor<GroupSyncOutbox>()).filter { $0.rejectedReason == Self.notAdmin }.count == 1)
        // El drain del descarte la capturó: sube en el push del ciclo siguiente.
        #expect(try fresh.fetch(FetchDescriptor<GroupSyncOutbox>())
            .contains { $0.syncID == fx.otherExpenseID && $0.rejectedReason == nil })
        #expect(try cursorMap(fresh)["SplitGroup-A"] == 42)
        #expect(client.capabilityRepullZones.isEmpty)
        #expect(notices.peek(groupID: "SplitGroup-A") == nil)
    }

    /// CONTROL del alcance: sin ninguna de esas dead-letters no hace nada (ni cursor, ni silencio de avisos).
    @Test func settle_withoutThoseDeadLetters_doesNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fx = try seedScenario(context, withRejections: false)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))

        #expect(client.settleRejectedOpeningBalances(context: context) == 0)

        let fresh = try freshContext(dir)
        #expect(try expenses(fresh, fx.expenseID).count == 1)
        #expect(try cursorMap(fresh)["SplitGroup-A"] == 42)
        #expect(client.capabilityRepullZones.isEmpty)
    }

    // MARK: - (3) El Merkle del grupo vuelve

    @Test func settle_letsTheGroupMerklePassTheDeadLetterGuard() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try seedScenario(context)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))

        // Antes: la dead-letter apaga la verificación del grupo.
        #expect(await client.verifyGroupIntegrity(groupID: "SplitGroup-A", context: context)
                == .skipped(reason: GroupMerkleSkipReason.deadLetters))

        client.settleRejectedOpeningBalances(context: context)

        // Después pasa el guard 2 y para en el siguiente (sin pull completado en este test): ya no es la dead-letter.
        #expect(await client.verifyGroupIntegrity(groupID: "SplitGroup-A", context: context)
                == .skipped(reason: GroupMerkleSkipReason.noCompletedPull))
    }

    // MARK: - (4) No vuelve a subir nada

    @Test func settle_isNotCapturedByTheDrain() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fx = try seedScenario(context)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))
        client.drainOnce(context: context)   // ancla el History con lo sembrado (bajo el autor del canal: nada que subir)
        let before = try context.fetch(FetchDescriptor<GroupSyncOutbox>()).count

        client.settleRejectedOpeningBalances(context: context)
        client.drainOnce(context: context)

        let rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(rows.count == before - 2)
        #expect(!rows.contains { $0.syncID == fx.expenseID || $0.syncID == fx.shareID })
    }

    /// CONTROL: el mismo borrado guardado con el autor por defecto sí lo captura el drain y sube un tombstone del saldo.
    /// Sin este caso, el de arriba podría salir verde con un drain que no capturara nada.
    @Test func control_theSameDeleteWithoutTheChannelAuthor_isCapturedAsATombstone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fx = try seedScenario(context)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))
        client.drainOnce(context: context)

        let id = fx.expenseID
        if let expense = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id })).first {
            context.delete(expense)
        }
        try context.save()
        client.drainOnce(context: context)

        let tombstones = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
            .filter { $0.syncID == id && $0.opRaw == SyncOutboxOp.tombstone.rawValue }
        #expect(tombstones.count == 1)
    }

    // MARK: - (5) Save fallido

    @Test func settle_failedSave_leavesNothingDirty() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let notices = OpeningBalanceServerRejectionNotices.shared
        notices._testReset(); defer { notices._testReset() }
        let fx = try seedScenario(context)
        try seedBridgedTx(context, expenseID: fx.expenseID)
        let client = makeClient(session: StubSession(pull: Self.emptyPull))
        client._testThrowOnSettleSave = true

        var settled = -1
        withBridge(context) { settled = client.settleRejectedOpeningBalances(context: context) }
        #expect(settled == 0)
        // Sin descarte no hay aviso: diría que el saldo volvió, y no volvió.
        #expect(notices.peek(groupID: "SplitGroup-A") == nil)
        #expect(try bridgedTxCount(context, expenseID: fx.expenseID) == 1)

        #expect(!context.hasChanges)
        // Re-fetch en el mismo contexto (lo que vería el save siguiente de otro) y en uno fresco (el disco).
        for ctx in [context, try freshContext(dir)] {
            #expect(try expenses(ctx, fx.expenseID).count == 1)
            #expect(try ctx.fetch(FetchDescriptor<GroupSyncOutbox>()).filter { $0.rejectedReason == Self.notAdmin }.count == 1)
        }
        #expect(client.capabilityRepullZones.isEmpty)
    }

    // MARK: - (6) El ciclo

    /// El push rechaza el saldo (dead-letter + aviso), el descarte lo quita del teléfono y el pull vuelve a bajar el grupo
    /// desde 0 con la versión del servidor: el saldo vuelve con su importe de antes.
    @Test func cycle_rejectedEdit_endsWithTheServerVersionOnThePhone() async throws {
        let notices = OpeningBalanceServerRejectionNotices.shared
        notices._testReset(); defer { notices._testReset() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let groupID = "SplitGroup-A"
        let expenseID = UUID()
        try seedCursor(context, ["SplitGroup-A": 42])
        try asChannel(context) {
            let g = SplitGroup(name: "Viaje"); g.cloudKitZoneID = groupID; g.isBackendGroup = true; context.insert(g)
            let e = SplitExpense(groupZoneID: groupID, amount: 100, currencyCode: "USD",
                                 expenseDescription: "Saldo inicial", paidByMemberID: "m-1")
            e.id = expenseID; e.isOpeningBalance = true; context.insert(e)
        }
        // La edición local (importe 250) espera en el outbox.
        let id = expenseID
        let local = try #require(try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id })).first)
        try asChannel(context) { local.amount = 250 }
        let mid = UUID()
        try insertOutbox(context, syncID: expenseID, group: groupID, entity: GroupSyncEntityType.splitExpense,
                         mid: mid, rejectedReason: nil, owner: "sub-a")

        let pushResponse = "{\"results\":[\(rejected(mid, "yala_opening_balance_locked"))]}"
        let pullPage = """
        {"deltas":[{"entity_type":"split_expenses","group_id":"\(groupID)","sync_id":"\(expenseID.uuidString.lowercased())",\
        "op":"upsert","server_seq":42,"hlc":"2026-10-30T00:00:00.000Z-0000-00000000000000bb","field_hlcs":{},\
        "schema_version":1,"fields":{"amount":"100.0000","is_opening_balance":true,"currency_code":"USD",\
        "expense_description":"Saldo inicial"}}],"cursors":{"\(groupID)":42},"memberships":["\(groupID)"]}
        """
        // El servidor no reenvía una fila que no cambió: el delta solo baja si el grupo se pide desde 0.
        let session = StubSession(push: pushResponse, pull: pullPage, thenPull: Self.emptyPull(cursor: 42, group: groupID),
                                  servePullOnlyFrom: "\"\(groupID)\":0")
        let client = makeClient(session: session)

        _ = await client.syncCycleOnce(context: context)

        // El pull pidió el grupo desde 0.
        #expect(session.pullCursors.first?.contains("\"\(groupID)\":0") == true)
        // El teléfono enseña la versión del servidor, sin la fila en el outbox.
        let fresh = try freshContext(dir)
        let after = try fresh.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }))
        #expect(after.count == 1)
        #expect(after.first?.amount == 100)
        #expect(try fresh.fetch(FetchDescriptor<GroupSyncOutbox>()).isEmpty)
        // El aviso sigue saliendo con su motivo.
        #expect(notices.peek(groupID: groupID) == .locked)
    }

    /// Guarda de la premisa, no del descarte: un rechazo 5xx es pasajero (`applyResults` no lo pasa a dead-letter), así que
    /// el descarte no lo ve. Si un día se pasara a dead-letter con un `upstream_400:yala_opening_balance_*`, esto lo diría.
    @Test func cycle_serverError_isRetried_notDiscarded() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fx = try seedScenario(context, withRejections: false)
        let mid = UUID()
        try insertOutbox(context, syncID: fx.expenseID, group: "SplitGroup-A", entity: GroupSyncEntityType.splitExpense,
                         mid: mid, rejectedReason: nil, owner: "sub-a")
        let pushResponse = """
        {"results":[{"sync_id":"s","client_mutation_id":"\(mid.uuidString.lowercased())","status":"rejected",\
        "reason":"upstream_503"}]}
        """
        let client = makeClient(session: StubSession(push: pushResponse, pull: Self.emptyPull))

        _ = await client.syncCycleOnce(context: context)

        let fresh = try freshContext(dir)
        let id = fx.expenseID
        #expect(try fresh.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id })).count == 1)
        #expect(try fresh.fetch(FetchDescriptor<GroupSyncOutbox>()).contains { $0.clientMutationID == mid && $0.rejectedReason == nil })
        #expect(try cursorMap(fresh)["SplitGroup-A"] == 42)
    }

    // MARK: - Infra

    private struct Fixture { let expenseID: UUID; let shareID: UUID; let otherExpenseID: UUID }

    /// Grupo A (cursor 42): un saldo inicial y su reparto rechazados (not_admin y locked, de la sesión) y un gasto normal.
    /// Grupo B (cursor 7): una dead-letter de otro código y un saldo rechazado de OTRA cuenta, que no se tocan.
    /// Más una fila viva. Todo lo local se guarda con el autor del canal, como si hubiera bajado del servidor.
    private func seedScenario(_ context: ModelContext, withRejections: Bool = true) throws -> Fixture {
        let expenseID = UUID(), shareID = UUID(), otherID = UUID()
        try seedCursor(context, ["SplitGroup-A": 42, "SplitGroup-B": 7])
        try asChannel(context) {
            for zone in ["SplitGroup-A", "SplitGroup-B"] {
                let g = SplitGroup(name: zone); g.cloudKitZoneID = zone; g.isBackendGroup = true; context.insert(g)
            }
            let e = SplitExpense(groupZoneID: "SplitGroup-A", amount: 100, currencyCode: "USD",
                                 expenseDescription: "Saldo inicial", paidByMemberID: "m-1")
            e.id = expenseID; e.isOpeningBalance = true; context.insert(e)
            let s = SplitShare(expenseID: expenseID, memberID: "m-2", amount: 100, groupZoneID: "SplitGroup-A")
            s.id = shareID; context.insert(s)
            let o = SplitExpense(groupZoneID: "SplitGroup-A", amount: 30, currencyCode: "USD",
                                 expenseDescription: "Cena", paidByMemberID: "m-1")
            o.id = otherID; context.insert(o)
        }
        if withRejections {
            try insertOutbox(context, syncID: expenseID, group: "SplitGroup-A", entity: GroupSyncEntityType.splitExpense,
                             mid: UUID(), rejectedReason: Self.notAdmin, owner: "sub-a")
            try insertOutbox(context, syncID: shareID, group: "SplitGroup-A", entity: GroupSyncEntityType.splitShare,
                             mid: UUID(), rejectedReason: Self.locked, owner: "sub-a")
            try insertOutbox(context, syncID: UUID(), group: "SplitGroup-B", entity: GroupSyncEntityType.splitExpense,
                             mid: UUID(), rejectedReason: "upstream_400:yala_not_authorized", owner: "sub-a")
            try insertOutbox(context, syncID: UUID(), group: "SplitGroup-B", entity: GroupSyncEntityType.splitExpense,
                             mid: UUID(), rejectedReason: Self.locked, owner: "sub-b")
            try insertOutbox(context, syncID: UUID(), group: "SplitGroup-B", entity: GroupSyncEntityType.splitExpense,
                             mid: UUID(), rejectedReason: nil, owner: "sub-a")
        }
        return Fixture(expenseID: expenseID, shareID: shareID, otherExpenseID: otherID)
    }

    private func expenses(_ context: ModelContext, _ id: UUID) throws -> [SplitExpense] {
        try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }))
    }
    private func shares(_ context: ModelContext, _ id: UUID) throws -> [SplitShare] {
        try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == id }))
    }

    private func asChannel(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }

    private func seedCursor(_ context: ModelContext, _ map: [String: Int]) throws {
        let json = String(data: try JSONSerialization.data(withJSONObject: map, options: [.sortedKeys]), encoding: .utf8) ?? "{}"
        try asChannel(context) {
            let cursor = GroupSyncCursor()
            cursor.groupCursorsJSON = json
            context.insert(cursor)
        }
    }

    private func cursorMap(_ context: ModelContext) throws -> [String: Int] {
        let cursor = try #require(try context.fetch(FetchDescriptor<GroupSyncCursor>()).first)
        let object = try JSONSerialization.jsonObject(with: Data(cursor.groupCursorsJSON.utf8))
        return (object as? [String: Int]) ?? [:]
    }

    private func insertOutbox(_ context: ModelContext, syncID: UUID, group: String, entity: String, mid: UUID,
                              rejectedReason: String?, owner: String) throws {
        try asChannel(context) {
            context.insert(GroupSyncOutbox(
                syncID: syncID, groupID: group, entityType: entity, op: .upsert,
                hlc: "2026-10-31T00:00:00.000Z-0001-00000000000000aa", clientMutationID: mid,
                fieldsJSON: "{\"is_opening_balance\":true}", author: "", createdAt: .now,
                rejectedReason: rejectedReason, ownerUserID: owner))
        }
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OBSettle-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        ModelContext(try makeContainer(dir))
    }
    /// Otro contenedor sobre los mismos ficheros: lee el disco, no la memoria del contexto del test.
    private func freshContext(_ dir: URL) throws -> ModelContext { try makeContext(dir) }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "OBS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "OBS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "OBS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    private static let emptyPull = emptyPull(cursor: nil, group: nil)
    private static func emptyPull(cursor: Int?, group: String?) -> String {
        let cursors = cursor.flatMap { c in group.map { "{\"\($0)\":\(c)}" } } ?? "{}"
        return "{\"deltas\":[],\"cursors\":\(cursors)}"
    }

    // Sin `memberships`: una lista vacía daría por perdidos los grupos del teléfono (`reconcileLostMemberships`).

    /// Stub por ruta: `/groups/push` devuelve `push`; `/groups/pull` devuelve `pull` la primera vez y `thenPull` después.
    /// Apunta los cursores con que se pidió cada pull.
    private final class StubSession: SyncHTTPSession, @unchecked Sendable {
        let push: Data
        let pull: Data
        let thenPull: Data
        let servePullOnlyFrom: String?
        var pullCount = 0
        var pullCursors: [String] = []
        init(push: String = "{\"results\":[]}", pull: String, thenPull: String? = nil, servePullOnlyFrom: String? = nil) {
            self.push = Data(push.utf8)
            self.pull = Data(pull.utf8)
            self.thenPull = Data((thenPull ?? OpeningBalanceRejectionSettleTests.emptyPull).utf8)
            self.servePullOnlyFrom = servePullOnlyFrom
        }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let path = request.url?.path ?? ""
            let body: Data
            if path.hasSuffix("/pull") {
                pullCount += 1
                let cursors = Self.cursorsOf(request)
                pullCursors.append(cursors)
                let served = pullCount == 1 && (servePullOnlyFrom.map { cursors.contains($0) } ?? true)
                body = served ? pull : thenPull
            } else {
                body = push
            }
            return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        private static func cursorsOf(_ request: URLRequest) -> String {
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let fromQuery = query.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
            let fromBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return fromQuery + fromBody
        }
    }

    private final class Counter: @unchecked Sendable { var count = 0 }

    private func makeClient(session: SyncHTTPSession) -> GroupsSyncClient {
        let checks = Counter()
        return GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: session,
            sessionCheck: { checks.count += 1; return checks.count <= 50 },
            currentUserIDProvider: { "sub-a" },
            signInLogProvider: { SessionSignInLog(entries: [.init(sub: "sub-a", at: .distantPast)]) },
            outboxMirror: nil,
            forceRefreshTokenProvider: { nil },
            canRenewSession: { false },
            onRemoteChangesApplied: {},
            onRemoteChanges: { _ in })
    }

    private func withBridge(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        defer { GroupTransactionBridge.shared._testClearContext() }
        try body()
    }

    /// El movimiento que el puente deja en la cuenta virtual «Grupos» por un saldo inicial (`bridgeOpeningBalance`).
    private func seedBridgedTx(_ context: ModelContext, expenseID: UUID) throws {
        let account = Account(name: "Grupos", currencyCode: "USD", colorHex: "#111111", iconName: "banknote",
                              type: "cash", isSystemAccount: true)
        context.insert(account)
        let tx = TransactionItem(date: .now, amount: 100, currencyCode: "USD", account: account)
        tx.splitExpenseID = expenseID.uuidString
        tx.splitGroupZoneID = "SplitGroup-A"
        context.insert(tx)
        try context.save()
    }

    private func bridgedTxCount(_ context: ModelContext, expenseID: UUID) throws -> Int {
        let key = expenseID.uuidString
        return try context.fetchCount(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == key }))
    }

    private func rejected(_ mid: UUID, _ code: String) -> String {
        "{\"sync_id\":\"s\",\"client_mutation_id\":\"\(mid.uuidString.lowercased())\",\"status\":\"rejected\","
            + "\"reason\":\"upstream_400\",\"outcome\":{\"code\":\"P0001\",\"message\":\"\(code)\"}}"
    }
}
