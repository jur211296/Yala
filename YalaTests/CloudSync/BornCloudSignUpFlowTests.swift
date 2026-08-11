//
//  BornCloudSignUpFlowTests.swift
//  YalaTests / CloudSync
//
//  A5 de D-A7 — el ENCADENADO del alta nube: consent → sign-in → claim → par `.cloud` →
//  relanzamiento → onboarding normal.
//
//  Tres cosas se prueban aquí y ninguna cubre a las otras:
//   1. La TABLA de `BornCloudSignUpFlow.step(for:)` — qué hace la pantalla con cada resultado del claim.
//   2. La MATRIZ DE CANCELACIÓN, que es la aserción que carga el peso del chip: qué queda escrito en el
//      device si el usuario abandona en cada uno de los tres cortes posibles. Son TRES filas y no dos
//      porque el registro de consent es APPEND-ONLY: una vez aceptado se queda, a propósito.
//   3. El source-scan del ORDEN. Lo que decide es QUIÉN llama y en qué orden, y eso ningún test de
//      comportamiento lo caza (familia `AttestWiringTests` / `GroupInviteChannelRoutingWiringTests`).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Stubs (locales: los de `BornCloudSignUpServiceTests` son file-private)

@MainActor
private final class A5Session: CloudSyncSessionProviding {
    var token: String?
    var userID: String?
    init(token: String?, userID: String?) { self.token = token; self.userID = userID }
    var currentUserID: String? { userID }
    func accessToken() async -> String? { token }
    var canRenewSession: Bool { token != nil }
    func attestToken() async throws -> String? { nil }
}

private final class A5BeaconStore: BeaconKeyValueStore, @unchecked Sendable {
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

private final class A5ClaimStub: SyncHTTPSession, @unchecked Sendable {
    var status = 200
    var body = Data(#"{"state":"created"}"#.utf8)
    private(set) var callCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

// MARK: - 1) La tabla: resultado del claim → paso del encadenado

/// `@MainActor` solo por `CloudSyncRuntime.shouldStartSync`, que está aislado; la tabla en sí es pura.
@Suite("A5 · BornCloudSignUpFlow (la tabla del encadenado)")
@MainActor
struct BornCloudSignUpFlowTableTests {

    @Test("`created` es el ÚNICO paso que toca el almacenamiento")
    func seeded_activatesStorage() {
        #expect(BornCloudSignUpFlow.step(for: .seeded) == .activateStorageAndRelaunch)
    }

    /// Variante A de §f.1, y la razón de que la pantalla esté parametrizada en vez de duplicada:
    /// sobre una cuenta ya poblada NO se siembra — se continúa por el returning-user que ya existe.
    @Test("`routeReturningUser` NO siembra: continúa por la re-entrada, con la sesión ya viva")
    func existingAccount_continuesAsReturningUser() {
        #expect(BornCloudSignUpFlow.step(for: .routeReturningUser) == .continueAsReturningUser)
        // La aserción que lo ata al invariante: el paso de siembra y este son distintos, así que un
        // mapeo que los confundiera escribiría el par `.cloud` sobre una cuenta que ya tiene datos.
        #expect(BornCloudSignUpFlow.step(for: .routeReturningUser) != .activateStorageAndRelaunch)
    }

    @Test("`waitForLeader` → pantalla de espera; el gate del runtime tampoco arranca el sync")
    func follower_waits() {
        #expect(BornCloudSignUpFlow.step(for: .waitForLeader) == .show(.waitingLeader))
        #expect(CloudSyncRuntime.shouldStartSync(after: .waitForLeader) == false)
    }

    /// Hoy INALCANZABLE desde `.bornCloud` (medido en A2: la variante B es `returningUser`-only,
    /// `AccountClaimDecision.swift:83`). Se mapea igual porque la tabla que decide vive allí.
    @Test("`providerMismatch` → el copy R9 existente, con el provider conocido intacto")
    func mismatch_showsR9() {
        #expect(BornCloudSignUpFlow.step(for: .providerMismatch(knownProvider: "google"))
                == .show(.providerMismatch(knownProvider: "google")))
        #expect(BornCloudSignUpFlow.step(for: .providerMismatch(knownProvider: nil))
                == .show(.providerMismatch(knownProvider: nil)))
    }

