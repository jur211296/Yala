//
//  ImageEntryReviewUITests.swift
//  YalaUITests
//
//  El registro por imagen de punta a punta (propuesta C, 2026-10-04): elegir → leer → «Esto leí» → Guardar, en la misma
//  hoja. El selector de Fotos es de otro proceso y en el simulador el servicio de imagen no contesta, así que el seam
//  `-uitest-image-result` hace que «Fotos» use los recibos de ejemplo y que la hoja «lea» un resultado fijo resuelto
//  contra los datos sembrados. Lo que cubre es la hoja y el guardado por el camino de la Bandeja
//  (`DraftService.approveDraft`); la cámara, Fotos de verdad y el modelo quedan en el device-QA del ticket
//  `image-entry-end-to-end-redesign`.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class ImageEntryReviewUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre la hoja de imagen desde el FAB con el resultado fijo `profile` y toca Fotos.
    private func openAndRead(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-image-result", profile])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()

        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        XCTAssertTrue(app.buttons["image_source_file"].exists, "Archivo tiene que ofrecerse junto a Fotos.")
        photos.tap()
        return app
    }

    private func waitForReview(_ app: XCUIApplication) {
        XCTAssertTrue(
            app.staticTexts["image_review_title"].waitForExistence(timeout: 15),
            "Tras leer no apareció lo leído (image_review_title)."
        )
    }

    /// Sin cuenta atrás: al elegir, la hoja lee con la foto a la vista y Cancelar; después, lo leído completo se guarda
    /// en la misma hoja y queda un solo botón para cerrar.
    func test_readsWithoutCountdown_andSavesInTheSameSheet() {
        let app = openAndRead("one")

        XCTAssertTrue(
            app.buttons["image_cancel_reading"].waitForExistence(timeout: 5),
            "Al elegir, la hoja tenía que pasar a leer con Cancelar (image_cancel_reading)."
        )
        waitForReview(app)

        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertTrue(save.isEnabled, "Un registro completo se tiene que poder guardar.")
        save.tap()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "voice_draft_saved").firstMatch
                .waitForExistence(timeout: 10),
            "Tras Guardar, la fila no se marcó como registrada."
        )
        XCTAssertFalse(app.buttons["image_save"].exists, "Con todo guardado no debe quedar Guardar.")

        let finish = app.buttons["image_finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "Falta Listo para cerrar (image_finish).")
        finish.tap()
        XCTAssertTrue(finish.waitForNonExistence(timeout: 10), "Listo no cerró la hoja.")
    }

    /// Sin subcategoría, Guardar está apagado y la píldora en ámbar la ofrece; al elegirla, Guardar se enciende.
    func test_missingSubcategory_blocksSave_untilChosen() {
        let app = openAndRead("incomplete")
        waitForReview(app)

        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertFalse(save.isEnabled, "Sin subcategoría, Guardar tiene que estar apagado.")

        let chip = app.buttons["voice_draft_chip_subcategory"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Lo que falta tiene que ofrecerse como píldora.")
        chip.tap()

        let firstSubcategory = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstSubcategory.waitForExistence(timeout: 10), "La píldora no abrió el selector de subcategoría.")
        firstSubcategory.tap()

        XCTAssertTrue(chip.waitForNonExistence(timeout: 10), "Con subcategoría elegida, la píldora de lo que falta se va.")
        XCTAssertTrue(save.isEnabled, "Con la subcategoría elegida, el registro se puede guardar.")
    }

    /// Dos fotos: una fila por registro y un solo «Guardar N».
    func test_twoPhotos_showOneRowEach_andSaveTogether() {
        let app = openAndRead("two")
        waitForReview(app)

        XCTAssertEqual(app.buttons.matching(identifier: "voice_draft_row").count, 2, "Tiene que haber una fila por registro.")
        XCTAssertFalse(app.otherElements["image_failed_photos"].exists, "Si todas se leyeron, no hay aviso de fotos fallidas.")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.isEnabled, "Dos registros completos se tienen que poder guardar juntos.")
        save.tap()

        let saved = app.descendants(matching: .any).matching(identifier: "voice_draft_saved")
        XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 10), "Tras Guardar, las filas no se marcaron.")
        XCTAssertEqual(saved.count, 2, "Guardar 2 tiene que guardar los dos.")
    }

    /// Una foto se lee y otra falla: lo leído se revisa y la que falló se avisa aparte con Reintentar. Antes desaparecía
    /// sin aviso.
    func test_partialRead_reviewsWhatWasRead_andFlagsTheFailedPhoto() {
        let app = openAndRead("partial")
        waitForReview(app)

        XCTAssertEqual(app.buttons.matching(identifier: "voice_draft_row").count, 1, "Solo la foto leída da fila.")
        XCTAssertTrue(
            app.otherElements["image_failed_photos"].waitForExistence(timeout: 5),
            "La foto que falló tenía que avisarse (image_failed_photos)."
        )
        XCTAssertTrue(app.buttons["image_retry_failed"].exists, "El aviso tiene que ofrecer Reintentar.")
    }

    /// Ninguna foto trae importe: el fallo se cuenta en la hoja, sin alert, y «Otra foto» vuelve a elegir.
    func test_noAmount_isToldInTheSheet_andOtherPhotoGoesBack() {
        let app = openAndRead("none")

        XCTAssertTrue(
            app.staticTexts["image_failure_title"].waitForExistence(timeout: 15),
            "Sin importe, el fallo tenía que contarse en la hoja (image_failure_title)."
        )
        XCTAssertEqual(app.alerts.count, 0, "El fallo ya no es un alert.")

        let other = app.buttons["image_other_photo"]
        XCTAssertTrue(other.waitForExistence(timeout: 5), "Falta «Otra foto».")
        other.tap()
        XCTAssertTrue(app.buttons["image_source_photos"].waitForExistence(timeout: 10), "«Otra foto» no volvió a elegir.")
    }
}
