//
//  WelcomeInviteOpeningUITests.swift
//  YalaUITests
//
//  Card z81w del QA guiado del TF19 (2026-10-20): al abrir un enlace de invitación en una instalación nueva, la
//  bienvenida normal salía 10-15 s, interactiva, antes de «Conecta tu cuenta». Ahora sale «Abriendo tu invitación…» sin
//  botones, y si la invitación no llega a relevarla, vuelve la bienvenida (techo de 20 s).
//
//  `-uitest-invite-opening` enciende la apertura en el arranque sin enlace ni red: lo que la apaga es el techo, como en
//  producción cuando nada releva a la bienvenida.
//

import XCTest

final class WelcomeInviteOpeningUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// La pantalla sale en lugar de la bienvenida, sin nada que tocar, y al vencer el techo vuelve la bienvenida.
    func test_openingInvite_hidesTheWelcome_untilTheCeilingReturnsIt() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, inviteOpening: true)

        // Cualquier tipo: el bloque combinado sale como elemento genérico (medido con `axe describe-ui`).
        let opening = app.descendants(matching: .any)["welcome_invite_opening"]
        XCTAssertTrue(opening.waitForExistence(timeout: 60), "No salió «Abriendo tu invitación…».")
        XCTAssertFalse(app.buttons["welcome_hero_cta"].exists,
                       "La bienvenida se podía tocar (o leer) mientras se abría la invitación.")
        XCTAssertEqual(app.buttons.count, 0, "Mientras se abre la invitación no hay ningún botón en pantalla.")

        // No es un camino muerto: pasado el techo vuelve la bienvenida.
        XCTAssertTrue(app.buttons["welcome_hero_cta"].waitForExistence(timeout: 45),
                      "Vencido el techo, la bienvenida no volvió: la pantalla sin botones se quedaba para siempre.")
        XCTAssertFalse(app.descendants(matching: .any)["welcome_invite_opening"].exists)
    }

    /// Control: sin enlace, la bienvenida de siempre desde el primer instante.
    func test_withoutAnInvite_theWelcomeIsTheUsualOne() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil)

        XCTAssertTrue(app.buttons["welcome_hero_cta"].waitForExistence(timeout: 60))
        XCTAssertFalse(app.descendants(matching: .any)["welcome_invite_opening"].exists)
    }
}
