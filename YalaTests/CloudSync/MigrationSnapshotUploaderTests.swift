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

/// Un error cualquiera de la base local, para el `catch` genérico del encolado.
private struct FakeLocalError: Error {}

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
                              _ stub: ApplyingStubSession, pageSize: Int,
                              canRenewSession: Bool = false,
                              leaseStillConfirmed: @escaping @MainActor () -> Bool = { true }) -> MigrationSnapshotUploader {
        let push = SyncPushClient(baseURL: workerURL, tokenProvider: { "jwt" }, urlSession: stub)
        return MigrationSnapshotUploader(engine: engine, pushClient: push, context: context,
                                         calendar: Calendar(identifier: .gregorian),
                                         now: { self.fixedNow }, pageSize: pageSize,
                                         canRenewSession: { canRenewSession },
                                         leaseStillConfirmed: leaseStillConfirmed)
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
            case let .blocked(blocker):
                Issue.record("blocked(\(blocker)) inesperado")
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

    // MARK: - El outbox que no se deja leer (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`)

    /// **Aquí el `[]` del `catch` CONFIRMABA la página.** `drainPushConfirm` devolvía `true` —«subido, avanza el
    /// cursor»— cuando lo cierto era que nadie había podido mirar el outbox, así que el snapshot seguía adelante
    /// dejando atrás filas que no viajaron.
    ///
    /// El control del final es lo que impide que el caso se sostenga por casualidad: con el store legible, el
    /// mismo dataset confirma su página y sube de verdad.
    @Test("uploadPage: un outbox ilegible no confirma la página")
    func uploadPage_unreadableOutbox_neverConfirms() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let cat = Category(name: "cat", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 10)
        uploader._testOutboxFetchThrowsFromCall = 1

        let outcome = await uploader.uploadPage(cursor: nil)
        // Igualdad con UN caso concreto, no una desigualdad: excluye a la vez `.pageConfirmed`, `.completed` y
        // `.transient`. Desde `snapshot-upload-has-no-ceiling-and-no-way-out` además dice POR QUÉ, que es lo que elige
        // el techo corto de la fase: con `.transient` la subida esperaría 72 h a una avería que esperar no arregla.
        #expect(outcome == .blocked(.localFailure),
                "sin poder leer el outbox no se avanza el cursor ni se cierra la pasada, y se dice por qué")
        #expect(stub.pushedSyncIDs.isEmpty, "y no se sube nada a ciegas")

        // Control en la dirección contraria: sin la avería, el mismo dataset sube y confirma.
        uploader._testOutboxFetchThrowsFromCall = nil
        let healthy = await uploader.uploadPage(cursor: nil)
        #expect({ if case .pageConfirmed = healthy { return true }; return false }(),
                "control: sin la avería este dataset SÍ avanza (\(healthy))")
        #expect(!stub.pushedSyncIDs.isEmpty, "control: y sube de verdad — la fila existía")
    }

    /// La RELECTURA de después del push, que es otra decisión y otro `catch`. Con el seam en la 2.ª llamada el
    /// pre-check pasa, el push corre de verdad —lo afirma `pushedSyncIDs`— y lo que falla es la comprobación de
    /// «¿quedó algo vivo?». Con el `[]` de antes eso valía **página confirmada**.
    ///
    /// El seam es un contador y no un `Bool` justo por esto: con un `Bool` la primera lectura corta y esta rama
    /// no se recorre nunca. Lo cazó una lente de la review del 2026-09-22 sobre el seam gemelo del Merkle.
    @Test("uploadPage: si el outbox se vuelve ilegible DESPUÉS del push, la página tampoco se confirma")
    func uploadPage_unreadableAfterPush_neverConfirms() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let cat = Category(name: "cat", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 10)
        uploader._testOutboxFetchThrowsFromCall = 2

        let outcome = await uploader.uploadPage(cursor: nil)
        #expect(!stub.pushedSyncIDs.isEmpty, "control del escenario: el push TIENE que haber corrido")
        #expect(outcome == .blocked(.localFailure), "la relectura que no se deja hacer no confirma la página")
    }

    /// El CIERRE de la pasada, que es el otro desenlace del mismo helper y devolvía `.completed`. Se alcanza con
    /// el store vacío: sin páginas que paginar, `uploadPage` va directo a `finishResidual`.
    ///
    /// Es un test aparte y no una aserción más del de arriba porque son dos funciones distintas: un arreglo que
    /// solo cubriera `drainPushConfirm` dejaría ésta devolviendo «pasada completa» sobre un outbox que nadie
    /// pudo leer, y ningún test lo diría.
    @Test("uploadPage: con el store vacío, un outbox ilegible no cierra la pasada como completa")
    func finishResidual_unreadableOutbox_isBlockedNotCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let uploader = makeUploader(context, engine, stub, pageSize: 10)

        // Control del escenario PRIMERO: sin la avería, este store cierra la pasada. Si no fuera así, el
        // desenlace de abajo podría venir de cualquier otra cosa.
        #expect(await uploader.uploadPage(cursor: nil) == .completed,
                "control del escenario: con el store vacío la pasada se cierra")

        let sick = makeUploader(context, engine, stub, pageSize: 10)
        sick._testOutboxFetchThrowsFromCall = 1
        #expect(await sick.uploadPage(cursor: nil) == .blocked(.localFailure),
                "y con el outbox ilegible NO se cierra: el runner reintenta antes de avanzar, con el motivo")
    }

    /// Una tabla que no se deja leer NO es una tabla agotada (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`).
    /// El paginador devolvía `([], nil, false)`, `nextPage` la saltaba y, siendo la última tabla con filas, la pasada
    /// CERRABA con `.completed`: esas filas no llegaban nunca a la nube y el paso no vuelve a pasar por ahí. El seam
    /// lanza un `CocoaError` dentro del `do` real, así que el test solo pasa si ese `catch` lo convierte.
    @Test("uploadPage: una tabla ilegible no se da por subida — .blocked(.localFailure), nunca .completed")
    func unreadableTable_isBlockedNotSkipped() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let cat = Category(name: "food", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        let tag = Tag(name: "viaje")
        context.insert(tag)
        try context.save()

        // `categories` va antes que `tags` (UTF-8 asc): la primera página se sube y la avería llega en la última tabla.
        let sick = makeUploader(context, engine, stub, pageSize: 10)
        sick._testThrowOnInventoryFetchOf = ["Tag"]
        guard case let .pageConfirmed(cursor) = await sick.uploadPage(cursor: nil) else {
            Issue.record("control del escenario: la tabla legible de antes tiene que subirse")
            return
        }
        #expect(await sick.uploadPage(cursor: cursor) == .blocked(.localFailure),
                "la tabla ilegible corta con el motivo local: saltarla cerraba la pasada como completa")
        #expect(!stub.pushedSyncIDs.contains(tag.id.uuidString.lowercased()), "la fila de la tabla ilegible no se inventa")

        // Control: legible, la misma pasada sube la fila y cierra.
        let healthy = makeUploader(context, engine, stub, pageSize: 10)
        #expect(await healthy.uploadPage(cursor: cursor) != .blocked(.localFailure))
        _ = await runToCompletion(healthy)
        #expect(stub.pushedSyncIDs.contains(tag.id.uuidString.lowercased()),
                "control del escenario: sin la avería esa fila SÍ se sube")
    }

    /// El caso extremo: la única tabla con filas es la ilegible. `nextPage` devolvía `nil` al PRIMER intento y la pasada
    /// entera se daba por completa sin subir nada.
    @Test("uploadPage: con la única tabla con filas ilegible, la pasada no cierra vacía")
    func onlyTableUnreadable_isBlockedNotCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()
        context.insert(Tag(name: "viaje"))
        try context.save()

        let sick = makeUploader(context, engine, stub, pageSize: 10)
        sick._testThrowOnInventoryFetchOf = ["Tag"]
        #expect(await sick.uploadPage(cursor: nil) == .blocked(.localFailure))
        #expect(stub.pushedSyncIDs.isEmpty)
    }

    // MARK: - Qué motivo lleva cada corte (`snapshot-upload-has-no-ceiling-and-no-way-out`)
    //
    // Hasta este ticket los cuatro cortes de abajo salían como `.transient`, y sin separarlos el techo de la fase no
    // podía tener un plazo corto: una cuenta suspendida esperaba lo mismo que un túnel. Cada caso fija el suyo con
    // igualdad exacta, y el de red (`pushTransient_cursorNotAdvanced`, arriba) fija que la red SIGUE siendo `.transient`.

    /// Un 401 que no es el de App Attest: la sesión ya no vale. En la ida la tarjeta no ofrece «Iniciar sesión», y la
    /// salida del techo (la tarjeta de fallo con «Reintentar») es la que vuelve a pedirla: por eso es definitivo aquí.
    @Test("uploadPage: un push 401 corta con .blocked(.sessionExpired)")
    func uploadPage_push401_isSessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()
        stub.failWithStatus = 401

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let outcome = await makeUploader(context, engine, stub, pageSize: 10).uploadPage(cursor: nil)
        #expect(outcome == .blocked(.sessionExpired))
        #expect(try !liveOutbox(context).isEmpty, "la fila sigue encolada: nada se dio por subido")
    }

    /// **El 401 con la sesión todavía GUARDADA no es definitivo** (hallazgo de las tres lentes de la review). Su caso
    /// principal es el reloj del teléfono atrasado: el gateway rechaza un JWT que el SDK aún da por bueno, y lo cura la
    /// renovación del SDK a su hora. Definitivo, sacaba de la subida a los 15 min y el reintento reusaba el mismo JWT
    /// sin pedir nada. Aquí es `.transient` —el techo largo— en la página y en el residual; el caso de arriba, con la
    /// sesión borrada (`canRenewSession == false`), es el que sigue siendo definitivo.
    @Test("uploadPage: un push 401 con la sesión todavía guardada es .transient, no definitivo")
    func uploadPage_push401_withARenewableSession_isTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 10, canRenewSession: true)
        guard case let .pageConfirmed(cursor) = await uploader.uploadPage(cursor: nil) else {
            Issue.record("control del escenario: la primera página tiene que confirmarse"); return
        }
        // Página: un segundo registro para que haya otra página que subir con el 401.
        let cat2 = Category(name: "rent", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat2.syncID = UUID(uuidString: "ffffffff-ffff-4fff-bfff-ffffffffffff")
        context.insert(cat2)
        try context.save()
        stub.failWithStatus = 401
        #expect(await uploader.uploadPage(cursor: cursor) == .transient, "página")

        // Residual: sin páginas que paginar y con una fila viva.
        stub.failWithStatus = nil
        let fresh = makeUploader(context, engine, stub, pageSize: 10, canRenewSession: true)
        var c = cursor
        while case let .pageConfirmed(next) = await fresh.uploadPage(cursor: c) { c = next }
        cat.name = "food-edited"
        try context.save()
        stub.failWithStatus = 401
        #expect(await fresh.uploadPage(cursor: c) == .transient, "residual")
        #expect(try !liveOutbox(context).isEmpty, "control: el residual tenía una fila viva que subir")
    }

    /// Un `fetch`/`save` LOCAL que lanza al encolar la página (el `catch` genérico) es `.blocked(.localFailure)`; la
    /// deriva del reloj, `.transient`. Los dos `catch` se recorren con el seam, sin romper el store.
    @Test("uploadPage: un fallo local al encolar es .blocked(.localFailure); la deriva del reloj, .transient")
    func uploadPage_enqueueFailures_areClassifiedByKind() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 10)
        uploader._testEnqueueError = FakeLocalError()
        #expect(await uploader.uploadPage(cursor: nil) == .blocked(.localFailure))
        uploader._testEnqueueError = ClockDriftError.driftExceeded(driftMillis: 600_000)
        #expect(await uploader.uploadPage(cursor: nil) == .transient)
        #expect(stub.pushedSyncIDs.isEmpty, "control: los dos cortes fueron al encolar, antes de subir nada")
    }

    @Test("uploadPage: un push 403 corta con .blocked(.accountUnavailable)")
    func uploadPage_push403_isAccountUnavailable() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()
        stub.failWithStatus = 403

        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let outcome = await makeUploader(context, engine, stub, pageSize: 10).uploadPage(cursor: nil)
        #expect(outcome == .blocked(.accountUnavailable))
        #expect(try !liveOutbox(context).isEmpty, "la fila sigue encolada: nada se dio por subido")
    }

    /// El CIERRE de la pasada tiene su propio `switch` del push, y un arreglo que solo tipara el de la página lo dejaría
    /// devolviendo `.transient`. Se llega con las páginas ya confirmadas y un cambio posterior que el drain captura
    /// como incremental: sin páginas que paginar, `uploadPage` va a `finishResidual` con una fila viva.
    @Test("finishResidual: el push del residual también tipa el 401 y el 403")
    func finishResidual_push401and403_areTyped() async throws {
        for (status, expected) in [(401, SnapshotStepOutcome.blocked(.sessionExpired)),
                                   (403, SnapshotStepOutcome.blocked(.accountUnavailable))] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let engine = CloudSyncEngine()
            let stub = ApplyingStubSession()

            let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
            cat.syncID = UUID()
            context.insert(cat)
            try context.save()

            let uploader = makeUploader(context, engine, stub, pageSize: 10)
            guard case let .pageConfirmed(cursor) = await uploader.uploadPage(cursor: nil) else {
                Issue.record("control del escenario: la primera página tiene que confirmarse"); return
            }
            cat.name = "food-edited"
            try context.save()
            stub.failWithStatus = status
            #expect(await uploader.uploadPage(cursor: cursor) == expected, "status \(status)")
            #expect(try !liveOutbox(context).isEmpty, "control: el residual tenía una fila viva que subir")
        }
    }

    /// Los DOS push de la subida —el de la página y el del residual— preguntan por la confirmación del lease antes de
    /// cada trozo (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`). Sin ella no sale nada y la
    /// pasada es `.transient`: la puerta del runner vuelve a preguntar en la siguiente.
    @Test("uploadPage: sin la confirmación del lease no sube ni la página ni el residual")
    func leaseStillConfirmed_gatesThePageAndTheResidualPush() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()
        let cat = Category(name: "food", colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()
        var confirmed = false
        let uploader = makeUploader(context, engine, stub, pageSize: 10, leaseStillConfirmed: { confirmed })

        #expect(await uploader.uploadPage(cursor: nil) == .transient, "página")
        #expect(stub.pushedSyncIDs.isEmpty, "la página no sale")

        confirmed = true
        guard case let .pageConfirmed(cursor) = await uploader.uploadPage(cursor: nil) else {
            Issue.record("control del escenario: con la confirmación la página se confirma"); return
        }
        cat.name = "food-edited"
        try context.save()
        stub.resetCapture()
        confirmed = false
        #expect(await uploader.uploadPage(cursor: cursor) == .transient, "residual")
        #expect(stub.pushedSyncIDs.isEmpty, "el residual no sale")
        #expect(try !liveOutbox(context).isEmpty, "control: el residual tenía una fila viva que subir")
    }

    /// La DERIVA del reloj (HLC por delante del reloj de pared más de 5 min) va como `.transient`, no como fallo
    /// local: el reloj puede corregirse solo, y el texto de «este dispositivo no pudo preparar tus datos» no sería
    /// verdad. Se provoca subiendo una página con un reloj y la siguiente con otro un día atrás: el HLC persistido va
    /// por delante.
    @Test("uploadPage: la deriva del reloj al encolar es .transient, no .blocked(.localFailure)")
    func uploadPage_clockDrift_isTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let stub = ApplyingStubSession()

        for name in ["a", "b"] {
            let cat = Category(name: name, colorHex: "#ABCDEF", isIncome: false, isDefaultSeed: false)
            cat.syncID = UUID()
            context.insert(cat)
        }
        try context.save()

        let uploader = makeUploader(context, engine, stub, pageSize: 1)
        guard case let .pageConfirmed(cursor) = await uploader.uploadPage(cursor: nil) else {
            Issue.record("control del escenario: la primera página tiene que confirmarse"); return
        }
        let push = SyncPushClient(baseURL: workerURL, tokenProvider: { "jwt" }, urlSession: stub)
        let behind = MigrationSnapshotUploader(
            engine: engine, pushClient: push, context: context, calendar: Calendar(identifier: .gregorian),
            now: { self.fixedNow.addingTimeInterval(-86_400) }, pageSize: 1)
        stub.resetCapture()
        #expect(await behind.uploadPage(cursor: cursor) == .transient)
        #expect(stub.pushedSyncIDs.isEmpty, "control: el corte fue al encolar, antes de subir nada")
    }

    // MARK: - Helpers

    /// Extrae el nombre de tabla de un cursor JSON `{table, afterSyncID}` para las asserts de orden.
    private func cursorTable(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["table"] as? String
    }
}
