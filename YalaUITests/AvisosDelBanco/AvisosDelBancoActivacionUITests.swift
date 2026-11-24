//
//  AvisosDelBancoActivacionUITests.swift
//  YalaUITests
//
//  «Avisos del banco», encargo del 23-nov-2026. Entrar a mirar el BCP ya no lo pone en «Activos»: lo pone «Ya lo
//  configuré»; y uno activo se quita con «Quitar de Activos». Con el arreglo fuera, la primera vuelta a la lista ya
//  enseña el BCP en «Activos» y el caso cae.
//

import XCTest

final class AvisosDelBancoActivacionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_enterDoesNotActivate_confirmActivates_removeDeactivates() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        openBankNotices(app)

        // 1. Entrar a mirar no lo activa.
        let bcp = app.buttons["bank_notices_bank_bcp"]
        XCTAssertTrue(bcp.waitForExistence(timeout: 10), "No se abrió «¿De qué banco?» con el BCP.")
        bcp.tap()
        let status = app.staticTexts["bank_notice_status_title"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10), "La pantalla del BCP no enseña su estado.")
        XCTAssertTrue(status.label.hasPrefix("Aún no está activo"), "Estado: \(status.label)")
        goBack(app)
        XCTAssertTrue(bcp.waitForExistence(timeout: 10), "Al volver, el BCP no sigue entre los que se pueden añadir.")
        XCTAssertFalse(app.buttons["bank_notices_active_bcp"].exists, "Entrar a mirar el BCP lo puso en «Activos».")

        // 2. «Ya lo configuré» lo activa.
        bcp.tap()
        let confirm = app.buttons["bank_notice_confirm_setup"]
        scrollTo(confirm, in: app)
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "«Ya lo configuré» sigue tras tocarlo.")
        goBack(app)
        let active = app.buttons["bank_notices_active_bcp"]
        XCTAssertTrue(active.waitForExistence(timeout: 10), "Tras «Ya lo configuré» el BCP no está en «Activos».")
        XCTAssertTrue(active.label.contains("Esperando el primer aviso"), "Fila: \(active.label)")

        // 3. «Quitar de Activos» lo devuelve a la lista.
        active.tap()
        let remove = app.buttons["bank_notice_deactivate"]
        scrollTo(remove, in: app)
        remove.tap()
        let quitar = app.alerts.buttons["Quitar"].firstMatch
        XCTAssertTrue(quitar.waitForExistence(timeout: 5), "No salió la confirmación de «Quitar de Activos».")
        quitar.tap()
        XCTAssertTrue(bcp.waitForExistence(timeout: 10), "Tras quitarlo, no volvió a «¿De qué banco?».")
        XCTAssertFalse(app.buttons["bank_notices_active_bcp"].exists, "Quitado, el BCP sigue en «Activos».")
        app.terminate()
    }

    // MARK: - Ayudantes

    private func openBankNotices(_ app: XCUIApplication) {
        app.openProfile()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")
        let row = app.buttons["profile_bank_notices"]
        var attempts = 0
        while !(row.exists && row.isHittable) && attempts < 12 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció la fila «Avisos del banco».")
        row.tap()
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var scrolls = 0
        while !(element.exists && element.isHittable) && scrolls < 12 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "No apareció \(element.identifier).")
    }

    /// Atrás con el gesto del borde: la pantalla del banco usa el «‹» del sistema dentro de la hoja de Ajustes.
    private func goBack(_ app: XCUIApplication) {
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    }
}
