//
//  MigrationSnapshotUploaderTests.swift
//  YalaTests / CloudSync
//
//  Uploader del snapshot completo (I10-wiring w4). Container 3-stores on-disk (`.serialized`) + un
//  `SyncHTTPSession` stub que ECOA `applied` por delta. Cubre: páginas deterministas (orden de tabla UTF-8
//  + keyset por afterSyncID); full-row (todas las columnas del manifest en `fields`); resume desde cursor NO
//  re-sube lo confirmado; push transient → el outbox NO se purga (cursor NO avanza); write concurrente
//  post-baseline → aparece como delta INCREMENTAL en el push (drain), sin pérdida; fila sin syncID → skip.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Stub HTTP que ecoa `applied` por delta

/// Parsea el body `{deltas:[…]}` del push y devuelve `{results:[{…, status:"applied"}]}` correlacionando por
/// `client_mutation_id`. Graba los `sync_id` y los bodies crudos para asertar orden/keyset/contenido.
private final class ApplyingStubSession: SyncHTTPSession, @unchecked Sendable {
    var failWithStatus: Int?
    private let lock = NSLock()
    private(set) var pushedSyncIDs: [String] = []
    private(set) var pushedBodies: [String] = []

    func resetCapture() {
        lock.lock(); pushedSyncIDs = []; pushedBodies = []; lock.unlock()
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let body = request.httpBody ?? Data()
        if let status = failWithStatus {
            let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(), resp)
        }
        var results: [[String: Any]] = []
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let deltas = json["deltas"] as? [[String: Any]] {
            lock.lock()
            pushedBodies.append(String(decoding: body, as: UTF8.self))
            for d in deltas {
                let sid = d["sync_id"] as? String ?? ""
                let cmid = d["client_mutation_id"] as? String ?? ""
                pushedSyncIDs.append(sid)
                results.append(["sync_id": sid, "client_mutation_id": cmid, "status": "applied"])
            }
            lock.unlock()
        }
        let respBody = (try? JSONSerialization.data(withJSONObject: ["results": results])) ?? Data("{\"results\":[]}".utf8)
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (respBody, resp)
    }
}

@Suite("MigrationSnapshotUploader · snapshot full-row (I10-wiring w4)", .serialized)
@MainActor
struct MigrationSnapshotUploaderTests {

    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    private let workerURL = URL(string: "https://stub.yala.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapUploader-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SU-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SU-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SU-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeUploader(_ context: ModelContext, _ engine: CloudSyncEngine,
                              _ stub: ApplyingStubSession, pageSize: Int) -> MigrationSnapshotUploader {
        let push = SyncPushClient(baseURL: workerURL, tokenProvider: { "jwt" }, urlSession: stub)
        return MigrationSnapshotUploader(engine: engine, pushClient: push, context: context,
                                         calendar: Calendar(identifier: .gregorian),
                                         now: { self.fixedNow }, pageSize: pageSize)
    }

