//
//  ReverseDrainBatchesTests.swift
//  YalaTests / ICloudReturnAndEmpty
//
//  «Volver a tu iCloud» se quedaba más de 6 minutos en «Traer tus datos de tu cuenta de Yala» (card
//  `volver-a-tu-icloud-se-queda-en-traer-tus`, E07 del recorrido del 13-nov). Medido en el iPhone 14: 3090 cambios en la cola
//  de subida, la fase en `reverseDrainAll` sin moverse en 7 minutos y la cola sin bajar ni uno. El drenaje subía el outbox
//  ENTERO en una llamada y purgaba al final: el Worker aplica cada cambio en serie, así que eran minutos sin cifra,
//  «Cancelar» apagado y, al cerrar Yala, nada purgado.
//
//  Lo que fija esta suite, con el ejecutor REAL y un stub de red:
//   - cada tanda se purga ANTES de pedir la siguiente (lo subido sobrevive a cerrar Yala);
//   - la cifra «X de Y» avanza por tanda;
//   - el «sí» de cancelar corta entre tandas sin tirar lo confirmado;
//   - el orden de subida es el de siempre (HLC) aunque vaya partido.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
private final class DrainSession: CloudSyncSessionProviding {
    var currentUserID: String? { "sub-1" }
    func accessToken() async -> String? { "jwt" }
    var canRenewSession: Bool { true }
    func attestToken() async throws -> String? { nil }
}

private final class DrainBeaconStore: BeaconKeyValueStore, @unchecked Sendable {
    func setBool(_ value: Bool, forKey key: String) {}
    func setString(_ value: String, forKey key: String) {}
    func setDouble(_ value: Double, forKey key: String) {}
    func bool(forKey key: String) -> Bool { false }
    func string(forKey key: String) -> String? { nil }
    func double(forKey key: String) -> Double { 0 }
    func removeObject(forKey key: String) {}
    @discardableResult func synchronize() -> Bool { true }
}

/// `/sync/push` contesta `applied` a cada delta y deja mirar el outbox en el instante en que llega cada petición.
private final class DrainStub: SyncHTTPSession, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var pushSizes: [Int] = []
    private(set) var pushedSyncIDs: [String] = []
    /// Se llama en el main actor al llegar cada push, antes de responder (índice 0 = el primero).
    var onPushOnMain: (@MainActor (Int) -> Void)?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        let ok = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        if path.contains("sync/push") {
            var results: [[String: Any]] = []
            var ids: [String] = []
            if let json = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any],
               let deltas = json["deltas"] as? [[String: Any]] {
                for d in deltas {
                    let sid = d["sync_id"] as? String ?? ""
                    ids.append(sid)
                    results.append(["sync_id": sid, "client_mutation_id": d["client_mutation_id"] as? String ?? "",
                                    "status": "applied"])
                }
            }
            lock.lock()
            let index = pushSizes.count
            pushSizes.append(ids.count)
            pushedSyncIDs.append(contentsOf: ids)
            lock.unlock()
            if let hook = onPushOnMain { await MainActor.run { hook(index) } }
            let body = (try? JSONSerialization.data(withJSONObject: ["results": results])) ?? Data()
            return (body, ok)
        }
        if path.contains("sync/pull") {
            return (Data("{\"deltas\":[],\"max_server_seq\":0}".utf8), ok)
        }
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
    }
}

