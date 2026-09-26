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

    /// **El `save` PROPAGA desde el 2026-09-22** (mismo ticket que el helper de abajo): con `try?`, un save que
    /// falla dejaba el escenario sin fila y en silencio — un test que cree estar midiendo «con filas vivas»
    /// midiendo el caso vacío. Si el save falla, el test debe caerse.
    private func liveRow(_ context: ModelContext, entityType: String, h: String) throws -> SyncOutbox {
        let row = SyncOutbox(syncID: UUID(), entityType: entityType, op: .upsert, hlc: h,
                             clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: "{}", author: "")
        context.insert(row)
        try context.save()
        return row
    }

    /// **Propaga desde el 2026-09-22** (ticket `verify-reads-a-failed-local-fetch-as-an-empty-outbox`): era un
    /// `try?` con `?? []`, el mismo antipatrón que ese ticket arregla en producción, y aquí hacía de CONTROL DE
    /// ESCENARIO —`#expect(outbox(context).isEmpty)` con el comentario «ni rehydrate ni drain corrieron»—. Un
    /// fetch que lanzara habría dado «outbox vacío» y el control habría certificado una premisa falsa.
    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
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
        prefsOutbox: PrefsOutbox? = nil,
        clientToken: String? = "jwt",
        clientSessionKept: Bool = false
    ) -> CloudSyncRuntime {
        CloudSyncRuntime(
            engine: engine ?? CloudSyncEngine(),
            pushClient: SyncPushClient(baseURL: URL(string: "https://x.test")!, tokenProvider: { clientToken },
                                       urlSession: push ?? StubSession(), canRenewSession: { clientSessionKept }),
            pullClient: SyncPullClient(baseURL: URL(string: "https://x.test")!, tokenProvider: { clientToken },
                                       urlSession: pull ?? StubSession(),
                                       canRenewSession: { clientSessionKept }),
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
        // A3 (D-A7): el testigo del mount es `.icloud` por default en el host de tests, y el guard nuevo lo
        // lee ⇒ hay que declarar el device como YA RELANZADO (que es el escenario de todo test que llegue
        // al arranque). Restaurar SIEMPRE: es estado global de proceso.
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
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
        #expect(try outbox(context).isEmpty)  // ni rehydrate ni drain corrieron
    }

    /// P6 cableado (guard de IDENTIDAD): `.cloud` + sesión SIN registro de claim (`claimAction == nil`,
    /// el user-switch de un Apple ID ajeno en un device migrado) → `.idle`, jamás arranca.
    @Test func start_cloudUnclaimedIdentity_idles() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)  // A3: device ya relanzado
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
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
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)  // A3: device ya relanzado
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1", claim: .routeReturningUser))
        await runtime.start(context: context)
        #expect(runtime.state == .running)
        runtime.teardownGuestSession()  // detener la cadencia async
    }

    // MARK: - La identidad que el espejo cambió en la ventana del adopt

    /// Ticket `adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`. Tras el remonte de un adopt, el
    /// arranque devuelve la identidad que el espejo cambió entre el reconcile y el remonte ANTES de su primer drain. Sin eso,
    /// la edición que trajo el import salía de ese drain bajo la identidad nueva: una fila aparte en el backend.
    @Test func start_afterAnAdopt_restoresTheRekeyedIdentityBeforeTheFirstDrain() async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)  // A3: device ya relanzado
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let ledgerURL = dir.appendingPathComponent("relay-identity-ledger.json")
        engine.relayIdentityLedgerURL = ledgerURL
        let backendID = UUID()
        let category = Category(name: "del backend", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        category.syncID = backendID
        context.insert(category)
        context.insert(SyncIdentity(syncID: backendID, entityType: SyncEntityType.category, localAnchor: "a"))
        try context.save()
        let key = try #require(RelayIdentityLedger.key(for: category.persistentModelID))
        try RelayIdentityLedger.merge([key: backendID], into: ledgerURL)
        try RelayIdentityLedger.markAdoptPin(ledgerURL)
        try RelayIdentityLedger.writeAdoptBackendKnown([backendID], for: ledgerURL)
        engine.fastForwardHistoryBaseline(context: context)
        // El import del espejo antes del remonte: la identidad del líder desplazado y su edición.
        category.syncID = UUID()
        category.name = "editada por el líder"
        context.author = "NSCloudKitMirroringDelegate.import"
        try context.save()
        context.author = nil

        let runtime = makeRuntime(engine: engine, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1", claim: .routeReturningUser))
        await runtime.start(context: context)
        defer { runtime.teardownGuestSession() }
        #expect(runtime.state == .running)
        #expect(category.syncID == backendID)
        // Restaurada ANTES del primer drain, la fila lleva una identidad que el backend conoce y la edición vieja que trajo el
        // espejo no sale (ticket `adopt-window-late-imports-overwrite-newer-cloud-edits`). Restaurada después, saldría con la
        // del líder.
        let upserts = try outbox(context).filter { $0.opRaw == SyncOutboxOp.upsert.rawValue }.map(\.syncID)
        #expect(upserts.isEmpty, "ni con la identidad del líder ni con la del backend: manda el backend")
        #expect(!RelayIdentityLedger.hasAdoptBackendKnown(for: ledgerURL), "control: el primer drain corrió entero y la retiró")
        #expect(!RelayIdentityLedger.isAdoptPinned(ledgerURL))
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
        // Con el sello del claim, como toda sesión que cicla en la nube: desde el 2026-09-25 un motor sin dueño en memoria
        // no cicla con una sesión sin sello (`sessionBelongsToAnotherAccount`), y `start()` ya lo exigía.
        let runtime = makeRuntime(session: StubCloudSession(userID: "u1", claim: .routeReturningUser),
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
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)  // A3: device ya relanzado
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
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
        #expect(try outbox(context).contains { $0.syncID == sid })
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
        let good = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))  // buildable
        // Poison = clase SIN mapeo a tabla Postgres (`table(forClass:)` → nil). `Budget` YA no sirve
        // (cableada en I12 commit A); un literal inexistente delata igual el path de dead-letter.
        let bad = try liveRow(context, entityType: "LegacyUnmappedEntity", h: hlc(2))

        let push = StubSession(body: pushAppliedJSON([good]))
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        _ = await runtime.syncCycle(context: context)

        let rows = try outbox(context)
        // La fila buildable se subió y purgó; la poison quedó dead-letter (no se subió, no se perdió).
        #expect(!rows.contains { $0.syncID == good.syncID })
        let deadLetter = rows.first { $0.syncID == bad.syncID }
        #expect(deadLetter?.rejectedReason == "unbuildable:LegacyUnmappedEntity")
    }

    // MARK: - El outbox que no se deja leer (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`)

    /// El tercer helper homónimo, y el que corre en cada ciclo del motor. Con el `[]` de su `catch`, un outbox
    /// ilegible se leía como «no hay nada que subir»: el ciclo se saltaba el push, pasaba al pull y devolvía el
    /// veredicto de ÉSTE —normalmente un `.completed` de página vacía—. La cadencia recibía «todo bien» sobre una
    /// avería, y las filas pendientes esperaban a que la lectura volviera sola.
    ///
    /// Aquí el desenlace correcto es `.transient` y no un `blocked`: el motor tiene backoff y reintenta él solo,
    /// que es lo único honesto que se puede hacer sin saber qué hay. El daño dura un ciclo, no una migración — y
    /// esa es justo la razón de que el trato sea otro.
    ///
    /// Las dos aserciones que cargan el peso son la del `callCount` a cero (el push NO se pidió a ciegas) y el
    /// control del final: con el store legible, el mismo escenario sube la fila y cierra.
    @Test("syncCycle: un outbox ilegible corta el ciclo en vez de seguir al pull como si estuviera limpio")
    func syncCycle_unreadableOutbox_isTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))

        let push = StubSession(status: 200, body: Data(#"{"results":[]}"#.utf8))
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(push: push, pull: pull, session: StubCloudSession(userID: "u1", canRenew: true))
        runtime._testThrowOnOutboxFetch = true

        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .transient, "el ciclo se reintenta; no se declara nada sobre un outbox sin leer")
        #expect(push.callCount == 0, "no se sube a ciegas")
        #expect(pull.callCount == 0, "y NO se sigue al pull: ése es el `[]` que este ticket quita")

        // Control en la dirección contraria: sin la avería el mismo ciclo llega al push y al pull.
        runtime._testThrowOnOutboxFetch = false
        _ = await runtime.syncCycle(context: context)
        #expect(push.callCount > 0, "control: sin la avería la fila viva SÍ se sube")
    }

    // MARK: - Gates de sesión / cuenta

    @Test func syncCycle_push401_sessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime = makeRuntime(push: StubSession(status: 401),
                                  session: StubCloudSession(userID: "u1", canRenew: true))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .sessionExpired)
    }

    @Test func syncCycle_push403_accountUnavailable_noRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime = makeRuntime(push: StubSession(status: 403),
                                  session: StubCloudSession(userID: "u1", canRenew: true))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .accountUnavailable)  // → stopUntilRelaunch en la policy (sin loop)
    }

    @Test func syncCycle_sessionExpiryPreflight_blocksWhenNotRenewable() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        // Pendientes + no renovable → estado accionable ANTES del push (el push stub no se consulta).
        let runtime = makeRuntime(push: StubSession(status: 200, body: Data("{\"results\":[]}".utf8)),
                                  session: StubCloudSession(userID: "u1", canRenew: false))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .sessionExpired)
    }

    // MARK: - Sin red con el token vencido: pasajero, no sesión caducada (2026-09-16)

    // Ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`. Sin red la renovación no vuelve y el SDK
    // CONSERVA la sesión. El ciclo devolvía `.sessionExpired`, la cadencia paraba con `stopUntilSignIn` hasta volver a
    // primer plano (y con ella Grupos, que en `.cloud` cicla dentro de este runtime) y Ajustes pedía iniciar sesión.

    @Test("MUTACIÓN: push sin token con la sesión guardada → `.transient` y backoff; con la sesión borrada, caducada")
    func syncCycle_pushWithoutToken_followsTheStoredSession() async throws {
        // La puerta del stub da token y borra la racha: aislada, para no tocar la del simulador.
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))

        let guardada = makeRuntime(session: StubCloudSession(userID: "u1", canRenew: true),
                                   clientToken: nil, clientSessionKept: true)
        let pasajero = await guardada.syncCycle(context: context)
        #expect(pasajero == .transient)
        #expect(SyncCadencePolicy.nextAction(outcome: pasajero, consecutiveTransients: 1) == .backoff(SyncCadencePolicy.backoffBase),
                "el loop tiene que seguir reintentando solo, no parar hasta volver a entrar")
        #expect(try outbox(context).count == 1, "la fila sigue viva para el reintento")

        // El SDK borra la sesión DURANTE la renovación: el preflight la vio viva y el push la ve borrada.
        let borrada = makeRuntime(session: StubCloudSession(userID: "u1", canRenew: true),
                                  clientToken: nil, clientSessionKept: false)
        #expect(await borrada.syncCycle(context: context) == .sessionExpired)
    }

    @Test("MUTACIÓN: pull sin token (sin nada que subir) con la sesión guardada → `.transient`; con la sesión borrada, caducada")
    func syncCycle_pullWithoutToken_followsTheStoredSession() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let guardada = makeRuntime(session: StubCloudSession(userID: "u1", canRenew: true),
                                   clientToken: nil, clientSessionKept: true)
        #expect(await guardada.syncCycle(context: context) == .transient)

        let borrada = makeRuntime(session: StubCloudSession(userID: "u1", canRenew: false),
                                  clientToken: nil, clientSessionKept: false)
        #expect(await borrada.syncCycle(context: context) == .sessionExpired)
    }

    // MARK: - La puerta de attest alimenta la racha del teléfono (2026-09-15)

    // Ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`. El motor personal nunca manda una subida
    // sin attest, así que lo único que ve es el error de su puerta. De eso depende que el cierre en la nube ofrezca exportar y
    // perder los cambios personales a quien lleva un día sin App Attest, y a nadie que solo esté sin conexión. Todos aíslan la
    // tienda de la racha: sin aislar, escribirían en el `UserDefaults` del host, que es la app.

    @Test("MUTACIÓN: un fallo que habla del attest suma a la racha, y el testigo solo sale con la racha terminal")
    func attestGate_feedsThePhoneStreak_andTheWitnessNeedsATerminalStreak() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(attestError: .unavailable))

        let primero = await runtime.syncCycle(context: context)
        #expect(primero == .transient)
        #expect(GroupsAttestStreakStore.current()?.rejections == 1, "el fallo de la puerta no sumó a la racha del teléfono")
        #expect(!runtime.stoppedByUnavailableAttest(for: primero), "un solo rechazo no es un teléfono sin attest")

        try racha.seedTerminal()
        let segundo = await runtime.syncCycle(context: context)
        #expect(runtime.stoppedByUnavailableAttest(for: segundo), "con la racha terminal, este fallo es el teléfono sin attest")
    }

    @Test("MUTACIÓN: sin red o con el servidor fallando, ni suma a la racha ni enciende el testigo")
    func attestGate_networkAndServerFailures_neverCount() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let antes = GroupsAttestStreakStore.current()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = StubCloudSession(attestError: .network(URLError(.notConnectedToInternet)))
        let runtime = makeRuntime(session: session)

        for error in [AppAttestError.network(URLError(.notConnectedToInternet)), .server("http_503"),
                      .server("yala_bad_request"), .server("decode")] {
            session.attestError = error
            let outcome = await runtime.syncCycle(context: context)
            #expect(outcome == .transient)
            #expect(!runtime.stoppedByUnavailableAttest(for: outcome), "con \(error) el aviso de la pérdida mentiría")
        }
        #expect(GroupsAttestStreakStore.current() == antes, "estar sin conexión no acerca el veredicto")
    }

    @Test("MUTACIÓN: el rechazo del gateway y un error de DeviceCheck cuentan como fallo del attest")
    func attestGate_gatewayRejectionAndDeviceCheckErrors_count() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = StubCloudSession(attestError: .server(AttestSyncGate.attestRejectedType))
        let runtime = makeRuntime(session: session)

        let rechazo = await runtime.syncCycle(context: context)
        #expect(runtime.stoppedByUnavailableAttest(for: rechazo))

        // `AppAttestClient` no envuelve los errores de DeviceCheck: llegan al `catch` genérico de la puerta. El dominio va
        // escrito a mano, que es lo que se ve en un log real («Domain=com.apple.devicecheck.error Code=4»).
        session.attestError = nil
        session.otherAttestError = NSError(domain: "com.apple.devicecheck.error", code: 4)
        let deviceCheck = await runtime.syncCycle(context: context)
        #expect(deviceCheck == .transient)
        #expect(runtime.stoppedByUnavailableAttest(for: deviceCheck))
    }

    @Test("MUTACIÓN: el testigo es de CADA ciclo, y un token conseguido acaba la racha")
    func attestGate_witnessIsPerCycle_andATokenEndsTheStreak() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = StubCloudSession(attestError: .unavailable)
        let runtime = makeRuntime(session: session)

        let fallo = await runtime.syncCycle(context: context)
        #expect(runtime.stoppedByUnavailableAttest(for: fallo))
        #expect(!runtime.stoppedByUnavailableAttest(for: .coalesced), "un `.coalesced` describe un ciclo ajeno")
        #expect(!runtime.stoppedByUnavailableAttest(for: .completed))

        // Un corte de red DESPUÉS de un fallo que contó, con la racha aún terminal: el testigo tiene que bajarse al entrar
        // en el ciclo, o este `.transient` se leería como el teléfono sin attest (review adversarial, 2026-09-15: con el
        // acierto directo, la racha borrada ya daba `false` y el mutante que quita el reinicio sobrevivía).
        session.attestError = .network(URLError(.notConnectedToInternet))
        let sinRed = await runtime.syncCycle(context: context)
        #expect(sinRed == .transient)
        #expect(GroupsAttestStreakStore.isTerminal(), "control: la racha sigue terminal, así que solo el testigo decide")
        #expect(!runtime.stoppedByUnavailableAttest(for: sinRed), "el testigo del ciclo anterior sobrevivió a este")

        session.attestError = nil
        let acierto = await runtime.syncCycle(context: context)
        #expect(!runtime.stoppedByUnavailableAttest(for: acierto))
        #expect(GroupsAttestStreakStore.current() == nil, "un token conseguido es un acierto: la racha se acaba")
    }

    // MARK: - El 401 del gateway es pasajero y no es el teléfono sin attest (2026-09-16)

    // Ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`. La puerta consiguió el token antes de subir,
    // así que el 401 `yala_attest_required` no habla del teléfono. Aquí se fija que el ciclo no para. Que ese 401 no toca la
    // racha lo fijan los tests de los clientes, con una racha sembrada que no se mueve: en el ciclo la puerta la borra antes.
    // El testigo del cierre no cambia con este ticket: sigue siendo solo la puerta (tests del 2026-09-15, más arriba).

    @Test("MUTACIÓN: con cambios pendientes, el 401 `yala_attest_required` del push → `.transient`, no parada")
    func syncCycle_push401AttestRequired_isTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let rechazo = Data(#"{"error":{"message":"m","type":"yala_attest_required","param":null,"code":"yala_attest_required"}}"#.utf8)
        let runtime = makeRuntime(push: StubSession(status: 401, body: rechazo),
                                  session: StubCloudSession(userID: "u1", canRenew: true))
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .transient, "volver a entrar no arregla un attest: el loop no puede pararse a esperar un sign-in")
        #expect(try outbox(context).count == 1, "la fila sigue viva para el reintento")
    }

    @Test("la parada terminal de la puerta (`.accountUnavailable`) también es el teléfono sin attest")
    func attestGate_terminalStop_isAlsoTheWitness() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(attestError: .unavailable))

        var outcome = SyncCadencePolicy.CadenceOutcome.completed
        for _ in 0...AttestSyncGate.defaultMaxRetries {
            outcome = await runtime.syncCycle(context: context)
        }
        #expect(outcome == .accountUnavailable)
        #expect(runtime.stoppedByUnavailableAttest(for: outcome))
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
        let row = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))

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
        let rows = try outbox(context)
        #expect(rows.contains { $0.syncID == row.syncID && $0.rejectedReason == nil },
                "la fila debe seguir viva: los resultados de un push post-teardown NO se aplican")
    }

    // MARK: - Purga de History (§i.6, doble-DARK)

    /// El ancla del drain personal (`SyncCursor.lastDrainedTxAt`): hasta dónde consumió el drain el History.
    private func personalAnchor(_ context: ModelContext) throws -> Date? {
        try context.fetch(FetchDescriptor<SyncCursor>()).first?.lastDrainedTxAt
    }

    private func historyCount(_ context: ModelContext, before cut: Date? = nil) throws -> Int {
        guard let cut else { return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count }
        return try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp < cut })).count
    }

    @Test func purgeHistoryOnce_respectsSafeCut_withUnconfirmedOutboxRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // History real y consumida: dos ediciones drenadas y confirmadas (el ancla queda en la segunda).
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        let anchor = try #require(try personalAnchor(context), "sin ancla la purga no corre y esto no prueba nada")
        let historyBefore = try historyCount(context)
        #expect(try historyCount(context, before: anchor) > 0, "control: hay History consumida que purgar")

        // Fila de outbox SIN confirmar con createdAt en el pasado remoto → el corte queda EN ella:
        // nada por delante de la fila sin-2xx más vieja se purga (invariante §d.5).
        let unconfirmed = SyncOutbox(syncID: UUID(), entityType: SyncEntityType.transactionItem,
                                     op: .upsert, hlc: hlc(1), fieldsJSON: "{}", author: "",
                                     createdAt: .distantPast)
        context.insert(unconfirmed)
        try context.save()

        let purged = engine.purgeHistoryOnce(context: context, now: .now)
        #expect(purged == nil)  // corte = distantPast → 0 transacciones por delante → no purga
        #expect(try historyCount(context) >= historyBefore)  // history INTACTA (el insert del outbox pudo sumar)

        // Al confirmar (purgar) la fila, el corte avanza hasta el ancla del drain → lo anterior se purga, y el ancla no.
        engine.confirmUploaded(syncID: unconfirmed.syncID, hlc: hlc(1), context: context)
        let purged2 = engine.purgeHistoryOnce(context: context, now: .now)
        #expect((purged2 ?? 0) > 0)
        #expect(try historyCount(context, before: anchor) == 0, "todo lo consumido antes del ancla se va")
        #expect(try historyCount(context) > 0, "la transacción del ancla —la del token— se queda")
    }

    /// Ticket `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending` (2026-09-26). La purga cortaba en `now`
    /// suponiendo que el drain ya había consumido todo. Una edición guardada DESPUÉS del último drain del ciclo —los
    /// reconciliadores del pull, o la persona durante la espera de red de las preferencias— se purgaba sin que ningún
    /// drain la viera, y no subía nunca. El drain siguiente tampoco la encontraba: su token apuntaba a History borrada.
    @Test("MUTACIÓN: la purga no se lleva lo que el drain no consumió, ni la transacción de su token")
    func purgeHistoryOnce_keepsWhatTheDrainHasNotConsumed() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        let anchor = try #require(try personalAnchor(context))

        usleep(20_000)
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_500), amount: -7, currencyCode: "USD"))
        try context.save()   // la edición que llega después del drain

        let purged = engine.purgeHistoryOnce(context: context, now: .now)
        #expect((purged ?? 0) > 0, "control: lo consumido sí se purga")
        #expect(try historyCount(context, before: anchor) == 0)

        let boundedBefore = engine.historyTokenBrokenBoundedCount
        #expect(engine.drainOnce(context: context))
        #expect(engine.historyTokenBrokenBoundedCount == boundedBefore, "el token sigue vivo: el drain no cae al respaldo")
        #expect(try outbox(context).count == 1, "el drain siguiente encuentra la edición y la encola")
    }

    /// Un reloj que retrocede no adelanta el corte: `min(now, ancla)`.
    @Test("MUTACIÓN: con `now` por detrás del ancla, la purga corta en `now`")
    func purgeHistoryOnce_clockBehindTheAnchor_cutsAtNow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        let before = try historyCount(context)
        #expect(engine.purgeHistoryOnce(context: context, now: .distantPast) == nil)
        #expect(try historyCount(context) == before)
    }

    /// Las instalaciones de antes del 2026-09-26 llegan con el token apuntando a History que la purga vieja ya borró: su
    /// fetch por token lanza. El drain lo resuelve con el re-escaneo acotado por el ancla; la sonda tiene que leer lo
    /// mismo, o el cierre con motor se quedaría en «no se sabe» —bloqueado— en un teléfono quieto, para siempre.
    @Test("MUTACIÓN: con el token purgado, la sonda lee la ventana del drain en vez de «no se sabe»")
    func uncapturedProbe_withAPurgedToken_readsTheDrainWindow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let runtime = makeRuntime(engine: engine, session: StubCloudSession(userID: "u1"))
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        try context.deleteHistory(HistoryDescriptor<DefaultHistoryTransaction>())   // la purga vieja, hasta `now`
        #expect(try historyCount(context) == 0, "control de escenario: el History está vacío y el token, huérfano")
        let tokenData = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first?.historyTokenData)
        let token = try JSONDecoder().decode(DefaultHistoryToken.self, from: tokenData)
        #expect(throws: (any Error).self, "control de escenario: el fetch por un token purgado lanza") {
            _ = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token }))
        }

        #expect(runtime.hasUncapturedPersonalChanges(context: context) == false, "nada que el drain vaya a leer")

        usleep(20_000)
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_900), amount: -8, currencyCode: "USD"))
        try context.save()
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true, "la edición nueva sí")
    }

    /// El drain consume por TOKEN y la purga borra por TIMESTAMP. Con el reloj por detrás del ancla (la hora estuvo
    /// adelantada y volvió), una edición sin consumir lleva un timestamp ANTERIOR al ancla; con `min(now, ancla)` se purgaba
    /// igual. El ancla se adelanta a mano: es lo que deja un drain que consumió con la hora adelantada.
    @Test("MUTACIÓN: con el reloj por detrás del ancla, la purga no se lleva una edición sin consumir")
    func purgeHistoryOnce_clockRewound_keepsAnUnconsumedEditBelowTheAnchor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        cursor.lastDrainedTxAt = Date().addingTimeInterval(3600)
        try context.save()

        usleep(20_000)
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_700), amount: -9, currencyCode: "USD"))
        try context.save()
        let editAt = try #require(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            .last { $0.author != CloudSyncEngine.outboxSaveAuthor && CloudSyncEngine.isPersonalStoreTransaction($0) }?
            .timestamp)

        _ = engine.purgeHistoryOnce(context: context, now: .now)
        #expect(try historyCount(context, before: editAt) == 0, "control: lo anterior a la edición sí se purga")
        let kept = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp >= editAt })).count
        #expect(kept > 0, "la edición sin consumir sobrevive aunque su timestamp quede por debajo del ancla")
    }

    /// El paso 3-bis del drain: hasta que un drain valide el token en este proceso, el token puede venir de otro mount y
    /// excluir lo nuevo sin lanzar. Se simula con un token que apunta DESPUÉS de la edición y el ancla antes de ella.
    @Test("MUTACIÓN: con el token sin validar, la sonda también mira lo posterior al ancla")
    func uncapturedProbe_unvalidatedToken_alsoReadsPastTheAnchor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try seedHistoryWithEmptyOutbox(engine: CloudSyncEngine(), context: context)
        usleep(20_000)
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_800), amount: -4, currencyCode: "USD"))
        try context.save()   // la edición sin capturar
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_801), amount: -3, currencyCode: "USD"))
        context.author = CloudSyncEngine.outboxSaveAuthor
        try context.save()   // una transacción del motor, por detrás de la edición
        context.author = nil
        let lastEngineTx = try #require(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            .last { $0.author == CloudSyncEngine.outboxSaveAuthor && CloudSyncEngine.isPersonalStoreTransaction($0) })
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        cursor.historyTokenData = try JSONEncoder().encode(lastEngineTx.token)   // el token «de otro mount» tapa la edición
        try context.save()

        // Un motor recién creado: ningún drain ha validado el token en este proceso.
        let runtime = makeRuntime(engine: CloudSyncEngine(), session: StubCloudSession(userID: "u1"))
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true)
    }

    @Test("sin ancla del drain —no ha consumido nada— la purga no borra nada")
    func purgeHistoryOnce_withoutAnAnchor_purgesNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -5, currencyCode: "USD"))
        try context.save()
        let before = try historyCount(context)
        #expect(before > 0)

        #expect(engine.purgeHistoryOnce(context: context, now: .now) == nil)
        #expect(try historyCount(context) == before, "una edición que ningún drain vio no se purga")

        // Con cursor y token pero sin ancla (un cursor anterior al schema del ancla): tampoco. Purgar hasta `now` se
        // llevaría la transacción de su token, y el drain caería al re-escaneo completo sin ancla en cada vuelta.
        let dir2 = freshDir(); defer { cleanup(dir2) }
        let context2 = try makeContext(dir2)
        let engine2 = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine2, context: context2)
        let cursor = try #require(try context2.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursor.historyTokenData != nil, "control de escenario: el token sigue ahí")
        cursor.lastDrainedTxAt = nil
        try context2.save()
        let before2 = try historyCount(context2)
        #expect(engine2.purgeHistoryOnce(context: context2, now: .now) == nil)
        #expect(try historyCount(context2) == before2, "sin ancla no hay nada consumido que purgar")
    }

    /// Prepara un contexto con history real y CONSUMIDA y el outbox VACÍO: dos ediciones, cada una drenada y confirmada,
    /// para que el ciclo del runtime no necesite push y quede History por debajo del ancla (la segunda) que purgar.
    private func seedHistoryWithEmptyOutbox(engine: CloudSyncEngine, context: ModelContext) throws {
        for amount in [-5.0, -6.0] {
            let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: "USD")
            context.insert(tx)
            try context.save()
            engine.drainOnce(context: context)
            for row in try outbox(context) {
                engine.confirmUploaded(syncID: row.syncID, hlc: row.hlc, context: context)
            }
            usleep(20_000)   // timestamps distintos: la primera queda estrictamente por debajo del ancla
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

    /// Con el canal de Grupos APAGADO el único suelo es el del drain personal ⇒ la purga llega hasta su ancla
    /// (hasta el 2026-09-26 llegaba hasta `now` y la History quedaba vacía).
    ///
    /// El apagado explícito NO es cosmético: es la precondición de «nada por debajo del ancla», y sin fijarla el
    /// resultado lo decidía el SCHEME. `Yala Dev` define `DEV_BUILD` ⇒ el default-ausente de remote-config
    /// es ON ⇒ el paso 5.6 corre el piggyback de Grupos ⇒ su `GroupSyncCursor.lastDrainedTxAt` entra como
    /// suelo en `deleteHistorySafeCut` (que devuelve `floors.min()`) ⇒ la purga no puede bajar a cero y la
    /// aserción era falsa BAJO ESE SCHEME (exit 65, medido el 2026-07-31 en el mismo commit que pasaba con
    /// `-scheme Yala`). Lo que ocurre con el canal ENCENDIDO —el caso de producción con el rollout al
    /// 100 %— lo afirma `syncCycle_bothFlagsOn_neverPurgesPastTheGroupsFloor`.
    @Test func syncCycle_bothFlagsOn_purgesHistoryAfterCompletedCycle() async throws {
        let prev = CloudSyncFlags.historyPurgeEnabled
        CloudSyncFlags.historyPurgeEnabled = true
        defer { CloudSyncFlags.historyPurgeEnabled = prev }
        CloudSyncFlags.groupsBackendEnabled = false
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        #expect(try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count > 0)

        let runtime = makeRuntime(engine: engine, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        // Ciclo completed (outbox vacío → sin push; pull vacío) + ambos flags → purga hasta el ancla del drain (no hasta
        // `now` desde el 2026-09-26: lo que el drain no consumió, y la transacción de su token, se quedan).
        let before = try historyCount(context)
        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .completed)
        let anchor = try #require(try personalAnchor(context))
        #expect(try historyCount(context, before: anchor) == 0, "todo lo consumido antes del ancla se va")
        let history = try historyCount(context)
        #expect(history > 0, "la transacción del ancla se queda")
        #expect(history < before, "control: la purga corrió")
    }

    /// La otra mitad, y la que describe producción: con el canal de Grupos ENCENDIDO el paso 5.6 deja un
    /// `GroupSyncCursor.lastDrainedTxAt`, y ese es un suelo más del corte. La purga tiene que llegar
    /// EXACTAMENTE hasta el menor de los suelos —el de Grupos o, desde el 2026-09-26, el ancla del drain
    /// personal—: ni menos (no purgar sería el bug que la purga existe para evitar) ni más (pasarse borra la
    /// History de una fila del outbox de Grupos antes de que su drain la vea, y esa fila se queda local para
    /// siempre: el bug que cierra `GroupsHistoryCutFloorTests`, donde el suelo de Grupos se mide solo)—.
    ///
    /// El piggyback se inyecta con un `GroupsSyncClient` PROPIO en vez del singleton: `shared` arrastraría
    /// su estado (`historyTokenValidated`, reloj, cursor de ciclo) entre tests y no tiene `_testReset()`.
    @Test func syncCycle_bothFlagsOn_neverPurgesPastTheGroupsFloor() async throws {
        let prev = CloudSyncFlags.historyPurgeEnabled
        CloudSyncFlags.historyPurgeEnabled = true
        defer { CloudSyncFlags.historyPurgeEnabled = prev }
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        try seedHistoryWithEmptyOutbox(engine: engine, context: context)
        let before = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(before > 0)

        let groupsClient = GroupsSyncClient()
        let runtime = makeRuntime(engine: engine, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        runtime.groupsSyncCycleRunner = { ctx in groupsClient.drainOnce(context: ctx) }

        let outcome = await runtime.syncCycle(context: context)
        #expect(outcome == .completed)

        // El suelo que dejó el piggyback (el mismo valor que leyó `deleteHistorySafeCut`: nada más drena
        // después de él en este ciclo).
        let floor = try #require(
            try context.fetch(FetchDescriptor<GroupSyncCursor>()).first?.lastDrainedTxAt,
            "el piggyback tiene que dejar su ancla: sin ella este test no prueba nada")

        // El corte es el menor de los suelos: el de Grupos y, desde el 2026-09-26, el ancla del drain personal.
        let anchor = try #require(try personalAnchor(context))
        let cut = min(floor, anchor)
        #expect(try historyCount(context, before: cut) == 0, "la purga se quedó corta: todo lo anterior al corte tenía que irse")

        let after = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count
        #expect(after > 0, "la purga se pasó del suelo del canal de Grupos")
        #expect(after < before, "no se purgó nada: el ciclo no llegó a la purga")
    }

    // MARK: - El push-all del cierre respeta el candado del motor

    // Ticket `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`. El cierre de sesión en la nube subía lo pendiente
    // con `syncCycle`, que no pasa por `canRunDomain()`: con el journal ilegible, una fase transitoria o el espejo de iCloud
    // montado corría un ciclo entero —drain, push, pull— que el motor no podía correr. Ahora no corre ninguno, y el cierre
    // sigue teniendo salida: sin pendientes llega al borrado; con ellos bloquea sin descartar.

    /// Recuento de filas vivas con el MISMO criterio que `livePendingUploadCount` (un fetch que falla no habilita nada).
    private func liveCount(_ context: ModelContext) -> Int {
        do {
            return try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }.count
        } catch {
            return Int.max
        }
    }

    /// El drain crea el cursor en su primera vuelta (`loadOrCreateCursor`): sin cursor, el drain no corrió.
    private func cursorCount(_ context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<SyncCursor>()).count
    }

    @Test("cierre con el candado cerrado y pendientes: bloquea sin correr ni el drain ni la red, y no descarta")
    func signOutPushAll_domainGateClosed_withPending_blocksWithoutACycle() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let push = StubSession(body: pushAppliedJSON([row]))
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(push: push, pull: pull, session: StubCloudSession(userID: "u1"))

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { false }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        // El motivo nombra la salida real —actualizar Yala—, no la conexión (ticket
        // `cloud-signout-with-the-engine-stopped-says-check-your-connection`).
        #expect(verdict == .blocked(pendingCount: 1, reason: .syncStoppedNeedsUpdate))
        #expect(push.callCount == 0, "con el candado cerrado no se sube nada")
        #expect(pull.callCount == 0, "ni se baja")
        #expect(try cursorCount(context) == 0, "ni corre el drain, que guarda en el store principal")
        #expect(try outbox(context).map(\.syncID) == [row.syncID], "la fila pendiente sigue ahí: no se descarta")

        // Control: el MISMO escenario con el candado abierto sí sube la fila y drena.
        let open = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        #expect(open == .drained)
        #expect(push.callCount > 0, "control: con el candado abierto el ciclo sí sube")
        #expect(try cursorCount(context) == 1, "control: el ciclo sí drena, y el drain deja su cursor")
    }

    @Test("cierre con el candado cerrado y sin pendientes: el cierre sigue (su borrado es la salida del estado)")
    func signOutPushAll_domainGateClosed_withoutPending_drains() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let push = StubSession(body: Data(#"{"results":[]}"#.utf8))
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(push: push, pull: pull, session: StubCloudSession(userID: "u1"))

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { false }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .drained, "sin nada pendiente el cierre no se queda atrapado")
        #expect(push.callCount == 0 && pull.callCount == 0, "y llega ahí sin un solo ciclo")
        #expect(try cursorCount(context) == 0, "ni un drain")
    }

    /// Entre ciclo y ciclo hay una pausa en la que una reversa puede arrancar: el candado se consulta antes de CADA uno.
    /// Con un solo `guard` al entrar, este escenario correría las 20 vueltas contra el servidor y saldría `.transient`.
    @Test("cierre: si el candado se cierra entre dos ciclos, no corre el siguiente")
    func signOutPushAll_domainGateClosingMidway_stopsBeforeTheNextCycle() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        // El servidor responde sin aplicar nada: el ciclo sale sano y la fila sigue viva ⇒ el loop quiere otra vuelta.
        let push = StubSession(body: Data(#"{"results":[]}"#.utf8))
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(push: push, pull: pull, session: StubCloudSession(userID: "u1"))
        var asked = 0

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context,
            domainGateOpen: { asked += 1; return asked == 1 },
            journalRead: { .phase(.reverseClaimLeader) },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        // Una vuelta a iCloud que arrancó entre dos ciclos: la salida está en «Dónde viven tus datos».
        #expect(verdict == .blocked(pendingCount: 1, reason: .syncStoppedMidMigration))
        #expect(asked == 2, "el candado se pregunta otra vez antes del segundo ciclo")
        #expect(push.callCount == 1, "solo corrió el ciclo de antes del cierre del candado")
    }

    @Test("cierre sin runtime: mismo veredicto que con el candado cerrado")
    func signOutPushAll_withoutRuntime_matchesTheClosedGate() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        // Sin runtime no se pregunta el candado: `canRunDomain()` deja rastros y un canario.
        var asked = 0
        var journalAsked = 0
        let empty = await CloudMigrationController.pushAllForSignOut(
            runtime: nil, context: context, domainGateOpen: { asked += 1; return true },
            journalRead: { journalAsked += 1; return .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        #expect(empty == .drained)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let pending = await CloudMigrationController.pushAllForSignOut(
            runtime: nil, context: context, domainGateOpen: { true },
            journalRead: { journalAsked += 1; return .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        // Sin runtime no es el candado —es el motor apagado—: no hay una salida que nombrar y queda el genérico.
        #expect(pending == .blocked(pendingCount: 1, reason: .permanent))
        #expect(asked == 0, "sin runtime el candado ni se consulta")
        #expect(journalAsked == 0, "ni el journal: el motivo del candado no aplica")
    }

    /// Cancelar el gesto a mitad de la pausa corta el loop y bloquea como pasajero, con las filas contadas: jamás
    /// `.drained` con pendientes.
    @Test("cierre cancelado durante la pausa: bloquea como pasajero sin descartar")
    func signOutPushAll_cancelledDuringThePause_blocksAsTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let push = StubSession(body: Data(#"{"results":[]}"#.utf8))
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        let task = Task { @MainActor in
            await CloudMigrationController.pushAllForSignOut(
                runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
                livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .seconds(60))
        }
        while push.callCount == 0 { await Task.yield() }
        task.cancel()
        let verdict = await task.value
        #expect(verdict == .blocked(pendingCount: 1, reason: .transient))
        #expect(push.callCount == 1, "la cancelación corta antes del segundo ciclo")
    }

    // MARK: - El paso 1 del cierre en la nube nombra el motivo real (2026-09-25)

    // Ticket `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`. Hasta ese día el paso 1 aplanaba a
    // `.permanent` —«revisa tu conexión»— un 5xx, un corte de red y un 401, porque el push-all personal pasaba
    // `uploadFailed: false` y el paso 1 no dejaba pasar nada que no fuera el motor parado. Estos casos van de punta a punta:
    // el ciclo real contra un transporte stub, el veredicto del push-all, la traducción del paso 1 y el texto del aviso.

    /// Lo que enseña Ajustes para un veredicto del push-all personal: el mismo camino que `performCloudSecureSignOut`.
    private func shownMessage(_ verdict: CloudSignOutFlowLogic.PushAllVerdict) -> String? {
        guard case .blocked(_, let reason) = verdict else { return nil }
        return SignOutBlockedCopy.message(for: CloudSignOutFlowLogic.personalPushAllShownReason(reason))
    }

    @Test("MUTACIÓN: con cambios personales pendientes, un fallo del servidor dice «inténtalo en un rato», no «revisa tu conexión»")
    func signOutPushAll_serverFailure_saysTryAgainLater() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let casos: [(String, SyncHTTPSession)] = [
            ("500", StubSession(status: 500, body: Data())),
            ("503", StubSession(status: 503, body: Data())),
            ("sin red", ThrowingSession(URLError(.notConnectedToInternet))),
            ("200 ilegible", StubSession(status: 200, body: Data("no es json".utf8))),
        ]
        for (nombre, push) in casos {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
            let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                      session: StubCloudSession(userID: "u1"))

            let verdict = await CloudMigrationController.pushAllForSignOut(
                runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
                livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

            #expect(verdict == .blocked(pendingCount: 1, reason: .uploadRetryLater), "\(nombre)")
            #expect(CloudSignOutFlowLogic.personalPushAllShownReason(.uploadRetryLater) == .personalUploadRetryLater)
            #expect(shownMessage(verdict) == L10n.Settings.signOutUploadRetryLater, "\(nombre)")
            #expect(shownMessage(verdict) != L10n.Settings.signOutBlockedMessage, "\(nombre): no es la conexión")
            #expect(try outbox(context).count == 1, "\(nombre): la fila sigue ahí, no se descarta")
        }
    }

    /// El 200 cuyo resultado es `upstream_*` no aplica la fila: el push sale `.completed`, el ciclo sigue al pull y, si ése
    /// falla, el testigo copiado tras `applyResults` es lo único que dice que lo pendiente no llegó (review adversarial del
    /// 2026-09-25, dos lentes). Sin él, «un momento más, espera unos segundos» con el servidor fallando.
    @Test("MUTACIÓN: un rechazo `upstream_*` seguido de un pull que falla dice «inténtalo en un rato»")
    func signOutPushAll_upstreamRejectionThenFailedPull_saysTryAgainLater() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let upstream = Data(("{\"results\":[{\"sync_id\":\"\(row.syncID.uuidString.lowercased())\"," +
            "\"client_mutation_id\":\"\(row.clientMutationID.uuidString.lowercased())\"," +
            "\"status\":\"rejected\",\"reason\":\"upstream_500\"}]}").utf8)
        let runtime = makeRuntime(push: StubSession(status: 200, body: upstream),
                                  pull: StubSession(status: 503, body: Data()),
                                  session: StubCloudSession(userID: "u1"))

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .blocked(pendingCount: 1, reason: .uploadRetryLater))
        #expect(shownMessage(verdict) == L10n.Settings.signOutUploadRetryLater)

        // Control: el mismo pull fallido con la fila APLICADA drena — el testigo no se enciende por el pull.
        let dir2 = freshDir(); defer { cleanup(dir2) }
        let context2 = try makeContext(dir2)
        let row2 = try liveRow(context2, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime2 = makeRuntime(push: StubSession(status: 200, body: pushAppliedJSON([row2])),
                                   pull: StubSession(status: 503, body: Data()),
                                   session: StubCloudSession(userID: "u1"))
        let drenado = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime2, context: context2, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context2) }, maxIterations: 20, pause: .zero)
        #expect(drenado == .drained)
        #expect(!runtime2.stoppedByFailedUpload(for: .transient), "el pull que falla no enciende el testigo")
    }

    /// Sin el pase del servidor el ciclo para antes de subir, y esperar unos segundos no lo cura: va con backoff.
    @Test("MUTACIÓN: la puerta de attest que no consigue el pase dice «inténtalo en un rato»")
    func signOutPushAll_attestGateTransient_saysTryAgainLater() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let push = StubSession(status: 200, body: Data(#"{"results":[]}"#.utf8))
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1",
                                                            attestError: .network(URLError(.notConnectedToInternet))))

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .blocked(pendingCount: 1, reason: .uploadRetryLater))
        #expect(push.callCount == 0, "control: el ciclo paró en la puerta, antes de subir")
        #expect(shownMessage(verdict) == L10n.Settings.signOutUploadRetryLater)
    }

    @Test("MUTACIÓN: con cambios personales pendientes, un 401 dice que la sesión caducó, no «revisa tu conexión»")
    func signOutPushAll_401_saysTheSessionExpired() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime = makeRuntime(push: StubSession(status: 401, body: Data()),
                                  pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .blocked(pendingCount: 1, reason: .sessionExpired))
        #expect(CloudSignOutFlowLogic.personalPushAllShownReason(.sessionExpired) == .cloudSessionExpired)
        #expect(shownMessage(verdict) == L10n.Settings.signOutCloudSessionExpired)
        #expect(shownMessage(verdict) != L10n.Settings.signOutBlockedMessage)
        #expect(try outbox(context).count == 1)
    }

    /// Lo del teléfono no se le achaca al servidor: un outbox que no se deja leer sale como el guardado que se asienta.
    @Test("MUTACIÓN: un fallo local del ciclo sale «un momento más», no «no llegaron a la nube» ni «revisa tu conexión»")
    func signOutPushAll_localFailure_saysAMomentMore() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let push = StubSession(status: 500, body: Data())
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        runtime._testThrowOnOutboxFetch = true

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .blocked(pendingCount: 1, reason: .transient))
        #expect(push.callCount == 0, "control: no llegó a la red")
        #expect(shownMessage(verdict) == L10n.Settings.signOutPendingMessage)
    }

    /// El testigo describe el ÚLTIMO ciclo: un 500 de antes no tiñe un fallo local de ahora, y un `.coalesced` no es suyo.
    @Test("MUTACIÓN: el testigo de la subida se baja en cada ciclo y solo cuenta con `.transient`")
    func uploadWitness_describesTheLastCycleOnly() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let runtime = makeRuntime(push: StubSession(status: 500, body: Data()),
                                  pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))

        let primero = await runtime.syncCycle(context: context)
        #expect(primero == .transient)
        #expect(runtime.stoppedByFailedUpload(for: primero), "control: el 500 lo enciende")
        #expect(!runtime.stoppedByFailedUpload(for: .coalesced), "un ciclo ajeno no es este")
        #expect(!runtime.stoppedByFailedUpload(for: .completed))

        runtime._testThrowOnOutboxFetch = true
        let segundo = await runtime.syncCycle(context: context)
        #expect(segundo == .transient)
        #expect(!runtime.stoppedByFailedUpload(for: segundo), "el fallo local de este ciclo no es del servidor")
    }

    @Test("pushAllVerdictWithoutEngine: solo sigue sin filas Y sin ediciones sin capturar; lo que no se pudo leer bloquea")
    func pushAllVerdictWithoutEngine_table() {
        typealias L = CloudSignOutFlowLogic
        // El motivo viaja tal cual en las tres formas de bloquear: se prueba con los dos del motor parado y con el genérico.
        for reason in [L.BlockReason.syncStoppedNeedsUpdate, .syncStoppedMidMigration, .syncStoppedNeedsRelaunch, .permanent] {
            #expect(L.pushAllVerdictWithoutEngine(livePendingCount: 0, uncapturedChanges: false, reason: reason) == .drained)
            #expect(L.pushAllVerdictWithoutEngine(livePendingCount: 3, uncapturedChanges: false, reason: reason)
                == .blocked(pendingCount: 3, reason: reason))
            #expect(L.pushAllVerdictWithoutEngine(livePendingCount: 3, uncapturedChanges: true, reason: reason)
                == .blocked(pendingCount: 3, reason: reason))
            // Ediciones solo en el History: bloquea, con la cifra del «no se pudo contar».
            #expect(L.pushAllVerdictWithoutEngine(livePendingCount: 0, uncapturedChanges: true, reason: reason)
                == .blocked(pendingCount: .max, reason: reason))
            // El History que no se pudo leer cuenta como «sí».
            #expect(L.pushAllVerdictWithoutEngine(livePendingCount: 0, uncapturedChanges: nil, reason: reason)
                == .blocked(pendingCount: .max, reason: reason))
            // Un recuento que falló (`Int.max`) jamás habilita el cierre.
            #expect(L.pushAllVerdictWithoutEngine(livePendingCount: .max, uncapturedChanges: false, reason: reason)
                == .blocked(pendingCount: .max, reason: reason))
        }
    }

    /// Se clasifica por lo que enseña «Dónde viven tus datos» en ese mismo estado. El journal ilegible: reabrir o
    /// actualizar. Una fase en vuelo, fallida o en espera: Almacenamiento, que enseña su progreso o su «Reintentar». Una fase
    /// ESTABLE con el candado cerrado es el espejo aún montado: Almacenamiento enseña la nube activa, sin nada que terminar,
    /// y lo que cura es reabrir (review adversarial del 2026-09-25, dos lentes).
    @Test("engineStoppedReason: ilegible → actualizar; fase en vuelo → Almacenamiento; fase estable → reabrir")
    func engineStoppedReason_table() {
        typealias L = CloudSignOutFlowLogic
        #expect(L.engineStoppedReason(read: .unreadable) == .syncStoppedNeedsUpdate)
        let midway: [MigrationPhase] = [.reverseClaimLeader, .reverseFailedRollback, .reverseUpload, .reverseMountMirror,
                                        .icloudActive, .failedRollback, .verifying, .waitingForLeader, .dryRun]
        for phase in midway {
            #expect(L.engineStoppedReason(read: .phase(phase)) == .syncStoppedMidMigration, "\(phase)")
        }
        for phase in [MigrationPhase.done, .notStarted] {
            #expect(L.engineStoppedReason(read: .phase(phase)) == .syncStoppedNeedsRelaunch, "\(phase)")
        }
    }

    /// Con la edición sin capturar y el paso a iCloud a medias, el motivo sale del journal legible (el otro par).
    @Test("cierre con el candado cerrado, journal legible y una edición sin capturar: bloquea con «Dónde viven tus datos»")
    func signOutPushAll_domainGateClosed_legibleJournal_uncapturedEdit_namesStorage() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let push = StubSession(body: Data(#"{"results":[]}"#.utf8))
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: 12, currencyCode: "USD"))
        try context.save()

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { false },
            journalRead: { .phase(.reverseFailedRollback) },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .blocked(pendingCount: .max, reason: .syncStoppedMidMigration))
        #expect(push.callCount == 0)
    }

    /// El caso que cazaron dos lentes de la review: con el motor parado, lo que la persona edita vive solo en el History.
    /// Sin drain no llega al outbox, y leer solo el outbox daba `.drained` y el borrado se lo llevaba sin aviso — antes, el
    /// ciclo que se saltaba el candado lo capturaba. Y la lectura no escribe: ni cursor, ni filas.
    @Test("cierre con el candado cerrado y una edición que el motor no capturó: bloquea, sin escribir nada")
    func signOutPushAll_domainGateClosed_withUncapturedEdit_blocks() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let push = StubSession(body: Data(#"{"results":[]}"#.utf8))
        let engine = CloudSyncEngine()
        let runtime = makeRuntime(engine: engine, push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: 12, currencyCode: "USD"))
        try context.save()

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { false }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .blocked(pendingCount: .max, reason: .syncStoppedNeedsUpdate),
                "la edición no se pierde en silencio")
        #expect(push.callCount == 0)
        #expect(try cursorCount(context) == 0, "la lectura del History no crea el cursor")
        #expect(try outbox(context).isEmpty, "ni encola nada")

        // Control: con un drain que la captura (el candado abierto), la misma edición ya no cuenta como sin capturar.
        #expect(engine.drainOnce(context: context), "control: el drain termina")
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == false,
                "control: capturada por el drain, la sonda la da por vista")
        #expect(liveCount(context) > 0, "control: y ahora vive en el outbox, que es quien bloquea")
    }

    @Test("sonda del History: lo que escribió el propio motor no cuenta, y un token roto se lee como lo leería el drain")
    func uncapturedProbe_ignoresEngineWrites_andReadsABrokenTokenLikeTheDrain() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let runtime = makeRuntime(session: StubCloudSession(userID: "u1"))
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == false, "store sin ediciones")

        // Un guardado firmado por el motor (el apply de un pull) no es una edición local.
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: 5, currencyCode: "USD"))
        context.author = CloudSyncEngine.outboxSaveAuthor
        try context.save()
        context.author = nil
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == false, "el eco del motor no cuenta")

        // Control positivo: la misma forma sin el autor del motor sí cuenta.
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_100), amount: 6, currencyCode: "USD"))
        try context.save()
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true)

        // Token del cursor que no decodifica y sin ancla: la ventana del drain es el History entero (`fullRescanNoAnchor`),
        // y la edición de arriba está ahí. Hasta el 2026-09-26 era `nil` sin mirar.
        let cursor = SyncCursor()
        cursor.historyTokenData = Data("garbage-token".utf8)
        context.insert(cursor)
        try context.save()
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true)

        // Con ancla, la ventana es la acotada (ancla − slack): lo consumido antes no cuenta; lo que viene después, sí.
        cursor.lastDrainedTxAt = Date().addingTimeInterval(3600)
        try context.save()
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == false, "todo queda por debajo del ancla")
        cursor.lastDrainedTxAt = Date().addingTimeInterval(-3600)
        try context.save()
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true, "la edición queda por delante del ancla")
        // La holgura del drain (60 s): con el ancla 30 s por delante de la edición, el drain la re-leería y la sonda también.
        cursor.lastDrainedTxAt = Date().addingTimeInterval(30)
        try context.save()
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true, "dentro de la holgura del respaldo")
    }

    /// Producción entra por el método de instancia, y lo que lo hace respetar el candado son sus dos argumentos: el runtime
    /// VIVO y el candado REAL. Un `domainGateOpen: { true }` aquí reabre el ticket con todos los tests de arriba en verde.
    /// Cuerpo ENTERO, sin comentarios: una sentencia antepuesta tampoco pasa.
    @Test("MUTACIÓN: el cierre de producción pasa el candado real y el runtime vivo")
    func signOutPushAll_productionWrapperWiresTheRealGate() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/CloudMigrationController.swift"), encoding: .utf8)
        let marker = "func pushAllPendingForSignOut(maxIterations: Int = 20) async -> CloudSignOutFlowLogic.PushAllVerdict {"
        let start = try #require(text.range(of: marker), "la firma del push-all del cierre cambió")
        let chars = Array(text[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        let code = String(chars[0..<min(i, chars.count)]).split(separator: "\n")
            .map { line -> String in
                var c = String(line)
                if let comment = c.range(of: "//") { c = String(c[..<comment.lowerBound]) }
                return c.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
        #expect(code == [
            "await Self.pushAllForSignOut(",
            "runtime: CloudSyncRuntime.shared,",
            "context: context,",
            "domainGateOpen: { CloudSyncRuntime.canRunDomain() },",
            "journalRead: { MigrationPhaseStore.shared.currentPhaseRead },",
            "livePendingCount: { [self] in livePendingUploadCount() },",
            "maxIterations: maxIterations)",
        ])
    }

    // MARK: - El push-all con motor relee el History antes de dar el outbox por vacío (2026-09-26)

    // Ticket `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`, gemelo de
    // `groups-drain-failure-reads-as-nothing-pending`. El drain del ciclo no viaja en su outcome: uno que aborta hace
    // `rollback()`, la edición se queda solo en el History, el outbox da 0 y el cierre salía `.drained` hacia el borrado.

    /// Una edición local de verdad (autor por defecto, como la de la persona): es lo que el drain tiene que capturar.
    private func localEdit(_ context: ModelContext) throws {
        context.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: 12, currencyCode: "USD"))
        try context.save()
    }

    @Test("MUTACIÓN: un drain que aborta no deja el cierre en `.drained`: bloquea «un momento más» sin descartar")
    func signOutPushAll_drainAborts_blocksInsteadOfDraining() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let push = EchoAppliedSession()
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(engine: engine, push: push, pull: pull, session: StubCloudSession(userID: "u1"))
        try localEdit(context)
        engine._testThrowOnDrainOutboxSave = true

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 3, pause: .zero)

        #expect(liveCount(context) == 0, "control de escenario: el drain abortó y el outbox quedó vacío")
        #expect(pull.callCount == 3, "da las vueltas del tope —otra vuelta cura lo escrito tras el drain— y ahí bloquea")
        #expect(verdict == .blocked(pendingCount: .max, reason: .transient), "la edición no se pierde en silencio")
        #expect(shownMessage(verdict) == L10n.Settings.signOutPendingMessage, "el aviso es el del guardado que se asienta")
        #expect(push.callCount == 0, "no había nada en el outbox que subir")
        #expect(runtime.hasUncapturedPersonalChanges(context: context) == true, "la edición sigue en el History")

        // Control: el MISMO escenario con el drain sano captura, sube y drena.
        engine._testThrowOnDrainOutboxSave = false
        let sano = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        #expect(sano == .drained)
        #expect(push.callCount == 1, "control: el reintento sube la edición")
    }

    /// Con la traducción cortada `drainOnce` devuelve `true` a propósito (ver su docblock), así que su Bool no bastaría:
    /// lo que decide es el History. Hoy solo lo corta un año fuera de 0001–9999, que el seam imita.
    @Test("MUTACIÓN: con la traducción cortada el drain dice que terminó, y el cierre tampoco sale `.drained`")
    func signOutPushAll_translationCut_blocksInsteadOfDraining() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let runtime = makeRuntime(engine: engine, push: EchoAppliedSession(), pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1"))
        try localEdit(context)
        engine._testThrowOnClockStamp = true
        defer { engine._testThrowOnClockStamp = false }

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(liveCount(context) == 0, "control de escenario: la edición no llegó al outbox")
        #expect(verdict == .blocked(pendingCount: .max, reason: .transient))
    }

    /// El segundo criterio del ticket: sin nada que se quede fuera, el cierre es el de siempre — un ciclo, una subida, un
    /// pull, y `.drained`. Ni esperas ni red nuevas. Con una edición REAL drenada y subida, no con una fila sembrada a mano.
    @Test("sin nada fuera del outbox, el cierre no cambia: un ciclo y `.drained`")
    func signOutPushAll_editDrainedAndUploaded_drainsInOneCycle() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let push = EchoAppliedSession()
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(push: push, pull: pull, session: StubCloudSession(userID: "u1"))
        try localEdit(context)

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(verdict == .drained)
        #expect(push.callCount == 1 && push.appliedCount == 1, "la edición subió en la primera vuelta")
        #expect(pull.callCount == 1, "un solo ciclo: la relectura no añade vueltas")

        // Y un store sin nada que subir: ni una subida.
        let dir2 = freshDir(); defer { cleanup(dir2) }
        let context2 = try makeContext(dir2)
        let push2 = EchoAppliedSession()
        let runtime2 = makeRuntime(push: push2, pull: StubSession(body: emptyPageJSON()), session: StubCloudSession(userID: "u1"))
        let vacio = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime2, context: context2, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context2) }, maxIterations: 20, pause: .zero)
        #expect(vacio == .drained)
        #expect(push2.callCount == 0)
    }

    /// Lo que la sonda ve puede haber llegado DESPUÉS del drain del ciclo, y eso lo cura el drain de la vuelta siguiente:
    /// el puente de Grupos del paso 5.6 escribe en el store personal justo ahí. Sin la vuelta extra, «un momento más».
    @Test("MUTACIÓN: una edición que llega tras el drain del ciclo sube en la vuelta siguiente y el cierre sigue")
    func signOutPushAll_editAfterTheCycleDrain_isCapturedByTheNextLap() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let push = EchoAppliedSession()
        let pull = StubSession(body: emptyPageJSON())
        let runtime = makeRuntime(push: push, pull: pull, session: StubCloudSession(userID: "u1"))
        var bridged = false
        runtime.groupsSyncCycleRunner = { ctx in
            guard !bridged else { return }
            bridged = true
            ctx.insert(TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_600), amount: -11, currencyCode: "USD"))
            do { try ctx.save() } catch { Issue.record("el save del puente simulado falló: \(error)") }
        }

        let verdict = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)

        #expect(bridged, "control de escenario: el paso 5.6 corrió")
        #expect(verdict == .drained)
        #expect(push.appliedCount == 1, "la edición del puente subió en la segunda vuelta")
        #expect(pull.callCount == 2, "una vuelta más, y no el tope")
    }

    /// El bloqueo por App Attest es el único que el paso 1 deja seguir perdiendo las filas del aviso. Con una edición fuera
    /// del outbox, el aviso no la enseñaría y la pérdida aceptada se la llevaría: sale como «un momento más», sin salida de
    /// pérdida, hasta que un drain la capture y el aviso la cuente.
    @Test("MUTACIÓN: el bloqueo por App Attest con una edición sin capturar no ofrece perder: «un momento más»")
    func signOutPushAll_attestBlockWithUncapturedEdit_isNotTheLossOffer() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let runtime = makeRuntime(engine: engine, push: EchoAppliedSession(), pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u1", attestError: .unavailable))
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))

        // Control: sin nada fuera del outbox, el bloqueo es el del attest, con la cifra del aviso.
        let soloOutbox = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        #expect(soloOutbox == .blocked(pendingCount: 1, reason: .attestUnavailable))

        try localEdit(context)
        engine._testThrowOnDrainOutboxSave = true
        let conEdicion = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        #expect(conEdicion == .blocked(pendingCount: 1, reason: .transient))

        // Control: capturada la edición, el aviso de la pérdida vuelve y la cuenta.
        engine._testThrowOnDrainOutboxSave = false
        let capturada = await CloudMigrationController.pushAllForSignOut(
            runtime: runtime, context: context, domainGateOpen: { true }, journalRead: { .unreadable },
            livePendingCount: { liveCount(context) }, maxIterations: 20, pause: .zero)
        #expect(capturada == .blocked(pendingCount: 2, reason: .attestUnavailable))
    }

    @Test("personalVerdictAfterProbe: solo relee `.drained` y el bloqueo por attest; lo que no se pudo leer bloquea")
    func personalVerdictAfterProbe_table() {
        typealias L = CloudSignOutFlowLogic
        var asked = 0
        func probe(_ answer: Bool?) -> () -> Bool? { { asked += 1; return answer } }

        #expect(L.personalVerdictAfterProbe(.drained, uncapturedChanges: probe(false)) == .drained)
        #expect(L.personalVerdictAfterProbe(.drained, uncapturedChanges: probe(true))
            == .blocked(pendingCount: .max, reason: .transient))
        #expect(L.personalVerdictAfterProbe(.drained, uncapturedChanges: probe(nil))
            == .blocked(pendingCount: .max, reason: .transient))

        let attest = L.PushAllVerdict.blocked(pendingCount: 3, reason: .attestUnavailable)
        #expect(L.personalVerdictAfterProbe(attest, uncapturedChanges: probe(false)) == attest)
        #expect(L.personalVerdictAfterProbe(attest, uncapturedChanges: probe(true)) == .blocked(pendingCount: 3, reason: .transient))
        #expect(L.personalVerdictAfterProbe(attest, uncapturedChanges: probe(nil)) == .blocked(pendingCount: 3, reason: .transient))
        #expect(asked == 6)

        // El resto de bloqueos no descarta nada: pasan tal cual y ni preguntan.
        asked = 0
        for reason in L.BlockReason.allCases where reason != .attestUnavailable {
            let verdict = L.PushAllVerdict.blocked(pendingCount: 2, reason: reason)
            #expect(L.personalVerdictAfterProbe(verdict, uncapturedChanges: probe(true)) == verdict, "\(reason)")
        }
        #expect(asked == 0, "la sonda es una lectura del History: solo se hace cuando decide algo")
    }

    // MARK: - La puerta de la nube con la sesión caducada

    /// Ticket `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` (2026-09-25). Arranca un runtime en `.cloud`
    /// estable con el dueño `u1` y lo deja en `.stoppedUntilSignIn` con `stopUntilSignIn()`, que es lo que hace el cierre de
    /// sesión al bloquear por sesión caducada. La cadencia que `start()` lanzó no llega a correr: se cancela antes del primer
    /// punto de suspensión del test.
    private func withStoppedCloudRuntime(
        push: StubSession, pull: StubSession,
        _ body: (CloudSyncRuntime, StubCloudSession, ModelContext) async throws -> Void
    ) async throws {
        let prev = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)
        defer {
            CloudSyncFlags.syncRuntimeEnabled = prev
            CloudSyncFlags.storageMode = prevMode
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
        }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = StubCloudSession(userID: "u1", claim: .routeReturningUser)
        let runtime = makeRuntime(push: push, pull: pull, session: session)
        await runtime.start(context: context)
        defer { runtime.teardownGuestSession() }
        #expect(runtime.state == .running, "control: el motor arrancó con su dueño")
        #expect(runtime.ownerUserID == "u1")
        runtime.stopUntilSignIn()
        #expect(runtime.state == .stoppedUntilSignIn)
        try await body(runtime, session, context)
    }

    @Test("MUTACIÓN: el cierre que bloquea por sesión caducada deja el motor parado hasta firmar, solo desde `.running`")
    func stopUntilSignIn_onlyFromRunning() async throws {
        try await withStoppedCloudRuntime(push: StubSession(), pull: StubSession(body: emptyPageJSON())) { runtime, _, _ in
            // Idempotente: parado sigue parado.
            runtime.stopUntilSignIn()
            #expect(runtime.state == .stoppedUntilSignIn)
            // Y no rebaja ni despierta otro estado: tras el teardown el motor está sin sesión, no «hasta firmar». La puerta de
            // ese estado la da la tarjeta con `.idleSignedOut` sin sesión (`SyncSignInBannerLogic.engineWaitsForSignIn`).
            runtime.teardownGuestSession()
            runtime.stopUntilSignIn()
            #expect(runtime.state == .idleSignedOut)
        }
    }

    @Test("MUTACIÓN: con OTRA cuenta firmada el ciclo no toca la red y lo lee como sesión caducada; con la del dueño, sube")
    func aCycleWithAnotherAccount_neitherPushesNorPulls() async throws {
        // La respuesta del push da igual: lo que se mide es si la petición SALE.
        let push = StubSession()
        let pull = StubSession(body: emptyPageJSON())
        try await withStoppedCloudRuntime(push: push, pull: pull) { runtime, session, context in
            _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
            let pushesBefore = push.callCount, pullsBefore = pull.callCount

            // Entró otra cuenta por cualquier puerta.
            session.currentUserID = "u2"
            #expect(await runtime.syncCycle(context: context) == .sessionExpired)
            #expect(push.callCount == pushesBefore, "el outbox del dueño no sube con el JWT de otra cuenta")
            #expect(pull.callCount == pullsBefore, "y lo de la otra cuenta no baja a este store")

            // La otra dirección: vuelve la cuenta del dueño y el ciclo sí habla con el servidor.
            session.currentUserID = "u1"
            _ = await runtime.syncCycle(context: context)
            #expect(push.callCount > pushesBefore, "con la cuenta del dueño, lo pendiente sube")
        }
    }

    /// Sin sesión no es «otra cuenta»: ése lo contestan el preflight y el pull, con su canario. Si la guarda lo cubriera,
    /// cortaría antes que ellos. Aquí la sesión falta en `currentUserID` pero el cliente aún tiene token: el push sale.
    @Test("MUTACIÓN: sin `sub` la guarda del dueño no corta el ciclo; lo decide lo de siempre")
    func noSessionIsNotAnotherAccount() async throws {
        let push = StubSession()
        try await withStoppedCloudRuntime(push: push, pull: StubSession(body: emptyPageJSON())) { runtime, session, context in
            _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
            let before = push.callCount
            session.currentUserID = nil
            session.canRenewSession = true
            _ = await runtime.syncCycle(context: context)
            #expect(push.callCount > before)
        }
    }

    /// Tras relanzar sin sesión el motor no fija dueño (`.idleSignedOut`), y el cierre de sesión llama a `syncCycle` igual. En
    /// la nube, el ancla es entonces el sello del claim: una sesión sin sello —otra cuenta que entró por «Nuevo grupo»— no
    /// sube ni baja nada; una con sello, sí (review del 2026-09-25).
    @Test("MUTACIÓN: sin dueño en memoria, en la nube el ciclo solo habla con el servidor con una cuenta sellada")
    func withoutAnOwner_theClaimStampDecides() async throws {
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .cloud
        defer { CloudSyncFlags.storageMode = prevMode }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let push = StubSession()
        let pull = StubSession(body: emptyPageJSON())
        let session = StubCloudSession(userID: "u2", claim: nil)
        let runtime = makeRuntime(push: push, pull: pull, session: session)
        #expect(runtime.ownerUserID == nil, "control: el motor no arrancó y no tiene dueño")

        #expect(await runtime.syncCycle(context: context) == .sessionExpired)
        #expect(push.callCount == 0 && pull.callCount == 0, "una cuenta sin sello no toca el servidor")

        session.claimAction = .routeReturningUser
        _ = await runtime.syncCycle(context: context)
        #expect(push.callCount > 0, "con el sello de este teléfono, lo pendiente sube")
    }

    /// Fuera de la nube el ancla no aplica: el trato de antes.
    @Test("Sin dueño y fuera de la nube, la guarda no corta")
    func withoutAnOwner_outsideTheCloud_doesNotCut() async throws {
        let prevMode = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = .icloud
        defer { CloudSyncFlags.storageMode = prevMode }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try liveRow(context, entityType: SyncEntityType.transactionItem, h: hlc(1))
        let push = StubSession()
        let runtime = makeRuntime(push: push, pull: StubSession(body: emptyPageJSON()),
                                  session: StubCloudSession(userID: "u2", claim: nil))
        _ = await runtime.syncCycle(context: context)
        #expect(push.callCount > 0)
    }

    @Test("MUTACIÓN: volver a primer plano con otra cuenta no reanuda la cadencia; con la del dueño, sí")
    func becomingActive_resumesOnlyForTheOwner() async throws {
        try await withStoppedCloudRuntime(push: StubSession(), pull: StubSession(body: emptyPageJSON())) { runtime, session, _ in
            session.currentUserID = "u2"
            runtime.handleBecameActive()
            #expect(runtime.state == .stoppedUntilSignIn)
            session.currentUserID = nil
            runtime.handleBecameActive()
            #expect(runtime.state == .stoppedUntilSignIn, "sin sesión tampoco: el trato de antes")
            session.currentUserID = "u1"
            runtime.handleBecameActive()
            #expect(runtime.state == .running)
        }
    }
}

