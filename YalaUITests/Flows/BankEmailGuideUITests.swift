//
//  BankEmailGuideUITests.swift
//  YalaUITests
//
//  «Correo del banco» (2.3): Ajustes enseña la dirección `auto+…@yalainbox.com` y el cupo de prueba, y cada correo tiene su
//  guía por pasos. El paso de Gmail que pide el código lo enseña en cuanto llega.
//
//  Sin servidor ni nube: `-uitest-bank-email` saca la fila y contesta con una dirección fija. Qué decide si la fila sale
//  (nube + sesión, fuera de solo-grupos) lo prueban los unit tests de `BankEmailEntryLogic`, sin el seam.
//  El paso «Abrir Gmail» saca de la app y no se toca: para llegar al del código, la guía arranca con su avance guardado
//  (`-stepGuide.progress.bankEmailGmail 2`, que el dominio de argumentos impone sobre `-uitest-reset`).
//

import XCTest

final class BankEmailGuideUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_bankEmail_showsTheAddressAndTheQuota_andTheGmailGuideStartsByCopyingIt() {
        let app = launchAndOpenBankEmail()

        let address = app.descendants(matching: .any)["bank_email_address"]
        XCTAssertTrue(address.waitForExistence(timeout: 5), "No salió la dirección de Yala.")
        XCTAssertEqual(address.label, "auto+k7m2xq9wpb@yalainbox.com")
        let quota = app.descendants(matching: .any)["bank_email_quota"]
        XCTAssertTrue(quota.exists, "Falta la línea del cupo de prueba.")
        XCTAssertTrue(quota.label.contains("2 de 5"), "El cupo no dice cuántos correos de prueba se usaron: «\(quota.label)».")

        app.buttons["bank_email_provider_gmail"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["bank_email_guide_gmail"].waitForExistence(timeout: 5),
                      "No se abrió la guía de Gmail.")
        assertProgress("Paso 1 de 5", in: app)

        // Copiar la dirección ES el paso: queda hecho y el siguiente pide abrir Gmail.
        let action = app.buttons["step_guide_action"]
        XCTAssertTrue(action.label.contains("Copiar dirección"), "El primer paso no copia la dirección: «\(action.label)».")
        action.tap()
        assertProgress("Paso 2 de 5", in: app)
        XCTAssertTrue(app.buttons["step_guide_action"].label.contains("Abrir Gmail"),
                      "El segundo paso no abre Gmail: «\(app.buttons["step_guide_action"].label)».")
    }

    func test_gmailGuide_showsTheConfirmationCode_whenItArrived() {
        let app = launchAndOpenBankEmail(extra: ["-uitest-bank-email-gmail-code", "-stepGuide.progress.bankEmailGmail", "2"])
        app.buttons["bank_email_provider_gmail"].tap()
        assertProgress("Paso 3 de 5", in: app)

        let code = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "482913765")).firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 5), "El paso de confirmación no enseña el código de Gmail.")
        XCTAssertTrue(app.buttons["step_guide_action"].label.contains("Copiar código"))
        app.buttons["step_guide_action"].tap()
        assertProgress("Paso 4 de 5", in: app)
    }

    func test_gmailGuide_withoutTheCode_offersToLookForIt() {
        let app = launchAndOpenBankEmail(extra: ["-stepGuide.progress.bankEmailGmail", "2"])
        app.buttons["bank_email_provider_gmail"].tap()
        assertProgress("Paso 3 de 5", in: app)
        XCTAssertTrue(app.buttons["step_guide_action"].label.contains("Buscar el código"),
                      "Sin código, el paso no ofrece buscarlo: «\(app.buttons["step_guide_action"].label)».")
        // Buscar sin código no da el paso por hecho.
        app.buttons["step_guide_action"].tap()
        assertProgress("Paso 3 de 5", in: app)
    }

    func test_outlookGuide_isARuleInThreeSteps() {
        let app = launchAndOpenBankEmail()
        app.buttons["bank_email_provider_outlook"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["bank_email_guide_outlook"].waitForExistence(timeout: 5))
        assertProgress("Paso 1 de 3", in: app)
    }

    // MARK: - Helpers

    private func launchAndOpenBankEmail(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-bank-email"] + extra)
        XCTAssertTrue(app.waitForUITestReady(), "La app no señaló uitest_ready.")
        let profile = app.buttons["profile_avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20), "No apareció profile_avatar.")
        profile.tap()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")
        let row = app.buttons["profile_bank_email"]
        var attempts = 0
        while !(row.exists && row.isHittable) && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció la fila «Correo del banco».")
        row.tap()
        XCTAssertTrue(app.buttons["bank_email_provider_gmail"].waitForExistence(timeout: 10), "No se abrió «Correo del banco».")
        return app
    }

    private func assertProgress(_ expected: String, in app: XCUIApplication) {
        let progress = app.descendants(matching: .any)["step_guide_progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "Falta el progreso de arriba.")
        let predicate = NSPredicate(format: "label CONTAINS %@", expected)
        let matched = expectation(for: predicate, evaluatedWith: progress)
        XCTAssertEqual(XCTWaiter().wait(for: [matched], timeout: 5), .completed,
                       "El progreso no dice «\(expected)»: «\(progress.label)».")
    }
}
