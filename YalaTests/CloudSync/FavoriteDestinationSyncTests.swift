//
//  FavoriteDestinationSyncTests.swift
//  YalaTests / CloudSync
//
//  Card da5d por el Modo Nube: la columna `favorite_payments.destination_account_ref` (el destino de un favorito de
//  transferencia, UX 2.2 · L2-14) con `since: 4`. Lo que fija, con el molde de `CashFlowAmountChangeSyncTests`:
//   - con `v3` la columna ni se emite (un Worker v3 rechazaría la fila entera) y lo cambiado se APUNTA; con `v4`, sí;
//   - ida y vuelta: lo que un teléfono emite en v4, otro lo aplica con su destino; sin la cuenta destino todavía, queda
//     un dangler que el pase final resuelve;
//   - al subir de v3 a v4 se reemiten los favoritos apuntados, con SOLO esa columna;
//   - el remapeo de identidad de una cuenta reemite también los favoritos que la tienen como DESTINO.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · favoritos: destino de una transferencia (destination_account_ref, v4)", .serialized)
@MainActor
struct FavoriteDestinationSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavDest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "FD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "FD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "FD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suite) ?? previous
        SyncCapability.defaults = isolated
        if let level { isolated.set(level, forKey: SyncCapability.backendManifestVersionKey) }
        return {
            isolated.removePersistentDomain(forName: suite)
            SyncCapability.defaults = previous
        }
    }

    private let node = "0123456789abcdef"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    private func account(_ context: ModelContext, _ name: String) -> Account {
        let a = Account(name: name, currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill",
                        type: AccountType.checking.rawValue)
        context.insert(a)
        return a
    }

    /// Un favorito de transferencia con identidad (`syncID`), como lo deja la captura en modo nube.
    private func transferFavorite(_ context: ModelContext, from origin: Account, to destination: Account?) -> FavoritePayment {
        let f = FavoritePayment(name: "Ahorro del mes", transactionType: TransactionType.transfer.rawValue, amount: 200,
                                account: origin, destinationAccount: destination, currencyCode: "PEN")
        f.syncID = UUID()
        context.insert(f)
        return f
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    // MARK: - Emisión

    @Test func emission_v4_carriesTheDestination_v3_doesNot() throws {
        let context = try makeContext(freshDir())
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = transferFavorite(context, from: origin, to: savings)
        let emission = EntityEmissionMap.favoritePayment

        let v4 = DeltaEmitter.emit(model: favorite, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 4)
        #expect(v4.fields["destination_account_ref"] == .uuid(savings.shortcutID))
        #expect(v4.fieldHlcs["destination_account_ref"] == hlc(1))

        let v3 = DeltaEmitter.emit(model: favorite, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 3)
        #expect(v3.fields["destination_account_ref"] == nil)
        #expect(v3.fields["account_ref"] == .uuid(origin.shortcutID), "el resto de la fila sí viaja")

        let onlyDestination = DeltaEmitter.emit(model: favorite, emission: emission,
                                                changedColumns: ["destination_account_ref"], hlc: hlc(1),
                                                capabilityLevel: 3)
        #expect(onlyDestination.fields.isEmpty && onlyDestination.fieldHlcs.isEmpty)
    }

    // MARK: - Drain

    @Test func drain_v3_neverSendsTheColumn_andNotesTheFavorite() throws {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = transferFavorite(context, from: origin, to: nil)
        try context.save()
        engine.drainOnce(context: context)
        #expect(SyncCapability.suppressedFavoriteDestinations.isEmpty, "sin destino no hay nada que apuntar")

        favorite.destinationAccount = savings
        try context.save()
        engine.drainOnce(context: context)

        let favoriteID = try #require(favorite.syncID)
        let rows = try outbox(context).filter { $0.syncID == favoriteID }
        #expect(rows.count == 1, "cambiar solo el destino con v3 no saca ninguna fila")
        for row in rows { #expect(try fields(row)["destination_account_ref"] == nil) }
        #expect(SyncCapability.suppressedFavoriteDestinations == [favoriteID])
    }

    @Test func drain_v4_sendsTheDestination_onAnEditOfOnlyIt() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = transferFavorite(context, from: origin, to: nil)
        try context.save()
        engine.drainOnce(context: context)

        favorite.destinationAccount = savings
        try context.save()
        engine.drainOnce(context: context)

        let favoriteID = try #require(favorite.syncID)
        let rows = try outbox(context).filter { $0.syncID == favoriteID }
        #expect(rows.count == 2)
        let update = try #require(rows.last)
        let updateFields = try fields(update)
        #expect(Set(updateFields.keys) == ["destination_account_ref"])
        #expect((updateFields["destination_account_ref"] as? String)?.lowercased()
                == savings.shortcutID.uuidString.lowercased())
        #expect(SyncCapability.suppressedFavoriteDestinations.isEmpty)
    }

    // MARK: - Ida y vuelta

    private func favoritePage(_ favorite: FavoritePayment, seq: Int) throws -> PulledPage {
        let emission = EntityEmissionMap.favoritePayment
        let emitted = DeltaEmitter.emit(model: favorite, emission: emission, changedColumns: emission.columns,
                                        hlc: hlc(seq), capabilityLevel: 4)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(seq))\"" }.joined(separator: ",")
        let syncID = try #require(favorite.syncID).uuidString.lowercased()
        let delta = """
        {"entity_type":"favorite_payments","sync_id":"\(syncID)","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(seq))","server_seq":\(seq),"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":\(seq),\"manifest_version\":4}"
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    @Test func roundTrip_destinationEmittedOnOnePhone_arrivesOnTheOther() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let origin = account(phoneA, "Principal")
        let savings = account(phoneA, "Ahorros")
        let favorite = transferFavorite(phoneA, from: origin, to: savings)
        try phoneA.save()
        let page = try favoritePage(favorite, seq: 2)

        // El otro teléfono ya tiene las dos cuentas, con las mismas identidades.
        let phoneB = try makeContext(freshDir())
        let originB = account(phoneB, "Principal")
        originB.shortcutID = origin.shortcutID
        let savingsB = account(phoneB, "Ahorros")
        savingsB.shortcutID = savings.shortcutID
        try phoneB.save()
        #expect(CloudSyncEngine().applyPage(page, context: phoneB, now: applyNow))

        let favoriteID = favorite.syncID
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<FavoritePayment>()).first { $0.syncID == favoriteID })
        #expect(arrived.destinationAccount?.shortcutID == savings.shortcutID)
        #expect(arrived.account?.shortcutID == origin.shortcutID)
    }

    /// La cuenta destino aún no llegó: queda un dangler de `destination_account_ref`, y cuando la cuenta llega, el pase
    /// final la engancha.
    @Test func roundTrip_destinationNotYetLocal_leavesADanglerThatResolves() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let origin = account(phoneA, "Principal")
        let savings = account(phoneA, "Ahorros")
        let favorite = transferFavorite(phoneA, from: origin, to: savings)
        try phoneA.save()
        let page = try favoritePage(favorite, seq: 2)

        let phoneB = try makeContext(freshDir())
        let originB = account(phoneB, "Principal")
        originB.shortcutID = origin.shortcutID
        try phoneB.save()
        #expect(CloudSyncEngine().applyPage(page, context: phoneB, now: applyNow))
        let danglers = try phoneB.fetch(FetchDescriptor<SyncDanglingRef>())
        let dangler = try #require(danglers.first { $0.column == "destination_account_ref" })
        #expect(dangler.targetUUID == savings.shortcutID)

        let savingsB = account(phoneB, "Ahorros")
        savingsB.shortcutID = savings.shortcutID
        try phoneB.save()
        #expect(EntityApplyMap.reresolveDangler(dangler, context: phoneB) == .resolved)
        let favoriteID = favorite.syncID
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<FavoritePayment>()).first { $0.syncID == favoriteID })
        #expect(arrived.destinationAccount?.shortcutID == savings.shortcutID)
    }

    // MARK: - La subida de v3 a v4

    @Test func pull_upgradeToV4_reemitsTheNotedFavorite_withOnlyTheDestination() async throws {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = transferFavorite(context, from: origin, to: nil)
        try context.save()
        engine.drainOnce(context: context)
        favorite.destinationAccount = savings
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }   // lo demás ya subió
        try context.save()
        let favoriteID = try #require(favorite.syncID)
        #expect(SyncCapability.suppressedFavoriteDestinations == [favoriteID])

        let announce = "{\"deltas\":[],\"max_server_seq\":0,\"manifest_version\":4}"
        let session = FavoriteCapabilitySession(bodies: [Data(announce.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context)

        #expect(session.capabilityHeaders.first == "v3")
        #expect(session.capabilityHeaders.contains("v4"))
        let reemitted = try #require(try outbox(context).last { $0.syncID == favoriteID })
        #expect(Set(try fields(reemitted).keys) == ["destination_account_ref"], "solo la columna, no la fila entera")
        #expect(!SyncCapability.upgradePending)
        #expect(SyncCapability.suppressedFavoriteDestinations.isEmpty)
    }

    @Test func upgradeWithTheWorkerBackAtV3_keepsTheNotedFavorites() throws {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = transferFavorite(context, from: origin, to: savings)
        try context.save()
        let favoriteID = try #require(favorite.syncID)
        SyncCapability.noteSuppressedFavoriteDestination(favoriteID)
        SyncCapability.upgradePending = true   // pedida y el Worker volvió a la v3 antes de cumplirse

        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        #expect(try outbox(context).filter { $0.syncID == favoriteID }.isEmpty, "con v3 la columna no viajaría")
        #expect(SyncCapability.suppressedFavoriteDestinations == [favoriteID], "se queda para la subida a v4")
    }

    // MARK: - Remapeo de identidad de la cuenta destino

    /// El remapeo de identidad de una cuenta reemite las filas que la referencian; el favorito que la tiene como
    /// DESTINO también, o su `destination_account_ref` apuntaría para siempre a la identidad vieja.
    @Test func remapOfTheDestinationAccount_reemitsTheFavorite() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let origin = account(context, "Principal")
        let savings = account(context, "Ahorros")
        let favorite = transferFavorite(context, from: origin, to: savings)
        try context.save()

        let previousMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags.storageMode = previousMode
            CloudSyncFlags._testResetStorageModeOverride()
        }
        let engine = CloudSyncEngine(nodeID: NodeID.generate())
        let oldID = savings.shortcutID
        savings.shortcutID = UUID()   // regeneración: `favorite.destinationAccount` sigue apuntando al MISMO objeto
        _ = try engine.emitIdentityRemap(
            pairs: [IdentityRemapPair(entityType: SyncEntityType.account, oldID: oldID, newID: savings.shortcutID)],
            in: context, now: applyNow)

        let favoriteID = try #require(favorite.syncID)
        let row = try #require(try outbox(context).first {
            $0.syncID == favoriteID && $0.opRaw == SyncOutboxOp.upsert.rawValue
        }, "el favorito con esa cuenta de destino no se reemitió")
        #expect(row.fieldsJSON.contains(savings.shortcutID.uuidString.lowercased()))
        #expect(!row.fieldsJSON.contains(oldID.uuidString.lowercased()))
    }
}

// MARK: - Stub

private final class FavoriteCapabilitySession: SyncHTTPSession, @unchecked Sendable {
    /// Respuestas en orden; la última se repite.
    let bodies: [Data]
    private(set) var capabilityHeaders: [String] = []
    init(bodies: [Data]) { self.bodies = bodies }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capabilityHeaders.append(request.value(forHTTPHeaderField: "X-Yala-Capability-Set") ?? "-")
        let body = bodies[min(capabilityHeaders.count - 1, bodies.count - 1)]
        let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200,
                                       httpVersion: nil, headerFields: nil)
        return (body, response ?? URLResponse())
    }
}
