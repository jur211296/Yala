//
//  ReverseEpochTxRelationsTests.swift
//  YalaTests / CloudSync
//
//  Ticket `cloud-tx-epoch-orphan-relations`: un movimiento creado en la nube con cuenta y subcategoría las perdió
//  tras «Volver a iCloud» (device-QA 2026-07-17). La pérdida fue LOCAL y dentro de la ventana de la reversa.
//
//  Esta suite recorre los pasos REALES del ejecutor que escriben en el store personal durante esa ventana
//  —drenaje con su pull, verificación con su pull, barrido de zombies, recuento de rebinds, auto-cura de
//  duplicados, muestreo de la subida— y el dedup del arranque siguiente, sobre un store on-disk y contra un
//  backend falso que GUARDA lo que se le sube y lo devuelve en el pull, como el de verdad. Así el movimiento
//  recibe su propio eco, que es lo único que distingue a una fila de la época nube de las anteriores.
//
//  Lo que NO puede cubrir: el espejo de CloudKit (no existe en el simulador). El remontaje y su export quedan
//  fuera; lo dice el ticket.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Backend falso con memoria

/// Guarda la versión vigente de cada fila (como `apply_delta`) y la sirve en el pull por `server_seq`. Un push
/// re-estampa la fila con un `server_seq` nuevo, así que el pull siguiente devuelve el ECO de lo que se subió.
private final class EchoBackend: SyncHTTPSession, @unchecked Sendable {
    private struct Row { var json: [String: Any]; var seq: Int64 }
    private let lock = NSLock()
    private var rows: [String: Row] = [:]
    private var seq: Int64 = 0
    /// El Merkle que contesta el backend: lo calcula el test desde el store local (converge).
    var merkleProvider: (@MainActor () -> Data)?
    private(set) var pushedEntityTypes: [String] = []
    /// Cuántos deltas sirvió el pull, por tabla: prueba que el eco BAJÓ.
    private(set) var pulledEntityTypes: [String] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        func resp(_ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        if path.contains("sync/push") {
            var results: [[String: Any]] = []
            if let json = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any],
               let deltas = json["deltas"] as? [[String: Any]] {
                lock.withLock {
                    for d in deltas {
                        let sid = (d["sync_id"] as? String ?? "").lowercased()
                        let type = d["entity_type"] as? String ?? ""
                        let op = d["op"] as? String ?? "upsert"
                        seq += 1
                        let tomb = op == "tombstone"
                        let row: [String: Any] = [
                            "entity_type": type, "sync_id": sid, "op": op,
                            "hlc": d["hlc"] as? String ?? "", "server_seq": seq,
                            "schema_version": d["schema_version"] as? Int ?? 1,
                            "fields": tomb ? [String: Any]() : (d["fields"] ?? [String: Any]()),
                            "field_hlcs": tomb ? [String: Any]() : (d["field_hlcs"] ?? [String: Any]()),
                        ]
                        rows["\(type)|\(sid)"] = Row(json: row, seq: seq)
                        pushedEntityTypes.append(type)
                        results.append(["sync_id": d["sync_id"] ?? "", "client_mutation_id": d["client_mutation_id"] ?? "",
                                        "status": "applied"])
                    }
                }
            }
            return ((try? JSONSerialization.data(withJSONObject: ["results": results])) ?? Data(), resp(200))
        }
        if path.contains("sync/pull") {
            let comps = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let since = Int64(comps?.queryItems?.first { $0.name == "since" }?.value ?? "0") ?? 0
            let limit = Int(comps?.queryItems?.first { $0.name == "limit" }?.value ?? "500") ?? 500
            let page = lock.withLock {
                let page = Array(rows.values.filter { $0.seq > since }.sorted { $0.seq < $1.seq }.prefix(limit))
                pulledEntityTypes.append(contentsOf: page.compactMap { $0.json["entity_type"] as? String })
                return page
            }
            let maxSeq = page.last?.seq ?? since
            let body: [String: Any] = ["deltas": page.map(\.json), "max_server_seq": maxSeq]
            return ((try? JSONSerialization.data(withJSONObject: body)) ?? Data(), resp(200))
        }
        if path.contains("sync/merkle") {
            let provider = merkleProvider
            let body = await MainActor.run { provider?() } ?? Data()
            return (body, resp(200))
        }
        if path.contains("account/migration") {
            return (Data("{\"ok\":true}".utf8), resp(200))
        }
        return (Data(), resp(404))
    }
}

