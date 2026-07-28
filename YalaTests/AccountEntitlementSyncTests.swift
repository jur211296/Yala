//
//  AccountEntitlementSyncTests.swift
//  YalaTests
//
//  Las TRES rutas de red de `AccountEntitlementService.sync()` contra un `SyncHTTPSession` stub
//  (C-8, 2026-07-27). Sin esto, el invariante que el propio servicio declara en su header —«un fallo
//  de red NUNCA borra el snapshot ni degrada a Free»— no lo comprobaba nadie: cambiar el
//  `return false` de la rama de error por un `store.clear()` dejaba la suite entera en verde y le
//  quitaba Pro a un pagador offline, que es EXACTAMENTE el bug que C-8 arregla.
//
//  También pinnea el contrato del wire (`pro`/`product`/`expires_at_ms`): un rename en el gateway
//  hoy se traduce en `.transient` silencioso, snapshot que nunca se escribe y usuario sin Pro sin un
//  solo error visible.
//

import Foundation
import Testing

@testable import Yala

/// Devuelve una respuesta distinta por llamada (el `sync` puede hacer bind y luego GET).
private final class ScriptedSession: SyncHTTPSession, @unchecked Sendable {
    private let responses: [(status: Int, body: String)]
    private let error: Error?
    private(set) var requests: [URLRequest] = []

    init(responses: [(status: Int, body: String)], error: Error? = nil) {
        self.responses = responses
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let error { throw error }
        let idx = min(requests.count - 1, responses.count - 1)
        let r = responses[idx]
        let response = HTTPURLResponse(
            url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: nil)!
        return (Data(r.body.utf8), response)
    }
}

@MainActor
@Suite("AccountEntitlementService · rutas de red (C-8)", .serialized)
struct AccountEntitlementSyncTests {

    static let userA = "11111111-2222-3333-4444-555555555555"
    static let userB = "99999999-8888-7777-6666-555555555555"
    static let futureMs = (Date.now.timeIntervalSince1970 + 30 * 24 * 3600) * 1000

    private func makeStore(_ name: String) -> (AccountEntitlementStore, UserDefaults) {
        let suite = "test.entitlement.net.\(name).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("suite de test") }
        return (AccountEntitlementStore(defaults: defaults), defaults)
    }

    private func makeService(
        session: ScriptedSession,
        store: AccountEntitlementStore,
        userID: String? = userA,
        jws: String? = nil
    ) -> AccountEntitlementService {
        AccountEntitlementService(
            store: store,
            client: CloudAccountClient(baseURL: URL(string: "https://gw.test")!, urlSession: session),
            jwtProvider: { "jwt" },
            userIDProvider: { userID },
            storeKitJWSProvider: { jws })
    }

    private func snapshot(
        userID: String = userA,
        expiresAt: Date? = .now.addingTimeInterval(30 * 24 * 3600),
        refreshedAt: Date = .now.addingTimeInterval(-7 * 3600)   // vieja: pasa el throttle
    ) -> AccountEntitlementSnapshot {
        AccountEntitlementSnapshot(
            userID: userID, product: "com.yala.pro.yearly", expiresAt: expiresAt, refreshedAt: refreshedAt)
    }

    // MARK: - Camino feliz

    @Test func get200_persisteElSnapshotConElDuenoDeLaSesion() async {
        let (store, defaults) = makeStore("get200")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let body = #"{"pro":true,"product":"com.yala.pro.yearly","expires_at_ms":\#(Self.futureMs)}"#
        let session = ScriptedSession(responses: [(200, body)])
        let changed = await makeService(session: session, store: store).sync(force: true)

        #expect(changed)
        #expect(store.read()?.userID == Self.userA)
        #expect(store.read()?.product == "com.yala.pro.yearly")
        #expect(session.requests.count == 1)
        #expect(session.requests.first?.httpMethod == "GET")
    }

    /// Con suscripción local, el sync BINDEA (POST) y la propia respuesta del bind hace de refresco:
    /// una sola llamada, no dos.
    @Test func conJWSLocal_bindeaYNoNecesitaSegundaLlamada() async {
        let (store, defaults) = makeStore("bind")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let body = #"{"pro":true,"product":"com.yala.pro.monthly","expires_at_ms":\#(Self.futureMs)}"#
        let session = ScriptedSession(responses: [(200, body)])
        let changed = await makeService(session: session, store: store, jws: "signed-jws").sync(force: true)

        #expect(changed)
        #expect(session.requests.count == 1)
        #expect(session.requests.first?.httpMethod == "POST")
        #expect(store.read()?.product == "com.yala.pro.monthly")
    }

    // MARK: - El invariante: la red NUNCA degrada a Free

