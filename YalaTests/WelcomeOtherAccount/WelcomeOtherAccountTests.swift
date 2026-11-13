//
//  WelcomeOtherAccountTests.swift
//  YalaTests
//
//  Ticket `other-account-sign-in-bounces-to-welcome` (fallos de Jürgen del 13-nov en el iPhone 14):
//  1. Google · «Usar otra cuenta» rebotaba a la bienvenida en vez de abrir el selector de cuentas.
//  2. Entrar con Google en un teléfono con datos del iCloud privado pedía reabrir y, al volver, otra vez el inicio de
//     sesión: la vuelta al neutro purga la sesión. Se deja iCloud aparte ANTES de firmar.
//  3. Apple · «Usar otra cuenta» rebotaba y volvía a firmar con el mismo Apple ID: un bucle.
//
//  Lógica pura con su tabla, y el cableado de la pantalla por lectura del fuente: con el código de antes, los escaneos
//  caen (`useAnotherAccount` llamaba a `onBack()` y la entrada firmaba sin mirar el corpus de iCloud).
//

import Foundation
import Testing
@testable import Yala

@Suite("Bienvenida · «Usar otra cuenta» abre otra cuenta (fallos 1 y 3)")
struct WelcomeUseAnotherAccountTests {

    @Test("Google vuelve a abrir su hoja, con o sin la web de Apple")
    func googleSignsInAgain() {
        #expect(WelcomeUseAnotherAccount.exit(provider: .google, appleWebSignInEnabled: true) == .signInAgain)
        #expect(WelcomeUseAnotherAccount.exit(provider: .google, appleWebSignInEnabled: false) == .signInAgain)
    }

    @Test("Apple con la web encendida abre otro Apple ID; sin ella, solo la salida a Google (nunca el mismo Apple ID)")
    func appleNeverReopensTheSameAppleID() {
        #expect(WelcomeUseAnotherAccount.exit(provider: .apple, appleWebSignInEnabled: true) == .appleOnTheWeb)
        #expect(WelcomeUseAnotherAccount.exit(provider: .apple, appleWebSignInEnabled: false) == .onlyTheOtherProvider)
    }
}

@Suite("Bienvenida · iCloud aparte antes de firmar (fallo 2)")
struct WelcomeLeaveICloudBeforeSignInTests {

    @Test("Con corpus de iCloud con copia y sin sello ni restauración, se vacía antes de firmar")
    func leavesFirstWhenTheGuardWouldBlock() {
        #expect(WelcomeLeaveICloudBeforeSignIn.leavesICloudAsideFirst(
            hasLocalData: true, restoreInProgress: false, hasClaimSeal: false, asideExit: .leaveICloudAside))
    }

    @Test("Cualquier término que haga pasar al guard o que no deje iCloud aparte vuelve al camino de siempre",
          arguments: [
            (false, false, false, ICloudAsideEntryLogic.Exit.leaveICloudAside),  // sin corpus: firmar y entrar
            (true, true, false, .leaveICloudAside),                               // el dueño restaurando: el guard pasa
            (true, false, true, .leaveICloudAside),                               // sello de claim: se sabe tras firmar
            (true, false, false, .staysBlocked),                                  // sin copia en iCloud: nunca vaciar
          ])
    func everyOtherCaseSignsInFirst(hasLocalData: Bool, restoring: Bool, seal: Bool, exit: ICloudAsideEntryLogic.Exit) {
        #expect(!WelcomeLeaveICloudBeforeSignIn.leavesICloudAsideFirst(
            hasLocalData: hasLocalData, restoreInProgress: restoring, hasClaimSeal: seal, asideExit: exit))
    }

    @Test("El sello de cualquier cuenta cuenta, y sin ninguno no hay sello")
    @MainActor
    func anyClaimSealCounts() throws {
        let defaults = try #require(testDefaults(suiteName: "WelcomeOtherAccountTests.\(UUID().uuidString)"))
        let store = CloudClaimActionStore(defaults: defaults)
        #expect(!store.hasAnyClaim())
        store.record(.routeReturningUser, forUserID: "otra-cuenta")
        #expect(store.hasAnyClaim())
    }
}

