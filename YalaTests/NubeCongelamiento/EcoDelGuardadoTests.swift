//
//  EcoDelGuardadoTests.swift
//  YalaTests / NubeCongelamiento
//
//  YALA-IOS-A (resto, 2026-11-21): con la nube activa, cada guardado recalculaba la app DOS veces. La primera, al guardar
//  (el formulario sube `dataVersion`). La segunda, 2-5 s después: el ciclo de la nube sube lo guardado, el pull devuelve
//  ese mismo cambio —el servidor no filtra por origen—, el apply lo cuenta como página aplicada y el aviso
//  (`fanOutRemoteChangesApplied` → `RemoteChangesFanOut`) vuelve a subir `dataVersion`. Con un historial grande, ese segundo
//  recálculo era el congelamiento de Sentry (YALA-IOS-A, y con pila propia YALA-IOS-14/15/16, misma apertura).
//
//  Se fija, con el ciclo real (`CloudSyncRuntime.syncCycle`) contra un servidor falso que devuelve lo que recibe como el
//  gateway (`server_seq > since`, los `field_hlcs` guardados):
//   1. el eco de lo propio no avisa a la app, y un guardado acaba en UNA sola subida de `dataVersion`;
//   2. lo que llega de otro aparato sí avisa: fila nueva, edición de una fila que ya está aquí y borrado;
//   3. una página que mezcla eco y cambio ajeno avisa (una vez);
//   4. el eco se sigue aplicando: el cursor avanza igual y los datos no cambian.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-A · el eco de lo guardado no recalcula la app otra vez", .serialized)
@MainActor
struct EcoDelGuardadoTests {

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EcoGuardado-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration("EG-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("EG-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("EG-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personal, groups, meta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func makeRuntime(server: EchoServer, engine: CloudSyncEngine, onApplied: @escaping () -> Void) -> CloudSyncRuntime {
        let base = stubBaseURL
        return CloudSyncRuntime(
            engine: engine,
            pushClient: SyncPushClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: server, canRenewSession: { true }),
            pullClient: SyncPullClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: server, canRenewSession: { true }),
            merkleClient: SyncMerkleClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: EmptyMerkleSession()),
            mirror: nil,
            coordinator: SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud }),
            session: EcoCloudSession(),
            onRemoteChangesApplied: onApplied
        )
    }

    /// Un gasto con su cuenta, guardado como lo guarda el formulario.
    @discardableResult
    private func saveExpense(_ context: ModelContext, note: String = "café") throws -> TransactionItem {
        let account = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_763_700_000), amount: -12.5,
                                 currencyCode: "PEN", account: account)
        tx.note = note
        context.insert(tx)
        try context.save()
        return tx
    }

    private func cursor(_ engine: CloudSyncEngine, _ context: ModelContext) throws -> Int64 {
        try engine.loadOrCreateCursor(context).serverSeqCursor
    }

    // MARK: - 1. El eco de lo propio

    @Test func guardarConLaNube_elEcoNoAvisaALaApp() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        let engine = CloudSyncEngine()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: engine) { avisos += 1 }

        try saveExpense(context)
        _ = await runtime.syncCycle(context: context)

        // Control del escenario: subió, y el pull devolvió lo subido y lo aplicó (el cursor llegó hasta el eco).
        #expect(server.storedCount >= 2, "el push no subió la cuenta y el gasto (\(server.storedCount))")
        #expect(server.pullsServingDeltas >= 1, "el pull no devolvió el eco")
        #expect(try cursor(engine, context) == server.maxSeq)
        #expect(engine.lastPullChangedLocalData == false)
        #expect(avisos == 0, "el eco de lo propio avisó a la app \(avisos) vez/veces: recalcula todo otra vez")
    }

    /// El criterio del encargo: una sola recalculación por guardado, contada en `dataVersion`.
    @Test func unGuardado_subeDataVersionUnaSolaVez() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        let state = SessionState()
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) {
            RemoteChangesFanOut.receive(isApplicationActive: true, session: state)
        }
        let before = state.dataVersion

        try saveExpense(context)
        state.incrementDataVersion()          // lo que hace el formulario al guardar
        _ = await runtime.syncCycle(context: context)
        _ = await runtime.syncCycle(context: context)   // un ciclo más, ya sin nada: tampoco recalcula

        #expect(state.dataVersion - before == 1, "recalculaciones por guardado: \(state.dataVersion - before)")
    }

    /// El eco se sigue aplicando: los datos quedan como estaban y no queda nada pendiente de subir.
    @Test func elEco_dejaLosDatosComoEstaban() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) {}

        let tx = try saveExpense(context, note: "almuerzo")
        let id = tx.persistentModelID
        _ = await runtime.syncCycle(context: context)

        let fresh = ModelContext(context.container)
        let reread = try #require(fresh.model(for: id) as? TransactionItem)
        #expect(reread.note == "almuerzo")
        #expect(reread.amount == -12.5)
        #expect(try context.fetch(FetchDescriptor<SyncOutbox>()).isEmpty)
    }

    /// Borrar aquí: el eco del borrado no encuentra la fila (ya no está) y no avisa.
    @Test func borrarConLaNube_elEcoDelBorradoNoAvisa() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) { avisos += 1 }

        let tx = try saveExpense(context)
        _ = await runtime.syncCycle(context: context)
        #expect(avisos == 0)

        context.delete(tx)
        try context.save()
        let seqBefore = server.maxSeq
        _ = await runtime.syncCycle(context: context)

        #expect(server.maxSeq > seqBefore, "el borrado no subió")
        #expect(avisos == 0, "el eco del propio borrado avisó a la app")
    }

    // MARK: - 2. Lo que llega de otro aparato sí avisa

    @Test func unGastoNuevoDeOtroAparato_avisa() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        let engine = CloudSyncEngine()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: engine) { avisos += 1 }

        server.inject(EchoServer.foreignExpense(syncID: UUID(), hlc: EchoServer.foreignHLC(1)))
        _ = await runtime.syncCycle(context: context)

        #expect(engine.lastPullChangedLocalData)
        #expect(avisos == 1)
    }

    @Test func unaEdicionDeOtroAparato_sobreUnaFilaDeAqui_avisa() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) { avisos += 1 }

        let tx = try saveExpense(context, note: "antes")
        _ = await runtime.syncCycle(context: context)
        #expect(avisos == 0)
        let syncID = try #require(tx.syncID, "el drain no le dio identidad de sincronización")

        // Otro aparato cambia la nota: la misma fila vuelve con la unidad `note` estampada por otro reloj.
        try server.editStored(table: "tx_items", syncID: syncID, column: "note", value: "después",
                              unit: "note", hlc: EchoServer.foreignHLC(2))
        _ = await runtime.syncCycle(context: context)

        #expect(avisos == 1, "una edición de otro aparato no avisó a la app")
        let fresh = ModelContext(context.container)
        let reread = try #require(fresh.model(for: tx.persistentModelID) as? TransactionItem)
        #expect(reread.note == "después")
    }

    @Test func unBorradoDeOtroAparato_avisa() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) { avisos += 1 }

        let tx = try saveExpense(context)
        _ = await runtime.syncCycle(context: context)
        let syncID = try #require(tx.syncID, "el drain no le dio identidad de sincronización")

        server.tombstoneStored(table: "tx_items", syncID: syncID, hlc: EchoServer.foreignHLC(3))
        _ = await runtime.syncCycle(context: context)

        #expect(avisos == 1)
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty)
    }

    /// Una fila sin su reloj por unidad (`SyncUnitClock` es caché derivable: puede volver vacía tras una migración ligera)
    /// no puede leerse como eco: una edición de otro aparato sobre ella avisa (review del 2026-11-21).
    @Test func filaSinRelojLocal_unaEdicionAjena_avisa() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) { avisos += 1 }

        let tx = try saveExpense(context, note: "antes")
        _ = await runtime.syncCycle(context: context)
        let syncID = try #require(tx.syncID, "el drain no le dio identidad de sincronización")
        let clocks = try context.fetch(FetchDescriptor<SyncUnitClock>(predicate: #Predicate { $0.syncID == syncID }))
        #expect(!clocks.isEmpty, "el escenario quería una fila con reloj que borrar")
        for clock in clocks { context.delete(clock) }
        try context.save()

        try server.editStored(table: "tx_items", syncID: syncID, column: "note", value: "después",
                              unit: "note", hlc: EchoServer.foreignHLC(5))
        _ = await runtime.syncCycle(context: context)

        #expect(avisos == 1, "sin reloj local, la edición de otro aparato se leyó como eco")
    }

    /// Si el reloj por unidad no se deja leer, la página no se aplica (la escritura del reloj vuelve a leerlo y lanza),
    /// el cursor no se mueve y no se avisa; al volver a leerse, la edición entra y avisa.
    @Test func relojIlegible_laPaginaNoSeAplica_niAvisa_yLuegoSi() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        let engine = CloudSyncEngine()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: engine) { avisos += 1 }

        let tx = try saveExpense(context, note: "antes")
        _ = await runtime.syncCycle(context: context)
        let syncID = try #require(tx.syncID)
        let cursorBefore = try cursor(engine, context)

        try server.editStored(table: "tx_items", syncID: syncID, column: "note", value: "después",
                              unit: "note", hlc: EchoServer.foreignHLC(6))
        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        defer { EntityApplyMap._testThrowOnFetchOf = [] }
        _ = await runtime.syncCycle(context: context)

        #expect(avisos == 0)
        #expect(engine.lastPullChangedLocalData == false)
        #expect(try cursor(engine, context) == cursorBefore, "el cursor avanzó con la página sin aplicar")

        EntityApplyMap._testThrowOnFetchOf = []
        _ = await runtime.syncCycle(context: context)
        #expect(avisos == 1, "al volver a leerse el reloj, la edición no avisó")
    }

    /// La regla del eco, sin el ciclo: mismo HLC es eco; sin reloj local, con otro nodo o con un HLC que no parsea, no.
    @Test func isOwnEcho_soloConElMismoHLC() {
        let mine = "2026-11-21T10:00:00.000Z-0001-0123456789abcdef"
        #expect(CloudSyncEngine.isOwnEcho(remote: mine, local: mine))
        #expect(!CloudSyncEngine.isOwnEcho(remote: mine, local: nil))
        #expect(!CloudSyncEngine.isOwnEcho(remote: mine, local: "2026-11-21T10:00:00.000Z-0001-fedcba9876543210"))
        #expect(!CloudSyncEngine.isOwnEcho(remote: "no-es-un-hlc", local: "no-es-un-hlc"))
        #expect(!CloudSyncEngine.isOwnEcho(remote: mine, local: "2026-11-21T10:00:00.000Z-0002-0123456789abcdef"))
    }

    // MARK: - 3. Mezcla

    @Test func ecoYCambioAjenoEnLaMismaPagina_avisaUnaVez() async throws {
        let dir = try freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let server = EchoServer()
        var avisos = 0
        let runtime = makeRuntime(server: server, engine: CloudSyncEngine()) { avisos += 1 }

        // El ajeno entra en el servidor ANTES de que corra el ciclo: el pull lo trae junto al eco de lo propio.
        server.inject(EchoServer.foreignExpense(syncID: UUID(), hlc: EchoServer.foreignHLC(4)))
        try saveExpense(context)
        _ = await runtime.syncCycle(context: context)

        #expect(server.pullsServingDeltas == 1, "el escenario quería una sola página con los dos")
        #expect(avisos == 1)
    }
}

