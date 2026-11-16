//
//  PanelAmountsVisibilityUITests.swift
//  YalaUITests
//
//  El ojo junto a la cifra grande del Panel (card «Ojo para ocultar montos en el Panel», 2026-11-06): oculta las cifras
//  del Panel, se queda así al volver a abrir la app y las devuelve con otro toque. La máscara y la preferencia las fija
//  `AmountPrivacyTests`; aquí, que el botón las enciende de verdad sobre la pantalla.
//
//  Se mira por las etiquetas de VoiceOver (`Monto oculto`), que dicen lo mismo que la pantalla: con el monto a la vista
//  la píldora dice «Salió S/ …» y con el monto oculto «Salió Monto oculto».
//
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class PanelAmountsVisibilityUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private let hiddenLabel = "Monto oculto"

    func test_eye_hidesThePanelAmounts_keepsThemHiddenAfterRelaunch_andShowsThemAgain() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let eye = app.buttons["panel_hero_amounts_visibility"]
        let expensePill = app.buttons["panel_hero_expense_pill"]
        XCTAssertTrue(eye.waitForExistence(timeout: 10), "No apareció el ojo junto a la cifra del Panel.")
        XCTAssertTrue(expensePill.waitForExistence(timeout: 10), "No apareció la píldora de gastos del hero.")

        // Control: con el estado limpio los montos se ven. Sin esto, el caso pasaría también con el Panel siempre oculto.
        XCTAssertEqual(eye.label, "Ocultar montos", "El ojo no ofrece ocultar con los montos a la vista.")
        XCTAssertFalse(expensePill.label.contains(hiddenLabel), "Los montos salieron ocultos sin tocar el ojo.")

        eye.tap()
        XCTAssertTrue(
            expensePill.label.contains(hiddenLabel) || waitForLabel(of: expensePill, containing: hiddenLabel),
            "Tras tocar el ojo la píldora sigue diciendo su monto: «\(expensePill.label)»."
        )
        XCTAssertEqual(eye.label, "Mostrar montos", "El ojo no ofrece volver a mostrar los montos.")

        // Volver a abrir la app SIN reset: la preferencia se queda.
        app.terminate()
        app.launchForUITest(reset: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")
        let eyeAfter = app.buttons["panel_hero_amounts_visibility"]
        let pillAfter = app.buttons["panel_hero_expense_pill"]
        XCTAssertTrue(pillAfter.waitForExistence(timeout: 10), "No apareció la píldora tras relanzar.")
        XCTAssertTrue(
            pillAfter.label.contains(hiddenLabel),
            "Al volver a abrir la app los montos salieron a la vista: «\(pillAfter.label)»."
        )

        eyeAfter.tap()
        XCTAssertTrue(
            waitForLabel(of: pillAfter, notContaining: hiddenLabel),
            "Tras volver a tocar el ojo los montos siguen ocultos."
        )
        XCTAssertEqual(eyeAfter.label, "Ocultar montos")
    }

    // MARK: - Esperas por etiqueta

    private func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    private func waitForLabel(of element: XCUIElement, notContaining text: String) -> Bool {
        let predicate = NSPredicate(format: "NOT (label CONTAINS %@)", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }
}
