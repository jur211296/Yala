//
//  OpeningBalanceOrphanSharesTests.swift
//  YalaTests / CloudSync
//
//  Card m76a (2026-11-02) · los repartos de un saldo inicial NUEVO que el servidor rechazó no se quedan vivos ni en el
//  servidor ni en el teléfono. El servidor rechaza el gasto y aplica sus repartos (medido en staging,
//  `qa/cloud/g29_01-staging-probe.sh` caso 6); tras descartar el saldo (card e6fd) y terminar el re-pull, la app los
//  borra y sube su tombstone (casos 7 y 8: el servidor lo acepta, y no deja borrar el reparto de un saldo que sí existe).
//
//  Lo que se fija:
//   (1) el descarte apunta el gasto en el libro;
//   (2) tras el pull, si el gasto NO volvió, sus repartos se borran y el drain los sube como tombstones;
//   (3) CONTROL: si volvió (era una edición rechazada), sus repartos son los del servidor y no se tocan;
//   (4) con el grupo cerrado se borran solo aquí: ningún tombstone pasaría la RLS;
//   (5) lo apuntado por otra cuenta se queda;
//   (6) el ciclo lo hace tras un pull COMPLETO, no antes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldos iniciales · los repartos de un saldo rechazado no quedan huérfanos (m76a)", .serialized)
@MainActor
struct OpeningBalanceOrphanSharesTests {

    nonisolated private static let notAdmin = "upstream_400:yala_opening_balance_not_admin"
    nonisolated private static let closed = "upstream_400:yala_opening_balance_group_closed"
    private let zone = "SplitGroup-A"

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OBOrphan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        discardTestStoreDirectory(dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "OBO-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "OBO-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "OBO-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let context = ModelContext(try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta))
        context.autosaveEnabled = false
        return context
    }

    private func withIsolatedLedger(_ body: () throws -> Void) throws {
        let previous = GroupsRejectedOpeningBalanceLedger.defaults
        GroupsRejectedOpeningBalanceLedger.defaults = try #require(testDefaults(suiteName: "test.obo.\(UUID().uuidString)"))
        defer { GroupsRejectedOpeningBalanceLedger.defaults = previous }
        try body()
    }

    private func asChannel(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }

