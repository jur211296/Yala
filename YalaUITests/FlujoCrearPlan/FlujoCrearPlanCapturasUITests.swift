//
//  FlujoCrearPlanCapturasUITests.swift
//  YalaUITests
//
//  Capturas de crear el plan del flujo de caja (S5 del replanteo, 18-nov-2026): la cabecera, las líneas propuestas,
//  los gastos que cambian desplegados y «Agregar línea › Desde mis gastos» con una subcategoría elegida. No fija nada.
//  Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`. Opcionales: `TEST_RUNNER_CAPTURA_TEXTO` (categoría de
//  texto), `TEST_RUNNER_CAPTURA_TEMA=claro` y `TEST_RUNNER_CAPTURA_PREFIJO`. Sin la carpeta, se salta.
//

import XCTest

final class FlujoCrearPlanCapturasUITests: XCTestCase {

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
                      "El armado del plan no montó.")
        pause(1.2)
        shot(app, "\(prefijo)-1-arriba")

        app.swipeUp(velocity: .slow)
        pause(0.8)
        shot(app, "\(prefijo)-2-lineas")

        let toggle = app.buttons["cashflow_setup_variable_toggle"]
        var tries = 0
        while !(toggle.exists && toggle.isHittable), tries < 10 { app.swipeUp(velocity: .slow); tries += 1 }
        if toggle.exists {
            toggle.tap()
            pause(0.8)
            app.swipeUp(velocity: .slow)
            pause(0.8)
            shot(app, "\(prefijo)-3-gastos-que-cambian")
        }

        // Crear el plan y abrir «Agregar línea › Desde mis gastos».
        let create = app.buttons["primary_button"]
        tries = 0
        while !(create.exists && create.isHittable), tries < 14 { app.swipeUp(); tries += 1 }
        guard create.exists else { return XCTFail("No apareció «Crear mi plan».") }
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMark(app)

        let add = app.buttons["cashflow_add_line_expense"]
        tries = 0
        while !(add.exists && add.isHittable), tries < 14 { app.swipeUp(); tries += 1 }
        guard add.exists else { return XCTFail("No está «Agregar línea» de gastos.") }
        add.tap()
        let fromExpenses = app.buttons["cashflow_add_from_expenses"]
        guard fromExpenses.waitForExistence(timeout: 5) else { return XCTFail("No está «Desde mis gastos».") }
        fromExpenses.tap()
        pause(1)
        let firstCategory = app.buttons.matching(identifier: "cashflow_add_category").firstMatch
        if firstCategory.waitForExistence(timeout: 5) {
            firstCategory.tap()
            pause(0.6)
            // La primera que aún no está en el plan (las que ya tienen línea salen apagadas desde el 27-nov-2026).
            let firstSub = app.buttons.matching(identifier: "cashflow_add_subcategory")
                .matching(NSPredicate(format: "enabled == true")).firstMatch
            if firstSub.waitForExistence(timeout: 3) { firstSub.tap() }
            pause(0.8)
        }
        shot(app, "\(prefijo)-4-agregar-linea")
        app.swipeUp(velocity: .slow)
        pause(0.8)
        shot(app, "\(prefijo)-5-agregar-linea-limite")
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
