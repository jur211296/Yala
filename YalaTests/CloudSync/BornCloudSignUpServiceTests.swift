//
//  BornCloudSignUpServiceTests.swift
//  YalaTests / CloudSync
//
//  El productor del claim born-cloud (A2 de D-A7): la matriz de los 4 resultados del claim × sus acciones,
//  con stub HTTP y SIN red.
//
//  POR QUÉ LA MATRIZ SE ACOTA A LA RAMA `.bornCloud` — medido, no supuesto (2026-08-09, HEAD `9cda9424`).
//  El spec pedía la matriz ×3 ramas; la nota del punto de control autoriza acotarla SOLO tras comprobar que
//  las otras dos ya están pinneadas. Medición:
//   · La DECISIÓN pura está cubierta exhaustivamente para las 3 ramas × 3 estados × 4 combos de faro en
//     `AccountClaimDecisionTests` (12 filas de `created` + los dos productos cartesianos).
//   · La rama `.migration` a nivel de SERVICIO (`MigrationWorkExecutor.performClaim`, con stub HTTP) tenía
//     pinneado `created` (+ estampado, + `migration: true` en el body, + provider vivo) y el camino sin JWT,
//     pero NO `existing_stable`, `claiming_in_progress` ni el transient. ⇒ la tabla SE AMPLIÓ ahí, en el
//     mismo commit: ver `MigrationWorkExecutorTests` §«Claim · los otros tres estados».
//   · La acción `.routeReturningUser` (flujo de adopt) ya estaba pinneada por
//     `MigrationWorkExecutorTests.adoptFlow_happy_persistsCloudArmedAndClaimStore` y su par no-quiescente.
//
//  `.serialized` + `MetricsService._testReset()`: la métrica del paso 6 y el canario del mismatch viven en un
//  singleton estático con estado de proceso (regla del repo: nunca tocar un `.shared` sin serializar y sin
//  restaurar).
//

import Foundation
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

/// Stub del `POST /account/claim` con el body capturado (para pinnear `migration: false`).
private final class ClaimStubHTTP: SyncHTTPSession, @unchecked Sendable {
    var status = 200
    var body = Data(#"{"state":"created"}"#.utf8)
    private(set) var lastBody: [String: Any]?
    private(set) var callCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastBody = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

/// Stub HTTP del drenaje de métricas. 500 a propósito: el drain reintenta y el spool CONSERVA los eventos,
/// que es lo que permite contarlos (molde `MetricsServiceTests`).
private final class MetricsStubHTTP: SyncHTTPSession, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}

// MARK: - Suite

@Suite("A2 · BornCloudSignUpService (el productor del claim born-cloud)", .serialized)
@MainActor
struct BornCloudSignUpServiceTests {

    private let base = URL(string: "https://gw.local")!

