//
//  RegistroB1PantallasCapturasUITests.swift
//  YalaUITests
//
//  Capturas de las pantallas de registro que llevan la hoja B1 (encargo del 20-nov: la aprobación de la Bandeja, Nuevo
//  gasto de Grupos, los borradores de grupo, Pago entre miembros y el editor de favorito), con el mismo guion antes y
//  después del cambio. Solo corre si la corrida lo pide (`TEST_RUNNER_YALA_CAPTURE_DIR`); el claro u oscuro lo pone
//  quien lanza (`simctl ui appearance`) y la app va con el tema «Sistema».
//

import XCTest

final class RegistroB1PantallasCapturasUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func requireCaptureRun() throws {
        guard ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil else {
            throw XCTSkip("Solo para capturas: sin YALA_CAPTURE_DIR no hay nada que hacer.")
        }
    }

    private func launch(seed: String, deeplink: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, deeplink: deeplink, extraArguments: ["-userTheme", "0"] + extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let prefix = ProcessInfo.processInfo.environment["YALA_CAPTURE_PREFIX"] ?? "captura"
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("RegistroB1PantallasCapturasUITests: captura no guardada: \(error)")
        }
    }

    /// Cierra el teclado tocando la pregunta del monto o un rótulo quieto, nunca la barra (en una hoja, arrastrarla es
    /// intentar cerrarla).
    private func dismissKeyboard(_ app: XCUIApplication, tapping target: XCUIElement) {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 2) else { return }
        if target.exists { target.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
    }

    // MARK: - 1 · Nuevo registro (gasto en soles y en dólares)

    func test_capture_1_nuevoRegistro() throws {
        try requireCaptureRun()
        let app = launch(seed: "tarjeta-dos-lineas", extra: ["-uitest-seed-registro-unificado"])
        app.buttons["panel_action_new"].tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No se abrió el formulario.")
        amount.tap()
        amount.typeText("45")
        dismissKeyboard(app, tapping: app.staticTexts["new_transaction_amount_question"])
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        capture(app, "1-nuevo-registro-soles")

        // La tarjeta «Visa QA» tiene su línea en dólares: con ella, la cápsula ofrece USD.
        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_Visa")
        let capsule = app.buttons["new_transaction_currency_capsule"]
        if capsule.waitForExistence(timeout: 3) {
            capsule.tap()
            let usd = app.buttons["new_transaction_currency_option_USD"].firstMatch
            if usd.waitForExistence(timeout: 5) {
                usd.tap()
                _ = element(app, "new_transaction_equivalence").waitForExistence(timeout: 5)
                capture(app, "1b-nuevo-registro-dolares")
            }
        }
    }

    // MARK: - 2 · Aprobación de la Bandeja

    func test_capture_2_bandeja() throws {
        try requireCaptureRun()
        let app = launch(seed: "tarjeta-dos-lineas", extra: ["-uitest-seed-registro-unificado"])
        app.buttons["panel_inbox_button"].tap()
        let row = app.buttons["inbox_draft_row_Almuerzo con el equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador sembrado.")
        row.tap()
        XCTAssertTrue(app.buttons["draft_editor_account_chip"].waitForExistence(timeout: 10), "No abrió la aprobación.")
        _ = app.waitForSettledLayout(of: app.buttons["draft_editor_account_chip"])
        capture(app, "2-bandeja-soles")

        // La línea en dólares de la tarjeta: con la B1, por la cápsula de moneda; antes, por su pastilla.
        let capsule = app.buttons["draft_editor_currency_capsule"]
        if capsule.exists {
            capsule.tap()
            let usd = app.buttons["draft_editor_currency_option_USD"].firstMatch
            if usd.waitForExistence(timeout: 5) { usd.tap() }
        } else if app.buttons["card_currency_chip_USD"].exists {
            app.buttons["card_currency_chip_USD"].tap()
        }
        _ = app.waitForSettledLayout(of: app.buttons["draft_editor_account_chip"])
        capture(app, "2b-bandeja-dolares")
    }

    // MARK: - 3 · Nuevo gasto de Grupos

    func test_capture_3_grupoNuevoGasto() throws {
        try requireCaptureRun()
        let app = launch(seed: "grupos", deeplink: "groups")
        let groupCard = element(app, "group_card")
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        groupCard.tap()
        let fab = app.buttons["group_detail_action_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto.")
        fab.tap()
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "El formulario no montó.")
        capture(app, "3-grupo-vacio")
        amount.tap()
        amount.typeText("240")
        dismissKeyboard(app, tapping: element(app, "group_expense_group_chip"))
        app.chooseFirstSelectorRow(chip: "group_expense_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        _ = app.waitForSettledLayout(of: app.buttons["group_expense_subcategory_chip"])
        capture(app, "3b-grupo-con-monto")
    }

    // MARK: - 4 · Borrador de grupo en la Bandeja

    func test_capture_4_grupoBorrador() throws {
        try requireCaptureRun()
        let app = launch(seed: "grupos", extra: ["-uitest-seed-group-split-lines"])
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()
        let row = app.buttons["inbox_draft_row_Recarga Sip"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador de «Recarga Sip».")
        row.tap()
        XCTAssertTrue(element(app, "group_draft_banner").waitForExistence(timeout: 8), "No abrió la hoja del gasto.")
        capture(app, "4-grupo-borrador")
    }

    // MARK: - 5 · Pago entre miembros

    func test_capture_5_pago() throws {
        try requireCaptureRun()
        let app = launch(seed: "grupos", deeplink: "groups")
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Viaje a Lima'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció «Viaje a Lima».")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let settle = element(app, "group_debt_settle")
        for _ in 0..<8 where !(settle.exists && settle.isHittable) { app.swipeUp() }
        XCTAssertTrue(settle.exists, "No hay «Saldar» en Lima.")
        settle.tap()
        XCTAssertTrue(app.textFields["settlement_form_amount"].waitForExistence(timeout: 5), "No abrió el pago.")
        capture(app, "5-pago")
    }

    // MARK: - 6 · Editor de favorito

    func test_capture_6_favorito() throws {
        try requireCaptureRun()
        let app = launch(seed: "formulario")
        app.openProfile()
        app.openSettingsSection("profile_favorites")
        let row = app.buttons["favorites_row_Café"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció el favorito «Café».")
        row.tap()
        XCTAssertTrue(app.textFields["favorite_name_field"].waitForExistence(timeout: 5), "No se abrió el editor.")
        capture(app, "6-favorito")
    }
}