// MARK: - Servidor falso

/// Hace de gateway para `/sync/push` y `/sync/pull`: guarda una fila por (tabla, `sync_id`) con su `server_seq`, y el pull
/// devuelve lo posterior a `since` con los `fields` y `field_hlcs` guardados, como `gateway/src/sync/routes.ts`. Un
/// tombstone baja con `fields` y `field_hlcs` vacíos y el `hlc` del borrado.
private final class EchoServer: SyncHTTPSession, @unchecked Sendable {
    private struct Row {
        var seq: Int
        var delta: [String: Any]
    }
    private var rows: [String: Row] = [:]
    private var nextSeq = 1
    private(set) var pullsServingDeltas = 0

    var storedCount: Int { rows.count }
    var maxSeq: Int64 { Int64(rows.values.map(\.seq).max() ?? 0) }

    private func key(_ table: String, _ syncID: String) -> String { "\(table)|\(syncID.lowercased())" }

    private func store(_ delta: [String: Any]) {
        guard let table = delta["entity_type"] as? String, let sid = delta["sync_id"] as? String else { return }
        var kept = delta
        kept.removeValue(forKey: "client_mutation_id")
        if (kept["op"] as? String) == "tombstone" {
            kept["fields"] = [String: Any]()
            kept["field_hlcs"] = [String: String]()
        }
        rows[key(table, sid)] = Row(seq: nextSeq, delta: kept)
        nextSeq += 1
    }

