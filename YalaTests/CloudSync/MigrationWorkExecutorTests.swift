//
//  MigrationWorkExecutorTests.swift
//  YalaTests / CloudSync
//
//  Ejecutor REAL del seam de la migración (I10-wiring w5). Container 3-stores on-disk (`.serialized`) +
//  RoutingStub (dispatch por path: /account/claim, /sync/push, /sync/pull, /sync/merkle) + KV beacon stub.
//  Cubre: claim (sin JWT → sessionExpired; 200 created → success), faro escrito en el KV, notWired journaled
//  (throw), verify pre-check TOCTOU (outbox no vacío → push-first → newDeltaDetected) + verify limpio
//  (pull → verifyIntegrity converge → match), y assignIdentity (backfill + flip del gate permanente).
//
//  Toca `CloudSyncFlags.identityCaptureEnabled` → `.serialized` + `defer { restore }`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Stubs

@MainActor
private final class FakeSession: CloudSyncSessionProviding {
    var token: String?
    var userID: String?
    init(token: String?, userID: String?) { self.token = token; self.userID = userID }
    var currentUserID: String? { userID }
    func accessToken() async -> String? { token }
    var canRenewSession: Bool { token != nil }
    func attestToken() async throws -> String? { nil }
}

/// Reloj MUTABLE para el test de throttle del heartbeat (I14-pre): avanzar `value` entre ticks sin recrear
/// el executor. MainActor (se muta y lee solo desde el test MainActor).
@MainActor
private final class MutableClock {
    var value: Date
    init(_ start: Date) { value = start }
}

private final class FakeBeaconStore: BeaconKeyValueStore, @unchecked Sendable {
    var bools: [String: Bool] = [:]
    var strings: [String: String] = [:]
    var doubles: [String: Double] = [:]
    func setBool(_ value: Bool, forKey key: String) { bools[key] = value }
    func setString(_ value: String, forKey key: String) { strings[key] = value }
    func setDouble(_ value: Double, forKey key: String) { doubles[key] = value }
    func bool(forKey key: String) -> Bool { bools[key] ?? false }
    func string(forKey key: String) -> String? { strings[key] }
    func double(forKey key: String) -> Double { doubles[key] ?? 0 }
    func removeObject(forKey key: String) { bools[key] = nil; strings[key] = nil; doubles[key] = nil }
    @discardableResult func synchronize() -> Bool { true }
}

/// Fuente de tombstones fabricada para el barrido de zombies (§h.3, golden §h.5). Sirve `pages` en orden
/// y luego una página VACÍA que agota la paginación; `forced` fuerza un outcome de red.
@MainActor
private final class FakeTombstoneSource: ReverseTombstoneSource {
    var pages: [PulledPage] = []
    var forced: PullOutcome?
    private var index = 0
    func pullPage(since: Int64, limit: Int) async -> PullOutcome {
        if let forced { return forced }
        if index < pages.count { defer { index += 1 }; return .page(pages[index]) }
        return .page(PulledPage(deltas: [], maxServerSeq: 0))
    }
}

/// Construye un tombstone `PulledDelta` de una tabla + syncID (op=.tombstone, fields vacíos).
@MainActor
private func tombstone(table: String, syncID: UUID, seq: Int64) -> PulledDelta {
    PulledDelta(entityType: table, syncID: syncID, op: .tombstone, fields: [:], fieldHlcs: [:],
                hlc: "deleted", serverSeq: seq, schemaVersion: 1, rawDelta: "{}")
}

/// Construye un upsert `PulledDelta` (para la enumeración del backend del adopt-reconcile: la enumeración
/// colecciona syncIDs de upserts Y tombstones; solo importa el `syncID`).
@MainActor
private func upsertDelta(table: String, syncID: UUID, seq: Int64) -> PulledDelta {
    PulledDelta(entityType: table, syncID: syncID, op: .upsert, fields: [:], fieldHlcs: [:],
                hlc: "hlc", serverSeq: seq, schemaVersion: 1, rawDelta: "{}")
}

/// Enruta por path: claim / push (ecoa applied) / pull (página vacía) / merkle (body configurable).
private final class RoutingStub: SyncHTTPSession, @unchecked Sendable {
    var claimBody = Data("{\"state\":\"created\"}".utf8)
    var claimStatus = 200
    private(set) var lastClaimBody: [String: Any]?
    var migrationBody = Data("{\"ok\":true}".utf8)
    var migrationStatus = 200
    private(set) var lastMigrationBody: [String: Any]?
    private(set) var migrationCallCount = 0
    var pushStatus = 200
    var merkleBody = Data()
    private let lock = NSLock()
    private(set) var pushedSyncIDs: [String] = []
    /// Deltas COMPLETOS del último push (para assertar contenido real — lección d49d2e47: fila full-row, no
    /// solo identidad). Cada entry es el objeto JSON `{sync_id, entity_type, fields, client_mutation_id}`.
    private(set) var lastPushedDeltas: [[String: Any]] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        func resp(_ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        if path.contains("account/migration") {
            migrationCallCount += 1
            lastMigrationBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            return (migrationBody, resp(migrationStatus))
        }
        if path.contains("account/claim") {
            lastClaimBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            return (claimBody, resp(claimStatus))
        }
        if path.contains("sync/push") {
            if pushStatus != 200 { return (Data(), resp(pushStatus)) }
            var results: [[String: Any]] = []
            if let json = try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any],
               let deltas = json["deltas"] as? [[String: Any]] {
                lock.lock()
                lastPushedDeltas = deltas
                for d in deltas {
                    let sid = d["sync_id"] as? String ?? ""
                    let cmid = d["client_mutation_id"] as? String ?? ""
                    pushedSyncIDs.append(sid)
                    results.append(["sync_id": sid, "client_mutation_id": cmid, "status": "applied"])
                }
                lock.unlock()
            }
            let body = (try? JSONSerialization.data(withJSONObject: ["results": results])) ?? Data()
            return (body, resp(200))
        }
        if path.contains("sync/pull") {
            return (Data("{\"deltas\":[],\"max_server_seq\":0}".utf8), resp(200))
        }
        if path.contains("sync/merkle") {
            return (merkleBody, resp(200))
        }
        return (Data(), resp(404))
    }
}

