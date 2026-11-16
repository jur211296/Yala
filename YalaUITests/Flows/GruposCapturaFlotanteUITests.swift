//
//  GruposCapturaFlotanteUITests.swift
//  YalaUITests
//
//  El «+» flotante dentro de un grupo sale solo cuando el scroll se lleva la fila de «Nuevo gasto» de arriba, como en
//  Panel, Registros, Presupuestos y Pagos (encargo «Grupos: voz, foto y Yala IA idénticos a personal», 2026-11-16).
//  `grupos` siembra «Viaje a Cusco» con gastos de sobra para desplazar, también en el iPhone 17 Pro.
//

import XCTest

final class GruposCapturaFlotanteUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_groupDetail_plusAppearsOnlyAfterScrollingAwayTheTopRow() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["group_detail_ready"].waitForExistence(timeout: 10),
                      "El detalle del grupo no terminó de cargar.")

        let topRow = app.buttons["group_detail_action_new_expense"]
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(topRow.waitForExistence(timeout: 5), "No está «Nuevo gasto» bajo el saldo.")
        // Arriba, con la fila a la vista, el «+» no sale (ni tras el falso «no visible» del montaje).
        XCTAssertFalse(fab.waitForExistence(timeout: 1.5), "El «+» sale con «Nuevo gasto» a la vista.")

        for _ in 0..<6 where !fab.exists {
            app.swipeUp()
        }
        XCTAssertTrue(fab.waitForExistence(timeout: 3), "El «+» no salió al desplazar la fila fuera de la vista.")

        for _ in 0..<8 where fab.exists {
            app.swipeDown()
        }
        XCTAssertTrue(topRow.waitForExistence(timeout: 3), "No volvió la fila de arriba.")
        XCTAssertTrue(fab.waitForNonExistence(timeout: 3), "El «+» sigue con «Nuevo gasto» otra vez a la vista.")

        fab.exists ? fab.tap() : topRow.tap()
        XCTAssertTrue(app.textFields["group_expense_description"].waitForExistence(timeout: 5),
                      "«Nuevo gasto» de arriba no abre el formulario.")
    }
}
