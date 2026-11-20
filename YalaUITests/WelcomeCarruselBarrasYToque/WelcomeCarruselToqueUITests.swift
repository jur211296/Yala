//
//  WelcomeCarruselToqueUITests.swift
//  YalaUITests
//
//  La vitrina del Welcome como historias (encargo del 19-nov): tocar la mitad derecha de la caja pasa a la siguiente
//  función, la izquierda vuelve a la anterior, y el botón de pausa pausa sin cambiar de función.
//

import XCTest

final class WelcomeCarruselToqueUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func waitForPosition(_ current: XCUIElement, _ position: String, _ message: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", position)
        let found = XCTNSPredicateExpectation(predicate: predicate, object: current)
        XCTAssertEqual(XCTWaiter().wait(for: [found], timeout: 5), .completed,
                       "\(message) Dice: «\(current.label)».", file: file, line: line)
    }

    func test_tappingTheHalves_movesForwardAndBack_andPauseDoesNotMove() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil)
        let stage = app.descendants(matching: .any)["welcome_showcase_stage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 60), "No apareció la vitrina de la bienvenida.")
        let current = app.descendants(matching: .any)["welcome_showcase_current"]
        let pause = app.buttons["welcome_showcase_pause"]

        // Quieta antes de tocar: si rotara sola, el cambio de función no diría nada del toque.
        pause.tap()
        app.buttons["welcome_showcase_segment_receipt"].tap()
        waitForPosition(current, "1 de 6", "El segmento no llevó a la primera función.")

        // La pausa es solo su botón: tocarlo no cambia de función.
        pause.tap()
        pause.tap()
        waitForPosition(current, "1 de 6", "Tocar la pausa cambió de función.")

        // Mitad derecha (sobre la demo, lejos de las barras y del botón): siguiente.
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.6)).tap()
        waitForPosition(current, "2 de 6", "Tocar la mitad derecha no pasó a la siguiente.")
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.6)).tap()
        waitForPosition(current, "3 de 6", "Un segundo toque a la derecha no avanzó otra vez.")

        // Mitad izquierda: anterior.
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.6)).tap()
        waitForPosition(current, "2 de 6", "Tocar la mitad izquierda no volvió a la anterior.")
    }
}