@Suite("MigrationWorkExecutor · ejecutor real (I10-wiring w5)", .serialized)
@MainActor
struct MigrationWorkExecutorTests {

    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    private let workerURL = URL(string: "https://stub.yala.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MWExec-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "MWE-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "MWE-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "MWE-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeExecutor(
        _ context: ModelContext, _ engine: CloudSyncEngine, _ stub: RoutingStub,
        _ session: FakeSession, _ beaconStore: FakeBeaconStore, personalStoreURL: URL,
        storageDefaults: UserDefaults? = nil,
        now: (() -> Date)? = nil,
        heartbeatInterval: TimeInterval = 60,
        tombstoneSource: ReverseTombstoneSource? = nil
    ) -> MigrationWorkExecutor {
        let token: () async -> String? = { "jwt" }
        let account = CloudAccountClient(baseURL: workerURL, urlSession: stub)
        let push = SyncPushClient(baseURL: workerURL, tokenProvider: token, urlSession: stub)
        let pull = SyncPullClient(baseURL: workerURL, tokenProvider: token, urlSession: stub)
        let merkle = SyncMerkleClient(baseURL: workerURL, tokenProvider: token, urlSession: stub)
        return MigrationWorkExecutor(
            engine: engine, pushClient: push, pullClient: pull, merkleClient: merkle,
            accountClient: account, session: session, context: context,
            calendar: Calendar(identifier: .gregorian), now: now ?? { self.fixedNow },
            deviceID: "device-1", beacon: CloudBeacon(store: beaconStore),
            personalStoreURL: personalStoreURL,
            storageDefaults: storageDefaults ?? makeIsolatedDefaults(prefix: "mwe.storage"),
            snapshotPageSize: 200, heartbeatInterval: heartbeatInterval,
            reverseTombstoneSource: tombstoneSource)
    }

    // MARK: - Claim

    @Test("performClaim: sin JWT → sessionExpired (nunca lanza)")
    func claim_noJWT_sessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: nil, userID: nil)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        let outcome = await executor.performClaim()
        #expect(outcome == .sessionExpired(detail: "no access token"))
    }

    @Test("performClaim: 200 created → success(.created)")
    func claim_created_success() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.performClaim() == .success(.created))
    }

    @Test("performClaim: el body lleva migration=true (bug device 2026-07-10: sin él el cutover se clava en not_in_progress)")
    func claim_sendsMigrationTrue() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        _ = await executor.performClaim()
        #expect(stub.lastClaimBody?["migration"] as? Bool == true,
                "el claim de la MIGRACIÓN debe armar migration_in_progress en el INSERT atómico")
    }

    // MARK: - Beacon / efectos

    @Test("execute(.writeBeacon): escribe linked+provider+hash en el KV (sin PII)")
    func execute_writeBeacon() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-abc-123")
        let beaconStore = FakeBeaconStore()
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, beaconStore,
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await executor.execute(.writeBeacon)
        #expect(beaconStore.bool(forKey: CloudBeacon.Keys.linked))
        #expect(beaconStore.string(forKey: CloudBeacon.Keys.provider) == "apple")
        #expect(beaconStore.string(forKey: CloudBeacon.Keys.accountHash) == CloudBeacon.hash("sub-abc-123"))
        // El hash NO es el sub en claro (sin PII).
        #expect(beaconStore.string(forKey: CloudBeacon.Keys.accountHash) != "sub-abc-123")
    }

    @Test("execute(.rollback): no-op REAL (device intacto pre-cutover) — no lanza y desarma mirror-off")
    func execute_rollback_isRealNoop() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = UserDefaults(suiteName: "test.rollback.\(UUID().uuidString)")!
        defaults.set(true, forKey: MigrationWorkExecutor.relaunchRequestedKey)  // defensivo: no debería estar
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.rollback)   // bug device 2026-07-10: notWired lo dejaba journaled-pendiente para siempre
        #expect(defaults.bool(forKey: MigrationWorkExecutor.relaunchRequestedKey) == false)
    }

    // MARK: - Cutover (w6, §g.4)

    @Test("confirmCutoverServer: migration_progress ok → true; other_leader → false")
    func confirmCutoverServer_okAndOtherLeader() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.confirmCutoverServer() == true)

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        #expect(await executor.confirmCutoverServer() == false)
    }

    @Test("confirmCutoverServer: sin JWT → false (sessionExpired)")
    func confirmCutoverServer_noJWT_false() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: nil, userID: nil)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.confirmCutoverServer() == false)
    }

    @Test("persistLocalMode: escribe storageMode=.cloud en los defaults inyectados → true")
    func persistLocalMode_writesCloud() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let storageDefaults = makeIsolatedDefaults(prefix: "mwe.persist")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: storageDefaults)
        #expect(StorageModePersistence.read(storageDefaults) == .icloud)   // antes: default
        #expect(await executor.persistLocalMode() == true)
        #expect(StorageModePersistence.read(storageDefaults) == .cloud)
    }

    @Test("isMirrorConfirmedOff: false en tests (personalStoreMountedMode default .icloud)")
    func isMirrorConfirmedOff_defaultFalse() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(executor.isMirrorConfirmedOff() == false)
    }

    @Test("execute(.writeCloudKitMarker): inserta el marcador con serverSeqCut + accountHash (sin PII)")
    func execute_writeCloudKitMarker_insertsMarker() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-xyz")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // serverSeqCut se lee del SyncCursor (single-row).
        let cursor = SyncCursor(serverSeqCursor: 42)
        context.insert(cursor)
        try context.save()

        try await executor.execute(.writeCloudKitMarker)

        let markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
        #expect(markers.count == 1)
        let marker = try #require(markers.first)
        #expect(marker.serverSeqCut == 42)
        #expect(marker.writerDeviceID == "device-1")
        #expect(marker.migratedAtStamp == fixedNow)
        #expect(marker.accountHash == CloudBeacon.hash("sub-xyz"))
        #expect(marker.accountHash != "sub-xyz")   // sin PII
    }

    @Test("isMarkerExported: false en un store de test (sin metadata CloudKit real)")
    func isMarkerExported_falseWithoutRealCloudKit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(executor.isMarkerExported() == false)   // sin marcador
        try await executor.execute(.writeCloudKitMarker)
        // Marcador presente pero el store de test no tiene metadata CloudKit (cloudKitDatabase: .none).
        #expect(executor.isMarkerExported() == false)
    }

    @Test("execute(.runLeaderReconcileFromFrozenCloudKit): complete ok → no throw (sin residual, barrido no-op)")
    func execute_reconcileComplete_ok() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await executor.execute(.runLeaderReconcileFromFrozenCloudKit)   // migration_progress('complete') ok
    }

    @Test("done-effect w8: el barrido de RED rescata un write huérfano de la ventana de cutover ANTES del complete")
    func execute_reconcile_sweepRescuesOrphanWrite() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // Write "huérfano" de la ventana localModeSet→mirrorOff: en History, aún sin drenar/subir.
        let cat = Category(name: "orphan-window", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        context.insert(cat)
        try context.save()

        try await executor.execute(.runLeaderReconcileFromFrozenCloudKit)

        #expect(!stub.pushedSyncIDs.isEmpty, "el barrido debe drenar + subir el write huérfano")
        let live = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(live.isEmpty, "tras el barrido el outbox vivo queda limpio (rescate confirmado)")
    }

    @Test("done-effect w8: barrido con red caída → throw retomable, el complete NO se marca")
    func execute_reconcile_sweepTransient_retomable() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        stub.pushStatus = 503   // red caída durante el barrido
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        let cat = Category(name: "orphan-transient", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        context.insert(cat)
        try context.save()

        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.runLeaderReconcileFromFrozenCloudKit)
        }
        // El residual sigue VIVO (nada se perdió) → el resume re-corre el efecto entero.
        let live = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(!live.isEmpty, "con red caída el residual queda vivo, retomable")
    }

    // MARK: - Verify

    @Test("verify pre-check TOCTOU: outbox no vacío → push-first → newDeltaDetected")
    func verify_precheck_pushFirst() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // Una escritura local pendiente (sin drenar): el drain del pre-check la captura y la sube.
        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        context.insert(cat)
        try context.save()

        let probe = await executor.verify()
        #expect(probe == .newDeltaDetected)
        #expect(!stub.pushedSyncIDs.isEmpty, "el pre-check debe haber subido la fila pendiente")
        let live = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(live.isEmpty, "tras el push el outbox vivo debe quedar limpio")
    }

    @Test("verify limpio: pull vacío marca lastPull + Merkle converge → match")
    func verify_clean_converged_match() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // Merkle remoto = árbol LOCAL (store vacío → converge byte a byte).
        let local = SyncMerkle.computeLocalMerkle(context: context)
        var entitiesJSON: [String: Any] = [:]
        for (table, summary) in local.entities {
            entitiesJSON[table] = ["count": summary.count, "hash": summary.hashHex]
        }
        stub.merkleBody = try JSONSerialization.data(withJSONObject: [
            "canon_version": "c1", "capability_set": "v1",
            "root": local.rootHex, "entities": entitiesJSON,
        ])

        #expect(await executor.verify() == .match)
    }

    // MARK: - Identidad

    @Test("assignIdentity: backfill de syncID + testigos + flip del gate permanente")
    func assignIdentity_backfillsAndFlips() async throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        #expect(cat.syncID == nil)
        context.insert(cat)
        try context.save()

        try await executor.assignIdentity()

        #expect(CloudSyncFlags.identityCaptureEnabled, "el gate permanente debe quedar ON")
        #expect(cat.syncID != nil, "el backfill debe acuñar el syncID")
        let witnesses = try context.fetch(FetchDescriptor<SyncIdentity>())
        #expect(witnesses.contains { $0.syncID == cat.syncID }, "debe existir la fila testigo")
    }

    // MARK: - Reversa (§h, I11-2)

    /// GOLDEN §h.5: 50 TX post-cutover + 10 tombstones fake + 1 SyncIdentity rebound → tras sweep 40 vivas,
    /// 0 zombies, verifyRebinds()==1; idempotente; tombstone de syncID inexistente no-op; el sweep NO avanza
    /// SyncCursor NI borra testigos; anti-eco (drainOnce tras el sweep no produce filas nuevas en el outbox).
    @Test("sweepZombies §h.5: barrido tombstones-vs-vivas — 40 vivas, verifyRebinds==1, idempotente, sin side-effects, anti-eco")
    func sweepZombies_goldenH5() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        // 50 TX post-cutover con syncID acuñado (sin CKRecord — irrelevante in-memory).
        var syncIDs: [UUID] = []
        for i in 0..<50 {
            let tx = TransactionItem(date: fixedNow, amount: Double(i), currencyCode: "USD")
            tx.syncID = UUID()
            syncIDs.append(tx.syncID!)
            context.insert(tx)
        }
        try context.save()

        // Baseline: drenar los 50 inserts al outbox (autor por DEFECTO) → token avanza.
        engine.drainOnce(context: context)
        let baselineOutbox = try context.fetchCount(FetchDescriptor<SyncOutbox>())
        #expect(baselineOutbox > 0, "los inserts se emitieron al outbox como baseline")

        // 1 testigo SyncIdentity rebound (lastReboundAt) apuntando a una TX que SOBREVIVE (no está entre 0..<10).
        let reboundSyncID = syncIDs[49]
        context.insert(SyncIdentity(syncID: reboundSyncID, entityType: SyncEntityType.transactionItem,
                                    localAnchor: "anchor", lastReboundAt: fixedNow))
        try context.save()

        // Fuente: 10 tombstones (syncIDs 0..<10) + 1 tombstone de syncID INEXISTENTE (no-op).
        var deltas = (0..<10).map { tombstone(table: "tx_items", syncID: syncIDs[$0], seq: Int64($0 + 1)) }
        deltas.append(tombstone(table: "tx_items", syncID: UUID(), seq: 999))
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: deltas, maxServerSeq: 999)]

        let executor = makeExecutor(context, engine, RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        // Testigos ANTES del sweep (para asserts de no-side-effects).
        let cursorBefore = try context.fetch(FetchDescriptor<SyncCursor>()).first?.serverSeqCursor ?? 0
        let witnessesBefore = try context.fetchCount(FetchDescriptor<SyncIdentity>())

        // SWEEP.
        #expect(await executor.sweepZombies(sinceSeq: 0) == .completed(deleted: 10),
                "10 filas vivas tombstoneadas borradas (el syncID inexistente es no-op)")
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 40, "quedan 40 vivas")
        #expect(executor.verifyRebinds() == 1, "la fila rebound sigue viva portando su syncID")

        // El sweep NO avanza SyncCursor NI borra testigos SyncIdentity (enumeración read-only salvo deletes).
        let cursorAfter = try context.fetch(FetchDescriptor<SyncCursor>()).first?.serverSeqCursor ?? 0
        #expect(cursorAfter == cursorBefore, "el sweep NO avanza SyncCursor")
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == witnessesBefore, "el sweep NO borra testigos")

        // Idempotencia: re-sweep con la misma página → 0 deletes (ya no hay filas vivas que casen).
        let source2 = FakeTombstoneSource()
        source2.pages = [PulledPage(deltas: deltas, maxServerSeq: 999)]
        let executor2 = makeExecutor(context, engine, RoutingStub(), session, FakeBeaconStore(),
                                     personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                     tombstoneSource: source2)
        #expect(await executor2.sweepZombies(sinceSeq: 0) == .completed(deleted: 0), "re-sweep idempotente")

        // ANTI-ECO: los deletes van bajo outboxSaveAuthor → un drainOnce posterior NO los re-emite al outbox.
        engine.drainOnce(context: context)
        #expect(try context.fetchCount(FetchDescriptor<SyncOutbox>()) == baselineOutbox,
                "los deletes del sweep NO se re-emiten al outbox (anti-eco)")
    }

    @Test("sweepZombies: red del pull → transient (sin mutación)")
    func sweepZombies_networkTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let tx = TransactionItem(date: fixedNow, amount: 1, currencyCode: "USD")
        tx.syncID = UUID()
        context.insert(tx)
        try context.save()

        let source = FakeTombstoneSource()
        source.forced = .transient
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)
        #expect(await executor.sweepZombies(sinceSeq: 0) == .transient)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 1, "red → sin borrar nada")
    }

    @Test("execute(.mountMirrorAndRelaunch): DESARMA el flag mirror-off (el proceso NO se mata solo)")
    func execute_mountMirror_disarmsFlag() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = makeIsolatedDefaults(prefix: "mwe.mount")
        defaults.set(true, forKey: MigrationWorkExecutor.relaunchRequestedKey)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.mountMirrorAndRelaunch)
        #expect(defaults.bool(forKey: MigrationWorkExecutor.relaunchRequestedKey) == false)
    }

    @Test("execute(.persistICloudMode): storageMode=.icloud + mirrorOffArmed=false JUNTOS (invariante SERIO 1)")
    func execute_persistICloudMode_pair() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = makeIsolatedDefaults(prefix: "mwe.icloud")
        StorageModePersistence.write(.cloud, defaults: defaults)
        defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.persistICloudMode)
        #expect(StorageModePersistence.read(defaults) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults) == false)
    }

    @Test("execute(.clearCloudBeacon): remueve las 4 keys del faro (simétrico a write)")
    func execute_clearBeacon_removesKeys() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let beaconStore = FakeBeaconStore()
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, beaconStore,
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await executor.execute(.writeBeacon)
        #expect(beaconStore.bool(forKey: CloudBeacon.Keys.linked))
        try await executor.execute(.clearCloudBeacon)
        #expect(beaconStore.bool(forKey: CloudBeacon.Keys.linked) == false)
        #expect(beaconStore.string(forKey: CloudBeacon.Keys.provider) == nil)
        #expect(beaconStore.string(forKey: CloudBeacon.Keys.accountHash) == nil)
        #expect(beaconStore.double(forKey: CloudBeacon.Keys.linkedAt) == 0)
    }

    @Test("execute(.deleteCloudKitMarker): borra los marcadores (idempotente)")
    func execute_deleteMarker_idempotent() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await executor.execute(.writeCloudKitMarker)
        #expect(try context.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 1)
        try await executor.execute(.deleteCloudKitMarker)
        #expect(try context.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 0)
        try await executor.execute(.deleteCloudKitMarker)   // idempotente (0 marcadores)
        #expect(try context.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 0)
    }

    // MARK: - Reversa server-side (I11-3): las 4 acciones `reverse_*`. LECCIÓN d49d2e47: cada acción
    // asserta el BODY enviado (device_id + action exactos) — el gap del bug del claim era exactamente un
    // test faltante del body.

    @Test("performReverseClaim: ok → accepted + BODY {device_id, action:'reverse_claim'} exacto")
    func reverseClaim_ok_sendsExactBody() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.performReverseClaim() == .accepted)
        #expect(stub.lastMigrationBody?["device_id"] as? String == "device-1")
        #expect(stub.lastMigrationBody?["action"] as? String == "reverse_claim")
    }

    @Test("performReverseClaim: mapeo de outcomes — other_leader/rejected/500/sin-JWT")
    func reverseClaim_outcomeMapping() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        #expect(await executor.performReverseClaim() == .otherLeader)

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"not_migrated\"}".utf8)
        #expect(await executor.performReverseClaim() == .rejected(reason: "not_migrated"))

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"migration_in_progress\"}".utf8)
        #expect(await executor.performReverseClaim() == .rejected(reason: "migration_in_progress"))

        stub.migrationStatus = 500
        #expect(await executor.performReverseClaim() == .transient)

        session.token = nil
        #expect(await executor.performReverseClaim() == .sessionExpired, "sin JWT → sessionExpired SIN tocar la red")
    }

    @Test("freezeBackendForReverse: ok → true + BODY {device_id, action:'reverse_freeze'}; rechazo/red/sin-JWT → false")
    func reverseFreeze_bodyAndOutcomes() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.freezeBackendForReverse() == true)
        #expect(stub.lastMigrationBody?["device_id"] as? String == "device-1")
        #expect(stub.lastMigrationBody?["action"] as? String == "reverse_freeze")

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        #expect(await executor.freezeBackendForReverse() == false)

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"not_in_progress\"}".utf8)
        #expect(await executor.freezeBackendForReverse() == false)

        stub.migrationStatus = 500
        #expect(await executor.freezeBackendForReverse() == false)

        session.token = nil
        #expect(await executor.freezeBackendForReverse() == false)
    }

    @Test("execute(.completeReverseServer): ok → no throw + BODY {device_id, action:'reverse_complete'}; rechazo → throw retomable")
    func reverseComplete_bodyAndThrows() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await executor.execute(.completeReverseServer)
        #expect(stub.lastMigrationBody?["device_id"] as? String == "device-1")
        #expect(stub.lastMigrationBody?["action"] as? String == "reverse_complete")

        // Rechazo (not_in_progress) → THROW: queda journaled-pendiente retomable (patrón de la ida).
        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"not_in_progress\"}".utf8)
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.completeReverseServer)
        }
        // Red caída → THROW retomable.
        stub.migrationStatus = 500
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.completeReverseServer)
        }
    }

    @Test("execute(.reverseRollback): ok → no throw + BODY {device_id, action:'reverse_abort'}; rejected/other_leader NO throwean (perpetuo); red sí")
    func reverseRollback_bodyAndNoPerpetualThrow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await executor.execute(.reverseRollback)
        #expect(stub.lastMigrationBody?["device_id"] as? String == "device-1")
        #expect(stub.lastMigrationBody?["action"] as? String == "reverse_abort")

        // Decisión I11-3: un abort RECHAZADO (lease usurpado / rejected) COMPLETA el efecto (no throw) —
        // el estado local ya es terminal estable; re-lanzar perpetuo repetiría el bug-class del rollback
        // de la ida (device 2026-07-10). Breadcrumb RUIDOSO delata el caso.
        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        try await executor.execute(.reverseRollback)

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"no_profile\"}".utf8)
        try await executor.execute(.reverseRollback)

        // Red caída / sin JWT → THROW retomable (la red/el re-login lo despiertan).
        stub.migrationStatus = 500
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.reverseRollback)
        }
        session.token = nil
        stub.migrationStatus = 200
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.reverseRollback)
        }
    }

    @Test("reverseUploadStatus: store vacío → drained (0 pares, sin cambios que persistir)")
    func reverseUploadStatus_empty_drained() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(executor.reverseUploadStatus() == .drained)
    }

    @Test("healDuplicates: AUTO-CURA (I11-4) — fusiona copias idénticas de Account y devuelve nº de perdedores")
    func healDuplicates_mergesDuplicates() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        // 2 cuentas idénticas por contenido (shortcutID distinto) → 1 grupo duplicado → 1 perdedor curado.
        context.insert(Account(name: "Cash", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash"))
        context.insert(Account(name: "Cash", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash"))
        try context.save()
        #expect(executor.healDuplicates() == 1)
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 1, "el perdedor fue borrado (cura, no solo detección)")
        #expect(executor.healDuplicates() == 0, "idempotente: 2ª pasada no cura nada")
    }

    // MARK: - ReverseEligibility (guardarraíl §h.6-A1, obligación 1 del review)

    @Test("ReverseEligibility: notCloudMode / reverseAlreadyTerminal / degradedNoMap / eligible")
    func reverseEligibility_decisions() {
        #expect(ReverseEligibility.decide(storageMode: .icloud, hasCKMap: true, journaledPhase: .done) == .notCloudMode)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: true, journaledPhase: .icloudActive) == .reverseAlreadyTerminal)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: true, journaledPhase: .reverseFailedRollback) == .reverseAlreadyTerminal)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: false, journaledPhase: .done) == .degradedNoMap)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: true, journaledPhase: .done) == .eligible)
    }

    // MARK: - Heartbeat del lease (I14-pre, residual pendiente #3)

    @Test("sendLeaseHeartbeatIfDue: BODY exacto {device_id:'device-1', action:'heartbeat'} (lección d49d2e47)")
    func heartbeat_sendsExactBody() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 1)
        #expect(stub.lastMigrationBody?["device_id"] as? String == "device-1")
        #expect(stub.lastMigrationBody?["action"] as? String == "heartbeat")
    }

    @Test("sendLeaseHeartbeatIfDue: throttle — 2 ticks dentro de la ventana → 1 request; pasada la ventana → 2")
    func heartbeat_throttlesWithinWindow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let clock = MutableClock(fixedNow)
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    now: { clock.value }, heartbeatInterval: 60)
        await executor.sendLeaseHeartbeatIfDue()               // t=0 → emite
        #expect(stub.migrationCallCount == 1)
        clock.value = fixedNow.addingTimeInterval(10)          // +10s: dentro de la ventana
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 1, "throttled: 10s < 60s")
        clock.value = fixedNow.addingTimeInterval(70)          // +70s: pasada la ventana
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 2, "pasada la ventana → 2º heartbeat")
    }

    @Test("sendLeaseHeartbeatIfDue: best-effort — rechazo (other_leader) y red (500) NO lanzan y ARMAN el throttle")
    func heartbeat_bestEffort_armsThrottleOnReject() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        let clock = MutableClock(fixedNow)
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    now: { clock.value }, heartbeatInterval: 60)
        // La firma NO lanza (best-effort garantizado por el compilador). El rechazo arma el throttle igual.
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 1)
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 1, "other_leader armó el throttle → 2º tick inmediato no re-pega")
        // Red caída (500) pasada la ventana: tampoco lanza y también arma el throttle.
        clock.value = fixedNow.addingTimeInterval(70)
        stub.migrationStatus = 500
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 2)
        clock.value = fixedNow.addingTimeInterval(80)
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 2, "el 500 también armó el throttle")
    }

    @Test("sendLeaseHeartbeatIfDue: sin JWT → 0 requests (no arma throttle; el paso reporta sessionExpired por su camino)")
    func heartbeat_noJWT_noRequest() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: nil, userID: nil)
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        await executor.sendLeaseHeartbeatIfDue()
        #expect(stub.migrationCallCount == 0)
    }

    // MARK: - Adopt-reconcile (DIFERIDOS #30, mecanismo v1 DARK)

    /// Helper: crea una categoría con un syncID PRE-asignado (fila con identidad estable ya presente).
    private func makeCategory(_ name: String, syncID: UUID, in context: ModelContext) -> Yala.Category {
        let cat = Yala.Category(name: name, colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = syncID
        context.insert(cat)
        return cat
    }

    /// Body `RemoteMerkle` mínimo con los counts de VIVAS por tabla — COHERENTE con las páginas del fake
    /// (SERIO 1: el reconcile verifica positivamente la completitud de la enumeración contra estos counts).
    private func makeMerkleBody(_ counts: [String: Int]) throws -> Data {
        var entities: [String: Any] = [:]
        for (table, count) in counts { entities[table] = ["count": count, "hash": "h"] }
        return try JSONSerialization.data(withJSONObject: [
            "canon_version": "c1", "capability_set": "v1", "root": "r", "entities": entities,
        ])
    }

    @Test("runAdoptOrphanReconcile: sube EXACTAMENTE la huérfana (∉ backend) fila-COMPLETA; conocida y tombstone NO se suben")
    func adoptReconcile_uploadsOnlyOrphanFullRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        let knownID = UUID(); let tombID = UUID(); let orphanID = UUID()
        _ = makeCategory("known", syncID: knownID, in: context)     // ∈ backend (upsert) → NO huérfana
        _ = makeCategory("tomb", syncID: tombID, in: context)       // ∈ backend (tombstone) → zombie, NO huérfana
        _ = makeCategory("orphan-of-window", syncID: orphanID, in: context)  // ∉ backend → huérfana
        try context.save()

        // Backend enumerado: upsert de knownID + tombstone de tombID (mezcla upsert+tombstone). Merkle
        // COHERENTE: 1 viva en categories (el tombstone no cuenta).
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [
            upsertDelta(table: "categories", syncID: knownID, seq: 1),
            tombstone(table: "categories", syncID: tombID, seq: 2),
        ], maxServerSeq: 2)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])

        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        let outcome = await executor.runAdoptOrphanReconcile()
        #expect(outcome == .completed(uploaded: 1, identityAssigned: 0))

        // EXACTAMENTE la huérfana subida (lección d49d2e47).
        #expect(stub.pushedSyncIDs.map { $0.lowercased() } == [orphanID.uuidString.lowercased()])
        #expect(!stub.pushedSyncIDs.map { $0.lowercased() }.contains(knownID.uuidString.lowercased()),
                "la conocida NO se sube")
        #expect(!stub.pushedSyncIDs.map { $0.lowercased() }.contains(tombID.uuidString.lowercased()),
                "la tombstoneada NO se sube (zombie del apply)")

        // Fila COMPLETA: el delta lleva `fields` poblados (no solo identidad).
        let delta = try #require(stub.lastPushedDeltas.first { ($0["sync_id"] as? String)?.lowercased() == orphanID.uuidString.lowercased() })
        let fields = try #require(delta["fields"] as? [String: Any])
        #expect(!fields.isEmpty, "fila full-row: fields poblados, no solo la identidad")
        #expect(delta["entity_type"] as? String == "categories")

        // El outbox vivo quedó limpio (rescate confirmado).
        let live = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(live.isEmpty)
    }

    @Test("runAdoptOrphanReconcile: fila nil-identity → backfill acuña syncID + testigo y viaja full-row")
    func adoptReconcile_nilIdentity_backfilledAndUploaded() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        // Categoría SIN identidad (sintética; syncID nil por default).
        let cat = Category(name: "window-nil", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        #expect(cat.syncID == nil)
        context.insert(cat)
        try context.save()

        // Backend NO vacío (para pasar el guard anti mass-upload) pero SIN la fila local. Merkle coherente.
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])

        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        let outcome = await executor.runAdoptOrphanReconcile()
        #expect(outcome == .completed(uploaded: 1, identityAssigned: 1))

        // El backfill acuñó el syncID + su fila testigo.
        let freshID = try #require(cat.syncID, "el backfill debe acuñar el syncID de la fila sin identidad")
        let witnesses = try context.fetch(FetchDescriptor<SyncIdentity>())
        #expect(witnesses.contains { $0.syncID == freshID }, "debe existir la fila testigo SyncIdentity")

        // La fila viajó COMPLETA con su syncID fresco.
        #expect(stub.pushedSyncIDs.map { $0.lowercased() } == [freshID.uuidString.lowercased()])
        let delta = try #require(stub.lastPushedDeltas.first)
        let fields = try #require(delta["fields"] as? [String: Any])
        #expect(!fields.isEmpty, "fila full-row (fieldsJSON poblado)")
    }

    @Test("runAdoptOrphanReconcile: red en el PULL (enumeración) → transient SIN mutación (backfill no corre)")
    func adoptReconcile_pullTransient_noMutation() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        let cat = Category(name: "orphan", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let source = FakeTombstoneSource()
        source.forced = .transient
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        #expect(await executor.runAdoptOrphanReconcile() == .transient)
        #expect(stub.pushedSyncIDs.isEmpty, "red en la enumeración → nada se sube")
        // El backfill NO corrió (la enumeración es el paso 1): sin testigos SyncIdentity.
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0)
    }

    @Test("runAdoptOrphanReconcile: red en el PUSH → transient; re-run completa (idempotencia kill-resume)")
    func adoptReconcile_pushTransient_thenResumes() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        let orphanID = UUID()
        _ = makeCategory("orphan", syncID: orphanID, in: context)
        try context.save()

        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])
        stub.pushStatus = 503   // red en el push
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)
        #expect(await executor.runAdoptOrphanReconcile() == .transient)
        // El residual sigue VIVO (nada perdido) → el resume re-diffea.
        let liveAfterFail = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(!liveAfterFail.isEmpty)

        // Re-run con la red arriba → completa y limpia el outbox (LWW absorbe la re-emisión H5).
        stub.pushStatus = 200
        let source2 = FakeTombstoneSource()
        source2.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        let executor2 = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                     personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                     tombstoneSource: source2)
        guard case .completed = await executor2.runAdoptOrphanReconcile() else {
            Issue.record("el re-run debía completar"); return
        }
        #expect(stub.pushedSyncIDs.map { $0.lowercased() }.contains(orphanID.uuidString.lowercased()))
        let liveAfterResume = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(liveAfterResume.isEmpty, "tras el resume el outbox vivo queda limpio")
    }

    @Test("runAdoptOrphanReconcile: 2ª pasada (huérfana ya en backend) → completed(0,0) no-op")
    func adoptReconcile_secondPass_noop() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        let orphanID = UUID()
        _ = makeCategory("orphan", syncID: orphanID, in: context)
        try context.save()

        // 1ª pasada: la huérfana NO está en el backend → se sube.
        let source1 = FakeTombstoneSource()
        source1.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])
        let executor1 = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                     personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                     tombstoneSource: source1)
        #expect(await executor1.runAdoptOrphanReconcile() == .completed(uploaded: 1, identityAssigned: 0))

        // 2ª pasada: ahora el backend YA conoce la ex-huérfana → diff vacío → no-op.
        let stub2 = RoutingStub()
        let source2 = FakeTombstoneSource()
        source2.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: orphanID, seq: 5)], maxServerSeq: 5)]
        stub2.merkleBody = try makeMerkleBody(["categories": 1])
        let executor2 = makeExecutor(context, engine, stub2, session, FakeBeaconStore(),
                                     personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                     tombstoneSource: source2)
        #expect(await executor2.runAdoptOrphanReconcile() == .completed(uploaded: 0, identityAssigned: 0))
        #expect(stub2.pushedSyncIDs.isEmpty, "no-op: nada que subir")
    }

    @Test("runAdoptOrphanReconcile: guard anti mass-upload — backend enumerado VACÍO + huérfanas → abortedEmptyBackend, SIN NINGUNA mutación")
    func adoptReconcile_emptyBackend_aborts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        _ = makeCategory("orphan", syncID: UUID(), in: context)
        try context.save()

        // Enumeración VACÍA (página vacía inmediata) + merkle en 0s COHERENTE (un backend realmente vacío
        // pasa la completitud pero sigue abortando A PROPÓSITO — decisión de producto de I14).
        let source = FakeTombstoneSource()
        stub.merkleBody = try makeMerkleBody([:])
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)
        #expect(await executor.runAdoptOrphanReconcile() == .abortedEmptyBackend)
        #expect(stub.pushedSyncIDs.isEmpty, "guard: NO se sube el corpus entero")
        let live = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(live.isEmpty, "el guard corta ANTES del enqueue")
        // MENOR 2 del review: el guard corre ANTES del backfill → CERO mutación (ni testigos SyncIdentity).
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0,
                "abortedEmptyBackend sin backfill: sin testigos")
    }

    @Test("runAdoptOrphanReconcile: merkle declara MÁS vivas que lo enumerado → transient (enumeración incompleta) SIN mutación")
    func adoptReconcile_incompleteEnumeration_transient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        _ = makeCategory("orphan", syncID: UUID(), in: context)
        let nilCat = Yala.Category(name: "window-nil", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        context.insert(nilCat)
        try context.save()

        // La enumeración ve 1 viva pero el merkle declara 2 → página vacía prematura simulada: subir el diff
        // pisaría con HLC fresco contenido más nuevo del backend → transient retomable (SERIO 1).
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 2])
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        #expect(await executor.runAdoptOrphanReconcile() == .transient)
        #expect(stub.pushedSyncIDs.isEmpty, "enumeración incompleta → NADA se sube")
        // Sin mutación: ni backfill (testigos) ni enqueue (outbox).
        #expect(nilCat.syncID == nil, "el backfill NO corre con enumeración incompleta")
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SyncOutbox>()) == 0)
    }

    @Test("runAdoptOrphanReconcile: fetchMerkle no-snapshot (body indecodificable) → transient SIN mutación")
    func adoptReconcile_merkleTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()   // merkleBody default = Data() → decode falla → .transient
        let session = FakeSession(token: "jwt", userID: "sub-1")

        _ = makeCategory("orphan", syncID: UUID(), in: context)
        try context.save()

        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        #expect(await executor.runAdoptOrphanReconcile() == .transient)
        #expect(stub.pushedSyncIDs.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0, "sin merkle no hay mutación")
        #expect(try context.fetchCount(FetchDescriptor<SyncOutbox>()) == 0)
    }

    @Test("adoptOrphanDryRun: read-only por el MISMO camino verificado — diff sin mutar; merkle incompleto → nil")
    func adoptDryRun_readOnly() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")

        let orphanID = UUID()
        _ = makeCategory("orphan", syncID: orphanID, in: context)
        let nilCat = Category(name: "window-nil", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        context.insert(nilCat)
        try context.save()

        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])   // camino VERIFICADO (SERIO 1)
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    tombstoneSource: source)

        let plan = try #require(await executor.adoptOrphanDryRun())
        #expect(plan.orphans["categories"] == [orphanID])   // solo la que tiene identidad ∉ backend
        #expect(plan.needsIdentity["categories"] == 1)       // la nil (sin backfill se ve como needsIdentity)
        // READ-ONLY: NO acuñó identidad ni testigos.
        #expect(nilCat.syncID == nil, "el dry-run NO hace backfill")
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0)
        #expect(stub.pushedSyncIDs.isEmpty)

        // El dry-run usa el MISMO guard de completitud: merkle > enumerado → nil (sin plan).
        let stub2 = RoutingStub()
        stub2.merkleBody = try makeMerkleBody(["categories": 3])
        let source2 = FakeTombstoneSource()
        source2.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
        let executor2 = makeExecutor(context, CloudSyncEngine(), stub2, session, FakeBeaconStore(),
                                     personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                     tombstoneSource: source2)
        #expect(await executor2.adoptOrphanDryRun() == nil, "enumeración incompleta → el dry-run devuelve nil")
    }

    @Test("execute(.adoptBackendAccount): SIGUE notWired (el flujo de adopt completo es I14)")
    func adoptBackendAccount_stillNotWired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.adoptBackendAccount)
        }
    }
}
