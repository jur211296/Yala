//
//  RecordsDetailSheetUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `records-transaction-detail`: el tap a una fila
//  de Registros (Estadísticas → chip Registros) abre el sheet de detalle
//  read-only (detent medium) en lugar del editor directo; desde ahí la X cierra
//  y el botón Editar hace swap al editor (NewTransactionView). Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class RecordsDetailSheetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega a Estadísticas (2º tab del config por defecto) → chip Registros.
    /// La barra de chips es un ScrollView horizontal y Registros (el último)
    /// puede quedar fuera de vista → se revela con swipe antes de tocarlo.
    /// (Mismo patrón que BulkEditUITests, sin entrar en modo selección.)
    private func openRecordsList(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()

        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros en Estadísticas.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()

        let firstRow = app.buttons.matching(identifier: "record_row").element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "No hay filas de transacción (record_row).")
    }

    /// Smoke: tap en una fila abre el detalle read-only (no el editor) y la X
    /// lo cierra devolviendo a la lista en modo normal.
    func test_tapRecordRow_opensDetailSheet_andCloseDismisses() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecordsList(app)
        app.buttons.matching(identifier: "record_row").element(boundBy: 0).tap()

        let editButton = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No se montó el sheet de detalle (transaction_detail_edit).")

        let closeButton = app.buttons["transaction_detail_close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "No apareció la X del detalle.")
        closeButton.tap()

        XCTAssertTrue(
            editButton.waitForNonExistence(timeout: 5),
            "El sheet de detalle no se cerró tras tocar la X."
        )
        XCTAssertTrue(
            app.recordsOverflowMenu.waitForExistence(timeout: 5),
            "No se volvió a la lista de Registros tras cerrar el detalle."
        )
    }

    /// El botón Editar del detalle hace swap in-place al editor de transacción.
    func test_detailEditButton_swapsToEditForm() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecordsList(app)
        app.buttons.matching(identifier: "record_row").element(boundBy: 0).tap()

        let editButton = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No se montó el sheet de detalle (transaction_detail_edit).")
        editButton.tap()

        XCTAssertTrue(
            app.buttons["new_transaction_save"].waitForExistence(timeout: 5),
            "El botón Editar no abrió el editor (new_transaction_save ausente)."
        )
    }
}
