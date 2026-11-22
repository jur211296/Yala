//
//  XNativaHojaFotoUITests.swift
//  YalaUITests
//
//  La hoja de foto tras el encargo del 2026-11-17: la X del sistema (44 pt) en la misma fila que el título, la
//  descripción que se corrige tocándola en «Esto leí» y la hoja que se cierra sola al guardar todo. Grupos: la misma X y
//  el nombre de cada línea del reparto editable. El seam `-uitest-image-result` lee un resultado fijo (como
//  `ImageEntryReviewUITests`); `-uitest-image-autoclose-seconds` solo alarga la confirmación para poder leerla.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class XNativaHojaFotoUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openPhotoSheet(_ profile: String, autoCloseSeconds: String = "3") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "records", aiConsent: true,
                            extraArguments: ["-uitest-image-result", profile,
                                             "-uitest-image-autoclose-seconds", autoCloseSeconds])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let action = app.buttons["stats_action_image"]
        XCTAssertTrue(action.waitForHittable(timeout: 15), "Falta la acción de foto de Registros (stats_action_image).")
        action.tap()
        XCTAssertTrue(app.buttons["image_source_photos"].waitForExistence(timeout: 15), "La hoja no abrió eligiendo.")
        return app
    }

    /// La X mide lo que la de las barras y comparte fila con el título: sin la fila vacía de antes.
    private func assertTitleSharesRowWithClose(_ app: XCUIApplication, title: String, close: String) {
        let titleElement = app.staticTexts[title]
        let closeElement = app.buttons[close]
        XCTAssertTrue(titleElement.waitForExistence(timeout: 15), "Falta el título (\(title)).")
        XCTAssertTrue(closeElement.waitForExistence(timeout: 5), "Falta la X (\(close)).")
        let closeFrame = closeElement.frame
        // 44 pt en el diseño; la hoja a media altura se dibuja escalada (386/402 en el 17 Pro) y XCUITest mide ~42.
        XCTAssertGreaterThanOrEqual(closeFrame.width, 41.5, "La X tiene que medir los 44 pt del sistema: \(closeFrame).")
        XCTAssertGreaterThanOrEqual(closeFrame.height, 41.5, "La X tiene que medir los 44 pt del sistema: \(closeFrame).")
        let titleFrame = titleElement.frame
        XCTAssertLessThan(
            abs(titleFrame.midY - closeFrame.midY), closeFrame.height / 2,
            "El título y la X tienen que ir en la misma fila: título \(titleFrame), X \(closeFrame)."
        )
        // Desde la opción A de «Esto leí» (2026-11-22) la X de la hoja personal va a la izquierda, como en B1; la de Grupos
        // sigue a la derecha. Lo que no cambia: no se montan.
        XCTAssertFalse(titleFrame.intersects(closeFrame), "El título no puede montarse sobre la X: \(titleFrame) \(closeFrame).")
    }

    func test_choose_titleAndNativeCloseShareTheRow() {
        let app = openPhotoSheet("one")
        assertTitleSharesRowWithClose(app, title: "image_choose_title", close: "image_close")
    }

    /// Tocar la descripción la abre en línea (sin abrir el formulario), lo escrito se queda, y al guardar el único
    /// registro la hoja enseña «Guardado» y se cierra sola, sin «Listo».
    func test_review_editsTheNoteInPlace_andClosesAloneAfterSaving() {
        let app = openPhotoSheet("one")
        app.buttons["image_source_photos"].tap()
        assertTitleSharesRowWithClose(app, title: "image_review_title", close: "image_close")

        let note = app.buttons["image_draft_note"].firstMatch
        XCTAssertTrue(note.waitForHittable(timeout: 10), "La descripción tiene que poder tocarse (image_draft_note).")
        note.tap()
        let field = app.textFields["image_draft_note_field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Tocar la descripción tenía que abrir el campo en línea.")
        XCTAssertFalse(app.buttons["draft_editor_more"].exists, "Tocar la descripción no abre el formulario completo.")
        field.typeText(" centro\n")

        let edited = app.buttons["image_draft_note"].firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 5), "Al confirmar, el campo vuelve a ser texto.")
        XCTAssertTrue(edited.label.hasSuffix("centro"), "Lo escrito tiene que quedarse en la fila: \(edited.label)")

        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForHittable(timeout: 5), "Falta Guardar (image_save).")
        save.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "voice_draft_saved").firstMatch
                .waitForExistence(timeout: 5),
            "Antes de cerrarse, la fila tenía que enseñar que se guardó."
        )
        XCTAssertFalse(app.buttons["image_finish"].exists, "Con todo guardado ya no se pide «Listo».")
        XCTAssertTrue(
            app.staticTexts["image_review_title"].waitForNonExistence(timeout: 12),
            "Con todo guardado, la hoja tenía que cerrarse sola."
        )
    }

    /// Desde la opción A (2026-11-22) tocar la tarjeta no abre nada: el formulario completo es «Ver todo», empujado dentro
    /// de la misma hoja, y ‹ vuelve a lo leído.
    func test_review_seeAll_opensTheFullFormInTheSameSheet_andBackReturns() {
        let app = openPhotoSheet("one")
        app.buttons["image_source_photos"].tap()
        let seeAll = app.buttons["esto_lei_ver_todo"].firstMatch
        XCTAssertTrue(seeAll.waitForHittable(timeout: 20), "Falta «Ver todo» en la tarjeta (esto_lei_ver_todo).")
        seeAll.tap()
        let back = app.buttons["draft_editor_back"]
        XCTAssertTrue(back.waitForHittable(timeout: 10), "«Ver todo» tenía que empujar el editor con ‹ (draft_editor_back).")
        XCTAssertTrue(app.buttons["draft_editor_more"].exists, "El editor completo trae su «···».")
        XCTAssertFalse(app.buttons["image_close"].isHittable, "Con el editor delante, la X de la hoja no se toca.")
        back.tap()
        XCTAssertTrue(app.buttons["esto_lei_ver_todo"].firstMatch.waitForHittable(timeout: 10),
                      "‹ tenía que volver a la tarjeta, en la misma hoja.")
        XCTAssertFalse(app.buttons["draft_editor_back"].exists, "Y el editor ya no está.")
    }

    /// Con un registro sin guardar (desmarcado en la hoja de varios), guardar no cierra la hoja: queda «Listo».
    func test_several_withOneLeftUnmarked_doesNotCloseAlone() {
        let app = openPhotoSheet("two")
        app.buttons["image_source_photos"].tap()
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForHittable(timeout: 20), "Falta Guardar (image_save).")
        let check = app.buttons.matching(identifier: "multi_review_check").firstMatch
        XCTAssertTrue(check.waitForHittable(timeout: 5), "Falta la marca de la hoja de varios.")
        check.tap()
        XCTAssertTrue(save.waitForHittable(timeout: 5))
        save.tap()
        XCTAssertTrue(app.buttons["image_finish"].waitForExistence(timeout: 8),
                      "Con uno sin guardar, la hoja se queda abierta con «Listo».")
    }

    // MARK: - Grupos

    func test_group_review_titleSharesRowWithClose_andLineNameEditsInPlace() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", "cusco"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Falta el grupo sembrado (group_card).")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["group_detail_ready"].waitForExistence(timeout: 15))
        let photo = app.buttons["group_detail_receipt_photo"]
        XCTAssertTrue(photo.waitForHittable(timeout: 10), "Falta Foto en el grupo (group_detail_receipt_photo).")
        photo.tap()
        assertTitleSharesRowWithClose(app, title: "group_photo_title", close: "receipt_split_close")

        let photos = app.buttons["group_photo_source_photos"]
        XCTAssertTrue(photos.waitForHittable(timeout: 10))
        photos.tap()
        XCTAssertTrue(app.buttons["receipt_split_use"].waitForExistence(timeout: 20), "No llegó lo entendido.")
        assertTitleSharesRowWithClose(app, title: "receipt_split_review_title", close: "receipt_split_close")

        let line = app.buttons["receipt_split_line_description"].firstMatch
        XCTAssertTrue(line.waitForHittable(timeout: 5), "El nombre de la línea tiene que poder tocarse.")
        line.tap()
        let field = app.textFields["receipt_split_line_description_field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Tocar el nombre de la línea tenía que abrir el campo.")
        field.typeText(" extra\n")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier == 'receipt_split_line_description' AND label ENDSWITH ' extra'"))
                .firstMatch.waitForExistence(timeout: 5),
            "Lo escrito tenía que quedarse como nombre de la línea."
        )
    }
}