// MARK: - Stubs

/// Stub de `SyncHTTPSession` que LANZA: la petición salió y no volvió (sin cobertura, timeout).
private final class ThrowingSession: SyncHTTPSession, @unchecked Sendable {
    let error: Error
    init(_ error: Error) { self.error = error }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { throw error }
}

/// Push que responde `applied` a cada delta que recibe: para subir filas que el drain crea en el propio test, cuyos
/// `sync_id` no se conocen al montar el stub.
private final class EchoAppliedSession: SyncHTTPSession, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var appliedCount = 0
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        var results: [String] = []
        if let body = request.httpBody,
           let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
           let deltas = json["deltas"] as? [[String: Any]] {
            for delta in deltas {
                guard let sid = delta["sync_id"] as? String, let cmid = delta["client_mutation_id"] as? String else { continue }
                results.append("{\"sync_id\":\"\(sid)\",\"client_mutation_id\":\"\(cmid)\",\"status\":\"applied\"}")
            }
        }
        appliedCount += results.count
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data("{\"results\":[\(results.joined(separator: ","))]}".utf8), response)
    }
}

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
    /// Un error que NO es `AppAttestError`, como los de DeviceCheck, que `AppAttestClient` no envuelve.
    var otherAttestError: (any Error)?
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
        if let otherAttestError { throw otherAttestError }
        return nil
    }
}
