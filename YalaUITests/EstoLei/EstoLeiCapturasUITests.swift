//
//  EstoLeiCapturasUITests.swift
//  YalaUITests
//
//  Capturas del antes y el después de la hoja «Esto leí» con la tarjeta B1 (opción A, elegida por Jürgen el
//  2026-11-22): foto y voz, con uno, dos, varios y uno incompleto, y en el después también «Ver todo», el selector de
//  categoría y lo guardado. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`; sin esa variable,
//  se salta. `TEST_RUNNER_CAPTURA_TEMA=claro` lanza con el tema Claro (`-userTheme 1`); sin ella, el de siempre.
//  Los pasos que solo existen en el después (`esto_lei_ver_todo`) se saltan solos en el antes.
//

import XCTest

final class EstoLeiCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    private var themeArguments: [String] {
        ProcessInfo.processInfo.environment["CAPTURA_TEMA"] == "claro" ? ["-userTheme", "1"] : []
    }

    private var suffix: String {
        ProcessInfo.processInfo.environment["CAPTURA_TEMA"] == "claro" ? "" : "-oscuro"
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let device = isPad ? "ipad-" : ""
        let data = app.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(device)\(name)\(suffix).png")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }

    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if element.exists, element.isHittable {
                element.tap()
                return true
            }
            pause(0.3)
        }
        return false
    }

    // MARK: - Abrir

    private func openPhoto(_ profile: String, seed: String = "minimal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: seed, aiConsent: true,
            extraArguments: ["-uitest-image-result", profile, "-uitest-image-autoclose-seconds", "6",
                             "-cuentaSola.porqueVeces", "0"] + themeArguments)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        if isPad {
            XCTAssertTrue(tapWhenHittable(app.buttons["panel_action_image"], timeout: 15))
        } else {
            app.revealPanelFAB().tap()
            XCTAssertTrue(tapWhenHittable(app.buttons["fab_image"]))
        }
        XCTAssertTrue(tapWhenHittable(app.buttons["image_source_photos"], timeout: 15))
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20))
        pause(1.5)
        return app
    }

    private func openVoice(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: ["-uitest-voice-result", profile] + themeArguments)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        if isPad {
            XCTAssertTrue(tapWhenHittable(app.buttons["panel_action_voice"], timeout: 15))
        } else {
            app.revealPanelFAB().tap()
            XCTAssertTrue(tapWhenHittable(app.buttons["fab_voice"]))
        }
        XCTAssertTrue(tapWhenHittable(app.buttons["voice_done"], timeout: 15))
        XCTAssertTrue(app.staticTexts["voice_review_title"].waitForExistence(timeout: 20))
        pause(1.5)
        return app
    }

    /// «Ver todo» y vuelta con ‹ (solo en el después).
    private func shootSeeAll(_ app: XCUIApplication, _ name: String) {
        guard tapWhenHittable(app.buttons["esto_lei_ver_todo"].firstMatch, timeout: 3) else { return }
        XCTAssertTrue(app.buttons["draft_editor_back"].waitForExistence(timeout: 10))
        pause(1.2)
        shot(app, name)
        _ = tapWhenHittable(app.buttons["draft_editor_back"])
        pause(1)
    }

    // MARK: - Foto

    func test_foto_una() {
        let app = openPhoto("one")
        shot(app, "foto-una")
        shootSeeAll(app, "foto-una-ver-todo")
        if tapWhenHittable(app.buttons["image_save"], timeout: 3) {
            pause(0.6)
            shot(app, "foto-una-guardado")
        }
    }

    func test_foto_incompleta() {
        let app = openPhoto("incomplete")
        shot(app, "foto-incompleta")
        if tapWhenHittable(app.buttons["voice_draft_chip_subcategory"].firstMatch, timeout: 5) {
            pause(1.5)
            shot(app, "foto-incompleta-selector")
        }
    }

    func test_foto_dos() {
        let app = openPhoto("two")
        shot(app, "foto-dos")
    }

    func test_foto_varias() {
        let app = openPhoto("many")
        shot(app, "foto-varias")
        app.swipeUp()
        pause(1)
        shot(app, "foto-varias-abajo")
    }

    func test_foto_cuentaSola() {
        let app = openPhoto("cuenta-sola", seed: "ficha")
        shot(app, "foto-cuenta-sola")
    }

    // MARK: - Voz

    func test_voz_una() {
        let app = openVoice("one")
        shot(app, "voz-una")
        if tapWhenHittable(app.buttons["voice_said"], timeout: 2) {
            pause(1)
            shot(app, "voz-una-lo-que-dijiste")
        }
    }

    func test_voz_incompleta() {
        let app = openVoice("incomplete")
        shot(app, "voz-incompleta")
    }

    func test_voz_dos() {
        let app = openVoice("two")
        shot(app, "voz-dos")
    }
}