    /// Monta el SUT con TODO inyectado (nada de `.standard`, nada de singletons vivos) y devuelve también
    /// las superficies que hay que observar: el faro, el claim-store y el stub del claim.
    private func makeSUT(
        token: String? = "jwt",
        userID: String? = "sub-born",
        provider: @escaping @MainActor () -> String = { "apple" },
        consentRegistered: Bool = true,
        beaconStore: FakeBeaconStore = FakeBeaconStore(),
        stub: ClaimStubHTTP = ClaimStubHTTP()
    ) -> (sut: BornCloudSignUpService, stub: ClaimStubHTTP, beacon: FakeBeaconStore,
          claimStore: CloudClaimActionStore, consent: UserDefaults) {
        let consent = makeIsolatedDefaults(prefix: "bornCloud.consent")
        if consentRegistered {
            consent.set(1_760_000_000, forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
            consent.set(CloudConsentText.version, forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)
        }
        let claimStore = CloudClaimActionStore(
            defaults: makeIsolatedDefaults(prefix: "bornCloud.claim"))
        let sut = BornCloudSignUpService(
            session: FakeSession(token: token, userID: userID),
            accountClient: CloudAccountClient(baseURL: base, urlSession: stub),
            provider: provider,
            deviceID: "device-born",
            beacon: CloudBeacon(store: beaconStore),
            claimStore: claimStore,
            consentDefaults: consent,
            now: { Date(timeIntervalSince1970: 1_760_000_500) })
        return (sut, stub, beaconStore, claimStore, consent)
    }

    /// Arranca `MetricsService` contra un spool aislado para poder contar lo encolado, y lo desarma después.
    private func withMetrics(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let defaults = makeIsolatedDefaults(prefix: "bornCloud.metrics")
        MetricsService._testReset()
        MetricsService.start(
            client: MetricsClient(baseURL: URL(string: "https://gw.test")!, urlSession: MetricsStubHTTP()),
            defaults: defaults)
        defer { MetricsService._testReset() }
        try await body(defaults)
    }

    private func registers(_ defaults: UserDefaults) -> [MetricsEvent] {
        MetricsSpool.pending(defaults).filter { $0.e == "register" }
    }

    private func beaconIsWritten(_ store: FakeBeaconStore) -> Bool {
        store.bool(forKey: CloudBeacon.Keys.linked)
    }

    /// Etiqueta del caso (sin payload) para comparar en la tabla de errores del claim.
    private static func label(of outcome: BornCloudSignUpOutcome) -> String {
        switch outcome {
        case .seeded:              return "seeded"
        case .routeReturningUser:  return "routeReturningUser"
        case .waitForLeader:       return "waitForLeader"
        case .providerMismatch:    return "providerMismatch"
        case .sessionExpired:      return "sessionExpired"
        case .accountUnavailable:  return "accountUnavailable"
        case .transient:           return "transient"
        }
    }

    // MARK: - La matriz: los 4 resultados del claim × sus acciones

    @Test("created → siembra: .seeded + faro escrito + claim-store seedBornCloud + registro contado")
    func created_seeds_writesBeacon_stamps_andCounts() async throws {
        try await withMetrics { metricsDefaults in
            let (sut, _, beacon, claimStore, _) = makeSUT()

            #expect(await sut.signUp() == .seeded)

            #expect(beaconIsWritten(beacon), "el faro es TEMPRANO: se escribe al reservar la cuenta")
            #expect(beacon.string(forKey: CloudBeacon.Keys.provider) == "apple")
            #expect(beacon.string(forKey: CloudBeacon.Keys.accountHash) == CloudBeacon.hash("sub-born"))
            #expect(claimStore.action(forUserID: "sub-born") == .seedBornCloud,
                    "sin estampado el runtime queda .idle post-relanzamiento (CloudSyncRuntime.swift:326)")
            let counted = registers(metricsDefaults)
            #expect(counted.count == 1)
            #expect(counted.first?.d == "bornCloud", "el detail alimenta el gatillo de PITR (P4)")
        }
    }

    @Test("existing_stable → 2º device: .routeReturningUser, NO siembra, NO reescribe el faro, NO cuenta")
    func existingStable_routesReturningUser_withoutBeaconOrRegister() async throws {
        try await withMetrics { metricsDefaults in
            let stub = ClaimStubHTTP()
            stub.body = Data(#"{"state":"existing_stable"}"#.utf8)
            let (sut, _, beacon, claimStore, _) = makeSUT(stub: stub)

            #expect(await sut.signUp() == .routeReturningUser)

            #expect(!beaconIsWritten(beacon),
                    "la cuenta ya existía: reescribir el faro pisaría la referencia de la variante B")
            #expect(claimStore.action(forUserID: "sub-born") == .routeReturningUser)
            #expect(registers(metricsDefaults).isEmpty, "un 2º device NO es un alta")
        }
    }

