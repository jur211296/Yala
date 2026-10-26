//
//  WelcomeAccountExistsUITests.swift
//  YalaUITests
//
//  Lote 12.7 · card `tablero-los-xcuitest-no-pueden-fingir-que-contes-er5c` (ticket
//  `no-test-seam-for-account-exists-blocks-xcuitest-of-identity`). Las celdas del bloque [I] de «Ya tengo una cuenta»
//  recorridas de punta a punta: hasta el 2026-10-25 ningún XCUITest pasaba del sign-in, porque no había forma de fingir
//  qué contesta `GET /account/exists`. El seam `-uitest-fake-account-exists <new|complete|groupsOnly|offline>` finge el
//  inicio de sesión (sin SIWA, sin token, sin red) y la respuesta; qué pantalla sale lo decide la tabla de siempre.
//
//  Ruta: Hero → «Ya tengo una cuenta» → Apple → consentimiento → «Aceptar».
//

import XCTest

final class WelcomeAccountExistsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ answer: String, attest: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            fakeAttestSupport: attest,
            extraArguments: ["-uitest-cloud-chooser", "-uitest-fake-account-exists", answer]
        )
        return app
    }

    /// Hasta el «Aceptar» del consentimiento, que es lo que arranca el inicio de sesión.
    private func signInFromExistingAccount(_ app: XCUIApplication) {
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()
        let restoreBranch = app.buttons["welcome_chooser_restore"]
        XCTAssertTrue(restoreBranch.waitForExistence(timeout: 10), "No apareció «Ya tengo una cuenta».")
        restoreBranch.tap()
        let appleCard = app.buttons["welcome_existing_cloud"]
        XCTAssertTrue(appleCard.waitForExistence(timeout: 10), "No apareció la card de Apple.")
        appleCard.tap()
        let accept = app.buttons["storage_consent_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No se abrió el consentimiento.")
        accept.tap()
    }

    /// Cuenta inexistente, con la puerta del alta abierta: «No encontramos una cuenta» con su botón al alta.
    func test_existingAccount_noAccount_offersTheSignUp() {
        let app = launch("new", attest: true)
        signInFromExistingAccount(app)
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_not_found"].waitForExistence(timeout: 20),
                      "No salió «No encontramos una cuenta».")
        XCTAssertTrue(app.buttons["welcome_cloud_not_found_cta"].exists, "Falta el botón que lleva al alta.")
        XCTAssertFalse(app.buttons["welcome_cloud_not_found_back"].exists)
    }

    /// Control de la condición: la misma respuesta sin App Attest no ofrece el alta, ofrece «Volver».
    func test_existingAccount_noAccount_withoutAppAttest_offersOnlyBack() {
        let app = launch("new")
        signInFromExistingAccount(app)
        XCTAssertTrue(app.buttons["welcome_cloud_not_found_back"].waitForExistence(timeout: 20),
                      "Sin App Attest, «No encontramos una cuenta» tenía que ofrecer «Volver».")
        XCTAssertFalse(app.buttons["welcome_cloud_not_found_cta"].exists)
    }

    /// Cuenta solo de grupos: no se adopta. Ni la barra de «Conectando con tu cuenta…» ni «No encontramos».
    func test_existingAccount_groupsOnly_doesNotAdopt() {
        let app = launch("groupsOnly", attest: true)
        signInFromExistingAccount(app)
        // Medido el 2026-10-25: la cadena de Grupos empieza por su consentimiento («Grupos en la nube»), que el
        // consentimiento de la nube no cubre.
        XCTAssertTrue(app.buttons["groups_onboarding_consent_accept"].waitForExistence(timeout: 20),
                      "Una cuenta solo de grupos no siguió por la cadena de Grupos.")
        XCTAssertFalse(app.descendants(matching: .any)["welcome_cloud_adopting"].exists, "Adoptó una cuenta solo de grupos.")
        XCTAssertFalse(app.descendants(matching: .any)["welcome_cloud_not_found"].exists)
    }

    /// La puerta de Grupos de un teléfono PRIVADO con una cuenta completa: el bloqueo («esta cuenta ya es de Yala
    /// completo»), no la cadena de Grupos. Que el bloqueo no escriba nada lo fija el `guard` del callback de éxito
    /// (`GroupsBackendInviteModifier`); aquí se fija que se llega a él.
    func test_groupsGate_privatePhone_completeAccount_isBlocked() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "groups",
                            extraArguments: ["-groups.hadSessionEver", "YES", "-hasShownGroupsOnboarding", "YES",
                                             "-uitest-fake-account-exists", "complete"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        let cta = app.buttons["groups_empty_state_signin"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 20), "No salió «Tus grupos están en tu cuenta».")
        cta.tap()
        let google = app.buttons["groups_signin_button_google"]
        XCTAssertTrue(google.waitForExistence(timeout: 10), "No se abrió «Conecta tu cuenta».")
        google.tap()
        XCTAssertTrue(app.descendants(matching: .any)["groups_account_complete_block"].waitForExistence(timeout: 20),
                      "Una cuenta completa entró por la puerta de Grupos de un teléfono privado.")
    }

    /// Sin red: el error con «Reintentar», nunca «No encontramos una cuenta».
    func test_existingAccount_offline_offersRetry() {
        let app = launch("offline", attest: true)
        signInFromExistingAccount(app)
        XCTAssertTrue(app.buttons["welcome_cloud_retry"].waitForExistence(timeout: 20), "Sin red no salió «Reintentar».")
        XCTAssertFalse(app.descendants(matching: .any)["welcome_cloud_not_found"].exists,
                       "Un fallo de red se leyó como «no tienes cuenta».")
    }
}
