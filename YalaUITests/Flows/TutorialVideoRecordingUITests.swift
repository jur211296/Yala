//
//  TutorialVideoRecordingUITests.swift
//  YalaUITests
//
//  Graba los vídeos de los tutoriales de Ajustes › Tutoriales (UX 2.2 · L16-16: «vídeos y textos regrabados»). NO es una
//  red: cada caso hace lo que enseña un paso del tutorial, con pausas para que se vea, y apunta en `YALA_RECORD_DIR` cuándo
//  empieza y acaba el tramo que vale. Un script del host graba el simulador mientras corre (`simctl io recordVideo`), corta
//  por esas marcas y le pone el marco del teléfono.
//
//  Se salta salvo con `TEST_RUNNER_YALA_RECORD_DIR` puesto: en el CI y en el gate no corre nada.
//

import XCTest

final class TutorialVideoRecordingUITests: XCTestCase {

    private var recordDir: String = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        recordDir = ProcessInfo.processInfo.environment["YALA_RECORD_DIR"] ?? ""
        try XCTSkipIf(recordDir.isEmpty, "Solo para grabar los vídeos de los tutoriales (YALA_RECORD_DIR).")
    }

    // MARK: - Helpers

    private func launch(pro: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: pro, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        pause(1.5)
        return app
    }

    private func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

    /// Marca el principio o el final del tramo que se queda en el vídeo, y espera a que el script del host conteste: al
    /// empezar, que ya está grabando (`.go`); al acabar, que ya paró (`.done`). `simctl io recordVideo` solo escribe
    /// fotogramas cuando cambia la pantalla, así que el tiempo del vídeo no se puede casar con el reloj: se graba justo
    /// el tramo en vez de recortarlo después.
    private func mark(_ edge: String) {
        let name = String(name.split(separator: " ").last?.dropLast() ?? "x")
        let dir = URL(fileURLWithPath: recordDir)
        do {
            try String(Date().timeIntervalSince1970).write(
                to: dir.appendingPathComponent("\(name).\(edge)"), atomically: true, encoding: .utf8)
        } catch {
            XCTFail("TutorialVideoRecordingUITests: no se pudo dejar la marca \(edge): \(error)")
        }
        let reply = dir.appendingPathComponent("\(name).\(edge == "start" ? "go" : "done")")
        let deadline = Date().addingTimeInterval(10)
        while !FileManager.default.fileExists(atPath: reply.path) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func tap(_ element: XCUIElement, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "No apareció \(what).")
        element.tap()
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    private func type(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No apareció el campo.")
        field.tap()
        pause(0.4)
        for chunk in text.map(String.init) {
            field.typeText(chunk)
            Thread.sleep(forTimeInterval: 0.07)
        }
    }

    // MARK: - Crear una cuenta

    func test_rec_createAccount_step0() {
        let app = launch()
        app.openProfile()
        pause(1)
        mark("start")
        pause(0.8)
        tap(app.buttons["profile_accounts"], "Cuentas")
        pause(1.5)
        tap(app.buttons["accounts_add_button"], "el +")
        pause(2)
        mark("end")
    }

    func test_rec_createAccount_step1() {
        let app = launch()
        mark("start")
        pause(1)
        let chip = app.buttons["panel_account_chip_0"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        let add = app.buttons["panel_account_chip_add"]
        var tries = 0
        while !(add.exists && add.isHittable) && tries < 6 {
            chip.swipeLeft()
            pause(0.6)
            tries += 1
        }
        pause(0.6)
        tap(add, "Agregar")
        pause(2)
        mark("end")
    }

    func test_rec_createAccount_step2() {
        let app = launch()
        app.openProfile()
        tap(app.buttons["profile_accounts"], "Cuentas")
        tap(app.buttons["accounts_add_button"], "el +")
        pause(1.2)
        mark("start")
        type(app.textFields["account_name_field"], "Ahorro viaje")
        pause(0.5)
        type(app.textFields["account_balance_field"], "1500")
        pause(1)
        tap(app.buttons["toolbar_save_button"], "Guardar")
        pause(2)
        mark("end")
    }

    // MARK: - Crear categorías

    func test_rec_createCategories_step0() {
        let app = launch()
        app.openProfile()
        pause(1)
        mark("start")
        pause(0.8)
        tap(app.buttons["profile_categories"], "Categorías")
        pause(1.5)
        tap(app.buttons["categories_add_button"], "el +")
        pause(2)
        mark("end")
    }

    func test_rec_createCategories_step1() {
        let app = launch()
        app.openProfile()
        tap(app.buttons["profile_categories"], "Categorías")
        tap(app.buttons["categories_add_button"], "el +")
        pause(1.2)
        mark("start")
        type(app.textFields["category_name_field"], "Viajes")
        pause(0.8)
        tap(app.buttons["category_add_subcategory"], "añadir subcategoría")
        pause(2)
        mark("end")
    }

    func test_rec_createCategories_step2() {
        let app = launch()
        app.openProfile()
        tap(app.buttons["profile_categories"], "Categorías")
        tap(app.buttons["categories_add_button"], "el +")
        type(app.textFields["category_name_field"], "Viajes")
        tap(app.buttons["category_add_subcategory"], "añadir subcategoría")
        pause(1.2)
        mark("start")
        type(app.textFields["subcategory_name_field"], "Pasajes")
        pause(1)
        app.swipeUp()
        pause(1.2)
        app.swipeDown()
        pause(0.8)
        tap(app.buttons["toolbar_save_button"], "Guardar subcategoría")
        pause(2)
        mark("end")
    }

    func test_rec_createCategories_step3() {
        let app = launch()
        app.openProfile()
        tap(app.buttons["profile_categories"], "Categorías")
        tap(app.buttons["categories_add_button"], "el +")
        pause(1.2)
        mark("start")
        type(app.textFields["category_name_field"], "Viajes")
        pause(0.6)
        app.swipeUp()
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        mark("end")
    }

    // MARK: - Crear etiquetas

    func test_rec_createTags_step0() {
        let app = launch()
        app.openProfile()
        pause(1)
        mark("start")
        pause(0.8)
        tap(app.buttons["profile_tags"], "Etiquetas")
        pause(1.5)
        tap(app.buttons["tags_add_button"], "el +")
        pause(2)
        mark("end")
    }

    func test_rec_createTags_step1() {
        let app = launch()
        app.openProfile()
        tap(app.buttons["profile_tags"], "Etiquetas")
        tap(app.buttons["tags_add_button"], "el +")
        pause(1.2)
        mark("start")
        type(app.textFields["tag_name_field"], "Viaje a Cusco")
        pause(0.8)
        app.swipeUp()
        pause(1.5)
        tap(app.buttons["toolbar_save_button"], "Guardar")
        pause(2)
        mark("end")
    }

    // MARK: - Registrar un gasto

    func test_rec_createRecord_step0() {
        let app = launch()
        mark("start")
        pause(1.2)
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(2.5)
        mark("end")
    }

    func test_rec_createRecord_step1() {
        let app = launch()
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        mark("start")
        pause(0.6)
        tap(app.buttons["new_transaction_type_income"], "Ingreso")
        pause(1.2)
        tap(app.buttons["new_transaction_type_transfer"], "Transferencia")
        pause(1.2)
        tap(app.buttons["new_transaction_type_expense"], "Gasto")
        pause(1.2)
        mark("end")
    }

    func test_rec_createRecord_step2() {
        let app = launch()
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        mark("start")
        type(app.textFields["new_transaction_amount"], "45.90")
        pause(0.6)
        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        pause(0.8)
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        pause(1)
        tap(app.buttons["new_transaction_save"], "Guardar")
        pause(2)
        mark("end")
    }

    // MARK: - Importar datos

    func test_rec_importData_step0() {
        let app = launch()
        app.openProfile()
        let row = scrollTo(app, "Importar archivo")
        pause(1)
        mark("start")
        pause(0.8)
        tap(row, "Importar archivo")
        pause(2.5)
        mark("end")
    }

    func test_rec_importData_step1() {
        let app = launch()
        app.openProfile()
        let row = scrollTo(app, "Importar archivo")
        tap(row, "Importar archivo")
        pause(1.5)
        mark("start")
        pause(1)
        app.swipeUp()
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        mark("end")
    }

    // MARK: - Personalizar el Panel

    func test_rec_editPanel_step0() {
        let app = launch()
        mark("start")
        pause(1)
        app.swipeUp()
        pause(1.2)
        app.swipeUp()
        pause(1.2)
        app.swipeDown()
        pause(0.8)
        app.swipeDown()
        pause(1)
        mark("end")
    }

    func test_rec_editPanel_step1() {
        let app = launch()
        let prefs = app.buttons["Preferencias de widgets"].firstMatch
        mark("start")
        pause(1)
        tap(prefs, "Preferencias de widgets")
        pause(2.5)
        app.swipeUp()
        pause(1.5)
        mark("end")
    }

    func test_rec_editPanel_step2() {
        let app = launch()
        let prefs = app.buttons["Preferencias de widgets"].firstMatch
        tap(prefs, "Preferencias de widgets")
        pause(1.5)
        mark("start")
        pause(0.8)
        for _ in 0..<3 { app.swipeUp(); pause(0.8) }
        pause(1.5)
        mark("end")
    }
    // MARK: - Registrar un gasto (atajos)

    func test_rec_createRecord_step3() {
        let app = launch()
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        let note = app.textFields["Descripción"].firstMatch
        mark("start")
        type(note, "Almuerzo @")
        pause(1.5)
        type(note, "a")
        pause(1.5)
        mark("end")
    }

    // MARK: - Presupuestos

    private func openPlanning(_ app: XCUIApplication, chip: String) {
        app.tabBars.buttons.element(boundBy: 2).tap()
        pause(0.8)
        let chipButton = app.buttons["planning_chip_\(chip)"]
        if chipButton.waitForExistence(timeout: 5) { chipButton.tap() }
    }

    func test_rec_createBudgets_step0() {
        let app = launch()
        mark("start")
        pause(0.8)
        openPlanning(app, chip: "budgets")
        pause(1.5)
        tap(app.buttons["budgets_create_button"], "el +")
        pause(2)
        mark("end")
    }

    func test_rec_createBudgets_step1() {
        let app = launch()
        openPlanning(app, chip: "budgets")
        tap(app.buttons["budgets_create_button"], "el +")
        pause(1.2)
        mark("start")
        type(app.textFields["budget_name_field"], "Comida")
        pause(0.4)
        type(app.textFields["budget_amount_field"], "800")
        pause(0.8)
        app.swipeUp()
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        mark("end")
    }

    func test_rec_createBudgets_step2() {
        let app = launch()
        openPlanning(app, chip: "budgets")
        tap(app.buttons["budgets_create_button"], "el +")
        pause(1.2)
        let toggle = app.switches["budget_show_in_widget_toggle"]
        var tries = 0
        while !(toggle.exists && toggle.isHittable) && tries < 8 { app.swipeUp(); tries += 1 }
        pause(0.8)
        mark("start")
        pause(1)
        toggle.switches.firstMatch.tap()
        pause(2)
        mark("end")
    }

    func test_rec_createBudgets_step3() {
        let app = launch()
        openPlanning(app, chip: "budgets")
        pause(1)
        mark("start")
        pause(0.8)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "budget_row_")).firstMatch
        tap(row, "un presupuesto")
        pause(2.5)
        mark("end")
    }

    // MARK: - Pagos planificados

    func test_rec_createScheduledPayments_step0() {
        let app = launch()
        mark("start")
        pause(0.8)
        openPlanning(app, chip: "scheduledPayments")
        pause(1.5)
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        pause(2)
        mark("end")
    }

    func test_rec_createScheduledPayments_step1() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        pause(1.2)
        mark("start")
        type(app.textFields["scheduled_name_field"], "Alquiler")
        pause(0.4)
        type(app.textFields["scheduled_amount_field"], "1200")
        pause(0.8)
        app.buttons["scheduled_subcategory_row"].tap()
        pause(1.2)
        let firstSubcat = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_")).firstMatch
        tap(firstSubcat, "una subcategoría")
        pause(1.5)
        mark("end")
    }

    func test_rec_createScheduledPayments_step2() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        pause(1.2)
        mark("start")
        pause(0.6)
        app.swipeUp()
        pause(1.5)
        app.swipeUp()
        pause(1.5)
        mark("end")
    }

    func test_rec_createScheduledPayments_step3() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        pause(1.2)
        // El interruptor vive dentro de «Más opciones».
        let more = app.buttons["scheduled_more_options"]
        var tries = 0
        while !(more.exists && more.isHittable) && tries < 8 { app.swipeUp(); tries += 1 }
        pause(0.8)
        mark("start")
        pause(0.8)
        tap(more, "Más opciones")
        pause(1.2)
        // Se enseña el interruptor «¿Es una suscripción?» dentro de «Más opciones».
        app.swipeUp()
        pause(1.2)
        app.swipeUp()
        pause(2)
        mark("end")
    }

    func test_rec_createScheduledPayments_step4() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        pause(1)
        mark("start")
        pause(0.8)
        let row = app.buttons.matching(NSPredicate(format: "identifier == %@", "scheduled_payment_row")).firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
        } else {
            app.swipeUp()
        }
        pause(2.5)
        mark("end")
    }

    // MARK: - Favoritos

    func test_rec_createFavorites_step0() {
        let app = launch()
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        mark("start")
        pause(0.6)
        tap(app.buttons["new_transaction_favorite_action"], "la estrella")
        pause(1.5)
        let add = app.buttons["favorites_add_button"]
        if add.waitForExistence(timeout: 5) { add.tap() }
        pause(2)
        mark("end")
    }

    func test_rec_createFavorites_step1() {
        let app = launch()
        // La semilla no trae favoritos: se crea uno antes de grabar.
        app.openProfile()
        tap(app.buttons["profile_favorites"], "Pagos favoritos")
        tap(app.buttons["favorites_add_button"], "el +")
        type(app.textFields["favorite_name_field"], "Cafe de la manana")
        tap(app.buttons["toolbar_save_button"], "Guardar")
        pause(1)
        // Cierra Ajustes deslizando la hoja hacia abajo desde su borde de arriba.
        let sheetTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        sheetTop.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        pause(1.5)
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        mark("start")
        pause(0.6)
        // La estrella de arriba abre los favoritos; «Favorito», debajo del monto, guarda uno.
        tap(app.buttons["Plantillas favoritas"].firstMatch, "la estrella de arriba")
        pause(1.5)
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "favorites_row_")).firstMatch
        tap(row, "un favorito")
        pause(2.5)
        mark("end")
    }

    // MARK: - Bandeja

    func test_rec_inboxApproval_step0() {
        let app = launch()
        mark("start")
        pause(1)
        tap(app.buttons["panel_inbox_button"], "la Bandeja")
        pause(3)
        mark("end")
    }

    func test_rec_inboxApproval_step1() {
        let app = launch()
        tap(app.buttons["panel_inbox_button"], "la Bandeja")
        pause(1.5)
        mark("start")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inbox_draft_row_")).firstMatch
        tap(row, "un borrador")
        pause(2.5)
        app.swipeUp()
        pause(1.5)
        mark("end")
    }

    func test_rec_inboxApproval_step2() {
        let app = launch()
        tap(app.buttons["panel_inbox_button"], "la Bandeja")
        pause(1.5)
        mark("start")
        pause(1)
        let ready = app.buttons["inbox_save_ready"]
        var tries = 0
        while !(ready.exists && ready.isHittable) && tries < 4 { app.swipeUp(); tries += 1 }
        pause(1.5)
        mark("end")
    }

    func test_rec_inboxApproval_step3() {
        let app = launch()
        tap(app.buttons["panel_inbox_button"], "la Bandeja")
        pause(1.5)
        mark("start")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inbox_draft_row_")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.swipeLeft()
        pause(2.5)
        mark("end")
    }
}
