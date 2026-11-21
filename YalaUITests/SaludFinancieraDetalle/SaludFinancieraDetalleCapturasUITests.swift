//
//  SaludFinancieraDetalleCapturasUITests.swift
//  YalaUITests
//
//  Capturas de la hoja de la nota de salud: los seis estados de las maquetas (todo bien, presupuesto excedido, no
//  alcanza, sin presupuestos, sin pagos planificados, sin Pro) con la muestra `-uitest-salud-estado`, o la semilla
//  `realista` con `TEST_RUNNER_CAPTURA_ESTADOS=realista`. No fija nada. Se corre a mano con
//  `TEST_RUNNER_CAPTURA_DIR=<carpeta>` (y opcionalmente `TEST_RUNNER_CAPTURA_TEXTO=<categoría>` para letra grande,
//  `TEST_RUNNER_CAPTURA_TEMA=claro` y `TEST_RUNNER_CAPTURA_PREFIJO`); sin la carpeta, se salta.
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
        let estados = (env["CAPTURA_ESTADOS"] ?? "noalcanza,excedido,bien,sinpres,sinpagos,sinpro")
            .split(separator: ",").map(String.init)
        let pantallas = Int(env["CAPTURA_PANTALLAS"] ?? "") ?? 4

        for estado in estados {
            let app = XCUIApplication()
            if estado == "realista" {
                app.launchForUITest(pro: true, seed: "realista", budgetStates: true, extraArguments: extra)
            } else {
                app.launchForUITest(pro: estado != "sinpro", seed: "minimal",
                                    extraArguments: extra + ["-uitest-salud-estado", estado])
            }
            XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")

            let card = app.buttons["panel_health_compact"]
            XCTAssertTrue(card.waitForExistence(timeout: 30), "La nota de salud no sale en el Panel.")
            card.tap()
            XCTAssertTrue(app.descendants(matching: .any)["health_breakdown"].waitForExistence(timeout: 10))
            _ = app.descendants(matching: .any)["health_section_ritmo"].waitForExistence(timeout: 15)
            pause(1)
            shot(app, "\(prefijo)-\(estado)-1")

            let scroll = app.scrollViews.element(boundBy: app.scrollViews.count - 1)
            if pantallas > 1 {
                for indice in 2...pantallas {
                    scroll.swipeUp(velocity: .slow)
                    pause(0.8)
                    shot(app, "\(prefijo)-\(estado)-\(indice)")
                }
            }
            app.terminate()
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
