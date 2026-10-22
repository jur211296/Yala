//
//  CloudIdentityDiscoveryTests.swift
//  YalaTests / CloudSync
//
//  El motor del bloque [I], SIN red (URLSession stub) y con `UserDefaults` aislados. Molde de
//  `CloudAccountClientTests`: los fixtures del wire copian los nombres reales de
//  `gateway/src/sync/account.ts` (`{"exists":true,"kind":"groups_only"}`).
//
//  Lo que estos tests cargan de verdad es el caso raro: **la sesión que cambia durante el `await`**. Sin
//  ese guard, la respuesta de una cuenta se le atribuye a la que entró después, y eso rutea a una persona
//  con el tipo de cuenta de otra.
//

import Foundation
import Testing

@testable import Yala

// MARK: - URLSession stub

private final class ExistsStubHTTP: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    let body: Data
    let error: Error?
    private(set) var calls = 0
    /// Lo que pasa MIENTRAS la petición está en vuelo (paso 6: otro dispositivo reescribe el faro). Corre en el
    /// MainActor, como el faro que toca — molde de `EditingStubSession` en `SyncApplyEngineTests`.
    var onRequest: (@MainActor @Sendable () -> Void)?

    init(status: Int = 200, body: Data = Data(), error: Error? = nil) {
        self.status = status
        self.body = body
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        calls += 1
        if let onRequest { await MainActor.run { onRequest() } }
        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (body, response)
    }
}

/// Store KV de juguete para el faro. **Todo motor de esta suite lleva uno**: desde el paso 6 el motor limpia
/// el faro huérfano, y con el `CloudBeacon()` por defecto leería —y BORRARÍA— el iCloud-KV real del simulador.
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

@Suite("Bloque [I] · el motor de descubrimiento")
@MainActor
struct CloudIdentityDiscoveryTests {

    private typealias Logic = CloudIdentityRoutingLogic

    private let base = URL(string: "https://gw.local")!

    private func makeMotor(
        body: String,
        status: Int = 200,
        error: Error? = nil,
        userID: String? = "sub-A",
        userIDAfterAwait: String? = nil,
        jwt: String? = "jwt-A",
        sessionProvider: String? = "apple",
        beaconStore: FakeBeaconStore = FakeBeaconStore(),
        duringRequest: (@MainActor @Sendable () -> Void)? = nil,
        store: AccountKindStore
    ) -> (CloudIdentityDiscovery, ExistsStubHTTP) {
        let stub = ExistsStubHTTP(status: status, body: Data(body.utf8), error: error)
        stub.onRequest = duringRequest
        // El segundo valor solo se usa si el test pide un cambio de sesión a mitad: la primera lectura
        // devuelve `userID` y las siguientes `userIDAfterAwait`.
        var lecturas = 0
        let motor = CloudIdentityDiscovery(
            client: CloudAccountClient(baseURL: base, urlSession: stub),
            store: store,
            jwtProvider: { jwt },
            userIDProvider: {
                lecturas += 1
                if lecturas > 1, let userIDAfterAwait { return userIDAfterAwait }
                return userID
            },
            beacon: CloudBeacon(store: beaconStore),
            sessionProviderName: { sessionProvider },
            now: { Date(timeIntervalSince1970: 1_000) })
        return (motor, stub)
    }

    /// Un faro puesto, como lo deja el claim: linked + método + hash del `sub` (si se da).
    private func linkedBeacon(provider: String, hashOf sub: String?) -> FakeBeaconStore {
        let beacon = FakeBeaconStore()
        beacon.setBool(true, forKey: CloudBeacon.Keys.linked)
        beacon.setString(provider, forKey: CloudBeacon.Keys.provider)
        if let sub { beacon.setString(CloudBeacon.hash(sub), forKey: CloudBeacon.Keys.accountHash) }
        return beacon
    }

    // MARK: - La ida en curso (ticket `settings-migrate-blocks-a-second-device-before-its-marker`)

