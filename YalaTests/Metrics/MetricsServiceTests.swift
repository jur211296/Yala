//
//  MetricsServiceTests.swift
//  YalaTests
//
//  Telemetría propia (C2 de la retirada de TelemetryDeck): lógica del ping diario,
//  spool persistido, cliente HTTP (asserta el BODY enviado — lección d49d2e47) y
//  semántica del servicio (no-op sin start, one-shots, drain).
//

import Foundation
import Testing
@testable import Yala

// MARK: - MetricsPingLogic (pura, tabla)

@Suite("MetricsPingLogic — día UTC y decisión de ping")
struct MetricsPingLogicTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) else {
            Issue.record("ISO inválida: \(iso)")
            return .distantPast
        }
        return d
    }

    @Test func dayString_esUTC_noLocal() {
        // 23:30 UTC del 1 de julio sigue siendo 1 de julio aunque en Lima sean las 18:30
        // y en Tokio ya sea 2 de julio — la key es UTC SIEMPRE.
        #expect(MetricsPingLogic.dayString(for: date("2026-07-01T23:30:00Z")) == "2026-07-01")
        #expect(MetricsPingLogic.dayString(for: date("2026-07-01T00:00:00Z")) == "2026-07-01")
        #expect(MetricsPingLogic.dayString(for: date("2026-12-31T23:59:59Z")) == "2026-12-31")
    }

    @Test func shouldPing_table() {
        typealias Row = (last: String?, nowISO: String, expected: Bool, note: String)
        let rows: [Row] = [
            (nil, "2026-07-17T10:00:00Z", true, "nunca pingueó"),
            ("2026-07-17", "2026-07-17T23:59:59Z", false, "mismo día UTC"),
            ("2026-07-16", "2026-07-17T00:00:01Z", true, "cambió el día"),
            ("2026-07-18", "2026-07-17T10:00:00Z", true, "reloj rebobinado → pingea igual (jamás silencio)"),
            ("garbage", "2026-07-17T10:00:00Z", true, "valor corrupto ≠ hoy → pingea"),
        ]
        for row in rows {
            #expect(
                MetricsPingLogic.shouldPing(lastPingDay: row.last, now: date(row.nowISO)) == row.expected,
                "\(row.note)"
            )
        }
    }
}

// MARK: - MetricsSpool (defaults aislados)

@Suite("MetricsSpool — cola persistida con cap drop-oldest")
struct MetricsSpoolTests {

    @Test func enqueue_persiste_y_pending_decodifica() {
        let defaults = makeIsolatedDefaults()
        MetricsSpool.enqueue(.ping(), defaults: defaults)
        MetricsSpool.enqueue(.register(kind: "local", detail: "full"), defaults: defaults)
        let pending = MetricsSpool.pending(defaults)
        #expect(pending.count == 2)
        #expect(pending[0] == .ping())
        #expect(pending[1].e == "register")
        #expect(pending[1].n == "local")
        #expect(pending[1].d == "full")
    }

    @Test func cap50_dropOldest() {
        let defaults = makeIsolatedDefaults()
        for i in 0..<55 {
            MetricsSpool.enqueue(.canary(name: "c\(i)", detail: nil, value: 1), defaults: defaults)
        }
        let pending = MetricsSpool.pending(defaults)
        #expect(pending.count == MetricsSpool.capacity)
        #expect(pending.first?.n == "c5", "caen los 5 MÁS VIEJOS")
        #expect(pending.last?.n == "c54")
    }

    @Test func removeFirst_retiraPorPrefijo() {
        let defaults = makeIsolatedDefaults()
        for i in 0..<4 {
            MetricsSpool.enqueue(.canary(name: "c\(i)", detail: nil, value: 1), defaults: defaults)
        }
        MetricsSpool.removeFirst(2, defaults: defaults)
        #expect(MetricsSpool.pending(defaults).map(\.n) == ["c2", "c3"])
        MetricsSpool.removeFirst(99, defaults: defaults)  // más que el tamaño → vacía sin crash
        #expect(MetricsSpool.pending(defaults).isEmpty)
    }

    @Test func spoolCorrupto_seDescartaSinCrash() {
        let defaults = makeIsolatedDefaults()
        defaults.set(Data("garbage".utf8), forKey: MetricsSpool.pendingKey)
        #expect(MetricsSpool.pending(defaults).isEmpty)
        // Y la key corrupta se limpió — el próximo enqueue repuebla limpio.
        MetricsSpool.enqueue(.ping(), defaults: defaults)
        #expect(MetricsSpool.pending(defaults).count == 1)
    }
}

