//
//  MedicionGuardadoConNubeTests.swift
//  YalaTests / NubeCongelamiento
//
//  La medición del encargo YALA-IOS-A (2026-11-21), no una red: corre solo con `YALA_MEDIR_CONGELAMIENTO=1` en el entorno
//  del runner (`TEST_RUNNER_YALA_MEDIR_CONGELAMIENTO=1 xcodebuild test …`), porque siembra 20.000 movimientos y tarda.
//
//  El escenario: un Panel cargado con un historial grande, la nube activa contra un servidor que devuelve lo subido (el
//  gateway), y un guardado. Se cuenta cuántas veces recalcula el Panel y cuánto se bloquea el hilo principal, con un
//  latido de 5 ms en el main actor: cada hueco de más de 5 ms entre dos latidos es tiempo en que la app no respondía.
//  Imprime una línea `MEDICION|…` que el informe recoge. La red de verdad son `EcoDelGuardadoTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-A · medición del guardado con la nube", .serialized,
       .enabled(if: ProcessInfo.processInfo.environment["YALA_MEDIR_CONGELAMIENTO"] == "1"))
@MainActor
struct MedicionGuardadoConNubeTests {

    /// 20.000 por defecto (el historial del ticket de YALA-IOS-K); `YALA_MEDIR_HISTORIAL` lo cambia.
    private let historial = Int(ProcessInfo.processInfo.environment["YALA_MEDIR_HISTORIAL"] ?? "") ?? 20_000

    @Test func guardarConLaNube_recalculosYBloqueoDelHiloPrincipal() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MedicionNube-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { discardTestStoreDirectory(dir) }

        let personal = ModelConfiguration("MN-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("p.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("MN-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("g.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("MN-Meta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("m.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personal, groups, meta)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        // Historial grande, ya subido: un primer ciclo lo sube y baja su eco, para que la medición vea solo el guardado.
        let account = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        let base = Date(timeIntervalSince1970: 1_763_700_000)
        for i in 0..<historial {
            let tx = TransactionItem(date: base.addingTimeInterval(-Double(i) * 1_800), amount: -Double(i % 300 + 1),
                                     currencyCode: "PEN", account: account)
            context.insert(tx)
        }
        try context.save()

        let server = MedicionServer()
        let engine = CloudSyncEngine()
        let state = SessionState()
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(ModelContext(container), defaultCurrencyCode: "PEN", sessionState: state)
        // Lo que hace `PanelDataObservers`: cada subida de `dataVersion` recarga y recalcula el Panel.
        var lastVersion = state.dataVersion
        func followDataVersion() {
            if state.dataVersion != lastVersion {
                lastVersion = state.dataVersion
                viewModel.reloadAndRecalculate()
            }
        }
        let runtime = CloudSyncRuntime(
            engine: engine,
            pushClient: SyncPushClient(baseURL: medicionStubBaseURL, tokenProvider: { "jwt" },
                                       urlSession: server, canRenewSession: { true }),
            pullClient: SyncPullClient(baseURL: medicionStubBaseURL, tokenProvider: { "jwt" },
                                       urlSession: server, canRenewSession: { true }),
            merkleClient: SyncMerkleClient(baseURL: medicionStubBaseURL, tokenProvider: { "jwt" },
                                           urlSession: server),
            mirror: nil,
            coordinator: SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud }),
            session: MedicionSession(),
            onRemoteChangesApplied: {
                RemoteChangesFanOut.receive(isApplicationActive: true, session: state)
                followDataVersion()
            }
        )
        for _ in 0..<3 { _ = await runtime.syncCycle(context: context) }
        viewModel.reloadAndRecalculate()
        try await Task.sleep(for: .seconds(4))
        // Tres escenarios sobre el mismo almacén, cada uno con la app quieta antes de empezar:
        //  A · guardar y que el ciclo llegue con el recálculo del guardado ya terminado (lo normal: la cadencia es de 60 s);
        //  B · guardar y que el ciclo llegue a mitad de ese recálculo (+2 s: el hero aún va por tramos);
        //  C · sin guardar, un ciclo vacío a mitad de un recálculo cualquiera.
        var resumen: [String] = []
        print("MEDICION-LISTO pid=\(getpid())")
        for (nombre, guarda, retraso) in [("A-ciclo-despues", true, 9.0), ("B-ciclo-solapado", true, 2.0),
                                          ("C-ciclo-vacio-solapado", false, 2.0)] {
            try await Task.sleep(for: .seconds(4))
            let windowsBefore = viewModel.debugRecalculationWindowsOpened
            let versionBefore = state.dataVersion
            var gaps: [Double] = []
            var timeline: [String] = []
            let t0 = ContinuousClock.now
            func mark(_ what: String) {
                timeline.append(String(format: "%.0f:%@(w%d)", (ContinuousClock.now - t0).milliseconds, what,
                                       viewModel.debugRecalculationWindowsOpened - windowsBefore))
            }
            let heart = Task { @MainActor in
                var last = ContinuousClock.now
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(5)) } catch { break }
                    let now = ContinuousClock.now
                    let gap = (now - last).milliseconds - 5
                    if gap > 5 {
                        gaps.append(gap)
                        if gap > 100 { timeline.append(String(format: "%.0f:hueco%.0fms", (last - t0).milliseconds, gap)) }
                    }
                    last = now
                }
            }
            if guarda {
                // El guardado: el formulario guarda y sube `dataVersion`.
                mark("guardar")
                let tx = TransactionItem(date: base.addingTimeInterval(60), amount: -9.9, currencyCode: "PEN",
                                         account: account)
                context.insert(tx)
                try context.save()
                state.incrementDataVersion()
                followDataVersion()
            } else {
                mark("recalculo-pedido")
                viewModel.reloadAndRecalculate()
            }
            try await Task.sleep(for: .seconds(retraso))
            mark("ciclo-inicio")
            if ProcessInfo.processInfo.environment["YALA_MEDIR_SIN_CICLO"] != "1" {
                _ = await runtime.syncCycle(context: context)
            }
            mark("ciclo-fin")
            try await Task.sleep(for: .seconds(6))
            mark("fin")
            heart.cancel()
            _ = await heart.value

            let recalculos = viewModel.debugRecalculationWindowsOpened - windowsBefore
            let bumps = state.dataVersion - versionBefore
            let worst = gaps.max() ?? 0
            let blocked = gaps.reduce(0, +)
            let over250 = gaps.filter { $0 > 250 }.count
            let line = String(format: "MEDICION|escenario=%@|historial=%d|recalculos=%d|dataVersion=%d|bloqueo_max_ms=%.0f|bloqueo_total_ms=%.0f|huecos_mas_250ms=%d|huecos=%@",
                              nombre, historial, recalculos, bumps, worst, blocked, over250,
                              gaps.sorted(by: >).prefix(6).map { String(format: "%.0f", $0) }.joined(separator: ","))
            print(line)
            print("MEDICION-TIEMPO|\(nombre)|" + timeline.joined(separator: " "))
            resumen.append("\(nombre)=\(recalculos)")
        }
        #expect(resumen.count == 3)
    }
}

