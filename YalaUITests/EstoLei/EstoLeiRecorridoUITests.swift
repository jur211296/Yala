//
//  EstoLeiRecorridoUITests.swift
//  YalaUITests
//
//  El recorrido de la opción A de «Esto leí» (Jürgen, 2026-11-22): completar lo que falta desde la tarjeta B1, «Ver
//  todo» empuja el editor en la misma hoja y ‹ vuelve, Guardar deja «Guardado en <cuenta>», y cerrar sin guardar deja
//  el registro en la Bandeja con su aviso. Con varios, la incompleta sale desplegada. Scheme Yala Dev, seed `minimal`.
//

import XCTest

final class EstoLeiRecorridoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openAndRead(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, aiConsent: true,
            extraArguments: ["-uitest-image-result", profile, "-uitest-image-autoclose-seconds", "6",
                             "-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let image = app.buttons["panel_action_image"]
            XCTAssertTrue(image.waitForHittable(timeout: 10), "Falta la acción de imagen del Panel.")
            image.tap()
        } else {
            app.revealPanelFAB().tap()
            let image = app.buttons["fab_image"]
            XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
            image.tap()
        }
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20), "No apareció lo leído.")
        return app
    }

    /// Falta la categoría: la tarjeta lo dice en ámbar, el chip abre el selector de siempre y, elegida, «Guardar» se
    /// enciende y deja «Guardado en …» en la tarjeta.
    func test_incompleta_seCompletaDesdeLaTarjeta_yGuarda() {
        let app = openAndRead("incomplete")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertFalse(save.isEnabled, "Sin categoría, Guardar va apagado (ajuste de Jürgen: el botón no cambia de texto).")
        XCTAssertTrue(app.descendants(matching: .any)["voice_draft_card"].exists, "Un registro va en la tarjeta B1.")

        let missing = app.buttons["voice_draft_chip_subcategory"]
        XCTAssertTrue(missing.waitForHittable(timeout: 5), "Falta el chip ámbar de la categoría.")
        missing.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El chip no abrió el selector de categoría.")
        row.tap()

        XCTAssertTrue(app.buttons["esto_lei_subcategory"].waitForExistence(timeout: 10),
                      "Elegida, la categoría va bajo el monto como en B1.")
        XCTAssertTrue(save.isEnabled, "Completa, se puede guardar.")
        save.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["voice_draft_saved"].firstMatch.waitForExistence(timeout: 5),
            "Guardada, la tarjeta dice dónde se guardó.")
    }

    /// «Ver todo» empuja el editor B1 con ‹; lo que se cambia ahí (la descripción) vuelve a la tarjeta.
    func test_verTodo_editaYVuelveConLoCambiado() {
        let app = openAndRead("one")
        let seeAll = app.buttons["esto_lei_ver_todo"].firstMatch
        XCTAssertTrue(seeAll.waitForHittable(timeout: 10), "Falta «Ver todo».")
        seeAll.tap()

        let note = app.textFields["draft_editor_note"]
        XCTAssertTrue(note.waitForHittable(timeout: 10), "El editor completo trae la descripción (draft_editor_note).")
        note.tap()
        note.typeText(" XYZ")
        let back = app.buttons["draft_editor_back"]
        XCTAssertTrue(back.waitForHittable(timeout: 5), "Falta ‹ (draft_editor_back).")
        back.tap()

        let description = app.buttons["image_draft_note"].firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "‹ tenía que volver a la tarjeta.")
        XCTAssertTrue(description.label.contains("XYZ"), "Lo editado en «Ver todo» se queda: \(description.label)")
        XCTAssertTrue(app.staticTexts["image_review_title"].exists, "Y sigue la misma hoja.")
    }

    /// Cerrar sin guardar: la hoja se va, el aviso dice que quedó en la Bandeja y «Ver» la abre.
    func test_cerrarSinGuardar_quedaEnLaBandeja_conSuAviso() {
        let app = openAndRead("one")
        let close = app.buttons["image_close"]
        XCTAssertTrue(close.waitForHittable(timeout: 5), "Falta la X de la hoja.")
        close.tap()
        let notice = app.descendants(matching: .any)["esto_lei_inbox_notice"].firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "Al cerrar sin guardar, el aviso de la Bandeja.")
        let view = app.buttons["esto_lei_inbox_view"]
        XCTAssertTrue(view.waitForHittable(timeout: 5), "El aviso lleva «Ver».")
        view.tap()
        XCTAssertTrue(app.buttons["inbox_close"].waitForExistence(timeout: 10), "«Ver» tenía que abrir la Bandeja.")
    }

    /// Varios: el recuento dice cuántos faltan y la primera incompleta sale desplegada; tocar otra fila la despliega.
    func test_varios_laIncompletaSaleDesplegada() {
        let app = openAndRead("many")
        let count = app.staticTexts["multi_review_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Falta el recuento (multi_review_count).")
        XCTAssertTrue(count.label.contains("por completar"), "El recuento dice cuántos faltan: \(count.label)")
        XCTAssertEqual(app.buttons.matching(identifier: "esto_lei_ver_todo").count, 1, "Una sola fila desplegada.")
        XCTAssertTrue(app.buttons["voice_draft_chip_subcategory"].firstMatch.exists, "La desplegada ofrece completar.")
        XCTAssertFalse(app.buttons["image_save"].isEnabled, "Con incompletas marcadas, Guardar va apagado.")
    }
}
