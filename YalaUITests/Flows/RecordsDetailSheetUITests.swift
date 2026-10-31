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

    /// Card 1w89: borrar desde el editor recorre el camino entero —«Eliminar», confirmar y cerrar— y vuelve a la lista sin
    /// el registro. El editor sigue presentado mientras se cierra con el registro ya borrado; en iOS 27.x leerlo abortaría
    /// la app (el simulador 27.0 no aborta: lo que no lee lo fijan `DeletedModelFormGuardWiringTests` y
    /// `DeletedRecordFormReleaseTests`). Aquí se fija que el gesto llega al final y la app sigue en pie.
    func test_deleteFromEditor_confirm_closesAndRemovesTheRecord() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecordsList(app)
        let firstRow = app.buttons.matching(identifier: "record_row").element(boundBy: 0)
        let rowLabel = firstRow.label
        let sameLabel = NSPredicate(format: "identifier == 'record_row' AND label == %@", rowLabel)
        let rowsBefore = app.buttons.matching(sameLabel).count
        firstRow.tap()

        let editButton = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No se montó el sheet de detalle (transaction_detail_edit).")
        editButton.tap()

        let delete = app.buttons["new_transaction_delete_action"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El editor de un registro guardado no ofreció Eliminar.")
        delete.tap()

        let confirm = app.alerts.buttons["new_transaction_delete_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No salió la pregunta de borrado.")
        confirm.tap()

        XCTAssertTrue(app.buttons["new_transaction_save"].waitForNonExistence(timeout: 5),
                      "El editor no se cerró tras borrar.")
        XCTAssertEqual(app.state, .runningForeground, "La app no siguió en pie tras borrar desde el editor.")
        XCTAssertTrue(app.recordsOverflowMenu.waitForExistence(timeout: 5), "No se volvió a la lista de Registros.")
        let gone = NSPredicate { _, _ in app.buttons.matching(sameLabel).count < rowsBefore }
        let wait = XCTNSPredicateExpectation(predicate: gone, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed,
                       "El registro borrado («\(rowLabel)») sigue en la lista.")
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

    /// Auditoría UX 2.2 · lote 8. Tras «Duplicar» el formulario es un registro NUEVO sin guardar, y su «Eliminar»
    /// borraba el ORIGINAL que se acababa de duplicar (medido en el simulador: 2295 → 2294 registros, el original
    /// fuera). Ahora Duplicar y Eliminar desaparecen en cuanto se duplica, y el registro de partida sigue en la lista.
    func test_duplicateFromEditor_hidesDeleteAndKeepsTheOriginal() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecordsList(app)
        app.buttons.matching(identifier: "record_row").element(boundBy: 0).tap()

        let editButton = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No se montó el sheet de detalle.")
        editButton.tap()

        let duplicate = app.buttons["new_transaction_duplicate_action"]
        let delete = app.buttons["new_transaction_delete_action"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5), "El editor de un registro guardado no ofreció Duplicar.")
        XCTAssertTrue(delete.exists, "El editor de un registro guardado no ofreció Eliminar.")

        duplicate.tap()

        XCTAssertTrue(delete.waitForNonExistence(timeout: 5),
                      "Tras Duplicar, Eliminar sigue ahí: borraría el original, no la copia sin guardar.")
        XCTAssertFalse(duplicate.exists, "Tras Duplicar, Duplicar sigue ahí.")

        // Cerrar sin guardar la copia: el editor se va (con una hoja arriba, el fondo sigue en el árbol, así que se mira
        // que el editor desaparezca, no que exista la lista).
        let close = app.buttons["new_transaction_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Falta la X del editor (new_transaction_close).")
        close.tap()
        XCTAssertTrue(app.buttons["new_transaction_save"].waitForNonExistence(timeout: 5), "El editor no se cerró.")
    }
}