    /// El 401 no es un error más: si no se suelta la sesión, `runSignInFlow`/`runBornCloudFlow` la
    /// reusan (saltan el sign-in cuando `hasSession`) y el retry no puede funcionar nunca.
    @Test("`sessionExpired` SUELTA la sesión antes de mostrar el error (si no, el retry es un bucle)")
    func sessionExpired_releasesTheSession() {
        #expect(BornCloudSignUpFlow.step(for: .sessionExpired(detail: "401"))
                == .releaseSessionAndShowError)
    }

    @Test("403 no es reintentable (la cuenta está suspendida) y 5xx sí (el claim es idempotente)")
    func errorRetryability_matchesTheCause() {
        #expect(BornCloudSignUpFlow.step(for: .accountUnavailable(detail: "403"))
                == .show(.error(retryable: false)))
        #expect(BornCloudSignUpFlow.step(for: .transient(detail: "500"))
                == .show(.error(retryable: true)))
    }
}

// MARK: - 2) La matriz de cancelación (TRES filas)

/// Qué queda en el device si el usuario abandona el alta. `.serialized` porque toca `MetricsService`
/// a través del servicio.
@Suite("A5 · matriz de cancelación del alta born-cloud", .serialized)
@MainActor
struct BornCloudCancellationMatrixTests {

