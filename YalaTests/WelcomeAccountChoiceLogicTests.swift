//
//  WelcomeAccountChoiceLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Welcome chooser 2 niveles — opciones visibles y bypass")
struct WelcomeAccountChoiceLogicTests {

    // MARK: - "Soy nuevo"

    @Test
    func newOptions_bornCloudDisabled_onlyPrivate() {
        // Born-cloud DIFERIDO: aun con backend configurado + remotos ON, sin el enable no aparece.
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: true, bornCloudEnabled: false,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    @Test
    func newOptions_bornCloudEnabled_requiresConfiguredAndNotUITest() {
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount, .cloudAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: false, isUITest: false, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: true, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    @Test
    func newOptions_remoteFlags_bothRequired() {
        // DIFERIDOS #34: la card born-cloud exige el flag padre Y el sub-flag §j.1 —
        // el escalón born-cloud es POSTERIOR al del flag padre en el rollout.
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: false, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: false
        ) == [.privateAccount])
    }

    /// **Sin App Attest no se ofrece la nube** (ticket `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`):
    /// con todo lo demás encendido, un teléfono que no puede conseguir token no ve la card. El control es la MISMA fila con
    /// App Attest: sin él, la aserción se cumpliría también si otro término se hubiera apagado por error.
    @Test("sin App Attest la card de la nube no sale, aunque todo lo demás esté encendido")
    func newOptions_withoutAttest_onlyPrivate() {
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount, .cloudAccount], "control: con App Attest y todo encendido salen las dos")
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    // MARK: - "Ya tengo cuenta"

    @Test
    func existingOptions_configured_showsAllThree() {
        // Sesión 2 Google: Apple y Google comparten el MISMO gate (configured && !uitest && remoto).
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: false, remoteCloudEnabled: true
        ) == [.restoreICloud, .cloudSignIn, .googleSignIn])
    }

    @Test
    func existingOptions_notConfigured_onlyRestore() {
        // Prod DARK hoy: el botón SIWA jamás aparece sin backend configurado.
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: false, isUITest: false, remoteCloudEnabled: true
        ) == [.restoreICloud])
    }

    @Test
    func existingOptions_uitest_onlyRestore() {
        // Bypass uitest intacto (el opt-in `-uitest-cloud-chooser` pasa isUITest=false en
        // el callsite — la lógica pura no cambia).
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: true, remoteCloudEnabled: true
        ) == [.restoreICloud])
    }

    @Test
    func existingOptions_remoteKillSwitch_onlyRestore() {
        // DIFERIDOS #34: kill-switch OFF oculta las cards nube → bypass a restore (= prod DARK).
        // Residual ratificado: un usuario nube que reinstala bajo el kill no re-entra hasta
        // re-encendido.
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: false, remoteCloudEnabled: false
        ) == [.restoreICloud])
    }

    // MARK: - Bypass

    @Test
    func bypass_singleOption_returnsIt() {
        #expect(WelcomeAccountChoiceLogic.bypass(
            [WelcomeAccountChoiceLogic.ExistingOption.restoreICloud]
        ) == .restoreICloud)
    }

    @Test
    func bypass_multipleOptions_returnsNil() {
        #expect(WelcomeAccountChoiceLogic.bypass(
            [WelcomeAccountChoiceLogic.ExistingOption.restoreICloud, .cloudSignIn]
        ) == nil)
    }
}

// MARK: - A4 · el faro va ANTES de la elección (A26, §k.2)

/// Store KV de juguete para el faro (molde `BornCloudSignUpServiceTests`). Sin él estos tests
/// leerían el `NSUbiquitousKeyValueStore` REAL del simulador, que es estado compartido.
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

/// La rama «Soy nuevo» consulta el faro ANTES de ofrecer nada, y con él puesto ENCAMINA a entrar con esa
/// cuenta. **Desde el paso 6 encaminar ya no es decidir** (ADR 2026-09-09 §10): la pantalla de destino ofrece
/// «Crear otra cuenta» (lo fija el XCUITest de `WelcomeChooserUITests`), y la ruta transporta el método del
/// faro TAL CUAL, sin fallback, para que el destino no afirme un método que el faro no dice.
@Suite("rama «Soy nuevo»: el faro se consulta ANTES y ENCAMINA (ADR 2026-09-09 §10)")
@MainActor
struct WelcomeNewBranchRouteTests {

    private let bothOptions: [WelcomeAccountChoiceLogic.NewOption] = [.privateAccount, .cloudAccount]

    private func makeBeacon(linked: Bool, provider: String?) -> CloudBeacon {
        let store = FakeBeaconStore()
        if linked {
            store.setBool(true, forKey: CloudBeacon.Keys.linked)
            if let provider { store.setString(provider, forKey: CloudBeacon.Keys.provider) }
        }
        return CloudBeacon(store: store)
    }