    private func liveOutbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
    }

    /// Drena el snapshot completo devolviendo los cursores confirmados en orden.
    private func runToCompletion(_ uploader: MigrationSnapshotUploader, maxSteps: Int = 100) async -> [String] {
        var cursor: String?
        var cursors: [String] = []
        for _ in 0..<maxSteps {
            switch await uploader.uploadPage(cursor: cursor) {
            case .completed:
                return cursors
            case .pageConfirmed(let c):
                cursor = c
                cursors.append(c)
            case .transient:
                Issue.record("transient inesperado")
                return cursors
            }
        }
        Issue.record("el snapshot no completó en \(maxSteps) pasos")
        return cursors
    }

    // MARK: - Tests

    @Test("dataset multi-entidad: todas las filas suben, orden de tabla UTF-8 asc, outbox vacío al final")
    func multiEntity_allUploaded_tableOrder() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        var expectedIDs: Set<String> = []
        for i in 0..<3 {
            let cat = Category(name: "cat-\(i)", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
            cat.syncID = UUID()
            context.insert(cat)
            expectedIDs.insert(cat.syncID!.uuidString.lowercased())
        }
        for i in 0..<2 {
            let tag = Tag(name: "tag-\(i)")
            context.insert(tag)
            expectedIDs.insert(tag.id.uuidString.lowercased())
        }
        let acc = Account(name: "acc", currencyCode: "USD", colorHex: "#222222",
                          iconName: "creditcard", type: "checking")
        context.insert(acc)
        expectedIDs.insert(acc.shortcutID.uuidString.lowercased())
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 2)
        let cursors = await runToCompletion(uploader)

        // Todas las identidades subieron (set-equality; sin re-subidas espurias).
        #expect(Set(stub.pushedSyncIDs) == expectedIDs)
        // Outbox vivo vacío al final (todo confirmado).
        #expect(try liveOutbox(context).isEmpty)
        // Cursores en orden de tabla UTF-8 no-decreciente (accounts < categories < tags).
        let tables = cursors.compactMap { cursorTable($0) }
        for i in 1..<max(tables.count, 1) where i < tables.count {
            #expect(!Canonc1Codec.utf8BytesLess(tables[i], tables[i - 1]),
                    "tablas fuera de orden: \(tables)")
        }
    }

    @Test("full-row: el delta de una Category lleva TODAS las columnas del manifest")
    func fullRow_allColumns() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 10)
        _ = await runToCompletion(uploader)

        let body = stub.pushedBodies.joined()
        for column in EntityEmissionMap.category.columns {
            #expect(body.contains("\"\(column)\""), "falta la columna \(column) en el full-row")
        }
    }

    @Test("resume desde cursor: NO re-sube lo confirmado (keyset)")
    func resumeFromCursor_noReupload() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        var ids: [String] = []
        for i in 0..<3 {
            let cat = Category(name: "cat-\(i)", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
            cat.syncID = UUID()
            context.insert(cat)
            ids.append(cat.syncID!.uuidString.lowercased())
        }
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 1)
        // Página 1 (una Category).
        guard case .pageConfirmed(let cursor1) = await uploader.uploadPage(cursor: nil) else {
            Issue.record("página 1 no confirmó"); return
        }
        let page1IDs = Set(stub.pushedSyncIDs)
        #expect(page1IDs.count == 1)

        // Resume: NO baseline, keyset excluye la página 1.
        stub.resetCapture()
        guard case .pageConfirmed = await uploader.uploadPage(cursor: cursor1) else {
            Issue.record("página 2 no confirmó"); return
        }
        let page2IDs = Set(stub.pushedSyncIDs)
        #expect(page2IDs.isDisjoint(with: page1IDs), "la página 2 re-subió filas confirmadas: \(page2IDs)")
    }

    @Test("push transient (500): outcome .transient, el outbox NO se purga")
    func pushTransient_cursorNotAdvanced() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()
        stub.failWithStatus = 500

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 10)
        let outcome = await uploader.uploadPage(cursor: nil)
        #expect(outcome == .transient)
        // La fila quedó ENCOLADA (no confirmada) → el runner reintenta desde el mismo cursor.
        #expect(try !liveOutbox(context).isEmpty)
    }

    @Test("baseline suprime la re-captura de las filas pre-baseline (el snapshot no se duplica como incremental)")
    func baseline_suppressesPreBaselineRecapture() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Filas PRE-baseline (las que sube el snapshot full-row).
        for i in 0..<3 {
            let cat = Category(name: "pre-\(i)", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
            cat.syncID = UUID()
            context.insert(cat)
        }
        try context.save()

        // Baseline: cierra la ventana → los inserts pre-baseline NO deben re-capturarse como incrementales
        // (si lo hicieran, el snapshot full-row + el incremental duplicarían la fila server-side).
        engine.fastForwardHistoryBaseline(context: context)
        engine.drainOnce(context: context)

        #expect(try liveOutbox(context).isEmpty,
                "el baseline debe suprimir la re-captura de los inserts pre-baseline")
    }

    @Test("write concurrente post-baseline → delta INCREMENTAL capturado por el drain, sin pérdida")
    func concurrentWritePostBaseline_incremental() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let catA = Category(name: "pre-baseline", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        catA.syncID = UUID()
        context.insert(catA)
        try context.save()

        // Baseline (cierra la ventana). Los inserts posteriores aparecen en History → los recoge el drain.
        engine.fastForwardHistoryBaseline(context: context)

        // Escritura NUEVA post-baseline.
        let catB = Category(name: "post-baseline", colorHex: "#00FF00", isIncome: false, isDefaultSeed: false)
        catB.syncID = UUID()
        context.insert(catB)
        try context.save()
        engine.drainOnce(context: context)

        let live = try liveOutbox(context)
        // El drain captura la fila NUEVA post-baseline (la pre-baseline NO — baselined out).
        #expect(live.contains { $0.syncID == catB.syncID }, "el write post-baseline debe capturarse (incremental)")
        #expect(!live.contains { $0.syncID == catA.syncID }, "la fila pre-baseline NO debe re-capturarse")
        #expect(live.count == 1)
    }

    @Test("fila sin syncID → la enumeración del snapshot la SALTA en su página")
    func rowWithoutSyncID_skippedInEnumeration() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let tx1 = TransactionItem(date: fixedNow, amount: -5, currencyCode: "USD")
        tx1.syncID = UUID()
        tx1.amountInPreferredCurrency = -5
        tx1.preferredCurrencyCode = "USD"
        context.insert(tx1)
        let tx2 = TransactionItem(date: fixedNow, amount: -7, currencyCode: "USD")
        tx2.syncID = nil   // sin identidad → el snapshot la SALTA en la enumeración (breadcrumb identityGap)
        tx2.amountInPreferredCurrency = -7
        tx2.preferredCurrencyCode = "USD"
        context.insert(tx2)
        try context.save()

        // UNA página: la enumeración de tx_items incluye SOLO tx1 (tx2 sin syncID se salta). El `drainOnce`
        // interno acuña un syncID defensivo a tx2 (born-cloud sweep) pero su cambio syncID-only NO emite fila
        // de dominio → tx2 NO se sube en esta página. (En una pasada COMPLETA el sweep sí terminaría
        // subiéndola: comportamiento correcto del sistema, no del snapshot — por eso se asierta una página.)
        let uploader = makeUploader(context, engine, stub, pageSize: 10)
        let outcome = await uploader.uploadPage(cursor: nil)
        guard case .pageConfirmed = outcome else {
            Issue.record("se esperaba pageConfirmed, fue \(outcome)"); return
        }
        #expect(stub.pushedSyncIDs == [tx1.syncID!.uuidString.lowercased()])
    }

    // MARK: - Helpers

    /// Extrae el nombre de tabla de un cursor JSON `{table, afterSyncID}` para las asserts de orden.
    private func cursorTable(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["table"] as? String
    }
}
