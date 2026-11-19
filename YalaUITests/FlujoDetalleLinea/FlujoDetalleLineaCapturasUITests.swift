//
//  FlujoDetalleLineaCapturasUITests.swift
//  YalaUITests
//
//  Capturas del detalle de una línea del flujo de caja (S3 del replanteo, 18-nov-2026): la hoja entera de una línea de
//  gastos del mes en curso, de arriba abajo. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`.
//  Opcionales: `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto), `TEST_RUNNER_CAPTURA_TEMA=claro`,
//  `TEST_RUNNER_CAPTURA_PREFIJO` y `TEST_RUNNER_CAPTURA_FILA` (índice de la fila del mes; por defecto la 5,
//  «Supermercados y tiendas» en la semilla `realista`, con registros en el mes). Sin la carpeta, se salta.
//

import XCTest

final class FlujoDetalleLineaCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = []
        // Reportes va en la barra: con texto de accesibilidad o en el SE la tarjeta de «Más» queda fuera del alcance
        // de XCUITest (`testing.md`, `LazyVGrid`).
        extra += ["-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#]
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if env["CAPTURA_TEMA"] == "claro" { extra += ["-userTheme", "1"] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"
        let fila = Int(env["CAPTURA_FILA"] ?? "") ?? 5

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

        openLine(app, index: fila)
        let sheet = app.scrollViews["cashflow_cell_detail"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5), "No se abrió el detalle de la línea.")
        pause(1)
        shot(app, "\(prefijo)-1-arriba")
        // De arriba abajo, en tramos cortos: cada captura solapa con la anterior.
        for tramo in 2...5 {
            let desde = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            desde.press(forDuration: 0.05, thenDragTo: sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
            pause(0.8)
            shot(app, "\(prefijo)-\(tramo)-bajando")
        }
    }

    private func openLine(_ app: XCUIApplication, index: Int) {
        let rows = app.buttons.matching(identifier: "cashflow_detail_line")
        let row = rows.element(boundBy: index)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No hay fila \(index) en el mes.")
        var tries = 0
        while row.exists, row.frame.maxY > app.frame.height * 0.7, tries < 8 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        row.tap()
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
