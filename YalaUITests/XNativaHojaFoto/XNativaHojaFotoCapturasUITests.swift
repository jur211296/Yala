//
//  XNativaHojaFotoCapturasUITests.swift
//  YalaUITests
//
//  Capturas del antes y el después de la hoja de foto (encargo «X nativa, cabecera ordenada, descripción editable y
//  cierre automático», 2026-11-17): elegir, «Esto leí», editando la descripción y guardado, en personal (una y varias
//  fotos) y en Grupos. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`; sin esa variable, se salta.
//

import XCTest

final class XNativaHojaFotoCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let data = app.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    /// `TEST_RUNNER_CAPTURA_TEXTO=<categoría>` (p. ej. `UICTContentSizeCategoryAccessibilityL`) lanza con letra grande.
    private var textSizeArguments: [String] {
        guard let size = ProcessInfo.processInfo.environment["CAPTURA_TEXTO"] else { return [] }
        return ["-UIPreferredContentSizeCategoryName", size]
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

    /// Edita la primera descripción si la hoja ya lo permite (en el «antes» no existe y se salta).
    private func editFirstNote(_ app: XCUIApplication, name: String, typing: String?) {
        guard tapWhenHittable(app.buttons["image_draft_note"].firstMatch, timeout: 3) else { return }
        let field = app.textFields["image_draft_note_field"].firstMatch
        guard field.waitForExistence(timeout: 5) else { return }
        if let typing { field.typeText(typing) }
        pause(0.8)
        shot(app, name)
        field.typeText("\n")
        pause(0.8)
    }

    // MARK: - Personal

    private func openPersonal(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "records", aiConsent: true,
                            extraArguments: ["-uitest-image-result", profile] + textSizeArguments)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        XCTAssertTrue(tapWhenHittable(app.buttons["stats_action_image"]))
        XCTAssertTrue(app.buttons["image_source_photos"].waitForExistence(timeout: 15))
        pause(1)
        return app
    }

    func test_personal_una() {
        let app = openPersonal("one")
        shot(app, "personal-una-1-elegir")
        app.buttons["image_source_photos"].tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20))
        pause(1)
        shot(app, "personal-una-2-esto-lei")
        editFirstNote(app, name: "personal-una-3-editando", typing: " centro")
        XCTAssertTrue(tapWhenHittable(app.buttons["image_save"]))
        pause(0.3)
        shot(app, "personal-una-4-guardado")
        pause(2)
        shot(app, "personal-una-5-tras-guardar")
    }

    func test_personal_varias() {
        let app = openPersonal("many")
        app.buttons["image_source_photos"].tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20))
        pause(1.5)
        shot(app, "personal-varias-1-esto-lei")
        editFirstNote(app, name: "personal-varias-2-editando", typing: nil)
    }

    // MARK: - Grupo

    func test_grupo_foto() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", "cusco"] + textSizeArguments)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        _ = app.descendants(matching: .any)["group_detail_ready"].waitForExistence(timeout: 10)
        pause(1)
        XCTAssertTrue(tapWhenHittable(app.buttons["group_detail_receipt_photo"]))
        pause(1.5)
        shot(app, "grupo-1-elegir")
        _ = tapWhenHittable(app.buttons["group_photo_source_photos"])
        XCTAssertTrue(app.buttons["receipt_split_use"].waitForExistence(timeout: 20))
        pause(1)
        shot(app, "grupo-2-esto-lei")
        if tapWhenHittable(app.buttons["receipt_split_line_description"].firstMatch, timeout: 3) {
            if app.textFields["receipt_split_line_description_field"].firstMatch.waitForExistence(timeout: 5) {
                pause(0.8)
                shot(app, "grupo-3-editando")
            }
        }
    }
}
