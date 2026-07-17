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
}
