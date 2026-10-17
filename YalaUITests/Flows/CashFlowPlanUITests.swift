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
        // El dashboard de "Más" tiene una card directa a Flujo de Caja que navega
        // a Reportes con ese sub-tab ya seleccionado (sin pasar por el chip).
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()

        let cashflowCard = app.buttons["more_card_flujoDeCaja"]
        XCTAssertTrue(cashflowCard.waitForExistence(timeout: 5), "No apareció la card Flujo de Caja en Más.")
        cashflowCard.tap()

        // CashFlowSetupView monta (header presente con o sin sugerencias).
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "cashflow_setup_view").firstMatch.waitForExistence(timeout: 15),
            "La vista de Flujo de Caja no montó (cashflow_setup_view)."
        )
    }

    // MARK: - Lote 18 de la auditoría UX 2.2

    /// Abre Flujo de caja con la semilla `realista` (hace falta volumen: con `minimal` el asistente puede no
    /// sugerir líneas), salta la guía y crea el plan. Devuelve con el plan del mes en curso en pantalla.
    private func openFreshPlan(_ app: XCUIApplication) {
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()
        let cashflowCard = app.buttons["more_card_flujoDeCaja"]
        XCTAssertTrue(cashflowCard.waitForExistence(timeout: 5), "No apareció la card Flujo de Caja en Más.")
        cashflowCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "cashflow_setup_view").firstMatch.waitForExistence(timeout: 15),
            "La vista de Flujo de Caja no montó (cashflow_setup_view)."
        )
        skipCoachMarkIfShown(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        let title = app.staticTexts["cashflow_month_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "El plan no se creó (falta el título del mes).")
        skipCoachMarkIfShown(app)
    }

    /// La guía de pasos sale a los 0,5-1 s de montar la pantalla y, mientras está, el scroll está apagado.
    private func skipCoachMarkIfShown(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    private func detailLines(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "cashflow_detail_line")
    }

    /// Bug: un `DragGesture` para cambiar de mes se quedaba el arrastre vertical y la lista del mes no se
    /// desplazaba con el dedo (solo arrastrando desde la tira de meses). Ahora el arrastre vertical mueve la
    /// lista y el horizontal cambia de mes, sin abrir la hoja de la fila que estaba debajo.
    func test_monthDetail_scrollsWithAFingerOnTheList_andASideSwipeChangesMonth() {
        let app = XCUIApplication()
        openFreshPlan(app)

        let row = detailLines(app).element(boundBy: 3)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No hay filas en el detalle del mes.")
        let anchor = detailLines(app).element(boundBy: 0)
        XCTAssertTrue(app.waitForSettledLayout(of: anchor), "El detalle no se quedó quieto.")
        let before = anchor.frame.minY

        row.swipeUp()
        XCTAssertTrue(app.waitForSettledLayout(of: anchor), "El scroll no se asentó.")
        // Con el bug la lista no se movía nada; un desplazamiento real son cientos de puntos.
        XCTAssertLessThan(anchor.frame.minY, before - 100, "La lista del mes no se desplazó al arrastrar sobre ella.")

        let title = app.staticTexts["cashflow_month_title"]
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let monthBefore = title.label
        detailLines(app).element(boundBy: 1).swipeLeft()
        let changed = NSPredicate(format: "label != %@", monthBefore)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: changed, object: title)], timeout: 5),
            .completed,
            "Deslizar a la izquierda no cambió de mes."
        )
        XCTAssertFalse(
            app.scrollViews["cashflow_cell_detail"].exists,
            "El deslizamiento abrió además la hoja de la fila."
        )
    }

    /// Bug: el menú de una línea borraba al instante, con la pregunta de confirmación como texto del botón,
    /// y la línea borrada seguía en pantalla hasta salir y volver. Ahora pregunta (con «Cancelar» visible) y la
    /// línea se va en cuanto se confirma.
    func test_lineMenu_asksBeforeDeleting_andTheLineLeavesRightAway() {
        let app = XCUIApplication()
        openFreshPlan(app)

        let rows = detailLines(app)
        XCTAssertTrue(rows.element(boundBy: 2).waitForExistence(timeout: 10))
        let countBefore = rows.count

        rows.element(boundBy: 2).press(forDuration: 1.0)
        let delete = app.buttons["cashflow_line_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El menú de la línea no ofreció «Eliminar línea».")
        delete.tap()

        let cancel = app.alerts.buttons["cashflow_line_delete_cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Borrar no pidió confirmación (o no se ve «Cancelar»).")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(rows.count, countBefore, "Cancelar borró la línea.")

        rows.element(boundBy: 2).press(forDuration: 1.0)
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let confirm = app.alerts.buttons["cashflow_line_delete_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let oneLess = NSPredicate(format: "count == %d", countBefore - 1)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: oneLess, object: rows)], timeout: 5),
            .completed,
            "La línea borrada siguió en pantalla."
        )
    }

    /// Bug: guardar el horizonte no recalculaba el plan; la tira seguía con los meses de antes hasta salir y
    /// volver. Ahora se aplica al guardar.
    func test_horizon_appliesAsSoonAsItIsSaved() {
        let app = XCUIApplication()
        openFreshPlan(app)

        let capsules = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cashflow_month_capsule_'"))
        XCTAssertTrue(capsules.firstMatch.waitForExistence(timeout: 10))
        let countBefore = capsules.count

        let menu = app.buttons["cashflow_more_menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "No apareció el menú (···) del plan.")
        menu.tap()
        let horizon = app.buttons["cashflow_configure_horizon"]
        XCTAssertTrue(horizon.waitForExistence(timeout: 5), "El menú no ofreció «Configurar horizonte».")
        horizon.tap()

        let ahead = app.steppers["cashflow_horizon_ahead"]
        XCTAssertTrue(ahead.waitForExistence(timeout: 5), "No apareció el horizonte.")
        let decrement = ahead.buttons.element(boundBy: 0)
        for _ in 0..<3 { decrement.tap() }
        app.buttons["primary_button"].tap()

        let fewer = NSPredicate(format: "count == %d", countBefore - 3)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fewer, object: capsules)], timeout: 5),
            .completed,
            "La tira no cambió al guardar el horizonte (tenía \(countBefore), sigue con \(capsules.count))."
        )
    }

    /// Bug: «Reiniciar plan» preguntaba en un globo anclado a media pantalla sin «Cancelar» a la vista, y
    /// reiniciar borra todas las líneas y ajustes. Ahora es una alerta con las dos salidas.
    func test_resetPlan_asksWithAVisibleCancel() {
        let app = XCUIApplication()
        openFreshPlan(app)

        let menu = app.buttons["cashflow_more_menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let reset = app.buttons["cashflow_reset_plan"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "El menú no ofreció «Reiniciar plan».")
        reset.tap()

        let cancel = app.alerts.buttons["cashflow_reset_cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Reiniciar no ofreció «Cancelar» a la vista.")
        cancel.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 5), "Cancelar reinició el plan.")

        menu.tap()
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        let confirm = app.alerts.buttons["cashflow_reset_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "cashflow_setup_view").firstMatch.waitForExistence(timeout: 10),
            "Tras reiniciar no volvió el asistente."
        )
    }
}
