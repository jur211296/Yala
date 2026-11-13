//
//  WelcomeVisualAdjustmentsUITests.swift
//  YalaUITests
//
//  Ajustes de la bienvenida 2.3 del 13-nov (ticket `welcome-2-3-visual-adjustments`): los tres accesos miden lo mismo,
//  «Dividir gastos con amigos» está debajo de ellos sin esperar a una función de grupos, la vitrina ya no lleva
//  «EJEMPLO» y la minidescripción ocupa una sola línea.
//

import XCTest

final class WelcomeVisualAdjustmentsUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchWelcome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            extraArguments: [XCUIApplication.welcomeProvidersArgument])
        XCTAssertTrue(app.descendants(matching: .any)["welcome_showcase_title"].waitForExistence(timeout: 60),
                      "No apareció la vitrina de la bienvenida.")
        return app
    }

    func test_threeAccesses_shareTheSameSize_andTheGroupsDoorSitsBelowThem() {
        let app = launchWelcome()
        let google = app.buttons["welcome_access_google"]
        let apple = app.buttons["welcome_access_apple"]
        let iCloud = app.buttons["welcome_access_icloud"]
        XCTAssertTrue(google.exists && apple.exists && iCloud.exists, "Faltan accesos.")

        // Mismo ancho y la misma x en los tres; Google y Apple del mismo alto, e iCloud privado algo más alto porque
        // lleva su línea debajo (Jürgen, 13-nov).
        for other in [apple, iCloud] {
            XCTAssertEqual(other.frame.width, google.frame.width, accuracy: 0.5)
            XCTAssertEqual(other.frame.minX, google.frame.minX, accuracy: 0.5)
        }
        XCTAssertEqual(apple.frame.height, google.frame.height, accuracy: 0.5)
        XCTAssertGreaterThan(iCloud.frame.height, google.frame.height + 5, "iCloud privado perdió su línea de debajo.")

        // Pausada en la primera función (foto, que no es de grupos), el atajo a Grupos ya está a la vista y debajo.
        app.buttons["welcome_showcase_pause"].tap()
        let door = app.buttons["welcome_showcase_groups_door"]
        XCTAssertTrue(door.waitForExistence(timeout: 5), "«Dividir gastos con amigos» depende otra vez de la vitrina.")
        XCTAssertGreaterThan(door.frame.minY, iCloud.frame.maxY, "«Dividir gastos con amigos» no está debajo de los accesos.")
    }

    func test_stage_hasNoExampleTag_andTheCaptionIsOneLine() {
        let app = launchWelcome()
        app.buttons["welcome_showcase_pause"].tap()
        XCTAssertFalse(app.staticTexts["EJEMPLO"].exists, "Volvió la etiqueta «EJEMPLO».")
        XCTAssertFalse(app.staticTexts["Ejemplo"].exists, "Volvió la etiqueta «EJEMPLO».")

        let caption = app.staticTexts["welcome_showcase_caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        let title = app.descendants(matching: .any)["welcome_showcase_current"]
        // Una línea de `subheadline` mide ~20 pt; dos, ~40.
        XCTAssertLessThan(caption.frame.height, 30, "La minidescripción ocupa más de una línea.")
        XCTAssertTrue(title.exists)
    }
}
