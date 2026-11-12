//
//  WelcomeFirstGroupCloseUITests.swift
//  YalaUITests
//
//  Card ycke (C2 del estudio del Welcome solo-grupos, 2026-10-24) · cerrar el formulario del primer grupo deja dentro.
//
//  Hasta este día, la «X» del formulario de «Crear mi primer grupo» devolvía al elector de grupos del Welcome (hallazgo H6):
//  quien aún no sabía cómo llamar al grupo, o esperaba a que un amigo lo invitara, tenía que volver a «Crear mi primer
//  grupo» y crearlo para entrar. Ahora, con su nombre escrito, cerrar completa el alta sin crear el grupo y aterriza en
//  Grupos vacío; sin su nombre, se le pregunta en una línea.
//
//  Mismo fingimiento que `WelcomeChooserUITests.testGroupsOrganizer_createCardWalksToTheGroupForm`: sesión de nube y
//  consentimiento de grupos fingidos (cero tráfico HTTP) y el educativo con su seam. El canal de grupos está siempre
//  encendido bajo `-uitest`, así que la rama «sin canal» (cerrar vuelve al elector) no se puede montar aquí.
//
//  Con el arreglo revertido los dos casos caen en la espera de `groups_empty_state`: la «X» vuelve al Welcome.
//  `YALA_CAPTURES` (vía `TEST_RUNNER_YALA_CAPTURES`) guarda las capturas del antes/después.
//

import XCTest

final class WelcomeFirstGroupCloseUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    /// Con «Tu nombre en el grupo» escrito, la «X» entra en Grupos sin crear el grupo.
    func test_closingTheFirstGroupForm_withYourName_landsInGroupsWithoutAGroup() {
        let app = walkToTheFirstGroupForm()

        let yourName = app.textFields["group_form_your_name_input"]
        yourName.tap()
        yourName.typeText("Ana")
        // El nombre del grupo también escrito: cerrar no lo crea, y la pestaña tiene que llegar vacía.
        let groupName = app.textFields["group_form_name_input"]
        groupName.tap()
        groupName.typeText("Depa Miraflores")
        capture(app, "1-formulario-con-nombre")

        tapClose(app)

        assertLandedInEmptyGroups(app, capturing: "2-cerrar-con-nombre")
    }

    /// Sin «Tu nombre en el grupo», la «X» pregunta en una línea. «Cancelar» deja el formulario; con el nombre, se entra.
    func test_closingTheFirstGroupForm_withoutYourName_asksForItInOneLine() {
        let app = walkToTheFirstGroupForm()

        tapClose(app)

        let alert = app.alerts.firstMatch
        let ask = alert.textFields.firstMatch
        let asked = ask.waitForExistence(timeout: 10)
        capture(app, "3-cerrar-sin-nombre-pregunta")
        XCTAssertTrue(asked,
                      "Sin tu nombre, cerrar tiene que preguntarlo en una línea, no echarte al Welcome.")
        let continueButton = alert.buttons["group_form_close_name_continue"].firstMatch
        XCTAssertTrue(continueButton.exists, "La pregunta no trae «Continuar».")
        XCTAssertFalse(continueButton.isEnabled, "«Continuar» tiene que estar apagado sin nombre.")

        // «Cancelar» devuelve al formulario tal cual.
        alert.buttons.element(boundBy: 0).firstMatch.tap()
        let cancelled = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: alert)
        wait(for: [cancelled], timeout: 10)
        XCTAssertTrue(app.textFields["group_form_your_name_input"].exists, "Cancelar la pregunta no dejó el formulario.")
        XCTAssertFalse(app.buttons["welcome_groups_create"].exists, "Cancelar la pregunta volvió al Welcome.")

        // Otra vez, ahora con el nombre en la pregunta.
        tapClose(app)
        XCTAssertTrue(ask.waitForExistence(timeout: 10), "La pregunta no volvió a salir.")
        ask.typeText("Ana")
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: continueButton)
        wait(for: [enabled], timeout: 5)
        continueButton.tap()

        assertLandedInEmptyGroups(app, capturing: "4-cerrar-sin-nombre-entra")
    }

    // MARK: - Recorrido

    private func walkToTheFirstGroupForm() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            cloudSession: true,
            groupsConsent: true,
            groupsEducativo: true
        )

        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()
        let inviteBranch = app.buttons["welcome_chooser_invite"]
        XCTAssertTrue(inviteBranch.waitForExistence(timeout: 10), "No apareció la fila de grupos del elector.")
        inviteBranch.tap()
        let createCard = app.buttons["welcome_groups_create"]
        XCTAssertTrue(createCard.waitForExistence(timeout: 10), "No apareció «Crear mi primer grupo».")
        createCard.tap()
        let educationalCTA = app.buttons["groups_onboarding_cta"]
        XCTAssertTrue(educationalCTA.waitForExistence(timeout: 20), "La rama no llegó al educativo.")
        educationalCTA.tap()
        XCTAssertTrue(app.textFields["group_form_your_name_input"].waitForExistence(timeout: 20),
                      "Tras el educativo, la rama no llegó al formulario del primer grupo.")
        return app
    }

    private func tapClose(_ app: XCUIApplication) {
        let close = app.buttons["group_form_close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "No apareció la «X» del formulario.")
        close.tap()
    }

    /// Captura ANTES de afirmar: con el arreglo revertido, esa captura es el «antes» (el Welcome tras cerrar).
    private func assertLandedInEmptyGroups(_ app: XCUIApplication, capturing name: String) {
        let landed = app.descendants(matching: .any)["groups_empty_state"].waitForExistence(timeout: 20)
        capture(app, name)
        XCTAssertTrue(landed, "Cerrar el formulario del primer grupo no dejó dentro, en Grupos vacío.")
        XCTAssertFalse(app.buttons["welcome_groups_create"].exists, "Cerrar el formulario volvió al Welcome.")
        XCTAssertFalse(app.buttons["welcome_hero_cta"].exists, "Cerrar el formulario volvió al Welcome.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            #if DEBUG
            print("WelcomeFirstGroupCloseUITests: Error: \(error)")
            #endif
        }
    }
}