    func inject(_ delta: [String: Any]) { store(delta) }

    func editStored(table: String, syncID: UUID, column: String, value: Any, unit: String, hlc: String) throws {
        let k = key(table, syncID.uuidString)
        guard var row = rows[k] else { throw EchoServerError.missingRow }
        var fields = row.delta["fields"] as? [String: Any] ?? [:]
        var hlcs = row.delta["field_hlcs"] as? [String: String] ?? [:]
        fields[column] = value
        hlcs[unit] = hlc
        row.delta["fields"] = fields
        row.delta["field_hlcs"] = hlcs
        row.delta["hlc"] = hlc
        rows[k] = nil
        store(row.delta)
    }

    func tombstoneStored(table: String, syncID: UUID, hlc: String) {
        store(["entity_type": table, "sync_id": syncID.uuidString.lowercased(), "op": "tombstone",
               "hlc": hlc, "schema_version": 1])
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (url, response) = try stubResponse(for: request)
        let path = url.path
        if path.hasSuffix("sync/push") {
            var results: [String] = []
            if let body = request.httpBody,
               let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
               let deltas = json["deltas"] as? [[String: Any]] {
                for delta in deltas {
                    guard let sid = delta["sync_id"] as? String,
                          let cmid = delta["client_mutation_id"] as? String else { continue }
                    store(delta)
                    results.append("{\"sync_id\":\"\(sid)\",\"client_mutation_id\":\"\(cmid)\",\"status\":\"applied\"}")
                }
            }
            return (Data("{\"results\":[\(results.joined(separator: ","))]}".utf8), response)
        }
        if path.hasSuffix("sync/pull") {
            let since = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "since" }?.value.flatMap { Int($0) } ?? 0
            let page = rows.values.filter { $0.seq > since }.sorted { $0.seq < $1.seq }
            if !page.isEmpty { pullsServingDeltas += 1 }
            let deltas: [[String: Any]] = page.map { row in
                var d = row.delta
                d["server_seq"] = row.seq
                if d["schema_version"] == nil { d["schema_version"] = 1 }
                if d["fields"] == nil { d["fields"] = [String: Any]() }
                if d["field_hlcs"] == nil { d["field_hlcs"] = [String: String]() }
                return d
            }
            let body: [String: Any] = ["deltas": deltas, "max_server_seq": page.last?.seq ?? since]
            return (try JSONSerialization.data(withJSONObject: body), response)
        }
        // prefs, grupos: nada que bajar.
        return (Data(#"{"deltas":[],"max_server_seq":0}"#.utf8), response)
    }

    // MARK: Datos de otro aparato

    /// HLC de otro reloj (otro nodo), con la hora de ahora para que el reloj local lo integre sin deriva.
    static func foreignHLC(_ counter: Int) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "\(formatter.string(from: .now))-\(String(format: "%04x", counter))-fedcba9876543210"
    }

