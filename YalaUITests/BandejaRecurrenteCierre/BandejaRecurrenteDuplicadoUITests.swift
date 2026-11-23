//
//  BandejaRecurrenteDuplicadoUITests.swift
//  YalaUITests
//
//  «Aprobar y hacer recurrente» cuando el borrador tiene un posible duplicado (encargo del 22-nov-2026). Con
//  `-uitest-inbox-duplicate-draft` la semilla guarda un registro gemelo de «Almuerzo equipo» (mismo día, importe y
//  cuenta), así que guardarlo saca el aviso «Posible duplicado».
//  - «Crear de todas formas» aprueba y abre el editor de recurrentes prellenado.
//  - «Cancelar» no guarda, y el «Guardar» de después enseña la pantalla de éxito de siempre, no el editor de
//    recurrentes: lo fija el desarme que «Guardar» hace antes de aprobar (sin él, este caso cae; medido con el mutante).
//

import XCTest

final class BandejaRecurrenteDuplicadoUITests: XCTestCase {

    private let twinDraft = "Almuerzo equipo"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Abre la Bandeja con el gemelo sembrado y entra en el borrador que tiene posible duplicado.
    private func openTwinDraft() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-inbox-duplicate-draft"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
        let row = app.buttons["inbox_draft_row_\(twinDraft)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "La Bandeja no mostró el borrador gemelo.")
        row.tap()
        XCTAssertTrue(app.buttons["inbox_approve_button"].waitForExistence(timeout: 5), "No se abrió el borrador.")
        return app
    }

    /// Toca «Aprobar y hacer recurrente» y espera el aviso de posible duplicado.
    private func approveAndMakeRecurring(_ app: XCUIApplication) {
        let item = app.draftApproveAndMakeRecurringItem()
        XCTAssertTrue(item.waitForExistence(timeout: 5), "El menú «…» no ofrece «Guardar y hacer recurrente».")
        item.tap()
    }

    private func duplicateAlertButton(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let button = app.alerts.firstMatch.buttons[id].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No salió el aviso «Posible duplicado».")
        return button
    }

    func test_possibleDuplicate_saveAnyway_approvesAndOpensThePrefilledEditor() {
        let app = openTwinDraft()
        approveAndMakeRecurring(app)
        let saveAnyway = duplicateAlertButton(app, "inbox_duplicate_save_anyway")
        attachScreenshot("aviso-posible-duplicado", of: app)
        saveAnyway.tap()

        let name = app.textFields["scheduled_name_field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Tras «Crear de todas formas» no se abrió el editor de recurrentes.")
        let amount = app.textFields["scheduled_amount_field"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "El editor no tiene el campo de monto.")
        let amountValue = (amount.value as? String) ?? ""
        XCTAssertFalse(amountValue.isEmpty || amountValue == "0.00" || amountValue == "0,00",
                       "El monto no vino del borrador: «\(amountValue)».")
        attachScreenshot("editor-prellenado-tras-duplicado", of: app)
        app.buttons["toolbar_save_button"].tap()

        // Aprobado: el borrador sale de pendientes (queda «Taxi aeropuerto», así que la Bandeja sigue abierta).
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(twinDraft)"].waitForNonExistence(timeout: 10),
            "El borrador sigue pendiente tras aprobarlo y hacerlo recurrente."
        )
    }

    func test_possibleDuplicate_cancel_disarmsRecurring_soTheNextSaveShowsTheSuccessScreen() {
        let app = openTwinDraft()
        approveAndMakeRecurring(app)
        duplicateAlertButton(app, "inbox_duplicate_cancel").tap()

        // Cancelar no guardó: el borrador sigue abierto.
        let approve = app.buttons["inbox_approve_button"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5), "Cancelar cerró el borrador.")
        approve.tap()
        duplicateAlertButton(app, "inbox_duplicate_save_anyway").tap()

        XCTAssertTrue(
            app.buttons["inbox_success_accept"].waitForExistence(timeout: 10),
            "«Guardar» tras cancelar no enseñó la pantalla de éxito."
        )
        XCTAssertFalse(
            app.textFields["scheduled_name_field"].exists,
            "«Guardar» a secas abrió el editor de recurrentes: lo recurrente seguía armado tras cancelar."
        )
        attachScreenshot("guardar-tras-cancelar", of: app)
    }
}
