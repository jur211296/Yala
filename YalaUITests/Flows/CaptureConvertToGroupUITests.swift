//
//  CaptureConvertToGroupUITests.swift
//  YalaUITests
//
//  Bug de Jürgen del 2026-11-03: desde la edición de un registro que entró por voz o por imagen no se podía convertir a
//  gasto compartido. La hoja del borrador enseñaba «Convertir a gasto compartido», pero esas dos pantallas la abrían sin
//  el flujo que tiene la Bandeja: el botón cerraba la hoja y no pasaba nada. Ahora abre el formulario de gasto de grupo
//  prellenado, como desde la Bandeja (`DraftGroupConversionFlow`).
//
//  Seed `grupos-invitado`: UN grupo elegible, así el formulario abre directo, sin el selector de grupo (hoja sobre hoja,
//  que XCUITest no toca de forma estable; ver `InboxConvertToGroupUITests`). Los seams de voz e imagen dan un gasto fijo
//  sin red. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targetear por identifier).
//

import XCTest

final class CaptureConvertToGroupUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        // El aviso «Movido a…» dura 5 s; en un runner lento puede irse antes de mirarlo (molde de `UXAudit22Lote08UITests`).
        app.launchForUITest(
            pro: true, seed: "grupos-invitado", aiConsent: true,
            extraArguments: extra + ["-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Desde la fila de lo entendido: abre su hoja, toca «Convertir a gasto compartido» y guarda el gasto de grupo.
    private func convertTheDraft(in app: XCUIApplication) {
        let row = app.buttons["voice_draft_row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció el registro entendido (voice_draft_row).")
        row.tap()

        let convert = app.buttons["inbox_convert_to_shared_button"]
        XCTAssertTrue(convert.waitForExistence(timeout: 10), "La hoja del registro no ofreció «Convertir a gasto compartido».")
        convert.tap()

        // El bug: aquí no se abría nada.
        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 15),
            "«Convertir a gasto compartido» no abrió el formulario de gasto de grupo."
        )
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció Guardar del gasto de grupo.")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed, "Guardar del gasto de grupo no se encendió.")
        save.tap()

        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "El formulario de grupo no se cerró al guardar.")
        XCTAssertEqual(app.state, .runningForeground, "La app no sigue viva tras guardar el gasto de grupo.")
        XCTAssertTrue(
            app.descendants(matching: .any)["inbox_moved_to_group_notice"].waitForExistence(timeout: 10),
            "Tras convertir, no se dijo adónde fue el registro."
        )
    }

    func test_voiceDraft_convertsToAGroupExpense() {
        let app = launch(["-uitest-voice-result", "one"])
        app.revealPanelFAB().tap()
        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()
        let done = app.buttons["voice_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "La hoja no abrió escuchando (voice_done).")
        done.tap()
        XCTAssertTrue(app.staticTexts["voice_review_title"].waitForExistence(timeout: 15), "No apareció lo entendido.")

        convertTheDraft(in: app)
    }

    func test_imageDraft_convertsToAGroupExpense() {
        let app = launch(["-uitest-image-result", "one"])
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15), "No apareció lo leído.")

        convertTheDraft(in: app)
    }
}
