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
//  Bug de Jürgen del 2026-11-20: guardado el gasto de grupo, la fila seguía en lo leído sin marcarse. Ahora sale como
//  guardada (`draft_registered_in_group_row`) y, en la foto, la hoja se cierra sola si era la única; cancelar el
//  formulario la deja pendiente.
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

    /// Desde la fila de lo entendido: abre su hoja y toca «Convertir a gasto compartido» hasta que sale el formulario.
    private func openTheGroupForm(in app: XCUIApplication) {
        let row = app.buttons["voice_draft_row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció el registro entendido (voice_draft_row).")
        // El importe, a la derecha: en la hoja de foto la descripción se edita al tocarla (encargo del 2026-11-17).
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()

        let convert = app.buttons["inbox_convert_to_shared_button"]
        XCTAssertTrue(convert.waitForExistence(timeout: 10), "La hoja del registro no ofreció «Convertir a gasto compartido».")
        convert.tap()

        // El bug: aquí no se abría nada.
        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 15),
            "«Convertir a gasto compartido» no abrió el formulario de gasto de grupo."
        )
    }

    /// Abre el formulario de grupo desde la fila y guarda el gasto.
    private func convertTheDraft(in app: XCUIApplication) {
        openTheGroupForm(in: app)
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

        // El bug del 2026-11-20: la fila seguía sin marcar. En la voz, como al guardar el último: «Guardado» y «Listo».
        XCTAssertTrue(
            app.descendants(matching: .any)["draft_registered_in_group_row"].waitForExistence(timeout: 10),
            "Lo convertido no salió marcado como registrado en lo entendido."
        )
        XCTAssertFalse(app.buttons["voice_save"].exists, "Tras registrarlo en el grupo, aún se ofrecía guardarlo como personal.")
        XCTAssertTrue(app.buttons["voice_finish"].waitForExistence(timeout: 5), "La hoja no pasó a «Listo» con todo registrado.")
    }

    /// Abre la hoja de foto con un registro leído.
    private func openImageReview(in app: XCUIApplication) {
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15), "No apareció lo leído.")
    }

    func test_imageDraft_convertsToAGroupExpense() {
        // El cierre solo se alarga para poder ver la fila marcada antes de que la hoja se vaya.
        let app = launch(["-uitest-image-result", "one", "-uitest-image-autoclose-seconds", "4"])
        openImageReview(in: app)

        convertTheDraft(in: app)

        // El bug del 2026-11-20: la fila seguía sin marcar y la hoja abierta.
        XCTAssertTrue(
            app.descendants(matching: .any)["draft_registered_in_group_row"].waitForExistence(timeout: 10),
            "Lo convertido no salió marcado como registrado en lo leído."
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "image_registered_in_group"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertFalse(app.buttons["image_save"].exists, "Tras registrarlo en el grupo, aún se ofrecía guardarlo como personal.")
        // Era el único: la hoja se cierra sola, como al guardar el último.
        XCTAssertTrue(
            app.staticTexts["image_review_title"].waitForNonExistence(timeout: 15),
            "La hoja de lo leído no se cerró sola con su único registro ya en el grupo."
        )
    }

    func test_imageDraft_cancellingTheGroupForm_leavesItPending() {
        let app = launch(["-uitest-image-result", "one"])
        openImageReview(in: app)
        openTheGroupForm(in: app)

        app.buttons["group_expense_close"].tap()
        let discard = app.buttons["group_form_discard_confirm"]
        if discard.waitForExistence(timeout: 2) { discard.tap() }
        XCTAssertTrue(app.textFields["group_expense_amount"].waitForNonExistence(timeout: 10), "El formulario de grupo no se cerró.")

        XCTAssertTrue(app.buttons["voice_draft_row"].firstMatch.waitForExistence(timeout: 10), "Al cancelar desapareció el registro.")
        XCTAssertFalse(
            app.descendants(matching: .any)["draft_registered_in_group_row"].exists,
            "Cancelar el formulario de grupo marcó el registro como guardado."
        )
        XCTAssertTrue(app.staticTexts["image_review_title"].exists, "Cancelar el formulario cerró la hoja de lo leído.")
    }
}
