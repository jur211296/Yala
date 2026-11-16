//
//  CardDesignUITests.swift
//  YalaUITests
//
//  Tarjetas de cuenta personalizables (2026-11-16): desde el botón de paleta de la tarjeta se abre el editor, se elige una
//  plantilla y los últimos 4 dígitos, y al guardar la tarjeta del Panel lo enseña y VoiceOver dice «terminada en …».
//  Cancelar no cambia nada, y la tarjeta «Grupos» no se diseña. Seed `minimal`, scheme Yala Dev, ids y no textos.
//

import XCTest

final class CardDesignUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchWithAccountsVisible(seed: String = "minimal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: seed)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        let card = app.buttons["panel_account_card_0"]
        if !card.waitForExistence(timeout: 3) {
            let header = app.buttons["panel_panorama_header"]
            XCTAssertTrue(header.waitForExistence(timeout: 5), "No apareció la cabecera de «Tus finanzas».")
            header.tap()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No apareció la primera tarjeta de cuenta.")
        return app
    }

    private func openDesigner(_ app: XCUIApplication, index: Int = 0) {
        let palette = app.buttons["panel_account_card_design_\(index)"]
        XCTAssertTrue(palette.waitForExistence(timeout: 5), "La tarjeta no tiene el botón de paleta.")
        palette.tap()
        XCTAssertTrue(app.buttons["card_design_save"].waitForExistence(timeout: 5), "No se abrió el editor de diseño.")
    }

    /// Sube el contenido de la hoja hasta que el elemento quede en la franja central (y no bajo la vista previa fija).
    private func bringIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<8 {
            if element.exists, element.frame.midY < window.maxY - 220, element.frame.midY > window.minY + 320 { return }
            app.swipeUp(velocity: .slow)
        }
    }

    /// El recorrido entero: plantilla + dígitos → guardar → la tarjeta lo enseña y lo dice. Volver a abrir el editor
    /// enseña lo guardado. Con el comportamiento anterior (sin editor) cae en el primer `waitForExistence`.
    func test_designCard_withTemplateAndLastFour_showsOnThePanelCard() {
        let app = launchWithAccountsVisible()
        openDesigner(app)

        let aurora = app.buttons["card_design_template_aurora"]
        XCTAssertTrue(aurora.waitForExistence(timeout: 5), "No está la plantilla «Aurora» en la galería.")
        aurora.tap()
        XCTAssertTrue(aurora.isSelected, "Tocar «Aurora» no la eligió.")

        let digits = app.textFields["card_design_last_four"]
        bringIntoView(digits, in: app)
        XCTAssertTrue(digits.waitForExistence(timeout: 5), "No está el campo de los últimos 4 dígitos.")
        digits.tap()
        // Un número más largo se queda en 4: nunca se guarda más que eso.
        digits.typeText("12567")
        XCTAssertEqual(digits.value as? String, "1256", "El campo dejó escribir más de 4 números.")

        app.buttons["card_design_save"].tap()
        XCTAssertTrue(app.buttons["card_design_save"].waitForNonExistence(timeout: 5), "Guardar no cerró el editor.")

        let card = app.buttons["panel_account_card_0"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // La tarjeta es un solo elemento de VoiceOver: los dígitos pintados van dentro de su etiqueta.
        XCTAssertTrue(card.label.contains("1256"), "VoiceOver no lee los últimos 4 dígitos: \(card.label)")

        // Lo guardado vuelve al abrir otra vez.
        openDesigner(app)
        XCTAssertTrue(app.buttons["card_design_template_aurora"].isSelected, "El editor no abrió con «Aurora».")
        let reopenedDigits = app.textFields["card_design_last_four"]
        bringIntoView(reopenedDigits, in: app)
        XCTAssertEqual(reopenedDigits.value as? String, "1256", "El editor no abrió con los dígitos guardados.")
    }

    /// Cancelar no guarda: la tarjeta sigue sin dígitos y el editor vuelve a abrir con «Tu color».
    func test_cancel_keepsTheCardAsItWas() {
        let app = launchWithAccountsVisible()
        let before = app.buttons["panel_account_card_0"].label
        openDesigner(app)

        let gold = app.buttons["card_design_template_gold"]
        XCTAssertTrue(gold.waitForExistence(timeout: 5))
        gold.tap()
        XCTAssertTrue(gold.isSelected)
        app.buttons["card_design_cancel"].tap()
        XCTAssertTrue(app.buttons["card_design_save"].waitForNonExistence(timeout: 5), "Cancelar no cerró el editor.")

        XCTAssertEqual(app.buttons["panel_account_card_0"].label, before)
        openDesigner(app)
        XCTAssertTrue(app.buttons["card_design_template_account"].isSelected, "Cancelar guardó la plantilla.")
        XCTAssertFalse(app.buttons["card_design_template_gold"].isSelected)
    }

    /// La tarjeta «Grupos» junta cuentas de sistema y no se diseña; la cuenta propia de al lado, sí.
    func test_groupsCard_hasNoPaletteButton() {
        let app = launchWithAccountsVisible(seed: "cuentas-de-grupos")
        XCTAssertTrue(app.buttons["panel_account_card_0"].label.hasPrefix("Grupos."))
        XCTAssertTrue(app.buttons["panel_account_card_design_1"].waitForExistence(timeout: 5),
                      "La cuenta propia no tiene el botón de paleta (control del caso).")
        XCTAssertFalse(app.buttons["panel_account_card_design_0"].exists, "La tarjeta «Grupos» ofrece diseñarse.")
    }
}
