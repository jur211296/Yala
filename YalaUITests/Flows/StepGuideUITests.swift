//
//  StepGuideUITests.swift
//  YalaUITests
//
//  Las guías por pasos con la forma de la referencia del 2026-09-15 (`YalaStepGuide`). Fija el antes → después:
//  «Registrar con Apple Pay» ya no es el carrusel de vídeo de los tutoriales, y la guía de Face ID ya no es una lista
//  fija. En las dos: progreso doble arriba, un solo paso accionable, garantía y dos salidas al pie.
//
//  El idioma lo fija `launchForUITest` (es_PE), así que el texto del progreso se compara en español.
//  Abrir Atajos (paso 1 de Apple Pay) saca de la app y no se toca aquí: el avance se prueba con «Hecho» en Face ID.
//

import XCTest

final class StepGuideUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Apple Pay

    func test_applePayTutorial_opensAsStepGuide() {
        let app = launchAndOpenProfile()
        tapRow("profile_help_tutorials", in: app)
        tapRow("tutorial_row_applePay", in: app)

        XCTAssertTrue(
            app.descendants(matching: .any)["applepay_guide_root"].waitForExistence(timeout: 5),
            "«Registrar con Apple Pay» no abrió la guía por pasos (seguía el carrusel)."
        )
        assertProgress("Paso 1 de 4", in: app)
        assertSingleActiveStep(0, of: 4, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["step_guide_guarantee"].exists, "Falta la línea de garantía.")
        XCTAssertTrue(app.descendants(matching: .any)["step_guide_preview"].exists, "Falta «Lo que vas a ver».")
        XCTAssertTrue(app.buttons["step_guide_stuck"].exists, "Falta la salida «Me atasqué».")
        XCTAssertTrue(app.buttons["primary_button"].exists, "Falta la salida de éxito.")
    }

    // MARK: - Face ID

    func test_faceIDGuide_doneAdvancesTheOnlyActiveStep() {
        let app = launchAndOpenProfile()
        tapRow("profile_security_faceid", in: app)

        XCTAssertTrue(
            app.descendants(matching: .any)["faceid_guide_root"].waitForExistence(timeout: 5),
            "No se abrió la guía de Face ID."
        )
        assertProgress("Paso 1 de 3", in: app)
        assertSingleActiveStep(0, of: 3, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["step_guide_preview"].exists, "Falta «Lo que vas a ver».")

        for next in 1...2 {
            app.buttons["step_guide_action"].tap()
            assertProgress("Paso \(next + 1) de 3", in: app)
            assertSingleActiveStep(next, of: 3, in: app)
        }

        // Con el último hecho no queda paso accionable y el progreso se queda en «3 de 3».
        app.buttons["step_guide_action"].tap()
        assertProgress("Paso 3 de 3", in: app)
        XCTAssertFalse(app.buttons["step_guide_action"].exists, "Quedó un botón de paso con todos hechos.")

        // «Listo» cierra la guía y vuelve a Ajustes.
        app.buttons["primary_button"].tap()
        XCTAssertTrue(
            app.buttons["profile_security_faceid"].waitForExistence(timeout: 5),
            "«Listo» no volvió a Ajustes."
        )
    }

    // MARK: - Ayudas

    private func launchAndOpenProfile() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "La app no señaló uitest_ready.")
        let profile = app.buttons["profile_avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20), "No apareció profile_avatar.")
        profile.tap()
        // Espera a que Ajustes esté en pantalla antes de bajar: un deslizamiento sobre el Panel, con la hoja todavía
        // entrando, no la recorre.
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")
        return app
    }

    /// Baja hasta la fila y la toca. Las listas montan solo las celdas visibles.
    private func tapRow(_ identifier: String, in app: XCUIApplication) {
        let row = app.buttons[identifier]
        var attempts = 0
        while !(row.exists && row.isHittable) && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció \(identifier).")
        row.tap()
    }

    private func assertProgress(_ expected: String, in app: XCUIApplication) {
        let progress = app.descendants(matching: .any)["step_guide_progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "Falta el progreso de arriba.")
        let predicate = NSPredicate(format: "label CONTAINS %@", expected)
        let matched = expectation(for: predicate, evaluatedWith: progress)
        XCTAssertEqual(XCTWaiter.wait(for: [matched], timeout: 5), .completed,
                       "El progreso dice «\(progress.label)», no «\(expected)».")
    }

    /// Un solo botón dentro de la lista, y el estado de cada paso coherente con él.
    private func assertSingleActiveStep(_ active: Int, of total: Int, in app: XCUIApplication) {
        XCTAssertEqual(app.buttons.matching(identifier: "step_guide_action").count, 1,
                       "Debe haber un solo paso accionable.")
        for index in 0..<total {
            let step = app.staticTexts["step_guide_step_\(index)"]
            XCTAssertTrue(step.waitForExistence(timeout: 5), "Falta el paso \(index + 1).")
            let expected = index < active ? "Hecho" : (index == active ? "Paso actual" : "Pendiente")
            XCTAssertEqual(step.value as? String, expected, "Paso \(index + 1) en estado inesperado.")
        }
    }
}
