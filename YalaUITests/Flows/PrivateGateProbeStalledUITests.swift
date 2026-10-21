//
//  PrivateGateProbeStalledUITests.swift
//  YalaUITests
//
//  Card blqa del QA guiado del TF19 (2026-10-20): con un iCloud con mucho historial, la revisión de «Tu cuenta en tu
//  iCloud privado» se pasaba de su plazo y la puerta decía «No pudimos conectarnos a iCloud · Puede ser la conexión». El
//  plazo pasó a ser sin avance y, cuando aun así vence, el texto no culpa a la conexión.
//
//  El simulador no tiene CloudKit: `-uitest-private-gate-probe-stalled` finge la respuesta de la revisión; lo que se
//  pinta lo decide la tabla de producción.
//

import XCTest

final class PrivateGateProbeStalledUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openPrivateGate(_ app: XCUIApplication) {
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()
        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card «Es mi primera vez».")
        newBranch.tap()
        let privateCard = app.buttons["welcome_new_private"]
        if privateCard.waitForExistence(timeout: 3) { privateCard.tap() }
    }

    /// El plazo sin avance vencido: su pantalla propia, con «Reintentar» y la salida de siempre.
    func test_stalledCheck_showsItsOwnNotice_withRetryAndTheUsualExit() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, privateGateProbeStalled: true)
        openPrivateGate(app)

        let retry = app.buttons["welcome_private_icloud_stalled_cta"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15),
                      "Con la revisión sin avanzar no salió su aviso propio (el que no culpa a la conexión).")
        XCTAssertTrue(app.buttons["welcome_private_icloud_stalled_secondary"].exists, "Falta «Seguir así».")
        XCTAssertFalse(app.buttons["welcome_private_icloud_error_cta"].exists,
                       "Salió el aviso de «Puede ser la conexión» para un plazo vencido.")

        // «Reintentar» vuelve a preguntar: con la revisión todavía sin avanzar, la misma pantalla.
        retry.tap()
        XCTAssertTrue(app.buttons["welcome_private_icloud_stalled_cta"].waitForExistence(timeout: 15),
                      "«Reintentar» no volvió a preguntar.")
    }
}
