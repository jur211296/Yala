//
//  GroupSettlementCollectedUITests.swift
//  YalaUITests
//
//  Grupos B · card 10: la hoja de pago de la Bandeja dice qué venta cobra ese pago y que cuenta como ingreso hoy.
//  «Ventas con Ana» trae solo una venta tuya a Ana de S/ 50 y un pago de Ana de S/ 50 por confirmar. Confirmas, abres el pago en la Bandeja y la hoja dice «Cobras «Venta de bici»: S/ 50.00 de … cuentan como
//  ingreso hoy.»
//
//  Discriminante: sin venta, un pago abre la hoja de siempre, sin frase (el caso de control). Sin el cambio, la hoja no
//  tiene la frase en ninguno de los dos.
//
//  Capturas: con `TEST_RUNNER_YALA_CAPTURE_DIR`, el control deja `antes-hoja-pago.png` (la hoja de siempre) y el caso,
//  `despues-hoja-pago.png`.
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los sembrados).
//

import XCTest

final class GroupSettlementCollectedUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Confirma el pago de Ana en `groupName`, relanza sin sembrar y abre su borrador en la Bandeja. Con venta, el grupo es
    /// «Ventas con Ana» (`-uitest-seed-group-sale`: solo la venta y el pago); sin ella, «Viaje a Cusco» con el pago de
    /// siempre (`-uitest-seed-pending-settlement`).
    private func openPaymentSheet(withSale: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        let groupName = withSale ? "Ventas con Ana" : "Viaje a Cusco"
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", pendingSettlement: !withSale, groupSale: withSale)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", groupName)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta de «\(groupName)».")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()
        let yes = app.buttons["group_pending_confirm_yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 10), "No apareció el pago de Ana por confirmar.")
        yes.tap()
        XCTAssertTrue(yes.waitForNonExistence(timeout: 8), "Confirmar no retiró la tarjeta.")

        // Relanzar SIN sembrar (los datos ya están en disco) y abrir la Bandeja desde el Panel.
        app.terminate()
        app.launchForUITest(reset: false, pro: true, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente tras relanzar.")
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()
        let payment = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ana' AND label CONTAINS %@", groupName))
            .firstMatch
        XCTAssertTrue(payment.waitForExistence(timeout: 8), "No apareció el pago de Ana en la Bandeja.")
        payment.tap()
        XCTAssertTrue(app.descendants(matching: .any)["group_draft_banner"].waitForExistence(timeout: 8),
                      "No abrió la hoja del pago.")
        return app
    }

    func test_paymentThatCollectsASale_saysItCountsAsIncomeToday() {
        let app = openPaymentSheet(withSale: true)
        let line = app.descendants(matching: .any)["group_draft_footnote"]
        XCTAssertTrue(line.waitForExistence(timeout: 8), "La hoja del pago no dice qué venta cobra.")
        XCTAssertTrue(line.label.contains("Venta de bici"), "La frase no nombra la venta: «\(line.label)».")
        XCTAssertTrue(line.label.contains("50"), "La frase no lleva el importe: «\(line.label)».")
        capture(app, "despues-hoja-pago")
    }

    /// Control: un pago de Ana en un grupo sin ventas («Viaje a Cusco») es una devolución de siempre, sin frase.
    func test_paymentWithoutSales_hasNoIncomeLine() {
        let app = openPaymentSheet(withSale: false)
        // La hoja ya está (el banner existe): la ausencia se mira con la hoja montada, no en otra pantalla.
        XCTAssertFalse(app.descendants(matching: .any)["group_draft_footnote"].exists,
                       "Un pago sin ventas no cobra ningún ingreso.")
        capture(app, "antes-hoja-pago")
    }

    /// Captura para el informe de la sesión, solo si la corrida la pide (`TEST_RUNNER_YALA_CAPTURE_DIR`).
    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("GroupSettlementCollectedUITests: captura no guardada: \(error)")
        }
    }
}