    private func makeSUT(
        status: Int = 200,
        body: String = #"{"state":"created"}"#,
        consentRegistered: Bool,
        beaconStore: A5BeaconStore = A5BeaconStore()
    ) -> (sut: BornCloudSignUpService, stub: A5ClaimStub, beacon: A5BeaconStore,
          claimStore: CloudClaimActionStore, consent: UserDefaults, storage: UserDefaults) {
        let consent = makeIsolatedDefaults(prefix: "a5.consent")
        if consentRegistered {
            consent.set(1_760_000_000, forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue)
            consent.set(CloudConsentText.version, forKey: PrefSyncKey.cloudConsentTextVersion.rawValue)
        }
        let storage = makeIsolatedDefaults(prefix: "a5.storage")
        let claimStore = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "a5.claim"))
        let stub = A5ClaimStub()
        stub.status = status
        stub.body = Data(body.utf8)
        let sut = BornCloudSignUpService(
            session: A5Session(token: "jwt", userID: "sub-a5"),
            accountClient: CloudAccountClient(baseURL: URL(string: "https://gw.local")!, urlSession: stub),
            provider: { "apple" },
            deviceID: "device-a5",
            beacon: CloudBeacon(store: beaconStore),
            claimStore: claimStore,
            consentDefaults: consent,
            storageDefaults: storage,
            now: { Date(timeIntervalSince1970: 1_760_000_500) })
        return (sut, stub, beaconStore, claimStore, consent, storage)
    }

    /// FILA 1 — cancelar ANTES de aceptar el consent (el botón «Cancelar» del sheet, que solo hace
    /// `dismiss()`). El device queda EXACTAMENTE como estaba: el sign-in ni se pidió, así que no hay
    /// sesión, ni claim, ni faro, ni par, ni siquiera el registro del consent.
    @Test("fila 1 · cancelar antes del consent: NADA persistido, ni el propio consent")
    func row1_cancelBeforeConsent_persistsNothing() async {
        let (_, stub, beacon, claimStore, consent, storage) = makeSUT(consentRegistered: false)
        // No se invoca `signUp()`: el flujo del alta cuelga ENTERO del `onAccept` del consent.
        #expect(stub.callCount == 0)
        #expect(consent.object(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) == nil)
        #expect(consent.object(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue) == nil)
        #expect(!beacon.bool(forKey: CloudBeacon.Keys.linked))
        #expect(claimStore.action(forUserID: "sub-a5") == nil)
        #expect(StorageModePersistence.read(storage) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storage) == false)
    }

    /// FILA 2 — cancelar TRAS aceptar el consent y ANTES de un `created`. Las dos keys del consent
    /// QUEDAN, y eso es deliberado: son el registro de un consentimiento que SÍ se dio y el
    /// precedente del repo es append-only (borrarlas sería la regresión de `bdbc46d1`, que además
    /// las propagaría a la cuenta por el canal de prefs). NADA más queda.
    @Test("fila 2 · claim fallido tras el consent: el consent SE QUEDA; ni par, ni faro, ni estampado",
          arguments: [401, 403, 500])
    func row2_consentSurvives_nothingElseDoes(status: Int) async {
        let (sut, _, beacon, claimStore, consent, storage) = makeSUT(
            status: status, body: #"{"error":{"message":"nope"}}"#, consentRegistered: true)

        _ = await sut.signUp()

        #expect(consent.object(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) as? Int == 1_760_000_000,
                "append-only: el consentimiento se dio de verdad y su registro no se retira")
        #expect(consent.object(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue) as? Int
                == CloudConsentText.version)
        #expect(!beacon.bool(forKey: CloudBeacon.Keys.linked))
        // Sin estampado, una sesión que quedara viva en el Keychain es INOFENSIVA por construcción:
        // el guard de identidad deja el runtime en `.idle` (`CloudSyncRuntime.swift:326`) y el
        // re-entry la reutiliza.
        #expect(claimStore.action(forUserID: "sub-a5") == nil)
        #expect(StorageModePersistence.read(storage) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(storage) == false)
    }

    /// FILA 3 — cancelar DESPUÉS de `created`. La cuenta ya existe server-side y el faro está
    /// escrito: el estado es RE-ENTRANTE por diseño, no un leak. El próximo paso por «Soy nuevo» ve
    /// el faro y encamina al returning-user (A26) en vez de ofrecer la elección otra vez.
    @Test("fila 3 · tras `created`: faro escrito ⇒ el siguiente «Soy nuevo» encamina al returning-user")
    func row3_afterCreated_isReentrantByDesign() async {
        let (sut, _, beacon, claimStore, _, storage) = makeSUT(consentRegistered: true)

        #expect(await sut.signUp() == .seeded)

        #expect(beacon.bool(forKey: CloudBeacon.Keys.linked))
        #expect(claimStore.action(forUserID: "sub-a5") == .seedBornCloud)
        // El par NO está: el usuario cortó antes de la terminal. Eso es correcto — el par lo escribe
        // el llamador (`activateBornCloudStorage`), no el claim.
        #expect(StorageModePersistence.read(storage) == .icloud)

        // Y ésta es la recuperación, en la misma unidad en la que ocurre: la rama «Soy nuevo» del
        // Welcome consulta el faro ANTES de ofrecer nada.
        #expect(WelcomeAccountChoiceLogic.routeNewBranch(
            beaconLinked: beacon.bool(forKey: CloudBeacon.Keys.linked),
            beaconProvider: beacon.string(forKey: CloudBeacon.Keys.provider),
            cloudEntryAvailable: true,
            options: [.privateAccount, .cloudAccount]) == .cloudSignIn(.apple))
    }
}

// MARK: - 3) El ORDEN (source-scan)

