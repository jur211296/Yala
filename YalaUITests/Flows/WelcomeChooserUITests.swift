//
//  WelcomeChooserUITests.swift
//  YalaUITests
//
//  Chooser del Welcome de 2 niveles con las cards de sign-in cloud (Google Sign-In sesión 2).
//  Opt-in EXPLÍCITO `-uitest-cloud-chooser`: destapa las cards Apple/Google bajo uitest SOLO
//  para este test (sin él, uitest conserva el bypass a restore — byte-idéntico, verificado
//  a mano en sim). NAVEGACIÓN determinista pura: jamás se tapea el botón de sign-in real
//  (nada de red/SIWA/sheets de Google).
//

import XCTest

final class WelcomeChooserUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExistingChooser_withCloudConfigured_showsThreeCards_andGoogleIntro() throws {
        let app = XCUIApplication()
        // Sin skipOnboarding (el flow Welcome ES el sujeto) y sin seed (no hace falta data).
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            extraArguments: ["-uitest-cloud-chooser"]
        )
        // NOTA: `uitest_ready` vive en el root de ContentView, que queda CUBIERTO por el
        // fullScreenCover del Welcome → no usar waitForUITestReady aquí (patrón
        // OnboardingFlowUITests); se espera el Hero directamente con timeout generoso.
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        // "Ya tengo una cuenta" → 2º nivel (con el opt-in hay >1 opción, no hay bypass).
        let restoreBranch = app.buttons["welcome_chooser_restore"]
        XCTAssertTrue(restoreBranch.waitForExistence(timeout: 10), "No apareció la card 'Ya tengo una cuenta'.")
        restoreBranch.tap()

        // 2º nivel: las TRES cards por identifier.
        let restoreCard = app.buttons["welcome_existing_restore"]
        XCTAssertTrue(restoreCard.waitForExistence(timeout: 10), "No apareció la card de restaurar iCloud.")
        XCTAssertTrue(app.buttons["welcome_existing_cloud"].exists, "No apareció la card de Apple.")
        let googleCard = app.buttons["welcome_existing_google"]
        XCTAssertTrue(googleCard.exists, "No apareció la card de Google.")

        // Card Google → intro con el botón Google (SIN tapearlo — nada de sign-in real).
        googleCard.tap()
        let googleButton = app.descendants(matching: .any)
            .matching(identifier: "welcome_cloud_signin_button_google").firstMatch
        XCTAssertTrue(googleButton.waitForExistence(timeout: 10), "No apareció el botón de Google en el intro.")

        // Back → de vuelta al chooser (nivel 1, por el onBack del cover).
        let backButton = app.buttons["welcome_back_button"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "No apareció el botón Volver del intro.")
        backButton.tap()
        XCTAssertTrue(app.buttons["welcome_chooser_restore"].waitForExistence(timeout: 10),
                      "El back no volvió al chooser.")
    }

    /// A4 de D-A7: el 2º nivel de "Soy nuevo". Mismo opt-in `-uitest-cloud-chooser` que el hermano
    /// —sin él, `visibleNewOptions` deja una sola card y el container hace bypass, con el recorrido
    /// byte-idéntico al de hoy (lo cubre `OnboardingFlowUITests`, que lanza sin el arg).
    func testNewChooser_withCloudConfigured_showsBothCards_andCloudCardIsStubbed() throws {
        let app = XCUIApplication()
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            extraArguments: ["-uitest-cloud-chooser"]
        )
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        // "Soy nuevo" → 2º nivel (con el opt-in hay 2 opciones, no hay bypass).
        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card 'Soy nuevo'.")
        newBranch.tap()

        let privateCard = app.buttons["welcome_new_private"]
        XCTAssertTrue(privateCard.waitForExistence(timeout: 10), "No apareció la card de privacidad total.")
        let cloudCard = app.buttons["welcome_new_cloud"]
        XCTAssertTrue(cloudCard.exists, "No apareció la card de cuenta en la nube.")

        // Stub A4 → A5: la card de nube AVISA (alert) en vez de ser un botón muerto silencioso.
        // Se comprueba por la presencia del alert, nunca por su texto localizado.
        cloudCard.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10),
                      "La card de nube no avisó de nada: es un botón muerto.")
        alert.buttons.firstMatch.tap()

        // Back → de vuelta al chooser (nivel 1).
        let backButton = app.buttons["welcome_back_button"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "No apareció el botón Volver del 2º nivel.")
        backButton.tap()
        XCTAssertTrue(app.buttons["welcome_chooser_new"].waitForExistence(timeout: 10),
                      "El back no volvió al chooser.")
    }
}
