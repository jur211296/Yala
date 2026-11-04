//
//  DailyAllowanceUITests.swift
//  YalaUITests
//
//  «Cuánto puedo gastar hoy» (2.3): el detalle de un presupuesto en curso enseña el cupo del día. La cuenta la fija
//  `YalaTests/DailyAllowanceLogicTests`; aquí, que la línea se monta en la pantalla.
//  Scheme Yala Dev. «Comidas fuera» es un presupuesto mensual del seed `realista` con margen todo el mes: el seed
//  reparte su gasto para quedar por debajo del límite, así que el cupo existe cualquier día.
//

import XCTest

final class DailyAllowanceUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_budgetDetail_showsTodaysAllowance() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let row = app.buttons["budget_row_Comidas fuera"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No está la fila de Comidas fuera.")
        row.tap()

        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "No se abrió el detalle del presupuesto.")
        let allowance = app.descendants(matching: .any)["budget_daily_allowance"]
        XCTAssertTrue(allowance.waitForExistence(timeout: 5), "El detalle no enseña el cupo del día.")
        XCTAssertFalse(allowance.label.isEmpty, "La línea del cupo del día está vacía.")
    }
}