    @Test("claiming_in_progress → seguidor: .waitForLeader, NO faro, NO registro, y el gate NO arranca")
    func claimingInProgress_waitsForLeader() async throws {
        try await withMetrics { metricsDefaults in
            let stub = ClaimStubHTTP()
            stub.body = Data(#"{"state":"claiming_in_progress"}"#.utf8)
            let (sut, _, beacon, claimStore, _) = makeSUT(stub: stub)

            #expect(await sut.signUp() == .waitForLeader)

            #expect(!beaconIsWritten(beacon))
            #expect(claimStore.action(forUserID: "sub-born") == .waitForLeader)
            #expect(registers(metricsDefaults).isEmpty)
            // La acción estampada es la que lee el gate de arranque del runtime: un seguidor NO sincroniza.
            #expect(CloudSyncRuntime.shouldStartSync(after: .waitForLeader) == false)
        }
    }

    @Test("error del claim: 401/403/5xx y sin JWT → ni faro, ni estampado, ni registro",
          arguments: [
            (401, "sessionExpired"),
            (403, "accountUnavailable"),
            (500, "transient"),
          ])
    func claimError_touchesNothing(status: Int, expected: String) async throws {
        try await withMetrics { metricsDefaults in
            let stub = ClaimStubHTTP()
            stub.status = status
            stub.body = Data(#"{"error":{"message":"nope"}}"#.utf8)
            let (sut, _, beacon, claimStore, _) = makeSUT(stub: stub)

            let outcome = await sut.signUp()
            #expect(Self.label(of: outcome) == expected,
                    "status \(status) → \(outcome), se esperaba \(expected)")

            #expect(!beaconIsWritten(beacon))
            #expect(claimStore.action(forUserID: "sub-born") == nil)
            #expect(registers(metricsDefaults).isEmpty)
        }
    }

    @Test("sin JWT → .sessionExpired SIN tocar la red (el claim ni se emite)")
    func noJWT_shortCircuits() async throws {
        let (sut, stub, beacon, claimStore, _) = makeSUT(token: nil, userID: nil)
        #expect(await sut.signUp() == .sessionExpired(detail: "no access token"))
        #expect(stub.callCount == 0, "sin sesión no se llama al gateway")
        #expect(!beaconIsWritten(beacon))
        #expect(claimStore.action(forUserID: "sub-born") == nil)
    }

    // MARK: - El wire del claim (mutación (a) del chip)

    @Test("el BODY lleva migration=FALSE: `true` armaría migration_in_progress y clavaría una máquina que born-cloud no tiene")
    func claimBody_carriesMigrationFalse() async throws {
        let (sut, stub, _, _, _) = makeSUT()
        _ = await sut.signUp()
        #expect(stub.lastBody?["migration"] as? Bool == false,
                "born-cloud NO migra: con migration=true el cutover queda pendiente para siempre")
        #expect(stub.lastBody?["device_id"] as? String == "device-born")
        #expect(stub.lastBody?["provider"] as? String == "apple")
    }

    @Test("el provider se lee VIVO al claimear, no en el init (el servicio puede nacer antes del sign-in)")
    func provider_isReadLive_inBodyAndBeacon() async throws {
        var current = "apple"
        let (sut, stub, beacon, _, _) = makeSUT(provider: { current })
        current = "google"

        _ = await sut.signUp()

        #expect(stub.lastBody?["provider"] as? String == "google")
        #expect(beacon.string(forKey: CloudBeacon.Keys.provider) == "google",
                "un faro con el provider congelado haría que la red R9 mostrara el método equivocado")
    }

    // MARK: - El faro alimenta la decisión con datos REALES

