//
//  MultiDraftReviewUITests.swift
//  YalaUITests
//
//  La hoja de varios registros (propuesta C de Jürgen, card va62), por foto con siete movimientos de cuatro días
//  (`-uitest-image-result many`, dos sin categoría) y por voz con dos (`-uitest-voice-result two`): todo sale marcado,
//  «Guardar» guarda solo lo marcado con su conteo y total, y lo desmarcado se queda en la Bandeja.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class MultiDraftReviewUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openPhotoReview() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-image-result", "many"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(
            app.staticTexts["image_review_title"].waitForExistence(timeout: 20),
            "Tras leer no apareció lo leído (image_review_title)."
        )
        return app
    }

    private func check(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'multi_review_check' AND label CONTAINS %@", name)).firstMatch
    }

    /// Lo baja hasta verlo: la hoja empieza a media altura y la lista es larga.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !element.isHittable, tries < 6 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
    }

    /// Siete leídos, dos sin categoría: todo marcado y Guardar apagado con el aviso; desmarcando esos dos, guarda los
    /// otros cinco, la hoja termina y avisa de que los otros siguen en la Bandeja.
    func test_photo_savesOnlyTheMarked_andLeavesTheRestInTheInbox() {
        let app = openPhotoReview()

        let count = app.staticTexts["multi_review_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Falta el resumen de arriba (multi_review_count).")
        XCTAssertTrue(count.label.hasPrefix("7 de 7"), "Todo tiene que salir marcado: \(count.label)")
        XCTAssertEqual(app.otherElements.matching(identifier: "multi_review_day").count, 4, "Un bloque por día.")

        let save = app.buttons["image_save"]
        XCTAssertFalse(save.isEnabled, "Con dos marcados sin categoría no se puede guardar.")
        XCTAssertTrue(app.staticTexts["multi_review_missing_hint"].exists, "Falta el aviso de qué hacer.")

        let toggleAll = app.buttons["multi_review_toggle_all"]
        toggleAll.tap()
        XCTAssertTrue(count.label.hasPrefix("0 de 7"), "«Quitar todos» tenía que desmarcarlos: \(count.label)")
        XCTAssertFalse(save.isEnabled, "Sin nada marcado no hay nada que guardar.")
        toggleAll.tap()
        XCTAssertTrue(count.label.hasPrefix("7 de 7"), "«Marcar todos» tenía que marcarlos: \(count.label)")

        for name in ["Uber", "Ladislao Bal"] {
            let mark = check(app, name)
            reveal(mark, in: app)
            XCTAssertTrue(mark.isSelected, "\(name) tenía que salir marcado.")
            mark.tap()
            XCTAssertFalse(mark.isSelected, "Tocar la marca de \(name) tenía que desmarcarlo.")
        }

        XCTAssertTrue(save.isEnabled, "Con los incompletos desmarcados, el resto se tiene que poder guardar.")
        XCTAssertTrue(save.label.hasPrefix("Guardar 5 · "), "El botón dice cuántos y cuánto: \(save.label)")
        XCTAssertTrue(save.label.contains("224.81"), "El total del botón es el de los cinco marcados: \(save.label)")
        XCTAssertTrue(
            app.staticTexts["review_inbox_note"].label.contains("Bandeja"),
            "La hoja tiene que decir que lo desmarcado sigue en la Bandeja."
        )
        save.tap()

        let saved = app.descendants(matching: .any).matching(identifier: "voice_draft_saved")
        XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 10), "Tras Guardar, las filas no se marcaron.")
        XCTAssertEqual(saved.count, 5, "Solo se guardan los cinco marcados.")
        XCTAssertEqual(app.buttons.matching(identifier: "voice_draft_row").count, 2, "Los desmarcados siguen pendientes.")
        let finish = app.buttons["image_finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "Con lo marcado guardado, la hoja ofrece Listo.")
        finish.tap()
        XCTAssertTrue(finish.waitForNonExistence(timeout: 10), "Listo no cerró la hoja.")
    }

    /// Por voz, la misma hoja: desmarcar uno de dos guarda solo el otro.
    func test_voice_savesOnlyTheMarked() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-voice-result", "two"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()
        let done = app.buttons["voice_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "La hoja no abrió escuchando (voice_done).")
        done.tap()

        let count = app.staticTexts["multi_review_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 15), "La voz con dos registros tiene que usar la hoja de varios.")
        XCTAssertTrue(count.label.hasPrefix("2 de 2"), "Todo tiene que salir marcado: \(count.label)")

        let marks = app.buttons.matching(identifier: "multi_review_check")
        XCTAssertEqual(marks.count, 2, "Una marca por registro.")
        marks.element(boundBy: 1).tap()
        XCTAssertTrue(count.label.hasPrefix("1 de 2"), "Desmarcar tenía que bajar el conteo: \(count.label)")

        let save = app.buttons["voice_save"]
        XCTAssertTrue(save.label.hasPrefix("Guardar 1 · "), "El botón dice cuántos y cuánto: \(save.label)")
        save.tap()
        let saved = app.descendants(matching: .any).matching(identifier: "voice_draft_saved")
        XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 10), "Tras Guardar, la fila no se marcó.")
        XCTAssertEqual(saved.count, 1, "Solo se guarda el marcado.")
        XCTAssertTrue(app.buttons["voice_finish"].waitForExistence(timeout: 5), "Con lo marcado guardado, Listo.")
    }
}
