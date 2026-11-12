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

    /// Los tres botones del selector de tipo, con el formulario ya quieto.
    private func typeButtons(_ app: XCUIApplication) -> (expense: XCUIElement, income: XCUIElement, transfer: XCUIElement) {
        let expense = app.buttons["new_transaction_type_expense"]
        let income = app.buttons["new_transaction_type_income"]
        let transfer = app.buttons["new_transaction_type_transfer"]
        XCTAssertTrue(transfer.waitForExistence(timeout: 5), "No está el selector de tipo en el formulario.")
        _ = app.waitForSettledLayout(of: transfer)
        return (expense, income, transfer)
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

    // MARK: - 64 · «Transferencia» no se parte en el selector de tipo

    func test_64_ax3_typeSelector_stacks_andEachTypeReadsInOneLine() {
        let app = launch(largeText: true)
        openForm(app)
        let (expense, income, transfer) = typeButtons(app)
        capture(app, "64-ax3-selector-de-tipo")

        XCTAssertLessThan(transfer.frame.height, expense.frame.height * 1.5,
                          "A AX3 «Transferencia» ocupa más de una línea (\(transfer.frame.height) pt frente a \(expense.frame.height) de «Gasto»).")
        XCTAssertGreaterThanOrEqual(income.frame.minY, expense.frame.maxY - 1, "A AX3 «Ingreso» va debajo de «Gasto».")
        XCTAssertGreaterThanOrEqual(transfer.frame.minY, income.frame.maxY - 1, "A AX3 «Transferencia» va debajo de «Ingreso».")

        // La cápsula sigue funcionando apilada: elegir «Transferencia» la marca y cambia el formulario.
        transfer.tap()
        XCTAssertTrue(transfer.waitForSelected(timeout: 3), "Tocar «Transferencia» apilada no la elige.")
    }

    func test_64_normalSize_typeSelector_staysInOneRow() {
        let app = launch(largeText: false)
        openForm(app)
        let (expense, income, transfer) = typeButtons(app)
        capture(app, "64-normal-selector-de-tipo")

        XCTAssertEqual(expense.frame.midY, transfer.frame.midY, accuracy: 1, "A tamaño normal los tres tipos van en una fila.")
        XCTAssertEqual(income.frame.midY, transfer.frame.midY, accuracy: 1, "A tamaño normal los tres tipos van en una fila.")
        XCTAssertLessThan(expense.frame.maxX, income.frame.minX + 1)
        XCTAssertLessThan(income.frame.maxX, transfer.frame.minX + 1)
    }
}

private extension XCUIElement {
    func waitForSelected(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: self)], timeout: timeout) == .completed
    }
}
