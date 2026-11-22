//
//  CuentaSolaReglasCapturasUITests.swift
//  YalaUITests
//
//  Capturas del antes y el después de las reglas de captura (parte 2, 2026-11-21): el permiso de voz y foto, Editar
//  cuenta con «Reglas de captura», el editor «Nueva regla» y «Recordar» tras corregir la cuenta de una foto. No fija
//  nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`, `TEST_RUNNER_CAPTURA_FASE=antes|despues` y, para el
//  tema claro, `TEST_RUNNER_CAPTURA_TEMA=claro`; sin la carpeta, se salta.
//

import XCTest

final class CuentaSolaReglasCapturasUITests: XCTestCase {

    private var folder: String?
    private var suffix = "oscuro"
    private var fase = "despues"

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
        if ProcessInfo.processInfo.environment["CAPTURA_TEMA"] == "claro" { suffix = "claro" }
        if ProcessInfo.processInfo.environment["CAPTURA_FASE"] == "antes" { fase = "antes" }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(fase)-\(name)-\(suffix).png")
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

    private var theme: [String] { suffix == "claro" ? ["-userTheme", "1"] : [] }

    /// El permiso de voz y foto que sale al tocar «Foto» sin haberlo aceptado.
    func test_capturaPermiso() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "ficha", extraArguments: theme)
        XCTAssertTrue(app.waitForUITestReady())
        let foto = app.buttons["panel_action_image"]
        XCTAssertTrue(foto.waitForExistence(timeout: 10))
        foto.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 8), "No salió el permiso.")
        pause(1)
        shot(app, "permiso")
    }

    /// Editar cuenta de «Tarjeta de crédito», bajado hasta debajo del número de cuenta.
    func test_capturaEditarCuenta() {
        let app = openEditar(extra: [])
        shot(app, "editar-cuenta")
        if fase == "despues" {
            let add = app.buttons["account_capture_rules_add"]
            if add.waitForExistence(timeout: 5) {
                add.tap()
                let field = app.textFields["capture_rule_value"]
                if field.waitForExistence(timeout: 8) {
                    field.typeText("zip")
                }
                pause(1)
                shot(app, "editor-regla")
            }
        }
    }

    /// Editar cuenta con una regla ya guardada (solo después).
    func test_capturaEditarCuentaConRegla() throws {
        try XCTSkipIf(fase == "antes")
        let app = openEditar(extra: ["-uitest-capture-rule", "Tarjeta de crédito|text|zip"])
        shot(app, "editar-cuenta-con-regla")
    }

    /// Corregir la cuenta de una foto y ver «Recordar» (solo después).
    func test_capturaRecordar() throws {
        try XCTSkipIf(fase == "antes")
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "ficha", aiConsent: true,
            extraArguments: ["-uitest-image-result", "cuenta-sola-zip", "-uitest-image-autoclose-seconds", "4"] + theme)
        XCTAssertTrue(app.waitForUITestReady())
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15))
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15))
        app.buttons["voice_draft_chip_account"].tap()
        let row = app.buttons["account_selector_row_Tarjeta de crédito"]
        if row.waitForExistence(timeout: 8) { row.tap() }
        let recordar = app.buttons["cuenta_sola_recordar"]
        XCTAssertTrue(recordar.waitForExistence(timeout: 8), "No salió «Recordar».")
        pause(1)
        shot(app, "recordar")
        recordar.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cuenta_sola_recordada"].firstMatch.waitForExistence(timeout: 5))
        pause(1)
        shot(app, "recordar-listo")
    }

    private func openEditar(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "ficha", extraArguments: ["-defaultPeriod", "last30Days"] + extra + theme)
        XCTAssertTrue(app.waitForUITestReady())
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10))
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) { app.buttons["panel_panorama_header"].tap() }
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Tarjeta de crédito.")).firstMatch
        var swipes = 0
        while !card.exists && swipes < 6 {
            first.swipeLeft()
            swipes += 1
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let edit = app.buttons["account_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        edit.tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 8))
        // Arrastres cortos hasta dejar la ayuda del número de cuenta arriba: debajo va «Reglas de captura» en el después.
        let help = app.descendants(matching: .any)["account_number_help"].firstMatch
        var drags = 0
        while drags < 8 && (!help.exists || help.frame.minY > app.frame.height * 0.3) {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
            drags += 1
        }
        pause(1)
        return app
    }
}
