//
//  FlujoFluidezMedicionUITests.swift
//  YalaUITests
//
//  Conductor de la medición de fluidez de Reportes (encargo del 20-nov-2026): el mismo recorrido antes y después, con
//  10 años de datos. No fija nada: deja en el log de la app los milisegundos de cada cálculo (`FlujoFluidezMedida`,
//  `LoadTimeMarks`) y, con `simctl io recordVideo` alrededor, el vídeo de la parte de arriba. Se corre a mano con
//  `TEST_RUNNER_FLUIDEZ_MEDIR=1`; sin ella, se salta.
//

import XCTest

final class FlujoFluidezMedicionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipIf(ProcessInfo.processInfo.environment["FLUIDEZ_MEDIR"] == nil, "Solo a mano, con TEST_RUNNER_FLUIDEZ_MEDIR.")
    }

    func test_recorrido() {
        let env = ProcessInfo.processInfo.environment
        let seed = env["FLUIDEZ_SEMILLA"] ?? "pesado"
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed)
        XCTAssertTrue(app.waitForUITestReady(timeout: 120), "uitest_ready ausente.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 60),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 30), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 60), "El plan no se creó.")
        skipCoachMark(app)
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        pause(2)

        // 1 · Ir y volver entre Comparativa y Flujo de caja.
        marca(app, "chips")
        for _ in 0..<3 {
            tap(app.buttons["report_chip_comparativa"])
            pause(1.5)
            tap(app.buttons["report_chip_flujoDeCaja"])
            pause(1.5)
        }

        // 2 · Cambiar de mes.
        marca(app, "meses")
        for offset in [-1, -2, -1, 0, 1, 2, 0] {
            select(app, offset: offset)
            pause(1)
        }

        // 3 · Scroll de la lista del mes.
        marca(app, "scroll")
        app.swipeUp(velocity: .slow)
        pause(1)
        app.swipeUp(velocity: .slow)
        pause(1)
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        pause(1.5)

        // 4 · Ver en Registros con el filtro de una línea y volver.
        marca(app, "registros")
        for _ in 0..<2 {
            let line = app.descendants(matching: .any)["cashflow_detail_line"].firstMatch
            guard line.waitForExistence(timeout: 10) else { XCTFail("Sin líneas en el mes."); break }
            line.tap()
            let see = app.buttons["cashflow_line_see_in_records"]
            var tries = 0
            while !see.exists, tries < 6 { app.swipeUp(velocity: .slow); tries += 1 }
            guard see.waitForExistence(timeout: 5) else { XCTFail("Sin «Ver en Registros»."); break }
            see.tap()
            pause(3)
            app.openReport("flujoDeCaja")
            pause(3)
        }

        // 5 · La Comparativa: entrar, bajar y subir.
        marca(app, "comparativa")
        tap(app.buttons["report_chip_comparativa"])
        pause(2)
        app.swipeUp(velocity: .slow)
        pause(1)
        app.swipeDown(velocity: .fast)
        pause(1.5)
        tap(app.buttons["report_chip_flujoDeCaja"])
        pause(2)
        marca(app, "fin")
    }

    /// El rebote de Jürgen (20-nov): bajar bastante en el Flujo de caja y lanzar rápido hacia arriba; arriba se quedaba
    /// «pegado rebotando» en el título. Lo mismo en la Comparativa. Se mira en el vídeo.
    func test_rebote() {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: env["FLUIDEZ_SEMILLA"] ?? "realista")
        XCTAssertTrue(app.waitForUITestReady(timeout: 120), "uitest_ready ausente.")
        // Control: el mismo gesto en el Panel.
        pause(3)
        for _ in 0..<5 { app.swipeUp(velocity: .fast) }
        pause(1)
        marca(app, "rebote panel")
        app.swipeDown(velocity: 4_000)
        pause(4)
        app.openReport("flujoDeCaja")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 60),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 30), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 60), "El plan no se creó.")
        skipCoachMark(app)
        for pantalla in ["flujo", "comparativa"] {
            if pantalla == "comparativa" {
                tap(app.buttons["report_chip_comparativa"])
                pause(1.5)
                let lastMonth = app.buttons["report_all_time_lastMonth"]
                if lastMonth.waitForExistence(timeout: 3) { lastMonth.tap() }
                pause(1.5)
            }
            for vuelta in 0..<2 {
                for _ in 0..<5 { app.swipeUp(velocity: .fast) }
                pause(1)
                marca(app, "rebote \(pantalla) \(vuelta)")
                app.swipeDown(velocity: 4_000)
                pause(4)
            }
        }
        marca(app, "fin")
    }

    /// Una marca en el log del runner para cruzar con el vídeo y con el log de la app.
    private func marca(_ app: XCUIApplication, _ nombre: String) {
        NSLog("FLUIDEZ marca \(nombre)")
    }

    private func tap(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 10) { element.tap() } else { XCTFail("No está \(element.identifier).") }
    }

    private func select(_ app: XCUIApplication, offset: Int) {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: date)
        let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        let capsule = app.buttons["cashflow_month_capsule_\(key)"]
        if capsule.waitForExistence(timeout: 5) { capsule.tap() }
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }
}
