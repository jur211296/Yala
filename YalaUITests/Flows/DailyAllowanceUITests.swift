//
//  DailyAllowanceUITests.swift
//  YalaUITests
//
//  «Cuánto puedo gastar hoy» (2.3): el detalle de un presupuesto en curso enseña el cupo del día. La cuenta la fija
//  `YalaTests/DailyAllowanceLogicTests`; aquí, que la línea se monta en la pantalla.
//  Scheme Yala Dev. El presupuesto es «QA 30» de `-uitest-seed-budget-states` (`DevSeedBudgetStates`): 305 de 1.000 el
//  día que sea, así que el cupo existe siempre. Hasta el 2026-11-19 era «Comidas fuera» del seed `realista`, que
//  reparte su gasto según la fecha: ese día iba en 1.831 de 1.800, la app escondía el cupo con razón y el caso cayó
//  3 de 3 en el CI y en local.
//

import XCTest

final class DailyAllowanceUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_budgetDetail_showsTodaysAllowance() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "budgets", budgetStates: true)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let row = app.buttons["budget_row_QA 30"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No está la fila de «QA 30».")
        // La lista no es perezosa: la fila existe aunque quede bajo la barra de pestañas. Se lleva a la franja central.
        let window = app.windows.firstMatch.frame
        for _ in 0..<12 where !(row.frame.minY > window.minY + 160 && row.frame.maxY < window.maxY - 160) {
            if row.frame.midY > window.midY { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
        }
        row.tap()

        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "No se abrió el detalle del presupuesto.")
        let allowance = app.descendants(matching: .any)["budget_daily_allowance"]
        XCTAssertTrue(allowance.waitForExistence(timeout: 5), "El detalle no enseña el cupo del día.")
        XCTAssertFalse(allowance.label.isEmpty, "La línea del cupo del día está vacía.")
    }
}
