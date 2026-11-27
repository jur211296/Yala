//
//  TutorialVideoRecordingUITests.swift
//  YalaUITests
//
//  Graba los vídeos de los tutoriales de Ajustes › Tutoriales (UX 2.2 · L16-16; regrabados con los flujos de 2.3 el
//  27-nov-2026: asistentes por pasos, hoja B1 de Nuevo registro, Ajustes con tarjeta y filtros desde Estadísticas). NO es
//  una red: cada caso hace lo que enseña un paso del tutorial, con pausas para que se vea, y apunta en `YALA_RECORD_DIR`
//  cuándo empieza y acaba el tramo que vale. Un script del host graba el simulador mientras corre
//  (`qa/scripts/tutorial-videos/record.sh`, también por lotes), graba solo ese tramo y le pone el marco del teléfono.
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

    override func tearDown() {
        restaurarEsperaDeQuietud?()
        restaurarEsperaDeQuietud = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var restaurarEsperaDeQuietud: (() -> Void)?

    /// Con la hoja B1 de Nuevo registro y un importe escrito, la app no llega nunca a «quieta» para XCTest, que espera
    /// 60 s antes de cada gesto (medido el 27-nov-2026: un clip de 6 min para cuatro toques). Solo en estos casos de
    /// grabación, y solo hasta el `tearDown`, se quita esa espera: el ritmo lo marcan las pausas del propio caso.
    private func sinEsperaDeQuietud() {
        guard let process = NSClassFromString("XCUIApplicationProcess") else { return }
        var restaurar: [() -> Void] = []
        let dosArgumentos = NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:isPreEvent:")
        if let metodo = class_getInstanceMethod(process, dosArgumentos) {
            let original = method_getImplementation(metodo)
            let nada: @convention(block) (AnyObject, Bool, Bool) -> Void = { _, _, _ in }
            method_setImplementation(metodo, imp_implementationWithBlock(nada))
            restaurar.append { method_setImplementation(metodo, original) }
        }
        let unArgumento = NSSelectorFromString("waitForQuiescenceIncludingAnimationsIdle:")
        if let metodo = class_getInstanceMethod(process, unArgumento) {
            let original = method_getImplementation(metodo)
            let nada: @convention(block) (AnyObject, Bool) -> Void = { _, _ in }
            method_setImplementation(metodo, imp_implementationWithBlock(nada))
            restaurar.append { method_setImplementation(metodo, original) }
        }
        restaurarEsperaDeQuietud = { restaurar.forEach { $0() } }
    }

    private func launch(deeplink: String? = nil, deeplinkURL: String? = nil,
                        extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: deeplink, deeplinkURL: deeplinkURL,
                            extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente.")
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

    /// Escribe en `field`. Si ya tiene el teclado no lo toca: un toque sobre el campo con foco saca el menú
    /// «Autorrellenar» del sistema, que no debe salir en el vídeo.
    private func type(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No apareció el campo.")
        if !hasFocus(field) {
            field.tap()
            pause(0.4)
        }
        typeSlowly(field, text)
    }

    private func hasFocus(_ field: XCUIElement) -> Bool {
        (field.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    private func typeSlowly(_ field: XCUIElement, _ text: String) {
        for chunk in text.map(String.init) {
            field.typeText(chunk)
            Thread.sleep(forTimeInterval: 0.07)
        }
    }

    /// Cambia lo que el asistente propone en un campo por `text`, letra a letra.
    private func replace(_ field: XCUIElement, _ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No apareció el campo.")
        if !hasFocus(field) {
            field.tap()
            pause(0.4)
        }
        let current = field.value as? String ?? ""
        if !current.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            pause(0.3)
        }
        typeSlowly(field, text)
    }

    // MARK: - Asistentes por pasos (2.3)

    /// Espera la pregunta `texto` del asistente (`asistente_question`).
    private func question(_ app: XCUIApplication, _ texto: String) {
        let titulo = app.staticTexts["asistente_question"]
        let espera = expectation(for: NSPredicate(format: "label == %@", texto), evaluatedWith: titulo)
        XCTAssertEqual(XCTWaiter.wait(for: [espera], timeout: 8), .completed,
                       "Se esperaba «\(texto)» y se ve «\(titulo.label)».")
    }

    /// Toca «Siguiente» del asistente, con una pausa antes para que se lea lo elegido (y el teclado se asiente).
    private func next(_ app: XCUIApplication, after seconds: TimeInterval = 0.9) {
        pause(seconds)
        let boton = app.buttons["asistente_next"]
        XCTAssertTrue(boton.waitForExistence(timeout: 5), "No está «Siguiente».")
        boton.tap()
        pause(0.6)
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
        question(app, "¿Qué tipo de cuenta es?")
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
        question(app, "¿Qué tipo de cuenta es?")
        pause(1)
        mark("start")
        pause(0.6)
        tap(app.buttons["asistente_cuenta_tipo_savings"], "Cuenta de ahorros")
        next(app)
        next(app, after: 1.2)                                       // la moneda principal, ya marcada
        replace(app.textFields["asistente_cuenta_nombre"], "Ahorro viaje")
        next(app)
        type(app.textFields["asistente_cuenta_saldo"], "1500")
        next(app)
        pause(1.5)                                                  // «¿La creamos así?»
        tap(app.buttons["asistente_next"], "Crear cuenta")
        pause(2.5)
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
        pause(0.6)
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
        pause(0.8)
        // El icono de arriba (con el lápiz) abre el icono y el color.
        tap(app.buttons["Editar"].firstMatch, "el icono de la categoría")
        pause(2)
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
        // Hoja B1: el tipo se elige en el título-menú.
        app.chooseNewTransactionType("income")
        pause(1.2)
        app.chooseNewTransactionType("transfer")
        pause(1.2)
        app.chooseNewTransactionType("expense")
        pause(1.2)
        mark("end")
    }

    func test_rec_createRecord_step2() {
        let app = launch()
        sinEsperaDeQuietud()
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

    func test_rec_createRecord_step3() {
        let app = launch()
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        let note = app.textFields["new_transaction_note"]
        mark("start")
        type(note, "Almuerzo @")
        pause(1.5)
        typeSlowly(note, "a")
        pause(1.5)
        mark("end")
    }

    // MARK: - Importar datos

    func test_rec_importData_step0() {
        let app = launch()
        app.openProfile()
        let row = scrollTo(app, "profile_import")
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
        let row = scrollTo(app, "profile_import")
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

    // MARK: - Presupuestos

    private func openPlanning(_ app: XCUIApplication, chip: String) {
        app.selectTab(.planning)
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
        question(app, "¿Qué gastos cuenta?")
        pause(2)
        mark("end")
    }

    func test_rec_createBudgets_step1() {
        let app = launch()
        openPlanning(app, chip: "budgets")
        tap(app.buttons["budgets_create_button"], "el +")
        question(app, "¿Qué gastos cuenta?")
        pause(1)
        mark("start")
        next(app, after: 1.2)                                       // «Todos mis gastos», ya marcado
        tap(app.buttons["asistente_presupuesto_periodo_monthly"], "Mensual")
        next(app)
        type(app.textFields["asistente_presupuesto_tope"], "800")
        next(app)
        replace(app.textFields["asistente_presupuesto_nombre"], "Comida")
        next(app)
        tap(app.buttons["asistente_presupuesto_aviso_100"], "aviso al 100 %")
        next(app)
        pause(1.5)                                                  // «¿Lo creamos así?»
        tap(app.buttons["asistente_next"], "Crear presupuesto")
        pause(2.5)
        mark("end")
    }

    /// «Mostrar en el widget» no está en el asistente: se enseña editando un presupuesto que ya existe.
    func test_rec_createBudgets_step2() {
        let app = launch()
        openPlanning(app, chip: "budgets")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "budget_row_")).firstMatch
        tap(row, "un presupuesto")
        pause(1.2)
        mark("start")
        pause(0.8)
        tap(app.buttons["Editar"].firstMatch, "Editar")
        pause(1.2)
        let toggle = app.switches["budget_show_in_widget_toggle"]
        var tries = 0
        while !(toggle.exists && toggle.isHittable) && tries < 8 { app.swipeUp(); pause(0.5); tries += 1 }
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
        question(app, "¿Qué pagas cada cierto tiempo?")
        pause(2)
        mark("end")
    }

    func test_rec_createScheduledPayments_step1() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        question(app, "¿Qué pagas cada cierto tiempo?")
        pause(1)
        mark("start")
        pause(0.6)
        tap(app.buttons["asistente_pago_tipo_rent"], "Alquiler")
        next(app)
        replace(app.textFields["asistente_pago_nombre"], "Alquiler")
        next(app)
        type(app.textFields["asistente_pago_monto"], "1200")
        next(app)
        pause(1.2)                                                  // «¿Cada cuánto toca pagar?»
        mark("end")
    }

    func test_rec_createScheduledPayments_step2() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        question(app, "¿Qué pagas cada cierto tiempo?")
        tap(app.buttons["asistente_pago_tipo_rent"], "Alquiler")
        next(app, after: 0.3)
        next(app, after: 0.3)                                       // el nombre que propone
        type(app.textFields["asistente_pago_monto"], "1200")
        next(app, after: 0.5)
        question(app, "¿Cada cuánto toca pagar?")
        pause(1)
        mark("start")
        pause(0.6)
        tap(app.buttons["asistente_pago_frecuencia_monthly"], "Cada mes")
        next(app)
        next(app, after: 1.5)                                       // «¿Qué día del mes toca?»
        tap(app.buttons["asistente_pago_aviso_oneDayBefore"], "1 día antes")
        next(app)
        pause(1.5)                                                  // «¿Algo más?»
        mark("end")
    }

    /// El interruptor «¿Es una suscripción?» vive en la primera pregunta del asistente (2.3).
    func test_rec_createScheduledPayments_step3() {
        let app = launch()
        openPlanning(app, chip: "scheduledPayments")
        tap(app.buttons["scheduled_payments_create_button"], "el +")
        question(app, "¿Qué pagas cada cierto tiempo?")
        pause(1)
        mark("start")
        pause(0.6)
        let toggle = app.switches["asistente_pago_suscripcion"].exists
            ? app.switches["asistente_pago_suscripcion"]
            : app.descendants(matching: .any)["asistente_pago_suscripcion"].firstMatch
        var tries = 0
        while !(toggle.exists && toggle.isHittable) && tries < 6 { app.swipeUp(); pause(0.5); tries += 1 }
        pause(1)
        if toggle.switches.firstMatch.exists { toggle.switches.firstMatch.tap() } else { toggle.tap() }
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

    /// Hoja B1: «Guardar como favorito» vive en «···».
    func test_rec_createFavorites_step0() {
        let app = launch()
        sinEsperaDeQuietud()
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        mark("start")
        type(app.textFields["new_transaction_amount"], "12.50")
        pause(0.6)
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        pause(1)
        app.tapNewTransactionMoreAction("new_transaction_favorite_action")
        pause(2.5)
        mark("end")
    }

    /// La fila de favoritos de Nuevo registro: tocar uno completa el formulario.
    func test_rec_createFavorites_step1() {
        let app = launch(extra: ["-uitest-seed-extra-favorites", "3"])
        tap(app.buttons["panel_action_new"], "Nuevo registro")
        pause(1.5)
        let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@",
                                                    "new_transaction_favorite_chip_")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No salió la fila de favoritos.")
        mark("start")
        pause(1.2)
        chip.tap()
        pause(3)
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

    // MARK: - Filtrar el Panel (2.3: se filtra desde Estadísticas › Distribución)

    private func launchOnDistribution() -> XCUIApplication {
        let app = launch(deeplinkURL: "yaladev://statistics/categories")
        XCTAssertTrue(app.buttons.matching(identifier: "distribution_category_row").firstMatch
            .waitForExistence(timeout: 20), "No apareció Distribución.")
        pause(0.8)
        return app
    }

    /// Pasa Distribución a «Gráficas» y la gráfica a su página de subcategorías.
    private func showSubcategoryChart(_ app: XCUIApplication) {
        let modes = app.buttons.matching(identifier: "distribution_content_mode")
        XCTAssertTrue(modes.element(boundBy: 1).waitForExistence(timeout: 5), "Falta «Gráficas».")
        modes.element(boundBy: 1).tap()
        pause(1.2)
        // Se desliza sobre el título de la tarjeta: el botón «Distribución por categoría» es el «?» de su ayuda.
        let chart = app.staticTexts.matching(identifier: "distribution_page_category").firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "No salió la gráfica de categorías.")
        chart.swipeLeft()
        pause(1.2)
        let leyenda = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@",
                                                       "distribution_page_subcategory", "Supermercados")).firstMatch
        XCTAssertTrue(leyenda.waitForHittable(timeout: 5), "La gráfica no pasó a subcategorías.")
    }

    /// Toca la subcategoría `name` en la leyenda de la gráfica: filtra.
    private func tapChartSubcategory(_ app: XCUIApplication, _ name: String) {
        let item = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@",
                                                    "distribution_page_subcategory", name)).firstMatch
        tap(item, "«\(name)» en la gráfica")
    }

    private func waitForFilterBand(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["filter_band_remove_all"].waitForExistence(timeout: 8), "No salió la barra de filtros.")
    }

    func test_rec_panelFiltering_step0() {
        let app = launchOnDistribution()
        mark("start")
        pause(1)
        showSubcategoryChart(app)
        pause(0.6)
        tapChartSubcategory(app, "Supermercados")
        waitForFilterBand(app)
        pause(2.5)
        mark("end")
    }

    func test_rec_panelFiltering_step1() {
        let app = launchOnDistribution()
        showSubcategoryChart(app)
        tapChartSubcategory(app, "Supermercados")
        waitForFilterBand(app)
        pause(1.2)
        mark("start")
        pause(1.5)
        let removes = app.buttons.matching(identifier: "applied_filter_chip_remove")
        tap(removes.element(boundBy: max(0, removes.count - 1)), "la X de un filtro")
        pause(2)
        tap(app.buttons["filter_band_remove_all"], "Quitar todo")
        pause(2)
        mark("end")
    }

    func test_rec_panelFiltering_step2() {
        let app = launchOnDistribution()
        mark("start")
        pause(1)
        let selector = app.buttons["Subcategorías"].firstMatch
        tap(selector, "la lista de subcategorías")
        pause(1.5)
        let rows = app.buttons.matching(identifier: "distribution_subcategory_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "La lista no pasó a subcategorías.")
        // «Sin subcategoría» no filtra: se toca la primera que sí.
        for index in 0..<min(rows.count, 4) {
            let row = rows.element(boundBy: index)
            if row.label.hasPrefix("Sin subcategoría") { continue }
            row.tap()
            break
        }
        waitForFilterBand(app)
        pause(2.5)
        mark("end")
    }

    func test_rec_panelFiltering_step3() {
        let app = launchOnDistribution()
        showSubcategoryChart(app)
        tapChartSubcategory(app, "Restaurantes")
        waitForFilterBand(app)
        app.swipeDown()
        pause(1.2)
        mark("start")
        pause(1.2)
        tap(app.buttons["detail_chip_tendencias"], "Tendencias")
        pause(2.2)
        tap(app.buttons["detail_chip_registros"], "Registros")
        pause(2.2)
        app.selectTab(.panel)
        pause(2.5)
        mark("end")
    }

    func test_rec_panelFiltering_step4() {
        let app = launchOnDistribution()
        mark("start")
        pause(1)
        tap(app.buttons["filters_toolbar_button"], "Filtros")
        pause(1.5)
        // La cuenta en soles: con la de dólares, Distribución se queda en «Sin movimientos en este período».
        let cuenta = app.buttons["Cuenta Principal"].firstMatch
        XCTAssertTrue(cuenta.waitForExistence(timeout: 5), "Filtros no ofrece «Cuenta Principal».")
        cuenta.tap()
        pause(1.2)
        tap(app.buttons["filters_apply_button"], "Aplicar")
        waitForFilterBand(app)
        pause(2)
        tap(app.buttons["filter_band_remove_all"], "Quitar todo")
        pause(2)
        mark("end")
    }
}
