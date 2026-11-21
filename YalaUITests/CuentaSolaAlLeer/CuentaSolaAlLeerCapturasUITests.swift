//
//  CuentaSolaAlLeerCapturasUITests.swift
//  YalaUITests
//
//  Capturas del después de la cuenta sola al leer (parte 1, 2026-11-20): elegida sola con su línea, sugerida, dos que
//  coinciden y choque, con el selector. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>` y, para el
//  tema claro, `TEST_RUNNER_CAPTURA_TEMA=claro`; sin la carpeta, se salta.
//

import XCTest

final class CuentaSolaAlLeerCapturasUITests: XCTestCase {

    private var folder: String?
    private var suffix = "oscuro"

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
        if ProcessInfo.processInfo.environment["CAPTURA_TEMA"] == "claro" { suffix = "claro" }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name)-\(suffix).png")
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

    private func open(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        let theme = suffix == "claro" ? ["-userTheme", "1"] : []
        app.launchForUITest(
            pro: true, seed: "ficha", aiConsent: true,
            extraArguments: ["-uitest-image-result", profile, "-uitest-image-autoclose-seconds", "4",
                             "-cuentaSola.porqueVeces", "0"] + theme)
        XCTAssertTrue(app.waitForUITestReady())
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15))
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15))
        pause(1)
        return app
    }

    private func openSelector(_ app: XCUIApplication) {
        app.buttons["voice_draft_chip_account"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        pause(1)
    }

    func test_capturas() {
        var app = open("cuenta-sola")
        shot(app, "despues-1-elegida-sola")
        app.terminate()

        app = open("cuenta-sola-sugerida")
        shot(app, "despues-2-sugerida")
        app.terminate()

        app = open("cuenta-sola-varias")
        shot(app, "despues-3-dos-coinciden")
        openSelector(app)
        shot(app, "despues-4-selector-coinciden")
        app.terminate()

        app = open("cuenta-sola-choque")
        openSelector(app)
        shot(app, "despues-5-selector-choque")
        app.terminate()
    }
}