/// consent → sign-in → claim → par. Ninguna de estas cuatro cosas es observable desde un resultado:
/// lo que decide es quién llama a quién y en qué orden.
@Suite("A5 · el orden del encadenado (source-scan)")
struct BornCloudSignUpOrderWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static let viewPath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let containerPath = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fichero SIN líneas de comentario. Hace falta para toda aserción NEGATIVA sobre un símbolo:
    /// este repo documenta sus invariantes nombrándolos, así que un `!contains("X")` sobre el texto
    /// crudo se rompe al explicar por qué X ya no está. Medido aquí mismo, con dos rojos.
    private static func codeOnly(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo de una declaración, balanceando llaves y SIN líneas de comentario. Acotar al cuerpo no
    /// es cosmético: un rango ancho comprueba que el símbolo EXISTE, no que se llame aquí (lección de
    /// `TestProcessGuardTests`), y contar prosa haría que documentar el invariante lo rompiera.
    private static func body(of marker: String, in source: String) throws -> String {
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

    /// LA MUTACIÓN DEL CHIP: invertir consent y sign-in.
    ///
    /// El invariante es «nada firma ni claimea antes de que `CloudConsentView` haya registrado el
    /// consent», y desde la fase `.intro` solo hay DOS funciones alcanzables: el intro y su handler
    /// de tap. Las dos tienen que estar limpias — **y hay que decirlo por separado**: la primera
    /// versión de este test solo miraba el intro y exigía que el handler CONTUVIERA
    /// `showConsent = true`, y con eso un mutante que firmaba en el handler y abría el consent
    /// DESPUÉS pasó en VERDE (medido, no supuesto). Contener el símbolo correcto no prueba que no
    /// haya nada más.
    @Test("nada firma antes del consent: ni el intro del alta ni su handler de tap")
    func nothingSignsInBeforeTheConsent() throws {
        let src = try Self.source(Self.viewPath)
        let forbidden = ["signIn(", "runBornCloudFlow(", "runFlowAfterConsent(", "signUp(", "launchFlow"]

        let intro = try Self.body(of: "private var bornCloudIntro: some View {", in: src)
        #expect(intro.contains("beginBornCloudSignUp(with: .apple)"))
        #expect(intro.contains("beginBornCloudSignUp(with: .google)"))

        let begin = try Self.body(of: "private func beginBornCloudSignUp(with provider: CloudSignInProvider) {",
                                  in: src)
        #expect(begin.contains("showConsent = true"),
                "el handler del tap solo fija el método y abre el consent")

        for (name, body) in [("bornCloudIntro", intro), ("beginBornCloudSignUp", begin)] {
            for symbol in forbidden {
                #expect(!body.contains(symbol), """
                    El consent SIEMPRE precede al sign-in: el login envía identidad, así que pedir
                    permiso después es pedirlo para algo ya hecho (docblock de `CloudConsentView`).
                    `\(symbol)` dentro de `\(name)` —alcanzable desde la fase `.intro`— invierte ese orden.
                    """)
            }
        }
    }

    @Test("el consent del alta se registra con `path: .bornCloud`, y el sheet es quien arranca el flujo")
    func consentPath_isBornCloud_andSheetIsTheProducer() throws {
        let src = try Self.source(Self.viewPath)
        let path = try Self.body(of: "private var consentPath: CloudMigrationController.ConsentPath {", in: src)
        #expect(path.contains("case .bornCloud: return .bornCloud"))
        #expect(path.contains("case .reentry:   return .adopt"),
                "la re-entrada conserva su path: A5 no cambia la telemetría del adopt")

        let sheet = try Self.body(of: ".sheet(isPresented: $showConsent) {", in: src)
        // Sin el paréntesis de cierre: M0 le añadió `persistsOnAccept:` (quién ESCRIBE el epoch, que en
        // el alta sigue siendo la pantalla). Lo que este test pinnea es que el sheet hospeda el consent
        // con su `path` y que de él sale el flujo; el destino de la escritura lo pinnea
        // `CloudConsentRegistrationTests`.
        #expect(sheet.contains("CloudConsentView(path: consentPath"))
        #expect(sheet.contains("runFlowAfterConsent()"))
    }

    @Test("`runBornCloudFlow` va en orden: sign-in → claim → par + terminal")
    func bornCloudFlow_signsInThenClaimsThenActivates() throws {
        let body = try Self.body(of: "private func runBornCloudFlow() async {",
                                 in: try Self.source(Self.viewPath))
        let signIn = try #require(body.range(of: "ensureSignedIn()"))
        let claim = try #require(body.range(of: "service.signUp()"))
        let activate = try #require(body.range(of: "service.activateBornCloudStorage("))
        // R2: la vista le pasa el TESTIGO de mount de este proceso. Sin ese argumento la primitiva tendría
        // que leerlo por dentro y su tabla dejaría de ser testeable sin montar un container.
        #expect(body.contains("mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision"), """
            la terminal del alta la decide qué montó ESTE proceso. Pasar una constante —o leer
            `CloudSyncFlags.storageMode`, que es el modo de AHORA y cambia en caliente— devuelve el
            relanzamiento a un camino que ya no lo necesita, o peor, lo quita de uno que sí.
            """)
        #expect(signIn.lowerBound < claim.lowerBound,
                "claimear sin sesión no puede autenticarse")
        #expect(claim.lowerBound < activate.lowerBound, """
            El par `.cloud` + `mirrorOffArmed` se escribe DESPUÉS de que el claim diga `created`.
            Al revés, un claim fallido dejaría el device en modo nube sin cuenta que lo respalde.
            """)
        #expect(body.contains("BornCloudSignUpFlow.step(for:"),
                "el mapeo vive en la lógica pura: un `switch` a mano aquí no tiene tabla que lo pinnee")
    }

    /// «Si te encuentras journaleando fases, te has metido en el camino equivocado» (chip A5).
    @Test("el alta NO conduce ninguna máquina de migración ni marca los flags de onboarding")
    func bornCloudFlow_hasNoStateMachineAndNoOnboardingFlags() throws {
        let body = try Self.body(of: "private func runBornCloudFlow() async {",
                                 in: try Self.source(Self.viewPath))
        for forbidden in ["MigrationRunner", "MigrationStateMachine", "startMigration(",
                          "startAdoptWithExistingSession(", "MigrationPhaseStore", "onAdoptStarted()"] {
            #expect(!body.contains(forbidden), """
                born-cloud no tiene corpus que mover: `\(forbidden)` mete el alta en una máquina que
                nadie conduce. Y marcar los flags de onboarding aquí se comería justo el onboarding
                que tiene que correr DESPUÉS del relanzamiento.
                """)
        }
    }

    /// El servicio devuelve la fase terminal y la vista la PINTA; ninguna de las dos mata el proceso
    /// (iOS trata la auto-muerte como un crash y App Review la rechaza).
    @Test("la terminal de relanzamiento se pinta, no se ejecuta: cero auto-kill en la vista")
    func relaunchTerminal_neverKillsTheProcess() throws {
        let src = try Self.source(Self.viewPath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        for killer in ["exit(0)", "abort()", "kill(", "SIGKILL"] {
            #expect(!src.contains(killer))
        }
    }

    /// El alta cuelga del cover que YA está en la matriz de readiness (`welcomeCloudSignIn`). Si
    /// alguien le da su propio anchor, hay que meterlo en `ContentViewReadinessLogic` — y ese es
    /// justo el olvido que la regla (3) de Presentaciones existe para prevenir.
    @Test("la card «nube» reusa el cover de nube: no se añade una presentación nueva")
    func cloudCard_reusesTheExistingCover() throws {
        let src = try Self.source("Yala/App/ContentView.swift")
        let handler = try Self.body(of: "onSelectCloudAccount: {", in: src)
        #expect(handler.contains("welcomeCloudEntry = .bornCloud"))
        #expect(handler.contains("showWelcomeCloudSignIn = true"))
        #expect(handler.contains("hasShownWelcomeChooser = true"), """
            Post-relanzamiento `presentNextOnboardingScreen` decide por este flag: sin él el usuario
            volvería al Welcome en vez de entrar al onboarding con el store ya en modo nube.
            """)
        // Y el container ya no tiene el stub de A4 (borrado, no silenciado).
        #expect(!(try Self.codeOnly(Self.containerPath)).contains("showBornCloudPendingAlert"))
    }
}
