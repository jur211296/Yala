//
//  BudgetsLote9UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 9 (presupuestos), lo que se puede asertar en el simulador:
//  - L9-5: tocar la alerta de un presupuesto abre SU detalle (toque fingido por `-uitest-budget-alert-tap`: el simulador
//    no deja a Yala mostrar notificaciones; entra por el mismo `NotificationService.routeTap`).
//  - L9-3: el + abre el editor en el tipo de la pestaña, con la línea que explica el tipo.
//  - L9-4: «Activar alertas» en el editor enciende el interruptor general y el aviso se va.
//  - L9-12: «Mostrar en el widget» en la pulsación larga de la fila.
//  - L9-14: la alerta de borrar nombra el presupuesto.
//  Scheme Yala Dev. Los nombres de presupuesto son datos del seed `realista`, no texto localizado.
//

import XCTest

final class BudgetsLote9UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// L9-5: la alerta de «Movilidad» abre el detalle de «Movilidad», no la lista.
    func test_alertTap_opensThatBudgetsDetail() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", budgetAlertTap: "Movilidad")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let detail = app.descendants(matching: .any)["budget_detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 20), "La alerta no abrió el detalle del presupuesto.")
        XCTAssertTrue(app.navigationBars["Movilidad"].waitForExistence(timeout: 5),
                      "El detalle abierto no es el del presupuesto de la alerta.")
    }

    /// L9-3 + L9-4: desde la pestaña Anual, el + abre el editor en Anual, con su explicación; y «Activar alertas»
    /// enciende el interruptor general en el sitio.
    func test_newFromYearlyTab_opensInYearly_andActivateAlertsTurnsTheGlobalOn() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 60), "uitest_ready ausente — bootstrap/seed no completó.")

        let listPicker = app.segmentedControls["budgets_period_type_picker"]
        XCTAssertTrue(listPicker.waitForExistence(timeout: 15), "No se montó el selector de tipo de la lista.")
        listPicker.buttons.element(boundBy: 2).tap()

        let fab = app.buttons["budgets_create_fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5), "No apareció budgets_create_fab.")
        fab.tap()

        let editorPicker = app.segmentedControls["budget_editor_period_picker"]
        XCTAssertTrue(editorPicker.waitForExistence(timeout: 5), "No se montó el editor.")
        let yearly = editorPicker.buttons.element(boundBy: 2)
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: yearly)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed,
                       "El editor no abrió en el tipo de la pestaña (Anual).")
        XCTAssertTrue(app.staticTexts["budget_period_type_hint"].exists, "Falta la línea que explica el tipo.")

        let activate = app.buttons["budget_alerts_activate_global"]
        XCTAssertTrue(activate.waitForExistence(timeout: 5), "Con el general apagado, el editor no ofrece activarlo.")
        activate.tap()
        XCTAssertTrue(activate.waitForNonExistence(timeout: 5),
                      "Tras «Activar alertas» el aviso sigue: el interruptor general no se encendió.")
    }

    /// L9-12 + L9-14: la pulsación larga ofrece «Mostrar en el widget» y, marcado, «Quitar del widget»; y borrar desde el
    /// editor nombra el presupuesto.
    func test_longPressShowsInWidget_andDeleteNamesTheBudget() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let row = app.buttons["budget_row_Movilidad"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No está la fila de Movilidad.")
        row.press(forDuration: 1.2)
        let show = app.buttons["star"]
        XCTAssertTrue(show.waitForExistence(timeout: 5), "El menú de la fila no ofrece «Mostrar en el widget».")
        show.tap()

        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["star.slash"].waitForExistence(timeout: 5),
                      "Marcado para el widget, el menú no ofrece quitarlo.")
        app.buttons["pencil"].tap()

        let delete = app.buttons["budget_delete_button"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "No se montó el editor con su botón de borrar.")
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "No salió la confirmación de borrar.")
        XCTAssertTrue(alert.label.contains("Movilidad"), "La confirmación no nombra el presupuesto: «\(alert.label)».")
    }
}