    private func makeClient(owner: String = "sub-a") -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: NoNetwork(),
            currentUserIDProvider: { owner },
            signInLogProvider: { SessionSignInLog(entries: [.init(sub: owner, at: .distantPast)]) },
            outboxMirror: nil, forceRefreshTokenProvider: { nil }, canRenewSession: { false },
            onRemoteChangesApplied: {}, onRemoteChanges: { _ in })
    }

    private final class NoNetwork: SyncHTTPSession, @unchecked Sendable {
        func data(for request: URLRequest) async throws -> (Data, URLResponse) { throw URLError(.notConnectedToInternet) }
    }

    private struct Fixture {
        let expenseID: UUID
        let shareID: UUID
    }

    /// Un grupo del backend con un saldo inicial NUEVO de esta sesión: el gasto en dead-letter (el servidor lo rechazó) y
    /// su reparto ya aplicado (sin fila en el outbox), como lo deja el push real.
    private func seed(_ context: ModelContext, reason: String = Self.notAdmin, owner: String = "sub-a") throws -> Fixture {
        let expenseID = UUID(), shareID = UUID()
        try asChannel(context) {
            let g = SplitGroup(name: "Viaje"); g.cloudKitZoneID = zone; g.isBackendGroup = true; context.insert(g)
            let e = SplitExpense(groupZoneID: zone, amount: 100, currencyCode: "USD",
                                 expenseDescription: "Saldo inicial", paidByMemberID: "m-1")
            e.id = expenseID; e.isOpeningBalance = true; context.insert(e)
            let s = SplitShare(expenseID: expenseID, memberID: "m-2", amount: 100, groupZoneID: zone)
            s.id = shareID; context.insert(s)
            let cursor = GroupSyncCursor(); cursor.groupCursorsJSON = "{\"\(zone)\":42}"; context.insert(cursor)
            context.insert(GroupSyncOutbox(
                syncID: expenseID, groupID: zone, entityType: GroupSyncEntityType.splitExpense, op: .upsert,
                hlc: "2026-11-02T00:00:00.000Z-0001-00000000000000aa", clientMutationID: UUID(),
                fieldsJSON: "{\"is_opening_balance\":true}", author: "", createdAt: .now,
                rejectedReason: reason, ownerUserID: owner))
        }
        return Fixture(expenseID: expenseID, shareID: shareID)
    }

    private func shares(_ context: ModelContext, _ id: UUID) throws -> [SplitShare] {
        try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == id }))
    }

    private func outboxTombstones(_ context: ModelContext, _ id: UUID) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>(predicate: #Predicate { $0.syncID == id }))
            .filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
    }

    // MARK: - (1)(2) El saldo nuevo: sus repartos se retiran y suben borrados

    @Test("(1)(2) saldo nuevo rechazado: tras el re-pull, su reparto se borra y sube como tombstone")
    func newOpeningBalance_orphanShareIsRemovedAndUploaded() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedLedger {
            let fx = try seed(context)
            let client = makeClient()
            GroupTransactionBridge.shared.setContext(context)
            defer { GroupTransactionBridge.shared._testClearContext() }

            #expect(client.settleRejectedOpeningBalances(context: context) == 1)
            #expect(GroupsRejectedOpeningBalanceLedger.entries.map(\.expenseID) == [fx.expenseID])
            #expect(try shares(context, fx.shareID).count == 1, "el descarte solo quita lo rechazado: el reparto sigue")

            // El re-pull terminó y el gasto no volvió.
            #expect(client.sweepRejectedOpeningBalanceShares(context: context) == 1)
            #expect(try shares(context, fx.shareID).isEmpty)
            #expect(GroupsRejectedOpeningBalanceLedger.entries.isEmpty)
            client.drainOnce(context: context)
            #expect(try outboxTombstones(context, fx.shareID).count == 1, "el servidor tiene que recibir el borrado")
        }
    }

    // MARK: - (3) CONTROL: una edición rechazada

    @Test("(3) control: si el gasto volvió con el re-pull, sus repartos son los del servidor y no se tocan")
    func editedOpeningBalance_comesBack_sharesStay() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedLedger {
            let fx = try seed(context)
            GroupsRejectedOpeningBalanceLedger.add([.init(groupID: zone, expenseID: fx.expenseID, ownerUserID: "sub-a",
                                                           localOnly: false)])
            let client = makeClient()
            // El gasto sigue (el re-pull lo devolvió): no se descarta nada.
            #expect(client.sweepRejectedOpeningBalanceShares(context: context) == 0)
            #expect(try shares(context, fx.shareID).count == 1)
            #expect(GroupsRejectedOpeningBalanceLedger.entries.isEmpty, "atendido: no se vuelve a mirar")
            client.drainOnce(context: context)
            #expect(try outboxTombstones(context, fx.shareID).isEmpty)
        }
    }

    // MARK: - (4) Grupo cerrado

    @Test("(4) con el grupo cerrado el reparto se borra solo en el teléfono: no sube nada")
    func closedGroup_removesLocallyOnly() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedLedger {
            let fx = try seed(context, reason: Self.closed)
            let client = makeClient()
            GroupTransactionBridge.shared.setContext(context)
            defer { GroupTransactionBridge.shared._testClearContext() }
            #expect(client.settleRejectedOpeningBalances(context: context) == 1)
            #expect(GroupsRejectedOpeningBalanceLedger.entries.first?.localOnly == true)
            #expect(client.sweepRejectedOpeningBalanceShares(context: context) == 1)
            #expect(try shares(context, fx.shareID).isEmpty)
            client.drainOnce(context: context)
            #expect(try outboxTombstones(context, fx.shareID).isEmpty)
        }
    }

    // MARK: - (5) Otra cuenta

    @Test("(5) lo que apuntó otra cuenta se queda apuntado y no se toca")
    func anotherAccountsEntry_isLeftAlone() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedLedger {
            let fx = try seed(context)
            try asChannel(context) {
                for e in try context.fetch(FetchDescriptor<SplitExpense>()) { context.delete(e) }
            }
            GroupsRejectedOpeningBalanceLedger.add([.init(groupID: zone, expenseID: fx.expenseID, ownerUserID: "sub-b",
                                                           localOnly: false)])
            #expect(makeClient(owner: "sub-a").sweepRejectedOpeningBalanceShares(context: context) == 0)
            #expect(try shares(context, fx.shareID).count == 1)
            #expect(GroupsRejectedOpeningBalanceLedger.entries.count == 1)
        }
    }

    // MARK: - (6) Cableado

    @Test("(6) el ciclo barre tras un pull COMPLETO, y el descarte apunta en el libro tras su save")
    func wiring() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let src = try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/Groups/GroupsSyncClient.swift"), encoding: .utf8)
        let completed = try #require(src.range(of: "if case .completed = pull {"))
        let sweep = try #require(src.range(of: "sweepRejectedOpeningBalanceShares(context: context)"))
        let elseBranch = try #require(src[completed.upperBound...].range(of: "} else {"))
        #expect(sweep.lowerBound > completed.upperBound && sweep.lowerBound < elseBranch.lowerBound,
                "el barrido va dentro de la rama del pull completo: antes, el re-pull aún no bajó el gasto")
        let settle = try #require(src.range(of: "func settleRejectedOpeningBalances("))
        let add = try #require(src[settle.upperBound...].range(of: "GroupsRejectedOpeningBalanceLedger.add(ledgerEntries)"))
        let rollback = try #require(src[settle.upperBound...].range(of: "context.rollback()\n            return 0"))
        #expect(add.lowerBound > rollback.upperBound, "solo se apunta lo que el save descartó de verdad")
    }
}
