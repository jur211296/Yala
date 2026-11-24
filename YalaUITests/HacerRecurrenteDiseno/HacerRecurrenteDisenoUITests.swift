//
//  HacerRecurrenteDisenoUITests.swift
//  YalaUITests
//
//  Pedido de Jürgen del 2026-11-23: la hoja «Hacer recurrente» de Nuevo registro con fondo sólido (no deja ver los
//  botones del formulario de atrás), las frecuencias en una tarjeta y un resumen de lo que se programa. Cada caso abre la
//  hoja sobre «Nuevo gasto» con descripción, monto y categoría, y adjunta su captura (`keepAlways`), en oscuro y en claro.
//

import XCTest

final class HacerRecurrenteDisenoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// `light`: el tema Claro (`-userTheme 1`); sin él, el de siempre (oscuro).
    private func launch(light: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var extra = ["-uitest-transactions-saved", "5"]
        if light { extra += ["-userTheme", "1"] }
        app.launchForUITest(seed: "una-cuenta", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Nuevo gasto con «Gimnasio», 40 y la primera categoría, y «Hacer recurrente» abierto desde «···».
    private func openQuickSheet(_ app: XCUIApplication) {
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        let note = app.textFields["new_transaction_note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "No se abrió el formulario.")
        note.tap()
        note.typeText("Gimnasio")
        let question = app.descendants(matching: .any)["new_transaction_amount_question"].firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Falta la pregunta del monto.")
        question.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado no se cerró.")
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("40")
        XCTAssertTrue((amount.value as? String ?? "").contains("40"), "El importe no quedó escrito: el toque se perdió.")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.tapNewTransactionMoreAction("new_transaction_recurring_action")
        XCTAssertTrue(app.buttons["recurring_quick_monthly"].waitForExistence(timeout: 5), "No se abrió la hoja.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// La hoja trae el resumen del registro (descripción y monto) y las tres frecuencias con «Más opciones…».
    private func expectRedesign(_ app: XCUIApplication) {
        let summary = app.descendants(matching: .any)["recurring_quick_summary"].firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Falta el resumen de lo que se programa.")
        let label = summary.label
        XCTAssertTrue(label.contains("Gimnasio"), "El resumen no nombra la descripción: \(label)")
        XCTAssertTrue(label.contains("40"), "El resumen no enseña el monto: \(label)")
        for id in ["recurring_quick_weekly", "recurring_quick_monthly", "recurring_quick_yearly", "recurring_quick_more"] {
            XCTAssertTrue(app.buttons[id].exists, "Falta \(id).")
        }
    }

    func test_hojaOscura_traeResumen_yFrecuencias() {
        let app = launch(light: false)
        openQuickSheet(app)
        capture(app, "hacer-recurrente-oscuro")
        expectRedesign(app)
    }

    func test_hojaClara_traeResumen_yFrecuencias() {
        let app = launch(light: true)
        openQuickSheet(app)
        capture(app, "hacer-recurrente-claro")
        expectRedesign(app)
    }
}
