//
//  VoiceEntryReviewUITests.swift
//  YalaUITests
//
//  El registro por voz de punta a punta (propuesta C, 2026-10-04): escuchar → Listo → «Esto entendí» → Guardar, en la
//  misma hoja. Sin red no hay transcripción, así que el seam `-uitest-voice-result` hace que la hoja no grabe y
//  «entienda» un resultado fijo resuelto contra los datos sembrados. Lo que cubre es la hoja y el guardado por el camino
//  de la Bandeja (`DraftService.approveDraft`); la voz real y el modelo quedan en el device-QA del ticket
//  `voice-entry-end-to-end`.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class VoiceEntryReviewUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre la hoja de voz desde el FAB con el resultado fijo `profile` y toca Listo.
    private func openReview(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-voice-result", profile])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.revealPanelFAB().tap()
        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()

        let done = app.buttons["voice_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "La hoja no abrió escuchando (voice_done).")
        XCTAssertTrue(done.isEnabled, "Con el seam no hay micro que esperar: Listo tiene que estar encendido.")
        done.tap()

        XCTAssertTrue(
            app.staticTexts["voice_review_title"].waitForExistence(timeout: 15),
            "Tras Listo no apareció lo entendido (voice_review_title)."
        )
        return app
    }

    /// Lo entendido completo se guarda en la misma hoja: la fila pasa a «Registrado» y queda un solo botón para cerrar.
    func test_completeDraft_savesInTheSameSheet() {
        let app = openReview("one")

        let save = app.buttons["voice_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (voice_save).")
        XCTAssertTrue(save.isEnabled, "Un registro completo se tiene que poder guardar.")
        save.tap()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "voice_draft_saved").firstMatch
                .waitForExistence(timeout: 10),
            "Tras Guardar, la fila no se marcó como registrada (voice_draft_saved)."
        )
        XCTAssertFalse(app.buttons["voice_save"].exists, "Con todo guardado no debe quedar Guardar.")

        let finish = app.buttons["voice_finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "Falta Listo para cerrar (voice_finish).")
        finish.tap()
        XCTAssertTrue(finish.waitForNonExistence(timeout: 10), "Listo no cerró la hoja.")
    }

    /// Sin subcategoría, Guardar está apagado y la píldora en ámbar la ofrece con el selector de Nuevo registro; al
    /// elegirla, Guardar se enciende.
    func test_missingSubcategory_blocksSave_untilChosen() {
        let app = openReview("incomplete")

        let save = app.buttons["voice_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (voice_save).")
        XCTAssertFalse(save.isEnabled, "Sin subcategoría, Guardar tiene que estar apagado.")

        let chip = app.buttons["voice_draft_chip_subcategory"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Lo que falta tiene que ofrecerse como píldora.")
        chip.tap()

        let firstSubcategory = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(
            firstSubcategory.waitForExistence(timeout: 10),
            "La píldora no abrió el selector de subcategoría de Nuevo registro."
        )
        firstSubcategory.tap()

        XCTAssertTrue(chip.waitForNonExistence(timeout: 10), "Con subcategoría elegida, la píldora de lo que falta se va.")
        XCTAssertTrue(save.isEnabled, "Con la subcategoría elegida, el registro se puede guardar.")
    }

    /// Varios registros en una grabación: una fila por registro y un solo «Guardar N».
    func test_severalDrafts_showOneRowEach_andSaveTogether() {
        let app = openReview("two")

        XCTAssertEqual(app.buttons.matching(identifier: "voice_draft_row").count, 2, "Tiene que haber una fila por registro.")
        let save = app.buttons["voice_save"]
        XCTAssertTrue(save.isEnabled, "Dos registros completos se tienen que poder guardar juntos.")
        save.tap()

        let saved = app.descendants(matching: .any).matching(identifier: "voice_draft_saved")
        XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 10), "Tras Guardar, las filas no se marcaron.")
        XCTAssertEqual(saved.count, 2, "Guardar 2 tiene que guardar los dos.")
    }

    /// Volver a grabar descarta lo entendido y la hoja vuelve a escuchar.
    func test_recordAgain_returnsToListening() {
        let app = openReview("one")

        let again = app.buttons["voice_record_again"]
        XCTAssertTrue(again.waitForExistence(timeout: 5), "Falta Volver a grabar.")
        again.tap()

        XCTAssertTrue(app.buttons["voice_done"].waitForExistence(timeout: 10), "Volver a grabar no volvió a escuchar.")
        XCTAssertFalse(app.staticTexts["voice_review_title"].exists, "Lo entendido tenía que desaparecer.")
    }

    /// Cupo de prueba agotado (sesión 2 del gateway de IA): el 403 `yala_trial_exhausted` no se cuenta como un fallo
    /// cualquiera, sino como lo que es, con una salida a Yala Pro y sin «Reintentar» (repetir el audio falla igual).
    func test_trialUsedUp_saysSo_andOffersPro() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-voice-result", "trial-used-up"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()
        let done = app.buttons["voice_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "La hoja no abrió escuchando (voice_done).")
        done.tap()

        let seePro = app.buttons["voice_trial_see_pro"]
        XCTAssertTrue(seePro.waitForExistence(timeout: 15), "El cupo agotado no ofreció Yala Pro (voice_trial_see_pro).")
        XCTAssertFalse(app.buttons["voice_retry"].exists, "Con el cupo agotado, reintentar el mismo audio no sirve.")
        seePro.tap()
        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10), "«Ver Yala Pro» no abrió Yala Pro.")
    }
}
