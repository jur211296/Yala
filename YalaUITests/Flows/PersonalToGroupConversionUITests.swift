//
//  PersonalToGroupConversionUITests.swift
//  YalaUITests
//
//  «Convertir a gasto compartido» desde Editar de un registro (2.3): el «Bus» de hoy (`-uitest-seed-today-record`), un
//  gasto personal en la cuenta principal, pasa a «Viaje a Cusco» (seed `grupos`). Fija la entrada, la revisión con lo del
//  registro fijo, el cierre con el aviso, que cancelar no cambia nada, y que el registro ya no ofrece pasarlo otra vez.
//
//  Con `TEST_RUNNER_YALA_CAPTURE_DIR` deja además las capturas de entrada, revisión y resultado en esa carpeta.
//  Convenciones: scheme Yala Dev, sin sleeps.
//

import XCTest

final class PersonalToGroupConversionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", cloudSession: true, groupsConsent: true,
                            extraArguments: ["-uitest-seed-today-record"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Estadísticas → chip Registros (molde de `RecordsDetailSheetUITests`).
    private func openRecordsList(_ app: XCUIApplication) {
        app.selectTab(.statistics)
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros en Estadísticas.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists { chipsBar.swipeLeft() }
        recordsChip.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 10),
                      "Registros no tiene filas.")
    }

    /// El «Bus» de hoy: el primero con ese texto (la lista va de lo más reciente a lo más viejo).
    private func busRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "record_row").matching(NSPredicate(format: "label CONTAINS 'Bus'")).firstMatch
    }

    private func openBusEditor(_ app: XCUIApplication) {
        let row = busRow(app)
        // La lista es perezosa: con texto grande el «Bus» queda debajo (molde de `GroupsBCabosSueltosUITests.openRecord`).
        var swipes = 0
        while !(row.exists && row.isHittable), swipes < 10 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el «Bus» de hoy en Registros.")
        if row.frame.maxY > app.windows.firstMatch.frame.maxY - 140 { app.swipeUp(velocity: .slow) }
        row.tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8), "El detalle no ofrece «Editar».")
        edit.tap()
        XCTAssertTrue(app.buttons["new_transaction_save"].waitForExistence(timeout: 8), "No abrió el editor.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            do { try shot.pngRepresentation.write(to: url) } catch { XCTFail("No se pudo guardar \(name): \(error)") }
        }
    }

    /// `despues` por defecto; `TEST_RUNNER_YALA_CAPTURE_PREFIX=antes` para la corrida contra la app base.
    private var capturePrefix: String {
        ProcessInfo.processInfo.environment["YALA_CAPTURE_PREFIX"] ?? "despues"
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Entrada → elegir el grupo → revisar → guardar: el editor se cierra con el aviso y el registro ya es del grupo.
    func test_convertingTheBus_toAGroup() {
        let app = launch()
        openRecordsList(app)
        openBusEditor(app)

        // La captura va antes de buscar el botón: corrida contra la app base deja el «antes» (el editor sin la opción).
        XCTAssertTrue(app.buttons["new_transaction_subcategory_chip"].waitForExistence(timeout: 5))
        capture(app, "\(capturePrefix)-1-entrada")
        let convert = app.buttons["new_transaction_convert_to_group"]
        XCTAssertTrue(convert.waitForExistence(timeout: 5), "El editor de un gasto personal no ofrece pasarlo a un grupo.")
        if convert.frame.maxY > app.windows.firstMatch.frame.maxY - 120 { app.swipeUp(velocity: .slow) }
        convert.tap()

        // `grupos` tiene varios grupos: primero se elige.
        let cusco = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'group_picker_row_' AND label CONTAINS 'Viaje a Cusco'")).firstMatch
        XCTAssertTrue(cusco.waitForExistence(timeout: 8), "No salió el selector de grupo con «Viaje a Cusco».")
        capture(app, "\(capturePrefix)-2-selector")
        cusco.tap()

        // La revisión: el aviso de qué pasa con el registro y el importe fijo (es el del registro).
        let notice = element(app, "group_expense_conversion_notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 8), "La revisión no dice qué pasa con el registro.")
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.exists, "La revisión no enseña el importe.")
        XCTAssertFalse(amount.isEnabled, "El importe del registro se puede cambiar en la revisión.")
        XCTAssertFalse(app.buttons["group_expense_from_receipt"].exists, "«Desde un recibo» no tiene sentido aquí.")
        capture(app, "\(capturePrefix)-3-revision")

        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // Se cierran la revisión y el editor, y sale el aviso «Movido a…» con «Ver».
        let moved = element(app, "record_converted_to_group_notice")
        XCTAssertTrue(moved.waitForExistence(timeout: 10), "No salió el aviso de adónde fue el registro.")
        XCTAssertTrue(app.buttons["new_transaction_save"].waitForNonExistence(timeout: 5),
                      "El editor no se cerró tras pasar el registro.")
        capture(app, "\(capturePrefix)-4-resultado")
        XCTAssertTrue(moved.waitForNonExistence(timeout: 15), "El aviso no se retiró.")

        // El mismo registro, ahora del grupo: el editor ya no ofrece pasarlo otra vez y dice dónde se gestiona.
        openBusEditor(app)
        XCTAssertTrue(element(app, "new_transaction_group_delete_hint").waitForExistence(timeout: 5),
                      "El registro no quedó enlazado al gasto del grupo.")
        XCTAssertFalse(app.buttons["new_transaction_convert_to_group"].exists,
                       "Un registro que ya es del grupo vuelve a ofrecer pasarlo.")
    }

    /// Cancelar en la revisión deja el registro como estaba: el editor sigue abierto y lo vuelve a ofrecer.
    func test_cancellingTheReview_changesNothing() {
        let app = launch()
        openRecordsList(app)
        openBusEditor(app)

        let convert = app.buttons["new_transaction_convert_to_group"]
        XCTAssertTrue(convert.waitForExistence(timeout: 5))
        if convert.frame.maxY > app.windows.firstMatch.frame.maxY - 120 { app.swipeUp(velocity: .slow) }
        convert.tap()
        let cusco = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'group_picker_row_' AND label CONTAINS 'Viaje a Cusco'")).firstMatch
        XCTAssertTrue(cusco.waitForExistence(timeout: 8))
        cusco.tap()
        XCTAssertTrue(element(app, "group_expense_conversion_notice").waitForExistence(timeout: 8))

        // La X de la revisión (molde del formulario de grupo).
        let close = app.buttons["group_expense_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "La revisión no tiene X.")
        close.tap()

        XCTAssertTrue(element(app, "group_expense_conversion_notice").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["new_transaction_save"].exists, "Cancelar cerró también el editor.")
        XCTAssertFalse(element(app, "record_converted_to_group_notice").exists, "Cancelar avisó de un movimiento.")
        XCTAssertTrue(app.buttons["new_transaction_convert_to_group"].exists,
                      "Tras cancelar el registro ya no se ofrece: algo cambió.")
        XCTAssertFalse(element(app, "new_transaction_group_delete_hint").exists, "Cancelar enlazó el registro al grupo.")
    }
}