    @Test("faro presente ⇒ ENCAMINA a entrar, aunque las dos cards estén visibles")
    func beaconLinked_routesToCloudSignIn_evenWithBothCardsVisible() {
        let route = WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "apple"),
            cloudEntryAvailable: true,
            options: bothOptions)
        #expect(route == .cloudSignIn(accountProvider: .apple))
    }

    @Test("el método sale del FARO, no de un default: Google encamina a Google")
    func beaconLinked_google_routesWithGoogleProvider() {
        let route = WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "google"),
            cloudEntryAvailable: true,
            options: bothOptions)
        #expect(route == .cloudSignIn(accountProvider: .google))
        #expect(WelcomeAccountChoiceLogic.signInProvider(forBeaconAccount: .google) == .google)
    }

    /// **La ruta transporta el «no lo sé»; el botón no.** Hasta el paso 6 el fallback a Apple vivía en la
    /// ruta y el destino no podía distinguir un faro de Apple de uno sin método: ahora el intro dice «creada
    /// con Apple» solo cuando el faro lo dice, y firma con Apple igual que antes.
    @Test("método ausente o desconocido ⇒ la ruta dice `nil` y el botón cae a Apple, como siempre")
    func beaconLinked_unknownProvider_carriesNil_andSignsInWithApple() {
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: nil),
            cloudEntryAvailable: true,
            options: bothOptions) == .cloudSignIn(accountProvider: nil))
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "microsoft"),
            cloudEntryAvailable: true,
            options: bothOptions) == .cloudSignIn(accountProvider: nil))
        #expect(WelcomeAccountChoiceLogic.signInProvider(forBeaconAccount: nil) == .apple)
    }

    @Test("faro presente con la entrada nube NO disponible (kill remoto / sin backend / uitest) ⇒ no encamina")
    func beaconLinked_withoutCloudEntry_doesNotRoute() {
        // Residual DECLARADO: bajo el kill-switch la re-entrada nube no se ofrece por política ya
        // ratificada, así que este device puede volver a divergir. Es el mismo residual de la card
        // de "Ya tengo cuenta", ampliado a este camino — no un descuido.
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "apple"),
            cloudEntryAvailable: false,
            options: [.privateAccount]) == .single(.privateAccount))
    }

    @Test("sin faro y con las dos cards ⇒ sub-chooser")
    func beaconAbsent_bothOptions_showsChooser() {
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: false, provider: nil),
            cloudEntryAvailable: true,
            options: bothOptions) == .chooser)
    }

    /// LA NO-REGRESIÓN que importa: con la card apagada el recorrido "Soy nuevo" no cambia — ni
    /// pantalla intermedia ni encaminamiento. **Ya no es «el recorrido de producción»**: prod sirve el
    /// percent en 100 (medido el 2026-09-09; se desplegó antes, sin fecha conocida). Sigue siendo el
    /// camino del kill-switch (devolver el percent
    /// a 0) y el de todo device que aún no tenga snapshot de `/config`, así que el caso no caduca.
    @Test("card apagada ⇒ bypass a `.privateAccount` (kill-switch y device sin snapshot)")
    func cardOff_bypassesToPrivate_endToEnd() {
        let options = WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: false)
        #expect(options == [.privateAccount])
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: false, provider: nil),
            cloudEntryAvailable: true,
            options: options) == .single(.privateAccount))
    }

    /// **Sin App Attest, «Es mi primera vez» va directo a la rama privada; y el faro sigue encaminando.** La primera mitad
    /// es el recorrido que ve ese teléfono. La segunda fija el alcance: la puerta del attest es del ALTA, y quien ya tiene
    /// una cuenta sigue llegando a ella (`cloudEntryAvailable` sale de «Ya tengo una cuenta», que no lleva el término).
    @Test("sin App Attest: sin faro ⇒ bypass a privado; con faro ⇒ sigue encaminando a entrar")
    func withoutAttest_bypassesToPrivate_butTheBeaconStillRoutes() {
        let options = WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, isAttestSupported: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true)
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: false, provider: nil),
            cloudEntryAvailable: true,
            options: options) == .single(.privateAccount))
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "google"),
            cloudEntryAvailable: true,
            options: options) == .cloudSignIn(accountProvider: .google))
    }
}

// MARK: - A4 · cableado (source-scan)