// MARK: - MetricsClient (mock de red — asserta el BODY)

private final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    let error: Error?
    private(set) var lastRequest: URLRequest?
    var callCount = 0
    init(status: Int = 200, error: Error? = nil) {
        self.status = status
        self.error = error
    }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequest = request
        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data("{\"ok\":true}".utf8), response)
    }
}

@MainActor
@Suite("MetricsClient — wire y clasificación de outcomes")
struct MetricsClientTests {

    private let baseURL = URL(string: "https://gw.test")!

    @Test func send_construyeElBodyExacto() async throws {
        let stub = StubHTTPSession(status: 200)
        let client = MetricsClient(baseURL: baseURL, urlSession: stub)
        let outcome = await client.send(
            install: "a1b2c3d4e5f60718",
            app: "2.0.5",
            events: [.ping(), .canary(name: "cloudSyncMerkleDivergence", detail: "tx_items", value: 3)]
        )
        guard case .delivered = outcome else {
            Issue.record("esperaba delivered, fue \(outcome)")
            return
        }
        let request = try #require(stub.lastRequest)
        #expect(request.url?.path == "/metrics")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil, "endpoint público: sin auth")
        // Lección d49d2e47: assertar el BODY REALMENTE enviado, no solo que se llamó.
        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder().decode(MetricsRequestBody.self, from: body)
        #expect(decoded.v == 1)
        #expect(decoded.install == "a1b2c3d4e5f60718")
        #expect(decoded.app == "2.0.5")
        #expect(decoded.events.count == 2)
        #expect(decoded.events[0].e == "ping")
        #expect(decoded.events[1].n == "cloudSyncMerkleDivergence")
        #expect(decoded.events[1].x == 3)
    }

    @Test func outcomes_porStatus() async {
        for (status, expectDelivered, expectDropped) in [(200, true, false), (400, false, true), (500, false, false)] {
            let client = MetricsClient(baseURL: baseURL, urlSession: StubHTTPSession(status: status))
            let outcome = await client.send(install: "a1b2c3d4e5f60718", app: nil, events: [.ping()])
            switch outcome {
            case .delivered: #expect(expectDelivered, "status \(status)")
            case .dropped: #expect(expectDropped, "status \(status)")
            case .retry: #expect(!expectDelivered && !expectDropped, "status \(status)")
            }
        }
    }

    @Test func redCaida_esRetry() async {
        let stub = StubHTTPSession(error: URLError(.notConnectedToInternet))
        let client = MetricsClient(baseURL: baseURL, urlSession: stub)
        let outcome = await client.send(install: "a1b2c3d4e5f60718", app: nil, events: [.ping()])
        guard case .retry = outcome else {
            Issue.record("offline debe ser retry (el spool conserva)")
            return
        }
    }

    @Test func eventsVacios_noLlamaRed() async {
        let stub = StubHTTPSession()
        let client = MetricsClient(baseURL: baseURL, urlSession: stub)
        _ = await client.send(install: "a1b2c3d4e5f60718", app: nil, events: [])
        #expect(stub.callCount == 0)
    }
}

// MARK: - MetricsService (estado estático compartido → serialized + _testReset)

@MainActor
@Suite("MetricsService — gating, one-shots y drain", .serialized)
struct MetricsServiceTests {

    /// Arranca el servicio contra defaults AISLADOS y un stub de red; restaura al salir.
    private func withStartedService(
        status: Int = 200,
        _ body: (UserDefaults, StubHTTPSession) async throws -> Void
    ) async rethrows {
        let defaults = makeIsolatedDefaults()
        let stub = StubHTTPSession(status: status)
        MetricsService._testReset()
        MetricsService.start(
            client: MetricsClient(baseURL: URL(string: "https://gw.test")!, urlSession: stub),
            defaults: defaults
        )
        defer { MetricsService._testReset() }
        try await body(defaults, stub)
    }

    @Test func sinStart_todoEsNoOp() {
        MetricsService._testReset()
        let defaults = makeIsolatedDefaults()
        // Sin start: ni canary ni ping escriben NADA (paridad isConfigured del viejo servicio).
        MetricsService.canary(.cloudSyncMerkleDivergence, detail: "tx_items")
        MetricsService.dailyActivePingIfNeeded()
        MetricsService.localRegistrationCompleted(mode: "full")
        #expect(MetricsSpool.pending(defaults).isEmpty)
        #expect(MetricsSpool.pending(.standard).isEmpty, "jamás contamina .standard sin start")
    }