private extension Duration {
    var milliseconds: Double {
        let (s, atto) = components
        return Double(s) * 1_000 + Double(atto) / 1e15
    }
}

/// El gateway mínimo: devuelve en el pull lo que recibió en el push (ver `EcoDelGuardadoTests.EchoServer`).
private final class MedicionServer: SyncHTTPSession, @unchecked Sendable {
    private var rows: [String: (seq: Int, delta: [String: Any])] = [:]
    private var nextSeq = 1

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (url, response) = try medicionStubResponse(for: request)
        let path = url.path
        if path.hasSuffix("sync/push") {
            var results: [String] = []
            if let body = request.httpBody,
               let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
               let deltas = json["deltas"] as? [[String: Any]] {
                for delta in deltas {
                    guard let table = delta["entity_type"] as? String, let sid = delta["sync_id"] as? String,
                          let cmid = delta["client_mutation_id"] as? String else { continue }
                    var kept = delta
                    kept.removeValue(forKey: "client_mutation_id")
                    rows["\(table)|\(sid.lowercased())"] = (nextSeq, kept)
                    nextSeq += 1
                    results.append("{\"sync_id\":\"\(sid)\",\"client_mutation_id\":\"\(cmid)\",\"status\":\"applied\"}")
                }
            }
            return (Data("{\"results\":[\(results.joined(separator: ","))]}".utf8), response)
        }
        if path.hasSuffix("sync/pull") {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let since = items.first { $0.name == "since" }?.value.flatMap { Int($0) } ?? 0
            let limit = items.first { $0.name == "limit" }?.value.flatMap { Int($0) } ?? 500
            let page = rows.values.filter { $0.seq > since }.sorted { $0.seq < $1.seq }.prefix(limit)
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
        return (Data(#"{"deltas":[],"max_server_seq":0}"#.utf8), response)
    }
}

@MainActor
private final class MedicionSession: CloudSyncSessionProviding {
    var currentUserID: String? { "u1" }
    func accessToken() async -> String? { "jwt" }
    var canRenewSession: Bool { true }
    func attestToken() async throws -> String? { nil }
}

/// Respuesta 200 del stub, sin `!`: una petición sin URL no la manda ningún cliente, y si llega, el test cae.
private func medicionStubResponse(for request: URLRequest) throws -> (URL, HTTPURLResponse) {
    guard let url = request.url,
          let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
        throw URLError(.badURL)
    }
    return (url, response)
}

/// La base de los clientes del test; nunca se resuelve contra la red.
private let medicionStubBaseURL = URL(fileURLWithPath: "/stub-gateway")
