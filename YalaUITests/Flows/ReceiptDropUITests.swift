//
//  ReceiptDropUITests.swift
//  YalaUITests
//
//  Soltar un recibo sobre Yala (ticket ipad-drop-unreadable-file-fails-silently). El arrastre entre apps no se puede
//  conducir desde XCUITest, así que el seam `-uitest-receipt-drop` suelta por el `ReceiptDropHandler.handle` real en
//  cuanto la ventana queda libre: lo que se prueba es todo lo que hay detrás de soltar (leer, el router, el
//  consentimiento y la hoja). Arrastrar de verdad queda en el device-QA del ticket, en un iPad.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class ReceiptDropUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(drop kind: String, aiConsent: Bool, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, aiConsent: aiConsent, extraArguments: ["-uitest-receipt-drop", kind] + extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// El rojo del ticket: con el código de antes, el soltar se aceptaba y no aparecía nada.
    func test_unreadableFile_opensTheImageEntryInItsFailure() {
        let app = launch(drop: "unreadable", aiConsent: true)

        XCTAssertTrue(
            app.staticTexts["image_failure_title"].waitForExistence(timeout: 20),
            "Soltar un archivo ilegible tenía que abrir el registro por imagen en su fallo (image_failure_title)."
        )
        let other = app.buttons["image_other_photo"]
        XCTAssertTrue(other.waitForExistence(timeout: 5), "El fallo tiene que ofrecer elegir otra (image_other_photo).")
        other.tap()
        XCTAssertTrue(
            app.buttons["image_source_photos"].waitForExistence(timeout: 10),
            "«Otra foto» tenía que volver a elegir (image_source_photos)."
        )
    }

    /// El camino feliz sigue igual: la imagen soltada se lee en la hoja.
    func test_readableImage_isReadInTheSheet() {
        let app = launch(drop: "readable", aiConsent: true, extraArguments: ["-uitest-image-result", "one"])

        XCTAssertTrue(
            app.staticTexts["image_review_title"].waitForExistence(timeout: 25),
            "La imagen soltada tenía que leerse y enseñar lo leído (image_review_title)."
        )
        XCTAssertFalse(app.staticTexts["image_failure_title"].exists, "Una imagen legible no puede acabar en el fallo.")
    }

    /// Sin consentimiento de IA, primero el aviso de consentimiento. Si no se acepta, el fallo no espera a la próxima vez
    /// que se abra el registro por imagen: ahí ya no explicaría nada.
    func test_withoutConsent_askingFirst_andDecliningForgetsTheFailure() {
        let app = launch(drop: "unreadable", aiConsent: false)

        let consent = app.alerts.firstMatch
        XCTAssertTrue(consent.waitForExistence(timeout: 20), "Sin consentimiento, el soltar tenía que pedirlo antes.")
        XCTAssertFalse(app.staticTexts["image_failure_title"].exists, "La hoja no puede abrirse antes del consentimiento.")
        let cancel = consent.buttons.element(boundBy: consent.buttons.count - 1)
        cancel.tap()
        XCTAssertTrue(consent.waitForNonExistence(timeout: 10), "El aviso de consentimiento no se cerró.")

        // La fila de acciones del Panel y no el flotante: en el iPad el Panel cabe sin scroll y el flotante no entra.
        let image = app.buttons["panel_action_image"]
        XCTAssertTrue(image.waitForHittable(timeout: 10), "Falta la acción de imagen del Panel (panel_action_image).")
        image.tap()

        let again = app.alerts.firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 10), "Abrir el registro por imagen tenía que pedir consentimiento.")
        again.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(
            app.buttons["image_source_photos"].waitForExistence(timeout: 15),
            "Tras rechazar y volver a entrar, la hoja tenía que abrir eligiendo, no en el fallo viejo."
        )
        XCTAssertFalse(app.staticTexts["image_failure_title"].exists, "El fallo del soltar rechazado volvió a salir.")
    }
}
