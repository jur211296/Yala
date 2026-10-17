//
//  TrialOfferMomentUITests.swift
//  YalaUITests
//
//  UX 2.2 · L1-12 (decisión de Jürgen del 2026-10-13): la oferta de prueba de Yala Pro ya no sale al terminar
//  el alta, sino tras el primer registro guardado. Con «¿Era de prueba?» detrás, espera a su respuesta.
//
//  `-uitest-trial-offer-armed` deja la oferta armada sin momento, como al terminar un alta. El test arranca
//  DOS veces: la segunda, sin reset, es el arranque de quien terminó el alta y cerró la app — el código de
//  antes presentaba la oferta justo ahí, así que esa aserción es la que discrimina la decisión.
//

import XCTest

final class TrialOfferMomentUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_offerWaitsForTheFirstRecord_andForThePracticeAnswer() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "sin-registros", trialOfferArmed: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let offer = app.buttons["trial_offer_dismiss"]
        let newRecord = app.buttons["panel_action_new"]
        XCTAssertTrue(newRecord.waitForHittable(timeout: 10), "No apareció «Nuevo registro» en el hero del Panel.")

        // El arranque de quien ya terminó el alta: la oferta sigue armada y NO sale.
        app.terminate()
        app.launchForUITest(reset: false, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")
        XCTAssertTrue(newRecord.waitForHittable(timeout: 15), "El Panel no quedó usable en el segundo arranque.")
        XCTAssertFalse(offer.waitForExistence(timeout: 8),
                       "La oferta salió al arrancar, antes de cualquier registro (UX 2.2 · L1-12).")

        newRecord.tap()
        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("12")
        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        XCTAssertTrue(app.buttons["new_transaction_subcategory_chip"].waitForExistence(timeout: 5))
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        let accept = app.buttons["transaction_success_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No apareció la pantalla de éxito.")
        XCTAssertFalse(offer.exists, "La oferta salió encima de la pantalla de éxito.")
        accept.tap()

        // Es el primer registro: detrás viene «¿Era de prueba?», y la oferta espera a la respuesta.
        let keep = app.alerts.buttons["Guardarlo"]
        XCTAssertTrue(keep.waitForExistence(timeout: 10), "No apareció el aviso «¿era de prueba?».")
        XCTAssertFalse(offer.exists, "La oferta salió a la vez que «¿era de prueba?».")
        keep.tap()

        XCTAssertTrue(offer.waitForExistence(timeout: 15),
                      "Tras el primer registro y su «¿era de prueba?» no salió la oferta de prueba.")
        offer.tap()
        XCTAssertTrue(newRecord.waitForHittable(timeout: 10), "Tras cerrar la oferta el Panel no quedó usable.")
    }
}