    /// `migration_in_progress` llega hasta la puerta de «Migrar» sin cambiar lo que se descubre ni lo que se cachea.
    @Test("`migration_in_progress` viaja con el descubrimiento, y ausente es false")
    func idaEnCursoViaja() async {
        for (body, esperado) in [
            (#"{"exists":true,"kind":"complete","migration_in_progress":true}"#, true),
            (#"{"exists":true,"kind":"complete","migration_in_progress":false}"#, false),
            (#"{"exists":true,"kind":"complete"}"#, false),
        ] {
            let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.mip"))
            let (motor, _) = makeMotor(body: body, store: store)
            #expect(await motor.discover(gate: .settingsMigrateToCloud)
                    == .discovered(.complete, userID: "sub-A", migrationInProgress: esperado), "\(body)")
            #expect(store.read()?.kind == .complete, "el campo nuevo no cambia lo que se cachea")
        }
    }

    /// El faro «nombra esta cuenta» solo puesto y con el hash de ESTE `sub`. Sin hash —el faro fingido de los XCUITest, o uno
    /// escrito sin `sub`— no nombra ninguna.
    @Test("el faro nombra la cuenta solo con su hash")
    func faroNombraLaCuenta() {
        #expect(CloudBeacon(store: linkedBeacon(provider: "apple", hashOf: "sub-A")).namesAccount(sub: "sub-A"))
        #expect(!CloudBeacon(store: linkedBeacon(provider: "apple", hashOf: "sub-B")).namesAccount(sub: "sub-A"),
                "otra cuenta")
        #expect(!CloudBeacon(store: linkedBeacon(provider: "apple", hashOf: nil)).namesAccount(sub: "sub-A"),
                "sin hash")
        #expect(!CloudBeacon(store: linkedBeacon(provider: "apple", hashOf: "sub-A")).namesAccount(sub: nil), "sin sesión")
        #expect(!CloudBeacon(store: linkedBeacon(provider: "apple", hashOf: "sub-A")).namesAccount(sub: ""), "sub vacío")
        let apagado = linkedBeacon(provider: "apple", hashOf: "sub-A")
        apagado.setBool(false, forKey: CloudBeacon.Keys.linked)
        #expect(!CloudBeacon(store: apagado).namesAccount(sub: "sub-A"), "faro apagado con el hash viejo")
        #expect(!CloudBeacon(store: FakeBeaconStore()).namesAccount(sub: "sub-A"), "sin faro")
    }

    // MARK: - Los tres resultados

    @Test("`exists:true` con `kind: complete` → completa, y lo cachea")
    func existsCompleta() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.completa")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(body: #"{"exists":true,"kind":"complete"}"#, store: store)

        let outcome = await motor.discover(gate: .welcomeExistingAccount)

