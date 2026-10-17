//
//  RecordsLote8UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 8 (Registros), lo decidido que se ve en pantalla:
//  - L8-1: Registros en el primer bloque de Más, junto a Panel.
//  - L8-4: Duplicar y Eliminar al pie del detalle; Duplicar abre la copia.
//  - L8-7: borrar pregunta en una alerta que nombra el registro y trae Cancelar, desde el detalle y desde el menú.
//  - L8-8: la copia se titula «Duplicar registro».
//  - L8-9: «Cambiar subcategoría» marca la actual y, al elegir otra, avisa con Deshacer.
//  - L8-12: «Seleccionar» a la vista, la línea de ayuda y la barra con Eliminar y Editar con texto.
//  Seed `minimal`, idioma fijo de la suite (es-419).
//

import XCTest

final class RecordsLote8UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
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

    private func rowCount(_ app: XCUIApplication) -> Int {
        app.buttons.matching(identifier: "record_row").count
    }

    // MARK: - L8-1

    func test_more_recordsCardSitsRightUnderPanel() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.tabBars.buttons["Más"].tap()

        let panel = app.buttons["more_card_panel"]
        let records = app.buttons["more_card_records"]
        XCTAssertTrue(records.waitForExistence(timeout: 10), "Más no trae la tarjeta de Registros.")
        XCTAssertTrue(records.isHittable, "Registros tiene que verse sin desplazar Más.")
        XCTAssertGreaterThan(records.frame.minY, panel.frame.minY, "Registros va debajo de Panel.")
        let groups = app.buttons["more_card_groups"]
        if groups.exists {
            XCTAssertLessThan(records.frame.minY, groups.frame.minY, "Registros va antes que «Más herramientas».")
        }
    }

    // MARK: - L8-4 / L8-7

    func test_detail_deleteAsksNamingTheRecord_cancelKeepsIt_deleteRemovesIt() {
        let app = launchInRecords()
        let before = rowCount(app)
        firstRow(app).tap()

        let delete = app.buttons["transaction_detail_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El detalle no ofrece Eliminar al pie.")
        XCTAssertTrue(app.buttons["transaction_detail_duplicate"].exists, "El detalle no ofrece Duplicar al pie.")
        delete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Eliminar no preguntó con una alerta.")
        XCTAssertTrue(alert.label.hasPrefix("¿Eliminar «"), "La pregunta no nombra el registro: «\(alert.label)».")
        XCTAssertTrue(alert.buttons["Cancelar"].firstMatch.exists, "La alerta no trae Cancelar.")
        alert.buttons["Cancelar"].firstMatch.tap()
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Cancelar cerró el detalle.")

        delete.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Eliminar"].firstMatch.tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 5), "El detalle no se cerró tras eliminar.")
        let deadline = Date().addingTimeInterval(5)
        while rowCount(app) >= before, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertLessThan(rowCount(app), before, "El registro sigue en la lista.")
    }

    // MARK: - L8-4 / L8-8

    func test_detail_duplicate_opensTheCopyTitledDuplicate() {
        let app = launchInRecords()
        firstRow(app).tap()

        let duplicate = app.buttons["transaction_detail_duplicate"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5), "El detalle no ofrece Duplicar al pie.")
        duplicate.tap()

        XCTAssertTrue(app.buttons["new_transaction_save"].waitForExistence(timeout: 10), "Duplicar no abrió el editor.")
        XCTAssertTrue(
            app.navigationBars["Duplicar registro"].waitForExistence(timeout: 5),
            "La copia no se titula «Duplicar registro».")
        XCTAssertFalse(app.buttons["new_transaction_delete_action"].exists,
                       "La copia sin guardar no puede ofrecer Eliminar (borraría el original).")
    }

    // MARK: - L8-7 desde el menú de la fila

    func test_rowMenuDelete_isACenteredAlertWithCancel() {
        let app = launchInRecords()
        firstRow(app).press(forDuration: 1.2)

        let delete = app.buttons["Eliminar"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "La pulsación larga no abrió el menú del registro.")
        delete.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Eliminar desde el menú no preguntó con una alerta.")
        XCTAssertTrue(alert.label.hasPrefix("¿Eliminar «"), "La pregunta no nombra el registro: «\(alert.label)».")
        XCTAssertTrue(alert.buttons["Cancelar"].firstMatch.exists, "La alerta no trae Cancelar.")
        alert.buttons["Cancelar"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
    }

    // MARK: - L8-9

    func test_changeSubcategory_marksTheCurrent_andUndoesFromTheNotice() {
        let app = launchInRecords()
        firstRow(app).press(forDuration: 1.2)

        let change = app.buttons["Cambiar categoría"].firstMatch
        XCTAssertTrue(change.waitForExistence(timeout: 5), "El menú no ofrece cambiar la categoría.")
        change.tap()

        let sheet = app.otherElements["record_subcategory_change_sheet"].firstMatch
        XCTAssertTrue(app.navigationBars["Cambiar subcategoría"].waitForExistence(timeout: 5),
                      "La hoja no se titula «Cambiar subcategoría».")
        XCTAssertTrue(app.descendants(matching: .any)["record_subcategory_change_record"].exists || sheet.exists,
                      "La hoja no dice qué registro cambia.")

        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'record_subcategory_option_'"))
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 5), "La hoja no trae opciones.")
        let current = options.matching(NSPredicate(format: "selected == true")).firstMatch
        XCTAssertTrue(current.exists, "La subcategoría actual no va marcada.")

        // Otra que no sea la actual.
        var other: XCUIElement?
        for index in 0..<min(options.count, 12) {
            let candidate = options.element(boundBy: index)
            if !candidate.isSelected, candidate.isHittable { other = candidate; break }
        }
        guard let other else { return XCTFail("No hay otra subcategoría a la vista.") }
        other.tap()

        let undo = app.buttons["record_subcategory_change_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Tras elegir no salió el aviso con Deshacer.")
        XCTAssertTrue(app.navigationBars["Cambiar subcategoría"].waitForNonExistence(timeout: 5), "La hoja no se cerró.")
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5), "Deshacer no retiró el aviso.")
    }

    // MARK: - L8-12

    func test_selection_visibleButton_hint_thenBarWithLabelledActions() {
        let app = launchInRecords()

        let select = app.buttons["records_select_visible"]
        XCTAssertTrue(select.waitForExistence(timeout: 5), "«Seleccionar» no está a la vista en la barra de arriba.")
        select.tap()

        XCTAssertTrue(app.descendants(matching: .any)["records_selection_hint"].waitForExistence(timeout: 5),
                      "Al entrar no se dice qué hacer.")

        firstRow(app).tap()
        let delete = app.buttons["bulk_delete_button"]
        let edit = app.buttons["bulk_edit_button"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "La barra no trae Eliminar.")
        XCTAssertTrue(edit.exists, "La barra no trae Editar.")
        XCTAssertEqual(delete.label, "Eliminar")
        XCTAssertEqual(edit.label, "Editar")
        XCTAssertTrue(app.staticTexts["1 seleccionado"].exists, "El recuento no dice «1 seleccionado».")

        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Borrar lo elegido no preguntó con una alerta centrada.")
        XCTAssertTrue(alert.label.hasPrefix("¿Eliminar «"), "Con uno elegido, la pregunta lo nombra: «\(alert.label)».")
        XCTAssertTrue(alert.buttons["Cancelar"].firstMatch.exists, "La alerta no trae Cancelar.")
        alert.buttons["Cancelar"].firstMatch.tap()
    }
}
