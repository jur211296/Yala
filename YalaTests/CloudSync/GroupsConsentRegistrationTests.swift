//
//  GroupsConsentRegistrationTests.swift
//  YalaTests / CloudSync
//
//  El registro del consent de Grupos contra la CUENTA (chip C1): el intent durable y el registrar.
//
//  ## Por qué estos tests son la ÚNICA red posible
//
//  La verificación e2e de este camino no se puede hacer desde aquí, y no por comodidad: staging corre
//  `ENFORCE = "observe"` (un request sin attest PASA) y contra producción ningún build de Xcode puede
//  atestar (el AAGUID de `verifyAttestation.ts` rechaza por diseño los builds de desarrollo). ⇒ el pin del
//  transporte es estructural (`AttestWiringTests` + `AttestHeaderTransportTests`) y el del COMPORTAMIENTO
//  es este fichero. La validación contra producción la hace el owner con un build de distribución, y quien
//  escribe el fix NO debe declararla verificada.
//
//  ## Lo que carga el peso
//
//  · **El epoch es la hora de la ACEPTACIÓN.** `registerConsent_sendsTheAcceptanceTime_notTheRetryTime` es
//    la aserción del chip: sin ella, un consent aceptado sin red quedaría fechado tres días después.
//  · **Arm-then-attempt-then-disarm.** Kill-safe: el intent sobrevive a que el proceso muera entre el tap y
//    el request, y solo un 200 lo desarma.
//  · **El `sub` que no casa ni intenta ni descarta** (R9): un relevo de humano en el mismo device no puede
//    registrar el consent de A contra la cuenta de B, y tampoco puede destruir la prueba de A.
//

import Foundation
import Testing

@testable import Yala

// MARK: - El intent durable