    @Test("faro de OTRO proveedor + created: la variante B es returningUser-only ⇒ born-cloud SIGUE sembrando")
    func beaconFromAnotherProvider_stillSeeds_variantBIsReturningUserOnly() async throws {
        // Faro puesto por un alta previa con Google y un `sub` distinto: es exactamente la combinación que
        // dispararía `.showProviderMismatch` en la rama `returningUser` (`AccountClaimDecision.swift:83`).
        let store = FakeBeaconStore()
        store.setBool(true, forKey: CloudBeacon.Keys.linked)
        store.setString("google", forKey: CloudBeacon.Keys.provider)
        store.setString(CloudBeacon.hash("otro-sub"), forKey: CloudBeacon.Keys.accountHash)

        let (sut, _, _, claimStore, _) = makeSUT(provider: { "apple" }, beaconStore: store)

        #expect(await sut.signUp() == .seeded,
                "MEDIDO: desde .bornCloud el mismatch es inalcanzable — el usuario dijo explícitamente «soy nuevo»")
        #expect(claimStore.action(forUserID: "sub-born") == .seedBornCloud)
    }

    @Test("faro del MISMO sub (reintento tras un created previo): sigue siendo el camino de siembra")
    func beaconFromSameSub_reentrant_stillSeeds() async throws {
        let store = FakeBeaconStore()
        store.setBool(true, forKey: CloudBeacon.Keys.linked)
        store.setString("apple", forKey: CloudBeacon.Keys.provider)
        store.setString(CloudBeacon.hash("sub-born"), forKey: CloudBeacon.Keys.accountHash)

        let (sut, _, beacon, _, _) = makeSUT(beaconStore: store)
        #expect(await sut.signUp() == .seeded)
        #expect(beacon.double(forKey: CloudBeacon.Keys.linkedAt) == 1_760_000_500,
                "el re-claim idempotente refresca el faro con el reloj inyectado")
    }

    // MARK: - Bordes del estampado y del consent

    @Test("claim OK con userID nil: NO estampa (imposible) y NO cuenta — pero tampoco rompe el alta")
    func nilUserID_skipsStampAndRegister_butStillSeeds() async throws {
        try await withMetrics { metricsDefaults in
            let (sut, _, beacon, claimStore, _) = makeSUT(userID: nil)

            #expect(await sut.signUp() == .seeded)

            #expect(beaconIsWritten(beacon), "el faro sigue siendo útil sin hash: linked + provider")
            #expect(beacon.string(forKey: CloudBeacon.Keys.accountHash) == nil)
            #expect(claimStore.action(forUserID: "sub-born") == nil)
            #expect(registers(metricsDefaults).isEmpty)
        }
    }

    @Test("consent AUSENTE: hace ruido pero JAMÁS aborta — el alta llega igual a .seeded")
    func missingConsent_neverAborts() async throws {
        let (sut, _, beacon, claimStore, _) = makeSUT(consentRegistered: false)
        #expect(await sut.signUp() == .seeded,
                "el consent es trazabilidad GDPR, no una precondición del alta (molde runAdoptFlow 5-bis)")
        #expect(beaconIsWritten(beacon))
        #expect(claimStore.action(forUserID: "sub-born") == .seedBornCloud)
    }

    @Test("el servicio NO escribe el consent: solo lo verifica (lo escribe CloudConsentView)")
    func consentIsOnlyRead_neverWritten() async throws {
        let (sut, _, _, _, consent) = makeSUT(consentRegistered: false)
        _ = await sut.signUp()
        #expect(consent.object(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) == nil)
        #expect(consent.object(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue) == nil)
    }

    // MARK: - El resultado encaja con el gate de arranque del runtime

    @Test("la acción estampada gobierna el arranque del sync: siembra/returning arrancan, seguidor no")
    func stampedActions_matchTheRuntimeGate() {
        #expect(CloudSyncRuntime.shouldStartSync(after: .seedBornCloud))
        #expect(CloudSyncRuntime.shouldStartSync(after: .routeReturningUser))
        #expect(!CloudSyncRuntime.shouldStartSync(after: .waitForLeader))
        #expect(!CloudSyncRuntime.shouldStartSync(after: .showProviderMismatch))
    }
}

// MARK: - A3 · la primitiva del par `.cloud` + relanzamiento asistido

/// La segunda cosa que A3 entrega (la primera es el guard de mount-mismatch, en
/// `PersonalMountMismatchGuardTests`): el escritor del par en el camino born-cloud y la fase TERMINAL que
/// su llamador debe presentar.
@Suite("A3 · BornCloudSignUpService.activateBornCloudStorage (el par + la terminal)", .serialized)
@MainActor
struct BornCloudStorageActivationTests {