        #expect(outcome == .discovered(.complete, userID: "sub-A"))
        #expect(store.read() == AccountKindSnapshot(
            userID: "sub-A", kind: .complete, refreshedAt: Date(timeIntervalSince1970: 1_000)),
            "el tipo tiene que quedar cacheado: es el único punto donde el backend lo dice pre-sesión")
    }

    @Test("`exists:true` con `kind: groups_only` → solo grupos")
    func existsSoloGrupos() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.grupos")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(body: #"{"exists":true,"kind":"groups_only"}"#, store: store)

        #expect(await motor.discover(gate: .welcomeExistingAccount)
            == .discovered(.groupsOnly, userID: "sub-A"))
        #expect(store.read()?.kind == .groupsOnly)
    }

    @Test("`exists:false` → nueva, y no cachea nada")
    func existsNueva() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.nueva")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(body: #"{"exists":false}"#, store: store)

        #expect(await motor.discover(gate: .welcomeExistingAccount)
            == .discovered(.newAccount, userID: "sub-A"))
        #expect(store.read() == nil, "no hay cuenta: no hay tipo que guardar")
    }

    // MARK: - El caso normal de hoy: el servidor no dice el tipo

    /// Medido el 2026-09-10: ni staging ni producción sirven `kind`. El motor no decide qué asumir — se lo
    /// pregunta a la tabla, que degrada al comportamiento de HOY **de esa puerta**. Por eso el mismo
    /// cuerpo del wire da dos resultados distintos según quién pregunte.
    @Test("`kind` ausente ⇒ la tabla degrada por PUERTA, no a un valor fijo")
    func kindAusenteDegradaPorPuerta() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.sinkind")
        let store = AccountKindStore(defaults: defaults)

        let (welcome, _) = makeMotor(body: #"{"exists":true}"#, store: store)
        #expect(await welcome.discover(gate: .welcomeExistingAccount)
            == .discovered(.complete, userID: "sub-A"),
            "la re-entrada dejaría de adoptar: regresión en producción")

        let (grupos, _) = makeMotor(body: #"{"exists":true}"#, store: store)
        #expect(await grupos.discover(gate: .groups)
            == .discovered(.groupsOnly, userID: "sub-A"),
            "la puerta de Grupos hoy no toca lo personal, y sin el dato debe seguir así")
    }

    /// Un gateway viejo, o uno caído, **no es prueba de que la cuenta haya cambiado de tipo**. Borrar aquí
    /// convertiría un fail-safe transitorio en una degradación permanente y silenciosa.
    @Test("`kind` ausente NO borra lo que ya sabíamos")
    func kindAusenteNoBorraLoCacheado() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.nopisa")
        let store = AccountKindStore(defaults: defaults)
        let previo = AccountKindSnapshot(
            userID: "sub-A", kind: .complete, refreshedAt: Date(timeIntervalSince1970: 1))
        store.write(previo)

        let (motor, _) = makeMotor(body: #"{"exists":true}"#, store: store)
        _ = await motor.discover(gate: .groups)

        #expect(store.read() == previo, "el snapshot se pisó con la respuesta muda del gateway")
    }

    // MARK: - Cuando no se puede preguntar

    @Test("red caída → no disponible y reintentable, sin tocar la caché")
    func redCaida() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.red")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(
            body: "", error: URLError(.notConnectedToInternet), store: store)

        #expect(await motor.discover(gate: .groups) == .unavailable(retryable: true))
        #expect(store.read() == nil)
    }

    @Test("sin sesión no hay a quién preguntar, y no se llama a la red")
    func sinSesion() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.sinsesion")
        let store = AccountKindStore(defaults: defaults)
        let (motor, stub) = makeMotor(
            body: #"{"exists":true,"kind":"complete"}"#, userID: nil, store: store)

        #expect(await motor.discover(gate: .groups) == .unavailable(retryable: false))
        #expect(stub.calls == 0, "preguntó sin sesión: el JWT no puede identificar a nadie")
    }

    @Test("sin JWT → reintentable (la sesión puede rehacerse)")
    func sinJWT() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.sinjwt")
        let store = AccountKindStore(defaults: defaults)
        let (motor, stub) = makeMotor(
            body: #"{"exists":true}"#, jwt: nil, store: store)

        #expect(await motor.discover(gate: .groups) == .unavailable(retryable: true))
        #expect(stub.calls == 0)
    }

    // MARK: - El guard que carga el peso

    /// **La respuesta de una cuenta jamás se le atribuye a otra.** Si entre la petición y la respuesta
    /// cambió quién está firmado, este resultado ya no describe a nadie: rutear con él llevaría a una
    /// persona al Yala completo de otra, o al revés.
    @Test("la sesión cambia durante el `await` ⇒ se descarta la respuesta y NO se cachea")
    func sesionCambiaDuranteElAwait() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.carrera")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(
            body: #"{"exists":true,"kind":"complete"}"#,
            userID: "sub-A", userIDAfterAwait: "sub-B", store: store)

        #expect(await motor.discover(gate: .welcomeExistingAccount) == .unavailable(retryable: false))
        #expect(store.read() == nil, """
            Se cacheó el tipo de `sub-A` mientras la sesión viva era ya de `sub-B`. El sello por userID \
            impediría LEERLO, pero el dato de una persona no debe quedarse en el disco de un dispositivo \
            que ya no es suyo.
            """)
    }

    /// **CONTROL POSITIVO del guard anterior.** Sin esto, «la carrera se descarta» se cumpliría igual si el
    /// motor devolviera `.unavailable` SIEMPRE — que es la familia del «Executed 0 tests».
    @Test("CONTROL POSITIVO: sin carrera, el mismo montaje SÍ descubre y cachea")
    func sinCarreraElMotorFunciona() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.control")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(
            body: #"{"exists":true,"kind":"complete"}"#,
            userID: "sub-A", userIDAfterAwait: "sub-A", store: store)

        #expect(await motor.discover(gate: .welcomeExistingAccount)
            == .discovered(.complete, userID: "sub-A"))
        #expect(store.read()?.kind == .complete)
    }

    // MARK: - La sesión expirada es reintentable, el 500 también

    @Test("401 del gateway → reintentable (volver a firmar rehace la sesión)")
    func sesionExpirada() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.401")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(
            body: #"{"error":{"type":"yala_unauthorized","message":"nope"}}"#,
            status: 401, store: store)

        #expect(await motor.discover(gate: .groups) == .unavailable(retryable: true))
    }

    @Test("502 del gateway → reintentable")
    func gatewayCaido() async {
        let defaults = makeIsolatedDefaults(prefix: "idisc.502")
        let store = AccountKindStore(defaults: defaults)
        let (motor, _) = makeMotor(body: "", status: 502, store: store)

        #expect(await motor.discover(gate: .groups) == .unavailable(retryable: true))
    }

    // MARK: - Paso 6 · el faro huérfano se limpia en cuanto [I] lo PRUEBA

    /// La prueba 1: el faro nombra la identidad que acaba de firmar, y el backend dice que no tiene cuenta.
    @Test("no existe + el faro nombra ESTA identidad ⇒ el faro se limpia")
    func huerfano_mismaCuenta_seLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.huerfano1"))
        let beacon = linkedBeacon(provider: "google", hashOf: "sub-A")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, sessionProvider: "google", beaconStore: beacon, store: store)

        #expect(await motor.discover(gate: .welcomeExistingAccount)
            == .discovered(.newAccount, userID: "sub-A"), "limpiar no cambia lo que se descubre")
        #expect(!beacon.bool(forKey: CloudBeacon.Keys.linked))
        #expect(beacon.string(forKey: CloudBeacon.Keys.provider) == nil)
        #expect(beacon.string(forKey: CloudBeacon.Keys.accountHash) == nil)
    }

    /// **El caso del fresh start**, y por la puerta de GRUPOS a propósito: la limpieza vive en el motor para
    /// que la haga cualquier puerta de [I], no solo el Welcome.
    @Test("fresh start: faro de Apple de un uuid borrado + la identidad Apple sin cuenta ⇒ se limpia")
    func huerfano_freshStartApple_seLimpia_tambienDesdeGrupos() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.huerfano2"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-BORRADO")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, sessionProvider: "apple", beaconStore: beacon, store: store)

        #expect(await motor.discover(gate: .groups) == .discovered(.newAccount, userID: "sub-A"))
        #expect(!beacon.bool(forKey: CloudBeacon.Keys.linked))
    }

    /// **La otra cara, con el mismo peso**: con Google y otro hash la persona puede haber firmado con otra
    /// cuenta de Google, y la del faro seguir viva.
    @Test("Google con otro hash ⇒ el faro NO se toca")
    func google_otroHash_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.google"))
        let beacon = linkedBeacon(provider: "google", hashOf: "sub-OTRO")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, sessionProvider: "google", beaconStore: beacon, store: store)

        _ = await motor.discover(gate: .welcomeExistingAccount)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
        #expect(beacon.string(forKey: CloudBeacon.Keys.provider) == "google")
    }

    @Test("la cuenta EXISTE ⇒ el faro no se toca aunque la nombre")
    func existe_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.existe"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-A")
        let (motor, _) = makeMotor(
            body: #"{"exists":true,"kind":"complete"}"#, beaconStore: beacon, store: store)

        _ = await motor.discover(gate: .welcomeExistingAccount)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
    }

    @Test("red caída ⇒ sin respuesta no hay prueba")
    func redCaida_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.redfaro"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-A")
        let (motor, _) = makeMotor(
            body: "", error: URLError(.notConnectedToInternet), beaconStore: beacon, store: store)

        _ = await motor.discover(gate: .welcomeExistingAccount)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
    }

    /// Si la sesión cambió durante el `await`, la respuesta no describe a nadie: probar con ella limpiaría el
    /// faro por la cuenta de otra persona.
    @Test("la sesión cambia durante el `await` ⇒ no se limpia nada")
    func carrera_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.carrerafaro"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-A")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, userID: "sub-A", userIDAfterAwait: "sub-B",
            beaconStore: beacon, store: store)

        #expect(await motor.discover(gate: .welcomeExistingAccount) == .unavailable(retryable: false))
        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
    }

    // MARK: - Paso 6 · el cableado de la prueba, en la dirección peligrosa (lentes B y C de la review)

    /// **Un Google sin cuenta no puede borrar el faro de una cuenta Apple viva.** Si el motor leyera mal el
    /// método —un `.apple` fijo, o un `storedProvider() ?? "apple"` como el de otros sitios del repo—, la prueba
    /// de Apple lo borraría en todos los dispositivos del Apple ID. `BeaconOrphanLogicTests` fija la tabla; esto,
    /// el cable que la alimenta.
    @Test("faro de Apple + sesión de GOOGLE sin cuenta ⇒ el faro NO se toca")
    func faroApple_sesionGoogle_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.appleGoogle"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-OTRO")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, sessionProvider: "google", beaconStore: beacon, store: store)

        _ = await motor.discover(gate: .welcomeExistingAccount)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
        #expect(beacon.string(forKey: CloudBeacon.Keys.provider) == "apple")
    }

    @Test("faro de Apple + método de sesión DESCONOCIDO ⇒ el faro NO se toca")
    func faroApple_sesionSinMetodo_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.appleNil"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-OTRO")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, sessionProvider: nil, beaconStore: beacon, store: store)

        _ = await motor.discover(gate: .welcomeExistingAccount)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
    }

    /// **El faro cambia mientras la petición está en vuelo.** Otro dispositivo del mismo Apple ID reclama la
    /// cuenta —misma identidad de Apple, mismo uuid— y escribe su faro; esta respuesta, calculada antes del
    /// claim, dice «no existe». Limpiar ahí borraría el faro de una cuenta que YA existe. El control es
    /// `huerfano_freshStartApple_seLimpia_tambienDesdeGrupos`: el mismo montaje sin el cambio a mitad, limpia.
    @Test("el faro cambia durante la petición ⇒ no se limpia: la respuesta ya no habla de él")
    func faroCambiaDuranteLaPeticion_noSeLimpia() async {
        let store = AccountKindStore(defaults: makeIsolatedDefaults(prefix: "idisc.cambia"))
        let beacon = linkedBeacon(provider: "apple", hashOf: "sub-VIEJO")
        let (motor, _) = makeMotor(
            body: #"{"exists":false}"#, sessionProvider: "apple", beaconStore: beacon,
            duringRequest: { beacon.setString(CloudBeacon.hash("sub-A"), forKey: CloudBeacon.Keys.accountHash) },
            store: store)

        _ = await motor.discover(gate: .welcomeExistingAccount)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
        #expect(beacon.string(forKey: CloudBeacon.Keys.accountHash) == CloudBeacon.hash("sub-A"))
    }
}
