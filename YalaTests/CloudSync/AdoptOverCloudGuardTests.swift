//
//  AdoptOverCloudGuardTests.swift
//  YalaTests
//
//  Ticket `adopt-over-a-device-already-in-cloud-mode-has-no-exit`, opción A de Jürgen (13-nov-2026). «Empezar de cero» del
//  Welcome retiraba la sesión en la nube y olvidaba los sellos del claim, pero dejaba el modo en `.cloud`; volver a entrar
//  con la cuenta arrancaba un adopt que, con la nube ya puesta, quedaba pendiente para siempre, sin «Cancelar» ni techo.
//
//  La reproducción entera pide Google y el backend, que el simulador no firma. Estas pruebas fijan las dos mitades del
//  arreglo: la regla (lógica pura) y su cableado en las salidas del Welcome (scan del código, como
//  `InboxSwipeSuccessSheetWiringTests`). Sin el arreglo, caen.
//

import Foundation
import Testing
@testable import Yala

@Suite("Adopt sobre la nube · «Empezar de cero» deja el teléfono recién instalado y el adopt no arranca sobre la nube")
struct AdoptOverCloudGuardTests {

    // MARK: - La regla

    /// Mitad 1: solo un teléfono en `.cloud` vuelve a recién instalado; en iCloud el onboarding se abre como siempre.
    @Test func freshStart_returnsToFreshInstall_onlyWithTheCloudModePersisted() {
        #expect(AdoptOverCloudGuardLogic.freshStartReturnsToFreshInstall(persistedMode: .cloud))
        #expect(!AdoptOverCloudGuardLogic.freshStartReturnsToFreshInstall(persistedMode: .icloud))
    }

    /// Mitad 2: con la nube puesta y sin el sello de esta cuenta, no se adopta. Con el sello, o en iCloud, sigue como hoy.
    @Test func adopt_isRefused_onlyOverTheCloudWithoutThisAccountsSeal() {
        #expect(AdoptOverCloudGuardLogic.refusesAdopt(persistedMode: .cloud, sameAccountClaimExists: false))
        #expect(!AdoptOverCloudGuardLogic.refusesAdopt(persistedMode: .cloud, sameAccountClaimExists: true))
        #expect(!AdoptOverCloudGuardLogic.refusesAdopt(persistedMode: .icloud, sameAccountClaimExists: false))
        #expect(!AdoptOverCloudGuardLogic.refusesAdopt(persistedMode: .icloud, sameAccountClaimExists: true))
    }

    /// Las dos mitades cubren todos los modos: un modo nuevo obliga a mirar esta regla.
    @Test func everyStorageMode_isCoveredByTheTable() {
        #expect(Set(StorageMode.allCases) == [.icloud, .cloud])
    }

    // MARK: - El cableado

