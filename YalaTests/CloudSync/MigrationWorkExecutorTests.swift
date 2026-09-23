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
//  C-1 (última sección): las 3 señales REALES que alimentan `probeICloudChannel()` (cuenta iCloud, huella
//  CloudKit del corpus, último `CKError` del mirror) y el par (`storageMode`, mirror-off armado) visto con
//  `isCloudWithMirrorOn` en los 3 caminos que lo escriben.
//

import CloudKit
import Foundation
import SQLite3
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
    /// Lo que hoy separa «sin red» de «vuelve a entrar» en los pasos de la reversa que piden el token a mano
    /// (ticket `reverse-before-mount-stays-stuck-with-an-expired-session`). **Sin override el default deriva del
    /// token**, que es el trato de antes de ese ticket: sin token no se puede renovar ⇒ sesión caducada. Ponerlo a
    /// `true` con `token = nil` es el caso nuevo: la renovación no volvió, pero la sesión sigue guardada.
    var canRenewSessionOverride: Bool?
    var canRenewSession: Bool { canRenewSessionOverride ?? (token != nil) }
    func attestToken() async throws -> String? { nil }
}

/// El SDK BORRA la sesión dentro de la renovación, antes de devolver `nil`: el testigo solo dice la verdad leído DESPUÉS
/// de pedir el token. Con el `FakeSession` de arriba, leerlo antes o después da lo mismo y un mutante que lo adelanta
/// sobrevive (lo cazó una lente de la review de `forward-migration-steps-have-no-ceiling-and-no-exit`).
@MainActor
private final class SessionRemovedWhileFetching: CloudSyncSessionProviding {
    private var saved = true
    var currentUserID: String? { "sub-1" }
    func accessToken() async -> String? { saved = false; return nil }
    var canRenewSession: Bool { saved }
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
    /// Se llama cuando el POST del claim LLEGA al stub, antes de la respuesta: es el instante de una respuesta perdida, y lo
    /// que la marca del claim tiene que haber dejado escrito ya.
    var onClaimRequest: (() -> Void)?
    var migrationBody = Data("{\"ok\":true}".utf8)
    var migrationStatus = 200
    private(set) var lastMigrationBody: [String: Any]?
    private(set) var migrationCallCount = 0
    var pushStatus = 200
    /// 401 aquí = sesión caducada del pull, que es la mitad que `reverseDrainOnce` y `verify` no podían separar
    /// hasta el ticket `reverse-before-mount-stays-stuck-with-an-expired-session`.
    var pullStatus = 200
    var merkleBody = Data()
    /// Status de `/sync/merkle`. 401 y 403 son la mitad que el Merkle NO podía separar hasta el ticket
    /// `reverse-verify-network-bucket-hides-a-definitive-server-no`: `SyncMerkle` aplanaba los tres desenlaces del
    /// fetch y salían como red.
    var merkleStatus = 200
    /// Cuerpo de la respuesta cuando `merkleStatus != 200` — el envelope del gateway separa los dos 401.
    var merkleErrorBody = Data()
    private let lock = NSLock()
    private(set) var pushedSyncIDs: [String] = []
    /// Cuántas veces se pidió cada paso. Lo que prueba que un desenlace CORTÓ la pasada no es su valor —un
    /// `.blocked` puede salir de cualquiera de los tres— sino que los pasos posteriores no llegaron a pedirse.
    private(set) var pullCallCount = 0
    private(set) var merkleCallCount = 0
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
            onClaimRequest?()
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
            pullCallCount += 1
            if pullStatus != 200 { return (Data(), resp(pullStatus)) }
            return (Data("{\"deltas\":[],\"max_server_seq\":0}".utf8), resp(200))
        }
        if path.contains("sync/merkle") {
            merkleCallCount += 1
            if merkleStatus != 200 { return (merkleErrorBody, resp(merkleStatus)) }
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
        _ session: CloudSyncSessionProviding, _ beaconStore: FakeBeaconStore, personalStoreURL: URL,
        storageDefaults: UserDefaults? = nil,
        now: (() -> Date)? = nil,
        heartbeatInterval: TimeInterval = 60,
        tombstoneSource: ReverseTombstoneSource? = nil,
        adoptQuiescenceSignal: @escaping () -> Bool = { true },
        claimStore: CloudClaimActionStore? = nil,
        provider: @escaping @MainActor () -> String = { "apple" },
        icloudAccountPresent: (@MainActor () -> Bool)? = nil,
        icloudLastExportErrorCode: (@MainActor () -> CKError.Code?)? = nil,
        icloudMirrorReportedNotAuthenticated: (@MainActor () -> Bool)? = nil,
        icloudLastExportErrorAt: (@MainActor () -> Date?)? = nil,
        icloudLastSuccessfulExportAt: (@MainActor () -> Date?)? = nil
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
            deviceID: "device-1", provider: provider, beacon: CloudBeacon(store: beaconStore),
            personalStoreURL: personalStoreURL,
            storageDefaults: storageDefaults ?? makeIsolatedDefaults(prefix: "mwe.storage"),
            snapshotPageSize: 200, heartbeatInterval: heartbeatInterval,
            reverseTombstoneSource: tombstoneSource,
            adoptQuiescenceSignal: adoptQuiescenceSignal,
            claimStore: claimStore,
            icloudAccountPresent: icloudAccountPresent,
            icloudLastExportErrorCode: icloudLastExportErrorCode,
            icloudMirrorReportedNotAuthenticated: icloudMirrorReportedNotAuthenticated,
            icloudLastExportErrorAt: icloudLastExportErrorAt,
            icloudLastSuccessfulExportAt: icloudLastSuccessfulExportAt)
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

    @Test("performClaim con provider 'google': el BODY del claim lleva provider=google (sesión 1 Google Sign-In)")
    func claim_providerGoogle_sendsGoogleInBody() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    provider: { "google" })
        _ = await executor.performClaim()
        #expect(stub.lastClaimBody?["provider"] as? String == "google",
                "el provider REAL de la sesión debe llegar al BODY del claim (lección d49d2e47)")
    }

    @Test("performClaim lee el provider VIVO al momento del claim, no el de la construcción (I4 sesión 3: runner nacido pre-sign-in)")
    func claim_providerIsReadLive_notFrozenAtInit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        // El executor nace ANTES del sign-in (provider aún "apple" — el fallback de key perdida).
        var currentProvider = "apple"
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    provider: { currentProvider })
        // Sign-in con Google DESPUÉS de construir el executor (el caso real del residual I4).
        currentProvider = "google"
        _ = await executor.performClaim()
        #expect(stub.lastClaimBody?["provider"] as? String == "google",
                "el BODY del claim debe reflejar el provider VIGENTE al claimear, no el congelado en init")
    }

    @Test("execute(.writeBeacon) lee el provider VIVO (ajuste A1: el faro con provider stale rompería la red R9)")
    func writeBeacon_providerIsReadLive_notFrozenAtInit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let beaconStore = FakeBeaconStore()
        var currentProvider = "apple"
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, beaconStore,
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    provider: { currentProvider })
        currentProvider = "google"
        try await executor.execute(.writeBeacon)
        #expect(beaconStore.string(forKey: CloudBeacon.Keys.provider) == "google",
                "el faro debe estampar el provider VIGENTE (un faro 'apple' para cuenta Google haría que R9 mostrara el método equivocado)")
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

    /// El reparto del no del servidor para el techo de `cutover(.pending)` (ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`): hasta ese ticket todo era un `false`, y sin separarlo no
    /// había techo corto posible. `other_leader` y un `rejected` son definitivos; la red espera.
    @Test("confirmCutoverServer: ok → confirmed · other_leader → otherDevice · rejected → refused · 5xx → transient")
    func confirmCutoverServer_classifiesTheServerAnswer() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.confirmCutoverServer() == .confirmed)

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        #expect(await executor.confirmCutoverServer() == .blocked(.otherDevice))

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"not_in_progress\"}".utf8)
        #expect(await executor.confirmCutoverServer() == .blocked(.refused))

        stub.migrationStatus = 503
        #expect(await executor.confirmCutoverServer() == .transient)
    }

    /// Sin JWT, o con un 401: definitivo SOLO con la sesión borrada por el SDK. Con la sesión guardada —el token que no se
    /// renueva sin red, el reloj atrasado— espera el plazo largo, que es la regla de la familia.
    @Test("confirmCutoverServer: sin JWT o 401 → sessionExpired solo con la sesión borrada")
    func confirmCutoverServer_sessionExpired_onlyWithTheSessionGone() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gone = FakeSession(token: nil, userID: nil)
        let executorGone = makeExecutor(context, CloudSyncEngine(), RoutingStub(), gone, FakeBeaconStore(),
                                        personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executorGone.confirmCutoverServer() == .blocked(.sessionExpired))

        let kept = FakeSession(token: nil, userID: "sub-1")
        kept.canRenewSessionOverride = true
        let executorKept = makeExecutor(context, CloudSyncEngine(), RoutingStub(), kept, FakeBeaconStore(),
                                        personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executorKept.confirmCutoverServer() == .transient, "token nulo con la sesión guardada")

        let stub401 = RoutingStub()
        stub401.migrationStatus = 401
        let withToken = FakeSession(token: "jwt", userID: "sub-1")
        let executor401 = makeExecutor(context, CloudSyncEngine(), stub401, withToken, FakeBeaconStore(),
                                       personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor401.confirmCutoverServer() == .transient, "401 con la sesión guardada")
        withToken.canRenewSessionOverride = false
        #expect(await executor401.confirmCutoverServer() == .blocked(.sessionExpired), "401 con la sesión borrada")

        // El SDK borra la sesión DENTRO de la renovación: leído antes de pedir el token, el testigo diría «guardada».
        let removed = SessionRemovedWhileFetching()
        let executorRemoved = makeExecutor(context, CloudSyncEngine(), RoutingStub(), removed, FakeBeaconStore(),
                                           personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executorRemoved.confirmCutoverServer() == .blocked(.sessionExpired),
                "el testigo se lee DESPUÉS de pedir el token")
    }

    /// La marca del claim sin respuesta: se escribe ANTES del POST —el stub la mira en el instante en que le llega la
    /// petición, que es cuando se pierde una respuesta— y se borra con cualquier respuesta. Sin ella, un claim que crea la
    /// cuenta y pierde la respuesta deja la cuenta `complete` sin sello, y tras el techo o «Cancelar» al 22 % la puerta de
    /// «Migrar» la tomaba por una cuenta con datos ajenos.
    @Test("performClaim de «Migrar»: la marca está puesta al llegar el POST, sobrevive sin respuesta y se borra con cualquiera")
    func performClaim_attemptMark_survivesALostAnswer_andClearsWithAnyAnswer() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-mark")
        let stub = RoutingStub()
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.attempt"))
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        var markedWhenThePostArrived: Bool?
        stub.onClaimRequest = { markedWhenThePostArrived = claimStore.hasMigrationClaimAttempt(forUserID: "sub-mark") }

        stub.claimStatus = 503
        guard case .transient = await executor.performClaim(marksMigrationAttempt: true) else {
            Issue.record("control del escenario: un 503 es `.transient`")
            return
        }
        #expect(markedWhenThePostArrived == true, "la marca va ANTES del POST: un kill con la petición en vuelo la conserva")
        #expect(claimStore.hasMigrationClaimAttempt(forUserID: "sub-mark"), "sin respuesta no se sabe: la marca se queda")
        #expect(claimStore.action(forUserID: "sub-mark") == nil, "control: el sello solo llega con la respuesta")

        for body in ["{\"state\":\"existing_stable\"}", "{\"state\":\"claiming_in_progress\"}",
                     "{\"state\":\"created\"}"] {
            claimStore.recordMigrationClaimAttempt(forUserID: "sub-mark")
            stub.claimStatus = 200
            stub.claimBody = Data(body.utf8)
            _ = await executor.performClaim(marksMigrationAttempt: true)
            #expect(!claimStore.hasMigrationClaimAttempt(forUserID: "sub-mark"), "con respuesta la marca sobra: \(body)")
        }
    }

    /// Un claim que no es de «Migrar» (adopt, seguidor) no marca: la marca abre la puerta de «Migrar», y la de un adopt la
    /// abriría a un teléfono que nunca lo pidió. Pero su respuesta SÍ borra una marca anterior de la misma cuenta.
    @Test("performClaim de un adopt: no marca, y su respuesta borra una marca anterior")
    func performClaim_notMigrate_doesNotMark_butItsAnswerClears() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-adopt-mark")
        let stub = RoutingStub()
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.adopt.mark"))
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        stub.claimStatus = 503
        _ = await executor.performClaim(marksMigrationAttempt: false)
        #expect(!claimStore.hasMigrationClaimAttempt(forUserID: "sub-adopt-mark"))

        claimStore.recordMigrationClaimAttempt(forUserID: "sub-adopt-mark")
        stub.claimStatus = 200
        stub.claimBody = Data("{\"state\":\"existing_stable\"}".utf8)
        _ = await executor.performClaim(marksMigrationAttempt: false)
        #expect(!claimStore.hasMigrationClaimAttempt(forUserID: "sub-adopt-mark"))
    }

    /// Sin JWT el claim ni sale: no hay POST, así que tampoco marca.
    @Test("performClaim: sin JWT no marca nada")
    func performClaim_noJWT_leavesNoAttemptMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: nil, userID: "sub-nojwt")
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.nojwt"))
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        _ = await executor.performClaim(marksMigrationAttempt: true)
        #expect(!claimStore.hasMigrationClaimAttempt(forUserID: "sub-nojwt"))
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

    @Test("isMirrorConfirmedOff: false en tests (personalStoreMountedDecision default .iCloudMirror)")
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

    /// **La migración terminada deja de abrir la comprobación de «Migrar a la nube».** `.proceedMigration` es lo que deja
    /// reintentar un intento que falló (`StorageMigrationIdentityGateLogic.check`); con el `complete` confirmado el sello
    /// pasa a `.routeReturningUser`. Sin confirmar, no se toca: el intento sigue a medias.
    @Test("execute(.runLeaderReconcileFromFrozenCloudKit): complete ok cambia el sello a routeReturningUser; rechazado, no")
    func execute_reconcileComplete_restampsTheClaim() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-leader")
        let stub = RoutingStub()
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.complete.stamp"))
        claimStore.record(.proceedMigration, forUserID: "sub-leader")
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.runLeaderReconcileFromFrozenCloudKit)
        }
        #expect(claimStore.action(forUserID: "sub-leader") == .proceedMigration, "sin complete, el intento sigue a medias")

        stub.migrationBody = Data("{\"ok\":true}".utf8)
        try await executor.execute(.runLeaderReconcileFromFrozenCloudKit)
        #expect(claimStore.action(forUserID: "sub-leader") == .routeReturningUser)
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

    /// **El 401 del canal deja de colapsar en «red», y esto es lo que la pantalla necesita para poder decir algo.**
    /// Hasta el ticket `reverse-before-mount-stays-stuck-with-an-expired-session`, `verify()` devolvía
    /// `.networkTimeout` y `reverseDrainOnce()` `.transient` ante una sesión que ya no vale: esperar no la renueva,
    /// así que la vuelta a iCloud se quedaba parada al 30 % y al 50 % sin decirlo.
    ///
    /// Los dos caminos que producen ese 401 se prueban por separado —el push y el pull—, porque cada uno tiene su
    /// `case` y un mutante puede colapsar solo uno. Aquí llegan como sesión caducada porque estos clientes se
    /// construyen con el default `{ false }` de `canRenewSession`; en producción el token que no llega sin red se
    /// queda en `.transient` antes de llegar aquí.
    @Test("verify y reverseDrainOnce: un 401 del canal sale como sesión caducada, no como red")
    func reverseSteps_channel401_surfaceAsSessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // — Por el PULL, con el outbox vacío (no hay push que hacer).
        stub.pullStatus = 401
        #expect(await executor.verify() == .sessionExpired, "verify: el 401 del pull es sesión caducada")
        #expect(await executor.reverseDrainOnce() == .sessionExpired, "drain: el 401 del pull es sesión caducada")

        // — Por el PUSH, que corre ANTES del pull: con una fila viva pendiente se llega a él primero.
        stub.pullStatus = 200
        stub.pushStatus = 401
        context.insert(Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        try context.save()
        #expect(await executor.verify() == .sessionExpired, "verify: el 401 del push es sesión caducada")
        #expect(await executor.reverseDrainOnce() == .sessionExpired, "drain: el 401 del push es sesión caducada")

        // — Controles en la dirección contraria, por las DOS rutas. Sin ellos, un mutante que mandara todo a
        // `.sessionExpired` saldría verde y la tarjeta diría «Tu sesión caducó. Vuelve a entrar» a quien solo está
        // sin cobertura, que es el falso positivo que este cambio existe para no cometer.
        stub.pushStatus = 503
        #expect(await executor.verify() == .networkTimeout, "verify: un 5xx del push sigue siendo red")
        #expect(await executor.reverseDrainOnce() == .transient, "drain: un 5xx del push sigue siendo red")

        // — Y el 403: cuenta suspendida. Sigue sin pedir volver a entrar —«Iniciar sesión» ahí manda a un gesto que
        // no cambia nada— pero desde el 2026-09-21 tampoco se confunde con la red: sale TIPADO
        // (`reverse-before-mount-has-no-way-to-abandon-the-return`), que es lo que deja elegir el techo corto de la
        // etapa. Con `.transient`, como estaba, la vuelta se quedaba parada aquí sin salida.
        stub.pushStatus = 403
        #expect(await executor.verify() == .blocked(.accountUnavailable),
                "verify: el 403 del push no es red, y tampoco pide volver a entrar")
        #expect(await executor.reverseDrainOnce() == .blocked(.accountUnavailable),
                "drain: el 403 del push no es red, y tampoco pide volver a entrar")

        // El 403 del PULL exige el outbox vacío: con filas vivas, el push las sube y `verify()` sale por
        // `.newDeltaDetected` antes de llegar al pull. Un `reverseDrainOnce` con el push en 200 lo limpia.
        stub.pushStatus = 200
        #expect(await executor.reverseDrainOnce() == .completed, "control: con todo en 200, el drain cierra")
        #expect(try liveOutboxRows(context).isEmpty, "control del escenario: sin este vacío, el pull no se alcanza")
        stub.pullStatus = 403
        #expect(await executor.verify() == .blocked(.accountUnavailable),
                "verify: el 403 del pull no es red, y tampoco pide volver a entrar")
        #expect(await executor.reverseDrainOnce() == .blocked(.accountUnavailable),
                "drain: el 403 del pull no es red, y tampoco pide volver a entrar")
    }

    /// Filas vivas del outbox: el escenario de arriba depende de que esté vacío, y afirmarlo es lo que impide que el
    /// caso se sostenga por casualidad (la trampa del «escenario que no recorre la rama que dice»).
    ///
    /// **Propaga desde el 2026-09-22** (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`): era un
    /// `try?` con `?? []`, o sea el mismo antipatrón que el ticket arregla, metido en el CONTROL del escenario. Un
    /// fetch que lanzara aquí habría dado «outbox vacío» y el control habría certificado una premisa falsa — justo
    /// lo que estos helpers existen para no hacer. Si lanza, el test se cae, que es lo correcto.
    private func liveOutboxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
    }

    // MARK: - El outbox que no se deja leer (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`)

    /// **EL caso del ticket.** Hasta el 2026-09-22 un `fetch(SyncOutbox)` que lanzaba devolvía `[]`, y la misma
    /// avería producía dos conclusiones opuestas en UNA pasada: el pre-check leía «no hay nada que subir» y se
    /// saltaba el push entero, y veinte líneas después `verifyIntegrity` repetía el mismo fetch y lo trataba como
    /// algo que no se arregla esperando. La primera era demasiado optimista y la segunda demasiado pesimista.
    ///
    /// Se mide en las dos mitades, porque un desenlace correcto por el camino equivocado no cierra el ticket:
    /// (a) el veredicto es `.blocked(.localFailure)`, el mismo al que `VerifyProbeMapping` manda
    /// `outbox-fetch-failed` — o sea, la pasada tiene UNA sola lectura; (b) **la pasada CORTÓ**, y eso se afirma
    /// con los contadores del stub: sin push subido, sin pull pedido y sin Merkle pedido. Con el `[]` de antes el
    /// pull y el Merkle sí se pedían, así que el contador en cero es lo que distingue «lo arreglé» de «coincide».
    @Test("verify: un outbox ilegible corta con un desenlace propio y NO se salta el push")
    func verify_unreadableOutbox_blocksLocalFailure_andStopsThePass() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub,
                                    FakeSession(token: "jwt", userID: "sub-1"), FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // Una fila local pendiente: sin ella el escenario no distingue «no había nada» de «no se pudo leer».
        context.insert(Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        try context.save()

        // Control del escenario ANTES de la avería: esa fila LLEGA al outbox y sin el seam se sube. Sin esto, el
        // caso no distinguiría «no había nada que subir» de «no se pudo leer», que es justo su tesis.
        let sano = makeExecutor(context, CloudSyncEngine(), stub,
                                FakeSession(token: "jwt", userID: "sub-1"), FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await sano.verify() == .newDeltaDetected,
                "control del escenario: sin la avería esta fila se sube y la pasada pide un re-run")
        #expect(!stub.pushedSyncIDs.isEmpty, "control del escenario: la fila existe y el push la sube")

        // Y ahora el caso, con el outbox re-poblado para que haya algo que saltarse.
        context.insert(Category(name: "drinks", colorHex: "#FEDCBA", isIncome: false, isDefaultSeed: false))
        try context.save()
        let pullsAntes = stub.pullCallCount
        let merkleAntes = stub.merkleCallCount
        let subidasAntes = stub.pushedSyncIDs.count

        executor._testOutboxFetchThrowsFromCall = 1
        let probe = await executor.verify()

        #expect(probe == .blocked(.localFailure),
                "el outbox ilegible tiene desenlace propio, no se lee como vacío")
        #expect(probe == VerifyProbeMapping.map(verdict: .skipped(reason: MerkleSkipReason.outboxFetchFailed)),
                "y es EL MISMO que el verificador Merkle da para ese fallo: una lectura, una conclusión")
        #expect(stub.pushedSyncIDs.count == subidasAntes, "no se sube nada a ciegas")
        // Y NO llega al pull. Con el `[]` de antes sí llegaba, y es el detalle que distingue este arreglo de
        // cualquier otro corte: `live.isEmpty` daba true, se saltaba el push entero y la pasada seguía adelante
        // hasta el Merkle, que sacaba la conclusión CONTRARIA del mismo fallo. Lo mata el mutante.
        #expect(stub.pullCallCount == pullsAntes, "la pasada corta AQUÍ: con el `[]` de antes seguía al pull")
        #expect(stub.merkleCallCount == merkleAntes, "y no llega al Merkle a sacar la conclusión contraria")
    }

    /// La SEGUNDA lectura de `verify()`, la de después del push, y era la peor de las dos: con `[]` devolvía
    /// `.newDeltaDetected`, que **no consume reintento**. O sea que una base ilegible no solo se leía como «todo
    /// subido» sino como «llegó un delta, vuelve a correr gratis» — una re-corrida sin techo alimentada por la
    /// propia avería. El contador del seam existe para que esta rama sea alcanzable: con un `Bool`, la primera
    /// lectura corta antes y nadie mediría ésta.
    ///
    /// El control del escenario es `pushedSyncIDs`: si el push no llegó a correr, este test estaría midiendo el
    /// caso de arriba con otro nombre.
    @Test("verify: si el outbox se vuelve ilegible DESPUÉS del push, tampoco es un re-run gratis")
    func verify_unreadableOutboxAfterPush_blocksInsteadOfFreeRerun() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub,
                                    FakeSession(token: "jwt", userID: "sub-1"), FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        context.insert(Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        try context.save()

        // La 1.ª lectura (pre-check) pasa y deja correr el push; la 2.ª (post-push) lanza.
        executor._testOutboxFetchThrowsFromCall = 2
        let probe = await executor.verify()

        #expect(!stub.pushedSyncIDs.isEmpty, "control del escenario: el push TIENE que haber corrido")
        #expect(probe == .blocked(.localFailure),
                "la relectura fallida no vale un re-run barato — devolvía `.newDeltaDetected`, que NO consume reintento")
    }

    /// El gemelo en la VUELTA, y donde el precio es mayor: `reverseDrainOnce` podía devolver `.completed` con el
    /// outbox sin leer, y lo siguiente que hace la vuelta a iCloud es CONGELAR el backend. Dar por drenado lo que
    /// nadie pudo mirar y cerrar la puerta detrás.
    ///
    /// `.blocked(.localFailure)` elige el techo CORTO de la etapa (`ReversePreMountBlocker.stallCause`), que es el
    /// trato que el ticket hermano ya le dio a esta misma avería vista desde el Merkle.
    @Test("reverseDrainOnce: un outbox ilegible no se da por drenado")
    func reverseDrain_unreadableOutbox_doesNotReportCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub,
                                    FakeSession(token: "jwt", userID: "sub-1"), FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        context.insert(Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        try context.save()

        executor._testOutboxFetchThrowsFromCall = 1
        let outcome = await executor.reverseDrainOnce()

        #expect(outcome == .blocked(.localFailure),
                "esperar no arregla una lectura que falla, y no se da por drenado: detrás viene el congelado")
        #expect(stub.pullCallCount == 0, "corta antes del pull final")
        #expect(stub.pushedSyncIDs.isEmpty, "sin subir nada a ciegas")

        // Control en la dirección contraria: con el store legible el mismo escenario cierra Y SUBE. Sin la
        // segunda mitad, `.completed` también sale con el outbox vacío —el push es condicional— así que el
        // control pasaría aunque la `Category` no hubiera encolado nada.
        executor._testOutboxFetchThrowsFromCall = nil
        #expect(await executor.reverseDrainOnce() == .completed,
                "control: sin la avería, este escenario SÍ drena — el `blocked` de arriba lo produce el fetch")
        #expect(!stub.pushedSyncIDs.isEmpty, "control del escenario: y había de verdad una fila que subir")
    }

    /// El barrido del líder antes de `migration_progress('complete')`. Con `[]` el residual salía vacío, no se
    /// subía nada y el `complete` se mandaba igual: la migración de la cuenta se cerraba con las filas del líder
    /// fuera. Ahora propaga como el resto de cortes retomables de ese bloque, y el `complete` no llega a pedirse.
    @Test("leader-reconcile: un outbox ilegible corta retomable y NO manda 'complete'")
    func leaderReconcile_unreadableOutbox_throwsBeforeComplete() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub,
                                    FakeSession(token: "jwt", userID: "sub-1"), FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // Control del escenario PRIMERO: sin la avería este efecto llega a mandar `complete`. Sin él, un mutante
        // que lanzara al ENTRAR en el efecto pasaría las dos aserciones de abajo sin tocar el outbox.
        let sano = makeExecutor(context, CloudSyncEngine(), stub,
                                FakeSession(token: "jwt", userID: "sub-1"), FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await sano.execute(.runLeaderReconcileFromFrozenCloudKit)
        #expect(stub.migrationCallCount == 1, "control del escenario: sin la avería SÍ se manda `complete`")

        executor._testOutboxFetchThrowsFromCall = 1
        // El `effect` EXACTO, no el tipo: `notWired` es el mismo case que usan `sweepTransient`,
        // `sessionExpired`, `otherLeader` y `rejected`, así que `throws: MigrationExecutorError.self` no
        // distinguiría esta rama de ninguna de las otras cuatro.
        await #expect(throws: MigrationExecutorError.notWired(effect: "runLeaderReconcile: outboxUnreadable")) {
            try await executor.execute(.runLeaderReconcileFromFrozenCloudKit)
        }
        #expect(stub.migrationCallCount == 1,
                "el `complete` NO se manda otra vez: cerraría la migración con filas del líder sin subir")
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
        let local = try SyncMerkle.computeLocalMerkle(context: context)
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

    /// **La cadena ENTERA, que es lo que el ticket cierra: un «no» del servidor que solo ve el TERCER paso.**
    /// El push y el pull tipan su 401 y su 403 desde el 2026-09-16, y el Merkle los aplanaba, así que la ventana
    /// viva era la del rechazo que empieza justo entre el pull y el Merkle. Aquí se monta exactamente eso: los dos
    /// primeros pasos en 200 y el Merkle contestando que no.
    ///
    /// El escenario arranca con el outbox VACÍO a propósito: con filas vivas el push las sube y `verify()` sale por
    /// `.newDeltaDetected` sin llegar al Merkle. **Con él vacío el push no se ejecuta siquiera** —`live.isEmpty`
    /// salta el bloque entero—, así que el único paso que corre antes del Merkle es el pull, que es justo la ventana
    /// que el ticket describe. El control positivo del final impide que el caso se sostenga por casualidad: con el
    /// mismo escenario y el Merkle en 200, `verify()` da `.match`.
    @Test("verify: el 401 y el 403 que solo ve el MERKLE ya no salen como red")
    func verify_merkleOnly401and403_areTyped() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        // Merkle remoto = árbol LOCAL (store vacío → converge byte a byte) para el control del final.
        let local = try SyncMerkle.computeLocalMerkle(context: context)
        var entitiesJSON: [String: Any] = [:]
        for (table, summary) in local.entities {
            entitiesJSON[table] = ["count": summary.count, "hash": summary.hashHex]
        }
        stub.merkleBody = try JSONSerialization.data(withJSONObject: [
            "canon_version": "c1", "capability_set": "v1",
            "root": local.rootHex, "entities": entitiesJSON,
        ])

        #expect(try liveOutboxRows(context).isEmpty, "control del escenario: sin outbox vacío no se alcanza el Merkle")

        stub.merkleStatus = 401
        #expect(await executor.verify() == .sessionExpired,
                "verify: el 401 del Merkle es sesión caducada — en la vuelta enciende «vuelve a entrar»")

        stub.merkleStatus = 403
        #expect(await executor.verify() == .blocked(.accountUnavailable),
                "verify: el 403 del Merkle no es red — en la vuelta elige el techo CORTO")

        // Control en la dirección contraria: lo que SÍ es red del Merkle sigue siendo red. Y el 401 del ATTEST
        // también, que es la otra mitad de este 401 y la que no debe pedir volver a entrar (regla
        // `.claude/rules/gateway-attest.md`): en la vuelta elige el techo LARGO, como el resto de la red.
        stub.merkleStatus = 503
        #expect(await executor.verify() == .networkTimeout, "verify: un 5xx del Merkle sigue siendo red")

        stub.merkleStatus = 401
        stub.merkleErrorBody = Data(#"{"error":{"type":"yala_attest_required","code":"yala_attest_required"}}"#.utf8)
        #expect(await executor.verify() == .networkTimeout,
                "verify: el 401 de attest del Merkle es pasajero, no una sesión que renovar")
        stub.merkleErrorBody = Data()

        // Control positivo: el mismo escenario con el Merkle sano converge.
        stub.merkleStatus = 200
        #expect(await executor.verify() == .match)
    }

    /// El `reason` desconocido y el `fetch` de la CUARENTENA no se pueden montar desde el transporte, así que su
    /// lectura se fija en el mapping (`VerifyProbeMappingTests`). **Ya no son «los dos `fetch`»**: desde
    /// `verify-reads-a-failed-local-fetch-as-an-empty-outbox` el del outbox SÍ se monta —con
    /// `_testOutboxFetchThrowsFromCall`, en los tests de más arriba— y el del cómputo del árbol local también, en
    /// `SyncMerkleTests`. Lo que SÍ se mide aquí es que ese mapping es el que `verify()` usa: con un canon que
    /// este build no compara, el veredicto sale por él.
    @Test("verify: el veredicto del Merkle pasa por VerifyProbeMapping, no por una tabla paralela")
    func verify_contractMismatch_goesThroughTheMapping() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let executor = makeExecutor(context, engine, stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))

        stub.merkleBody = try JSONSerialization.data(withJSONObject: [
            "canon_version": "c2", "capability_set": "v1", "root": "r", "entities": [:],
        ])
        #expect(await executor.verify() == .mismatch,
                "canon futuro → mismatch, que es lo que dice la tabla del mapping")
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

    /// Ticket `apply-overwrites-a-pending-local-write-without-its-guards`: una tabla que no se deja leer ya no
    /// cuenta como «0 zombies». Las tablas se barren en orden (`tags` antes que `tx_items`), así que `tags` ya
    /// dejó su delete en el contexto cuando `tx_items` lanza: el rollback lo tira, nada se guarda y el runner
    /// reintenta. Control positivo: con la lectura de vuelta, borra las dos.
    @Test("sweepZombies: tabla ilegible → transient con rollback, sin dar el barrido por hecho")
    func sweepZombies_unreadableTable_transientWithRollback() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        defer { EntityApplyMap._testThrowOnFetchOf = [] }
        let tx = TransactionItem(date: fixedNow, amount: 1, currencyCode: "USD")
        tx.syncID = UUID()
        let tag = Yala.Tag(name: "Viaje")
        context.insert(tx)
        context.insert(tag)
        try context.save()
        let deltas = [tombstone(table: "tags", syncID: tag.id, seq: 1),
                      tombstone(table: "tx_items", syncID: try #require(tx.syncID), seq: 2)]

        func executor() -> MigrationWorkExecutor {
            let source = FakeTombstoneSource()
            source.pages = [PulledPage(deltas: deltas, maxServerSeq: 2)]
            return makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                tombstoneSource: source)
        }

        EntityApplyMap._testThrowOnFetchOf = ["TransactionItem"]
        #expect(await executor().sweepZombies(sinceSeq: 0) == .transient)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(context.hasChanges == false, "rollback: el delete de tags no queda dirty")
        #expect(try context.fetchCount(FetchDescriptor<Yala.Tag>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 1)

        #expect(await executor().sweepZombies(sinceSeq: 0) == .completed(deleted: 2))
        #expect(try context.fetchCount(FetchDescriptor<Yala.Tag>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
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

    @Test("execute(.persistICloudMode): retira los sentinels del drenaje iKV (#37) — TODOS los userIDs, keys ajenas intactas")
    func execute_persistICloudMode_clearsDrainSentinels() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = makeIsolatedDefaults(prefix: "mwe.icloud.sentinel")
        defaults.set(true, forKey: PrefsCutoverDrain.sentinelPrefix + "userA")
        defaults.set(true, forKey: PrefsCutoverDrain.sentinelPrefix + "userB")
        defaults.set(true, forKey: "cloudSync.otherKey")   // ajena: jamás se toca
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.persistICloudMode)
        #expect(defaults.object(forKey: PrefsCutoverDrain.sentinelPrefix + "userA") == nil,
                "sentinel del userID A retirado — una re-migración vuelve a drenar")
        #expect(defaults.object(forKey: PrefsCutoverDrain.sentinelPrefix + "userB") == nil,
                "sentinel de OTRO userID también (basura inerte post-reversa)")
        #expect(defaults.bool(forKey: "cloudSync.otherKey"), "key ajena al prefijo intacta")
        // Idempotencia (kill-safe: el efecto puede re-ejecutarse en resume): segunda pasada no lanza.
        try await executor.execute(.persistICloudMode)
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

        // g15_02: el rechazo por tipo de cuenta ya no es `not_migrated` sino `not_complete` (solo-grupos,
        // o una cuenta que YA volvió a iCloud). El executor lo propaga OPACO — no hay `switch` por motivo.
        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"not_complete\"}".utf8)
        #expect(await executor.performReverseClaim() == .rejected(reason: "not_complete"))

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"migration_in_progress\"}".utf8)
        #expect(await executor.performReverseClaim() == .rejected(reason: "migration_in_progress"))

        stub.migrationStatus = 500
        #expect(await executor.performReverseClaim() == .transient)

        session.token = nil
        #expect(await executor.performReverseClaim() == .sessionExpired, "sin JWT → sessionExpired SIN tocar la red")

        // El caso que abre el ticket `reverse-before-mount-stays-stuck-with-an-expired-session`: el token no llega
        // pero el SDK CONSERVA la sesión ⇒ la renovación no volvió (sin red, 5xx del servidor de auth), no hay nada
        // que volver a firmar. Sin esta separación, quedarse sin cobertura a mitad de la vuelta pediría iniciar
        // sesión — el mismo falso positivo que cerró `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`.
        session.canRenewSessionOverride = true
        #expect(await executor.performReverseClaim() == .transient,
                "token ausente con la sesión guardada → pasajero, NO sesión caducada")
    }

    @Test("""
        freezeBackendForReverse: ok → completed + BODY {device_id, action:'reverse_freeze'}; rechazo/red → transient; \
        sin JWT → sessionExpired, salvo que el SDK conserve la sesión (entonces pasajero)
        """)
    func reverseFreeze_bodyAndOutcomes() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let stub = RoutingStub()
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        #expect(await executor.freezeBackendForReverse() == .completed)
        #expect(stub.lastMigrationBody?["device_id"] as? String == "device-1")
        #expect(stub.lastMigrationBody?["action"] as? String == "reverse_freeze")

        // Desde el 2026-09-21 los dos rechazos del servidor salen TIPADOS
        // (`reverse-before-mount-has-no-way-to-abandon-the-return`): hasta entonces colapsaban en `.transient` y esta
        // fase era la única de las cuatro sin ninguna salida, reintentando un «no» para siempre.
        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"other_leader\"}".utf8)
        #expect(await executor.freezeBackendForReverse() == .blocked(.otherLeader))

        stub.migrationBody = Data("{\"ok\":false,\"reason\":\"not_in_progress\"}".utf8)
        #expect(await executor.freezeBackendForReverse() == .blocked(.refused))

        stub.migrationStatus = 500
        #expect(await executor.freezeBackendForReverse() == .transient)

        // 401 del gateway: `/account/migration` NO exige App Attest, así que su 401 es siempre el JWT (a diferencia
        // de `/sync/*`, donde hay un segundo 401 que es del attest y NO pide volver a entrar).
        stub.migrationStatus = 401
        #expect(await executor.freezeBackendForReverse() == .sessionExpired)

        stub.migrationStatus = 200
        session.token = nil
        #expect(await executor.freezeBackendForReverse() == .sessionExpired,
                "sin JWT y sin sesión guardada → hay que volver a entrar")

        session.canRenewSessionOverride = true
        #expect(await executor.freezeBackendForReverse() == .transient,
                "token ausente con la sesión guardada → pasajero: esperar lo arregla")
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

    @Test("ReverseEligibility: notCloudMode / reverseAlreadyTerminal / eligible")
    func reverseEligibility_decisions() {
        #expect(ReverseEligibility.decide(
            storageMode: .icloud, hasCKMap: true, isBornCloud: false, journaledPhase: .done) == .notCloudMode)
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: true, isBornCloud: false, journaledPhase: .icloudActive) == .reverseAlreadyTerminal)
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: true, isBornCloud: false, journaledPhase: .reverseFailedRollback) == .reverseAlreadyTerminal)
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: true, isBornCloud: false, journaledPhase: .done) == .eligible)
    }

    /// El eje que g15_02 abre: el mapa CloudKit solo se le exige a quien NO consta como born-cloud. Los dos
    /// casos de `hasCKMap: false` son los que discriminan — si alguien retira `|| isBornCloud` cae el
    /// born-cloud; si retira `hasCKMap ||` cae el sin-mapa-sin-marca, que sigue excluido a propósito.
    @Test("ReverseEligibility: sin mapa CloudKit, born-cloud entra y el resto NO (resurrección de borrados)")
    func reverseEligibility_mapOnlyRequiredWithoutBornCloudMark() {
        // Sin mapa y sin marca: puede ser un MIGRADO que perdió el mapa, y su zona CloudKit sigue ahí con
        // los records que borró durante la época nube. Remontar el mirror los resucitaría → sigue fuera.
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false, isBornCloud: false, journaledPhase: .done) == .degradedNoMap)

        // Born-cloud: nunca hubo zona con borrados de la época nube, así que no hay nada que resucitar.
        // Hasta el 2026-09-10 caía en `degradedNoMap` por arrastre, y tras el fresh start de ese día eso
        // era TODA la población.
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false, isBornCloud: true, journaledPhase: .done) == .eligible)

        // Born-cloud que ya pobló el mapa en una reversa anterior (`reverseUploadStatus` captura las
        // coordenadas conforme el mirror exporta): elegible por las dos vías.
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: true, isBornCloud: true, journaledPhase: .done) == .eligible)
    }

    /// La PRECEDENCIA de los guards, que sin este test es decorado: los casos de arriba se pueden reordenar
    /// sin que ninguno caiga. El que carga el peso es el primero — sin-mapa-sin-marca **ya en un terminal**
    /// tiene que decir `reverseAlreadyTerminal`, no `degradedNoMap`. Un mutante que suba el guard del mapa
    /// por encima del `switch` de fase lo tumba, y no tumba nada más.
    @Test("ReverseEligibility: el terminal y el modo GANAN al guard del mapa (precedencia, no solo salida)")
    func reverseEligibility_guardPrecedence() {
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false, isBornCloud: false, journaledPhase: .icloudActive) == .reverseAlreadyTerminal)
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false, isBornCloud: false, journaledPhase: .reverseFailedRollback) == .reverseAlreadyTerminal)
        #expect(ReverseEligibility.decide(
            storageMode: .icloud, hasCKMap: false, isBornCloud: false, journaledPhase: .done) == .notCloudMode)
        // Y el terminal también gana a un born-cloud que por lo demás sería elegible.
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false, isBornCloud: true, journaledPhase: .icloudActive) == .reverseAlreadyTerminal)
    }

    /// El CABLEADO de la marca, que es donde vive el riesgo real: `decide` es pura y recibe un `Bool`, así
    /// que toda la tabla de verdad de arriba puede estar verde con ese `Bool` mal calculado en producción.
    /// Aquí se prueba el mapeo población → `Bool` contra `UserDefaults` de verdad.
    ///
    /// Lo que fija, y por qué importa: la marca es POSITIVA y **ausente ⇒ false**. La primera versión de
    /// este cambio la derivaba de la AUSENCIA del `CloudMigrationMarker` y fallaba ABIERTO — un 2.º device
    /// adoptado cuyo marcador no llegó por el mirror (su propio belt dice «ausente = no bloquea»), o
    /// cualquiera que hubiese usado el botón DEBUG de «borrar marcador stale», pasaba por born-cloud y se
    /// llevaba por delante el guardarraíl de la resurrección de borrados.
    @Test("StorageModePersistence: la marca born-cloud es positiva, la escribe el alta y ausente es false")
    func bornCloudMark_isPositiveAndDefaultsToFalse() {
        let defaults = makeIsolatedDefaults(prefix: "reverse.bornCloud")
        defer { defaults.removeObject(forKey: StorageModePersistence.bornCloudKey) }

        // Un dominio limpio es un device del que no sabemos nada ⇒ NO se le abre la puerta.
        #expect(StorageModePersistence.isBornCloud(defaults) == false)
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false,
            isBornCloud: StorageModePersistence.isBornCloud(defaults),
            journaledPhase: .done) == .degradedNoMap)

        // El alta born-cloud la escribe, y con ella la reversa se abre sin exigir mapa.
        StorageModePersistence.markBornCloud(defaults: defaults)
        #expect(StorageModePersistence.isBornCloud(defaults) == true)
        #expect(ReverseEligibility.decide(
            storageMode: .cloud, hasCKMap: false,
            isBornCloud: StorageModePersistence.isBornCloud(defaults),
            journaledPhase: .done) == .eligible)

        // Idempotente: el alta puede reentrar (su propio docblock lo declara) sin cambiar nada.
        StorageModePersistence.markBornCloud(defaults: defaults)
        #expect(StorageModePersistence.isBornCloud(defaults) == true)

        // Y NO la escribe `writeCloudArmed`, que es el escritor del par y lo llama TAMBIÉN el adopt de un
        // 2.º device. Si alguien la mueve ahí, un migrado adoptado se volvería elegible sin mapa: es el
        // fallo exacto que este diseño evita.
        let armado = makeIsolatedDefaults(prefix: "reverse.armado")
        defer { armado.removeObject(forKey: StorageModePersistence.mirrorOffArmedKey) }
        StorageModePersistence.writeCloudArmed(defaults: armado)
        #expect(StorageModePersistence.read(armado) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(armado) == true)
        #expect(StorageModePersistence.isBornCloud(armado) == false,
                "writeCloudArmed NO puede marcar born-cloud: el adopt lo llama y no es un alta")
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

    // MARK: - Adopt flow (I14 P6, #30)

    @Test("execute(.adoptBackendAccount): reconcile transient (merkle indecodificable) → THROW retomable (journaled)")
    func adoptFlow_transientReconcile_throws() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        // RoutingStub default: merkleBody vacío → fetchMerkle no-snapshot → reconcile transient → adopt throw.
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        await #expect(throws: MigrationExecutorError.self) {
            try await executor.execute(.adoptBackendAccount)
        }
    }

    @Test("runAdoptFlow: no quiescente → THROW SIN mutar el modo (retomable)")
    func adoptFlow_notQuiescent_throwsWithoutMutating() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let storageDefaults = makeIsolatedDefaults(prefix: "mwe.adopt.q")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: storageDefaults, adoptQuiescenceSignal: { false })
        await #expect(throws: MigrationExecutorError.self) { try await executor.runAdoptFlow() }
        #expect(StorageModePersistence.read(storageDefaults) == .icloud, "no quiescente → NO persiste .cloud")
        #expect(storageDefaults.bool(forKey: MigrationWorkExecutor.relaunchRequestedKey) == false)
    }

    @Test("runAdoptFlow: backend vacío + merkle coherente → persiste PAR .cloud+armed + estampa claim-store routeReturningUser")
    func adoptFlow_happy_persistsCloudArmedAndClaimStore() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-adopt")
        let stub = RoutingStub()
        stub.merkleBody = try makeMerkleBody([:])   // enumeración vacía coherente (0 vivas) → reconcile completa
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [], maxServerSeq: 0)]

        let storageDefaults = makeIsolatedDefaults(prefix: "mwe.adopt.ok")
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.adopt.claim"))
        // Rutea `PreferenceSyncService.set` por el outbox (no iKV): `.cloud` override + userID nil → sin
        // enqueue; solo escribe las 2 keys de consent a standard, que se limpian abajo.
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags._testResetStorageModeOverride()
            UserDefaults.standard.removeObject(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
            UserDefaults.standard.removeObject(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)
        }
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: storageDefaults, tombstoneSource: source,
                                    claimStore: claimStore)

        try await executor.runAdoptFlow()

        #expect(StorageModePersistence.read(storageDefaults) == .cloud, "persiste el modo nube")
        #expect(storageDefaults.bool(forKey: MigrationWorkExecutor.relaunchRequestedKey) == true, "arma el mirror-off")
        #expect(claimStore.action(forUserID: "sub-adopt") == .routeReturningUser, "estampa el claim-store")
    }

    @Test("performClaim: 200 created → estampa el claim-store con proceedMigration (branch migración)")
    func performClaim_stampsClaimStore() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-claim")
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.stamp"))
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        #expect(await executor.performClaim() == .success(.created))
        #expect(claimStore.action(forUserID: "sub-claim") == .proceedMigration,
                "created + branch migración → proceedMigration persistido (contenido real, lección d49d2e47)")
    }

    // MARK: - Claim · los otros tres estados (ampliación de la tabla, A2 de D-A7)
    //
    // Al escribir el productor born-cloud (`BornCloudSignUpService`, A2) la nota del punto de control exigía
    // comprobar que la rama `.migration` ya estuviera pinneada antes de acotar la matriz nueva a
    // `.bornCloud`. **No lo estaba**: a nivel de `performClaim` solo había `created` y el camino sin JWT —
    // `existing_stable`, `claiming_in_progress` y el transient viajaban cubiertos únicamente por la lógica
    // PURA (`AccountClaimDecisionTests`) y por el runner con un executor FALSO, que no ejercita ni el
    // estampado ni el gate de la métrica. Estos tres cierran esa mitad.

    @Test("performClaim: 200 existing_stable → estampa routeReturningUser (el líder se retira, no re-migra)")
    func performClaim_existingStable_stampsRouteReturningUser() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-stable")
        let stub = RoutingStub()
        stub.claimBody = Data(#"{"state":"existing_stable"}"#.utf8)
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.stable"))
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        #expect(await executor.performClaim() == .success(.existingStable))
        #expect(claimStore.action(forUserID: "sub-stable") == .routeReturningUser,
                "existing_stable NUNCA siembra ni lidera: es la clausura de la variante A (§k.4)")
    }

    // MARK: - Claim · deshacer el sello cuando «Migrar» lo devuelve al inicio
    //
    // Ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`. Con la intención de migrar, el runner no
    // entrega un `existing_stable` a la máquina y pide deshacer el sello: `.routeReturningUser` sin adopt afirmaría que
    // esa cuenta entró en el dispositivo, y el Welcome deja re-entrar libre a «la misma cuenta» por ese sello.

    @Test("discardLastClaimStamp: sin sello previo, el de existing_stable se borra")
    func discardLastClaimStamp_withoutPreviousStamp_clearsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        stub.claimBody = Data(#"{"state":"existing_stable"}"#.utf8)
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.undo.none"))
        let executor = makeExecutor(context, CloudSyncEngine(), stub, FakeSession(token: "jwt", userID: "sub-undo"),
                                    FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        #expect(await executor.performClaim() == .success(.existingStable))
        #expect(claimStore.action(forUserID: "sub-undo") == .routeReturningUser, "control: el claim selló")

        executor.discardLastClaimStamp()
        #expect(claimStore.action(forUserID: "sub-undo") == nil)
    }

    @Test("discardLastClaimStamp: repone el sello que había antes del claim, no lo borra")
    func discardLastClaimStamp_restoresThePreviousStamp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        stub.claimBody = Data(#"{"state":"existing_stable"}"#.utf8)
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.undo.prev"))
        claimStore.record(.proceedMigration, forUserID: "sub-undo")
        let executor = makeExecutor(context, CloudSyncEngine(), stub, FakeSession(token: "jwt", userID: "sub-undo"),
                                    FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        #expect(await executor.performClaim() == .success(.existingStable))
        #expect(claimStore.action(forUserID: "sub-undo") == .routeReturningUser, "control: el claim pisó el sello")

        executor.discardLastClaimStamp()
        #expect(claimStore.action(forUserID: "sub-undo") == .proceedMigration)
    }

    /// Solo se deshace el claim de la llamada en curso: un segundo `discard` no tiene nada que hacer, y un claim que no
    /// selló —sin JWT— tampoco deja que se deshaga el de un claim anterior.
    @Test("discardLastClaimStamp: un solo uso, y un claim sin sello no deshace el anterior")
    func discardLastClaimStamp_isOneShot_andOnlyForTheLastClaim() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        stub.claimBody = Data(#"{"state":"existing_stable"}"#.utf8)
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.undo.once"))
        let session = FakeSession(token: "jwt", userID: "sub-undo")
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)

        executor.discardLastClaimStamp()
        #expect(claimStore.action(forUserID: "sub-undo") == nil, "sin claim no hay nada que deshacer")

        #expect(await executor.performClaim() == .success(.existingStable))
        executor.discardLastClaimStamp()
        claimStore.record(.proceedMigration, forUserID: "sub-undo")
        executor.discardLastClaimStamp()
        #expect(claimStore.action(forUserID: "sub-undo") == .proceedMigration, "el segundo discard no toca nada")

        #expect(await executor.performClaim() == .success(.existingStable))
        session.token = nil
        #expect(await executor.performClaim() == .sessionExpired(detail: "no access token"))
        executor.discardLastClaimStamp()
        #expect(claimStore.action(forUserID: "sub-undo") == .routeReturningUser,
                "el claim sin JWT no selló, así que no deshace el del claim anterior")
    }

    @Test("performClaim: 200 claiming_in_progress → estampa waitForLeader (otro device lidera; el gate no arranca)")
    func performClaim_claimingInProgress_stampsWaitForLeader() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-follower")
        let stub = RoutingStub()
        stub.claimBody = Data(#"{"state":"claiming_in_progress"}"#.utf8)
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.follower"))
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        #expect(await executor.performClaim() == .success(.claimingInProgress))
        #expect(claimStore.action(forUserID: "sub-follower") == .waitForLeader)
        #expect(CloudSyncRuntime.shouldStartSync(after: .waitForLeader) == false,
                "un seguidor no debe arrancar el sync mientras el líder no termine (§g.6)")
    }

    @Test("performClaim: 500 → transient y el claim-store queda INTACTO (nada que estampar sin claim)")
    func performClaim_transient_doesNotStamp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-5xx")
        let stub = RoutingStub()
        stub.claimStatus = 500
        stub.claimBody = Data(#"{"error":{"message":"upstream"}}"#.utf8)
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.claim.5xx"))
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    claimStore: claimStore)
        guard case .transient = await executor.performClaim() else {
            Issue.record("500 debe clasificar como transient (retomable)")
            return
        }
        #expect(claimStore.action(forUserID: "sub-5xx") == nil)
    }

    // MARK: - Canal iCloud · probeICloudChannel (C-1)
    //
    // La decisión es pura y se pinnea celda a celda en `ICloudCutoverGateLogicTests`. Lo que se pinnea AQUÍ
    // es el CABLEADO: que el executor recoja las tres señales de las fuentes correctas y las pase en el orden
    // correcto. Si alguien invierte `accountPresent`, lee la huella con el predicado equivocado (p.ej. contando
    // testigos SIN `ckRecordName`) o se salta el error code, la lógica pura seguiría verde y el bug C-1
    // volvería: un veredicto `.healthy` falso deja al paso 4 esperando un marcador que jamás exporta.
    //
    // Las 2 closures se inyectan SIEMPRE (también donde el veredicto no dependería del error code): los
    // argumentos de `decide` se evalúan de forma eager, y el default de producción es
    // `iCloudSyncService.shared` — un singleton que los tests no deben tocar.

    @Test("probeICloudChannel: sin cuenta iCloud y sin huella CloudKit → noChannelNoFootprint (el waiver del gate del marcador)")
    func probeICloudChannel_noAccountNoFootprint() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")

        // Testigo SIN `ckRecordName`: existe la fila pero NUNCA hizo round-trip a CloudKit. La huella es
        // "hay copia en CloudKit", no "hay testigos" — contarlo como huella vetaría el modo nube para siempre
        // al usuario que no usa iCloud ("necesitas iCloud para dejar de usar iCloud").
        context.insert(SyncIdentity(syncID: UUID(), entityType: SyncEntityType.category, localAnchor: "anchor"))
        try context.save()

        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { false },
                                    icloudLastExportErrorCode: { nil })
        #expect(await executor.probeICloudChannel() == .noChannelNoFootprint)
    }

    @Test("probeICloudChannel: sin cuenta iCloud pero CON huella (≥1 ckRecordName) → noAccountWithFootprint (bloquea la entrada)")
    func probeICloudChannel_noAccountWithFootprint() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")

        // Huella DURABLE: el corpus ya tiene copia viva en CloudKit (sobrevive a que el usuario cierre iCloud).
        // Hay a quién avisar del cutover y no podemos → nada durable ha cambiado aún, así que se aborta la
        // entrada en vez de quedar en `.cloud` con el mirror vivo.
        context.insert(SyncIdentity(syncID: UUID(), entityType: SyncEntityType.category,
                                    localAnchor: "anchor", ckRecordName: "CKR-1",
                                    ckZoneName: "com.apple.coredata.cloudkit.zone", ckOwnerName: "__defaultOwner__"))
        try context.save()

        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { false },
                                    icloudLastExportErrorCode: { nil })
        #expect(await executor.probeICloudChannel() == .noAccountWithFootprint)
    }

    @Test("probeICloudChannel: cuenta presente + quotaExceeded → quotaExceeded (iCloud lleno = el write NO entra)")
    func probeICloudChannel_quotaExceeded() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        // Con cuenta presente la huella es irrelevante: manda el dictamen post-hoc de CloudKit. Es la ÚNICA
        // señal real de "lleno" que iOS expone (no hay API de espacio disponible).
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { true },
                                    icloudLastExportErrorCode: { .quotaExceeded })
        #expect(await executor.probeICloudChannel() == .quotaExceeded)
    }

    @Test("probeICloudChannel: cuenta presente + error RETRIABLE (networkUnavailable) → healthy (fail-open)")
    func probeICloudChannel_retriableError_failsOpen() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        // FAIL-OPEN: un túnel o un rate-limit NO son un canal roto. Abortar por ellos cancelaría migraciones
        // sanas; el atasco de verdad lo caza el TOPE POR TIEMPO del paso 4, no este probe.
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { true },
                                    icloudLastExportErrorCode: { .networkUnavailable })
        #expect(await executor.probeICloudChannel() == .healthy)
    }

    @Test("probeICloudChannel: cuenta presente + sin error observado (nil) → healthy (el caso del 99 % de 2.x)")
    func probeICloudChannel_noError_healthy() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        // `nil` es también el estado tras un boot fresco (el error vive EN MEMORIA) — de ahí que este probe
        // sea un acelerador y no la autoridad.
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { true },
                                    icloudLastExportErrorCode: { nil })
        #expect(await executor.probeICloudChannel() == .healthy)
    }

    // MARK: - El par (storageMode, mirror-off armado) visto con isCloudWithMirrorOn (C-1)
    //
    // `isCloudWithMirrorOn == true` significa "modo nube con el mirror de CloudKit VIVO" = doble escritura.
    // Es LEGÍTIMO y transitorio dentro de la ventana del cutover, y PROHIBIDO en cualquier fase estable. Los
    // 3 tests de abajo pinnean el valor del invariante en los 3 caminos que escriben el par, para que la
    // ventana sea un estado DECLARADO (y por tanto gateable por `MigrationRuntimeGate.canRun`) y no un
    // accidente que nadie note hasta que el motor y el mirror escriban a la vez.

    @Test("persistLocalMode: ABRE la ventana declarada — isCloudWithMirrorOn true (.cloud persistido, mirror aún VIVO)")
    func persistLocalMode_declaresCloudWithMirrorOn() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let storageDefaults = makeIsolatedDefaults(prefix: "mwe.pair.open")
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: storageDefaults)
        // Antes: en `.icloud` el invariante es false por construcción (el gate es inerte para 2.x).
        #expect(StorageModePersistence.isCloudWithMirrorOn(storageDefaults) == false)

        #expect(await executor.persistLocalMode() == true)

        // El paso 2 persiste `.cloud` SIN armar el mirror-off a propósito (el marcador todavía tiene que
        // exportar por el mirror vivo, pasos 3-4). Ese estado debe ser LEGIBLE, no inferido.
        #expect(StorageModePersistence.isCloudWithMirrorOn(storageDefaults) == true,
                "la ventana del cutover es un estado DECLARADO — el gate del motor la reconoce por aquí")
    }

    @Test("execute(.persistICloudMode): CIERRA la ventana — isCloudWithMirrorOn false (vuelta a .icloud)")
    func execute_persistICloudMode_closesCloudWithMirrorOnWindow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = makeIsolatedDefaults(prefix: "mwe.pair.close")
        // Estado de partida: la ventana ABIERTA (lo que deja el paso 2 antes del rollback de C-1).
        StorageModePersistence.write(.cloud, defaults: defaults)
        #expect(StorageModePersistence.isCloudWithMirrorOn(defaults) == true)

        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.persistICloudMode)
        // El rollback del atasco del marcador devuelve el device a `.icloud`: el mirror sigue vivo, pero ya
        // NO en modo nube ⇒ no hay doble escritura que gatear.
        #expect(StorageModePersistence.isCloudWithMirrorOn(defaults) == false)
    }

    @Test("runAdoptFlow (camino feliz): el par queda COMPLETO por el escritor único → isCloudWithMirrorOn false")
    func adoptFlow_happy_pairIsCompleteNotHalfWritten() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-adopt-pair")
        let stub = RoutingStub()
        stub.merkleBody = try makeMerkleBody([:])   // enumeración vacía coherente (0 vivas) → reconcile completa
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [], maxServerSeq: 0)]

        let storageDefaults = makeIsolatedDefaults(prefix: "mwe.pair.adopt")
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "mwe.pair.adopt.claim"))
        // Mismo aislamiento que el test hermano del adopt feliz: `.cloud` override + userID nil rutea
        // `PreferenceSyncService.set` por el outbox sin enqueue; las 2 keys de consent van a standard.
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags._testResetStorageModeOverride()
            UserDefaults.standard.removeObject(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
            UserDefaults.standard.removeObject(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)
        }
        let executor = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: storageDefaults, tombstoneSource: source,
                                    claimStore: claimStore)

        try await executor.runAdoptFlow()

        // El adopt cruza el gate del marcador por definición (lo exportó el LÍDER) ⇒ escribe las DOS mitades
        // de una vez con `writeCloudArmed`. Media escritura dejaría al secundario en modo nube con el mirror
        // vivo hasta el relanzamiento: exactamente el estado que C-1 persigue.
        #expect(StorageModePersistence.read(storageDefaults) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storageDefaults) == true)
        #expect(StorageModePersistence.isCloudWithMirrorOn(storageDefaults) == false,
                "el par completo NO abre ventana de doble escritura (escritor único, no dos `set` sueltos)")
    }

    // MARK: - Techo de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`)

    @Test("execute(.rearmMirrorOff): en la espera de la reversa (.cloud + mirror vivo) re-arma el par ENTERO y cierra la ventana")
    func execute_rearmMirrorOff_rearmsTheWholePair() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = makeIsolatedDefaults(prefix: "mwe.rearm")
        // Estado de partida de `reverseUpload`: `.mountMirrorAndRelaunch` desarmó el flag manteniendo `.cloud`.
        StorageModePersistence.write(.cloud, defaults: defaults)
        #expect(StorageModePersistence.isCloudWithMirrorOn(defaults) == true)

        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.rearmMirrorOff)

        // Con el par completo, el siguiente arranque monta el store sin mirror y el motor puede correr. Con el
        // flag suelto y `.icloud` (el otro orden posible), `derive` pediría relanzar en bucle.
        #expect(StorageModePersistence.read(defaults) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults) == true)
        #expect(StorageModePersistence.isCloudWithMirrorOn(defaults) == false)
    }

    @Test("execute(.rearmMirrorOff): escribe el MODO también — desde `.icloud` no deja la mitad «armado + .icloud»")
    func execute_rearmMirrorOff_fromICloud_writesTheModeToo() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let defaults = makeIsolatedDefaults(prefix: "mwe.rearm.icloud")
        // No debería pasar en `reverseUpload` (el modo es `.cloud`), pero si pasa, armar el flag suelto dejaría la
        // mitad que `derive` lee como «relanza» en bucle. Con el escritor único del par no puede quedar a medias.
        StorageModePersistence.write(.icloud, defaults: defaults)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                    personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    storageDefaults: defaults)
        try await executor.execute(.rearmMirrorOff)
        try await executor.execute(.rearmMirrorOff)         // idempotente: re-ejecutarlo tras un kill no cambia nada
        #expect(StorageModePersistence.read(defaults) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults) == true)
    }

    // La decisión es pura y se pinnea en `ReverseUploadCeilingLogicTests`. Aquí, el CABLEADO: que las tres señales
    // lleguen al sitio que les toca. Se inyectan las tres siempre (los argumentos se evalúan eager y el default de
    // producción es `iCloudSyncService.shared`).

    @Test("reverseUploadBlocker: sin token de iCloud y sin error → icloudOff (copy honesto, presupuesto LARGO)")
    func reverseUploadBlocker_noTokenNoError_isICloudOff() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), FakeSession(token: "jwt", userID: "s"),
                                    FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { false },
                                    icloudLastExportErrorCode: { nil },
                                    icloudMirrorReportedNotAuthenticated: { false },
                                    icloudLastExportErrorAt: { nil },
                                    icloudLastSuccessfulExportAt: { nil })
        #expect(executor.reverseUploadBlocker() == .icloudOff)
        #expect(executor.reverseUploadBlocker().stallCause == .unknown)
    }

    @Test("reverseUploadBlocker: quotaExceeded → icloudFull; mirror no autenticado → icloudUnusable")
    func reverseUploadBlocker_cloudKitWord_isDefinitive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let failedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let full = makeExecutor(context, CloudSyncEngine(), RoutingStub(), FakeSession(token: "jwt", userID: "s"),
                                FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                icloudAccountPresent: { true },
                                icloudLastExportErrorCode: { .quotaExceeded },
                                icloudMirrorReportedNotAuthenticated: { false },
                                icloudLastExportErrorAt: { failedAt },
                                icloudLastSuccessfulExportAt: { failedAt.addingTimeInterval(-60) })
        #expect(full.reverseUploadBlocker() == .icloudFull)
        let unauthenticated = makeExecutor(
            context, CloudSyncEngine(), RoutingStub(), FakeSession(token: "jwt", userID: "s"),
            FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
            icloudAccountPresent: { true },
            icloudLastExportErrorCode: { nil },
            icloudMirrorReportedNotAuthenticated: { true },
            icloudLastExportErrorAt: { nil },
            icloudLastSuccessfulExportAt: { nil })
        #expect(unauthenticated.reverseUploadBlocker() == .icloudUnusable)
    }

    @Test("reverseUploadBlocker: un «iCloud lleno» ANTERIOR al último export con éxito ya no manda → unknown")
    func reverseUploadBlocker_errorOutdatedByASuccess_isUnknown() async throws {
        // El cableado de las dos fechas: si el executor pasara la del error como la del éxito (o no las pasara), el
        // latch de `lastExportError` volvería a acortar la espera a quien ya liberó espacio.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let failedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), FakeSession(token: "jwt", userID: "s"),
                                    FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { true },
                                    icloudLastExportErrorCode: { .quotaExceeded },
                                    icloudMirrorReportedNotAuthenticated: { false },
                                    icloudLastExportErrorAt: { failedAt },
                                    icloudLastSuccessfulExportAt: { failedAt.addingTimeInterval(60) })
        #expect(executor.reverseUploadBlocker() == .unknown)
    }

    @Test("reverseUploadBlocker: token presente y sin error → unknown (el caso normal de una subida lenta)")
    func reverseUploadBlocker_healthySignals_isUnknown() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let executor = makeExecutor(context, CloudSyncEngine(), RoutingStub(), FakeSession(token: "jwt", userID: "s"),
                                    FakeBeaconStore(), personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                    icloudAccountPresent: { true },
                                    icloudLastExportErrorCode: { nil },
                                    icloudMirrorReportedNotAuthenticated: { false },
                                    icloudLastExportErrorAt: { nil },
                                    icloudLastSuccessfulExportAt: { nil })
        #expect(executor.reverseUploadBlocker() == .unknown)
    }

    // MARK: - Muestreo de `reverseUpload` con filas SIN testigo (born-cloud, D15)

    /// Side-tables de CloudKit fabricadas a mano (molde de `CKIdentityCaptureTests`) para una sola `TransactionItem`:
    /// su `Z_ENT` y, si se pide, su fila de metadata con o sin nombre de registro.
    private func makeReverseUploadFixture(_ dir: URL, zpk: Int64, recordName: String?, withMetadata: Bool) -> URL {
        let url = dir.appendingPathComponent("ckfixture-reverse.sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        var statements = [
            "CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER, Z_NAME TEXT)",
            "INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME) VALUES (5, 'TransactionItem')",
            """
            CREATE TABLE ANSCKRECORDMETADATA
            (Z_PK INTEGER, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZCKRECORDNAME TEXT, ZRECORDZONE INTEGER)
            """,
            "CREATE TABLE ANSCKRECORDZONEMETADATA (Z_PK INTEGER, ZCKRECORDZONENAME TEXT, ZCKOWNERNAME TEXT)",
            "INSERT INTO ANSCKRECORDZONEMETADATA VALUES (2, 'com.apple.coredata.cloudkit.zone', '__defaultOwner__')",
        ]
        if withMetadata {
            let name = recordName.map { "'\($0)'" } ?? "NULL"
            statements.append("INSERT INTO ANSCKRECORDMETADATA VALUES (1, \(zpk), 5, \(name), 2)")
        }
        for sql in statements {
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "SQL: \(sql)")
        }
        sqlite3_close(db)
        return url
    }

    /// EL test de D15: una fila creada en ESTE teléfono por una cuenta nacida en la nube NO tiene testigo
    /// `SyncIdentity` (solo lo crean `backfillIdentities` y el pull de filas nuevas). Antes el muestreo emparejaba
    /// únicamente filas con testigo: cero pares ⇒ `.drained` ⇒ la vuelta a iCloud se daba por hecha sin comprobar
    /// nada. Ahora la fila entra con un testigo scratch: sin metadata de CloudKit cuenta como PENDIENTE, y con su
    /// nombre de registro cuenta como exportada. Y el testigo scratch no se persiste.
    @Test("reverseUploadStatus: fila viva SIN testigo (born-cloud) → pendiente hasta que CloudKit le da nombre")
    func reverseUploadStatus_unwitnessedRow_isPendingUntilExported() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let tx = TransactionItem(date: fixedNow, amount: -12.5, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0, "premisa: la fila no tiene testigo")
        let zpk = try #require(CKIdentityCapture.entityAndPK(for: tx.persistentModelID)?.zpk)

        let sinMetadata = makeReverseUploadFixture(dir, zpk: zpk, recordName: nil, withMetadata: false)
        let pendiente = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                     personalStoreURL: sinMetadata)
        #expect(pendiente.reverseUploadStatus() == .pending(count: 1),
                "sin metadata de CloudKit la fila no ha subido: la vuelta no puede darse por hecha")
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0, "el testigo scratch no se inserta")

        try FileManager.default.removeItem(at: sinMetadata)
        let exportada = makeReverseUploadFixture(dir, zpk: zpk, recordName: "rec-born-cloud", withMetadata: true)
        let drenado = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                   personalStoreURL: exportada)
        #expect(drenado.reverseUploadStatus() == .drained, "con nombre de registro, la fila ya está en CloudKit")
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0)
    }

    // MARK: - Un inventario que no pudo leer una tabla no es el corpus entero
    // (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`)
    //
    // Cada caso monta la avería con `_testInventoryFetchThrows` —que lanza un `CocoaError` dentro del `do` real— y lleva
    // su control: el MISMO escenario sin la avería da el desenlace bueno. Sin el control, el desenlace de la avería podría
    // venir de cualquier otra cosa del escenario.

    /// La captura de identidad de la ida. Su llamador SÍ puede fallar —`driveIdentity` convierte el `throw` en
    /// `.localFailure`— y la premisa del ticket, que decía lo contrario, era falsa. Antes la tabla se saltaba y la
    /// captura corría sobre un inventario parcial, con el breadcrumb contando `captured: 0` como si no hubiera nada.
    @Test("assignIdentity: una tabla ilegible en la captura lanza, no captura sobre un inventario parcial")
    func assignIdentity_unreadableInventoryTable_throws() async throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        context.insert(Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        try context.save()

        // Control: sin la avería la captura termina.
        let sano = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        try await sano.assignIdentity()

        // Una tabla de negocio…
        let enferma = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                   personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        enferma._testInventoryFetchThrows = { step, entity in step == "identity-capture" && entity == "Category" }
        await #expect(throws: MigrationExecutorError.inventoryUnreadable(entity: "Category")) {
            try await enferma.assignIdentity()
        }

        // …el backfill que corre antes, que se tragaba su error y dejaba filas sin identidad…
        defer { SyncIdentityService._testThrowOnBackfillFetchOf = [] }
        SyncIdentityService._testThrowOnBackfillFetchOf = ["Category"]
        let sinBackfill = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                       personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        await #expect(throws: CocoaError.self) { try await sinBackfill.assignIdentity() }
        SyncIdentityService._testThrowOnBackfillFetchOf = []

        // …y la de testigos, que antes devolvía `[]` entera: cero pares y ni una coordenada capturada.
        let sinTestigos = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                       personalStoreURL: dir.appendingPathComponent("personal.sqlite"))
        sinTestigos._testInventoryFetchThrows = { step, entity in step == "identity-capture" && entity == "SyncIdentity" }
        await #expect(throws: MigrationExecutorError.inventoryUnreadable(entity: "SyncIdentity")) {
            try await sinTestigos.assignIdentity()
        }
    }

    /// El guard anti-fusión del adopt. Con el backend VACÍO y una huérfana local, el adopt tiene que abortar
    /// (`.abortedEmptyBackend`); con la tabla ilegible el plan preliminar salía con `uploadCount == 0` y el guard, que
    /// existe para no fusionar dos corpus, se apagaba. Y como el plan definitivo también salía vacío, el adopt se
    /// declaraba completo.
    @Test("runAdoptOrphanReconcile: un inventario ilegible no apaga el guard anti-fusión — transient, sin mutar")
    func adoptReconcile_unreadablePrePlanInventory_isTransientNotCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        _ = makeCategory("orphan", syncID: UUID(), in: context)
        try context.save()
        stub.merkleBody = try makeMerkleBody([:])

        // Control: sin la avería, backend vacío + huérfana ⇒ el guard aborta.
        let sano = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                tombstoneSource: FakeTombstoneSource())
        #expect(await sano.runAdoptOrphanReconcile() == .abortedEmptyBackend,
                "control del escenario: con el inventario legible el guard SÍ salta")

        let enfermo = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                   personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                   tombstoneSource: FakeTombstoneSource())
        enfermo._testInventoryFetchThrows = { step, entity in step == "adopt-inventory" && entity == "Category" }
        #expect(await enfermo.runAdoptOrphanReconcile() == .transient,
                "ilegible no es «sin huérfanas»: se reintenta, no se cierra el adopt")
        #expect(stub.pushedSyncIDs.isEmpty, "nada se sube")
        #expect(try context.fetchCount(FetchDescriptor<SyncIdentity>()) == 0,
                "corta ANTES del backfill: sin testigos, igual que el guard")
    }

    /// La SEGUNDA lectura del inventario del adopt, la de después del backfill, y la que cerraba el adopt en falso:
    /// `guard !plan.orphans.isEmpty else { return .completed(uploaded: 0) }`, y el adopt no vuelve a pasar por ahí. El
    /// closure del seam es lo que la hace alcanzable: la primera lectura pasa y la segunda lanza.
    @Test("runAdoptOrphanReconcile: si el inventario post-backfill no se deja leer, el adopt no se da por completo")
    func adoptReconcile_unreadableDefinitiveInventory_isTransientNotCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let knownID = UUID(); let orphanID = UUID()
        _ = makeCategory("known", syncID: knownID, in: context)
        _ = makeCategory("orphan", syncID: orphanID, in: context)
        try context.save()
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: knownID, seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])

        let enfermo = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                   personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                   tombstoneSource: source)
        let lecturas = InventoryReadCounter()
        enfermo._testInventoryFetchThrows = { step, entity in
            guard step == "adopt-inventory", entity == "Category" else { return false }
            lecturas.value += 1
            return lecturas.value >= 2
        }
        #expect(await enfermo.runAdoptOrphanReconcile() == .transient,
                "con el plan definitivo ilegible el adopt se reintenta: `completed(0)` lo cerraba con la huérfana fuera")
        #expect(lecturas.value == 2, "control del seam: la primera lectura pasó y la segunda lanzó")
        #expect(stub.pushedSyncIDs.isEmpty, "nada se sube a ciegas")

        // Control: el mismo escenario, legible, sube la huérfana. Fuente nueva: la de arriba ya sirvió su página.
        let fuente = FakeTombstoneSource()
        fuente.pages = source.pages
        let sano = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                tombstoneSource: fuente)
        #expect(await sano.runAdoptOrphanReconcile() == .completed(uploaded: 1, identityAssigned: 0),
                "control del escenario: sin la avería la huérfana SÍ se sube")
        #expect(stub.pushedSyncIDs.map { $0.lowercased() } == [orphanID.uuidString.lowercased()])
    }

    /// El backfill entre los dos inventarios. Tragado, dejaba la fila SIN identidad, el diff la contaba como
    /// `needsIdentity` y no como huérfana, y el adopt cerraba `completed(0, 1)` sin subirla.
    @Test("runAdoptOrphanReconcile: si el backfill no termina, transient — no un adopt completo sin la fila")
    func adoptReconcile_backfillFails_isTransientNotCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        context.insert(Category(name: "window-nil", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false))
        try context.save()
        func source() -> FakeTombstoneSource {
            let s = FakeTombstoneSource()
            s.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
            return s
        }
        stub.merkleBody = try makeMerkleBody(["categories": 1])

        defer { SyncIdentityService._testThrowOnBackfillFetchOf = [] }
        SyncIdentityService._testThrowOnBackfillFetchOf = ["Category"]
        let enfermo = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                   personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                   tombstoneSource: source())
        #expect(await enfermo.runAdoptOrphanReconcile() == .transient)
        #expect(stub.pushedSyncIDs.isEmpty)

        // Control: con el backfill sano, la misma fila recibe identidad y se sube.
        SyncIdentityService._testThrowOnBackfillFetchOf = []
        let sano = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                tombstoneSource: source())
        #expect(await sano.runAdoptOrphanReconcile() == .completed(uploaded: 1, identityAssigned: 1))
    }

    /// El diff del panel DEBUG usa el mismo inventario: ilegible devuelve `nil` en vez de un diff parcial.
    @Test("adoptOrphanDryRun: un inventario ilegible no pinta un diff parcial")
    func adoptDryRun_unreadableInventory_isNil() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        _ = makeCategory("orphan", syncID: UUID(), in: context)
        try context.save()
        func source() -> FakeTombstoneSource {
            let s = FakeTombstoneSource()
            s.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: UUID(), seq: 1)], maxServerSeq: 1)]
            return s
        }
        stub.merkleBody = try makeMerkleBody(["categories": 1])

        let sano = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                personalStoreURL: dir.appendingPathComponent("personal.sqlite"), tombstoneSource: source())
        #expect(await sano.adoptOrphanDryRun()?.uploadCount == 1, "control: legible, el diff ve la huérfana")

        let enfermo = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                   personalStoreURL: dir.appendingPathComponent("personal.sqlite"), tombstoneSource: source())
        enfermo._testInventoryFetchThrows = { step, entity in step == "adopt-inventory" && entity == "Category" }
        #expect(await enfermo.adoptOrphanDryRun() == nil)
    }

    /// El fetch dirigido de las huérfanas. Saltar la tabla dejaba `inputs` sin sus filas, el outbox vivo vacío y el
    /// adopt `completed(uploaded: 0)`: las huérfanas de esa tabla no llegaban nunca al backend.
    @Test("runAdoptOrphanReconcile: si la tabla de las huérfanas no se deja leer al emitirlas, transient")
    func adoptReconcile_unreadableOrphanInputs_isTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = RoutingStub()
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let knownID = UUID()
        _ = makeCategory("known", syncID: knownID, in: context)
        _ = makeCategory("orphan", syncID: UUID(), in: context)
        try context.save()
        let source = FakeTombstoneSource()
        source.pages = [PulledPage(deltas: [upsertDelta(table: "categories", syncID: knownID, seq: 1)], maxServerSeq: 1)]
        stub.merkleBody = try makeMerkleBody(["categories": 1])

        let enfermo = makeExecutor(context, CloudSyncEngine(), stub, session, FakeBeaconStore(),
                                   personalStoreURL: dir.appendingPathComponent("personal.sqlite"),
                                   tombstoneSource: source)
        enfermo._testInventoryFetchThrows = { step, entity in step == "adopt-orphan-inputs" && entity == "Category" }
        #expect(await enfermo.runAdoptOrphanReconcile() == .transient)
        #expect(stub.pushedSyncIDs.isEmpty, "nada se sube")
        let live = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        #expect(live.isEmpty, "corta antes de encolar")
    }

    /// La muestra de la vuelta. Si la tabla ilegible era la de las filas pendientes, la muestra salía vacía y
    /// `.drained` cerraba la vuelta a iCloud con esos datos sin llegar. El control es el test de D15 de arriba: la misma
    /// fila, legible, cuenta como pendiente.
    @Test("reverseUploadStatus: una tabla ilegible en la muestra es .unreadable, no .drained")
    func reverseUploadStatus_unreadableTable_isUnreadableNotDrained() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = FakeSession(token: "jwt", userID: "sub-1")
        let tx = TransactionItem(date: fixedNow, amount: -12.5, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        let zpk = try #require(CKIdentityCapture.entityAndPK(for: tx.persistentModelID)?.zpk)
        let sinMetadata = makeReverseUploadFixture(dir, zpk: zpk, recordName: nil, withMetadata: false)

        let sano = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                personalStoreURL: sinMetadata)
        #expect(sano.reverseUploadStatus() == .pending(count: 1), "control del escenario: la fila está pendiente")

        let enfermo = makeExecutor(context, CloudSyncEngine(), RoutingStub(), session, FakeBeaconStore(),
                                   personalStoreURL: sinMetadata)
        enfermo._testInventoryFetchThrows = { step, entity in step == "reverse-sample" && entity == "TransactionItem" }
        #expect(enfermo.reverseUploadStatus() == .unreadable,
                "sin la tabla la muestra contaba cero pendientes y daba la vuelta por hecha")
    }

    /// El canario de metadata huérfana. Con el `Set` vacío de antes, toda la metadata de una tabla ilegible contaba como
    /// huérfana; ahora la tabla se queda sin key y el escáner la ignora, como a una entidad no cableada.
    @Test("collectLiveByEntityName: una tabla ilegible se queda SIN key, no con un Set vacío")
    func collectLiveByEntityName_unreadableTable_hasNoKey() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.insert(Tag(name: "t"))
        try context.save()

        let sano = MigrationWorkExecutor.collectLiveByEntityName(context: context)
        #expect(sano["Tag"]?.count == 1, "control: legible, la key está y trae la fila")
        #expect(sano["Category"] == [], "control: sin filas, la key está con un Set vacío (contrato RP-4)")

        let enfermo = MigrationWorkExecutor.collectLiveByEntityName(context: context, throwingOn: { $0 == "Tag" })
        #expect(enfermo["Tag"] == nil, "ilegible: sin key, o toda su metadata contaría como huérfana")
        #expect(enfermo["Category"] == [], "las demás tablas siguen con su key")
        #expect(enfermo.count == sano.count - 1)
    }
}

/// Caja para contar desde el closure del seam: el closure se guarda en el ejecutor y la cuenta tiene que sobrevivir a él.
@MainActor
private final class InventoryReadCounter {
    var value = 0
}
