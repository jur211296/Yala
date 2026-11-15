//
//  FlujoNecesariasLote08UITests.swift
//  YalaUITests
//
//  Lote 08 de mejoras necesarias 2.3 (Flujo de caja). Un caso por punto que se ve; los tres dejan capturas
//  (`XCTAttachment`) que sirven de evidencia de antes y después.
//  (1) «Gastos no considerados» enseña el mes desde el que se abre, no siempre el mes en curso.
//  (2) El detalle de una línea de un mes pasado no dice «vs».
//  (3) El vacío de Flujo de caja no habla de un período.
//  El contraste de «Te quedó» (punto 4) no se lee en XCUITest: lo fija `FlujoNecesariasLote08Tests`; aquí solo se
//  captura la tarjeta.
//

import XCTest

final class FlujoNecesariasLote08UITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func attach(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func skipCoachMarkIfShown(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    /// Semilla `realista` (hace falta volumen y meses pasados), Pro (tres meses atrás) y el plan sugerido creado.
    private func openFreshPlan(_ app: XCUIApplication) {
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(element(app, "cashflow_setup_view").firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMarkIfShown(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMarkIfShown(app)
    }

    /// Clave «AAAA-MM» del mes que está `offset` meses del actual, con el calendario de la app (misma zona).
    private func monthKey(offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    private func selectMonth(_ app: XCUIApplication, offset: Int) {
        let capsule = app.buttons["cashflow_month_capsule_\(monthKey(offset: offset))"]
        XCTAssertTrue(capsule.waitForExistence(timeout: 10), "No está el mes \(monthKey(offset: offset)) en la tira.")
        let title = app.staticTexts["cashflow_month_title"]
        let before = title.label
        capsule.tap()
        if offset != 0 {
            let changed = NSPredicate(format: "label != %@", before)
            _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: changed, object: title)], timeout: 5)
        }
    }

    /// Baja hasta la fila «Otros gastos» y la toca. Devuelve los importes de la hoja, de arriba abajo.
    private func othersAmounts(_ app: XCUIApplication, shot: String) -> [String] {
        let row = app.buttons["cashflow_others_expense_row"]
        var drags = 0
        while !(row.exists && row.isHittable), drags < 10 { app.swipeUp(); drags += 1 }
        XCTAssertTrue(row.exists, "No está la fila «Otros gastos» en este mes.")
        row.tap()
        let amounts = app.descendants(matching: .any).matching(identifier: "cashflow_others_item_amount")
        XCTAssertTrue(amounts.firstMatch.waitForExistence(timeout: 8), "La hoja de no considerados no enseña nada.")
        attach(shot, app)
        let labels = (0..<min(amounts.count, 6)).map { amounts.element(boundBy: $0).label }
        app.swipeDown(velocity: .fast)
        _ = amounts.firstMatch.waitForNonExistence(timeout: 5)
        return labels
    }

    // MARK: - (1) y (2) · Hoja de no considerados y detalle de un mes pasado

    /// Bug: la hoja leía siempre el mes en curso. Abierta desde el mes pasado, enseñaba lo de este mes.
    /// Y el detalle de una línea del mes pasado decía «Gastaste X vs estimado Y», con «vs» en los 16 idiomas.
    func test_othersSheet_showsTheMonthItOpenedFrom_andPastLineDetailHasNoVs() {
        let app = XCUIApplication()
        openFreshPlan(app)

        selectMonth(app, offset: 0)
        let current = othersAmounts(app, shot: "no-considerados-mes-en-curso")

        app.swipeDown()
        app.swipeDown()
        selectMonth(app, offset: -1)
        let previous = othersAmounts(app, shot: "no-considerados-mes-pasado")

        XCTAssertNotEqual(previous, current,
                          "Abierta desde el mes pasado, la hoja enseña los mismos importes que la del mes en curso.")

        // (2) El detalle de una línea del mes pasado.
        app.swipeDown()
        app.swipeDown()
        let line = app.buttons.matching(identifier: "cashflow_detail_line").firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 10), "No hay líneas en el mes pasado.")
        line.tap()
        let detail = app.scrollViews["cashflow_cell_detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 8), "No se abrió el detalle de la línea.")
        attach("detalle-linea-mes-pasado", app)
        let vs = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' vs '"))
        XCTAssertEqual(vs.count, 0, "El detalle de la línea sigue diciendo «vs»: \(vs.firstMatch.label)")

        // Decisión 35: en Gráficas, la frase de «Gastos por revisar» dice que es un promedio. Solo captura: la frase la
        // fija `CashFlowDeviationCommentPeriodTests`.
        app.swipeDown(velocity: .fast)
        _ = detail.waitForNonExistence(timeout: 5)
        let charts = app.buttons["cashflow_charts_button"]
        if charts.waitForExistence(timeout: 5) {
            charts.tap()
            let deviation = element(app, "cashflow_chart_deviation_row")
            var drags = 0
            while !(deviation.exists && deviation.isHittable), drags < 10 { app.swipeUp(); drags += 1 }
            app.swipeUp()
            attach("graficas-gastos-por-revisar", app)
        }
    }

    // MARK: - (3) · Vacío de Flujo de caja

    /// Bug: sin registros, Flujo de caja decía «No hay registros en este período», y el flujo de caja no tiene período.
    func test_emptyCashFlow_doesNotTalkAboutAPeriod() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openReport("flujoDeCaja")
        let empty = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'flujo de caja' OR label CONTAINS[c] 'período'"))
        XCTAssertTrue(empty.firstMatch.waitForExistence(timeout: 10), "No apareció el vacío de Flujo de caja.")
        attach("flujo-de-caja-vacio", app)
        let period = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'período' OR label CONTAINS[c] 'periodo'"))
        XCTAssertEqual(period.count, 0, "El vacío de Flujo de caja habla de un período: \(period.firstMatch.label)")
    }

    // MARK: - (4) · Captura de «Te quedó»

    func test_netSummary_capture() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("comparativa")
        let thisMonth = app.buttons["report_all_time_thisMonth"]
        if thisMonth.waitForExistence(timeout: 10) { thisMonth.tap() }
        let summary = element(app, "report_net_summary")
        var drags = 0
        while !(summary.exists && summary.isHittable), drags < 12 { app.swipeUp(); drags += 1 }
        XCTAssertTrue(summary.exists, "No está la tarjeta «Te quedó».")
        attach("comparativa-te-quedo", app)
    }
}
