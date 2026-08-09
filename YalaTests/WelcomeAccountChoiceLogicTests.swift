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
            isConfigured: true, isUITest: false, bornCloudEnabled: false,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    @Test
    func newOptions_bornCloudEnabled_requiresConfiguredAndNotUITest() {
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount, .cloudAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: false, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    @Test
    func newOptions_remoteFlags_bothRequired() {
        // DIFERIDOS #34: la card born-cloud exige el flag padre Y el sub-flag §j.1 —
        // el escalón born-cloud es POSTERIOR al del flag padre en el rollout.
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: false, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: false
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

/// La lógica NUEVA de A4 y la que carga su peso: sin ella un born-cloud en su 2º device elige
/// "iCloud privado" y arranca un dataset divergente que no se reúne con nada (A26). El bypass-test
/// no la cubre — con el faro puesto la elección ni se plantea.
@Suite("A4 · rama «Soy nuevo»: el faro se consulta ANTES de ofrecer nada (A26)")
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

    @Test("faro presente ⇒ returning-user, JAMÁS la elección — aunque las dos cards estén visibles")
    func beaconLinked_routesToCloudSignIn_evenWithBothCardsVisible() {
        let route = WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "apple"),
            cloudEntryAvailable: true,
            options: bothOptions)
        #expect(route == .cloudSignIn(.apple))
    }

    @Test("el provider sale del FARO, no de un default: Google encamina a Google")
    func beaconLinked_google_routesWithGoogleProvider() {
        let route = WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "google"),
            cloudEntryAvailable: true,
            options: bothOptions)
        #expect(route == .cloudSignIn(.google))
    }

    @Test("provider ausente o desconocido ⇒ `.apple` (el faro solo ENCAMINA; el mismatch lo dice el destino)")
    func beaconLinked_unknownProvider_fallsBackToApple() {
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: nil),
            cloudEntryAvailable: true,
            options: bothOptions) == .cloudSignIn(.apple))
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: true, provider: "microsoft"),
            cloudEntryAvailable: true,
            options: bothOptions) == .cloudSignIn(.apple))
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

    /// LA NO-REGRESIÓN que importa: con la card apagada (producción, percent remoto en 0) el
    /// recorrido "Soy nuevo" es byte-idéntico al de hoy — ni pantalla intermedia ni encaminamiento.
    @Test("card apagada ⇒ bypass a `.privateAccount`, el recorrido de producción de hoy")
    func cardOff_bypassesToPrivate_endToEnd() {
        let options = WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: false)
        #expect(options == [.privateAccount])
        #expect(WelcomeNewBranchRouter.route(
            beacon: makeBeacon(linked: false, provider: nil),
            cloudEntryAvailable: true,
            options: options) == .single(.privateAccount))
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
        let body = try Self.body(
            of: "private var visibleNewOptions: [WelcomeAccountChoiceLogic.NewOption] {",
            in: try Self.source(Self.containerPath))
        #expect(body.contains("bornCloudEnabled: CloudSyncFlags.bornCloudChoiceEnabled"))
        #expect(body.contains("remoteOnboardingChoiceEnabled: CloudRemoteFlags.cloudOnboardingChoiceEnabled"),
                "sin el sub-flag, la card dejaría de ser DARK en producción")
        #expect(body.contains("remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled"))
    }

    /// La disponibilidad del destino del faro se DERIVA de la card de re-entrada. Re-escribir los
    /// tres términos es como dos gates que deben coincidir empiezan a divergir.
    @Test("`cloudEntryAvailable` se deriva de `visibleExistingOptions`, no se re-escribe")
    func cloudEntryAvailable_isDerivedFromTheExistingCard() throws {
        let body = try Self.body(of: "private var cloudEntryAvailable: Bool {",
                                 in: try Self.source(Self.containerPath))
        #expect(body.contains("visibleExistingOptions.contains(.cloudSignIn)"))
    }

    /// STUB de A4: la card de nube avisa en voz alta hasta que A5 monte el encadenado. Si esto se
    /// pone rojo porque el destino ya existe, es A5 — bórralo en ESE commit, no lo silencies.
    @Test("la card de nube NO es un botón muerto silencioso (stub explícito hasta A5)")
    func cloudCard_hasAnExplicitStub() throws {
        let body = try Self.body(
            of: "private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {",
            in: try Self.source(Self.containerPath))
        #expect(body.contains("case .cloudAccount:"))
        #expect(body.contains("showBornCloudPendingAlert = true"))
    }

    /// A7 verifica esta constante antes de subir el percent de producción; que lo haga un test y no
    /// solo un grep evita que el día del encendido dependa de la memoria de nadie.
    @Test("la constante compilada de la choice card está en `true` (la palanca de release es el percent)")
    func compiledFlag_isOn() {
        #expect(CloudSyncFlags.bornCloudChoiceEnabled)
    }
}
