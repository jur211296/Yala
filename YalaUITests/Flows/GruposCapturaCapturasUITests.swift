//
//  GruposCapturaCapturasUITests.swift
//  YalaUITests
//
//  Capturas lado a lado de Voz, Foto y Yala IA en personal y en un grupo (encargo «Grupos: voz, foto y Yala IA
//  idénticos a personal», 2026-11-16). No fija nada: guarda una captura por paso para comparar el antes y el después.
//  Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`; sin esa variable, se salta.
//

import XCTest

final class GruposCapturaCapturasUITests: XCTestCase {

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

    private func tapFirst(_ app: XCUIApplication, _ ids: [String], timeout: TimeInterval = 10) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            for id in ids {
                let button = app.buttons[id]
                if button.exists, button.isHittable {
                    button.tap()
                    return true
                }
            }
            pause(0.3)
        }
        return false
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }

    // MARK: - Personal

    func test_personal_voz() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "records", aiConsent: true,
                            extraArguments: ["-uitest-voice-result", "one", "-uitest-voice-live"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        XCTAssertTrue(tapFirst(app, ["stats_action_voice"]))
        pause(3)
        shot(app, "personal-voz-1-escuchando")
        _ = tapFirst(app, ["voice_done"])
        pause(0.6)
        shot(app, "personal-voz-2-procesando")
        _ = app.staticTexts["voice_review_title"].waitForExistence(timeout: 15)
        pause(0.8)
        shot(app, "personal-voz-3-revision")
    }

    func test_personal_foto() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "records", aiConsent: true)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        XCTAssertTrue(tapFirst(app, ["stats_action_image"]))
        pause(1.5)
        shot(app, "personal-foto-1-elegir")
    }

    func test_personal_ia() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "records", aiChatReady: true)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        XCTAssertTrue(tapFirst(app, ["stats_action_ai"]))
        _ = app.textFields["chat_input"].waitForExistence(timeout: 10)
        pause(1.5)
        shot(app, "personal-ia-1-vacio")
    }

    // MARK: - Grupo

    private func openGroup(profile: String = "cusco", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", profile] + extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90))
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        _ = app.descendants(matching: .any)["group_detail_ready"].waitForExistence(timeout: 10)
        pause(1)
        return app
    }

    func test_grupo_detalle_fab() {
        let app = openGroup()
        shot(app, "grupo-fab-1-arriba")
        for _ in 0..<4 { app.swipeUp() }
        pause(1)
        shot(app, "grupo-fab-2-desplazado")
    }

    func test_grupo_voz() {
        let app = openGroup(extra: ["-uitest-voice-live"])
        XCTAssertTrue(tapFirst(app, ["group_detail_receipt_voice"]))
        pause(3)
        shot(app, "grupo-voz-1-escuchando")
        _ = tapFirst(app, ["group_voice_done", "receipt_split_stop"])
        pause(0.6)
        shot(app, "grupo-voz-2-procesando")
        _ = app.buttons["receipt_split_use"].waitForExistence(timeout: 15)
        pause(0.8)
        shot(app, "grupo-voz-3-revision")
    }

    func test_grupo_foto() {
        let app = openGroup()
        XCTAssertTrue(tapFirst(app, ["group_detail_receipt_photo"]))
        pause(1.5)
        shot(app, "grupo-foto-1-elegir")
        _ = tapFirst(app, ["group_photo_source_photos", "receipt_split_library"])
        pause(0.5)
        if app.buttons["receipt_split_split"].exists { app.buttons["receipt_split_split"].tap() }
        pause(0.3)
        shot(app, "grupo-foto-2-leyendo")
        _ = app.buttons["receipt_split_use"].waitForExistence(timeout: 15)
        pause(0.8)
        shot(app, "grupo-foto-3-revision")
    }

    func test_grupo_ia() {
        let app = openGroup()
        XCTAssertTrue(tapFirst(app, ["group_detail_receipt_ai"]))
        pause(1.5)
        shot(app, "grupo-ia-1-vacio")
        let chat = app.textFields["group_chat_input"]
        let field = chat.exists ? chat : app.textFields["receipt_split_text"]
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("Pizza 48 Ana y yo, lomo 38 Ana, ají 32 Beto")
        }
        _ = tapFirst(app, ["group_chat_send", "receipt_split_split"], timeout: 3)
        pause(0.6)
        shot(app, "grupo-ia-2-pensando")
        pause(2.5)
        shot(app, "grupo-ia-3-respuesta")
        if tapFirst(app, ["group_chat_adjust"], timeout: 2) {
            pause(1)
            shot(app, "grupo-ia-4-ajustar")
        }
    }
}
