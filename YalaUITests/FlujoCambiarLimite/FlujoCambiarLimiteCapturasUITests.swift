//
//  FlujoCambiarLimiteCapturasUITests.swift
//  YalaUITests
//
//  Capturas de «Cambiar límite» del flujo de caja (S4 del replanteo, 18-nov-2026): el detalle de una línea del mes en
//  curso y lo que sale al tocar «Ajustar monto» (antes: el campo y la alerta de alcance; después: la hoja nueva), y la
//  misma hoja en un mes pasado. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`. Opcionales:
//  `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto), `TEST_RUNNER_CAPTURA_TEMA=claro` y `TEST_RUNNER_CAPTURA_PREFIJO`.
//  Sin la carpeta, se salta.
//

import XCTest

final class FlujoCambiarLimiteCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = []
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if env["CAPTURA_TEMA"] == "claro" { extra += ["-userTheme", "1"] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"

        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: extra)
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

        openFirstExpenseLine(app)
        let sheet = app.scrollViews["cashflow_cell_detail"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "No se abrió el detalle de la línea.")
        let adjust = app.buttons["cashflow_adjust_amount"]
        var tries = 0
        while adjust.exists, !adjust.isHittable, tries < 6 { sheet.swipeUp(); tries += 1 }
        pause(0.8)
        shot(app, "\(prefijo)-1-detalle-de-linea")
        adjust.tap()
        pause(1.2)

        let nueva = app.descendants(matching: .any)["flujo_cambiar_limite"].firstMatch
        if nueva.waitForExistence(timeout: 3) {
            shot(app, "\(prefijo)-2-hoja")
            let solo = app.buttons["flujo_cambiar_limite_alcance_soloEsteMes"]
            if solo.waitForExistence(timeout: 3) { solo.tap() }
            pause(0.8)
            shot(app, "\(prefijo)-3-solo-este-mes")
            // Un monto nuevo, para que «Así quedan» enseñe el antes y el después.
            let field = app.textFields["flujo_cambiar_limite_monto"]
            if field.waitForExistence(timeout: 3) {
                // El cursor al final del texto, o el borrado deja dígitos a la izquierda.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
                let current = (field.value as? String) ?? ""
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 4))
                field.typeText("2500")
            }
            let hoja = app.scrollViews["flujo_cambiar_limite"]
            let todos = app.buttons["flujo_cambiar_limite_alcance_todos"]
            if todos.waitForExistence(timeout: 3) { todos.tap() }
            arrastrarHaciaArriba(hoja)
            pause(0.8)
            shot(app, "\(prefijo)-4-todos-con-monto")
            let desde = app.buttons["flujo_cambiar_limite_alcance_desdeEsteMes"]
            if desde.waitForExistence(timeout: 3) { desde.tap() }
            arrastrarHaciaArriba(hoja)
            pause(0.8)
            shot(app, "\(prefijo)-5-desde-asi-quedan")
        } else {
            // Antes: el campo dentro del detalle y, al guardar, la alerta de alcance.
            let field = app.textFields["cashflow_adjust_amount_field"]
            if field.waitForExistence(timeout: 5) {
                field.tap()
                pause(1)
                shot(app, "\(prefijo)-2-campo")
                let save = app.buttons["cashflow_adjust_keyboard_save"]
                if save.waitForExistence(timeout: 3) { save.tap() }
                pause(1)
                shot(app, "\(prefijo)-3-alerta-de-alcance")
            }
        }
    }

    /// La primera línea de gastos del mes en curso (las dos primeras filas son los ingresos de la semilla).
    private func openFirstExpenseLine(_ app: XCUIApplication) {
        let rows = app.buttons.matching(identifier: "cashflow_detail_line")
        let row = rows.element(boundBy: 2)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No hay líneas de gasto en el mes.")
        var tries = 0
        while row.exists, row.frame.maxY > app.frame.height * 0.7, tries < 8 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        row.tap()
    }

    /// Arrastra desde la parte alta de la hoja (no desde el campo, que se queda el gesto) para que baje y cierre el teclado.
    private func arrastrarHaciaArriba(_ hoja: XCUIElement) {
        let desde = hoja.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
        desde.press(forDuration: 0.05, thenDragTo: hoja.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)))
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }
}
