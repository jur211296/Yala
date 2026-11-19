//
//  RecurrenteDesdeRegistroUITests.swift
//  YalaUITests
//
//  «Hacer recurrente» a partir de un registro (encargo del 15-nov): las tres entradas llegan al editor de recurrentes
//  prellenado y, al guardar, el registro queda como primer pago (la acción deja de ofrecerse sobre él).
//  - Detalle del registro: «Recurrente» al pie, junto a Duplicar.
//  - Menú del registro (pulsación larga): «Hacer recurrente».
//  - Bandeja: «Aprobar y hacer recurrente» bajo «Aprobar».
//  - Planificación › Pagos: «Desde un registro» abre el selector de registros recientes.
//  Seed `minimal`, idioma fijo de la suite (es-419).
//

import XCTest

final class RecurrenteDesdeRegistroUITests: XCTestCase {

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

    private func launchInRecords() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(deeplink: "records")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(firstRow(app).waitForExistence(timeout: 15), "No hay filas de registro.")
        return app
    }

    private func firstRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "record_row").firstMatch
    }

    /// El editor de recurrentes, o la pregunta de «ya tienes uno parecido» si la semilla trae uno.
    private func waitForPrefilledEditor(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let choice = app.descendants(matching: .any)["recurring_from_record_choice"]
        let name = app.textFields["scheduled_name_field"]
        let deadline = Date().addingTimeInterval(10)
        while !name.exists && !choice.exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        if choice.exists {
            let createNew = app.buttons["recurring_from_record_create_new"]
            XCTAssertTrue(createNew.waitForExistence(timeout: 5), file: file, line: line)
            createNew.tap()
        }
        XCTAssertTrue(name.waitForExistence(timeout: 10), "No se abrió el editor de recurrentes.", file: file, line: line)
        let amount = app.textFields["scheduled_amount_field"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), file: file, line: line)
        let amountValue = (amount.value as? String) ?? ""
        XCTAssertFalse(amountValue.isEmpty || amountValue == "0.00" || amountValue == "0,00",
                       "El monto no vino del registro: «\(amountValue)».", file: file, line: line)
    }

    // MARK: - Detalle

    func test_detail_makeRecurring_prefillsTheEditor_andTheRecordBecomesItsFirstPayment() {
        let app = launchInRecords()
        firstRow(app).tap()

        let makeRecurring = app.buttons["transaction_detail_make_recurring"]
        XCTAssertTrue(makeRecurring.waitForExistence(timeout: 5), "El detalle no ofrece «Recurrente» al pie.")
        XCTAssertEqual(makeRecurring.label, "Hacer recurrente", "VoiceOver tiene que decir qué hace el botón.")
        XCTAssertTrue(app.buttons["transaction_detail_duplicate"].exists, "Duplicar dejó de salir junto a Recurrente.")
        attachScreenshot("detalle-con-recurrente", of: app)
        makeRecurring.tap()

        waitForPrefilledEditor(app)
        attachScreenshot("editor-prellenado", of: app)

        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // De vuelta en el detalle: el registro ya es un pago del recurrente y la acción no se repite.
        XCTAssertTrue(app.buttons["transaction_detail_duplicate"].waitForExistence(timeout: 10),
                      "Guardar no devolvió al detalle del registro.")
        XCTAssertTrue(makeRecurring.waitForNonExistence(timeout: 5),
                      "Tras crearlo, el registro sigue ofreciendo «Recurrente»: no quedó vinculado.")
        attachScreenshot("detalle-tras-vincular", of: app)
    }

    // MARK: - Menú del registro

    func test_rowMenu_offersMakeRecurring_andOpensTheEditor() {
        let app = launchInRecords()
        firstRow(app).press(forDuration: 1.2)

        let action = app.buttons["Hacer recurrente"].firstMatch
        XCTAssertTrue(action.waitForExistence(timeout: 5), "El menú del registro no ofrece «Hacer recurrente».")
        XCTAssertTrue(app.buttons["Duplicar"].firstMatch.exists)
        attachScreenshot("menu-con-hacer-recurrente", of: app)
        action.tap()

        waitForPrefilledEditor(app)
    }

    // MARK: - Bandeja

    func test_inbox_approveAndMakeRecurring_approvesAndOpensTheEditor() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
        let row = app.buttons["inbox_draft_row_Taxi aeropuerto"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "La Bandeja no mostró el borrador de la semilla.")
        row.tap()

        let approveAndRecurring = app.buttons["inbox_approve_and_make_recurring_button"]
        XCTAssertTrue(approveAndRecurring.waitForExistence(timeout: 5), "La hoja del borrador no ofrece «Aprobar y hacer recurrente».")
        XCTAssertTrue(app.buttons["inbox_approve_button"].exists, "«Aprobar» dejó de salir.")
        attachScreenshot("bandeja-aprobar-y-hacer-recurrente", of: app)
        approveAndRecurring.tap()

        waitForPrefilledEditor(app)
        attachScreenshot("bandeja-editor-prellenado", of: app)
        app.buttons["toolbar_save_button"].tap()

        // Aprobado: el borrador ya no está pendiente.
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "El borrador sigue pendiente tras aprobarlo.")
    }

    // MARK: - Planificación

    func test_planning_fromRecord_opensThePicker_andThePrefilledEditor() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openScheduledPaymentsList()

        let fromRecord = app.buttons["scheduled_payments_create_from_record_button"]
        XCTAssertTrue(fromRecord.waitForExistence(timeout: 5), "Pagos no ofrece «Reusar».")
        let newPayment = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(newPayment.exists, "«Nuevo pago planificado» dejó de salir.")
        // Nunca uno debajo del otro (Jürgen, 17-nov): los dos en la misma fila.
        XCTAssertEqual(fromRecord.frame.midY, newPayment.frame.midY, accuracy: 2,
                       "«Reusar» quedó en otra fila que «Nuevo pago planificado».")
        attachScreenshot("pagos-reusar", of: app)
        fromRecord.tap()

        // Las filas de Registros, dentro de la hoja (con la hoja encima, Registros sigue en el árbol: se busca dentro).
        let picker = app.descendants(matching: .any)["recurring_record_picker_list"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "No se abrió la hoja de «Reusar».")
        XCTAssertTrue(picker.buttons["records_quick_account"].exists, "La hoja no trae el chip de Cuenta.")
        XCTAssertTrue(picker.textFields["records_list_search_field"].exists, "La hoja no trae el buscador.")
        let pickerRow = picker.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(pickerRow.waitForExistence(timeout: 10), "El selector no lista registros recientes.")
        attachScreenshot("selector-de-registros", of: app)
        pickerRow.tap()

        waitForPrefilledEditor(app)
    }

    /// Con el iPhone girado (encargo del 17-nov): «Reusar» sigue al lado de «Nuevo pago planificado» y la hoja abre con
    /// el buscador, los chips y las filas.
    func test_planning_reuse_inLandscape_staysInTheSameRow_andThePickerOpens() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.openScheduledPaymentsList()

        let fromRecord = app.buttons["scheduled_payments_create_from_record_button"]
        XCTAssertTrue(fromRecord.waitForExistence(timeout: 5), "Pagos no ofrece «Reusar» con el iPhone girado.")
        let newPayment = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(newPayment.exists, "«Nuevo pago planificado» dejó de salir con el iPhone girado.")
        XCTAssertEqual(fromRecord.frame.midY, newPayment.frame.midY, accuracy: 2,
                       "Girado, «Reusar» quedó en otra fila que «Nuevo pago planificado».")
        attachScreenshot("pagos-reusar-girado", of: app)
        fromRecord.tap()

        let picker = app.descendants(matching: .any)["recurring_record_picker_list"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Girado, no se abrió la hoja de «Reusar».")
        XCTAssertTrue(picker.buttons["records_quick_account"].exists, "Girado, la hoja no trae el chip de Cuenta.")
        XCTAssertTrue(picker.textFields["records_list_search_field"].exists, "Girado, la hoja no trae el buscador.")
        XCTAssertTrue(picker.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 10),
                      "Girado, el selector no lista registros.")
        attachScreenshot("selector-de-registros-girado", of: app)
    }
}
