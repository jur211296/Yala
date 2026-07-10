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

/// Enruta por path: claim / push (ecoa applied) / pull (página vacía) / merkle (body configurable).
private final class RoutingStub: SyncHTTPSession, @unchecked Sendable {
    var claimBody = Data("{\"state\":\"created\"}".utf8)
    var claimStatus = 200
    private(set) var lastClaimBody: [String: Any]?
    var migrationBody = Data("{\"ok\":true}".utf8)
    var migrationStatus = 200
    var pushStatus = 200
    var merkleBody = Data()
    private let lock = NSLock()
    private(set) var pushedSyncIDs: [String] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url?.path ?? ""
        func resp(_ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
        if path.contains("account/migration") {
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
            calendar: Calendar(identifier: .gregorian), now: { self.fixedNow },
            deviceID: "device-1", beacon: CloudBeacon(store: beaconStore),
            personalStoreURL: personalStoreURL,
            storageDefaults: storageDefaults ?? makeIsolatedDefaults(prefix: "mwe.storage"),
            snapshotPageSize: 200, reverseTombstoneSource: tombstoneSource)
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

    @Test("performReverseClaim/freezeBackendForReverse: notWired hoy (I11-3) → transient/false")
    func reverseServerStubs_notWired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.performReverseClaim() == .transient)
        #expect(await executor.freezeBackendForReverse() == false)
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

    @Test("healDuplicates: DETECCIÓN read-only de copias idénticas de Account (I11-2; auto-cura en I11-4)")
    func healDuplicates_detectsDuplicates() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        // 2 cuentas idénticas por contenido (shortcutID distinto) → 1 grupo duplicado.
        context.insert(Account(name: "Cash", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash"))
        context.insert(Account(name: "Cash", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash"))
        try context.save()
        #expect(executor.healDuplicates() == 1)
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
}