    /// SUT mínimo: la primitiva no toca red, sesión ni faro — solo el almacén del par.
    private func makeSUT() -> (sut: BornCloudSignUpService, storage: UserDefaults) {
        let storage = makeIsolatedDefaults(prefix: "bornCloud.storage")
        let sut = BornCloudSignUpService(
            session: FakeSession(token: "jwt", userID: "sub-born"),
            accountClient: CloudAccountClient(baseURL: URL(string: "https://gw.local")!,
                                              urlSession: ClaimStubHTTP()),
            deviceID: "device-born",
            beacon: CloudBeacon(store: FakeBeaconStore()),
            claimStore: CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "bornCloud.claim.a3")),
            consentDefaults: makeIsolatedDefaults(prefix: "bornCloud.consent.a3"),
            storageDefaults: storage)
        return (sut, storage)
    }

    @Test("escribe el par COMPLETO por el escritor único → isCloudWithMirrorOn false")
    func writesTheCompletePair() {
        let (sut, storage) = makeSUT()
        // Premisa: virgen. `.icloud` y sin armar, como todo device de 2.x.
        #expect(StorageModePersistence.read(storage) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storage) == false)

        sut.activateBornCloudStorage()

        #expect(StorageModePersistence.read(storage) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storage) == true)
        // El invariante C-1 visto desde su aserción: escribir SOLO el modo dejaría esto en `true` (= "modo
        // nube con el mirror de CloudKit VIVO"), que es el estado PROHIBIDO en una fase estable.
        #expect(StorageModePersistence.isCloudWithMirrorOn(storage) == false)
    }

    @Test("devuelve la fase TERMINAL de relanzamiento (y el proceso sigue vivo)")
    func returnsTheRelaunchTerminalPhase() {
        let (sut, _) = makeSUT()
        #expect(sut.activateBornCloudStorage() == .relaunch)
        // Si la primitiva se auto-matara, este test no llegaría a su segunda línea — pero eso no es una
        // aserción sino una casualidad, así que el pin REAL de "jamás auto-kill" es el source-scan de abajo.
    }

    @Test("idempotente: re-invocarla deja el mismo par (un reintento del alta no rompe nada)")
    func isIdempotent() {
        let (sut, storage) = makeSUT()
        sut.activateBornCloudStorage()
        sut.activateBornCloudStorage()
        #expect(StorageModePersistence.read(storage) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storage) == true)
    }

    @Test("no journalea NADA: la fase sigue en `notStarted`, que ya es estable para el runtime")
    func doesNotJournalAnything() {
        // El born-cloud no tiene máquina de migración. Post-relanzamiento el motor arranca solo por el
        // estampado del claim (A2) + la fase estable + el par completo + el mount ya en `.cloud`. Si alguien
        // journalea una fase transicional aquí, el motor se queda esperando a un runner que nadie conduce.
        let (sut, _) = makeSUT()
        let before = MigrationPhaseStore.shared.currentPhase
        sut.activateBornCloudStorage()
        #expect(MigrationPhaseStore.shared.currentPhase == before)
        #expect(MigrationRuntimeGate.isDomainStablePhase(MigrationPhaseStore.shared.currentPhase))
    }

    @Test("el par NO se escribe por el mero hecho de construir el servicio ni de resolver un claim")
    func pairIsNotWrittenAsASideEffectOfSignUp() async {
        // A2 declara que `signUp()` no toca el storage y A3 lo mantiene: el par es un cambio de estado del
        // DEVICE que solo el camino `.seeded` debe provocar, y lo provoca su llamador (A5) explícitamente.
        let (sut, storage) = makeSUT()
        _ = await sut.signUp()
        #expect(StorageModePersistence.read(storage) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storage) == false)
    }
}

// MARK: - Orden de efectos y estado DARK (source-scan)