/// Lo que decide aquí es QUIÉN llama y en qué ORDEN, y eso ningún test de comportamiento lo caza:
/// la ruta puede ser perfecta y sus tests verdes mientras el container llama al bypass directamente
/// y nunca le pregunta al faro (familia `AttestWiringTests`).
@Suite("A4 · sub-chooser «Soy nuevo» · cableado (source-scan)")
struct WelcomeNewChooserWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static let containerPath = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"

    /// Cuerpo de una función, balanceando llaves y sin líneas de comentario. Acotar al CUERPO no es
    /// cosmético: un rango ancho comprueba que el símbolo EXISTE, no que se llame aquí (lección de
    /// `TestProcessGuardTests`); y contar prosa haría que documentar el invariante lo rompiera.
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

    @Test("la rama `.new` del chooser pasa por `handleNewBranch`, no por `onSelectBranch`")
    func newBranch_isRoutedToItsSecondLevel() throws {
        let src = try Self.source(Self.containerPath)
        #expect(src.contains("case .new: handleNewBranch()"),
                "si `.new` vuelve a salir por `onSelectBranch`, la consulta del faro deja de correr")
    }

    @Test("`handleNewBranch` PREGUNTA AL FARO antes de decidir (mutación: quitarlo tiene que caer aquí)")
    func handleNewBranch_asksTheBeacon() throws {
        let body = try Self.body(of: "private func handleNewBranch() {", in: try Self.source(Self.containerPath))
        #expect(body.contains("WelcomeNewBranchRouter.route("))
        #expect(body.contains("beacon: CloudBeacon()"),
                "el faro REAL: leerlo de otro sitio (o no leerlo) reabre A26")
        #expect(body.contains("cloudEntryAvailable: cloudEntryAvailable"))
    }

    @Test("`visibleNewOptions` cablea la constante COMPILADA y el sub-flag remoto de la elección")
    func visibleNewOptions_wiresBothGates() throws {
        // Paso 8 · el gate se lee en UN sitio, `WelcomeNewOptionsGate.live`, que comparten el Welcome y la
        // activación de Yala completo (mismo chooser, mismo gate). El container tiene que DELEGAR en él —si
        // volviera a escribir los términos, las dos pantallas podrían divergir— y los términos se miden allí.
        let container = try Self.body(
            of: "private var visibleNewOptions: [WelcomeAccountChoiceLogic.NewOption] {",
            in: try Self.source(Self.containerPath))
        #expect(container.contains("WelcomeNewOptionsGate.live"))
        let body = try Self.body(
            of: "static var live: [WelcomeAccountChoiceLogic.NewOption] {",
            in: try Self.source("Yala/App/Logic/WelcomeAccountChoiceLogic.swift"))
        #expect(body.contains("isUITest: SwiftDataConfiguration.isUITesting && !UITestHooks.forceCloudChooser"))
        #expect(body.contains("bornCloudEnabled: CloudSyncFlags.bornCloudChoiceEnabled"))
        #expect(body.contains("remoteOnboardingChoiceEnabled: CloudRemoteFlags.cloudOnboardingChoiceEnabled"),
                "sin el sub-flag, la card dejaría de ser DARK en producción")
        #expect(body.contains("remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled"))
        // **El cuerpo ENTERO, y no un `contains` del término del attest** (review adversarial, 2026-09-16). En el host de
        // test la capacidad vale `false`, así que un término añadido detrás —`… canObtainSessionToken && algo`— dejaba a
        // TODO iPhone sin la nube con la suite entera en verde: el `contains` de un prefijo lo daba por bueno.
        #expect(Self.normalized(body) == """
            WelcomeAccountChoiceLogic.visibleNewOptions( \
            isConfigured: CloudBackendConfig.isConfigured, \
            isUITest: SwiftDataConfiguration.isUITesting && !UITestHooks.forceCloudChooser, \
            isAttestSupported: UITestHooks.fakeAttestSupport || AppAttestClient.canObtainSessionToken, \
            bornCloudEnabled: CloudSyncFlags.bornCloudChoiceEnabled, \
            remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled, \
            remoteOnboardingChoiceEnabled: CloudRemoteFlags.cloudOnboardingChoiceEnabled)
            """, "sin la capacidad REAL, un iPhone sin App Attest vuelve a ver la nube; sin el seam, los XCUI del chooser no")
    }

    /// Líneas recortadas, sin vacías, unidas por un espacio: la forma de comparar un cuerpo entero sin depender de la
    /// indentación (`.claude/rules/testing.md`, «fija el cuerpo ENTERO normalizado»).
    private static func normalized(_ body: String) -> String {
        body.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// **La puerta del attest tiene llamador, y es éste.** El ticket nació de una función con la decisión del owner dentro
    /// y ningún call-site: la tabla de arriba seguiría en verde si el término se escribiera a mano y la función volviera a
    /// quedarse sola, y el día que la función cambie, esta lógica no se enteraría.
    @Test("`visibleNewOptions` decide la nube con `AttestSyncGate.shouldOfferCloudOnly`")
    func visibleNewOptions_callsTheAttestGate() throws {
        let body = try Self.body(
            of: ") -> [NewOption] {",
            in: try Self.source("Yala/App/Logic/WelcomeAccountChoiceLogic.swift"))
        #expect(body.contains("AttestSyncGate.shouldOfferCloudOnly(isAttestSupported: isAttestSupported)"))
    }

    /// **Qué es «tener App Attest», fijado entero.** En el host de test `canObtainSessionToken` vale `false` siempre —el
    /// simulador no tiene App Attest y ningún scheme pone el secreto—, así que un `{ false }` dejaría a TODO iPhone sin la
    /// nube y ningún test de comportamiento lo vería. Y tiene que ser la primera decisión de `performRefresh`, entera: sin
    /// la mitad del secreto, el simulador que sí sincroniza perdería la nube.
    @Test("`AppAttestClient.canObtainSessionToken` es exactamente la primera decisión de `performRefresh`")
    func canObtainSessionToken_mirrorsTheClient() throws {
        let client = try Self.source("Yala/App/Services/AppAttestClient.swift")
        let body = try Self.body(of: "static var canObtainSessionToken: Bool {", in: client)
        #expect(Self.normalized(body) == "DCAppAttestService.shared.isSupported || !ProxyConfig.devSharedSecret.isEmpty")
        // La otra orilla del espejo, y en ORDEN: que `performRefresh` EMPIECE decidiendo así. Un `contains` suelto daba por
        // buena una comprobación nueva antes del `guard`, o el bypass sacado del `else` (review adversarial, 2026-09-16).
        let refresh = try Self.body(of: "private func performRefresh() async throws -> String {", in: client)
        #expect(Self.normalized(refresh).hasPrefix(
            "let service = DCAppAttestService.shared guard service.isSupported else { return try await devTokenOrThrow() }"))
        // Y el bypass: solo en DEBUG, con el secreto de `ProxyConfig` y `.unavailable` sin él; en release, `.unavailable`.
        let devToken = Self.normalized(
            try Self.body(of: "private func devTokenOrThrow() async throws -> String {", in: client))
        #expect(devToken.hasPrefix(
            "#if DEBUG let secret = ProxyConfig.devSharedSecret guard !secret.isEmpty else { throw AppAttestError.unavailable }"))
        #expect(devToken.hasSuffix("#else throw AppAttestError.unavailable #endif"))
    }

    /// **La paridad del nombre del seam.** Con un typo a un lado el seam vale `false`, y los XCUITest que necesitan la card
    /// de la nube caerían culpando a la pantalla; al revés, el negativo seguiría verde sin haber discriminado nada.
    @Test("`-uitest-fake-attest-support` se escribe igual en el lanzador y en `UITestHooks`")
    func fakeAttestSupport_argNameParity() throws {
        let launcher = try Self.source("YalaUITests/Support/XCUIApplication+Yala.swift")
        let hooks = try Self.source("Yala/App/UITestHooks.swift")
        let arg = "-uitest-fake-attest-support"
        #expect(launcher.contains("args.append(\"\(arg)\")"), "el lanzador del XCUITest no pasa `\(arg)`")
        #expect(hooks.contains("hasArg(\"\(arg)\")"), "`UITestHooks` no lee `\(arg)`")
    }

    /// La disponibilidad del destino del faro se DERIVA de la card de re-entrada. Re-escribir los
    /// tres términos es como dos gates que deben coincidir empiezan a divergir.
    @Test("`cloudEntryAvailable` se deriva de `visibleExistingOptions`, no se re-escribe")
    func cloudEntryAvailable_isDerivedFromTheExistingCard() throws {
        let body = try Self.body(of: "private var cloudEntryAvailable: Bool {",
                                 in: try Self.source(Self.containerPath))
        #expect(body.contains("visibleExistingOptions.contains(.cloudSignIn)"))
    }

    /// **Paso 6 · «Crear otra cuenta» abre el chooser ENTERO, no el de nivel 1** (decisión de Jürgen
    /// 2026-09-09). El XCUITest lo prueba de verdad; esto fija en la suite rápida la mitad que un refactor
    /// movería sin que nada visible se rompiera hasta el siguiente device-QA: volver a `.chooser` dejaría a
    /// la persona en «¿qué quieres hacer?», donde «Soy nuevo» la volvería a encaminar.
    @Test("«Crear otra cuenta» reabre el Welcome en `.newChooser`, y la entrada del faro es la suya propia")
    func createAnother_reopensTheFullChooser() throws {
        let content = try Self.source("Yala/App/ContentView.swift")
        let closure = try Self.body(of: "onCreateAnotherAccount: {", in: content)
        #expect(closure.contains("welcomeFlowInitialStep = .newChooser"))
        #expect(!closure.contains("welcomeFlowInitialStep = .chooser"),
                "el nivel 1 re-encaminaría por el faro: la persona no llegaría nunca a elegir")
        #expect(closure.contains("showWelcomeCloudSignIn = false"))
        #expect(closure.contains("showWelcomeFlow = true"))

        let beacon = try Self.body(of: "onBeaconRoutesToCloudSignIn: { provider in", in: content)
        #expect(beacon.contains("welcomeCloudEntry = .beaconRouted(accountProvider: provider)"),
                "con `.reentry` el intro no sabría que vino del faro y no ofrecería «Crear otra cuenta»")
    }

    /// **La persona vuelve a estar ELIGIENDO** (lentes A y D de la review): con el `true` que dejó el faro al
    /// encaminar, un cierre de la app en ese chooser abriría el onboarding privado directo —sin elegir y sin la
    /// comprobación de iCloud del paso 4— y el arranque siguiente ya no montaría neutro.
    @Test("«Crear otra cuenta» devuelve `hasShownWelcomeChooser` a false, como el recorrido normal")
    func createAnother_resetsTheChooserSeenFlag() throws {
        let content = try Self.source("Yala/App/ContentView.swift")
        let closure = try Self.body(of: "onCreateAnotherAccount: {", in: content)
        #expect(closure.contains("hasShownWelcomeChooser = false"))
    }

    private static let signInViewPath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"

    /// **Paso 6 · lo que la entrada del faro y el mismatch hacen DESPUÉS de firmar.** Ningún XCUITest llega ahí
    /// —hace falta un sign-in real—, así que estas cuatro defensas se fijan una por test: si compartieran test,
    /// un mutante taparía a otro. La primera es la que más caro sale: si `.beaconRouted` corriera el flujo del
    /// ALTA, «Iniciar sesión con Apple» crearía una cuenta en vez de entrar.
    @Test("la entrada del faro ENTRA tras el consentimiento, nunca da de alta")
    func beaconRoutedEntry_signsIn_afterTheConsent() throws {
        let afterConsent = try Self.body(of: "private func runFlowAfterConsent() async {",
                                         in: try Self.source(Self.signInViewPath))
        let beaconLine = try #require(afterConsent.split(separator: "\n").first { $0.contains(".beaconRouted") })
        #expect(beaconLine.contains("runSignInFlow()"))
        #expect(!beaconLine.contains("runBornCloudFlow"), "con el flujo del alta, «Iniciar sesión» crearía una cuenta")
    }

    /// Lente B: el Keychain puede quedarse con el método de otra sesión, y con él la prueba de Apple del faro
    /// huérfano borraría el faro de una cuenta viva.
    @Test("el motor recibe el método que la pantalla ACABA de firmar, no el del Keychain")
    func signInFlow_passesTheSignedMethodToTheMotor() throws {
        let signIn = try Self.body(of: "private func runSignInFlow() async {", in: try Self.source(Self.signInViewPath))
        #expect(signIn.contains("CloudIdentityDiscovery(sessionProviderName: { firmadoCon.rawValue })"))
        #expect(signIn.contains("let firmadoCon = provider"))
    }

    /// Lente A: «Iniciar sesión con…» suelta una sesión viva, respeta el consentimiento y, si se cancela,
    /// vuelve a la pantalla de las dos salidas en vez de al intro.
    @Test("«Iniciar sesión con…» del mismatch: suelta la sesión, respeta el consentimiento y vuelve si se cancela")
    func mismatchSignIn_releasesSession_respectsConsent_andReturnsOnCancel() throws {
        let exit = try Self.body(
            of: "private func signInWithAccountMethod(_ method: CloudSignInProvider, from exits: ProviderMismatchLogic.Exits) {",
            in: try Self.source(Self.signInViewPath))
        #expect(exit.contains("if CloudAuthService.shared.hasSession { await CloudAuthService.shared.signOut() }"))
        #expect(exit.contains("guard consentStillPending else"))
        #expect(exit.contains("if phase == .intro { phase = .providerMismatch(exits) }"))
    }

    // MARK: - La puerta del alta en la pantalla de entrar

    /// Ticket `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`. Ningún XCUITest llega a «No encontramos
    /// una cuenta» ni al mismatch —las dos fases exigen firmar de verdad— y en el host de test la capacidad vale `false`,
    /// así que el cableado de la puerta solo lo puede ver un scan. Por eso se ancla la condición ENTERA, con su llave: una
    /// puerta invertida (`if !…`), ampliada (`if … || algo {`) o sustituida no casa con este literal.
    private static let signUpGate = "if WelcomeNewOptionsGate.offersCloudSignUp {"

    /// El fichero sin sus líneas de comentario, como `body(of:)`. Las posiciones se miden sobre ESTE texto: los docblocks
    /// de la vista nombran la puerta y `switchToSignUp`, y contarlos pondría el test en rojo por documentar.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func ranges(of marker: String, in code: String) -> [Range<String.Index>] {
        var hits: [Range<String.Index>] = []
        var cursor = code.startIndex
        while let hit = code.range(of: marker, range: cursor..<code.endIndex) {
            hits.append(hit)
            cursor = hit.upperBound
        }
        return hits
    }

    /// Lo que va DENTRO de cada bloque que abre `marker`: desde su llave de apertura hasta la que la cierra.
    private static func blocks(openedBy marker: String, in code: String) -> [Range<String.Index>] {
        ranges(of: marker, in: code).map { opening in
            var depth = 1
            var index = opening.upperBound
            while index < code.endIndex {
                if code[index] == "{" { depth += 1 }
                if code[index] == "}" { depth -= 1; if depth == 0 { break } }
                index = code.index(after: index)
            }
            return opening.upperBound..<index
        }
    }

    /// **La puerta de las salidas es la card, y se DERIVA de ella.** En el host de test la capacidad vale `false`, así
    /// que el lado `true` de esta propiedad es inalcanzable: un `{ false }` le quitaría «Crear mi cuenta» a todo iPhone y
    /// solo un scan lo ve. Y repetir aquí los términos de `live` es como la card y las salidas empezarían a divergir. Se
    /// busca sobre el código sin comentarios: un docblock que citara el cuerpo bueno taparía uno malo.
    @Test("`offersCloudSignUp` es exactamente la card de la nube de `live`")
    func offersCloudSignUp_isTheCloudCardOfLive() throws {
        let body = try Self.body(
            of: "static var offersCloudSignUp: Bool {",
            in: Self.codeOnly(try Self.source("Yala/App/Logic/WelcomeAccountChoiceLogic.swift")))
        #expect(Self.normalized(body) == "live.contains(.cloudAccount)")
    }

    /// **Toda salida al alta de la pantalla de entrar va detrás de la puerta**, también la que alguien añada mañana. Dos
    /// medidas por POSICIÓN: cada llamada a `switchToSignUp(` cae dentro de un bloque cuya condición es exactamente la
    /// puerta, y son tres (el botón de «No encontramos una cuenta» y los dos de marca del «Crear cuenta con…»); y el
    /// reencaminamiento al alta, `entryOverride = .bornCloud`, solo existe dentro de `switchToSignUp`. Sin la segunda, una
    /// salida nueva que lo escribiera a mano —o un «Iniciar sesión con…» que reencaminara al alta— pasaría sin puerta.
    @Test("toda salida al alta pasa por la puerta: tres llamadas a `switchToSignUp` y un solo reencaminamiento al alta")
    func everySignUpExit_isBehindTheSignUpGate() throws {
        let code = Self.codeOnly(try Self.source(Self.signInViewPath))
        let blocks = Self.blocks(openedBy: Self.signUpGate, in: code)
        let calls = Self.ranges(of: "switchToSignUp(", in: code).filter { hit in
            // La DEFINICIÓN no es una salida.
            let lineStart = code[..<hit.lowerBound].lastIndex(of: "\n").map { code.index(after: $0) } ?? code.startIndex
            return !code[lineStart..<hit.lowerBound].contains("func ")
        }
        #expect(calls.count == 3, "se esperaban 3 salidas al alta y hay \(calls.count)")
        for call in calls {
            let lineStart = code[..<call.lowerBound].lastIndex(of: "\n").map { code.index(after: $0) } ?? code.startIndex
            let lineEnd = code[call.upperBound...].firstIndex(of: "\n") ?? code.endIndex
            #expect(blocks.contains { $0.contains(call.lowerBound) },
                    "una salida al alta no pasa por la puerta: «\(code[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces))»")
        }

        let reroutes = Self.ranges(of: "entryOverride = .bornCloud", in: code)
        try #require(reroutes.count == 1, "se esperaba un solo `entryOverride = .bornCloud` y hay \(reroutes.count)")
        let definition = Self.blocks(
            openedBy: "private func switchToSignUp(with signUpProvider: CloudSignInProvider) {", in: code)
        try #require(definition.count == 1, "`switchToSignUp` cambió de firma o está repetida")
        #expect(definition[0].contains(reroutes[0].lowerBound), "el reencaminamiento al alta vive fuera de `switchToSignUp`")
    }

    /// **Las dos pantallas, ENTERAS** (`.claude/rules/testing.md`: cuando el scan es la única red, se fija el cuerpo
    /// entero normalizado). Medir solo que los botones de crear «caen dentro» de la puerta dejaba vivo el fallo caro: una
    /// condición más alrededor o dentro (`if exits.accountProvider != nil`, `if provider == .apple`, un `#if DEBUG`) le
    /// quitaba el botón a un iPhone con App Attest con la suite en verde, y un `/* */` lo dejaba sin puerta. Fija además
    /// lo que va FUERA: el mensaje de las dos pantallas, la salida de entrar del mismatch y el «Volver» que ocupa el sitio
    /// de «Crear mi cuenta» sin la puerta (decisión de Jürgen, 2026-09-16), con el identificador del mensaje en su bloque
    /// para que no pise los de los botones.
    @Test("las dos pantallas, enteras: la puerta es la única condición de los botones de crear y «Volver» ocupa su sitio")
    func signUpScreens_areFixedWhole() throws {
        let code = Self.codeOnly(try Self.source(Self.signInViewPath))
        #expect(Self.blocks(openedBy: Self.signUpGate, in: code).count == 2, "se esperaban 2 bloques con la puerta del alta")

        let notFound = try Self.body(of: "private var notFoundContent: some View {", in: code)
        #expect(Self.normalized(notFound) == """
            VStack(spacing: DS.Spacing.lg) { \
            messageContent( \
            icon: "person.crop.circle.badge.questionmark", \
            title: L10n.Welcome.Cloud.notFoundTitle, \
            body: L10n.Welcome.Cloud.notFoundBody) \
            .accessibilityIdentifier("welcome_cloud_not_found") \
            if WelcomeNewOptionsGate.offersCloudSignUp { \
            YalaPrimaryButton(L10n.Welcome.Cloud.notFoundCta) { \
            DS.Haptic.selection() \
            switchToSignUp(with: provider) \
            } \
            .padding(.horizontal, DS.Spacing.xl) \
            .accessibilityIdentifier("welcome_cloud_not_found_cta") \
            } else { \
            YalaPrimaryButton(L10n.Welcome.Cloud.blockedBack) { \
            onBack() \
            } \
            .padding(.horizontal, DS.Spacing.xl) \
            .accessibilityIdentifier("welcome_cloud_not_found_back") \
            } \
            }
            """, "«No encontramos una cuenta» cambió: revisa que «Crear mi cuenta» siga detrás de la puerta y «Volver» fuera")

        let mismatch = try Self.body(
            of: "private func providerMismatchContent(_ exits: ProviderMismatchLogic.Exits) -> some View {", in: code)
        #expect(Self.normalized(mismatch) == """
            VStack(spacing: DS.Spacing.lg) { \
            messageContent( \
            icon: "person.crop.circle.badge.exclamationmark", \
            title: L10n.Welcome.Cloud.providerMismatchTitle, \
            body: providerMismatchBody(accountProvider: exits.accountProvider)) \
            .accessibilityIdentifier("welcome_cloud_provider_mismatch") \
            VStack(spacing: DS.Spacing.md) { \
            switch exits.signInWith { \
            case .apple: \
            AppleSignInButton(type: .signIn) { \
            DS.Haptic.selection() \
            signInWithAccountMethod(exits.signInWith, from: exits) \
            } \
            .frame(height: 50) \
            .accessibilityIdentifier("welcome_cloud_mismatch_sign_in") \
            case .google: \
            GoogleSignInButton(variant: .light, purpose: .signIn) { \
            DS.Haptic.selection() \
            signInWithAccountMethod(exits.signInWith, from: exits) \
            } \
            .frame(height: 50) \
            .accessibilityIdentifier("welcome_cloud_mismatch_sign_in") \
            } \
            if WelcomeNewOptionsGate.offersCloudSignUp { \
            switch exits.createWith { \
            case .apple: \
            AppleSignInButton(type: .signUp) { \
            DS.Haptic.selection() \
            switchToSignUp(with: exits.createWith) \
            } \
            .frame(height: 50) \
            .accessibilityIdentifier("welcome_cloud_mismatch_create") \
            case .google: \
            GoogleSignInButton(variant: .light, purpose: .signUp) { \
            DS.Haptic.selection() \
            switchToSignUp(with: exits.createWith) \
            } \
            .frame(height: 50) \
            .accessibilityIdentifier("welcome_cloud_mismatch_create") \
            } \
            } \
            } \
            .padding(.horizontal, DS.Spacing.xl) \
            }
            """, "el mismatch cambió: revisa que «Crear cuenta con…» siga detrás de la puerta y «Iniciar sesión con…» fuera")
    }

    /// A5 SUSTITUYE AL STUB DE A4. La versión anterior de este test exigía
    /// `showBornCloudPendingAlert = true` (el aviso «próximamente» de la card de nube) y decía por
    /// escrito que había que BORRARLO en el commit de A5, no silenciarlo. Esto es ese borrado: la
    /// card ya tiene destino real y lo que se pinnea ahora es que lo tenga.
    @Test("la card de nube arranca el alta born-cloud (y el stub de A4 ya no existe)")
    func cloudCard_startsTheBornCloudSignUp() throws {
        let src = try Self.source(Self.containerPath)
        let body = try Self.body(
            of: "private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {",
            in: src)
        #expect(body.contains("case .cloudAccount:"))
        #expect(body.contains("onSelectCloudAccount()"),
                "sin este callback la card vuelve a ser un botón muerto, ahora en silencio")
        // Sobre el CÓDIGO, no sobre el texto: el comentario que explica el borrado nombra el símbolo
        // borrado, así que un `!contains` sobre el fichero crudo se rompe al documentar el invariante.
        let code = src.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        #expect(!code.contains("showBornCloudPendingAlert"),
                "el stub de A4 se BORRA en el commit de A5 — una promesa con fecha, no un residual")
    }

    /// A7 verifica esta constante antes de subir el percent de producción; que lo haga un test y no
    /// solo un grep evita que el día del encendido dependa de la memoria de nadie.
    @Test("la constante compilada de la choice card está en `true` (la palanca de release es el percent)")
    func compiledFlag_isOn() {
        #expect(CloudSyncFlags.bornCloudChoiceEnabled)
    }
}

// MARK: - Qué se dice cuando la búsqueda termina vacía (owner 2026-09-06 y 2026-09-17)

/// El mensaje del ÚNICO camino que queda abierto bajo el kill. Con las dos puertas de nube cerradas,
/// quien vuelve solo puede tocar «Restaurar desde iCloud» — y esa pantalla busca en CloudKit, donde un
/// nacido-en-nube nunca tuvo nada. La tabla de abajo fija que cada aviso aparece SOLO cuando su hecho
/// es cierto, y son TRES hechos desde el 2026-09-17: «no hay datos», «los hay y la nube está en pausa»
/// y «no lo hemos podido comprobar».
///
/// MUTANTES VERIFICADOS (compilados y corridos sobre las 3 suites afectadas, no razonados):
///  (1) la decisión sin su `guard cloudConfigKnown` —la tabla de antes del ticket— → 6 fallos.
///  (2) `isConfigKnown` con `!backendConfigured` devolviendo `false` (la ausencia falla cerrada) → 3.
///  (3) `.cloudUnverified` llamando a `onStartFresh()` directo, sin confirmar → 4.
///  (4) `case .cloudUnverified:` pintando `state = .notFound` (el swap que compila) → 3.
///  (5) la lectura de `cloudConfigKnown` guardada en un `let` POR ENCIMA del `refreshIfDue(force: true)`
///      y pasada por variable → 3. Es la forma que la review señaló que se colaba: el ancla del test
///      miraba `cloudConfigKnown` a secas, que casa primero con la ETIQUETA del argumento y no puede
///      moverse sola. Hoy el ancla es `CloudRemoteFlags.cloudConfigKnown` y el mutante cae.
///  (6) el adaptador vivo con `hasSnapshot: true` cableado a la constante → 3.
///  (7) el desconocimiento ganando al faro —el primer intento de este ticket, que le quitaba «tus datos
///      siguen a salvo» a quien SÍ tiene cuenta probada— → 4. Lo cazó la review adversarial, no yo.
@Suite("Restore con búsqueda vacía — solo se afirma lo que se sabe")
struct WelcomeRestoreEmptyOutcomeTests {

    @Test("La tabla 2×2 del kill: hace falta faro Y kill, y con el config YA comprobado")
    func table() {
        // El caso que motiva el aviso de pausa: cuenta nube + kill puesto ⇒ «la nube está en pausa».
        #expect(WelcomeRestoreEmptyOutcome.resolve(
            beaconLinked: true, cloudConfigKnown: true, remoteCloudEnabled: false) == .cloudPaused)

        // Sin faro no hay nada que prometer: este Apple ID no tiene cuenta nube, así que una búsqueda
        // vacía SÍ significa "no hay datos" y el copy honesto es el de siempre.
        #expect(WelcomeRestoreEmptyOutcome.resolve(
            beaconLinked: false, cloudConfigKnown: true, remoteCloudEnabled: false) == .notFound)

        // Con la nube encendida el vacío tampoco se explica por una pausa. Y además este usuario no
        // llega aquí: con el kill apagado tiene sus cards de sign-in.
        #expect(WelcomeRestoreEmptyOutcome.resolve(
            beaconLinked: true, cloudConfigKnown: true, remoteCloudEnabled: true) == .notFound)

        #expect(WelcomeRestoreEmptyOutcome.resolve(
            beaconLinked: false, cloudConfigKnown: true, remoteCloudEnabled: true) == .notFound)
    }

    /// **El caso del ticket `reinstall-without-network-has-no-cloud-door`.** Quien reinstala pierde el
    /// snapshot de remote-config (vive en el contenedor de la app) y su iCloud-KV tampoco ha
    /// sincronizado, así que las DOS señales están en blanco. Antes, `beaconLinked: false` mandaba a
    /// `.notFound` y ese usuario leía «no hay datos asociados a tu cuenta» con su histórico intacto en
    /// el servidor.
    @Test("Sin faro y sin config no se afirma nada: `.cloudUnverified`, diga lo que diga el remoto")
    func unverifiedWhenNeitherSignalIsIn() {
        for remote in [true, false] {
            #expect(WelcomeRestoreEmptyOutcome.resolve(
                beaconLinked: false,
                cloudConfigKnown: false,
                remoteCloudEnabled: remote) == .cloudUnverified, Comment(rawValue: """
                remoto=\(remote): sin haber hablado con el servidor no se puede afirmar que los datos
                falten — el propio valor de `remoteCloudEnabled` es el `absentDefault`, no una
                respuesta, y por eso no puede decidir nada aquí.
                """))
        }
    }

    /// **El faro gana al desconocimiento, y esto lo cazó la review adversarial del 2026-09-17.** El
    /// primer intento mandaba a `.cloudUnverified` todo lo que llegara sin snapshot, faro incluido:
    /// le quitaba «tus datos siguen a salvo en tu cuenta de Yala» justo a quien SÍ podemos probar que
    /// tiene cuenta, y le mandaba a revisar una conexión que funciona.
    ///
    /// La población es real porque **las dos señales viajan por canales distintos**: el faro vive en el
    /// iCloud-KV y el snapshot lo sirve nuestro gateway, así que una red que filtre el dominio del
    /// Worker, un 5xx o una caída de Cloudflare dejan el faro puesto y el snapshot ausente.
    @Test("Con faro probado gana `.cloudPaused` aunque no se haya podido comprobar el config")
    func beaconWinsOverNotKnowing() {
        for remote in [true, false] {
            #expect(WelcomeRestoreEmptyOutcome.resolve(
                beaconLinked: true,
                cloudConfigKnown: false,
                remoteCloudEnabled: remote) == .cloudPaused, Comment(rawValue: """
                remoto=\(remote): con el faro puesto ya sabemos el hecho que decide el mensaje —los
                datos EXISTEN—, y eso no depende de haber podido preguntar. El término remoto no puede
                cambiarlo: sin snapshot su valor es el `absentDefault`, que difiere entre builds.
                """))
        }

        // Y el control por el otro lado: con el config comprobado y la nube ABIERTA, el faro no
        // convierte en pausa un vacío que sí está medido.
        #expect(WelcomeRestoreEmptyOutcome.resolve(
            beaconLinked: true, cloudConfigKnown: true, remoteCloudEnabled: true) == .notFound)
    }

    /// **La ausencia de snapshot falla ABIERTA en dos casos, y los dos evitarían un mensaje falso para
    /// todo el parque.** Sin backend configurado `refreshIfDue` sale en su primera línea: no habría
    /// snapshot NUNCA, así que tratar esa ausencia como «no comprobado» le enseñaría el aviso a todo el
    /// mundo para siempre. Y bajo host de test el `.standard` del simulador puede traer el snapshot de
    /// una corrida manual — el mismo corte que ya hace `CloudRemoteFlags.decide`, para que el recorrido
    /// determinista quede byte-idéntico.
    @Test("La ausencia de snapshot solo cuenta si había a quién preguntar y no es un host de test")
    func absentSnapshotFailsOpenWhereItMust() {
        // El caso real: hay backend, no es test, y no hay snapshot ⇒ no lo sabemos.
        #expect(!RemoteFlagDecisionLogic.isConfigKnown(
            hasSnapshot: false, backendConfigured: true, isTestHost: false))

        // Con snapshot lo sabemos, y da igual lo que diga.
        #expect(RemoteFlagDecisionLogic.isConfigKnown(
            hasSnapshot: true, backendConfigured: true, isTestHost: false))

        // Sin backend no hay comprobación pendiente: la nube no existe para esa build.
        #expect(RemoteFlagDecisionLogic.isConfigKnown(
            hasSnapshot: false, backendConfigured: false, isTestHost: false))

        // Host de test: el recorrido de hoy, sin depender del estado del simulador.
        #expect(RemoteFlagDecisionLogic.isConfigKnown(
            hasSnapshot: false, backendConfigured: true, isTestHost: true))
    }

    /// **El adaptador que alimenta la decisión con lo vivo, fijado por su cuerpo entero.** No se puede
    /// probar por comportamiento: bajo host de test `cloudConfigKnown` vale `true` por diseño —el mismo
    /// corte que `decide()`— así que llamarlo desde aquí devuelve siempre lo mismo y no distingue nada.
    /// Y es un sitio donde el swap sale barato: cablear `hasSnapshot: true` fijo deja la pantalla
    /// exactamente como estaba antes del ticket, con el enum nuevo puesto y toda la tabla en verde.
    @Test("`cloudConfigKnown` alimenta la decisión con las tres entradas VIVAS, no con constantes")
    func liveAdapterFeedsTheRealTerms() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // YalaTests/
                .deletingLastPathComponent()   // repo root
                .appendingPathComponent("Yala/Services/CloudSync/CloudRemoteConfig.swift"),
            encoding: .utf8)
        let code = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
            .joined(separator: "\n")
        let marker = "static var cloudConfigKnown: Bool {"
        let start = try #require(code.range(of: marker), "el getter `cloudConfigKnown` cambió de firma")
        let chars = Array(code[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        let body = String(chars[0..<min(i, chars.count)])
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        #expect(body == "RemoteFlagDecisionLogic.isConfigKnown( "
            + "hasSnapshot: CloudRemoteConfigStore.readSnapshot() != nil, "
            + "backendConfigured: CloudBackendConfig.isConfigured, "
            + "isTestHost: isRunningTests || isUITestHost)", Comment(rawValue: """
                El cuerpo de `cloudConfigKnown` cambió y este test fija el ENTERO a propósito: cada una
                de sus tres entradas es un término que, cableado a una constante, devuelve la pantalla
                al mensaje falso sin poner nada en rojo. Cuerpo medido: \(body)
                """))
    }

    /// **El término que hace útil al botón «Reintentar», y el que alguien retiraría por limpieza.**
    /// `refreshIfDue` SIN `force` es un no-op mientras el último fetch tenga menos de 6 h — el caso
    /// normal, porque el boot acaba de refrescar. Sin forzar, esta pantalla leería el flag del
    /// arranque y su botón primario no podría cambiar nunca el desenlace: el kill se conmuta desde el
    /// backend. Es el mismo no-op que ya mordió en `WelcomeGroupsGateView` y en `GroupsContainerView`.
    ///
    /// Desde el 2026-09-17 carga además el otro término: `cloudConfigKnown` se lee DESPUÉS del refresco
    /// porque el refresco es justamente el intento de que deje de ser `false`.
    @Test("La decisión se toma con el flag FRESCO, no con el del arranque")
    func outcomeIsDecidedOnAFreshFlag() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // YalaTests/
                .deletingLastPathComponent()   // repo root
                .appendingPathComponent("Yala/App/Views/Onboarding/WelcomeRestoreView.swift"),
            encoding: .utf8)
        let marker = "private func resolveEmptyState(_ settlement: RestoreImportSettlement) async {"
        let start = try #require(source.range(of: marker), "la firma de `resolveEmptyState` cambió")
        let chars = Array(source[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        let body = String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        #expect(body.contains("refreshIfDue(force: true)"), """
            La resolución tiene que forzar el refresco del flag remoto. Sin `force: true` el fetch es
            un no-op durante 6 h y «Reintentar» se convierte en un botón que no puede cambiar su
            propio desenlace.
            """)
        #expect(body.contains("Task.isCancelled"), """
            tras el único punto de suspensión hace falta el guard: la cancelación de `refreshIfDue` es
            cooperativa y sin él la pantalla cambia bajo el dedo de quien ya tocó «volver».
            """)
        #expect(!body.contains("hasAnyData"), """
            esta rama es solo para búsquedas VACÍAS; si vuelve a decidir sobre `hasAnyData`, alguien
            metió el camino con datos detrás de una llamada de red que no necesita.
            """)

        // Y el orden: el estado de conocimiento se LEE después del intento de conseguirlo. Leerlo
        // antes describiría el mundo previo a preguntar, que es el de cualquier arranque — y el
        // mensaje nuevo saldría con red y todo.
        // El ancla es la LECTURA completa, no la etiqueta del argumento. `cloudConfigKnown` a secas
        // casa primero con `cloudConfigKnown:` del callsite, que no puede moverse independientemente
        // de la llamada — así que mediría algo que no puede fallar por la vía que dice. Con este ancla
        // sí cae el mutante que guarda la lectura en un `let` por encima del `await` y pasa la variable.
        let refresh = try #require(body.range(of: "refreshIfDue(force: true)"))
        let known = try #require(body.range(of: "CloudRemoteFlags.cloudConfigKnown"),
                                 "la pantalla dejó de leer si el config llegó a comprobarse")
        #expect(refresh.upperBound < known.lowerBound, """
            `cloudConfigKnown` se lee ANTES del refresco: así siempre valdría lo de antes de preguntar.
            """)
    }

    /// **El mapeo de los tres desenlaces a los tres estados de pantalla, uno por uno.** La decisión pura
    /// de arriba puede estar perfecta y la pantalla enseñar otra cosa: mandar `.cloudUnverified` al
    /// estado `.notFound` compila, deja toda la tabla en verde y reintroduce el bug entero con el
    /// enum nuevo puesto. Como los tres desenlaces viven en closures de una vista SwiftUI que ningún
    /// unit test puede invocar, la única red posible es el scan — y entonces se fija el emparejamiento,
    /// no la presencia de los literales (`.claude/rules/testing.md`).
    @Test("Cada desenlace pinta SU estado: el swap que compila no pasa")
    func eachOutcomeMapsToItsOwnState() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // YalaTests/
                .deletingLastPathComponent()   // repo root
                .appendingPathComponent("Yala/App/Views/Onboarding/WelcomeRestoreView.swift"),
            encoding: .utf8)
        let code = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let marker = "private func resolveEmptyState(_ settlement: RestoreImportSettlement) async {"
        let start = try #require(code.range(of: marker), "la firma de `resolveEmptyState` cambió")
        let chars = Array(code[start.upperBound...])
        var depth = 1, i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        let body = String(chars[0..<min(i, chars.count)])

        // Cada `case` se acota hasta el siguiente para que la aserción no la cumpla el vecino: un
        // recorte que llegue al final del cuerpo se satisface con la asignación de al lado.
        let cases = ["case .cloudPaused:", "case .cloudUnverified:", "case .notFound:"]
        let estados = [".cloudPaused", ".cloudUnverified", ".notFound"]
        for (caso, estado) in zip(cases, estados) {
            let desde = try #require(body.range(of: caso), Comment(rawValue: "falta la rama `\(caso)`"))
            let siguiente = cases
                .compactMap { body.range(of: $0, range: desde.upperBound..<body.endIndex)?.lowerBound }
                .min() ?? body.endIndex
            let rama = String(body[desde.upperBound..<siguiente])
            #expect(rama.contains("state = \(estado)"), Comment(rawValue: """
                `\(caso)` no pone `state = \(estado)`. Mandar un desenlace al estado de otro compila y
                deja toda la tabla de decisión en verde mientras la pantalla afirma lo que no sabe.
                """))
        }

        // Y el rastro de producción del caso nuevo, que es lo único que distingue en Console.app un
        // «no pudimos comprobar» de un `.notFound` legítimo: en pantalla se parecen.
        let unverified = try #require(body.range(of: "case .cloudUnverified:"))
        let siguiente = body.range(of: "case .notFound:", range: unverified.upperBound..<body.endIndex)?
            .lowerBound ?? body.endIndex
        #expect(String(body[unverified.upperBound..<siguiente]).contains("RestoreBreadcrumb.cloudUnverified()"), """
            la rama del desenlace nuevo dejó de dejar rastro: sin él, el único recorrido que produce
            este mensaje —reinstalar sin red— no deja huella de por qué enseñó lo que enseñó.
            """)
    }

    /// Control de coherencia entre las dos mitades de la decisión: el aviso de PAUSA solo puede verse
    /// en el mismo estado remoto que cierra las cards. Si alguien relaja el kill en
    /// `visibleExistingOptions` sin tocar esto, el usuario tendría su card Y el aviso a la vez.
    @Test("El aviso de pausa vive exactamente en el estado que cierra la card de sign-in")
    func pausedOnlyWhenTheCardIsGone() {
        for beaconLinked in [true, false] {
            for remote in [true, false] {
                let cards = WelcomeAccountChoiceLogic.visibleExistingOptions(
                    isConfigured: true, isUITest: false, remoteCloudEnabled: remote)
                let outcome = WelcomeRestoreEmptyOutcome.resolve(
                    beaconLinked: beaconLinked, cloudConfigKnown: true, remoteCloudEnabled: remote)
                if outcome == .cloudPaused {
                    #expect(!cards.contains(.cloudSignIn),
                            "el aviso de pausa no puede convivir con la card de sign-in")
                }
            }
        }
    }
}
