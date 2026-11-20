//
//  NuevoRegistroTextoGrande23UITests.swift
//  YalaUITests
//
//  Revisión 2.3 · Nuevo registro, decisiones 63 y 64 del 9-nov
//  (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`, ficha en
//  `docs/ux/revision-vistas-2.3/32-nuevo-registro/`). Seed `formulario`: «Café» (gasto, S/ 12.00), «Sueldo» (ingreso,
//  S/ 3,000.00) y dos transferencias.
//
//  - 63: con texto grande, el importe de un favorito en Ajustes › Favoritos baja a su propia línea y se lee entero; antes
//    se partía al lado del nombre («S/ / 3,000. / 00»). Mismo molde que «Esto entendí» en 2.2.
//  - 64: con texto grande, el selector «Gasto | Ingreso | Transferencia» se apila; antes «Transferencia» se partía en tres
//    líneas («Trans-feren-cia»). A tamaño normal, la fila de siempre.
//
//  Texto grande = AX3 (`AccessibilityXL`), el tamaño de la revisión. Cada caso adjunta su captura (`keepAlways`): son el
//  antes y el después de la entrega.
//

import XCTest

final class NuevoRegistroTextoGrande23UITests: XCTestCase {

    private static let ax3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(largeText: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "formulario", extraArguments: largeText ? Self.ax3 : [])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openForm(_ app: XCUIApplication) {
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No apareció «Nuevo» en el Panel.")
        XCTAssertTrue(new.waitForHittable(timeout: 10), "«Nuevo» existe pero no se puede tocar.")
        new.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// La fila de abajo de la hoja B1 (Hoy · Cuenta · #), con el formulario ya quieto y sin teclado.
    private func bottomRow(_ app: XCUIApplication) -> (date: XCUIElement, account: XCUIElement, tags: XCUIElement) {
        if app.keyboards.count > 0 {
            app.staticTexts["new_transaction_amount_question"].tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado no se cerró.")
        }
        let date = app.buttons["new_transaction_date_chip"]
        let account = app.buttons["new_transaction_account_chip"]
        let tags = app.buttons["new_transaction_tags_chip"]
        XCTAssertTrue(tags.waitForExistence(timeout: 5), "No está la fila de abajo del formulario.")
        _ = app.waitForSettledLayout(of: tags)
        return (date, account, tags)
    }

    // MARK: - 63 · El importe de un favorito no se parte

    func test_63_ax3_favoriteAmount_goesBelowTheName_inOneLine() {
        let app = launch(largeText: true)
        app.openProfile()
        app.openSettingsSection("profile_favorites")

        let name = app.descendants(matching: .any)["favorite_row_name_Sueldo"]
        let amount = app.descendants(matching: .any)["favorite_row_amount_Sueldo"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No está el importe del favorito «Sueldo» en Ajustes › Favoritos.")
        XCTAssertTrue(name.exists, "No está el nombre del favorito «Sueldo».")
        _ = app.waitForSettledLayout(of: amount)
        capture(app, "63-ax3-favoritos")

        XCTAssertGreaterThanOrEqual(amount.frame.minY, name.frame.maxY - 1,
                                    "A AX3 el importe sigue al lado del nombre (\(amount.frame) junto a \(name.frame)), donde se parte.")
        XCTAssertLessThan(amount.frame.height, name.frame.height * 1.6,
                          "A AX3 el importe ocupa más de una línea (\(amount.frame.height) pt frente a \(name.frame.height) del nombre).")
    }

    func test_63_normalSize_favoriteAmount_staysBesideTheName() {
        let app = launch(largeText: false)
        app.openProfile()
        app.openSettingsSection("profile_favorites")

        let name = app.descendants(matching: .any)["favorite_row_name_Sueldo"]
        let amount = app.descendants(matching: .any)["favorite_row_amount_Sueldo"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No está el importe del favorito «Sueldo».")
        _ = app.waitForSettledLayout(of: amount)
        capture(app, "63-normal-favoritos")

        XCTAssertGreaterThan(amount.frame.minX, name.frame.maxX,
                             "A tamaño normal el importe va a la derecha del nombre, como siempre.")
    }

    // MARK: - Hoja B1 · el tipo en el título-menú y la fila de abajo en una sola línea (2026-11-20)

    /// El segmentado de tipo ya no está en Nuevo registro (decisión 64 de 2.3 vive en el flujo de caja): con texto grande
    /// el título-menú sigue eligiendo el tipo.
    func test_b1_ax3_titleMenu_choosesTheType() {
        let app = launch(largeText: true)
        openForm(app)
        app.chooseNewTransactionType("transfer")
        XCTAssertTrue(app.buttons["new_transaction_source_chip"].waitForExistence(timeout: 5),
                      "A AX3, elegir «Transferencia» en el título-menú no cambió el formulario.")
        capture(app, "b1-ax3-transferencia")
    }

    /// Ajuste 1 de Jürgen: la fila de abajo NUNCA baja a otra línea, tampoco con texto grande.
    func test_b1_ax3_bottomRow_staysInOneLine() {
        let app = launch(largeText: true)
        openForm(app)
        let (date, account, tags) = bottomRow(app)
        capture(app, "b1-ax3-fila-de-abajo")
        XCTAssertEqual(date.frame.midY, account.frame.midY, accuracy: 2, "A AX3 la cuenta bajó a otra línea.")
        XCTAssertEqual(tags.frame.midY, account.frame.midY, accuracy: 2, "A AX3 «#» bajó a otra línea.")
        XCTAssertLessThan(date.frame.maxX, account.frame.minX + 1, "Hoy va primero.")
        XCTAssertLessThan(account.frame.maxX, tags.frame.minX + 1, "«#» va al final.")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(tags.frame.maxX, window.maxX, "La fila se sale por la derecha.")
    }

    func test_b1_normalSize_bottomRow_staysInOneLine() {
        let app = launch(largeText: false)
        openForm(app)
        let (date, account, tags) = bottomRow(app)
        capture(app, "b1-normal-fila-de-abajo")
        XCTAssertEqual(date.frame.midY, account.frame.midY, accuracy: 2)
        XCTAssertEqual(tags.frame.midY, account.frame.midY, accuracy: 2)
    }
}
