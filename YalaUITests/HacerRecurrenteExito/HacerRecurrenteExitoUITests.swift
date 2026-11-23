//
//  HacerRecurrenteExitoUITests.swift
//  YalaUITests
//
//  Decisión de Jürgen del 2026-11-23: «Hacer recurrente» (menú «···» de Nuevo registro) enseña la pantalla de éxito al
//  guardar, como «Guardar», con «Recurrente» ya marcado y sin el aviso breve encima. Por la fila rápida («Cada mes») y
//  por el editor completo («Más opciones…»). Cada caso adjunta su captura (`keepAlways`).
//

import XCTest

final class HacerRecurrenteExitoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Una cuenta (viene puesta) y cinco registros guardados: donde antes el formulario cerraba con el aviso.
    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta", extraArguments: [
            "-uitest-transactions-saved", "5", "-uitest-undo-notice-seconds", "30",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// `note`: la descripción, que el editor completo toma como nombre del pago (sin nombre no deja guardar).
    private func openFilledForm(_ app: XCUIApplication, note: String? = nil) {
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        if let note {
            let field = app.textFields["new_transaction_note"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(note)
            // Fuera el teclado antes de tocar el importe: mientras entra, el formulario se mueve debajo del toque
            // (`testing.md`). La pregunta del monto no es un control: tocarla solo cierra el teclado.
            let question = app.descendants(matching: .any)["new_transaction_amount_question"].firstMatch
            XCTAssertTrue(question.waitForExistence(timeout: 5), "Falta la pregunta del monto.")
            question.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado no se cerró.")
        }
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No se abrió el formulario.")
        amount.tap()
        amount.typeText("40")
        XCTAssertTrue((amount.value as? String ?? "").contains("40"), "El importe no quedó escrito: el toque se perdió.")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.tapNewTransactionMoreAction("new_transaction_recurring_action")
    }

    /// La pantalla de éxito con «Recurrente» marcado, sin aviso; «Aceptar» cierra y tampoco sale el aviso después.
    private func expectSuccessMarkedRecurring(_ app: XCUIApplication, capture name: String) {
        let accept = app.buttons["transaction_success_accept"]
        let shown = accept.waitForExistence(timeout: 10)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(shown, "«Hacer recurrente» debía enseñar la pantalla de éxito.")

        let notice = app.descendants(matching: .any)["saved_record_notice"]
        XCTAssertFalse(notice.exists, "Con la pantalla de éxito no sale además el aviso breve.")
        let recurring = app.buttons["transaction_success_recurring"]
        XCTAssertTrue(recurring.waitForExistence(timeout: 5), "Falta «Recurrente» en la pantalla de éxito.")
        XCTAssertFalse(recurring.isEnabled, "Ya es recurrente: «Recurrente» sale marcado y no se vuelve a abrir.")

        accept.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForNonExistence(timeout: 8), "«Aceptar» no cerró.")
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5), "«Aceptar» no cerró la pantalla de éxito.")
        XCTAssertFalse(notice.waitForExistence(timeout: 2), "Al cerrar el éxito no sale el aviso breve.")
    }

    // MARK: - Casos

    func test_filaCadaMes_ensenaElExito_conRecurrenteMarcado() {
        let app = launch()
        openFilledForm(app)
        let monthly = app.buttons["recurring_quick_monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5), "Falta «Cada mes» en «Hacer recurrente».")
        monthly.tap()
        expectSuccessMarkedRecurring(app, capture: "exito-recurrente-cada-mes")
    }

    func test_editorCompleto_ensenaElExito_alCerrarse() {
        let app = launch()
        openFilledForm(app, note: "Gimnasio")
        let more = app.buttons["recurring_quick_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Falta «Más opciones…».")
        more.tap()
        XCTAssertTrue(app.textFields["scheduled_name_field"].waitForExistence(timeout: 8), "No se abrió el editor completo.")
        let save = app.buttons["toolbar_save_button"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta el ✓ del editor.")
        save.tap()
        expectSuccessMarkedRecurring(app, capture: "exito-recurrente-editor")
    }
}