/// Lo que estos tests pinnean NO es observable desde el resultado: los tres efectos del orden van a
/// almacenes DISTINTOS (iCloud-KV, `UserDefaults` del claim-store, spool de métricas), así que ninguna
/// aserción de comportamiento cae si alguien los reordena. Y el estado DARK —que nadie lo llame todavía—
/// es por definición la ausencia de algo, que solo un escáner puede afirmar.
@Suite("A2 · BornCloudSignUpService · orden de efectos y DARK (source-scan)")
struct BornCloudSignUpWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static let servicePath = "Yala/Services/CloudSync/BornCloudSignUpService.swift"

    private static func serviceSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(servicePath), encoding: .utf8)
    }

    /// Cuerpo de `func signUp()` (de su llave de apertura a la de cierre, balanceando). Acotar al CUERPO no
    /// es cosmético: un rango ancho comprobaría que los símbolos EXISTEN en el fichero, no que se llamen
    /// dentro de este método en este orden (lección de `TestProcessGuardTests`).
    private static func signUpBody(_ source: String) throws -> String {
        let marker = "func signUp() async -> BornCloudSignUpOutcome {"
        let start = try #require(source.range(of: marker))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    @Test("el orden es faro → estampado → consent → métrica (§k.3 paso 0: el faro TEMPRANO)")
    func effectOrder_isBeaconThenStampThenConsentThenMetric() throws {
        let body = try Self.signUpBody(try Self.serviceSource())
        let beacon = try #require(body.range(of: "beacon.writeCloudAccountLinked("))
        let stamp = try #require(body.range(of: "claimStore.record("))
        let consent = try #require(body.range(of: "verifyConsentRegistered()"))
        let metric = try #require(body.range(of: "MetricsService.cloudRegistrationCompletedIfFirst("))

        #expect(beacon.lowerBound < stamp.lowerBound,
                "el faro va ANTES del estampado: es la referencia que ve un 2º device durante la ventana del alta")
        #expect(stamp.lowerBound < consent.lowerBound)
        #expect(consent.lowerBound < metric.lowerBound)
    }

    @Test("el faro y la métrica van gateados por `created` (nunca en existing_stable / claiming_in_progress)")
    func beaconAndMetric_areGatedByCreated() throws {
        let body = try Self.signUpBody(try Self.serviceSource())
        let gate = try #require(body.range(of: "if claimState == .created {"))
        let beacon = try #require(body.range(of: "beacon.writeCloudAccountLinked("))
        #expect(gate.lowerBound < beacon.lowerBound)
        #expect(body.contains("if claimState == .created, let userID {"),
                "la métrica cuenta ALTAS: un `existing_stable` es un 2º device")
    }

    @Test("el claim pasa `migration: false` EXPLÍCITO (no heredado del default, para que la mutación se vea)")
    func claimCall_passesMigrationFalseExplicitly() throws {
        let body = try Self.signUpBody(try Self.serviceSource())
        #expect(body.contains("migration: false"))
        #expect(!body.contains("migration: true"))
    }

    /// DARK: A2 entrega el productor sin cablearlo. Si esto se pone rojo porque apareció una construcción de
    /// producción, es A5 y hay que borrar este test (y el aviso del docblock) en ese commit — no silenciarlo.
    @Test("sigue SIN call-site de producción: A2 es DARK y A5 es quien lo cablea")
    func service_hasNoProductionCallSite_yet() throws {
        var constructions: [String] = []
        for root in ["Yala", "YalaWidgets", "YalaShare"] {
            let base = Self.repoRoot.appendingPathComponent(root)
            guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
            else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                guard url.lastPathComponent != "BornCloudSignUpService.swift",
                      let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                // Ignora las líneas que son comentario entero: los docblocks de este repo nombran clases
                // constantemente y sin esto documentar el invariante lo rompería.
                let code = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                    .joined(separator: "\n")
                if code.contains("BornCloudSignUpService(") {
                    constructions.append(root + "/" + url.lastPathComponent)
                }
            }
        }
        #expect(constructions.isEmpty, """
            `BornCloudSignUpService` ya se construye en producción (\(constructions.joined(separator: ", "))).
            Si es A5, borra este test en ESE commit junto con el aviso DARK del docblock del servicio.
            """)
    }

    @Test("el docblock declara el estado DARK nombrando A5 (la coartada convertida en contrato)")
    func docblock_namesTheIncrementThatWiresIt() throws {
        let source = try Self.serviceSource()
        #expect(source.contains("A5"))
        #expect(source.contains("SIN CALL-SITE DE PRODUCCIÓN"))
        #expect(source.contains("bórralo o cabléalo"))
    }

    // MARK: - A3

    /// Cuerpo de `activateBornCloudStorage()`, sin comentarios. Mismo acotado y mismo porqué que
    /// `signUpBody` (un rango ancho comprobaría que el símbolo EXISTE, no que se use aquí).
    private static func activateBody(_ source: String) throws -> String {
        let marker = "func activateBornCloudStorage() -> CloudWelcomeSignInPhase {"
        let start = try #require(source.range(of: marker))
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("A3: el par lo escribe el ESCRITOR ÚNICO, jamás dos `set` sueltos")
    func activate_usesTheSinglePairWriter() throws {
        let body = try Self.activateBody(try Self.serviceSource())
        #expect(body.contains("StorageModePersistence.writeCloudArmed("), """
            C-1 colapsó las dos escrituras en un solo escritor para que no puedan divergir. Escribir el modo
            y el flag por separado aquí reabre la mitad `armado + .icloud`, que `CloudMigrationUIStateDeriver`
            lee como `needsRelaunch(.toCloud)` ⇒ tarjeta de relanzamiento en bucle sin salida.
            """)
        #expect(!body.contains("StorageModePersistence.write("),
                "el modo suelto no: el par entero o nada")
    }

    @Test("A3: la terminal NUNCA auto-mata el proceso (contrato de la fase `.relaunch`)")
    func activate_neverKillsTheProcess() throws {
        // iOS trata la auto-muerte como un crash y App Review la rechaza; además dejaría al usuario sin
        // saber qué pasó. El contrato es que el usuario cierra la app a mano, igual que en el adopt.
        // Se escanea el fichero ENTERO, no solo el cuerpo: un `exit` escondido en un helper privado de al
        // lado tendría exactamente el mismo efecto.
        let source = try Self.serviceSource()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        for killer in ["exit(0)", "exit(", "abort()", "fatalError(", "kill(", "SIGKILL"] {
            #expect(!source.contains(killer), "el alta born-cloud no puede matar el proceso: \(killer)")
        }
    }
}