@MainActor
@Suite("C1 · GroupsConsentPendingIntent", .serialized)
struct GroupsConsentPendingIntentTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func withIntent(_ body: (UserDefaults) throws -> Void) rethrows {
        let d = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let previous = GroupsConsentPendingIntent.defaults
        GroupsConsentPendingIntent.defaults = d
        defer { GroupsConsentPendingIntent.defaults = previous }
        try body(d)
    }

    @Test func arm_persistsEverythingTheRetryNeeds() throws {
        try withIntent { _ in
            GroupsConsentPendingIntent.arm(
                userID: "sub-A", textVersion: 1, acceptedAt: t0, path: "invite", at: t0)

            let pending = try #require(GroupsConsentPendingIntent.pending)
            #expect(pending.userID == "sub-A")
            #expect(pending.textVersion == 1)
            #expect(pending.acceptedAt == t0)
            #expect(pending.path == "invite")
            #expect(pending.attempts == 0)
            #expect(pending.lastAttemptAt == nil)
        }
    }

    @Test func survivesAProcessDeath_becauseItLivesInUserDefaults() throws {
        // Kill-safe: el estado se relee del almacén, no de memoria. Es lo que cubre «matar la app entre el
        // tap de aceptar y el request».
        let d = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let previous = GroupsConsentPendingIntent.defaults
        GroupsConsentPendingIntent.defaults = d
        defer { GroupsConsentPendingIntent.defaults = previous }

        GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)
        // Simula el arranque siguiente: mismo almacén, ningún estado en memoria.
        GroupsConsentPendingIntent.defaults = d
        let pending = try #require(GroupsConsentPendingIntent.pending)
        #expect(pending.acceptedAt == t0, "la hora de la ACEPTACIÓN cruza el kill intacta")
    }

    @Test func rearmingSameVersion_keepsTheOriginalAcceptanceTimeAndAge() throws {
        // Re-fechar convertiría un intent viejo en uno nuevo cada vez que alguien vuelve a pasar por la
        // pantalla, y el canario dejaría de ver que se arrastra.
        try withIntent { _ in
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)
            GroupsConsentPendingIntent.noteFailedAttempt(at: t0.addingTimeInterval(10))

            let later = t0.addingTimeInterval(86_400)
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: later, path: nil, at: later)

            let pending = try #require(GroupsConsentPendingIntent.pending)
            #expect(pending.acceptedAt == t0)
            #expect(pending.armedAt == t0)
            #expect(pending.attempts == 1)
        }
    }

    @Test func rearmingHigherVersion_startsFresh() throws {
        // Es OTRA aceptación (el usuario volvió a firmar un texto sustantivamente distinto): su hora es la
        // suya, y el servidor conserva las dos filas — la PK es (user_id, text_version).
        try withIntent { _ in
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)
            GroupsConsentPendingIntent.noteFailedAttempt(at: t0)

            let later = t0.addingTimeInterval(86_400)
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 2, acceptedAt: later, path: nil, at: later)

            let pending = try #require(GroupsConsentPendingIntent.pending)
            #expect(pending.textVersion == 2)
            #expect(pending.acceptedAt == later)
            #expect(pending.attempts == 0)
        }
    }

    @Test func confirm_onlyDisarmsWhatIsActuallyArmed() {
        withIntent { _ in
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 2, acceptedAt: t0, path: nil, at: t0)

            // Otra cuenta: una respuesta que llega tarde no puede desarmar el intent de quien está ahora.
            GroupsConsentPendingIntent.confirm(userID: "sub-B", textVersion: 2)
            #expect(GroupsConsentPendingIntent.isArmed)

            // Versión anterior: el servidor confirmó la 1, pero lo armado es la 2 y sigue pendiente.
            GroupsConsentPendingIntent.confirm(userID: "sub-A", textVersion: 1)
            #expect(GroupsConsentPendingIntent.isArmed)

            GroupsConsentPendingIntent.confirm(userID: "sub-A", textVersion: 2)
            #expect(!GroupsConsentPendingIntent.isArmed)
        }
    }

    @Test func failedAttempts_climbButNEVERDiscard() throws {
        // A diferencia del intent del bridge, aquí NO hay tope: caducar sería tirar la prueba legal. Lo que
        // impide el bucle es la escalera del backoff, no un descarte.
        try withIntent { _ in
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)
            for i in 1...25 {
                GroupsConsentPendingIntent.noteFailedAttempt(at: t0.addingTimeInterval(Double(i)))
            }
            let pending = try #require(GroupsConsentPendingIntent.pending)
            #expect(pending.attempts == 25)
            #expect(GroupsConsentPendingIntent.isArmed, "un intent de consent no se descarta JAMÁS")
        }
    }

    @Test func unreadablePayload_isDiscarded_soTheResumeCanRepairItself() {
        withIntent { d in
            d.set(Data("{ no soy json".utf8), forKey: GroupsConsentPendingIntent.userDefaultsKey)
            #expect(GroupsConsentPendingIntent.pending == nil)
            #expect(d.data(forKey: GroupsConsentPendingIntent.userDefaultsKey) == nil)
        }
    }
}

// MARK: - El registrar

