//
//  CashFlowMonthEndUITests.swift
//  YalaUITests
//
//  Decisión 30 de la revisión 2.3 (opción A, 9-nov-2026): el mes en curso del flujo de caja abre con «Al 30 de
//  noviembre tendrías», la misma cifra que «Ver proyectado» del Panel, con su cuenta debajo (Tienes hoy · Falta entrar
//  · Falta salir). Antes abría con lo que entra menos lo que sale («Este mes te sobran»), que pasa a una línea.
//  Que la cifra sea la del Panel lo fija `FlujoAl30YEstimadoTests`; aquí, que la pantalla la enseña.
//

import XCTest

final class CashFlowMonthEndUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Con el plan recién creado, el mes en curso enseña la cifra al fin de mes y su cuenta, y no la cifra grande de
    /// antes; el neto del mes sigue, como línea.
    func test_currentMonth_opensWithTheMonthEndFigure_andItsBreakdown() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "cashflow_setup_view").firstMatch.waitForExistence(timeout: 15),
            "La vista de Flujo de Caja no montó (cashflow_setup_view)."
        )
        skipCoachMarkIfShown(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMarkIfShown(app)

        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["cashflow_month_end_closing"].firstMatch.waitForExistence(timeout: 10),
                      "El mes en curso no abre con «Al 30 tendrías».")
        for id in ["cashflow_month_end_today", "cashflow_month_end_in", "cashflow_month_end_out", "cashflow_month_net_line"] {
            XCTAssertTrue(any[id].firstMatch.exists, "Falta \(id) en la cabecera del mes.")
        }
        XCTAssertFalse(any["cashflow_month_net"].firstMatch.exists,
                       "La cifra grande del mes en curso sigue siendo lo que entra menos lo que sale.")
    }

    /// La guía de pasos sale a los 0,5-1 s de montar la pantalla y, mientras está, el scroll está apagado.
    private func skipCoachMarkIfShown(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }
}
