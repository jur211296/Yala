//
//  GruposPagoPorConfirmarUITests.swift
//  YalaUITests
//
//  Grupos 2.3 · una deuda con un pago esperando confirmación (opción B; Jürgen, 2026-11-13).
//
//  Semilla `grupos` + `-uitest-seed-pending-settlement`: en «Viaje a Cusco» Ana me debe S/ 80 y apuntó que me pagó S/ 50,
//  por confirmar. Con `-uitest-seed-pending-settlement-already-settled`, Ana ya saldó esos S/ 80 con otro pago.
//
//  Discriminante, con el código de antes:
//  - la tarjeta de la deuda no decía nada del pago (`group_debt_pending_note` no existía);
//  - «Sí, lo recibí» confirmaba al primer toque aunque la deuda ya estuviera saldada (no había aviso).
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo la cifra sembrada).
//

import XCTest

final class GruposPagoPorConfirmarUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func test_debtWithAPendingPayment_saysSo() {
        let app = openBalances(alreadySettled: false)
        let confirmYes = app.buttons["group_pending_confirm_yes"]
        XCTAssertTrue(confirmYes.waitForExistence(timeout: 10), "No apareció el pago de Ana por confirmar.")
        let note = app.descendants(matching: .any)["group_debt_pending_note"]
        _ = note.waitForExistence(timeout: 5)
        if note.exists { note.scrollIntoViewIfNeeded(in: app) }
        capture(app, "1-tarjeta")

        XCTAssertTrue(note.exists, "La tarjeta de la deuda de Ana no dice que hay un pago por confirmar.")
        XCTAssertTrue(note.label.contains("50"), "La línea no dice cuánto: «\(note.label)».")
    }

    func test_confirmingAPaymentOnASettledDebt_warnsFirst() {
        let app = openBalances(alreadySettled: true)
        let confirmYes = app.buttons["group_pending_confirm_yes"]
        XCTAssertTrue(confirmYes.waitForExistence(timeout: 10), "No apareció el pago de Ana por confirmar.")
        confirmYes.tap()

        let anyway = app.buttons["group_pending_over_confirm"].firstMatch
        _ = anyway.waitForExistence(timeout: 5)
        capture(app, "2-aviso")
        XCTAssertTrue(anyway.exists, "«Sí, lo recibí» confirmó sin avisar que la deuda ya estaba saldada.")
        XCTAssertTrue(app.buttons["group_pending_over_remove"].firstMatch.exists, "El aviso no ofrece «Quitar el pago».")

        // Los botones de la alerta salen dos veces en el árbol de accesibilidad (medido: dos por id), así que se cogen con
        // `firstMatch` y el «un solo Cancelar» se mira en la captura, no contando.
        // «Cancelar» no confirma: el pago sigue esperando.
        app.buttons["group_pending_over_cancel"].firstMatch.tap()
        XCTAssertTrue(anyway.waitForNonExistence(timeout: 5), "El aviso no se cerró.")
        XCTAssertTrue(confirmYes.exists, "Cancelar confirmó o quitó el pago.")

        // «Confirmar igual» lo confirma: sale de «por confirmar».
        confirmYes.tap()
        XCTAssertTrue(anyway.waitForExistence(timeout: 5), "El aviso no volvió a salir.")
        anyway.firstMatch.tap()
        XCTAssertTrue(confirmYes.waitForNonExistence(timeout: 8), "«Confirmar igual» no confirmó el pago.")
    }

    // MARK: - Helpers

    private func openBalances(alreadySettled: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var extra = ["-uitest-seed-pending-settlement"]
        if alreadySettled { extra.append("-uitest-seed-pending-settlement-already-settled") }
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "No apareció la pestaña de saldos del grupo.")
        tab.tap()
        return app
    }

    /// Antes y después para el PR: `YALA_CAPTURE_DIR` (con `TEST_RUNNER_`) y `YALA_CAPTURE_PREFIX` («antes» o «despues»).
    private func capture(_ app: XCUIApplication, _ name: String) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["YALA_CAPTURE_DIR"] else { return }
        let prefix = env["YALA_CAPTURE_PREFIX"] ?? "despues"
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("GruposPagoPorConfirmarUITests: captura no guardada: \(error)")
        }
    }
}

private extension XCUIElement {
    /// Sube la línea a la vista si quedó bajo el borde (la tarjeta de Ana va debajo del pago por confirmar).
    func scrollIntoViewIfNeeded(in app: XCUIApplication) {
        var tries = 0
        while !isHittable && tries < 4 {
            app.swipeUp()
            tries += 1
        }
    }
}