@Suite("Bienvenida · cableado de la pantalla de entrar")
struct WelcomeOtherAccountWiringTests {

    private func viewSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(
            "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"), encoding: .utf8)
    }

    /// El cuerpo de una función privada, de su firma a la siguiente `private func`.
    private func body(of signature: String, in source: String) throws -> Substring {
        let start = try #require(source.range(of: signature))
        let rest = source[start.upperBound...]
        let end = rest.range(of: "    private ")?.lowerBound ?? rest.endIndex
        return rest[..<end]
    }

    @Test("«Usar otra cuenta» vuelve a firmar en el acto y no vuelve a la vitrina")
    func useAnotherAccountSignsInAgain() throws {
        let fn = try body(of: "private func useAnotherAccount()", in: try viewSource())
        #expect(fn.contains("await runSignInFlow(origin: .reentry)"))
        #expect(!fn.contains("onBack()"), "Volver a la vitrina es el rebote del fallo 1.")
        #expect(fn.contains("signsInWithAppleOnTheWeb = exit == .appleOnTheWeb"))
    }

    @Test("Las dos hojas usan la salida que decide el proveedor, nunca la de texto a secas")
    func bothSheetsUseTheProviderAwareExit() throws {
        let source = try viewSource()
        #expect(source.contains("useAnotherAccountControls(id: \"welcome_cloud_create_use_another\""))
        #expect(source.contains("useAnotherAccountControls(id: \"welcome_cloud_confirm_load_use_another\""))
        #expect(!source.contains("textExit(L10n.UnifiedAccess.useAnotherAccount, id: \"welcome_cloud_"))
    }

    @Test("Toda entrada que firma mira el corpus de iCloud antes de abrir la hoja de inicio de sesión")
    func everySignInLeavesICloudAsideFirst() throws {
        let source = try viewSource()
        let flow = try body(of: "private func runSignInFlow(origin: WelcomeAdoptOrigin) async {", in: source)
        let check = try #require(flow.range(of: "if leavesICloudAsideInsteadOfSigningIn() {"))
        let signIn = try #require(flow.range(of: "guard await ensureSignedIn() else { return }"))
        #expect(check.lowerBound < signIn.lowerBound, "La hoja de inicio de sesión se abría antes de dejar iCloud aparte.")
        #expect(flow[check.upperBound...].hasPrefix("\n            onLeaveICloudAside(provider)\n            return"))
        let fn = try body(of: "private func leavesICloudAsideInsteadOfSigningIn()", in: source)
        #expect(fn.contains("guard !CloudAuthService.shared.hasSession else { return false }"))
        #expect(fn.contains("if case .bornCloud = activeEntry { return false }"))
        #expect(fn.contains("ICloudAsideEntryLogic.exit("))
        #expect(fn.contains("ICloudRestoreSessionSignal.isRestoringNow"))
        #expect(fn.contains("CloudClaimActionStore.shared.hasAnyClaim()"))
    }

    @Test("Desde «¡Hola de nuevo!» se deja iCloud aparte ANTES del consentimiento, que si no se pediría dos veces")
    func reentryLeavesICloudAsideBeforeTheConsent() throws {
        let source = try viewSource()
        let latch = try #require(source.range(of: "guard startsAtConsent, !didAutoOpenConsent else { return }"))
        let rest = source[latch.upperBound...]
        let check = try #require(rest.range(of: "if leavesICloudAsideInsteadOfSigningIn() {"))
        let consent = try #require(rest.range(of: "showConsent = true"))
        #expect(check.lowerBound < consent.lowerBound)
    }

    @Test("«Otra cuenta de Apple» firma por la web con el despacho común (seam de XCUITest y Pro incluidos)")
    func appleOnTheWebGoesThroughTheDispatcher() throws {
        let fn = try body(of: "private func ensureSignedIn()", in: try viewSource())
        #expect(fn.contains("appleOnTheWeb: appleOnTheWeb"))
        #expect(fn.contains("signsInWithAppleOnTheWeb = false"), "Se gasta una sola vez.")
    }
}