@MainActor
private final class EchoSession: CloudSyncSessionProviding {
    var currentUserID: String? { "sub-1" }
    func accessToken() async -> String? { "jwt" }
    var canRenewSession: Bool { true }
    func attestToken() async throws -> String? { nil }
}

/// Sin tombstones en el backend: el caso del ticket (nadie borró nada).
@MainActor
private final class NoTombstones: ReverseTombstoneSource {
    func pullPage(since: Int64, limit: Int) async -> PullOutcome {
        .page(PulledPage(deltas: [], maxServerSeq: 0))
    }
}

// MARK: - Suite

@Suite("Reversa · el movimiento de la época nube conserva cuenta y subcategoría", .serialized)
@MainActor
struct ReverseEpochTxRelationsTests {

    private let workerURL = URL(string: "https://stub.yala.test")!

    private struct Fixture {
        let dir: URL
        let container: ModelContainer
        let context: ModelContext
        let backend: EchoBackend
        let executor: MigrationWorkExecutor
        let account: Account
        let subcategory: Subcategory
        let category: Yala.Category
    }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "RETR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "RETR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "RETR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    /// Corpus «migrado»: categoría, subcategoría semilla, cuenta y movimientos viejos que ya están en el backend
    /// (suben con una pasada del drenaje y su eco ya se aplicó). Es el punto de partida de la época nube.
    private func makeMigratedFixture() async throws -> Fixture {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RETR-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let container = try makeContainer(dir)
        let context = ModelContext(container)

        let category = Yala.Category(name: "Comida", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: true)
        context.insert(category)
        let subcategory = Subcategory(name: "Supermercados", category: category)
        context.insert(subcategory)
        let account = Account(name: "Cuenta principal PEN", currencyCode: "PEN", colorHex: "#00AA00",
                              iconName: "banknote", type: "bank")
        context.insert(account)
        for i in 0..<3 {
            context.insert(TransactionItem(
                date: Date(timeIntervalSinceNow: -Double(86_400 * (i + 1))), amount: -Double(10 + i),
                currencyCode: "PEN", note: "pre-época \(i)", category: category, subcategory: subcategory,
                account: account, amountInPreferredCurrency: -Double(10 + i)))
        }
        try context.save()

        let backend = EchoBackend()
        backend.merkleProvider = { Self.merkleBody(context) }
        let token: () async -> String? = { "jwt" }
        let ledgerURL = dir.appendingPathComponent("relay-identity-ledger.json")
        let engine = CloudSyncEngine()
        engine.relayIdentityLedgerURL = ledgerURL
        let executor = MigrationWorkExecutor(
            engine: engine,
            pushClient: SyncPushClient(baseURL: workerURL, tokenProvider: token, urlSession: backend),
            pullClient: SyncPullClient(baseURL: workerURL, tokenProvider: token, urlSession: backend),
            merkleClient: SyncMerkleClient(baseURL: workerURL, tokenProvider: token, urlSession: backend),
            accountClient: CloudAccountClient(baseURL: workerURL, urlSession: backend),
            session: EchoSession(), context: context,
            calendar: Calendar(identifier: .gregorian), now: { Date() },
            deviceID: "device-1", personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
            storageDefaults: makeIsolatedDefaults(prefix: "retr.storage"),
            reverseTombstoneSource: NoTombstones(),
            relayIdentityLedgerURL: ledgerURL)

        // La migración: el corpus sube y su eco vuelve (la segunda pasada ya no trae nada nuevo).
        #expect(await executor.reverseDrainOnce() == .completed, "control: el corpus inicial sube")
        #expect(backend.pushedEntityTypes.filter { $0 == "tx_items" }.count == 3,
                "control: los movimientos viejos están en el backend")
        #expect(await executor.reverseDrainOnce() == .completed)