@MainActor
@Suite("C1 · GroupsConsentRegistrar", .serialized)
struct GroupsConsentRegistrarTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// Sesión HTTP de juguete: registra cada request y responde lo que se le diga.
    final class StubSession: SyncHTTPSession, @unchecked Sendable {
        var requests: [URLRequest] = []
        var bodies: [[String: Any]] = []
        var responseData: Data
        var statusCode: Int

        init(responseData: Data = Data("{}".utf8), statusCode: Int = 200) {
            self.responseData = responseData
            self.statusCode = statusCode
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                bodies.append(json)
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }
    }

    /// Monta el mundo: `UserDefaults` aislados para la caché y el intent, y un registrar con su doble de red.
    private func makeSUT(
        session: StubSession, userID: String?
    ) -> GroupsConsentRegistrar {
        GroupsConsentRegistrar(
            clientFactory: {
                let client = GroupsMembershipClient(
                    baseURL: URL(string: "https://gw.test")!,
                    tokenProvider: { "jwt" },
                    attestProvider: { "attest-tok" },
                    urlSession: session)
                client.sleeper = { _ in }
                return client
            },
            userIDProvider: { userID })
    }

    private func withIsolatedStores(_ body: () async -> Void) async {
        let cache = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let intent = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let prevCache = GroupsConsentState.defaults
        let prevIntent = GroupsConsentPendingIntent.defaults
        let prevProvider = GroupsConsentState.currentUserIDProvider
        GroupsConsentState.defaults = cache
        GroupsConsentPendingIntent.defaults = intent
        defer {
            GroupsConsentState.defaults = prevCache
            GroupsConsentPendingIntent.defaults = prevIntent
            GroupsConsentState.currentUserIDProvider = prevProvider
        }
        await body()
    }

    private func recordOK(version: Int = 1) -> Data {
        Data(#"{"text_version":\#(version),"accepted_at":"2026-08-11T18:04:05.123456+00:00","inserted":true}"#.utf8)
    }

    // MARK: El invariante del epoch

    @Test func registerConsent_sendsTheAcceptanceTime_notTheRetryTime() async {
        // EL test del chip. El usuario acepta a t0 sin red; tres días después el retome consigue red. Lo
        // que viaja tiene que seguir siendo t0 — un registro fechado en el reintento es una traza falsa.
        await withIsolatedStores {
            let failing = StubSession(statusCode: 500)
            let sut = makeSUT(session: failing, userID: "sub-A")
            GroupsConsentPendingIntent.arm(
                userID: "sub-A", textVersion: 1, acceptedAt: t0, path: "invite", at: t0)
            _ = await sut.resumeIfNeeded(now: t0)
            #expect(GroupsConsentPendingIntent.isArmed)

            let ok = StubSession(responseData: recordOK())
            let later = t0.addingTimeInterval(3 * 86_400)
            let sut2 = makeSUT(session: ok, userID: "sub-A")
            let outcome = await sut2.resumeIfNeeded(now: later)

            #expect(outcome == .registered)
            let sent = ok.bodies.first?["p_accepted_at"] as? String
            #expect(sent == GroupsConsentStateResult.wireTimestamp(t0),
                    "viajó la hora del REINTENTO en vez de la de la aceptación")
        }
    }

    // MARK: Arm → attempt → disarm

    @Test func success_disarmsTheIntent_andSealsTheCache() async {
        await withIsolatedStores {
            let session = StubSession(responseData: recordOK())
            let sut = makeSUT(session: session, userID: "sub-A")
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            let outcome = await sut.resumeIfNeeded(now: t0)

            #expect(outcome == .registered)
            #expect(!GroupsConsentPendingIntent.isArmed)
            #expect(GroupsConsentState.readSnapshot()?.userID == "sub-A")
        }
    }

    @Test func register_armsBeforeAttempting_andWritesTheLocalCacheEvenIfTheNetworkFails() async {
        // El usuario aceptó de verdad: la puerta no puede depender de nuestra red.
        await withIsolatedStores {
            let session = StubSession(statusCode: 503)
            let sut = makeSUT(session: session, userID: "sub-A")

            sut.register(path: "organizer", now: t0)

            #expect(GroupsConsentState.readSnapshot()?.acceptedAt == t0)
            #expect(GroupsConsentPendingIntent.isArmed)
            #expect(GroupsConsentPendingIntent.pending?.path == "organizer")
        }
    }

    @Test func killSwitch403_isTransient_theProofIsNeverThrownAway() async {
        await withIsolatedStores {
            let session = StubSession(
                responseData: Data(#"{"error":{"type":"yala_groups_disabled","message":"off"}}"#.utf8),
                statusCode: 403)
            let sut = makeSUT(session: session, userID: "sub-A")
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            let outcome = await sut.resumeIfNeeded(now: t0)

            #expect(outcome == .deferred(reason: "channel-disabled"))
            #expect(GroupsConsentPendingIntent.isArmed)
            #expect(GroupsConsentPendingIntent.pending?.attempts == 1)
        }
    }

    @Test func permanentRejection400_conservesTheIntent_becauseItIsOurBugNotTheirs() async {
        await withIsolatedStores {
            let session = StubSession(
                responseData: Data(#"{"error":{"type":"yala_rpc_error","code":"yala_bad_input"}}"#.utf8),
                statusCode: 400)
            let sut = makeSUT(session: session, userID: "sub-A")
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            let outcome = await sut.resumeIfNeeded(now: t0)

            #expect(outcome == .deferred(reason: "rejected"))
            #expect(GroupsConsentPendingIntent.isArmed,
                    "un 400 sobre un registro LEGAL no es razón para tirar la prueba")
        }
    }

    // MARK: R9 — el relevo de humano

    @Test func subMismatch_neitherAttemptsNorDiscards() async {
        await withIsolatedStores {
            let session = StubSession(responseData: recordOK())
            let sut = makeSUT(session: session, userID: "sub-B")   // entró otra persona en este device
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            let outcome = await sut.resumeIfNeeded(now: t0)

            #expect(outcome == .deferred(reason: "sub-mismatch"))
            #expect(session.requests.isEmpty, "ni un request: registrarlo sería atribuirle a B lo de A")
            #expect(GroupsConsentPendingIntent.isArmed, "ni un descarte: es la prueba de A, que sigue valiendo")
            #expect(GroupsConsentPendingIntent.pending?.attempts == 0, "tampoco gasta un peldaño del backoff")
        }
    }

    @Test func withoutSession_defersWithoutTouchingTheNetwork() async {
        await withIsolatedStores {
            let session = StubSession(responseData: recordOK())
            let sut = makeSUT(session: session, userID: nil)
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            #expect(await sut.resumeIfNeeded(now: t0) == .deferred(reason: "no-session"))
            #expect(session.requests.isEmpty)
        }
    }

    @Test func noIntent_isIdle_andSilent() async {
        await withIsolatedStores {
            let session = StubSession()
            let sut = makeSUT(session: session, userID: "sub-A")
            #expect(await sut.resumeIfNeeded(now: t0) == .idle)
            #expect(session.requests.isEmpty)
        }
    }

    @Test func backoff_holdsTheSecondAttempt_untilItsStepElapses() async {
        await withIsolatedStores {
            let session = StubSession(statusCode: 500)
            let sut = makeSUT(session: session, userID: "sub-A")
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            _ = await sut.resumeIfNeeded(now: t0)
            let requestsAfterFirst = session.requests.count

            #expect(await sut.resumeIfNeeded(now: t0.addingTimeInterval(30)) == .deferred(reason: "backoff"))
            #expect(session.requests.count == requestsAfterFirst, "el backoff no llegó a la red")

            _ = await sut.resumeIfNeeded(now: t0.addingTimeInterval(120))
            #expect(session.requests.count > requestsAfterFirst)
        }
    }

    // MARK: Idempotencia

    @Test func registeringTwice_neitherDuplicatesNorRefetches() async {
        // La idempotencia la garantiza el servidor (PK + ON CONFLICT DO NOTHING) y su respuesta trae el
        // estado VIGENTE. Lo que se comprueba aquí es la mitad del cliente: un `inserted:false` es un éxito
        // igual de bueno —la cuenta ya tiene su registro— y desarma el intent sin re-fechar nada.
        await withIsolatedStores {
            let session = StubSession(responseData: Data(
                #"{"text_version":1,"accepted_at":"2026-08-11T18:04:05.123456+00:00","inserted":false}"#.utf8))
            let sut = makeSUT(session: session, userID: "sub-A")
            GroupsConsentPendingIntent.arm(userID: "sub-A", textVersion: 1, acceptedAt: t0, path: nil, at: t0)

            #expect(await sut.resumeIfNeeded(now: t0) == .registered)
            #expect(!GroupsConsentPendingIntent.isArmed)
            #expect(await sut.resumeIfNeeded(now: t0) == .idle, "sin intent no hay segundo request")
            #expect(session.requests.count == 1)
        }
    }

    // MARK: La adopción del consent legacy — lo que CREA el registro del parque

    @Test func adoptLegacy_sealsTheOldConsentAndArmsItsRegistration() async {
        await withIsolatedStores {
            GroupsConsentState.defaults.set(
                1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
            let session = StubSession(responseData: recordOK())
            let sut = makeSUT(session: session, userID: "sub-A")

            await sut.adoptLegacyIfNeeded(now: t0)

            #expect(GroupsConsentState.readSnapshot()?.userID == "sub-A")
            let pending = GroupsConsentPendingIntent.pending
            #expect(pending?.userID == "sub-A")
            #expect(pending?.acceptedAt == Date(timeIntervalSince1970: 1_700_000_000),
                    "se adopta la hora ORIGINAL de aceptación, no la de la adopción")
        }
    }

    @Test func adoptLegacy_doesNotTouchAConsentOfAnotherAccount() async {
        await withIsolatedStores {
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: "sub-DUEÑO", textVersion: 1, acceptedAt: t0))
            let session = StubSession(responseData: recordOK())
            let sut = makeSUT(session: session, userID: "sub-VISITA")

            await sut.adoptLegacyIfNeeded(now: t0)

            #expect(GroupsConsentState.readSnapshot()?.userID == "sub-DUEÑO",
                    "el consent del dueño no se pisa: si vuelve a entrar, sigue siendo suyo")
            #expect(!GroupsConsentPendingIntent.isArmed)
        }
    }

    // MARK: La lectura desde la cuenta (el consent sigue a la persona)

    @Test func refreshFromServer_sealsTheCacheWithWhatTheAccountSays() async {
        await withIsolatedStores {
            let session = StubSession(responseData: Data(
                #"{"text_version":1,"accepted_at":"2026-08-11T18:04:05+00:00"}"#.utf8))
            let sut = makeSUT(session: session, userID: "sub-A")

            #expect(await sut.refreshFromServer())

            let snapshot = GroupsConsentState.readSnapshot()
            #expect(snapshot?.userID == "sub-A")
            #expect(snapshot?.textVersion == 1)
            // El `timestamptz` de PostgREST llega con precisión fraccionaria VARIABLE: un decoder `.iso8601`
            // a secas dejaría la fecha en nil justo cuando el servidor sí la mandó.
            #expect(snapshot?.acceptedAt != nil)
        }
    }

    @Test func refreshFromServer_neverDegradesTheLocalCacheOnFailure() async {
        await withIsolatedStores {
            GroupsConsentState.write(GroupsConsentSnapshot(userID: "sub-A", textVersion: 1, acceptedAt: t0))
            let session = StubSession(statusCode: 500)
            let sut = makeSUT(session: session, userID: "sub-A")

            #expect(await sut.refreshFromServer() == false)
            #expect(GroupsConsentState.isAcceptedForTesting(userID: "sub-A"),
                    "un fallo de red JAMÁS retira un consent que ya se dio")
        }
    }

    @Test func serverStateOlderThanLocal_doesNotOverwriteIt() async {
        // El local puede ser una aceptación de hace un segundo cuyo registro aún viaja en el intent.
        await withIsolatedStores {
            GroupsConsentState.write(GroupsConsentSnapshot(userID: "sub-A", textVersion: 3, acceptedAt: t0))
            let session = StubSession(responseData: Data(
                #"{"text_version":1,"accepted_at":"2026-08-11T18:04:05+00:00"}"#.utf8))
            let sut = makeSUT(session: session, userID: "sub-A")

            #expect(await sut.refreshFromServer() == false)
            #expect(GroupsConsentState.readSnapshot()?.textVersion == 3)
        }
    }
}

// MARK: - Ayuda de lectura sin depender del provider global

extension GroupsConsentState {
    /// Igual que `isAccepted` pero con el `sub` explícito: los tests del registrar inyectan la sesión en el
    /// SUT, no en este enum, y leer el provider global aquí mediría otra cosa.
    @MainActor
    static func isAcceptedForTesting(userID: String?) -> Bool {
        GroupsConsentDecisionLogic.isAccepted(snapshot: readSnapshot(), sessionUserID: userID)
    }
}
