//
//  FlujoDetalleLineaUITests.swift
//  YalaUITests
//
//  S3 del replanteo del flujo de caja (18-nov-2026): el detalle de una línea pone el límite arriba con «Cambiar», debajo
//  seis meses de real contra límite y todos los registros del mes por día; «‹ mes ›» cambia de mes sin salir, y «Ver en
//  Registros» lleva a Registros con esa línea filtrada.
//

import XCTest

final class FlujoDetalleLineaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Crea el plan con la semilla y abre la primera línea de gastos del mes en curso. Devuelve su nombre.
    @discardableResult
    private func openFirstExpenseLine(_ app: XCUIApplication) -> String {
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMark(app)

        // Las dos primeras filas son los ingresos de la semilla.
        let row = app.buttons.matching(identifier: "cashflow_detail_line").element(boundBy: 2)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No hay líneas de gasto en el mes.")
        let name = String(row.label.split(separator: ",").first ?? "")
        // Arrastres cortos hasta dejar la fila en la franja central: un `swipeUp` la subía bajo la barra de arriba y el
        // toque no la abría (`testing.md`, «`isHittable` tampoco»).
        let height = app.frame.height
        var tries = 0
        while row.frame.midY > height * 0.6, tries < 12 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
            tries += 1
        }
        let detail = app.scrollViews["cashflow_cell_detail"]
        row.tap()
        if !detail.waitForExistence(timeout: 4) { row.tap() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "No se abrió el detalle.")
        return name
    }

    /// Arriba el límite con «Cambiar», y por debajo, en este orden, los seis meses y los registros por día.
    func test_elLimiteVaArriba_yDebajoLosSeisMesesYLosRegistrosPorDia() {
        let app = XCUIApplication()
        openFirstExpenseLine(app)

        let cambiar = app.buttons["cashflow_adjust_amount"]
        XCTAssertTrue(cambiar.waitForExistence(timeout: 5), "No hay «Cambiar» junto al límite.")
        XCTAssertTrue(cambiar.isHittable, "«Cambiar» tiene que verse al abrir, sin desplazar.")
        let limite = app.descendants(matching: .any)["cashflow_detail_planned_amount"].firstMatch
        XCTAssertTrue(limite.exists, "No está la cifra del límite.")
        XCTAssertLessThan(abs(limite.frame.midY - cambiar.frame.midY), 60, "«Cambiar» va en la fila del límite.")

        let grafica = app.descendants(matching: .any)["cashflow_line_history_chart"].firstMatch
        XCTAssertTrue(grafica.waitForExistence(timeout: 5), "No están los seis meses.")
        XCTAssertGreaterThan(grafica.frame.minY, cambiar.frame.maxY, "Los seis meses van debajo del límite.")

        let sheet = app.scrollViews["cashflow_cell_detail"]
        let dia = app.descendants(matching: .any).matching(identifier: "cashflow_line_records_day").firstMatch
        var tries = 0
        while !dia.exists, tries < 6 { sheet.swipeUp(); tries += 1 }
        XCTAssertTrue(dia.waitForExistence(timeout: 3), "No hay registros agrupados por día.")
        XCTAssertGreaterThan(dia.frame.minY, grafica.frame.minY, "Los registros van debajo de los seis meses.")
        // Ya no hay «Ajustar monto» al pie ni la tira de meses.
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cashflow_detail_timeline_'")).firstMatch.exists)
    }

    /// 19-nov-2026: un solo «Cambiar» (el de «Cómo se calcula» se retiró), y tocar una barra de los seis meses cambia la
    /// lista de registros a ese mes; «Volver a…» regresa al mes que se ve.
    func test_unSoloCambiar_yTocarUnMesCambiaLosRegistros() {
        let app = XCUIApplication()
        openFirstExpenseLine(app)

        XCTAssertTrue(app.buttons["cashflow_adjust_amount"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cashflow_detail_change_method"].exists, "Volvió el segundo «Cambiar».")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_detail_how"].firstMatch.exists,
                      "«Cómo se calcula» tiene que decir cómo sale el límite.")

        let sheet = app.scrollViews["cashflow_cell_detail"]
        let grafica = app.descendants(matching: .any)["cashflow_line_history_chart"].firstMatch
        XCTAssertTrue(grafica.waitForExistence(timeout: 5), "No están los seis meses.")
        var tries = 0
        while grafica.frame.maxY > app.frame.height * 0.7, tries < 6 {
            let from = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            from.press(forDuration: 0.05, thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            tries += 1
        }
        // La tercera barra (tres meses atrás): sobre el área de la gráfica, que deja el eje a la derecha.
        grafica.coordinate(withNormalizedOffset: CGVector(dx: 2.5 / 6 * 0.86, dy: 0.55)).tap()
        let volver = app.buttons["cashflow_line_records_back"]
        XCTAssertTrue(volver.waitForExistence(timeout: 5), "Tocar un mes no cambió la lista de registros.")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_line_records_total"].firstMatch.exists,
                      "La lista de otro mes dice su total.")
        tries = 0
        while !volver.isHittable, tries < 4 { sheet.swipeUp(); tries += 1 }
        volver.tap()
        XCTAssertTrue(volver.waitForNonExistence(timeout: 5), "«Volver» no regresó al mes que se ve.")
    }

    /// «‹ mes ›» recorre el plan sin salir del detalle.
    func test_lasFlechasCambianDeMes() {
        let app = XCUIApplication()
        openFirstExpenseLine(app)
        let mes = app.staticTexts["cashflow_detail_month"]
        XCTAssertTrue(mes.waitForExistence(timeout: 5))
        let antes = mes.label
        let anterior = app.buttons["cashflow_detail_previous_month"]
        XCTAssertTrue(anterior.isEnabled, "La semilla tiene meses anteriores en el plan.")
        anterior.tap()
        let deadline = Date().addingTimeInterval(5)
        while mes.label == antes, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertNotEqual(mes.label, antes, "La flecha no cambió de mes.")
        // Un mes cerrado dice lo gastado contra el límite.
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_detail_closed"].firstMatch.waitForExistence(timeout: 5),
                      "El mes anterior no dice cuánto gastaste de cuánto.")
        app.buttons["cashflow_detail_next_month"].tap()
        let vuelta = Date().addingTimeInterval(5)
        while mes.label != antes, Date() < vuelta { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertEqual(mes.label, antes)
    }

    /// «Ver en Registros» cierra el detalle y abre Registros con la línea filtrada.
    func test_verEnRegistros_abreRegistrosConLaLineaFiltrada() {
        let app = XCUIApplication()
        let name = openFirstExpenseLine(app)
        let sheet = app.scrollViews["cashflow_cell_detail"]
        let ver = app.buttons["cashflow_line_see_in_records"]
        var tries = 0
        while !(ver.exists && ver.isHittable), tries < 6 { sheet.swipeUp(); tries += 1 }
        XCTAssertTrue(ver.waitForExistence(timeout: 3), "No hay «Ver en Registros».")
        ver.tap()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5), "«Ver en Registros» no cerró el detalle.")
        let chip = app.descendants(matching: .any)["records_quick_category"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No se abrió Registros.")
        let deadline = Date().addingTimeInterval(5)
        func filtrado() -> Bool { (chip.value as? String ?? "").contains(name) }
        while !filtrado(), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(filtrado(), "El chip «Categoría» no dice «\(name)» (dice «\(String(describing: chip.value))»).")
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }
}
