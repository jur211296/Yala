//
//  FlujoAisladosCapturasUITests.swift
//  YalaUITests
//
//  Capturas del antes y el después del encargo de aislados en las líneas por promedio (19-nov-2026): la línea «Fitness y
//  actividad física» con dos compras grandes (`-uitest-seed-flujo-aislados`), su método en Promedio 6 meses, la hoja de
//  «Cálculo del monto» (y con Monto fijo), el gráfico de 6 meses con un mes mantenido y elegido, y la hoja de gastos no
//  considerados de un mes que viene. No fija nada: corre igual sobre la build de antes y la de después. Se corre a mano
//  con `TEST_RUNNER_CAPTURA_DIR=<carpeta>` y `TEST_RUNNER_CAPTURA_PREFIJO=antes|despues`. Sin la carpeta, se salta.
//

import XCTest

final class FlujoAisladosCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = ["-uitest-seed-flujo-aislados"]
        extra += ["-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#]
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"

        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.selectTab(.reports)
        let chip = app.buttons["report_chip_flujoDeCaja"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No está el chip de Flujo de caja.")
        chip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMark(app)
        shot(app, "\(prefijo)-0-mes")

        guard openFitness(app) else { return }
        let sheet = app.scrollViews["cashflow_cell_detail"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "No se abrió el detalle de la línea.")
        pause(1)
        shot(app, "\(prefijo)-1-linea-como-se-creo")

        // A «Promedio 6 meses»: antes, por «Cómo se calcula · Cambiar»; después, por el único «Cambiar».
        let oldChange = app.buttons["cashflow_detail_change_method"]
        let change = oldChange.exists ? oldChange : app.buttons["cashflow_adjust_amount"]
        XCTAssertTrue(change.waitForExistence(timeout: 5), "No hay «Cambiar».")
        change.tap()
        pause(1.2)
        shot(app, "\(prefijo)-2-calculo-del-monto")
        let average = app.buttons["cashflow_method_average6m"].exists
            ? app.buttons["cashflow_method_average6m"]
            : app.staticTexts[methodName("average6m")].firstMatch
        if average.waitForExistence(timeout: 3) { average.tap() }
        pause(0.8)
        shot(app, "\(prefijo)-3-calculo-promedio")
        let manual = app.buttons["cashflow_method_manual"].exists
            ? app.buttons["cashflow_method_manual"]
            : app.staticTexts[methodName("manual")].firstMatch
        if manual.waitForExistence(timeout: 3) {
            manual.tap()
            pause(1.2)
            shot(app, "\(prefijo)-4-calculo-monto-fijo")
            if average.exists { average.tap() }
            pause(0.6)
        }
        let save = app.buttons["cashflow_method_save"].exists
            ? app.buttons["cashflow_method_save"] : app.buttons["toolbar_save_button"].firstMatch
        if save.waitForExistence(timeout: 3) { save.tap() }
        pause(1.5)
        shot(app, "\(prefijo)-5-linea-promedio")

        // El gráfico de 6 meses: mantener agosto (tres meses atrás) y tocarlo.
        let chart = app.descendants(matching: .any)["cashflow_line_history_chart"].firstMatch
        var tries = 0
        while chart.exists, chart.frame.maxY > app.frame.height * 0.75, tries < 6 {
            let from = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            from.press(forDuration: 0.05, thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            pause(0.6)
            tries += 1
        }
        shot(app, "\(prefijo)-6-grafico")
        if chart.exists {
            let bar = chart.coordinate(withNormalizedOffset: CGVector(dx: 2.5 / 6 * 0.86, dy: 0.55))
            bar.press(forDuration: 1.2)
            shot(app, "\(prefijo)-7-tooltip")
            bar.tap()
            pause(1)
            shot(app, "\(prefijo)-8-mes-elegido")
            let from = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            from.press(forDuration: 0.05, thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
            pause(0.8)
            shot(app, "\(prefijo)-9-registros-del-mes")
        }

        // Gastos no considerados de un mes que viene.
        app.buttons.matching(identifier: "cashflow_cell_detail_close").firstMatch.tapIfExists()
        let close = app.buttons[localizedClose()].firstMatch
        if close.exists { close.tap() }
        pause(1)
        shot(app, "\(prefijo)-9b-cerrado")
        let next = app.descendants(matching: .any)["cashflow_month_capsule_\(nextMonthKey())"].firstMatch
        if next.waitForExistence(timeout: 3) {
            next.tap()
            pause(1.2)
        }
        shot(app, "\(prefijo)-9c-mes-siguiente")
        let others = app.buttons["cashflow_others_expense_row"].firstMatch
        var scroll = 0
        while !(others.exists && others.isHittable) && scroll < 16 {
            app.swipeUp(velocity: .slow)
            scroll += 1
        }
        if others.exists {
            others.tap()
            pause(1.5)
            shot(app, "\(prefijo)-10-no-considerados-futuro")
            let sheetScroll = app.scrollViews.firstMatch
            if sheetScroll.exists {
                sheetScroll.swipeUp(velocity: .slow)
                pause(0.8)
                shot(app, "\(prefijo)-11-no-considerados-futuro-abajo")
            }
            // La hoja del mes en curso: lo real por subcategoría, agrupado por categoría.
            app.buttons[localizedClose()].firstMatch.tapIfExists()
            pause(1)
            let current = app.descendants(matching: .any)["cashflow_month_capsule_\(monthKey(offset: 0))"].firstMatch
            if current.waitForExistence(timeout: 3) {
                current.tap()
                pause(1.2)
            }
            let othersNow = app.buttons["cashflow_others_expense_row"].firstMatch
            var tries = 0
            while !(othersNow.exists && othersNow.isHittable) && tries < 16 {
                app.swipeUp(velocity: .slow)
                tries += 1
            }
            if othersNow.exists {
                othersNow.tap()
                pause(1.5)
                shot(app, "\(prefijo)-12-no-considerados-mes-en-curso")
                let scrollNow = app.scrollViews.firstMatch
                if scrollNow.exists {
                    scrollNow.swipeUp(velocity: .slow)
                    pause(0.8)
                    shot(app, "\(prefijo)-13-no-considerados-mes-en-curso-abajo")
                }
            }
        }
    }

    private func openFitness(_ app: XCUIApplication) -> Bool {
        let rows = app.buttons.matching(identifier: "cashflow_detail_line")
        let fitness = rows.matching(NSPredicate(format: "label CONTAINS[c] 'Fitness'")).firstMatch
        var tries = 0
        while !(fitness.exists && fitness.isHittable && fitness.frame.maxY < app.frame.height * 0.8), tries < 12 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        guard fitness.exists else {
            XCTFail("No hay línea de Fitness en el mes.")
            return false
        }
        fitness.tap()
        return true
    }

    private func methodName(_ raw: String) -> String {
        switch raw {
        case "average6m": return "Promedio 6 meses"
        case "manual": return "Monto fijo"
        default: return raw
        }
    }

    private func localizedClose() -> String { "Cerrar" }

    /// «2026-12» con hoy en noviembre de 2026.
    private func nextMonthKey() -> String { monthKey(offset: 1) }

    private func monthKey(offset: Int) -> String {
        let calendar = Calendar.current
        let next = calendar.date(byAdding: .month, value: offset, to: .now) ?? .now
        let c = calendar.dateComponents([.year, .month], from: next)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            pause(0.5)
        }
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }
}

private extension XCUIElement {
    func tapIfExists() {
        if exists { tap() }
    }
}