    private static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return text.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// El cuerpo que devuelve a recién instalado es el de «Cerrar sesión»: arma el borrado del arranque y lo consuma en
    /// caliente si puede. Sin el borrado por archivos, el espejo reproduciría el History de la época nube hacia iCloud.
    @Test func returnToFreshInstall_armsTheSignOutWipe_andTriesTheInPlaceSwap() throws {
        let signOut = try Self.code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let start = try #require(signOut.range(of: "func armReturnToFreshInstallAfterWelcomeFreshStart() -> Bool {"),
                                 "Falta el cierre que devuelve a recién instalado tras «Empezar de cero» en la nube.")
        let body = signOut[start.upperBound...]
        let end = try #require(body.range(of: "\n    }\n"))
        let method = body[..<end.lowerBound]
        // La mitad síncrona arma y pide reabrir sin un solo `await`: un cierre de la app tras bajar el Welcome lo termina el
        // arranque, en vez de reabrir el onboarding sobre la nube (review adversarial).
        #expect(method.contains("StorageModePersistence.armSignOutWipe()"))
        #expect(method.contains("phase = .awaitingRelaunch"))
        #expect(!method.contains("await "), "El borrado se arma antes de cualquier espera.")
        let finish = try #require(signOut.range(of: "func finishReturnToFreshInstallAfterWelcomeFreshStart() async -> Bool {"))
        let finishBody = signOut[finish.upperBound...]
        let finishEnd = try #require(finishBody.range(of: "\n    }\n"))
        let finishMethod = finishBody[..<finishEnd.lowerBound]
        #expect(finishMethod.contains("guard phase == .awaitingRelaunch, StorageModePersistence.isSignOutWipeArmed()"))
        #expect(finishMethod.contains("PersonalContainerSwap.attemptSignOutSwap()"))
        #expect(method.contains("WelcomePendingDestinationStore.clear()"), "Recién instalado es sin destino pendiente.")
        #expect(!method.contains("markSignOutWipeIncludesGroups"),
                "El relevo ya purgó los grupos; marcar el store se llevaría los que el aviso tardío conservó.")
        #expect(method.contains("guard phase == .idle"), "Con un cierre en curso no se pisa nada.")
    }

    /// Las tres salidas del Welcome que abrían el onboarding privado tras «Empezar de cero» consultan la regla.
    @Test func welcomeFreshStartExits_returnTheCloudPhoneToFreshInstall() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        let helper = try #require(content.range(of: "private func returnCloudPhoneToFreshInstallIfNeeded() -> Bool {"))
        let helperBody = content[helper.upperBound...].prefix(1500)
        #expect(helperBody.contains("AdoptOverCloudGuardLogic.freshStartReturnsToFreshInstall("))
        let armed = try #require(helperBody.range(of:
            "guard CloudSessionSignOut.shared.armReturnToFreshInstallAfterWelcomeFreshStart() else { return false }"),
            "El Welcome se cierra sin haber armado antes el borrado, o con el coordinador ocupado.")
        let closes = try #require(helperBody.range(of: "showWelcomeFlow = false"),
                                  "El cover del Welcome tiene que irse para que se presente el del cierre.")
        #expect(armed.upperBound <= closes.lowerBound)
        #expect(helperBody.contains("CloudSessionSignOut.shared.finishReturnToFreshInstallAfterWelcomeFreshStart()"))

        // 1) «Soy nuevo» sin datos: antes de abrir el onboarding.
        let fresh = try #require(content.range(of: "private func startFreshPrivateOnboarding() {"))
        let freshBody = content[fresh.upperBound...]
        let guardCall = try #require(freshBody.range(of: "guard !returnCloudPhoneToFreshInstallIfNeeded() else { return }"),
                                     "«Empezar de cero» sin datos abre el onboarding sin mirar el modo.")
        let opens = try #require(freshBody.range(of: "showOnboarding = true"))
        #expect(guardCall.upperBound <= opens.lowerBound)

        // 2) El relanzamiento del espejo con destino `.privateOnboarding`: antes de encolarlo.
        let relaunch = try #require(content.range(of:
            "if destination == .privateOnboarding, returnCloudPhoneToFreshInstallIfNeeded() { return }"),
            "El relanzamiento hacia el onboarding privado se encola sin mirar el modo.")
        let enqueue = try #require(content[relaunch.upperBound...].range(of: "WelcomePendingDestinationStore.set(destination)"))
        #expect(relaunch.upperBound <= enqueue.lowerBound)

        // 3) El alert de datos existentes, tras borrar.
        let alerts = try Self.code("Yala/App/Views/Shared/ShellDataAlertsModifier.swift")
        let wipe = try #require(alerts.range(of: "private func performFreshStartWipe() {"))
        let wipeBody = alerts[wipe.upperBound...]
        let rule = try #require(wipeBody.range(of: "AdoptOverCloudGuardLogic.freshStartReturnsToFreshInstall("),
                                "El alert de «Empezar de cero» abre el onboarding sin mirar el modo.")
        let swap = try #require(wipeBody.range(of: "CloudSessionSignOut.shared.armReturnToFreshInstallAfterWelcomeFreshStart()"))
        let alertOpens = try #require(wipeBody.range(of: "showOnboarding = true"))
        #expect(rule.upperBound <= swap.lowerBound && swap.upperBound <= alertOpens.lowerBound)
    }

    /// El cinturón: la entrada a una cuenta pasa por la regla ANTES del guard cross-cuenta, y negarse es el bloqueo con
    /// salida al elector, nunca el adopt.
    @Test func welcomeSignIn_refusesTheAdoptOverTheCloud_beforeStartingIt() throws {
        let view = try Self.code("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let rule = try #require(view.range(of: "let refusesAdoptOverCloud = AdoptOverCloudGuardLogic.refusesAdopt("),
                                "La entrada a la cuenta adopta sin mirar si el teléfono ya está en la nube.")
        let decision = try #require(view.range(of:
            "let decision: CrossAccountEntryGuardLogic.Decision = refusesAdoptOverCloud ? .blockedForeignData"))
        let adopt = try #require(view[decision.upperBound...].range(of: "startAdoptWithExistingSession("))
        #expect(rule.upperBound <= decision.lowerBound && decision.upperBound <= adopt.lowerBound)
        #expect(view.contains("MetricsService.canary(.adoptOverCloudRefused)"), "Falta el canario para medirlo en la flota.")
    }
}
