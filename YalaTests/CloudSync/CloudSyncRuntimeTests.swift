//
//  CloudSyncRuntimeTests.swift
//  YalaTests / CloudSync
//
//  Orquestador del motor (I9): stub de sesión + clients con `SyncHTTPSession` stub. Cubre orden de
//  arranque (rehydrate), gate del flag, teardown M1, poison-row (#26) aislado, gates de sesión (401 /
//  preflight) y cuenta (403), fan-out post-apply, remediación Merkle (una vez), y el gate puro de claim.
//  Container ON-DISK temp con los 3 stores (patrón SyncApplyEngineTests). `.serialized` (≥2 containers).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSyncRuntime · orquestador I9", .serialized)
@MainActor
struct CloudSyncRuntimeTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CSRuntime-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CSR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CSR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CSR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ c: Int) -> String { "2023-11-14T22:13:20.000Z-\(String(format: "%04x", c))-\(node)" }
    private let epochTS = "2023-11-14T22:13:20.000Z"

    private func emptyPageJSON() -> Data { Data(#"{"deltas":[],"max_server_seq":0}"#.utf8) }

    private func txPageJSON(sid: UUID, serverSeq: Int, h: String) -> Data {
        Data(#"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"10.5000","currency_code":"USD","note":"r",
        "amount_in_preferred_currency":"38.0000","preferred_currency_code":"PEN","exchange_rate":"3.62000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)","tag_refs":[]},
        "field_hlcs":{"money":"\#(h)","date":"\#(h)","note":"\#(h)","currency_code":"\#(h)","tag_refs":"\#(h)","created_at":"\#(h)"},
        "hlc":"\#(h)","server_seq":\#(serverSeq),"schema_version":1}],"max_server_seq":\#(serverSeq)}
        """#.utf8)
    }

    /// Respuesta push 200 marcando `rows` como `applied` (echoa cada `client_mutation_id`).
    private func pushAppliedJSON(_ rows: [SyncOutbox]) -> Data {
        let results = rows.map {
            "{\"sync_id\":\"\($0.syncID.uuidString.lowercased())\",\"client_mutation_id\":\"\($0.clientMutationID.uuidString.lowercased())\",\"status\":\"applied\"}"
        }.joined(separator: ",")
        return Data("{\"results\":[\(results)]}".utf8)
    }

    private func liveRow(_ context: ModelContext, entityType: String, h: String) -> SyncOutbox {
        let row = SyncOutbox(syncID: UUID(), entityType: entityType, op: .upsert, hlc: h,
                             clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: "{}", author: "")
        context.insert(row)
        try? context.save()
        return row
    }

    private func outbox(_ context: ModelContext) -> [SyncOutbox] {
        (try? context.fetch(FetchDescriptor<SyncOutbox>())) ?? []
    }

    /// Construye un runtime con clients stubbeados (push/pull/merkle) y sesión stub. Los `@MainActor`
    /// (engine/coordinator/session) se crean en el CUERPO (main actor), no en default args (nonisolated).
    private func makeRuntime(
        engine: CloudSyncEngine? = nil,
        push: SyncHTTPSession? = nil,
        pull: StubSession? = nil,
        merkle: StubSession? = nil,
        mirror: SyncOutboxMirror? = nil,
        coordinator: SyncQuiescenceCoordinator? = nil,
        session: StubCloudSession? = nil,
        onRemoteChangesApplied: (() -> Void)? = nil,
        prefsSession: StubSession? = nil,
        prefsOutbox: PrefsOutbox? = nil
    ) -> CloudSyncRuntime {
        CloudSyncRuntime(
            engine: engine ?? CloudSyncEngine(),
            pushClient: SyncPushClient(baseURL: URL(string: "https://x.test")!, tokenProvider: { "jwt" }, urlSession: push ?? StubSession()),
            pullClient: SyncPullClient(baseURL: URL(string: "https://x.test")!, tokenProvider: { "jwt" }, urlSession: pull ?? StubSession()),
            merkleClient: SyncMerkleClient(baseURL: URL(string: "https://x.test")!, tokenProvider: { "jwt" }, urlSession: merkle ?? StubSession()),
            mirror: mirror,
            coordinator: coordinator ?? SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud }),
            session: session ?? StubCloudSession(),
            onRemoteChangesApplied: onRemoteChangesApplied,
            prefsClient: prefsSession.map {
                PrefsSyncClient(baseURL: URL(string: "https://x.test")!, tokenProvider: { "jwt" }, urlSession: $0)
            },
            prefsOutbox: prefsOutbox
        )
    }

    // MARK: - Gate del flag

    @Test func start_flagOff_isNoOp() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = false
        defer { CloudSyncFlags.syncRuntimeEnabled = prev }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(userID: "u1"))
        await runtime.start(context: context)
        #expect(runtime.state == .idle)  // ni idleSignedOut ni running: no-op TOTAL
    }

    @Test func start_noSession_idleSignedOut() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        // P0 (I14): en `.icloud` el domain-gate corta ANTES del chequeo de sesión → este test exige `.cloud`.
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(userID: nil))
        await runtime.start(context: context)
        #expect(runtime.state == .idleSignedOut)
    }

    // MARK: - P0/P6 (I14): gates del DOMINIO y de IDENTIDAD cableados en start()

    /// P0 cableado: `.icloud` (default de TODO device de producción post-encendido del flag) con sesión
    /// y claim VÁLIDOS → `.idle` sin tocar sesión/red/store — la prueba de que encender
    /// `syncRuntimeEnabled` no cambia el comportamiento de los usuarios actuales.
    /// (El caso `.cloud`+fase TRANSICIONAL comparte esta misma línea de guard; su matriz de fases es
    /// exhaustiva en `CloudMigrationI14Tests.isDomainStablePhase` — no se re-ejercita aquí porque el
    /// override de fase del singleton escribe `UserDefaults.standard`, prohibido en tests.)
    @Test func start_icloudMode_domainGateIdles() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        defer { CloudSyncFlags.syncRuntimeEnabled = prev }
        // storageMode queda en su default `.icloud` — ES el caso bajo test.

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(userID: "u1", claim: .proceedMigration))
        await runtime.start(context: context)
        #expect(runtime.state == .idle)
        #expect(outbox(context).isEmpty)  // ni rehydrate ni drain corrieron
    }

    /// P6 cableado (guard de IDENTIDAD): `.cloud` + sesión SIN registro de claim (`claimAction == nil`,
    /// el user-switch de un Apple ID ajeno en un device migrado) → `.idle`, jamás arranca.
    @Test func start_cloudUnclaimedIdentity_idles() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(userID: "user-b", claim: nil))
        await runtime.start(context: context)
        #expect(runtime.state == .idle)
    }

    /// Positivo: `.cloud` + fase estable (`.notStarted` sin journal) + sesión con claim proceed-like →
    /// el runtime ARRANCA (cadencia viva).
    @Test func start_cloudStableWithClaim_runs() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1", claim: .routeReturningUser))
        await runtime.start(context: context)
        #expect(runtime.state == .running)
        runtime.teardownGuestSession()  // detener la cadencia async
    }

    // MARK: - S1 (review I13): el paso de prefs del ciclo está gateado por storageMode

    /// En `.icloud` (default SSOT hoy), el paso 5.5 de prefs NO corre aunque las deps estén cableadas
    /// y haya entries pendientes — sin este gate, un device de SPIKE (.icloud + runtime ON) haría
    /// split-brain: escrituras a iKV, lecturas del backend (y los markers de staging pisarían prefs
    /// reales). Regresión del fix S1.
    @Test func syncCycle_prefsStep_gatedOff_inICloudMode() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        defer { CloudSyncFlags.syncRuntimeEnabled = prev }
        // CloudSyncFlags.storageMode queda en su default `.icloud` — es el caso bajo test.

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prefsDir = freshDir(); defer { cleanup(prefsDir) }
        let prefsOutbox = PrefsOutbox(directoryURL: prefsDir)
        try prefsOutbox.enqueue(key: "userName", userID: "u1", value: .string("Spike"),
                                now: Date(timeIntervalSince1970: 1_700_000_000))
        let prefsSession = StubSession(
            status: 200, body: Data(#"{"results":[{"key":"userName","status":"applied"}]}"#.utf8))
        let runtime = makeRuntime(session: StubCloudSession(userID: "u1"),
                                  prefsSession: prefsSession, prefsOutbox: prefsOutbox)
        _ = await runtime.syncCycle(context: context)

        #expect(prefsSession.callCount == 0)                      // ni push ni pull de prefs
        #expect(prefsOutbox.entries(forUserID: "u1").count == 1)  // la entry sigue: no se purgó nada
        #expect(prefsOutbox.pullCursor == 0)
    }

    /// Contraparte: en `.cloud` el paso SÍ corre (el gate no convierte el sync de prefs en dead code).
    @Test func syncCycle_prefsStep_runs_inCloudMode() async throws {
        let prevFlag = CloudSyncFlags.syncRuntimeEnabled
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.syncRuntimeEnabled = true
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prevFlag
            CloudSyncFlags.storageMode = prevMode
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prefsDir = freshDir(); defer { cleanup(prefsDir) }
        let prefsOutbox = PrefsOutbox(directoryURL: prefsDir)
        try prefsOutbox.enqueue(key: "userName", userID: "u1", value: .string("Nube"),
                                now: Date(timeIntervalSince1970: 1_700_000_000))
        let prefsSession = StubSession(
            status: 200, body: Data(#"{"results":[{"key":"userName","status":"applied"}]}"#.utf8))
        let runtime = makeRuntime(session: StubCloudSession(userID: "u1"),
                                  prefsSession: prefsSession, prefsOutbox: prefsOutbox)
        _ = await runtime.syncCycle(context: context)

        #expect(prefsSession.callCount >= 1)                      // el paso corrió
        #expect(prefsOutbox.entries(forUserID: "u1").isEmpty)     // applied → purgada del outbox
    }

    // MARK: - Gate puro de claim (AccountClaimDecision)

    @Test func shouldStartSync_proceedLikeActions() {
        #expect(CloudSyncRuntime.shouldStartSync(after: .seedBornCloud))
        #expect(CloudSyncRuntime.shouldStartSync(after: .proceedMigration))
        #expect(CloudSyncRuntime.shouldStartSync(after: .routeReturningUser))
        #expect(!CloudSyncRuntime.shouldStartSync(after: .waitForLeader))
        #expect(!CloudSyncRuntime.shouldStartSync(after: .showProviderMismatch))
    }

    // MARK: - Arranque: rehydrate del espejo corre en start()

    @Test func start_rehydratesOutboxFromMirror() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        // P0/P6 (I14): el arranque exige `.cloud` + claim proceed-like para llegar al rehydrate.
        CloudSyncFlags.storageMode = .cloud
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("mirror", isDirectory: true)
        let mirror = SyncOutboxMirror(directoryURL: mirrorDir)
        // Sembrar una entry huérfana del userID (fila que una migración se llevó del store).
        let sid = UUID()
        try mirror.write(OutboxMirrorEntry(
            userID: "u1", syncID: sid, entityType: SyncEntityType.transactionItem, op: "upsert",
            hlc: hlc(1), clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: "{}",
            tombstoneReason: nil, author: SyncOutboxMirror.author, createdAt: .now))

        let context = try makeContext(dir)
        let runtime = makeRuntime(pull: StubSession(body: emptyPageJSON()),
                                  mirror: mirror,
                                  session: StubCloudSession(userID: "u1", claim: .proceedMigration))
        await runtime.start(context: context)
        runtime.teardownGuestSession()  // detener la cadencia async

        // La fila del espejo se re-insertó en el outbox durante el arranque.
        #expect(outbox(context).contains { $0.syncID == sid })
    }

    // MARK: - Teardown M1

    @Test func teardownGuestSession_purgesMirror() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("mirror", isDirectory: true)
        let mirror = SyncOutboxMirror(directoryURL: mirrorDir)
        try mirror.write(OutboxMirrorEntry(
            userID: "u1", syncID: UUID(), entityType: SyncEntityType.transactionItem, op: "upsert",
            hlc: hlc(1), clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: "{}",
            tombstoneReason: nil, author: SyncOutboxMirror.author, createdAt: .now))
        #expect(!mirror.entriesForUser("u1").isEmpty)

        let runtime = makeRuntime(mirror: mirror)
        runtime.teardownGuestSession()

        #expect(mirror.entriesForUser("u1").isEmpty)  // espejo purgado (M1(a))
        #expect(runtime.state == .idleSignedOut)
    }

    // MARK: - Poison-row (#26): aisla y el resto sube

    @Test func syncCycle_poisonRow_deadLettered_restUploads() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let good = liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))  // buildable
        // Poison = clase SIN mapeo a tabla Postgres (`table(forClass:)` → nil). `Budget` YA no sirve
        // (cableada en I12 commit A); un literal inexistente delata igual el path de dead-letter.
        let bad = liveRow(context, entityType: "LegacyUnmappedEntity", h: hlc(2))

        let push = StubSession(body: pushAppliedJSON([good]))
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        _ = await runtime.syncCycle(context: context)

        let rows = outbox(context)
        // La fila buildable se subió y purgó; la poison quedó dead-letter (no se subió, no se perdió).
        #expect(!rows.contains { $0.syncID == good.syncID })
        let deadLetter = rows.first { $0.syncID == bad.syncID }
        #expect(deadLetter?.rejectedReason == "unbuildable:LegacyUnmappedEntity")
    }

    // MARK: - Gates de sesión / cuenta

    @Test func syncCycle_push401_sessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime = makeRuntime(push: StubSession(status: 401),
                                  session: StubCloudSession(userID: "u1", canRenew: true))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .sessionExpired)
    }

    @Test func syncCycle_push403_accountUnavailable_noRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime = makeRuntime(push: StubSession(status: 403),
                                  session: StubCloudSession(userID: "u1", canRenew: true))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .accountUnavailable)  // → stopUntilRelaunch en la policy (sin loop)
    }

    @Test func syncCycle_sessionExpiryPreflight_blocksWhenNotRenewable() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        // Pendientes + no renovable → estado accionable ANTES del push (el push stub no se consulta).
        let runtime = makeRuntime(push: StubSession(status: 200, body: Data("{\"results\":[]}".utf8)),
                                  session: StubCloudSession(userID: "u1", canRenew: false))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .sessionExpired)
    }

    // MARK: - Fan-out post-apply

    @Test func syncCycle_fanOut_firesOnlyWhenPagesApplied() async throws {
        let dir = freshDir(); defer { cleanup(dir) }

        // (a) pull con 1 delta → pagesApplied>0 → fan-out dispara.
        let context1 = try makeContext(dir)
        var applied1 = 0
        let runtime1 = makeRuntime(pull: StubSession(body: txPageJSON(sid: UUID(), serverSeq: 5, h: hlc(1))),
                                   session: StubCloudSession(userID: "u1"),
                                   onRemoteChangesApplied: { applied1 += 1 })
        _ = await runtime1.syncCycle(context: context1)
        #expect(applied1 == 1)

        // (b) pull vacío → pagesApplied==0 → NO dispara.
        let dir2 = freshDir(); defer { cleanup(dir2) }
        let context2 = try makeContext(dir2)
        var applied2 = 0
        let runtime2 = makeRuntime(pull: StubSession(body: emptyPageJSON()),
                                   session: StubCloudSession(userID: "u1"),
                                   onRemoteChangesApplied: { applied2 += 1 })
        _ = await runtime2.syncCycle(context: context2)
        #expect(applied2 == 0)
        cleanup(dir)
    }

    // MARK: - Remediación Merkle (E-bis): una vez por sesión, sin loop

    @Test func merkleRemediation_divergedOncePerSession() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true  // satisface el guard A-3 (store vacío, outbox vacío)

        // Snapshot remoto que DIVERGE en tx_items (las otras 5 cableadas = hash vacío = local vacío).
        let emptyHex = SyncMerkle.hexString(SyncMerkle.emptyDigest)
        let entitiesJSON = EntityApplyMap.wiredTables.map { table -> String in
            let h = (table == EntityApplyMap.transactionItem.table) ? "00ff00ff00ff" : emptyHex
            return "\"\(table)\":{\"count\":0,\"hash\":\"\(h)\"}"
        }.joined(separator: ",")
        let merkleJSON = Data("{\"canon_version\":\"c1\",\"capability_set\":\"v1\",\"root\":\"deadbeef\",\"entities\":{\(entitiesJSON)}}".utf8)

        let pull = StubSession(body: emptyPageJSON())  // el re-pull de remediación es no-op (empty)
        let runtime = makeRuntime(engine: engine, pull: pull, merkle: StubSession(body: merkleJSON),
                                  session: StubCloudSession(userID: "u1"))

        let v1 = await runtime.runMerkleVerification(context: context)
        #expect(v1 == .diverged(entities: ["tx_items"]))
        #expect(pull.callCount == 1)  // UNA remediación (re-pull)

        let v2 = await runtime.runMerkleVerification(context: context)
        #expect(v2 == .diverged(entities: ["tx_items"]))  // sigue divergiendo (verdadera)
        #expect(pull.callCount == 1)  // NO vuelve a remediar (throttle una-vez-por-sesión)
    }

    // MARK: - SERIO-2: teardown durante un push suspendido → resultados NO se aplican

    @Test func teardownDuringSuspendedPush_abortsWithoutApplyingResults() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))

        // Push stub que SUSPENDE hasta `release()` — simula un request en vuelo durante el teardown.
        let gated = GatedSession(body: pushAppliedJSON([row]))
        let runtime = makeRuntime(push: gated,
                                  pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))

        let cycleTask = Task { await runtime.syncCycle(context: context) }
        await gated.waitUntilRequestStarted()   // el push está suspendido en el await del transporte
        runtime.teardownGuestSession()          // epoch++ mientras el push sigue en vuelo
        gated.release()                         // el transporte responde 200 applied... demasiado tarde
        let outcome = await cycleTask.value

        // El ciclo abortó SIN aplicar los resultados: la fila NO se purgó/confirmó post-teardown,
        // y el outcome no lleva señal de cadencia (el loop ya está cancelado).
        #expect(outcome == .coalesced)
        let rows = outbox(context)
        #expect(rows.contains { $0.syncID == row.syncID && $0.rejectedReason == nil },
                "la fila debe seguir viva: los resultados de un push post-teardown NO se aplican")
    }

    // MARK: - Purga de History (§i.6, doble-DARK)

    @Test func purgeHistoryOnce_respectsSafeCut_withUnconfirmedOutboxRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Generar history real: un save de dominio.
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000),
                                 amount: -5, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        let historyBefore = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(historyBefore > 0)

        // Fila de outbox SIN confirmar con createdAt en el pasado remoto → el corte queda EN ella:
        // nada por delante de la fila sin-2xx más vieja se purga (invariante §d.5).
        let unconfirmed = SyncOutbox(syncID: UUID(), entityType: SyncEntityType.transactionItem,
                                     op: .upsert, hlc: hlc(1), fieldsJSON: "{}", author: "",
                                     createdAt: .distantPast)
        context.insert(unconfirmed)
        try context.save()

        let purged = engine.purgeHistoryOnce(context: context, now: .now)
        #expect(purged == nil)  // corte = distantPast → 0 transacciones por delante → no purga
        let historyAfter = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(historyAfter >= historyBefore)  // history INTACTA (el insert del outbox pudo sumar)

        // Al confirmar (purgar) la fila, el corte avanza a `now` → TODO lo anterior se purga.
        engine.confirmUploaded(syncID: unconfirmed.syncID, hlc: hlc(1), context: context)
        let purged2 = engine.purgeHistoryOnce(context: context, now: .now)
        #expect((purged2 ?? 0) > 0)
        let historyFinal = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(historyFinal == 0)
    }

    /// Prepara un contexto con history real y el outbox VACÍO (drain + confirm), para que el ciclo del
    /// runtime no necesite push (el corte de la purga queda en `now`, sin fila sin-2xx que lo frene).
    private func seedHistoryWithEmptyOutbox(engine: CloudSyncEngine, context: ModelContext) throws {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000),
                                 amount: -5, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        for row in outbox(context) {
            engine.confirmUploaded(syncID: row.syncID, hlc: row.hlc, context: context)
        }
    }

    @Test func syncCycle_purgeFlagOff_doesNotPurgeHistory() async throws {
        // Default de producción: `historyPurgeEnabled == false` → un ciclo completed NO purga.
        let prev = CloudSyncFlags.historyPurgeEnabled
        CloudSyncFlags.historyPurgeEnabled = false
        defer { CloudSyncFlags.historyPurgeEnabled = prev }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        let historyBefore = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(historyBefore > 0)

        let runtime = makeRuntime(engine: engine, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .completed)
        let history = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(history >= historyBefore)  // NADA purgado con el flag off
    }

    @Test func syncCycle_bothFlagsOn_purgesHistoryAfterCompletedCycle() async throws {
        let prev = CloudSyncFlags.historyPurgeEnabled
        CloudSyncFlags.historyPurgeEnabled = true
        defer { CloudSyncFlags.historyPurgeEnabled = prev }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        #expect(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count > 0)

        let runtime = makeRuntime(engine: engine, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        // Ciclo completed (outbox vacío → sin push; pull vacío) + ambos flags → purga hasta `now`.
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .completed)
        let history = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(history == 0)
    }
}

// MARK: - Stubs

/// Stub de `SyncHTTPSession` con respuesta fija + contador de llamadas.
private final class StubSession: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    let body: Data
    private(set) var callCount = 0
    init(status: Int = 200, body: Data = Data(#"{"deltas":[],"max_server_seq":0}"#.utf8)) {
        self.status = status
        self.body = body
    }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

/// Stub de `SyncHTTPSession` que SUSPENDE la respuesta hasta `release()` (SERIO-2: teardown durante un
/// request en vuelo). Determinista: `waitUntilRequestStarted()` señala cuándo el request quedó
/// suspendido — sin sleeps. Bajo `NonisolatedNonsendingByDefault` todos sus métodos corren en el actor
/// del caller (MainActor en estos tests) → el estado mutable no se toca concurrentemente.
private final class GatedSession: SyncHTTPSession, @unchecked Sendable {
    private let body: Data
    private var started = false
    private var released = false
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var gateContinuation: CheckedContinuation<Void, Never>?

    init(body: Data) { self.body = body }

    /// Suspende hasta que `data(for:)` haya ENTRADO (el push está en vuelo).
    func waitUntilRequestStarted() async {
        if started { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    /// Libera el request suspendido (el transporte "responde").
    func release() {
        released = true
        gateContinuation?.resume()
        gateContinuation = nil
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        started = true
        startedContinuation?.resume()
        startedContinuation = nil
        if !released {
            await withCheckedContinuation { gateContinuation = $0 }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

/// Stub del seam de sesión (I7c).
@MainActor
private final class StubCloudSession: CloudSyncSessionProviding {
    var currentUserID: String?
    var canRenewSession: Bool
    var attestError: AppAttestError?
    var claimAction: AccountClaimDecision.AuthAction?
    init(userID: String? = "u1", canRenew: Bool = true, attestError: AppAttestError? = nil,
         claim: AccountClaimDecision.AuthAction? = nil) {
        self.currentUserID = userID
        self.canRenewSession = canRenew
        self.attestError = attestError
        self.claimAction = claim
    }
    func accessToken() async -> String? { "jwt" }
    func attestToken() async throws -> String? {
        if let attestError { throw attestError }
        return nil
    }
}