    @Test func redCaida_conservaElSnapshotVigente() async {
        let (store, defaults) = makeStore("offline")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let previo = snapshot()
        store.write(previo)
        let session = ScriptedSession(responses: [], error: URLError(.notConnectedToInternet))
        let changed = await makeService(session: session, store: store).sync(force: true)

        #expect(changed == false)
        #expect(store.read() == previo, "un fallo de red jamás puede tocar la caché")
        #expect(ProEntitlementLogic.isPro(localActive: false, snapshot: store.read(),
                                          sessionUserID: Self.userA, resolutionEnabled: true))
    }

    @Test func http500_conservaElSnapshotVigente() async {
        let (store, defaults) = makeStore("500")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let previo = snapshot()
        store.write(previo)
        let session = ScriptedSession(responses: [(500, "boom")])
        _ = await makeService(session: session, store: store).sync(force: true)

        #expect(store.read() == previo)
    }

    /// Sesión expirada: tampoco se borra. El derecho no se pierde por no poder preguntar; si la
    /// sesión muere de verdad, `ProEntitlementLogic` ya deja de aplicar el snapshot (sin `userID`).
    @Test func http401_conservaElSnapshotVigente() async {
        let (store, defaults) = makeStore("401")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let previo = snapshot()
        store.write(previo)
        let session = ScriptedSession(responses: [(401, #"{"error":{"type":"yala_attest_invalid"}}"#)])
        _ = await makeService(session: session, store: store).sync(force: true)

        #expect(store.read() == previo)
    }

    /// 409: esta suscripción es de otra cuenta de Yala. No es motivo para tocar el derecho propio.
    @Test func http409_ownerMismatch_conservaElSnapshotYSigueConsultando() async {
        let (store, defaults) = makeStore("409")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let previo = snapshot()
        store.write(previo)
        // 1ª (POST bind) → 409; 2ª (GET) → estado real de la cuenta.
        let body = #"{"pro":true,"product":"com.yala.pro.yearly","expires_at_ms":\#(Self.futureMs)}"#
        let session = ScriptedSession(responses: [(409, #"{"error":{"type":"yala_entitlement_owner_mismatch"}}"#),
                                                  (200, body)])
        _ = await makeService(session: session, store: store, jws: "signed-jws").sync(force: true)

        #expect(session.requests.count == 2, "tras el 409 se consulta igual el estado de la cuenta")
        #expect(store.read()?.userID == Self.userA)
    }

    // MARK: - Contrato del wire

    /// Un rename de campo en el gateway no puede pasar desapercibido: hoy degrada a `.transient`.
    @Test func respuesta200ConShapeDesconocido_noEscribeNada() async {
        let (store, defaults) = makeStore("shape")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let session = ScriptedSession(responses: [(200, #"{"isPro":true,"expiresAtMs":123}"#)])
        let changed = await makeService(session: session, store: store).sync(force: true)

        #expect(changed == false)
        #expect(store.read() == nil)
    }

    /// Cuenta sin suscripción: 200 con `expires_at_ms: null` ⇒ snapshot SIN derecho (no ausencia).
    @Test func cuentaSinDerecho_persisteSnapshotVacio() async {
        let (store, defaults) = makeStore("free")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        let session = ScriptedSession(responses: [(200, #"{"pro":false,"product":null,"expires_at_ms":null}"#)])
        _ = await makeService(session: session, store: store).sync(force: true)

        #expect(store.read()?.expiresAt == nil)
        #expect(ProEntitlementLogic.isPro(localActive: false, snapshot: store.read(),
                                          sessionUserID: Self.userA, resolutionEnabled: true) == false)
    }

    // MARK: - Fronteras de cuenta

    /// La sesión cambió durante el await de red: la respuesta pertenece a una cuenta que ya no está
    /// dentro. Escribirla resucitaría el snapshot que la frontera acaba de purgar.
    @Test func sesionCambiadaDuranteLaRed_descartaLaRespuesta() async {
        let (store, defaults) = makeStore("boundary")
        defer { defaults.removePersistentDomain(forName: defaults.description) }

        var current: String? = Self.userA
        let body = #"{"pro":true,"product":"com.yala.pro.yearly","expires_at_ms":\#(Self.futureMs)}"#
        let session = ScriptedSession(responses: [(200, body)])
        let service = AccountEntitlementService(
            store: store,
            client: CloudAccountClient(baseURL: URL(string: "https://gw.test")!, urlSession: session),
            jwtProvider: {
                current = Self.userB      // el usuario cerró sesión / entró otro mientras iba la red
                return "jwt"
            },
            userIDProvider: { current },
            storeKitJWSProvider: { nil })

        let changed = await service.sync(force: true)
        #expect(changed == false)
        #expect(store.read() == nil, "jamás escribir el derecho de una sesión que ya no está")
    }
}