        return Fixture(dir: dir, container: container, context: context, backend: backend, executor: executor,
                       account: account, subcategory: subcategory, category: category)
    }

    /// El Merkle del backend calculado desde el store local; con `diverging`, `tx_items` y la raíz no cuadran.
    private static func merkleBody(_ context: ModelContext, diverging: Bool = false) -> Data {
        guard let local = try? SyncMerkle.computeLocalMerkle(context: context) else { return Data() }
        var entities: [String: Any] = [:]
        for (table, summary) in local.entities { entities[table] = ["count": summary.count, "hash": summary.hashHex] }
        var root = local.rootHex
        if diverging {
            entities["tx_items"] = ["count": 99, "hash": String(repeating: "0", count: 64)]
            root = String(repeating: "0", count: 64)
        }
        return (try? JSONSerialization.data(withJSONObject: [
            "canon_version": "c1", "capability_set": "v1", "root": root, "entities": entities,
        ])) ?? Data()
    }

    /// Un movimiento nuevo de la época nube, con cuenta y subcategoría, como lo crea la persona.
    private func createEpochTx(_ f: Fixture, note: String, in context: ModelContext? = nil) throws {
        let ctx = context ?? f.context
        let account = try #require(ctx.model(for: f.account.persistentModelID) as? Account)
        let sub = try #require(ctx.model(for: f.subcategory.persistentModelID) as? Subcategory)
        let cat = try #require(ctx.model(for: f.category.persistentModelID) as? Yala.Category)
        ctx.insert(TransactionItem(date: Date(), amount: -500, currencyCode: "PEN", note: note, category: cat,
                                   subcategory: sub, account: account, amountInPreferredCurrency: -500))
        try ctx.save()
    }

    /// Los pasos de la reversa que escriben en el store personal, en su orden (§h): drenaje con pull, verificación
    /// con pull, y tras el remontaje el barrido de zombies, los rebinds, la auto-cura y el muestreo de la subida.
    /// Cierra con el dedup del arranque, que corre sin gate de modo tras relanzar.
    private func runReverseWritingSteps(_ f: Fixture) async {
        #expect(await f.executor.reverseDrainOnce() == .completed, "reverseDrainAll")
        _ = await f.executor.verify(underMigrationLease: false)
        #expect(await f.executor.sweepZombies(sinceSeq: 0) == .completed(deleted: 0), "deletingZombies")
        _ = f.executor.verifyRebinds()
        #expect(f.executor.healDuplicates() == 0, "dedupHealed: no hay duplicados que curar")
        _ = f.executor.reverseUploadStatus()
        _ = CategoryDeduplicationService.runAllDeduplication(in: f.context)
    }

    /// Las relaciones del movimiento leídas en un contexto y, además, en un contenedor NUEVO sobre el mismo disco:
    /// el «matar y reabrir» del guion. Se compara por IDENTIDAD (`shortcutID`/`syncID`), no por nombre: una fila
    /// re-apuntada a un duplicado con el mismo nombre pasaría la comparación por nombre (lo cazó la review). Y no
    /// puede haber una segunda cuenta ni subcategoría: un merge hacia un ganador nuevo también re-apunta.
    private func assertIntact(_ f: Fixture, note: String) throws {
        let accountID = f.account.shortcutID, subID = f.subcategory.shortcutID, catID = f.category.syncID
        for (label, ctx) in [("en caliente", f.context), ("tras reabrir", ModelContext(try makeContainer(f.dir)))] {
            let tx = try #require(try ctx.fetch(
                FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.note == note })).first)
            #expect(tx.account?.shortcutID == accountID, "\(label): la cuenta sigue puesta")
            #expect(tx.subcategory?.shortcutID == subID, "\(label): la subcategoría sigue puesta")
            #expect(tx.category?.syncID == catID, "\(label): la categoría sigue puesta")
            #expect(try ctx.fetchCount(FetchDescriptor<Account>()) == 1, "\(label): sin cuentas duplicadas")
            #expect(try ctx.fetchCount(FetchDescriptor<Subcategory>()) == 1, "\(label): sin subcategorías duplicadas")
        }
        let danglers = try f.context.fetch(FetchDescriptor<SyncDanglingRef>())
        #expect(danglers.isEmpty, "ninguna ref quedó colgada: \(danglers.map(\.column))")
    }

    // MARK: - Variantes

    /// El caso original: creado y revertido enseguida (~4 min), sin que un ciclo de la nube haya bajado su eco.
    /// El eco le llega DENTRO de la reversa, en el pull del drenaje.
    @Test("reversa inmediata: el eco llega dentro de la reversa y las relaciones siguen puestas")
    func immediateReverse_keepsRelations() async throws {
        let f = try await makeMigratedFixture(); defer { try? FileManager.default.removeItem(at: f.dir) }
        try createEpochTx(f, note: "Prueba staging")
        let pulledBefore = f.backend.pulledEntityTypes.filter { $0 == "tx_items" }.count
        await runReverseWritingSteps(f)
        #expect(f.backend.pushedEntityTypes.filter { $0 == "tx_items" }.count == 4,
                "control: el movimiento de la época subió (3 viejos + 1)")
        #expect(f.backend.pulledEntityTypes.filter { $0 == "tx_items" }.count == pulledBefore + 1,
                "control: su eco bajó y se aplicó dentro de la reversa")
        try assertIntact(f, note: "Prueba staging")
    }

    /// La espera larga: la nube estable bajó el eco en ciclos anteriores; la reversa llega después. Ojo al leer su
    /// rojo: un apply que rompa la relación lo rompe ya en esos ciclos, no en la reversa (lo dijo la review). Fija
    /// las dos mitades del guion del 2026-07-17: la época nube Y la reversa que llega tarde.
    @Test("reversa tras varios ciclos: el eco ya aplicado no cambia nada en la reversa")
    func lateReverse_keepsRelations() async throws {
        let f = try await makeMigratedFixture(); defer { try? FileManager.default.removeItem(at: f.dir) }
        try createEpochTx(f, note: "qa-eco")
        // Ciclos de la nube estable (drain + push + pull), como la cadencia del runtime.
        for _ in 0..<3 { #expect(await f.executor.reverseDrainOnce() == .completed) }
        await runReverseWritingSteps(f)
        try assertIntact(f, note: "qa-eco")
    }

    /// La remediación del Merkle pone el cursor a cero y vuelve a bajar el corpus entero: dentro de la reversa, el
    /// movimiento de la época y los viejos se re-aplican sobre sus filas.
    @Test("reversa con re-pull completo: el corpus re-aplicado conserva las relaciones")
    func reverseWithFullRepull_keepsRelations() async throws {
        let f = try await makeMigratedFixture(); defer { try? FileManager.default.removeItem(at: f.dir) }
        try createEpochTx(f, note: "repull")
        let cursor = try #require(try f.context.fetch(FetchDescriptor<SyncCursor>()).first)
        cursor.serverSeqCursor = 0
        try f.context.save()
        await runReverseWritingSteps(f)
        try assertIntact(f, note: "repull")
        for i in 0..<3 { try assertIntact(f, note: "pre-época \(i)") }
    }

    /// La verificación no cuadra a la primera (el device tenía divergencia en `tx_items`): la reversa vuelve al
    /// drenaje y verifica otra vez, con dos pulls más sobre la fila de la época.
    @Test("reversa con la verificación en desacuerdo: el re-drenaje conserva las relaciones")
    func reverseWithVerifyMismatch_keepsRelations() async throws {
        let f = try await makeMigratedFixture(); defer { try? FileManager.default.removeItem(at: f.dir) }
        try createEpochTx(f, note: "mismatch")
        var answered = 0
        f.backend.merkleProvider = {
            answered += 1
            return Self.merkleBody(f.context, diverging: answered == 1)
        }
        #expect(await f.executor.reverseDrainOnce() == .completed, "reverseDrainAll")
        let first = await f.executor.verify(underMigrationLease: false)
        #expect(first == .mismatch, "control: la primera verificación no cuadra")
        await runReverseWritingSteps(f)
        try assertIntact(f, note: "mismatch")
    }

    /// El movimiento nace en OTRO contexto del mismo contenedor y la reversa corre sobre el suyo, con las inversas
    /// de la cuenta y la subcategoría ya cargadas antes del alta.
    @Test("reversa con el movimiento creado en otro contexto: las relaciones siguen puestas")
    func reverseWithTxFromAnotherContext_keepsRelations() async throws {
        let f = try await makeMigratedFixture(); defer { try? FileManager.default.removeItem(at: f.dir) }
        _ = f.account.transactions?.count
        _ = f.subcategory.transactions?.count
        try createEpochTx(f, note: "otro-contexto", in: ModelContext(f.container))
        await runReverseWritingSteps(f)
        try assertIntact(f, note: "otro-contexto")
    }
}
