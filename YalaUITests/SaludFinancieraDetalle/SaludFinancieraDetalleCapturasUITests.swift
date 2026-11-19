//
//  SaludFinancieraDetalleCapturasUITests.swift
//  YalaUITests
//
//  Capturas de la hoja de la nota de salud (18-nov-2026): la hoja abierta y bajando hasta el final, con la semilla
//  `realista` y los presupuestos en sus cuatro estados. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`
//  (y opcionalmente `TEST_RUNNER_CAPTURA_TEXTO=<categoría>` para letra grande y `TEST_RUNNER_CAPTURA_TEMA=claro`); sin
//  la carpeta, se salta.
//

import XCTest

final class SaludFinancieraDetalleCapturasUITests: XCTestCase {

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
        // `TEST_RUNNER_CAPTURA_SEMILLA=cuenta-con-movimientos` enseña la hoja sin presupuestos ni pagos.
        let semilla = env["CAPTURA_SEMILLA"]
        app.launchForUITest(pro: true, seed: semilla ?? "realista", budgetStates: semilla == nil, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")

        let card = app.buttons["panel_health_compact"]
        XCTAssertTrue(card.waitForExistence(timeout: 30), "La nota de salud no sale en el Panel.")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["health_breakdown"].waitForExistence(timeout: 10))
        _ = app.descendants(matching: .any)["health_section_streak"].waitForExistence(timeout: 15)
        pause(1)
        shot(app, "\(prefijo)-1")

        let scroll = app.scrollViews.element(boundBy: app.scrollViews.count - 1)
        for indice in 2...6 {
            scroll.swipeUp(velocity: .slow)
            pause(0.8)
            shot(app, "\(prefijo)-\(indice)")
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