@Suite("Volver a tu iCloud · el drenaje sube por tandas", .serialized)
@MainActor
struct ReverseDrainBatchesTests {
    private let workerURL = URL(string: "https://stub.yala.test")!

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RevDrain-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear el directorio del store: \(error)")
        }
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "RD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "RD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "RD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func makeExecutor(_ context: ModelContext, _ stub: DrainStub, dir: URL) -> MigrationWorkExecutor {
        let token: () async -> String? = { "jwt" }
        let engine = CloudSyncEngine()
        let ledgerURL = dir.appendingPathComponent("relay-identity-ledger.json")
        engine.relayIdentityLedgerURL = ledgerURL
        return MigrationWorkExecutor(
            engine: engine,
            pushClient: SyncPushClient(baseURL: workerURL, tokenProvider: token, attestProvider: { nil },
                                       urlSession: stub),
            pullClient: SyncPullClient(baseURL: workerURL, tokenProvider: token, urlSession: stub),
            merkleClient: SyncMerkleClient(baseURL: workerURL, tokenProvider: token, urlSession: stub),
            accountClient: CloudAccountClient(baseURL: workerURL, urlSession: stub),
            session: DrainSession(), context: context,
            calendar: Calendar(identifier: .gregorian), now: { Date(timeIntervalSince1970: 1_700_000_000) },
            deviceID: "device-1", beacon: CloudBeacon(store: DrainBeaconStore()),
            personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
            storageDefaults: makeIsolatedDefaults(prefix: "revdrain.storage"),
            relayIdentityLedgerURL: ledgerURL)
    }

    /// Siembra `count` categorías y las pasa al outbox con un drain, como hace la app antes de subir.
    private func seedOutbox(_ context: ModelContext, count: Int, dir: URL) throws -> Int {
        for index in 0..<count {
            context.insert(Category(name: "cat-\(index)", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        }
        try context.save()
        let engine = CloudSyncEngine()
        engine.relayIdentityLedgerURL = dir.appendingPathComponent("relay-identity-ledger.json")
        #expect(engine.drainOnce(context: context), "control: el drain del fixture terminó")
        return try liveOutboxCount(context)
    }

    private func liveOutboxCount(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }.count
    }

    /// La pieza que faltaba: con el outbox entero en una llamada, al llegar la SEGUNDA petición no se había purgado nada, y
    /// cerrar Yala ahí lo dejaba todo por subir otra vez. Con las tandas, lo de la primera ya no está en el outbox.
    @Test("cada tanda se purga antes de pedir la siguiente")
    func eachBatchIsPurgedBeforeTheNext() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let stub = DrainStub()
        let executor = makeExecutor(context, stub, dir: dir)
        let total = try seedOutbox(context, count: 120, dir: dir)
        #expect(total >= 120, "control del escenario: hay más de dos tandas que subir")

        var outboxWhenSecondPushArrived: Int?
        stub.onPushOnMain = { index in
            guard index == 1 else { return }
            do {
                outboxWhenSecondPushArrived = try liveOutboxCount(context)
            } catch {
                Issue.record("no se pudo leer el outbox: \(error)")
            }
        }

        let outcome = await executor.reverseDrainOnce(continueWhile: { true }, onProgress: { _ in })

        #expect(outcome == .completed)
        #expect(outboxWhenSecondPushArrived == total - MigrationWorkExecutor.reverseDrainBatchSize,
                "la primera tanda ya estaba purgada cuando salió la segunda")
        #expect(try liveOutboxCount(context) == 0)
        #expect(stub.pushSizes.allSatisfy { $0 <= MigrationWorkExecutor.reverseDrainBatchSize })
        #expect(stub.pushSizes.reduce(0, +) == total)
    }

    @Test("la cifra «X de Y» avanza por tanda y termina llena")
    func progressAdvancesPerBatch() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let stub = DrainStub()
        let executor = makeExecutor(context, stub, dir: dir)
        let total = try seedOutbox(context, count: 120, dir: dir)

        var seen: [CloudProgressStepsLogic.UploadProgress] = []
        let outcome = await executor.reverseDrainOnce(continueWhile: { true }, onProgress: { seen.append($0) })

        #expect(outcome == .completed)
        #expect(seen.first == CloudProgressStepsLogic.UploadProgress(done: 0, total: total), "arranca en 0 de Y")
        #expect(seen.last == CloudProgressStepsLogic.UploadProgress(done: total, total: total), "termina en Y de Y")
        #expect(seen.count == stub.pushSizes.count + 1, "una cifra por tanda confirmada, más la inicial")
        let dones = seen.map(\.done)
        #expect(dones == dones.sorted(), "nunca retrocede")
    }

    /// El «sí» de «Cancelar y seguir en tu cuenta de Yala» se mira antes de cada tanda: corta sin esperar al outbox entero
    /// y lo ya confirmado queda purgado.
    @Test("con el «sí» de cancelar, corta entre tandas y conserva lo subido")
    func cancelStopsBetweenBatchesKeepingWhatWasConfirmed() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let stub = DrainStub()
        let executor = makeExecutor(context, stub, dir: dir)
        let total = try seedOutbox(context, count: 120, dir: dir)

        var cancelled = false
        stub.onPushOnMain = { index in if index == 0 { cancelled = true } }
        let outcome = await executor.reverseDrainOnce(continueWhile: { !cancelled }, onProgress: { _ in })

        #expect(outcome == .transient, "no da por drenado lo que no subió")
        #expect(stub.pushSizes.count == 1, "no pidió la segunda tanda")
        #expect(try liveOutboxCount(context) == total - MigrationWorkExecutor.reverseDrainBatchSize,
                "lo confirmado en la primera tanda se purgó")
    }

    /// Partir la subida no puede cambiar el orden en que llega al servidor (regla «Todo HLC guardado queda acotado»: con el
    /// reloj adelantado, el servidor solo conserva el orden propio si los cambios llegan en orden de HLC).
    @Test("el orden de subida sigue siendo el del HLC aunque vaya partido")
    func uploadOrderIsTheHLCOrderAcrossBatches() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let stub = DrainStub()
        let executor = makeExecutor(context, stub, dir: dir)
        _ = try seedOutbox(context, count: 120, dir: dir)
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        let expected = HLC.uploadOrder(rows, hlc: \.hlc, createdAt: \.createdAt).map { $0.syncID.uuidString.lowercased() }

        _ = await executor.reverseDrainOnce(continueWhile: { true }, onProgress: { _ in })

        #expect(stub.pushSizes.count > 1, "control: fue en varias tandas")
        #expect(stub.pushedSyncIDs == expected)
    }
}