    static func foreignExpense(syncID: UUID, hlc: String) -> [String: Any] {
        let ts = "2025-11-21T10:00:00.000Z"
        return [
            "entity_type": "tx_items",
            "sync_id": syncID.uuidString.lowercased(),
            "op": "upsert",
            "fields": [
                "date": ts, "amount": "-30.0000", "currency_code": "PEN", "note": "de otro teléfono",
                "amount_in_preferred_currency": "-30.0000", "preferred_currency_code": "PEN",
                "exchange_rate": "1.00000000", "is_exchange_rate_provisional": false, "created_at": ts,
                "tag_refs": [Any](),
            ] as [String: Any],
            "field_hlcs": ["money": hlc, "date": hlc, "note": hlc, "currency_code": hlc, "tag_refs": hlc,
                           "created_at": hlc],
            "hlc": hlc,
            "schema_version": 1,
        ]
    }
}

private enum EchoServerError: Error { case missingRow }

/// El Merkle no entra en este escenario: responde sin hojas.
private final class EmptyMerkleSession: SyncHTTPSession, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (_, response) = try stubResponse(for: request)
        return (Data(#"{"deltas":[],"max_server_seq":0}"#.utf8), response)
    }
}

@MainActor
private final class EcoCloudSession: CloudSyncSessionProviding {
    var currentUserID: String? { "u1" }
    func accessToken() async -> String? { "jwt" }
    var canRenewSession: Bool { true }
    func attestToken() async throws -> String? { nil }
}

/// Respuesta 200 del stub, sin `!`: una petición sin URL no la manda ningún cliente, y si llega, el test cae.
private func stubResponse(for request: URLRequest) throws -> (URL, HTTPURLResponse) {
    guard let url = request.url,
          let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
        throw URLError(.badURL)
    }
    return (url, response)
}

/// La base de los clientes del test; nunca se resuelve contra la red.
private let stubBaseURL = URL(fileURLWithPath: "/stub-gateway")
