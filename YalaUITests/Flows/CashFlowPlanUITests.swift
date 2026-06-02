//
//  CashFlowPlanUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest "no-crash" (smoke) del área `cash-flow-plan`: la vista de
//  Flujo de Caja monta su setup sin crash. El tab Reports vive oculto en "Más";
//  su sub-tab "Flujo de Caja" presenta CashFlowSetupView cuando aún no hay plan
//  (con transacciones del seed). NO se tocan los charts pesados (CashFlowChartsSheet)
//  para evitar problemas de timing. Seed `minimal` (incluye transacciones).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CashFlowPlanUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El sub-tab Flujo de Caja monta el setup del plan sin crashear.
    func test_cashFlowSetupMounts() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Reports está oculto en "Más" (config default [panel, statistics, planning]).
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()

        let reportsRow = app.buttons["more_tab_row_reports"]
        XCTAssertTrue(reportsRow.waitForExistence(timeout: 5), "No apareció la fila Reportes en Más.")
        reportsRow.tap()

        // El sub-tab por defecto es Comparativa → cambiar a Flujo de Caja.
        let cashflowChip = app.buttons["report_chip_flujoDeCaja"]
        XCTAssertTrue(cashflowChip.waitForExistence(timeout: 10), "No apareció el chip de Flujo de Caja en Reportes.")
        cashflowChip.tap()

        // CashFlowSetupView monta (header presente con o sin sugerencias).
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "cashflow_setup_view").firstMatch.waitForExistence(timeout: 15),
            "La vista de Flujo de Caja no montó (cashflow_setup_view)."
        )
    }
}
