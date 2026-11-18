//
//  HojaCuentaTarjetaCapturasUITests.swift
//  YalaUITests
//
//  Capturas de la hoja de una cuenta del Panel (pedido de Jürgen del 17-nov-2026): la tarjeta personalizada arriba,
//  abierta a media altura y estirada. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>` y la cuenta
//  en `TEST_RUNNER_CAPTURA_CUENTA` (nombre sembrado). Opcionales: `TEST_RUNNER_CAPTURA_SEMILLA` (por defecto
//  `tarjeta-corte`), `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto), `TEST_RUNNER_CAPTURA_TEMA=claro` y
//  `TEST_RUNNER_CAPTURA_PREFIJO`. Sin la carpeta, se salta.
//

import XCTest

final class HojaCuentaTarjetaCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = ["-defaultPeriod", "last30Days"]
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if env["CAPTURA_TEMA"] == "claro" { extra += ["-userTheme", "1"] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"
        let cuenta = env["CAPTURA_CUENTA"] ?? "Visa QA"

        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: env["CAPTURA_SEMILLA"] ?? "tarjeta-corte", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 15), "La app no llegó al Panel.")

        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        let target = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(cuenta).")).firstMatch
        var swipes = 0
        while !target.exists && swipes < 8 {
            first.swipeLeft()
            swipes += 1
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), "No hay tarjeta de «\(cuenta)».")
        target.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["account_detail_sheet"].firstMatch.waitForExistence(timeout: 8),
            "No abrió la ficha."
        )
        pause(1.5)
        shot(app, "\(prefijo)-1")

        // Estirada: lo que se ve con la hoja grande, y bajando una vez.
        let middle = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.47))
        let top = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        middle.press(forDuration: 0.1, thenDragTo: top)
        pause(1.2)
        shot(app, "\(prefijo)-2")
        let scroll = app.scrollViews.element(boundBy: app.scrollViews.count - 1)
        scroll.swipeUp(velocity: .slow)
        pause(1)
        shot(app, "\(prefijo)-3")
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