    @Test func pingDiario_soloUnaVezPorDia() async throws {
        try await withStartedService { defaults, _ in
            let day1 = Date(timeIntervalSince1970: 1_760_000_000)
            MetricsService.dailyActivePingIfNeeded(now: day1)
            MetricsService.dailyActivePingIfNeeded(now: day1.addingTimeInterval(3600))
            #expect(defaults.string(forKey: MetricsService.lastPingDayKey) == MetricsPingLogic.dayString(for: day1))
            // El 2º del mismo día NO encoló otro ping (el drain pudo haber vaciado el
            // primero — assertamos por la key del día, que es el guard real).
            let pings = MetricsSpool.pending(defaults).filter { $0.e == "ping" }
            #expect(pings.count <= 1)
        }
    }

    @Test func registroCloud_oneShotPorUserID() async throws {
        try await withStartedService(status: 500) { defaults, _ in
            // status 500 → retry → el spool CONSERVA (así podemos contar lo encolado).
            MetricsService.cloudRegistrationCompletedIfFirst(userID: "sub-abc", detail: "migration")
            MetricsService.cloudRegistrationCompletedIfFirst(userID: "sub-abc", detail: "migration")
            let registers = MetricsSpool.pending(defaults).filter { $0.e == "register" }
            #expect(registers.count == 1, "re-claim del mismo líder NO re-cuenta")
            MetricsService.cloudRegistrationCompletedIfFirst(userID: "sub-otro", detail: "migration")
            #expect(MetricsSpool.pending(defaults).filter { $0.e == "register" }.count == 2, "userID distinto sí")
        }
    }

    @Test func canaryOnce_dedupePorSesion() async throws {
        try await withStartedService(status: 500) { defaults, _ in
            MetricsService.canaryOnce(.cloudkitDuplicateDetected, key: "Tag:boot:z1", detail: "Tag")
            MetricsService.canaryOnce(.cloudkitDuplicateDetected, key: "Tag:boot:z1", detail: "Tag")
            MetricsService.canaryOnce(.cloudkitDuplicateDetected, key: "Tag:boot:z2", detail: "Tag")
            #expect(MetricsSpool.pending(defaults).count == 2)
        }
    }

    @Test func drain_entregaYVacia() async throws {
        try await withStartedService { defaults, stub in
            MetricsService.canary(.relaunchNetExhausted, detail: "signout")
            // El drain corre en un Task — cedemos vueltas del runloop hasta que vacíe.
            for _ in 0..<50 where !MetricsSpool.pending(defaults).isEmpty {
                await Task.yield()
            }
            #expect(MetricsSpool.pending(defaults).isEmpty)
            #expect(stub.callCount >= 1)
        }
    }

    @Test func resetLocalState_limpiaTodasLasKeysMetrics() {
        let defaults = makeIsolatedDefaults()
        MetricsSpool.enqueue(.ping(), defaults: defaults)
        defaults.set("2026-07-17", forKey: MetricsService.lastPingDayKey)
        defaults.set(true, forKey: MetricsService.cloudRegisteredKeyPrefix + "sub-abc")
        MetricsService.resetLocalState(defaults)
        #expect(MetricsSpool.pending(defaults).isEmpty)
        #expect(defaults.string(forKey: MetricsService.lastPingDayKey) == nil)
        #expect(!defaults.bool(forKey: MetricsService.cloudRegisteredKeyPrefix + "sub-abc"))
    }

    @Test func installHash_estable_16hex_noEsElSeed() {
        let defaults = makeIsolatedDefaults()
        MetricsService._testReset()
        MetricsService.start(client: MetricsClient(urlSession: StubHTTPSession()), defaults: defaults)
        defer { MetricsService._testReset() }
        let h1 = MetricsService.installHash
        let h2 = MetricsService.installHash
        #expect(h1 == h2, "estable por instalación")
        #expect(h1.count == 16)
        #expect(h1.allSatisfy { $0.isHexDigit })
        let seed = CloudRemoteConfigStore.bucketSeed(defaults)
        #expect(h1 != seed, "el seed crudo JAMÁS sale del device")
        #expect(!seed.lowercased().contains(h1), "el hash no es un substring del seed")
    }
}
